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

    /// payload 有上限，超過的要截掉——keychain 不該被塞進整個菇清單。
    /// 實際顯示幾顆由小工具依尺寸決定（小 3、中 6、大 12），這裡驗的是上限本身。
    func testMakeLimitsToTheMaximum() {
        let names = (1...WidgetPayload.maxMushrooms + 3).map { "菇\($0)" }
        let payload = WidgetPayload.make(
            groupName: "中山路口",
            mushrooms: names.map { (UUID(), $0) }
        )
        XCTAssertEqual(payload.mushrooms.count, WidgetPayload.maxMushrooms)
        XCTAssertEqual(
            payload.mushrooms.map(\.name),
            Array(names.prefix(WidgetPayload.maxMushrooms))
        )
    }
}
