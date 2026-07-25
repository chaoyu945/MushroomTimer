import SwiftData
import XCTest
@testable import MushroomTimer

/// 可控制的假排程器。記下收到什麼，也能被要求失敗。
private final class StubScheduler: NotificationScheduling, @unchecked Sendable {
    var scheduled: [(id: UUID, fireAt: Date)] = []
    var cancelled: [UUID] = []
    var errorToThrow: Error?

    struct Boom: Error {}

    func schedule(id: UUID, groupName: String, mushroomName: String, at date: Date) async throws {
        if let errorToThrow { throw errorToThrow }
        scheduled.append((id, date))
    }

    func cancel(id: UUID) {
        cancelled.append(id)
    }
}

@MainActor
final class MushroomLoggerTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private var scheduler: StubScheduler!
    private let now = Date(timeIntervalSince1970: 1_000_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer.mushroomTimer(inMemory: true)
        scheduler = StubScheduler()
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    private func makeMushroom() -> Mushroom {
        let group = MushroomGroup(name: "中山路口", latitude: 25.05, longitude: 121.52)
        context.insert(group)
        let mushroom = Mushroom(name: "7-11 門口", group: group)
        context.insert(mushroom)
        return mushroom
    }

    func testLogCreatesEntryWithCalculatedFireAt() async throws {
        let mushroom = makeMushroom()
        let entry = try await MushroomLogger.log(
            mushroom: mushroom,
            remainingSeconds: 150,
            leadSeconds: 15,
            respawnSeconds: 300,
            context: context,
            scheduler: scheduler,
            now: now
        )

        XCTAssertEqual(entry.fireAt, now.addingTimeInterval(435))
        XCTAssertEqual(entry.leadSeconds, 15)
        XCTAssertEqual(entry.remainingSeconds, 150)
        XCTAssertEqual(entry.status, .active)
        XCTAssertEqual(entry.mushroom?.id, mushroom.id)
    }

    func testLogBumpsUseCountAndLastUsedAt() async throws {
        let mushroom = makeMushroom()
        _ = try await MushroomLogger.log(
            mushroom: mushroom, remainingSeconds: 0, leadSeconds: 15,
            respawnSeconds: 300, context: context, scheduler: scheduler, now: now
        )
        _ = try await MushroomLogger.log(
            mushroom: mushroom, remainingSeconds: 0, leadSeconds: 15,
            respawnSeconds: 300, context: context, scheduler: scheduler, now: now
        )

        XCTAssertEqual(mushroom.useCount, 2)
        XCTAssertEqual(mushroom.lastUsedAt, now)
    }

    func testLogThrowsWhenResultIsInThePast() async {
        let mushroom = makeMushroom()
        do {
            _ = try await MushroomLogger.log(
                mushroom: mushroom, remainingSeconds: 0, leadSeconds: 400,
                respawnSeconds: 300, context: context, scheduler: scheduler, now: now
            )
            XCTFail("應該要丟出 timeAlreadyPassed")
        } catch MushroomLogger.LogError.timeAlreadyPassed {
            // 正確
        } catch {
            XCTFail("丟出非預期的錯誤：\(error)")
        }
    }

    func testFailedLogDoesNotCreateEntryOrBumpUseCount() async throws {
        let mushroom = makeMushroom()
        _ = try? await MushroomLogger.log(
            mushroom: mushroom, remainingSeconds: 0, leadSeconds: 400,
            respawnSeconds: 300, context: context, scheduler: scheduler, now: now
        )
        XCTAssertEqual(try context.fetch(FetchDescriptor<TimerEntry>()).count, 0)
        XCTAssertEqual(mushroom.useCount, 0)
    }

    func testCancelMarksEntryCancelled() async throws {
        let mushroom = makeMushroom()
        let entry = try await MushroomLogger.log(
            mushroom: mushroom, remainingSeconds: 0, leadSeconds: 15,
            respawnSeconds: 300, context: context, scheduler: scheduler, now: now
        )
        try MushroomLogger.cancel(entry, context: context)
        XCTAssertEqual(entry.status, .cancelled)
        XCTAssertEqual(try TimerQueries.active(in: context).count, 0)
    }

    func testCompleteMarksEntryCompleted() async throws {
        let mushroom = makeMushroom()
        let entry = try await MushroomLogger.log(
            mushroom: mushroom, remainingSeconds: 0, leadSeconds: 15,
            respawnSeconds: 300, context: context, scheduler: scheduler, now: now
        )
        try MushroomLogger.complete(entry, context: context)
        XCTAssertEqual(entry.status, .completed)
    }

    /// 排定成功時，通知的 id 與時間必須跟建立出來的那筆計時一致。
    func testLogSchedulesNotificationForTheEntry() async throws {
        let mushroom = makeMushroom()
        let scheduler = StubScheduler()
        let entry = try await MushroomLogger.log(
            mushroom: mushroom, remainingSeconds: 150, leadSeconds: 15,
            respawnSeconds: 300, context: context, scheduler: scheduler, now: now
        )
        XCTAssertEqual(scheduler.scheduled.count, 1)
        XCTAssertEqual(scheduler.scheduled.first?.id, entry.id)
        XCTAssertEqual(scheduler.scheduled.first?.fireAt, entry.fireAt)
    }

    /// 通知排不進去時，整筆都不可以留下來。
    /// 留下一筆會倒數卻永遠不會響的計時，比什麼都沒建立更糟。
    func testFailedSchedulingLeavesNothingBehind() async throws {
        let mushroom = makeMushroom()
        let scheduler = StubScheduler()
        scheduler.errorToThrow = StubScheduler.Boom()

        do {
            _ = try await MushroomLogger.log(
                mushroom: mushroom, remainingSeconds: 0, leadSeconds: 15,
                respawnSeconds: 300, context: context, scheduler: scheduler, now: now
            )
            XCTFail("應該要丟出 notificationFailed")
        } catch MushroomLogger.LogError.notificationFailed {
            // 正確
        }

        XCTAssertEqual(try context.fetch(FetchDescriptor<TimerEntry>()).count, 0)
        XCTAssertEqual(mushroom.useCount, 0)
        XCTAssertNil(mushroom.lastUsedAt)
    }
}
