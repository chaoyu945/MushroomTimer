import Foundation

/// 剩餘時間的輸入解析與顯示格式化。
///
/// 使用者只按數字鍵,最後兩位當秒、其餘當分:「230」= 2:30 = 150 秒。
enum DurationInput {
    /// 最多 4 位數,也就是 99:59。
    static let maxDigits = 4

    /// - Returns: 解析後的秒數;輸入含非數字、超長、或秒數 ≥ 60 時回傳 `nil`。
    static func seconds(fromDigits digits: String) -> Int? {
        guard digits.count <= maxDigits else { return nil }
        guard !digits.isEmpty else { return 0 }
        guard digits.allSatisfy(\.isNumber) else { return nil }

        let padded = String(repeating: "0", count: maxDigits - digits.count) + digits
        guard let minutes = Int(padded.prefix(2)),
              let seconds = Int(padded.suffix(2)),
              seconds < 60 else { return nil }
        return minutes * 60 + seconds
    }

    /// 秒數轉成 `分:秒`,秒補零。超過一小時仍以分計(例如 61:01)。
    static func formatted(seconds: Int) -> String {
        let clamped = max(0, seconds)
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }

    /// 時鐘時間,例如 `21:43:20`。用於「7:15 後提醒 · 21:43:20」的後半段。
    static func clockTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
