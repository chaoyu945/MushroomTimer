import XCTest
@testable import MushroomTimer

final class TimeInputModelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testAppendBuildsDigits() {
        let model = TimeInputModel(leadSeconds: 15)
        model.append("2")
        model.append("3")
        model.append("0")
        XCTAssertEqual(model.digits, "230")
        XCTAssertEqual(model.remainingSeconds, 150)
    }

    func testAppendStopsAtMaxDigits() {
        let model = TimeInputModel(leadSeconds: 15)
        for digit in ["1", "2", "3", "4", "5"] {
            model.append(digit)
        }
        XCTAssertEqual(model.digits, "1234")
    }

    func testDeleteLast() {
        let model = TimeInputModel(leadSeconds: 15)
        model.append("2")
        model.append("3")
        model.deleteLast()
        XCTAssertEqual(model.digits, "2")
        model.deleteLast()
        model.deleteLast()
        XCTAssertEqual(model.digits, "")
    }

    func testJustPoppedClearsToZero() {
        let model = TimeInputModel(leadSeconds: 15)
        model.append("2")
        model.append("3")
        model.append("0")
        model.justPopped()
        XCTAssertEqual(model.digits, "")
        XCTAssertEqual(model.remainingSeconds, 0)
    }

    func testAdjustLeadStaysInRange() {
        let model = TimeInputModel(leadSeconds: 15)
        model.adjustLead(by: 5)
        XCTAssertEqual(model.leadSeconds, 20)
        model.adjustLead(by: -25)
        XCTAssertEqual(model.leadSeconds, 0)
        model.adjustLead(by: -5)
        XCTAssertEqual(model.leadSeconds, 0)
    }

    /// 規格範例：剩 2:30、重生 5:00、提前 15 秒 → 「7:15 後提醒 · 21:43:20」。
    func testPreviewShowsOffsetAndClockTime() {
        let model = TimeInputModel(leadSeconds: 15)
        model.append("2")
        model.append("3")
        model.append("0")
        let preview = model.preview(now: now, respawnSeconds: 300)
        XCTAssertTrue(preview.hasPrefix("7:15 後提醒 · "), "實際：\(preview)")
    }

    func testPreviewReportsInvalidInput() {
        let model = TimeInputModel(leadSeconds: 15)
        model.append("2")
        model.append("7")
        model.append("0")
        XCTAssertEqual(model.preview(now: now, respawnSeconds: 300), "輸入不正確")
    }

    func testPreviewReportsTimeAlreadyPassed() {
        let model = TimeInputModel(leadSeconds: 300)
        XCTAssertEqual(model.preview(now: now, respawnSeconds: 300), "時間已過")
    }
}
