import SwiftData
import XCTest
@testable import MushroomTimer

@MainActor
final class BackupCodecTests: XCTestCase {
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

    @discardableResult
    private func seed(groupName: String, mushroomNames: [String]) -> MushroomGroup {
        let group = MushroomGroup(name: groupName, latitude: 25.05, longitude: 121.52)
        context.insert(group)
        for name in mushroomNames {
            // 指定 `group:` 就會透過 inverse relationship 自動加進 group.mushrooms。
            let mushroom = Mushroom(name: name, useCount: 3, group: group)
            context.insert(mushroom)
        }
        return group
    }

    func testExportThenImportIntoEmptyDatabaseRestoresEverything() throws {
        seed(groupName: "中山路口", mushroomNames: ["7-11 門口", "天橋下"])
        try context.save()
        let data = try BackupCodec.export(context: context)

        let fresh = try ModelContainer.mushroomTimer(inMemory: true)
        let added = try BackupCodec.importing(data, into: fresh.mainContext)

        XCTAssertEqual(added, 1)
        let groups = try fresh.mainContext.fetch(FetchDescriptor<MushroomGroup>())
        XCTAssertEqual(groups.map(\.name), ["中山路口"])
        XCTAssertEqual(
            groups.first?.mushrooms.map(\.name).sorted(),
            ["7-11 門口", "天橋下"]
        )
        XCTAssertEqual(groups.first?.mushrooms.first?.useCount, 3)
    }

    /// 匯入不應該產生重複資料，同 id 的群組直接跳過。
    func testImportingTwiceDoesNotDuplicate() throws {
        seed(groupName: "中山路口", mushroomNames: ["7-11 門口"])
        try context.save()
        let data = try BackupCodec.export(context: context)

        let fresh = try ModelContainer.mushroomTimer(inMemory: true)
        XCTAssertEqual(try BackupCodec.importing(data, into: fresh.mainContext), 1)
        XCTAssertEqual(try BackupCodec.importing(data, into: fresh.mainContext), 0)
        XCTAssertEqual(
            try fresh.mainContext.fetch(FetchDescriptor<MushroomGroup>()).count, 1
        )
    }

    func testExportOfEmptyDatabase() throws {
        let data = try BackupCodec.export(context: context)
        let document = try JSONDecoder().decode(BackupDocument.self, from: data)
        XCTAssertEqual(document.version, 1)
        XCTAssertTrue(document.groups.isEmpty)
    }

    func testImportRejectsGarbage() {
        let garbage = Data("not json".utf8)
        XCTAssertThrowsError(
            try BackupCodec.importing(garbage, into: context)
        )
    }

    /// 來自更新版 App 的備份檔要明確拒絕，不能默默讀進去然後丟掉看不懂的欄位。
    func testRejectsNewerFormatVersion() throws {
        let json = """
        {"version": 99, "groups": []}
        """.data(using: .utf8)!

        XCTAssertThrowsError(try BackupCodec.importing(json, into: context)) { error in
            guard case BackupCodec.ImportError.unsupportedVersion(let version) = error else {
                return XCTFail("預期 unsupportedVersion，實際是 \(error)")
            }
            XCTAssertEqual(version, 99)
        }
    }

}
