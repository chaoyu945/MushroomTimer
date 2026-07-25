import SwiftData
import SwiftUI

@main
struct MushroomTimerApp: App {
    @StateObject private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(settings)
        }
        .modelContainer(ModelContainer.shared)
    }
}
