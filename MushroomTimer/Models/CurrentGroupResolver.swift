import Foundation

/// 一次定位判定的結果。
///
/// 「還沒問到」與「問到了，你不在任何群組裡」必須分開表示。
/// 把兩者混成同一個 `nil`，就會分不出該顯示舊群組還是該請使用者建立新群組。
enum GPSResolution: Equatable {
    /// 還沒有結果：權限尚未回答、剛啟動、或定位失敗。
    case pending
    /// 判定落在某個群組範圍內。
    case matched(UUID)
    /// 判定完成，但不在任何已知群組的半徑內。
    case outsideAllGroups
}

/// 決定主畫面要顯示哪一個群組。
///
/// 抽成純函式是因為這條規則曾經出錯：原本在找不到 GPS 結果時一律退回
/// 「最近建立的群組」，於是 `currentGroup` 永遠不是 nil——走到新地點時畫面
/// 賴在舊群組不動，而「建立新群組」按鈕（顯示條件是沒有目前群組）
/// 在建立第一個群組之後就再也不會出現。
enum CurrentGroupResolver {
    static func resolve(
        manualSelection: UUID?,
        gps: GPSResolution,
        groups: [MushroomGroup]
    ) -> MushroomGroup? {
        // 手動選擇優先：市區 GPS 誤差可達 10–30 公尺，自動判定不一定準。
        if let manualSelection,
           let match = groups.first(where: { $0.id == manualSelection }) {
            return match
        }
        switch gps {
        case .matched(let id):
            return groups.first(where: { $0.id == id })
        case .outsideAllGroups:
            // 這是有意義的答案，不可以用任何 fallback 蓋掉。
            return nil
        case .pending:
            // 只有在完全沒有答案時，才退回最近建立的群組，
            // 免得剛開 App 的那一瞬間畫面是空的。
            return groups.first
        }
    }
}
