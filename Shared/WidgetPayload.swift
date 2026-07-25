import Foundation

/// 小工具要顯示的精簡資料。
///
/// Widget extension 讀不到主 App 的 SwiftData 資料庫，所以主 App 每次資料異動時
/// 把這份 payload 寫進共享 keychain，小工具只負責讀。
struct WidgetPayload: Codable, Equatable {
    struct Item: Codable, Equatable, Identifiable {
        var id: UUID
        var name: String
    }

    var groupName: String
    var mushrooms: [Item]

    static let empty = WidgetPayload(groupName: "", mushrooms: [])

    /// 小工具版面最多容納 3 顆按鈕。
    static let maxMushrooms = 3

    static func make(groupName: String, mushrooms: [(UUID, String)]) -> WidgetPayload {
        WidgetPayload(
            groupName: groupName,
            mushrooms: mushrooms.prefix(maxMushrooms).map { Item(id: $0.0, name: $0.1) }
        )
    }
}
