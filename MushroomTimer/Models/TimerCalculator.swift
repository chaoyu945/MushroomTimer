import Foundation

/// 提醒時間的計算。全部以秒（Int）運算，避免浮點誤差。
///
///     fireAt = now + remainingSeconds + respawnSeconds - leadSeconds
enum TimerCalculator {
    /// - Returns: 計算後的提醒時間；若結果不在未來則回傳 `nil`（呼叫端應提示「時間已過」並拒絕建立）。
    static func fireAt(
        now: Date,
        remainingSeconds: Int,
        respawnSeconds: Int,
        leadSeconds: Int
    ) -> Date? {
        let offset = remainingSeconds + respawnSeconds - leadSeconds
        guard offset > 0 else { return nil }
        return now.addingTimeInterval(TimeInterval(offset))
    }
}
