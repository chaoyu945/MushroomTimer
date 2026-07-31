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
        // 倒數的終點是菇重生的時刻 = fireAt + leadSeconds（這裡 leadSeconds 是 15）。
        XCTAssertEqual(state?.respawnAt, now.addingTimeInterval(115))
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

    /// 倒數必須對著菇重生的時刻，不是發通知的時刻。
    ///
    /// 拿發通知的時刻當終點的話，島上歸零之後通知才會到，看起來像通知遲到——
    /// 實際上那正是提前量在發揮作用。使用者在乎的是菇什麼時候重生。
    func testCountdownTargetsRespawnNotTheNotification() {
        let entry = makeEntry(name: "7-11 門口", offset: 300)
        let state = LiveActivityController.state(from: [entry])
        XCTAssertEqual(state?.respawnAt, entry.fireAt.addingTimeInterval(15))
        XCTAssertGreaterThan(
            state!.respawnAt, entry.fireAt,
            "重生時刻一定晚於通知時刻，差距就是提前量"
        )
    }

}
