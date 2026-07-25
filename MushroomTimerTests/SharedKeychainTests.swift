import Security
import XCTest
@testable import MushroomTimer

/// `SharedKeychain` 是主 App 與小工具之間唯一的資料通道。
/// 實機驗證時它整條掛掉（access group 解析失敗），而原本完全沒有測試涵蓋到它。
final class SharedKeychainTests: XCTestCase {
    /// Team ID 探測必須成功。失敗時把 OSStatus 印出來，因為不同的錯誤碼
    /// 代表完全不同的原因：-50 是傳了非法參數，-34018 是 entitlement 沒簽進去。
    func testTeamIdentifierProbeSucceeds() {
        let result = SharedKeychain.probeTeamIdentifierPrefix()
        XCTAssertEqual(
            result.status, errSecSuccess,
            "探測在 \(result.stage) 階段失敗，OSStatus = \(result.status)"
        )
        XCTAssertNotNil(result.prefix, "探測成功但取不出 access group 的 prefix")
    }

    /// 有了 prefix 才組得出 access group。
    func testAccessGroupResolves() {
        XCTAssertNotNil(
            SharedKeychain.accessGroup,
            "access group 解析失敗，save/load 會全部靜默失敗"
        )
    }

    /// 寫進去要讀得回來——這正是實機上失敗的那一步。
    func testSaveThenLoadRoundTrips() throws {
        let payload = WidgetPayload.make(
            groupName: "中山路口",
            mushrooms: [(UUID(), "7-11 門口"), (UUID(), "天橋下")]
        )
        XCTAssertTrue(SharedKeychain.save(payload), "寫入 keychain 失敗")
        XCTAssertEqual(SharedKeychain.load(), payload)
    }

    /// 重複寫入不可以堆積出多筆項目，否則讀回來的可能是舊的那筆。
    func testSaveIsIdempotent() {
        let first = WidgetPayload.make(groupName: "甲", mushrooms: [(UUID(), "一")])
        let second = WidgetPayload.make(groupName: "乙", mushrooms: [(UUID(), "二")])
        XCTAssertTrue(SharedKeychain.save(first))
        XCTAssertTrue(SharedKeychain.save(second))
        XCTAssertEqual(SharedKeychain.load(), second)
    }
}
