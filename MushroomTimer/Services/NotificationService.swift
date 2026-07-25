import Foundation
import UserNotifications

/// 讓 `MushroomLogger` 可以在測試中換掉真正的通知中心。
/// 沒有這層，排定失敗的路徑就完全測不到——而那正是最需要測的一條。
protocol NotificationScheduling {
    func schedule(id: UUID, groupName: String, mushroomName: String, at date: Date) async throws
    func cancel(id: UUID)
}

/// 本機通知的排定與取消。不需要伺服器，也不需要遠端推播 entitlement。
final class NotificationService: NotificationScheduling {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    /// 向使用者要求通知權限。首次呼叫會跳出系統對話框。
    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// 排定一則在 `date` 響起的本機通知。
    /// - Parameter id: 用計時的 UUID 當通知識別碼，取消時才找得到它。
    func schedule(id: UUID, groupName: String, mushroomName: String, at date: Date) async throws {
        let intervalSeconds = Int(date.timeIntervalSinceNow.rounded(.down))
        guard intervalSeconds > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = NotificationPolicy.title
        content.body = NotificationPolicy.body(groupName: groupName, mushroomName: mushroomName)
        content.sound = .default
        content.interruptionLevel = NotificationPolicy.interruptionLevel

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(intervalSeconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: id.uuidString, content: content, trigger: trigger
        )
        try await center.add(request)
    }

    func cancel(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }
}
