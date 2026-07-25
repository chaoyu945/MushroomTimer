import SwiftData
import XCTest
@testable import MushroomTimer

/// 假排程器。這些測試用固定的過去時間當「現在」，而真正的
/// `NotificationService` 是拿真實時鐘算間隔的，會直接判定太近而拒絕。
private final class StubScheduler: NotificationScheduling, @unchecked Sendable {
    var scheduled: [(id: UUID, fireAt: Date)] = []
    var cancelled: [UUID] = []
    var errorToThrow: Error?

    struct Boom: Error {}

    func schedule(id: UUID, groupName: String, mushroomName: String, at date: Date) async throws {
        if let errorToThrow { throw errorToThrow }
        scheduled.append((id, date))
    }

    func cancel(id: UUID) { cancelled.append(id) }
}

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

    /// 延後 1 分鐘：狀態回到 active，fireAt 從「現在」推遲 60 秒，
    /// 而且要真的排一則新的通知，不能只是改資料庫裡的時間。
    func testSnoozeActionReschedulesOneMinuteFromNow() async throws {
        let entry = makeEntry()
        let scheduler = StubScheduler()
        try await NotificationActionHandler.handle(
            actionID: NotificationPolicy.snoozeActionID,
            timerID: entry.id,
            context: context,
            scheduler: scheduler,
            now: now
        )
        XCTAssertEqual(entry.status, .active)
        XCTAssertEqual(entry.fireAt, now.addingTimeInterval(60))
        XCTAssertEqual(scheduler.scheduled.count, 1)
        XCTAssertEqual(scheduler.scheduled.first?.id, entry.id)
        XCTAssertEqual(scheduler.scheduled.first?.fireAt, now.addingTimeInterval(60))
    }

    /// 延後時如果通知排不進去，不可以把狀態改成 active——
    /// 那會留下一筆會倒數卻永遠不會響的計時，而使用者明明按了「延後」。
    func testFailedSnoozeLeavesTheEntryUntouched() async {
        let entry = makeEntry()
        let originalFireAt = entry.fireAt
        let scheduler = StubScheduler()
        scheduler.errorToThrow = StubScheduler.Boom()

        do {
            try await NotificationActionHandler.handle(
                actionID: NotificationPolicy.snoozeActionID,
                timerID: entry.id,
                context: context,
                scheduler: scheduler,
                now: now
            )
            XCTFail("排定失敗時應該把錯誤丟出來")
        } catch {
            // 正確
        }

        XCTAssertEqual(entry.status, .fired)
        XCTAssertEqual(entry.fireAt, originalFireAt)
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
