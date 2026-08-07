import Foundation
import SwiftData
import UserNotifications

/// 量測通知的實際送達時間，用來取代「盯著動態島估秒數」。
///
/// 存在的理由：使用者回報提醒有時準時、有時慢約 10 秒、偶爾完全沒出現。
/// 這三種情況的成因完全不同，而目視估算分辨不出來：
///
/// - 準時：預定與送達的差接近 0
/// - 遲到：差是正值，數字本身就是系統延遲了多久
/// - 從未送達：既沒有送達紀錄，排程裡也找不到對應的請求
/// - 還沒到時間：沒有送達紀錄，但排程裡找得到
///
/// 只有把這四種分開，才知道該修哪裡——或者該不該修。
enum NotificationDiagnostics {
    enum Outcome: Equatable {
        /// 已送達，附上與預定時刻的落差（正值＝遲到幾秒）。
        case delivered(delaySeconds: Int)
        /// 尚未送達，但請求還在排程裡等著。
        case pending
        /// 預定時間已過，卻既沒送達也不在排程裡——這筆是真的消失了。
        case missing
        /// 使用者自己取消或標記完成的，不列入判斷。
        case notApplicable
    }

    struct Row: Equatable {
        var mushroomName: String
        var intendedFireAt: Date
        var outcome: Outcome
    }

    /// 純函式，方便測試。`deliveredAt` 與 `pendingIDs` 由呼叫端從
    /// `UNUserNotificationCenter` 取得。
    static func rows(
        entries: [TimerEntry],
        deliveredAt: [UUID: Date],
        pendingIDs: Set<UUID>,
        now: Date = .now
    ) -> [Row] {
        entries.map { entry in
            Row(
                mushroomName: entry.mushroom?.name ?? "（已刪除的菇）",
                intendedFireAt: entry.fireAt,
                outcome: outcome(
                    for: entry, deliveredAt: deliveredAt, pendingIDs: pendingIDs, now: now
                )
            )
        }
    }

    private static func outcome(
        for entry: TimerEntry,
        deliveredAt: [UUID: Date],
        pendingIDs: Set<UUID>,
        now: Date
    ) -> Outcome {
        if let delivered = deliveredAt[entry.id] {
            // 這就是使用者一直在目測的那個數字，現在有精確值了。
            return .delivered(
                delaySeconds: Int(delivered.timeIntervalSince(entry.fireAt).rounded())
            )
        }
        if entry.status == .cancelled || entry.status == .completed {
            return .notApplicable
        }
        if pendingIDs.contains(entry.id) {
            return .pending
        }
        // 送達紀錄會被使用者滑掉，所以時間還沒到就找不到請求才算真的不見。
        return entry.fireAt <= now ? .missing : .pending
    }

    /// 從系統取得目前的送達與待發狀態，組出報告。
    @MainActor
    static func report(
        context: ModelContext,
        center: UNUserNotificationCenter = .current(),
        limit: Int = 20,
        now: Date = .now
    ) async throws -> [Row] {
        var descriptor = FetchDescriptor<TimerEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let entries = try context.fetch(descriptor)

        var deliveredAt: [UUID: Date] = [:]
        for note in await center.deliveredNotifications() {
            if let id = UUID(uuidString: note.request.identifier) {
                deliveredAt[id] = note.date
            }
        }
        let pendingIDs = Set(
            await center.pendingNotificationRequests()
                .compactMap { UUID(uuidString: $0.identifier) }
        )

        return rows(
            entries: entries, deliveredAt: deliveredAt, pendingIDs: pendingIDs, now: now
        )
    }
}
