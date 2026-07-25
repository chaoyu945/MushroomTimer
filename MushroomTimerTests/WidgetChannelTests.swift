import SwiftData
import XCTest
@testable import MushroomTimer

@MainActor
final class WidgetChannelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer.mushroomTimer(inMemory: true)
        defaults = UserDefaults(suiteName: "WidgetChannelTests")!
        defaults.removePersistentDomain(forName: "WidgetChannelTests")
    }

    override func tearDown() {
        container = nil
        defaults = nil
        super.tearDown()
    }

    private func makeGroup(name: String, mushrooms: [(String, Int)]) -> MushroomGroup {
        let group = MushroomGroup(name: name, latitude: 25.05, longitude: 121.52)
        context.insert(group)
        for (mushroomName, useCount) in mushrooms {
            // 指定 `group:` 就會透過 inverse relationship 自動加進 group.mushrooms，
            // 不可以再 append 一次，否則會出現重複。
            let mushroom = Mushroom(name: mushroomName, useCount: useCount, group: group)
            context.insert(mushroom)
        }
        return group
    }

    func testPayloadUsesLastKnownGroupAndTopThreeMushrooms() throws {
        let group = makeGroup(
            name: "中山路口",
            mushrooms: [("一", 1), ("二", 2), ("三", 3), ("四", 4)]
        )
        try context.save()
        defaults.set(group.id.uuidString, forKey: LocationService.lastKnownGroupIDKey)

        let payload = try WidgetChannel.makePayload(context: context, defaults: defaults)
        XCTAssertEqual(payload.groupName, "中山路口")
        XCTAssertEqual(payload.mushrooms.map(\.name), ["四", "三", "二"])
    }

    func testPayloadIsEmptyWithoutAnyGroup() throws {
        let payload = try WidgetChannel.makePayload(context: context, defaults: defaults)
        XCTAssertEqual(payload, .empty)
    }

    /// 沒有記錄過群組時退回最近建立的群組，小工具才不會一片空白。
    func testPayloadFallsBackToNewestGroup() throws {
        makeGroup(name: "舊", mushrooms: [("舊菇", 1)])
        try context.save()
        makeGroup(name: "新", mushrooms: [("新菇", 1)])
        try context.save()

        let payload = try WidgetChannel.makePayload(context: context, defaults: defaults)
        XCTAssertEqual(payload.groupName, "新")
    }
}
