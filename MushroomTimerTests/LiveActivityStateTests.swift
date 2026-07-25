import SwiftData
import XCTest
@testable import MushroomTimer

@MainActor
final class LiveActivityStateTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private let now = Date(timeIntervalSince1970: 1_000_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer.mushroomTimer(inMemory: true)
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    private func makeEntry(name: String, offset: TimeInterval) -> TimerEntry {
        let group = MushroomGroup(name: "中山路口", latitude: 25.05, longitude: 121.52)
        context.insert(group)
        let mushroom = Mushroom(name: name, group: group)
        context.insert(mushroom)
        let entry = TimerEntry(
            mushroom: mushroom,
            createdAt: now,
            remainingSeconds: 0,
            leadSeconds: 15,
            fireAt: now.addingTimeInterval(offset)
        )
        context.insert(entry)
        return entry
    }

    func testNilWhenNothingIsActive() {
        XCTAssertNil(LiveActivityController.state(from: []))
    }

    /// 只顯示最快到期的那一筆，其餘算進排隊筆數。
    func testUsesSoonestEntryAndCountsTheRest() {
        let soonest = makeEntry(name: "最快", offset: 100)
        let second = makeEntry(name: "第二", offset: 200)
        let third = makeEntry(name: "第三", offset: 300)

        let state = LiveActivityController.state(from: [soonest, second, third])
        XCTAssertEqual(state?.mushroomName, "最快")
        XCTAssertEqual(state?.groupName, "中山路口")
        XCTAssertEqual(state?.fireAt, now.addingTimeInterval(100))
        XCTAssertEqual(state?.queuedCount, 2)
        XCTAssertEqual(state?.queueLabel, "+2")
        XCTAssertEqual(state?.nextMushroomName, "第二")
    }

    func testSingleEntryHasNoQueue() {
        let only = makeEntry(name: "唯一", offset: 100)
        let state = LiveActivityController.state(from: [only])
        XCTAssertEqual(state?.queuedCount, 0)
        XCTAssertNil(state?.queueLabel)
        XCTAssertNil(state?.nextMushroomName)
    }
}
