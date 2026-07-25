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
    func perform() async throws -> some IntentResult & ProvidesDialog {
        #if !WIDGET_EXTENSION
        // 小工具上的按鈕可能停留在已經被刪掉的菇上（payload 還沒更新）。
        // 這時候不能無聲無息——使用者按了卻什麼都沒發生，會以為提醒設好了。
        guard let id = UUID(uuidString: mushroomID) else {
            return .result(dialog: "這顆菇的資料不正確。")
        }
        let context = ModelContainer.shared.mainContext
        guard let mushroom = try IntentSupport.mushroom(id: id, context: context) else {
            return .result(dialog: "找不到「\(mushroomName)」，可能已經被刪除了。")
        }
        let settings = SettingsStore()
        // 這三個 Intent 都是 openAppWhenRun = false，可能從桌面小工具或捷徑
        // 在完全沒有畫面的情況下執行。丟出去的例外在那裡不一定看得到，
        // 所以自己接起來換成對話框——沒排定成功卻讓人以為排好了，是最糟的結果。
        do {
            try await MushroomLogger.log(
                mushroom: mushroom,
                remainingSeconds: 0,
                leadSeconds: settings.defaultLeadSeconds,
                respawnSeconds: settings.respawnSeconds,
                context: context
            )
        } catch {
            return .result(dialog: "沒有建立提醒：\(error.localizedDescription)")
        }
        return .result(dialog: "已登記「\(mushroomName)」。")
        #else
        return .result(dialog: "無法在此執行。")
        #endif
    }
}
