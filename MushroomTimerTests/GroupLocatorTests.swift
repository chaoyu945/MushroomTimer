import SwiftData
import XCTest
@testable import MushroomTimer

@MainActor
final class GroupLocatorTests: XCTestCase {
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

    /// 台北車站附近。緯度差 0.001 度約 111 公尺。
    private let baseLat = 25.0478
    private let baseLon = 121.5170

    private func makeGroup(
        name: String, latOffset: Double, radius: Double = 80
    ) -> MushroomGroup {
        let group = MushroomGroup(
            name: name,
            latitude: baseLat + latOffset,
            longitude: baseLon,
            radius: radius
        )
        context.insert(group)
        return group
    }

    func testReturnsNilWhenNoGroups() {
        XCTAssertNil(GroupLocator.nearest(
            latitude: baseLat, longitude: baseLon, groups: []
        ))
    }

    func testReturnsNilWhenAllGroupsAreOutOfRange() {
        let far = makeGroup(name: "遠", latOffset: 0.01) // 約 1100 公尺
        XCTAssertNil(GroupLocator.nearest(
            latitude: baseLat, longitude: baseLon, groups: [far]
        ))
    }

    func testReturnsGroupWithinRadius() {
        let near = makeGroup(name: "近", latOffset: 0.0002) // 約 22 公尺
        XCTAssertEqual(
            GroupLocator.nearest(
                latitude: baseLat, longitude: baseLon, groups: [near]
            )?.name,
            "近"
        )
    }

    func testPicksClosestWhenMultipleAreInRange() {
        let closer = makeGroup(name: "較近", latOffset: 0.0001)
        let further = makeGroup(name: "較遠", latOffset: 0.0005)
        XCTAssertEqual(
            GroupLocator.nearest(
                latitude: baseLat, longitude: baseLon, groups: [further, closer]
            )?.name,
            "較近"
        )
    }

    /// 半徑是每個群組自己的設定，不是全域常數。
    func testRespectsPerGroupRadius() {
        let wide = makeGroup(name: "大範圍", latOffset: 0.002, radius: 300)
        XCTAssertEqual(
            GroupLocator.nearest(
                latitude: baseLat, longitude: baseLon, groups: [wide]
            )?.name,
            "大範圍"
        )
    }
}
