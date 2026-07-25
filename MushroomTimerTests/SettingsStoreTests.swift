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

    /// 夾住之後必須真的寫進去。原本這條路徑完全沒有測試,
    /// 而它的正確性曾經依賴 @Published 的重入行為。
    func testClampedValueIsPersisted() {
        let store = SettingsStore(defaults: defaults)
        store.respawnSeconds = 5
        store.defaultLeadSeconds = 9_999
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.respawnSeconds, 30)
        XCTAssertEqual(reloaded.defaultLeadSeconds, 300)
    }

    /// 磁碟上已經壞掉的值,讀進來時要順手修好,不能只修記憶體裡那份。
    func testCorruptedStoredValueIsHealedOnInit() {
        defaults.set(99_999, forKey: "respawnSeconds")
        defaults.set(-42, forKey: "defaultLeadSeconds")
        _ = SettingsStore(defaults: defaults)
        XCTAssertEqual(defaults.integer(forKey: "respawnSeconds"), 3600)
        XCTAssertEqual(defaults.integer(forKey: "defaultLeadSeconds"), 0)
    }
}
