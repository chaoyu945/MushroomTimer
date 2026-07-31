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
}
