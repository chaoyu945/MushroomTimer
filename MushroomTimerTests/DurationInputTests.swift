import XCTest
@testable import MushroomTimer

final class DurationInputTests: XCTestCase {
    func testFourDigitsAreMinutesAndSeconds() {
        XCTAssertEqual(DurationInput.seconds(fromDigits: "1230"), 12 * 60 + 30)
    }

    /// 規格範例:輸入「230」代表 2:30。
    func testThreeDigits() {
        XCTAssertEqual(DurationInput.seconds(fromDigits: "230"), 150)
    }

    func testTwoDigitsAreSecondsOnly() {
        XCTAssertEqual(DurationInput.seconds(fromDigits: "45"), 45)
    }

    func testOneDigitIsSecondsOnly() {
        XCTAssertEqual(DurationInput.seconds(fromDigits: "5"), 5)
    }

    /// 空字串代表使用者還沒輸入,視為 0 秒(等同「剛爆」)。
    func testEmptyIsZero() {
        XCTAssertEqual(DurationInput.seconds(fromDigits: ""), 0)
    }

    /// 秒數部分不可 ≥ 60,例如「270」不是合法的 2:70。
    func testRejectsSecondsAboveFiftyNine() {
        XCTAssertNil(DurationInput.seconds(fromDigits: "270"))
        XCTAssertNil(DurationInput.seconds(fromDigits: "160"))
    }

    func testRejectsNonDigits() {
        XCTAssertNil(DurationInput.seconds(fromDigits: "2:30"))
        XCTAssertNil(DurationInput.seconds(fromDigits: "abc"))
    }

    func testRejectsTooManyDigits() {
        XCTAssertNil(DurationInput.seconds(fromDigits: "12345"))
    }

    func testFormattedPadsSeconds() {
        XCTAssertEqual(DurationInput.formatted(seconds: 435), "7:15")
        XCTAssertEqual(DurationInput.formatted(seconds: 65), "1:05")
        XCTAssertEqual(DurationInput.formatted(seconds: 5), "0:05")
        XCTAssertEqual(DurationInput.formatted(seconds: 0), "0:00")
    }

    func testFormattedHandlesOverAnHour() {
        XCTAssertEqual(DurationInput.formatted(seconds: 3661), "61:01")
    }
}
