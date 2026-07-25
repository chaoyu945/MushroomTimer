import ActivityKit
import Foundation

/// Live Activity 的資料契約。
///
/// 免費帳號不能用 App Groups，Widget extension 讀不到主 App 的資料庫，
/// 因此顯示所需的**全部**資料都必須放進 `ContentState` 一次帶過去。
struct MushroomActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// 最快到期那一筆的菇名稱。
        var mushroomName: String
        /// 該筆所屬的群組名稱。
        var groupName: String
        /// 提醒時間。畫面用 `Text(timerInterval:)` 自己逐秒跑，不需背景更新。
        var fireAt: Date
        /// 除了目前這筆之外，還有幾筆在排隊。
        var queuedCount: Int
        /// 下一筆的菇名稱。主 App 沒在執行時無法自動切換，
        /// 先帶著讓畫面在目前這筆結束後仍有意義。
        var nextMushroomName: String?

        /// 排隊筆數的顯示文字，例如 `"+2"`；沒有排隊時為 `nil`。
        var queueLabel: String? {
            queuedCount > 0 ? "+\(queuedCount)" : nil
        }
    }
}
