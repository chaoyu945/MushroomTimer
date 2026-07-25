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

        // 先排通知，成功了才動資料庫。
        //
        // 順序很重要，而且不能靠 `context.rollback()` 善後——實測證實它不會丟掉
        // 尚未存檔的 insert，也不會還原已經改掉的屬性。所以唯一可靠的做法是
        // 在確定通知排得進去之前，什麼都不要寫。
        //
        // 通知的識別碼就是這筆計時的 id，所以先把 id 產生出來。
        let id = UUID()
        do {
            try await scheduler.schedule(
                id: id,
                groupName: mushroom.group?.name ?? "",
                mushroomName: mushroom.name,
                at: fireAt
            )
        } catch {
            throw LogError.notificationFailed(error)
        }

        let entry = TimerEntry(
            id: id,
            mushroom: mushroom,
            createdAt: now,
            remainingSeconds: remainingSeconds,
            leadSeconds: leadSeconds,
            fireAt: fireAt
        )
        let previousLastUsedAt = mushroom.lastUsedAt
        context.insert(entry)
        mushroom.useCount += 1
        mushroom.lastUsedAt = now

        do {
            try context.save()
        } catch {
            // 存檔失敗時明確地把每一項還原回去，不要指望 rollback()。
            // 通知也要收回來，否則會響一個沒有對應計時的提醒。
            scheduler.cancel(id: id)
            context.delete(entry)
            mushroom.useCount -= 1
            mushroom.lastUsedAt = previousLastUsedAt
            throw error
        }

        WidgetChannel.refresh(context: context)
        // 傳同一個 now。用真實時間回收會把這筆剛建立的計時當成過期的。
        await LiveActivityController.refresh(context: context, now: now)

        return entry
    }

    /// 使用者左滑取消。連帶把已排定的通知撤掉。
    static func cancel(_ entry: TimerEntry, context: ModelContext) async throws {
        entry.status = .cancelled
        NotificationService.shared.cancel(id: entry.id)
        try context.save()
        await LiveActivityController.refresh(context: context)
    }

    /// 使用者按「已完成」。
    static func complete(_ entry: TimerEntry, context: ModelContext) async throws {
        entry.status = .completed
        NotificationService.shared.cancel(id: entry.id)
        try context.save()
        await LiveActivityController.refresh(context: context)
    }
}
