import AppIntents
import Foundation
#if !WIDGET_EXTENSION
import SwiftData
#endif

/// 小工具按鈕觸發的登記 Intent，剩餘時間固定為 0（剛爆）。
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

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        guard let id = UUID(uuidString: mushroomID) else { return .result() }
        let context = ModelContainer.shared.mainContext
        guard let mushroom = try IntentSupport.mushroom(id: id, context: context) else {
            return .result()
        }
        let settings = SettingsStore()
        try await MushroomLogger.log(
            mushroom: mushroom,
            remainingSeconds: 0,
            leadSeconds: settings.defaultLeadSeconds,
            respawnSeconds: settings.respawnSeconds,
            context: context
        )
        #endif
        return .result()
    }
}
