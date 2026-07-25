import CoreLocation
import Foundation

/// 一次性定位與反向地理編碼。
///
/// 只要「使用 App 期間」權限：進入前景時取一次位置就好，不需要背景定位，
/// 也因此不會持續耗電。
@MainActor
final class LocationService: NSObject, ObservableObject {
    static let lastKnownGroupIDKey = "last-known-group-id"

    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var authorizationDenied = false

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// 取得目前位置。不論成功或失敗都會回傳（失敗時為 `nil`），不會卡住呼叫端。
    func updateCurrentLocation() async -> CLLocationCoordinate2D? {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            return nil
        case .denied, .restricted:
            authorizationDenied = true
            return nil
        default:
            break
        }

        if continuation != nil { return coordinate }

        let result = await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
        coordinate = result ?? coordinate
        return coordinate
    }

    /// 用反向地理編碼產生群組的預設名稱。這是全 App 唯一需要網路的功能；
    /// 失敗時退回座標字串，使用者可以自己改。
    func suggestedName(for coordinate: CLLocationCoordinate2D) async -> String {
        let location = CLLocation(
            latitude: coordinate.latitude, longitude: coordinate.longitude
        )
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(
            location, preferredLocale: Locale(identifier: "zh_Hant_TW")
        )
        guard let placemark = placemarks?.first else {
            return String(
                format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude
            )
        }
        let candidates = [
            placemark.name,
            placemark.thoroughfare,
            placemark.subLocality,
            placemark.locality
        ]
        return candidates.compactMap { $0 }.first ?? "新群組"
    }

    private func finish(with coordinate: CLLocationCoordinate2D?) {
        continuation?.resume(returning: coordinate)
        continuation = nil
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        let coordinate = locations.last?.coordinate
        Task { @MainActor in finish(with: coordinate) }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager, didFailWithError error: Error
    ) {
        Task { @MainActor in finish(with: nil) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationDenied = (status == .denied || status == .restricted)
        }
    }
}
