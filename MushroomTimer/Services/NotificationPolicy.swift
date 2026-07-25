import Foundation
import UserNotifications

/// 通知的文案與中斷等級。中斷等級集中在這裡，方便依實機驗證結果一次切換。
enum NotificationPolicy {
    /// `.timeSensitive` 可穿透「專注模式」，但需要 entitlement。
    /// 若實機驗證免費帳號無法簽署，改成 `.active`，並在設定頁引導使用者
    /// 手動把本 App 加入專注模式的允許清單（效果相同，不需 entitlement）。
    static let interruptionLevel: UNNotificationInterruptionLevel = .timeSensitive

    static let title = "菇要重生了"

    static func body(groupName: String, mushroomName: String) -> String {
        "【\(groupName)】\(mushroomName) 的菇要重生了"
    }
}
