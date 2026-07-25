import SwiftData
import XCTest
@testable import MushroomTimer

@MainActor
final class TimerQueriesTests: XCTestCase {
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

    private func makeGroup() -> MushroomGroup {
        let group = MushroomGroup(name: "中山路口", latitude: 25.05, longitude: 121.52)
        context.insert(group)
        return group
    }

    @discardableResult
    private func makeEntry(offset: TimeInterval, status: TimerStatus = .active) -> TimerEntry {
        let mushroom = Mushroom(name: "菇\(offset)", group: makeGroup())
        context.insert(mushroom)
        let entry = TimerEntry(
            mushroom: mushroom,
            createdAt: now,
            remainingSeconds: 0,
            leadSeconds: 15,
            fireAt: now.addingTimeInterval(offset),
            status: status
        )
        context.insert(entry)
        return entry
    }

    func testActiveIsSortedByFireAtAscending() throws {
        makeEntry(offset: 300)
        makeEntry(offset: 100)
        makeEntry(offset: 200)
        try context.save()

        let fireAts = try TimerQueries.active(in: context).map(\.fireAt)
        XCTAssertEqual(fireAts, [
            now.addingTimeInterval(100),
            now.addingTimeInterval(200),
            now.addingTimeInterval(300)
        ])
    }

    func testActiveExcludesNonActiveStatuses() throws {
        makeEntry(offset: 100)
        makeEntry(offset: 200, status: .cancelled)
        makeEntry(offset: 300, status: .completed)
        makeEntry(offset: 400, status: .fired)
        try context.save()

        XCTAssertEqual(try TimerQueries.active(in: context).count, 1)
    }

    /// 本機通知不會喚醒 App，所以到期的計時是在下次開 App 時才標記。
    func testMarkFiredFlipsExpiredActiveEntries() throws {
        makeEntry(offset: -10)
        makeEntry(offset: 100)
        try context.save()

        try TimerQueries.markFired(in: context, now: now)

        let all = try context.fetch(FetchDescriptor<TimerEntry>())
        XCTAssertEqual(all.filter { $0.status == .fired }.count, 1)
        XCTAssertEqual(all.filter { $0.status == .active }.count, 1)
    }

    func testMostUsedSortsByUseCountDescending() {
        let group = makeGroup()
        let a = Mushroom(name: "少", useCount: 1, group: group)
        let b = Mushroom(name: "多", useCount: 9, group: group)
        let c = Mushroom(name: "中", useCount: 5, group: group)
        [a, b, c].forEach(context.insert)
        group.mushrooms = [a, b, c]

        XCTAssertEqual(
            TimerQueries.mostUsed(in: group, limit: 2).map(\.name),
            ["多", "中"]
        )
    }
}
