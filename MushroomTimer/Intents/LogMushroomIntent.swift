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
    var remainingSeconds: Int?

    init() {}

    init(mushroom: MushroomEntity?, remainingSeconds: Int?) {
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
        let entry = try await MushroomLogger.log(
            mushroom: target,
            remainingSeconds: remainingSeconds ?? 0,
            leadSeconds: settings.defaultLeadSeconds,
            respawnSeconds: settings.respawnSeconds,
            context: context
        )
        return .result(
            dialog: "已登記 \(target.name)，\(DurationInput.clockTime(entry.fireAt)) 提醒你。"
        )
    }
}
