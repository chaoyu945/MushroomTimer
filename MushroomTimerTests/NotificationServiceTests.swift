import XCTest
@testable import MushroomTimer

/// `NotificationService` 幾乎全是對系統框架的轉呼叫，但有一段自己的判斷邏輯，
/// 而它曾經是靜默失敗的：時間太近時直接 return，讓呼叫端誤以為排定成功。
final class NotificationServiceTests: XCTestCase {
    /// 不足一秒時必須丟例外，不可以靜默當作排定成功——那會留下一筆有倒數、
    /// 有鎖定畫面卡片，卻永遠不會響的計時。
    ///
    /// 這裡刻意用 0.4 秒而不是 1 秒。`TimerCalculator` 允許 offset 只有 1 秒，
    /// 而從它算出 fireAt 到這裡執行之間通常會有時間流逝，捨去後就變成 0；
    /// 但兩次 `Date.now` 也可能讀到同一個值，所以正好 1 秒是會飄的邊界，
    /// 不適合拿來當斷言。
    func testSchedulingLessThanASecondAheadThrows() async {
        do {
            try await NotificationService.shared.schedule(
                id: UUID(),
                groupName: "中山路口",
                mushroomName: "7-11 門口",
                at: Date.now.addingTimeInterval(0.4)
            )
            XCTFail("時間太近時應該丟出 tooSoon，而不是安靜地當作排定成功")
        } catch NotificationService.ScheduleError.tooSoon {
            // 正確
        } catch {
            XCTFail("預期 tooSoon，實際是 \(error)")
        }
    }

    /// 已經過去的時間同樣要拒絕。
    func testSchedulingInThePastThrows() async {
        do {
            try await NotificationService.shared.schedule(
                id: UUID(),
                groupName: "中山路口",
                mushroomName: "天橋下",
                at: Date.now.addingTimeInterval(-60)
            )
            XCTFail("過去的時間應該丟出 tooSoon")
        } catch NotificationService.ScheduleError.tooSoon {
            // 正確
        } catch {
            XCTFail("預期 tooSoon，實際是 \(error)")
        }
    }
}
