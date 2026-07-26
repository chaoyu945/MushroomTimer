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

    /// payload 帶得動的上限。實際顯示幾顆由小工具依尺寸自己決定
    /// （小 3、中 6、大 12），所以這裡取最大的那個。
    static let maxMushrooms = 12

    static func make(groupName: String, mushrooms: [(UUID, String)]) -> WidgetPayload {
        WidgetPayload(
            groupName: groupName,
            mushrooms: mushrooms.prefix(maxMushrooms).map { Item(id: $0.0, name: $0.1) }
        )
    }
}
