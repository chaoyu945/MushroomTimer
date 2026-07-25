import SwiftData
import SwiftUI

@main
struct MushroomTimerApp: App {
    private let container: ModelContainer
    @StateObject private var settings = SettingsStore()

    init() {
        do {
            container = try ModelContainer.mushroomTimer()
        } catch {
            fatalError("無法建立資料庫：\(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(settings)
        }
        .modelContainer(container)
    }
}
