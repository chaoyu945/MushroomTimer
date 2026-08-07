import XCTest
@testable import MushroomTimer

final class MushroomActivityAttributesTests: XCTestCase {
    private func state(queued: Int) -> MushroomActivityAttributes.ContentState {
        MushroomActivityAttributes.ContentState(
            mushroomName: "7-11 門口",
            groupName: "中山路口",
            respawnAt: Date(timeIntervalSince1970: 1_000_000),
            queuedCount: queued,
            nextMushroomName: nil
        )
    }

    func testNoQueueLabelWhenNothingIsWaiting() {
        XCTAssertNil(state(queued: 0).queueLabel)
    }

    func testQueueLabelShowsPlusCount() {
        XCTAssertEqual(state(queued: 2).queueLabel, "+2")
    }

    /// ContentState 會被序列化送到 Widget process，必須是 Codable 且能完整還原。
    func testContentStateRoundTripsThroughJSON() throws {
        let original = state(queued: 3)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            MushroomActivityAttributes.ContentState.self, from: data
        )
        XCTAssertEqual(decoded, original)
    }

    /// 舊版把這個欄位叫 `fireAt`。ActivityKit 會持久化 ContentState，
    /// 所以 App 更新時可能有進行中的活動仍是舊格式——解不開的話卡片會變空白，
    /// 而通知照常運作，看起來像 Live Activity 無故壞掉。
    func testDecodesLegacyFireAtKey() throws {
        let json = """
        {
          "mushroomName": "7-11 門口",
          "groupName": "竹北家",
          "fireAt": 1000000,
          "queuedCount": 2
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(
            MushroomActivityAttributes.ContentState.self, from: json
        )
        XCTAssertEqual(state.mushroomName, "7-11 門口")
        XCTAssertEqual(state.respawnAt, Date(timeIntervalSinceReferenceDate: 1_000_000))
        XCTAssertEqual(state.queuedCount, 2)
        XCTAssertNil(state.nextMushroomName)
    }

    /// 新格式當然也要能來回。
    func testRoundTripsCurrentFormat() throws {
        let original = MushroomActivityAttributes.ContentState(
            mushroomName: "天橋下",
            groupName: "竹北家",
            respawnAt: Date(timeIntervalSince1970: 1_700_000_000),
            queuedCount: 1,
            nextMushroomName: "7-11 門口"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            MushroomActivityAttributes.ContentState.self, from: data
        )
        XCTAssertEqual(decoded, original)
    }

}
