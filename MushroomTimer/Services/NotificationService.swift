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

    enum ScheduleError: LocalizedError {
        /// 到期時間太近，`UNTimeIntervalNotificationTrigger` 需要大於 0 秒。
        case tooSoon

        var errorDescription: String? {
            "提醒時間太接近現在，來不及排定通知。"
        }
    }

    /// 排定一則在 `date` 響起的本機通知。
    /// - Parameter id: 用計時的 UUID 當通知識別碼，取消時才找得到它。
    func schedule(id: UUID, groupName: String, mushroomName: String, at date: Date) async throws {
        let intervalSeconds = Int(date.timeIntervalSinceNow.rounded(.down))
        // 這裡一定要丟例外，不可以靜默 return。
        //
        // `TimerCalculator` 允許 offset 只有 1 秒，但從它算出 fireAt 到這行執行之間
        // 必然有時間流逝，所以 `timeIntervalSinceNow` 會是 0.99 之類的值，無條件捨去後
        // 變成 0。若這裡默默返回，`MushroomLogger.log` 會把它當成排定成功，
        // 於是使用者看到倒數與鎖定畫面卡片，但通知從頭到尾不存在——
        // 這正是本 App 最不能出的錯。
        guard intervalSeconds > 0 else { throw ScheduleError.tooSoon }

        let content = UNMutableNotificationContent()
        content.title = NotificationPolicy.title
        content.body = NotificationPolicy.body(groupName: groupName, mushroomName: mushroomName)
        content.sound = .default
        content.interruptionLevel = NotificationPolicy.interruptionLevel
        content.categoryIdentifier = NotificationPolicy.categoryID
        content.userInfo = ["timerID": id.uuidString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(intervalSeconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: id.uuidString, content: content, trigger: trigger
        )
        try await center.add(request)
    }

    /// 註冊通知上的動作按鈕。App 啟動時呼叫一次即可。
    func registerCategories() {
        let complete = UNNotificationAction(
            identifier: NotificationPolicy.completeActionID,
            title: "已完成",
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: NotificationPolicy.snoozeActionID,
            title: "延後 1 分鐘",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: NotificationPolicy.categoryID,
            actions: [complete, snooze],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    func cancel(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }
}
