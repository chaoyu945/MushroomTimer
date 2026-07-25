import XCTest
import UserNotifications
@testable import MushroomTimer

final class NotificationPolicyTests: XCTestCase {
    func testBodyFormat() {
        XCTAssertEqual(
            NotificationPolicy.body(groupName: "中山路口", mushroomName: "7-11 門口"),
            "【中山路口】7-11 門口 的菇要重生了"
        )
    }

    func testTitleIsNotEmpty() {
        XCTAssertFalse(NotificationPolicy.title.isEmpty)
    }

    /// 提前量可能只有 15 秒，因此不可使用會被系統延後的 .passive。
    func testInterruptionLevelIsNotPassive() {
        XCTAssertNotEqual(NotificationPolicy.interruptionLevel, .passive)
    }
}
