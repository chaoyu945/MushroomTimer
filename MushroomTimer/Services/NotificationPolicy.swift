import Foundation
import UserNotifications

/// 通知的文案與中斷等級。中斷等級集中在這裡，方便依實機驗證結果一次切換。
enum NotificationPolicy {
    /// 2026-07-25 實機驗證結果：免費的 Personal Team **不支援** Time Sensitive
    /// Notifications capability，帶著該 entitlement 連 provisioning profile 都建不出來
    /// （Xcode：「Personal development teams … do not support the Time Sensitive
    /// Notifications capability」）。因此改用 `.active`，並在設定頁引導使用者手動把
    /// 本 App 加進「專注模式」的允許清單——效果相同，且不需要任何 entitlement。
    ///
    /// 若日後改用付費開發者帳號，把這裡換回 `.timeSensitive` 並把
    /// `com.apple.developer.usernotifications.time-sensitive` 加回 project.yml 即可。
    static let interruptionLevel: UNNotificationInterruptionLevel = .active

    static let title = "菇要重生了"

    static let categoryID = "mushroom-respawn"
    static let completeActionID = "complete"
    static let snoozeActionID = "snooze"
    /// 「延後 1 分鐘」的秒數。
    static let snoozeSeconds = 60

    static func body(groupName: String, mushroomName: String) -> String {
        "【\(groupName)】\(mushroomName) 的菇要重生了"
    }
}
