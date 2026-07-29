import SwiftData
import XCTest
@testable import MushroomTimer

@MainActor
final class CurrentGroupResolverTests: XCTestCase {
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

    private func makeGroup(_ name: String) -> MushroomGroup {
        let group = MushroomGroup(name: name, latitude: 25.05, longitude: 121.52)
        context.insert(group)
        return group
    }

    /// 走出所有已知群組時必須回傳 nil。
    ///
    /// 這是這支程式最初的 bug：它會退回「最近建立的群組」，於是使用者走到新地點
    /// 畫面仍賴在舊群組，而且「建立新群組」按鈕（沒有目前群組時才出現）
    /// 在建立第一個群組之後就永遠不再出現，第二個群組根本建不出來。
    func testOutsideAllGroupsResolvesToNothing() {
        let home = makeGroup("home")
        XCTAssertNil(
            CurrentGroupResolver.resolve(
                manualSelection: nil, gps: .outsideAllGroups, groups: [home]
            )
        )
    }

    /// 還沒問到定位時才退回最近建立的群組，免得剛開 App 畫面是空的。
    func testPendingFallsBackToNewestGroup() {
        let home = makeGroup("home")
        let office = makeGroup("office")
        XCTAssertEqual(
            CurrentGroupResolver.resolve(
                manualSelection: nil, gps: .pending, groups: [office, home]
            )?.name,
            "office"
        )
    }

    func testMatchedGPSWins() {
        let home = makeGroup("home")
        let office = makeGroup("office")
        XCTAssertEqual(
            CurrentGroupResolver.resolve(
                manualSelection: nil, gps: .matched(home.id), groups: [office, home]
            )?.name,
            "home"
        )
    }

    /// 手動選擇要壓過 GPS——市區誤差可達 10–30 公尺，自動判定不一定準。
    func testManualSelectionOverridesGPS() {
        let home = makeGroup("home")
        let office = makeGroup("office")
        XCTAssertEqual(
            CurrentGroupResolver.resolve(
                manualSelection: office.id, gps: .matched(home.id), groups: [office, home]
            )?.name,
            "office"
        )
    }

    /// 手動選的群組被刪掉之後，不能卡在一個不存在的選擇上。
    func testDeletedManualSelectionFallsThrough() {
        let home = makeGroup("home")
        XCTAssertEqual(
            CurrentGroupResolver.resolve(
                manualSelection: UUID(), gps: .matched(home.id), groups: [home]
            )?.name,
            "home"
        )
    }

    /// 一個群組都沒有時，任何情況都只能是 nil。
    func testNoGroupsAtAll() {
        XCTAssertNil(
            CurrentGroupResolver.resolve(manualSelection: nil, gps: .pending, groups: [])
        )
    }
}
