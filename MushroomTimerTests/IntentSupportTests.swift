import SwiftData
import XCTest
@testable import MushroomTimer

@MainActor
final class IntentSupportTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer.mushroomTimer(inMemory: true)
        defaults = UserDefaults(suiteName: "IntentSupportTests")!
        defaults.removePersistentDomain(forName: "IntentSupportTests")
    }

    override func tearDown() {
        container = nil
        defaults = nil
        super.tearDown()
    }

    @discardableResult
    private func makeGroup(name: String) -> MushroomGroup {
        let group = MushroomGroup(name: name, latitude: 25.05, longitude: 121.52)
        context.insert(group)
        return group
    }

    @discardableResult
    private func makeMushroom(
        name: String, useCount: Int, group: MushroomGroup
    ) -> Mushroom {
        // 指定 `group:` 就會透過 inverse relationship 自動加進 group.mushrooms。
        let mushroom = Mushroom(name: name, useCount: useCount, group: group)
        context.insert(mushroom)
        return mushroom
    }

    func testMushroomLookupByID() throws {
        let group = makeGroup(name: "中山路口")
        let mushroom = makeMushroom(name: "7-11 門口", useCount: 0, group: group)
        try context.save()

        XCTAssertEqual(
            try IntentSupport.mushroom(id: mushroom.id, context: context)?.name,
            "7-11 門口"
        )
        XCTAssertNil(try IntentSupport.mushroom(id: UUID(), context: context))
    }

    func testAllMushroomsSortedByUseCountDescending() throws {
        let group = makeGroup(name: "中山路口")
        makeMushroom(name: "少", useCount: 1, group: group)
        makeMushroom(name: "多", useCount: 9, group: group)
        try context.save()

        XCTAssertEqual(
            try IntentSupport.allMushrooms(context: context).map(\.name),
            ["多", "少"]
        )
    }

    /// QuickLogHere 不觸發 GPS，改讀主 App 上次記下的群組。
    func testPreferredMushroomUsesLastKnownGroup() throws {
        let a = makeGroup(name: "中山路口")
        let b = makeGroup(name: "南京東路")
        makeMushroom(name: "A 的常用", useCount: 3, group: a)
        makeMushroom(name: "B 的常用", useCount: 7, group: b)
        try context.save()

        defaults.set(a.id.uuidString, forKey: LocationService.lastKnownGroupIDKey)
        XCTAssertEqual(
            try IntentSupport.preferredMushroom(context: context, defaults: defaults)?.name,
            "A 的常用"
        )
    }

    /// 沒有記錄過群組時，退而取全體最常用的那顆。
    func testPreferredMushroomFallsBackToGlobalMostUsed() throws {
        let a = makeGroup(name: "中山路口")
        let b = makeGroup(name: "南京東路")
        makeMushroom(name: "A 的常用", useCount: 3, group: a)
        makeMushroom(name: "B 的常用", useCount: 7, group: b)
        try context.save()

        XCTAssertEqual(
            try IntentSupport.preferredMushroom(context: context, defaults: defaults)?.name,
            "B 的常用"
        )
    }

    func testPreferredMushroomIsNilWhenThereAreNoMushrooms() throws {
        XCTAssertNil(
            try IntentSupport.preferredMushroom(context: context, defaults: defaults)
        )
    }

    /// 記下的群組後來被刪掉時要退回全體最常用，不能整個回傳 nil。
    /// 這條路徑跟「從來沒記錄過群組」不同：UUID 解析得出來，只是查不到東西。
    func testPreferredMushroomFallsBackWhenKnownGroupWasDeleted() throws {
        let doomed = makeGroup(name: "會被刪掉的群組")
        let survivor = makeGroup(name: "還在的群組")
        makeMushroom(name: "沒了的菇", useCount: 9, group: doomed)
        makeMushroom(name: "還在的菇", useCount: 2, group: survivor)
        try context.save()
        defaults.set(doomed.id.uuidString, forKey: LocationService.lastKnownGroupIDKey)

        context.delete(doomed)
        try context.save()

        XCTAssertEqual(
            try IntentSupport.preferredMushroom(context: context, defaults: defaults)?.name,
            "還在的菇"
        )
    }

    /// 記下的群組還在、但裡面一顆菇都沒有時，也要退回全體最常用。
    func testPreferredMushroomFallsBackWhenKnownGroupHasNoMushrooms() throws {
        let empty = makeGroup(name: "空群組")
        let other = makeGroup(name: "有菇的群組")
        makeMushroom(name: "別處的菇", useCount: 4, group: other)
        try context.save()
        defaults.set(empty.id.uuidString, forKey: LocationService.lastKnownGroupIDKey)

        XCTAssertEqual(
            try IntentSupport.preferredMushroom(context: context, defaults: defaults)?.name,
            "別處的菇"
        )
    }
}
