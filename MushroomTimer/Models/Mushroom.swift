import Foundation
import SwiftData

/// 隸屬於某個群組的一顆菇，例如「7-11 門口」。
@Model
final class Mushroom {
    @Attribute(.unique) var id: UUID
    var name: String
    /// 使用次數，主畫面的菇清單依此由高到低排序。
    var useCount: Int
    var lastUsedAt: Date?
    var group: MushroomGroup?

    init(
        id: UUID = UUID(),
        name: String,
        useCount: Int = 0,
        lastUsedAt: Date? = nil,
        group: MushroomGroup? = nil
    ) {
        self.id = id
        self.name = name
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
        self.group = group
    }
}
