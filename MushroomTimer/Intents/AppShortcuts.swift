import AppIntents

/// 開放給 Siri 與捷徑 App 的預設捷徑。
struct MushroomTimerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickLogHereIntent(),
            phrases: [
                "在\(.applicationName)快速登記",
                "用\(.applicationName)登記菇"
            ],
            shortTitle: "快速登記",
            systemImageName: "circle.hexagongrid.fill"
        )
        AppShortcut(
            intent: LogMushroomIntent(),
            phrases: ["用\(.applicationName)登記一顆菇"],
            shortTitle: "登記一顆菇",
            systemImageName: "plus.circle.fill"
        )
    }
}
