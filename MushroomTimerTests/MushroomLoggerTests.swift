import SwiftData
import XCTest
@testable import MushroomTimer

@MainActor
final class MushroomLoggerTests: XCTestCase {
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
            respawnSeconds: 300, context: context, now: now
        )
        _ = try await MushroomLogger.log(
            mushroom: mushroom, remainingSeconds: 0, leadSeconds: 15,
            respawnSeconds: 300, context: context, now: now
        )

        XCTAssertEqual(mushroom.useCount, 2)
        XCTAssertEqual(mushroom.lastUsedAt, now)
    }

    func testLogThrowsWhenResultIsInThePast() async {
        let mushroom = makeMushroom()
        do {
            _ = try await MushroomLogger.log(
                mushroom: mushroom, remainingSeconds: 0, leadSeconds: 400,
                respawnSeconds: 300, context: context, now: now
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
            respawnSeconds: 300, context: context, now: now
        )
        XCTAssertEqual(try context.fetch(FetchDescriptor<TimerEntry>()).count, 0)
        XCTAssertEqual(mushroom.useCount, 0)
    }

    func testCancelMarksEntryCancelled() async throws {
        let mushroom = makeMushroom()
        let entry = try await MushroomLogger.log(
            mushroom: mushroom, remainingSeconds: 0, leadSeconds: 15,
            respawnSeconds: 300, context: context, now: now
        )
        try MushroomLogger.cancel(entry, context: context)
        XCTAssertEqual(entry.status, .cancelled)
        XCTAssertEqual(try TimerQueries.active(in: context).count, 0)
    }

    func testCompleteMarksEntryCompleted() async throws {
        let mushroom = makeMushroom()
        let entry = try await MushroomLogger.log(
            mushroom: mushroom, remainingSeconds: 0, leadSeconds: 15,
            respawnSeconds: 300, context: context, now: now
        )
        try MushroomLogger.complete(entry, context: context)
        XCTAssertEqual(entry.status, .completed)
    }
}
