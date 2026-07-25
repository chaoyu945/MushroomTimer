import SwiftData
import XCTest
@testable import MushroomTimer

@MainActor
final class NotificationActionHandlerTests: XCTestCase {
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

    private func makeEntry(status: TimerStatus = .fired) -> TimerEntry {
        let group = MushroomGroup(name: "中山路口", latitude: 25.05, longitude: 121.52)
        context.insert(group)
        let mushroom = Mushroom(name: "7-11 門口", group: group)
        context.insert(mushroom)
        let entry = TimerEntry(
            mushroom: mushroom,
            createdAt: now,
            remainingSeconds: 0,
            leadSeconds: 15,
            fireAt: now,
            status: status
        )
        context.insert(entry)
        return entry
    }

    func testCompleteActionMarksCompleted() async throws {
        let entry = makeEntry()
        try await NotificationActionHandler.handle(
            actionID: NotificationPolicy.completeActionID,
            timerID: entry.id,
            context: context,
            now: now
        )
        XCTAssertEqual(entry.status, .completed)
    }

    /// 延後 1 分鐘：狀態回到 active，fireAt 從「現在」推遲 60 秒。
    func testSnoozeActionReschedulesOneMinuteFromNow() async throws {
        let entry = makeEntry()
        try await NotificationActionHandler.handle(
            actionID: NotificationPolicy.snoozeActionID,
            timerID: entry.id,
            context: context,
            now: now
        )
        XCTAssertEqual(entry.status, .active)
        XCTAssertEqual(entry.fireAt, now.addingTimeInterval(60))
    }

    func testUnknownTimerIDIsIgnored() async throws {
        try await NotificationActionHandler.handle(
            actionID: NotificationPolicy.completeActionID,
            timerID: UUID(),
            context: context,
            now: now
        )
        XCTAssertEqual(try context.fetch(FetchDescriptor<TimerEntry>()).count, 0)
    }

    func testUnknownActionLeavesStatusUnchanged() async throws {
        let entry = makeEntry(status: .active)
        try await NotificationActionHandler.handle(
            actionID: "something-else",
            timerID: entry.id,
            context: context,
            now: now
        )
        XCTAssertEqual(entry.status, .active)
    }
}
