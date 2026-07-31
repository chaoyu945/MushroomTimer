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
        /// 菇重生的時間，也就是畫面倒數的終點。
        ///
        /// 刻意不是「發通知的時間」。通知會提前 `leadSeconds` 響，所以拿它當終點的話，
        /// 島上歸零之後通知才到，看起來像通知遲到——實際上那正是提前量在發揮作用。
        /// 使用者真正在乎的是菇什麼時候重生，倒數就該對著那個時刻。
        var respawnAt: Date
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
