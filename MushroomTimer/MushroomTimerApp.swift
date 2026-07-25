import SwiftData
import SwiftUI
import UserNotifications

@main
struct MushroomTimerApp: App {
    @StateObject private var settings = SettingsStore()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationActionHandler.shared
        NotificationService.shared.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(settings)
        }
        .modelContainer(ModelContainer.shared)
    }
}
