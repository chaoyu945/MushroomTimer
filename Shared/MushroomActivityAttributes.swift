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

        init(
            mushroomName: String,
            groupName: String,
            respawnAt: Date,
            queuedCount: Int,
            nextMushroomName: String? = nil
        ) {
            self.mushroomName = mushroomName
            self.groupName = groupName
            self.respawnAt = respawnAt
            self.queuedCount = queuedCount
            self.nextMushroomName = nextMushroomName
        }

        // MARK: - 持久化格式
        //
        // ⚠️ `ContentState` 是**會被 ActivityKit 存起來**的格式，不只是記憶體裡的結構。
        // 進行中的 Live Activity 用「建立當下那個版本」的欄位名存著，App 更新之後
        // 由新版程式碼解碼。所以改欄位名等同於改檔案格式：舊的活動會解不開，
        // 卡片先凍結在最後一幀、接著變成空白，而通知照常運作——看起來像
        // 「Live Activity 無緣無故壞了」，很難聯想到是改名造成的。
        //
        // 2026-08 就是這樣把 `fireAt` 改名成 `respawnAt`，弄壞了當時正在飛的活動。
        // 下面保留舊鍵的相容解碼。要再改欄位名的話，請一併在這裡留退路。
        private enum CodingKeys: String, CodingKey {
            case mushroomName, groupName, respawnAt, queuedCount, nextMushroomName
            case legacyFireAt = "fireAt"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            mushroomName = try container.decode(String.self, forKey: .mushroomName)
            groupName = try container.decode(String.self, forKey: .groupName)
            queuedCount = try container.decode(Int.self, forKey: .queuedCount)
            nextMushroomName = try container.decodeIfPresent(
                String.self, forKey: .nextMushroomName
            )
            if let respawn = try container.decodeIfPresent(Date.self, forKey: .respawnAt) {
                respawnAt = respawn
            } else {
                // 舊版存的是發通知的時刻，比重生早一個提前量。差幾秒，
                // 但總比整張卡片畫不出來好——下次更新就會被覆蓋成正確的值。
                respawnAt = try container.decode(Date.self, forKey: .legacyFireAt)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(mushroomName, forKey: .mushroomName)
            try container.encode(groupName, forKey: .groupName)
            try container.encode(respawnAt, forKey: .respawnAt)
            try container.encode(queuedCount, forKey: .queuedCount)
            try container.encodeIfPresent(nextMushroomName, forKey: .nextMushroomName)
        }
    }
}
