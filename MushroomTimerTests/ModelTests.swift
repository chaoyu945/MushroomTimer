import SwiftData
import XCTest
@testable import MushroomTimer

@MainActor
final class ModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer.mushroomTimer(inMemory: true)
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    func testGroupDefaultsToEightyMetreRadius() {
        let group = MushroomGroup(name: "中山路口", latitude: 25.05, longitude: 121.52)
        XCTAssertEqual(group.radius, 80)
        XCTAssertTrue(group.mushrooms.isEmpty)
    }

    func testMushroomBelongsToGroup() throws {
        let group = MushroomGroup(name: "中山路口", latitude: 25.05, longitude: 121.52)
        context.insert(group)
        let mushroom = Mushroom(name: "7-11 門口", group: group)
        context.insert(mushroom)
        try context.save()

        let groups = try context.fetch(FetchDescriptor<MushroomGroup>())
        XCTAssertEqual(groups.first?.mushrooms.map(\.name), ["7-11 門口"])
        XCTAssertEqual(mushroom.useCount, 0)
        XCTAssertNil(mushroom.lastUsedAt)
    }

    /// 刪除群組要一併刪掉底下的菇（cascade）。
    func testDeletingGroupCascadesToMushrooms() throws {
        let group = MushroomGroup(name: "中山路口", latitude: 25.05, longitude: 121.52)
        context.insert(group)
        context.insert(Mushroom(name: "7-11 門口", group: group))
        context.insert(Mushroom(name: "天橋下", group: group))
        try context.save()

        context.delete(group)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Mushroom>()).count, 0)
    }

    func testTimerEntryStatusRoundTrips() throws {
        let group = MushroomGroup(name: "中山路口", latitude: 25.05, longitude: 121.52)
        context.insert(group)
        let mushroom = Mushroom(name: "7-11 門口", group: group)
        context.insert(mushroom)
        let entry = TimerEntry(
            mushroom: mushroom,
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            remainingSeconds: 150,
            leadSeconds: 15,
            fireAt: Date(timeIntervalSince1970: 1_000_435)
        )
        context.insert(entry)
        try context.save()

        XCTAssertEqual(entry.status, .active)
        entry.status = .completed
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<TimerEntry>())
        XCTAssertEqual(fetched.first?.status, .completed)
        XCTAssertEqual(fetched.first?.statusRaw, "completed")
    }

    /// leadSeconds 是快照：之後改全域設定不應影響已建立的計時。
    func testLeadSecondsIsStoredPerEntry() {
        let group = MushroomGroup(name: "中山路口", latitude: 25.05, longitude: 121.52)
        let mushroom = Mushroom(name: "7-11 門口", group: group)
        let entry = TimerEntry(
            mushroom: mushroom,
            createdAt: .now,
            remainingSeconds: 0,
            leadSeconds: 42,
            fireAt: .now.addingTimeInterval(258)
        )
        XCTAssertEqual(entry.leadSeconds, 42)
    }
}
