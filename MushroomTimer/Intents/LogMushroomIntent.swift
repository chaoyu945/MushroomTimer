import AppIntents
import Foundation
import SwiftData

/// 登記一顆菇。兩個參數都可以在捷徑 App 裡預先綁定，
/// 綁定之後就是「一個 tap 完成登記，App 完全不用開啟」。
struct LogMushroomIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "登記一顆菇"
    static var description = IntentDescription("為指定的菇建立重生提醒。")
    /// 不開啟 App 畫面，在主 App 的 process 背景執行。
    static var openAppWhenRun: Bool = false

    @Parameter(title: "菇")
    var mushroom: MushroomEntity?

    @Parameter(title: "剩餘秒數", default: 0, inclusiveRange: (0, 5999))
    var remainingSeconds: Int

    /// 沒有這個摘要，捷徑編輯器只會用預設版面，剩餘秒數那個參數
    /// 根本不會出現在畫面上——使用者能選菇卻不能選時間。
    /// 兩個參數都列出來之後，才能各自預先綁定成
    /// 「7-11 門口 · 剛爆」「7-11 門口 · 2:30」這種一點即完成的桌面捷徑。
    static var parameterSummary: some ParameterSummary {
        Summary("登記 \(\.$mushroom)，剩餘 \(\.$remainingSeconds) 秒")
    }

    init() {}

    init(mushroom: MushroomEntity?, remainingSeconds: Int) {
        self.mushroom = mushroom
        self.remainingSeconds = remainingSeconds
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let entity = try await $mushroom.requestValue("要登記哪一顆菇？")
        let context = ModelContainer.shared.mainContext
        guard let target = try IntentSupport.mushroom(id: entity.id, context: context) else {
            return .result(dialog: "找不到這顆菇，可能已經被刪除了。")
        }

        let settings = SettingsStore()
        // 這三個 Intent 都是 openAppWhenRun = false，可能從桌面小工具或捷徑
        // 在完全沒有畫面的情況下執行。丟出去的例外在那裡不一定看得到，
        // 所以自己接起來換成對話框——沒排定成功卻讓人以為排好了，是最糟的結果。
        do {
            let entry = try await MushroomLogger.log(
                mushroom: target,
                remainingSeconds: remainingSeconds,
                leadSeconds: settings.defaultLeadSeconds,
                respawnSeconds: settings.respawnSeconds,
                context: context
            )
            return .result(
                dialog: "已登記 \(target.name)，\(DurationInput.clockTime(entry.fireAt)) 提醒你。"
            )
        } catch {
            return .result(dialog: "沒有建立提醒：\(error.localizedDescription)")
        }
    }
}
