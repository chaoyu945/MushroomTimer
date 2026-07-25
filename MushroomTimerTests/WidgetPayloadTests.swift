import XCTest
@testable import MushroomTimer

final class WidgetPayloadTests: XCTestCase {
    /// payload 會經過 JSON 存進 keychain 再被 widget 讀出，必須能完整還原。
    func testRoundTripsThroughJSON() throws {
        let original = WidgetPayload(
            groupName: "中山路口",
            mushrooms: [
                .init(id: UUID(), name: "7-11 門口"),
                .init(id: UUID(), name: "天橋下")
            ]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetPayload.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testEmptyPayloadHasNoMushrooms() {
        XCTAssertTrue(WidgetPayload.empty.mushrooms.isEmpty)
    }

    /// 小工具最多放 3 顆按鈕，超過的要截掉。
    func testMakeLimitsToThreeMushrooms() {
        let payload = WidgetPayload.make(
            groupName: "中山路口",
            mushrooms: [
                (UUID(), "一"), (UUID(), "二"), (UUID(), "三"), (UUID(), "四")
            ]
        )
        XCTAssertEqual(payload.mushrooms.map(\.name), ["一", "二", "三"])
    }
}
