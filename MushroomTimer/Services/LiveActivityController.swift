import ActivityKit
import Foundation
import SwiftData

/// 全程只維持一個 Live Activity，內容永遠是最快到期的那一筆。
///
/// 動態島同時只能顯示一個 Live Activity，所以不能一筆計時開一個。
///
/// 已知限制：免費帳號沒有遠端推播，主 App 沒在執行時無法在最快一筆到期的瞬間
/// 自動換成下一筆。因此 `ContentState` 會帶著下一筆的名稱，並在每次主 App
/// 的 process 有機會執行時重新整理——進前景、以及每一次登記／取消／完成／
/// 通知動作（`NotificationActionHandler.handle` 的已完成與延後兩條路徑都會呼叫）。
@MainActor
enum LiveActivityController {
    /// 由進行中的計時（已依 fireAt 排序）組出畫面狀態。
    static func state(
        from timers: [TimerEntry]
    ) -> MushroomActivityAttributes.ContentState? {
        guard let soonest = timers.first else { return nil }
        return MushroomActivityAttributes.ContentState(
            mushroomName: soonest.mushroom?.name ?? "菇",
            groupName: soonest.mushroom?.group?.name ?? "",
            fireAt: soonest.fireAt,
            queuedCount: max(0, timers.count - 1),
            nextMushroomName: timers.dropFirst().first?.mushroom?.name
        )
    }

    /// 依目前資料庫內容建立、更新或結束唯一的 Live Activity。
    ///
    /// `now` 要跟呼叫端使用的時鐘一致。用真實時間去回收一筆以注入時間建立的計時，
    /// 會把它當成早就過期而直接標記成 fired。
    static func refresh(context: ModelContext, now: Date = .now) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // 先回收已到期的計時，再問誰是最快的一筆。
        //
        // `active` 只代表「沒被取消或完成」，過期的計時要等 `markFired` 才會翻面，
        // 而 `markFired` 只在 App 進前景時跑。偏偏 Intent 刻意不開啟 App——
        // 所以從小工具或捷徑登記時，鎖定畫面會把一筆早就響過的計時當成「下一個」，
        // 真正的下一筆反而被藏在 +N 裡面。
        try? TimerQueries.markFired(in: context, now: now)
        let timers = (try? TimerQueries.active(in: context)) ?? []
        let existing = Activity<MushroomActivityAttributes>.activities

        guard let state = state(from: timers) else {
            for activity in existing {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }

        let content = ActivityContent(state: state, staleDate: state.fireAt)
        if let activity = existing.first {
            await activity.update(content)
            // 保險起見，把多開的收掉，確保永遠只有一個。
            for extra in existing.dropFirst() {
                await extra.end(nil, dismissalPolicy: .immediate)
            }
        } else {
            _ = try? Activity.request(
                attributes: MushroomActivityAttributes(), content: content
            )
        }
    }
}
