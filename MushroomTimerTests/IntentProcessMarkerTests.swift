import XCTest
@testable import MushroomTimer

final class IntentProcessMarkerTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "IntentProcessMarkerTests")!
        defaults.removePersistentDomain(forName: "IntentProcessMarkerTests")
    }

    func testStartsEmpty() {
        XCTAssertNil(IntentProcessMarker.latest(defaults: defaults))
    }

    func testRecordsProcessAndBundle() {
        IntentProcessMarker.record(
            processName: "MushroomTimer",
            bundleID: "com.chaoyu.MushroomTimer",
            defaults: defaults
        )
        let latest = IntentProcessMarker.latest(defaults: defaults)
        XCTAssertEqual(latest, "MushroomTimer / com.chaoyu.MushroomTimer")
    }

    func testLatestRecordWins() {
        IntentProcessMarker.record(
            processName: "A", bundleID: "a", defaults: defaults
        )
        IntentProcessMarker.record(
            processName: "B", bundleID: "b", defaults: defaults
        )
        XCTAssertEqual(IntentProcessMarker.latest(defaults: defaults), "B / b")
    }

    func testClearRemovesTheRecord() {
        IntentProcessMarker.record(
            processName: "MushroomTimer",
            bundleID: "com.chaoyu.MushroomTimer",
            defaults: defaults
        )
        IntentProcessMarker.clear(defaults: defaults)
        XCTAssertNil(IntentProcessMarker.latest(defaults: defaults))
    }
}
