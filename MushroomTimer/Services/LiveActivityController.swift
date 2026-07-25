import ActivityKit
import Foundation
import SwiftData

/// 全程只維持一個 Live Activity，內容永遠是最快到期的那一筆。
///
/// 動態島同時只能顯示一個 Live Activity，所以不能一筆計時開一個。
///
/// 已知限制：免費帳號沒有遠端推播，主 App 沒在執行時無法在最快一筆到期的瞬間
/// 自動換成下一筆。因此 `ContentState` 會帶著下一筆的名稱，並在每次主 App
/// 有機會執行時（進前景、Intent 執行、處理通知動作）重新整理。
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
    static func refresh(context: ModelContext) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
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
