import Foundation
import OSLog
import SwiftData
import UserNotifications

private let logger = Logger(
    subsystem: "com.chaoyu.MushroomTimer", category: "NotificationAction"
)

/// 處理通知上的動作按鈕。
///
/// 按下動作時系統會喚醒 App（即使原本沒在執行），所以這裡可以安全地
/// 寫資料庫、重排通知、更新 Live Activity。
final class NotificationActionHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationActionHandler()

    private override init() { super.init() }

    /// 實際的處理邏輯。抽成靜態方法才能不經過 UserNotifications 框架就測到。
    @MainActor
    static func handle(
        actionID: String,
        timerID: UUID,
        context: ModelContext,
        scheduler: NotificationScheduling = NotificationService.shared,
        now: Date = .now
    ) async throws {
        var descriptor = FetchDescriptor<TimerEntry>(
            predicate: #Predicate { $0.id == timerID }
        )
        descriptor.fetchLimit = 1
        guard let entry = try context.fetch(descriptor).first else { return }

        switch actionID {
        case NotificationPolicy.completeActionID:
            try await MushroomLogger.complete(entry, context: context)

        case NotificationPolicy.snoozeActionID:
            let snoozedTo = now.addingTimeInterval(TimeInterval(NotificationPolicy.snoozeSeconds))
            // 先排通知，成功了才改資料——理由同 `MushroomLogger.log`。
            // 延後失敗卻把狀態改成 active，會留下一筆會倒數但永遠不會響的計時，
            // 而使用者明明按了「延後 1 分鐘」，最可能就這樣錯過。
            try await scheduler.schedule(
                id: entry.id,
                groupName: entry.mushroom?.group?.name ?? "",
                mushroomName: entry.mushroom?.name ?? "",
                at: snoozedTo
            )
            entry.fireAt = snoozedTo
            entry.status = .active
            try context.save()
            // 一定要把同一個 now 傳下去，否則回收會用真實時間把這筆剛延後的
            // 計時當成早就過期而標記成 fired。
            await LiveActivityController.refresh(context: context, now: now)

        default:
            break
        }
    }

    // ⚠️ 這兩個 delegate 方法**必須**標 `@MainActor`。
    //
    // `UNUserNotificationCenterDelegate` 的 async 版本沒有 actor 隔離，
    // 預設跑在 global concurrent executor 上——也就是非主執行緒。
    // 但 UserNotifications 要求這些回呼在主執行緒完成，否則會丟出
    // `NSInternalInconsistencyException: "Call must be made on main thread"`，
    // App 當場卡住或崩潰，而通知本身照常送達，看起來像「收到通知就壞掉」。
    //
    // 內部呼叫已經自己 hop 回 MainActor 了，但那不夠：出問題的是**方法回傳**
    // 給框架的那一刻所在的執行緒，尤其是 `willPresent` 還要回傳顯示選項。
    @MainActor
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let raw = userInfo["timerID"] as? String,
              let timerID = UUID(uuidString: raw) else { return }
        // 這個 method 是 async 的，系統會等它回來才讓 App 重新休眠。
        // 只丟一個 Task 就返回等於謊報「做完了」，實際工作可能還沒跑完就被切掉。
        await Self.handleOnMainActor(
            actionID: response.actionIdentifier, timerID: timerID
        )
    }

    @MainActor
    private static func handleOnMainActor(actionID: String, timerID: UUID) async {
        do {
            try await handle(
                actionID: actionID,
                timerID: timerID,
                context: ModelContainer.shared.mainContext
            )
        } catch {
            logger.error(
                "通知動作處理失敗：\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// App 在前景時也要看得到通知，否則使用者會以為沒響。
    @MainActor
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
