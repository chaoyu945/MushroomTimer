import AppIntents
import Foundation

/// 記錄 Intent 是在哪一個 process 執行的。第 0 階段驗證用，Task 19 移除。
enum IntentProcessMarker {
    private static let key = "intent-process-marker"

    static func record(
        processName: String,
        bundleID: String,
        defaults: UserDefaults = .standard
    ) {
        defaults.set("\(processName) / \(bundleID)", forKey: key)
    }

    static func latest(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: key)
    }

    /// 重測前必須先清除。否則上一次成功的紀錄還留著，
    /// 就算這次 Intent 跑錯 process（主 App 根本讀不到它寫的東西），
    /// 畫面上仍會顯示舊的成功結果，變成假通過。
    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}

/// 小工具按鈕觸發的登記 Intent。
///
/// 關鍵：從小工具按鈕觸發的 App Intent **預設在 Widget extension 的 process 執行**，
/// 那個 process 讀不到主 App 的 SwiftData 資料庫。遵循 `LiveActivityIntent` 之後，
/// 系統會改在主 App 的 process 背景執行（不會開啟 App 畫面）。
struct QuickLogIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "快速登記"
    static var description = IntentDescription("以「剛爆」登記指定的菇。")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "菇 ID")
    var mushroomID: String

    @Parameter(title: "菇名稱")
    var mushroomName: String

    init() {}

    init(mushroomID: String, mushroomName: String) {
        self.mushroomID = mushroomID
        self.mushroomName = mushroomName
    }

    func perform() async throws -> some IntentResult {
        IntentProcessMarker.record(
            processName: ProcessInfo.processInfo.processName,
            bundleID: Bundle.main.bundleIdentifier ?? "unknown"
        )
        return .result()
    }
}
