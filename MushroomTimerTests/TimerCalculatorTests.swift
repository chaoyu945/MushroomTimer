import XCTest
@testable import MushroomTimer

final class TimerCalculatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    /// 規格範例：剩 2:30、重生 5:00、提前 15 秒 → 435 秒後提醒。
    func testSpecExample() {
        let fireAt = TimerCalculator.fireAt(
            now: now, remainingSeconds: 150, respawnSeconds: 300, leadSeconds: 15
        )
        XCTAssertEqual(fireAt, now.addingTimeInterval(435))
    }

    /// 剩餘時間 0 代表「剛爆」，是合法輸入。
    func testJustPoppedIsAllowed() {
        let fireAt = TimerCalculator.fireAt(
            now: now, remainingSeconds: 0, respawnSeconds: 300, leadSeconds: 15
        )
        XCTAssertEqual(fireAt, now.addingTimeInterval(285))
    }

    /// 提前量大於等於總時間 → 時間已過，不可建立計時。
    func testReturnsNilWhenResultIsNotInTheFuture() {
        XCTAssertNil(TimerCalculator.fireAt(
            now: now, remainingSeconds: 0, respawnSeconds: 300, leadSeconds: 300
        ))
        XCTAssertNil(TimerCalculator.fireAt(
            now: now, remainingSeconds: 0, respawnSeconds: 300, leadSeconds: 400
        ))
    }

    /// 剛好剩 1 秒仍算未來，可以建立。
    func testOneSecondInFutureIsAllowed() {
        let fireAt = TimerCalculator.fireAt(
            now: now, remainingSeconds: 0, respawnSeconds: 300, leadSeconds: 299
        )
        XCTAssertEqual(fireAt, now.addingTimeInterval(1))
    }

    /// 提前量為 0（使用者調到最低）也要正常運作。
    func testZeroLead() {
        let fireAt = TimerCalculator.fireAt(
            now: now, remainingSeconds: 60, respawnSeconds: 300, leadSeconds: 0
        )
        XCTAssertEqual(fireAt, now.addingTimeInterval(360))
    }
}
