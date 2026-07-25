import CoreLocation
import Foundation

/// 由座標判定所在群組。純函式，不碰定位權限，方便測試。
enum GroupLocator {
    static func distance(
        latitude: Double, longitude: Double, group: MushroomGroup
    ) -> Double {
        CLLocation(latitude: latitude, longitude: longitude).distance(
            from: CLLocation(latitude: group.latitude, longitude: group.longitude)
        )
    }

    /// 距離最近且在該群組自己的 `radius` 內的群組；都不符合時回傳 `nil`。
    static func nearest(
        latitude: Double, longitude: Double, groups: [MushroomGroup]
    ) -> MushroomGroup? {
        groups
            .map { ($0, distance(latitude: latitude, longitude: longitude, group: $0)) }
            .filter { $0.1 <= $0.0.radius }
            .min { $0.1 < $1.1 }?
            .0
    }
}
