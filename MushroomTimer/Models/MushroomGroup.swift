import Foundation
import SwiftData

/// 一個地理區域，例如「中山路口」。
@Model
final class MushroomGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    /// 判定半徑（公尺）。市區 GPS 誤差可達 10～30 公尺，預設放寬到 80。
    var radius: Double
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Mushroom.group)
    var mushrooms: [Mushroom]

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        radius: Double = 80,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.createdAt = createdAt
        self.mushrooms = []
    }
}
