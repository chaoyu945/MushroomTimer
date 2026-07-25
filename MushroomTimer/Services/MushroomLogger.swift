import Foundation
import SwiftData

/// 「登記一顆菇」的唯一入口。主畫面、App Intents、桌面小工具全部走這裡，
/// 三個入口的副作用（寫資料庫、排通知、更新使用次數）因此保證一致。
@MainActor
enum MushroomLogger {
    enum LogError: LocalizedError {
        /// 剩餘時間加重生時間扣掉提前量後已經是過去，不建立計時。
        case timeAlreadyPassed

        var errorDescription: String? {
            switch self {
            case .timeAlreadyPassed:
                return "時間已過，無法建立提醒"
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
        try context.save()

        try? await NotificationService.shared.schedule(
            id: entry.id,
            groupName: mushroom.group?.name ?? "",
            mushroomName: mushroom.name,
            at: fireAt
        )

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
