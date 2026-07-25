import XCTest
@testable import MushroomTimer

final class SettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "SettingsStoreTests")!
        defaults.removePersistentDomain(forName: "SettingsStoreTests")
    }

    func testDefaults() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.respawnSeconds, 300)
        XCTAssertEqual(store.defaultLeadSeconds, 15)
    }

    func testPersistsAcrossInstances() {
        let store = SettingsStore(defaults: defaults)
        store.respawnSeconds = 240
        store.defaultLeadSeconds = 30
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.respawnSeconds, 240)
        XCTAssertEqual(reloaded.defaultLeadSeconds, 30)
    }

    func testClampsOutOfRangeValues() {
        let store = SettingsStore(defaults: defaults)
        store.respawnSeconds = 5
        XCTAssertEqual(store.respawnSeconds, 30)
        store.respawnSeconds = 99_999
        XCTAssertEqual(store.respawnSeconds, 3600)
        store.defaultLeadSeconds = -10
        XCTAssertEqual(store.defaultLeadSeconds, 0)
        store.defaultLeadSeconds = 9_999
        XCTAssertEqual(store.defaultLeadSeconds, 300)
    }
}
