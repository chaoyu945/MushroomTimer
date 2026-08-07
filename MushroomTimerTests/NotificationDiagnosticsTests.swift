import SwiftData
import XCTest
@testable import MushroomTimer

@MainActor
final class NotificationDiagnosticsTests: XCTestCase {
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

    @discardableResult
    private func makeEntry(
        name: String = "7-11 門口",
        fireAtOffset: TimeInterval,
        status: TimerStatus = .active
    ) -> TimerEntry {
        let group = MushroomGroup(name: "竹北家", latitude: 24.8, longitude: 121.0)
        context.insert(group)
        let mushroom = Mushroom(name: name, group: group)
        context.insert(mushroom)
        let entry = TimerEntry(
            mushroom: mushroom,
            createdAt: now,
            remainingSeconds: 0,
            leadSeconds: 15,
            fireAt: now.addingTimeInterval(fireAtOffset)
        )
        entry.status = status
        context.insert(entry)
        return entry
    }

    /// 準時送達＝落差 0。這是基準線。
    func testOnTimeDeliveryHasNoDelay() {
        let entry = makeEntry(fireAtOffset: -60)
        let rows = NotificationDiagnostics.rows(
            entries: [entry],
            deliveredAt: [entry.id: entry.fireAt],
            pendingIDs: [],
            now: now
        )
        XCTAssertEqual(rows.first?.outcome, .delivered(delaySeconds: 0))
    }

    /// 遲到的秒數要精確算出來——這正是使用者一直在目測的數字。
    func testLateDeliveryReportsHowLate() {
        let entry = makeEntry(fireAtOffset: -60)
        let rows = NotificationDiagnostics.rows(
            entries: [entry],
            deliveredAt: [entry.id: entry.fireAt.addingTimeInterval(10)],
            pendingIDs: [],
            now: now
        )
        XCTAssertEqual(rows.first?.outcome, .delivered(delaySeconds: 10))
    }

    /// 時間到了、沒送達、排程裡也沒有 → 這筆真的不見了，跟「還沒到時間」不同。
    func testVanishedNotificationIsReportedMissing() {
        let entry = makeEntry(fireAtOffset: -60)
        let rows = NotificationDiagnostics.rows(
            entries: [entry], deliveredAt: [:], pendingIDs: [], now: now
        )
        XCTAssertEqual(rows.first?.outcome, .missing)
    }

    /// 還沒到時間就不算不見，即使排程查詢當下沒回報它。
    func testFutureEntryIsPendingNotMissing() {
        let entry = makeEntry(fireAtOffset: 300)
        let rows = NotificationDiagnostics.rows(
            entries: [entry], deliveredAt: [:], pendingIDs: [], now: now
        )
        XCTAssertEqual(rows.first?.outcome, .pending)
    }

    /// 排程裡找得到就是等著，不管時間過了沒。
    func testStillScheduledIsPending() {
        let entry = makeEntry(fireAtOffset: -5)
        let rows = NotificationDiagnostics.rows(
            entries: [entry], deliveredAt: [:], pendingIDs: [entry.id], now: now
        )
        XCTAssertEqual(rows.first?.outcome, .pending)
    }

    /// 使用者自己取消或按完成的，不該被算成「通知不見了」。
    func testCancelledAndCompletedAreNotCountedAsFailures() {
        let cancelled = makeEntry(name: "取消的", fireAtOffset: -60, status: .cancelled)
        let completed = makeEntry(name: "完成的", fireAtOffset: -60, status: .completed)
        let rows = NotificationDiagnostics.rows(
            entries: [cancelled, completed], deliveredAt: [:], pendingIDs: [], now: now
        )
        XCTAssertEqual(rows.map(\.outcome), [.notApplicable, .notApplicable])
    }
}
