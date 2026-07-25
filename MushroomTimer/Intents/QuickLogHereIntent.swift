import AppIntents
import Foundation
import SwiftData

/// 用目前群組中最常用的那顆菇建立計時。不需要指定菇，也不會觸發 GPS。
struct QuickLogHereIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "在這裡快速登記"
    static var description = IntentDescription("用目前群組中最常用的菇建立重生提醒。")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "剩餘秒數", default: 0, inclusiveRange: (0, 5999))
    var remainingSeconds: Int

    init() {}

    init(remainingSeconds: Int) {
        self.remainingSeconds = remainingSeconds
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContainer.shared.mainContext
        guard let target = try IntentSupport.preferredMushroom(context: context) else {
            return .result(dialog: "還沒有建立任何菇，請先開啟打菇茜新增。")
        }

        let settings = SettingsStore()
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
    }
}
