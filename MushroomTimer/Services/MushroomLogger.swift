import Foundation
import SwiftData

/// 「登記一顆菇」的唯一入口。主畫面、App Intents、桌面小工具全部走這裡，
/// 三個入口的副作用（寫資料庫、排通知、更新使用次數）因此保證一致。
@MainActor
enum MushroomLogger {
    enum LogError: LocalizedError {
        /// 剩餘時間加重生時間扣掉提前量後已經是過去，不建立計時。
        case timeAlreadyPassed
        /// 通知排不進去。這時整筆計時都不會建立——見 `log` 內的說明。
        case notificationFailed(Error)

        var errorDescription: String? {
            switch self {
            case .timeAlreadyPassed:
                return "時間已過，無法建立提醒"
            case .notificationFailed:
                return "無法排定通知，計時沒有建立。請檢查通知權限。"
            }
        }
    }

    @discardableResult
    static func log(
        mushroom: Mushroom,
        remainingSeconds: Int,
        leadSeconds: Int,
        respawnSeconds: Int,
        context: ModelContext,
        scheduler: NotificationScheduling = NotificationService.shared,
        now: Date = .now
    ) async throws -> TimerEntry {
        guard let fireAt = TimerCalculator.fireAt(
            now: now,
            remainingSeconds: remainingSeconds,
            respawnSeconds: respawnSeconds,
            leadSeconds: leadSeconds
        ) else {
            throw LogError.timeAlreadyPassed
        }

        let entry = TimerEntry(
            mushroom: mushroom,
            createdAt: now,
            remainingSeconds: remainingSeconds,
            leadSeconds: leadSeconds,
            fireAt: fireAt
        )
        context.insert(entry)
        mushroom.useCount += 1
        mushroom.lastUsedAt = now

        // 先排通知再存檔。排不成功就整筆回滾——寧可什麼都沒建立，
        // 也不要留下一筆會倒數但永遠不會響的計時。
        do {
            try await scheduler.schedule(
                id: entry.id,
                groupName: mushroom.group?.name ?? "",
                mushroomName: mushroom.name,
                at: fireAt
            )
        } catch {
            // rollback 會丟掉這個 context 上所有未存檔的變更，包含上面那些。
            context.rollback()
            throw LogError.notificationFailed(error)
        }

        do {
            try context.save()
        } catch {
            // 存檔失敗就把已經排好的通知收回來，否則會響一個沒有對應計時的提醒。
            scheduler.cancel(id: entry.id)
            context.rollback()
            throw error
        }

        return entry
    }

    /// 使用者左滑取消。連帶把已排定的通知撤掉。
    static func cancel(_ entry: TimerEntry, context: ModelContext) throws {
        entry.status = .cancelled
        NotificationService.shared.cancel(id: entry.id)
        try context.save()
    }

    /// 使用者按「已完成」。
    static func complete(_ entry: TimerEntry, context: ModelContext) throws {
        entry.status = .completed
        NotificationService.shared.cancel(id: entry.id)
        try context.save()
    }
}
