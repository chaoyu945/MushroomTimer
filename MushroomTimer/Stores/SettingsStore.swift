import Foundation

/// 全域設定。存 UserDefaults 即可,資料量小且不需要跟資料庫一起查詢。
final class SettingsStore: ObservableObject {
    static let respawnRange = 30...3600
    static let leadRange = 0...300

    private enum Key {
        static let respawn = "respawnSeconds"
        static let lead = "defaultLeadSeconds"
    }

    private let defaults: UserDefaults

    /// 菇的重生時間。做成可調整,以防官方調整數值。
    @Published var respawnSeconds: Int {
        didSet {
            let clamped = Self.respawnRange.clamping(respawnSeconds)
            if clamped != respawnSeconds {
                respawnSeconds = clamped
                return
            }
            defaults.set(respawnSeconds, forKey: Key.respawn)
        }
    }

    /// 預設提前量。建立計時時會把當下的值快照進 `TimerEntry.leadSeconds`。
    @Published var defaultLeadSeconds: Int {
        didSet {
            let clamped = Self.leadRange.clamping(defaultLeadSeconds)
            if clamped != defaultLeadSeconds {
                defaultLeadSeconds = clamped
                return
            }
            defaults.set(defaultLeadSeconds, forKey: Key.lead)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedRespawn = defaults.object(forKey: Key.respawn) as? Int
        let storedLead = defaults.object(forKey: Key.lead) as? Int
        self.respawnSeconds = Self.respawnRange.clamping(storedRespawn ?? 300)
        self.defaultLeadSeconds = Self.leadRange.clamping(storedLead ?? 15)
    }
}

extension ClosedRange where Bound == Int {
    /// 把值夾在範圍內。
    func clamping(_ value: Int) -> Int {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
