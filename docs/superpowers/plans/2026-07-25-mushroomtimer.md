# 打菇茜（MushroomTimer）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 做出一個 iOS App「打菇茜」，讓 Pikmin Bloom 玩家在 2～3 個 tap、零打字的情況下登記一顆菇的重生提醒。

**Architecture:** 單機 SwiftUI App，SwiftData 存三張表（群組／菇／計時）。所有「登記」動作都走同一條管線 `MushroomLogger`，由主畫面、App Intents、桌面小工具共用。因為使用免費 Apple Developer 帳號、不能用 App Groups，Widget extension 完全不碰資料庫：Live Activity 靠 `ContentState` 一次帶齊資料，小工具靠共享 Keychain 讀一份主 App 寫好的精簡 payload。倒數一律用 `Text(timerInterval:)`，零背景作業。

**Tech Stack:** Swift 5.9+／SwiftUI／SwiftData／ActivityKit／WidgetKit／AppIntents／UserNotifications／CoreLocation／XcodeGen／XCTest

**設計文件：** [docs/superpowers/specs/2026-07-25-mushroomtimer-design.md](../specs/2026-07-25-mushroomtimer-design.md)

## Global Constraints

這些是全域規則，**每一個 task 都適用**，不會在各 task 內重複：

- 最低支援 iOS 17.0；`TARGETED_DEVICE_FAMILY: "1"`（iPhone only）
- 主 App Bundle ID `com.chaoyu.MushroomTimer`；Widget extension `com.chaoyu.MushroomTimer.Widgets`。**一旦定案不可更改**（App ID 設定每 7 天僅能改 10 次）
- entitlements 中**絕不可出現 App Groups**、遠端推播、iCloud、Sign in with Apple、Associated Domains
- Widget extension **不可** import SwiftData、不可存取主 App 資料庫
- 倒數顯示一律用 `Text(timerInterval:countsDown:)`，**禁止**用 `Timer`／背景輪詢／定時推送更新倒數
- 所有時間計算以秒（`Int`）為單位，不用浮點數
- UI 文案一律繁體中文（zh-TW）
- 專案用 XcodeGen 產生：改 `project.yml` → 執行 `xcodegen generate`。產生的 `.xcodeproj` 要進版控，且重新產生必須零 diff
- `DEVELOPMENT_TEAM` 不進 git（xcodegen 會移除，建置時在 Xcode 重選 Team）
- 測試指令：`xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test`
- 每個 task 結束時 commit，commit message 用英文、結尾加 `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`

## 檔案結構

```
project.yml                          # XcodeGen 設定，三個 target
Shared/                              # 同時編進主 App 與 Widget extension 兩個 target
  MushroomActivityAttributes.swift   # Live Activity 的 ActivityAttributes / ContentState
  WidgetPayload.swift                # 小工具要顯示的精簡資料（Codable）
  SharedKeychain.swift               # 共享 keychain 讀寫 + team prefix 探測
  QuickLogIntent.swift               # 小工具按鈕用的 LiveActivityIntent
MushroomTimer/                       # 主 App target
  MushroomTimerApp.swift             # @main，建立 ModelContainer
  Models/
    MushroomGroup.swift              # @Model 群組
    Mushroom.swift                   # @Model 菇
    TimerEntry.swift                 # @Model 計時 + TimerStatus enum
    TimerCalculator.swift            # 純函式：fireAt 計算
    DurationInput.swift              # 純函式：「230」→ 150 秒、秒數格式化
    GroupLocator.swift               # 純函式：找最近且在半徑內的群組
  Services/
    NotificationService.swift        # 本機通知排定／取消／授權
    NotificationPolicy.swift         # interruptionLevel 與文案（純函式，可測）
    LocationService.swift            # 一次性定位 + 反向地理編碼
    LiveActivityController.swift     # 單一 Live Activity 的生命週期
    WidgetChannel.swift              # 寫 payload 到 keychain + reload timeline
    MushroomLogger.swift             # 登記管線（所有入口共用）
  Stores/
    SettingsStore.swift              # respawnSeconds / defaultLeadSeconds
    BackupCodec.swift                # JSON 匯出／匯入（純函式）
  Views/
    MainView.swift                   # 主畫面（上：計時清單，下：快速登記）
    ActiveTimersSection.swift        # 主畫面上半部
    QuickLogSection.swift            # 主畫面下半部
    TimeInputSheet.swift             # 剩餘時間輸入
    GroupListView.swift              # 群組 CRUD
    MushroomListView.swift           # 菇 CRUD
    SettingsView.swift               # 設定 + 匯出匯入 + 說明
    VerificationView.swift           # 第 0 階段驗證用（Task 19 移除）
  Intents/
    MushroomEntity.swift             # 捷徑用的菇 entity + query
    LogMushroomIntent.swift
    QuickLogHereIntent.swift
    AppShortcuts.swift
MushroomTimerWidgets/                # Widget extension target
  MushroomTimerWidgetBundle.swift
  QuickLogWidget.swift               # 互動式桌面小工具
  MushroomLiveActivity.swift         # 鎖定畫面／動態島四種版面
MushroomTimerTests/
```

## 任務總覽

| # | Task | 階段 |
|---|---|---|
| 1 | 專案骨架 + TimerCalculator | 0 |
| 2 | 【驗證】通知與 Time Sensitive | 0 |
| 3 | 【驗證】Live Activity 最小版 | 0 |
| 4 | 【驗證】共享 Keychain | 0 |
| 5 | 【驗證】小工具按鈕 Intent 的執行 process | 0 |
| 6 | DurationInput 輸入解析 | 1 |
| 7 | SettingsStore | 1 |
| 8 | SwiftData 資料模型 | 1 |
| 9 | MushroomLogger 登記管線 | 1 |
| 10 | 群組／菇 CRUD 畫面 | 1 |
| 11 | TimeInputSheet | 1 |
| 12 | MainView | 1 |
| 13 | LocationService + GroupLocator | 2 |
| 14 | App Intents | 2 |
| 15 | 互動式桌面小工具 | 2 |
| 16 | Live Activity 整合 | 3 |
| 17 | 通知動作按鈕 | 3 |
| 18 | JSON 匯出匯入 | 3 |
| 19 | 設定畫面與收尾 | 3 |

---

### Task 1: 專案骨架與 TimerCalculator

建立 XcodeGen 專案（三個 target、entitlements 一次到位），並以此為載體用 TDD 完成核心計算函式。entitlements 必須一次設定正確，因為 App ID 每 7 天只能改 10 次。

**Files:**
- Create: `project.yml`
- Create: `MushroomTimer/MushroomTimerApp.swift`
- Create: `MushroomTimer/Info.plist`
- Create: `MushroomTimer/MushroomTimer.entitlements`
- Create: `MushroomTimer/Views/MainView.swift`
- Create: `MushroomTimer/Models/TimerCalculator.swift`
- Create: `MushroomTimerWidgets/Info.plist`
- Create: `MushroomTimerWidgets/MushroomTimerWidgets.entitlements`
- Create: `MushroomTimerWidgets/MushroomTimerWidgetBundle.swift`
- Create: `Shared/Placeholder.swift`
- Test: `MushroomTimerTests/TimerCalculatorTests.swift`

**Interfaces:**
- Consumes: 無（第一個 task）
- Produces: `TimerCalculator.fireAt(now:remainingSeconds:respawnSeconds:leadSeconds:) -> Date?`（回傳 `nil` 代表時間已過，不可建立計時）

- [ ] **Step 1: 建立 `project.yml`**

`PRODUCT_BUNDLE_IDENTIFIER` 必須明確寫出來。XcodeGen 預設會用 `bundleIdPrefix + target 名稱`，那會產生 `com.chaoyu.MushroomTimerWidgets`——但 App Extension 的 bundle ID **必須**是主 App bundle ID 加上一段後綴，否則無法安裝。

```yaml
name: MushroomTimer
options:
  bundleIdPrefix: com.chaoyu
  deploymentTarget:
    iOS: "17.0"
  createIntermediateGroups: true
targets:
  MushroomTimer:
    type: application
    platform: iOS
    sources: [MushroomTimer, Shared]
    entitlements:
      path: MushroomTimer/MushroomTimer.entitlements
      properties:
        keychain-access-groups:
          - $(AppIdentifierPrefix)com.chaoyu.MushroomTimer.shared
        com.apple.developer.usernotifications.time-sensitive: true
    info:
      path: MushroomTimer/Info.plist
      properties:
        CFBundleDisplayName: 打菇茜
        NSSupportsLiveActivities: true
        NSLocationWhenInUseUsageDescription: 打菇茜需要目前位置，用來判斷你在哪一個菇群組。
        UILaunchScreen: {}
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.chaoyu.MushroomTimer
        TARGETED_DEVICE_FAMILY: "1"
        CODE_SIGN_STYLE: Automatic
        SWIFT_EMIT_LOC_STRINGS: YES
    dependencies:
      - target: MushroomTimerWidgets
    scheme:
      testTargets: [MushroomTimerTests]
  MushroomTimerWidgets:
    type: app-extension
    platform: iOS
    sources: [MushroomTimerWidgets, Shared]
    entitlements:
      path: MushroomTimerWidgets/MushroomTimerWidgets.entitlements
      properties:
        keychain-access-groups:
          - $(AppIdentifierPrefix)com.chaoyu.MushroomTimer.shared
    info:
      path: MushroomTimerWidgets/Info.plist
      properties:
        CFBundleDisplayName: 打菇茜
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.chaoyu.MushroomTimer.Widgets
        TARGETED_DEVICE_FAMILY: "1"
        CODE_SIGN_STYLE: Automatic
        SKIP_INSTALL: YES
    dependencies:
      - sdk: SwiftUI.framework
      - sdk: WidgetKit.framework
  MushroomTimerTests:
    type: bundle.unit-test
    platform: iOS
    sources: [MushroomTimerTests]
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
    dependencies:
      - target: MushroomTimer
```

- [ ] **Step 2: 建立兩個 entitlements 檔**

XcodeGen 會依 `project.yml` 的 `properties` 覆寫這兩個檔案的內容，但檔案必須先存在。兩個檔案都先寫成空 plist：

`MushroomTimer/MushroomTimer.entitlements` 與 `MushroomTimerWidgets/MushroomTimerWidgets.entitlements`，內容相同：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
```

兩個 Info.plist 同樣先建成空 plist（內容如上），XcodeGen 會填入 `properties` 的內容。

- [ ] **Step 3: 建立最小可執行的 App 與 Widget 程式碼**

`MushroomTimer/MushroomTimerApp.swift`：

```swift
import SwiftUI

@main
struct MushroomTimerApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
```

`MushroomTimer/Views/MainView.swift`：

```swift
import SwiftUI

struct MainView: View {
    var body: some View {
        Text("打菇茜")
            .font(.largeTitle)
    }
}
```

`MushroomTimerWidgets/MushroomTimerWidgetBundle.swift`：

```swift
import SwiftUI
import WidgetKit

@main
struct MushroomTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        EmptyWidget()
    }
}

/// 佔位用，Task 15 會換成真正的互動式小工具。
struct EmptyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Placeholder", provider: PlaceholderProvider()) { _ in
            Text("打菇茜")
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("打菇茜")
        .description("快速登記一顆菇。")
        .supportedFamilies([.systemSmall])
    }
}

struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [PlaceholderEntry(date: .now)], policy: .never))
    }
}
```

`Shared/Placeholder.swift`（`Shared/` 資料夾必須有檔案才能被 XcodeGen 收進兩個 target，Task 3 會加入真正的內容）：

```swift
import Foundation

/// `Shared/` 內的檔案會同時編進主 App 與 Widget extension。
enum SharedBuildMarker {
    static let name = "MushroomTimer"
}
```

- [ ] **Step 4: 產生專案並確認可以建置**

```bash
cd ~/Developer/MushroomTimer && xcodegen generate
```

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 寫 TimerCalculator 的失敗測試**

`MushroomTimerTests/TimerCalculatorTests.swift`：

```swift
import XCTest
@testable import MushroomTimer

final class TimerCalculatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    /// 規格範例：剩 2:30、重生 5:00、提前 15 秒 → 435 秒後提醒。
    func testSpecExample() {
        let fireAt = TimerCalculator.fireAt(
            now: now, remainingSeconds: 150, respawnSeconds: 300, leadSeconds: 15
        )
        XCTAssertEqual(fireAt, now.addingTimeInterval(435))
    }

    /// 剩餘時間 0 代表「剛爆」，是合法輸入。
    func testJustPoppedIsAllowed() {
        let fireAt = TimerCalculator.fireAt(
            now: now, remainingSeconds: 0, respawnSeconds: 300, leadSeconds: 15
        )
        XCTAssertEqual(fireAt, now.addingTimeInterval(285))
    }

    /// 提前量大於等於總時間 → 時間已過，不可建立計時。
    func testReturnsNilWhenResultIsNotInTheFuture() {
        XCTAssertNil(TimerCalculator.fireAt(
            now: now, remainingSeconds: 0, respawnSeconds: 300, leadSeconds: 300
        ))
        XCTAssertNil(TimerCalculator.fireAt(
            now: now, remainingSeconds: 0, respawnSeconds: 300, leadSeconds: 400
        ))
    }

    /// 剛好剩 1 秒仍算未來，可以建立。
    func testOneSecondInFutureIsAllowed() {
        let fireAt = TimerCalculator.fireAt(
            now: now, remainingSeconds: 0, respawnSeconds: 300, leadSeconds: 299
        )
        XCTAssertEqual(fireAt, now.addingTimeInterval(1))
    }

    /// 提前量為 0（使用者調到最低）也要正常運作。
    func testZeroLead() {
        let fireAt = TimerCalculator.fireAt(
            now: now, remainingSeconds: 60, respawnSeconds: 300, leadSeconds: 0
        )
        XCTAssertEqual(fireAt, now.addingTimeInterval(360))
    }
}
```

- [ ] **Step 6: 執行測試確認失敗**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 編譯失敗，錯誤訊息為 `cannot find 'TimerCalculator' in scope`

- [ ] **Step 7: 實作 TimerCalculator**

`MushroomTimer/Models/TimerCalculator.swift`：

```swift
import Foundation

/// 提醒時間的計算。全部以秒（Int）運算，避免浮點誤差。
///
///     fireAt = now + remainingSeconds + respawnSeconds - leadSeconds
enum TimerCalculator {
    /// - Returns: 計算後的提醒時間；若結果不在未來則回傳 `nil`（呼叫端應提示「時間已過」並拒絕建立）。
    static func fireAt(
        now: Date,
        remainingSeconds: Int,
        respawnSeconds: Int,
        leadSeconds: Int
    ) -> Date? {
        let offset = remainingSeconds + respawnSeconds - leadSeconds
        guard offset > 0 else { return nil }
        return now.addingTimeInterval(TimeInterval(offset))
    }
}
```

- [ ] **Step 8: 執行測試確認通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`，5 個測試全數通過

- [ ] **Step 9: 【使用者手動】實機安裝驗證**

這一步無法由 agent 執行，**必須停下來請使用者操作並回報結果**：

1. 在 Xcode 開啟 `MushroomTimer.xcodeproj`
2. 選 MushroomTimer target → Signing & Capabilities → Team 選自己的 Personal Team
3. 接上 iPhone，選該裝置為執行目標，按 Run
4. 確認 App 成功安裝並顯示「打菇茜」字樣

若安裝失敗且錯誤訊息提到 entitlement／capability，記下完整錯誤訊息——最可能的原因是 `com.apple.developer.usernotifications.time-sensitive` 免費帳號不能簽（這正是 Task 2 要驗證的事）。此時先從 `project.yml` 移除該行、重新 `xcodegen generate`，確認移除後可安裝，並在 Task 2 記錄「Time Sensitive 不可用」。

- [ ] **Step 10: Commit**

```bash
cd ~/Developer/MushroomTimer && git add -A && git commit -m "$(cat <<'EOF'
feat: scaffold XcodeGen project and add TimerCalculator

Three targets (app, widget extension, unit tests) with keychain sharing
entitlements and no App Groups. TimerCalculator computes fireAt in whole
seconds and rejects results that are not in the future.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: 【驗證】通知與 Time Sensitive

驗證通知能否設為 Time Sensitive（時效性通知），以及在專注模式下是否準時響。這決定了 App 的通知策略，必須在寫其他功能前確認。

**Files:**
- Create: `MushroomTimer/Services/NotificationPolicy.swift`
- Create: `MushroomTimer/Services/NotificationService.swift`
- Create: `MushroomTimer/Views/VerificationView.swift`
- Modify: `MushroomTimer/Views/MainView.swift`
- Create: `docs/verification-results.md`
- Test: `MushroomTimerTests/NotificationPolicyTests.swift`

**Interfaces:**
- Consumes: 無
- Produces:
  - `NotificationPolicy.interruptionLevel: UNNotificationInterruptionLevel`（單一開關，驗證失敗時改成 `.active`）
  - `NotificationPolicy.title = "菇要重生了"`
  - `NotificationPolicy.body(groupName: String, mushroomName: String) -> String`
  - `NotificationService.shared.requestAuthorization() async -> Bool`
  - `NotificationService.shared.schedule(id: UUID, groupName: String, mushroomName: String, at: Date) async throws`
  - `NotificationService.shared.cancel(id: UUID)`

- [ ] **Step 1: 寫 NotificationPolicy 的失敗測試**

`MushroomTimerTests/NotificationPolicyTests.swift`：

```swift
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
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 編譯失敗，`cannot find 'NotificationPolicy' in scope`

- [ ] **Step 3: 實作 NotificationPolicy**

`MushroomTimer/Services/NotificationPolicy.swift`：

```swift
import Foundation
import UserNotifications

/// 通知的文案與中斷等級。中斷等級集中在這裡，方便依實機驗證結果一次切換。
enum NotificationPolicy {
    /// `.timeSensitive` 可穿透「專注模式」，但需要 entitlement。
    /// 若實機驗證免費帳號無法簽署，改成 `.active`，並在設定頁引導使用者
    /// 手動把本 App 加入專注模式的允許清單（效果相同，不需 entitlement）。
    static let interruptionLevel: UNNotificationInterruptionLevel = .timeSensitive

    static let title = "菇要重生了"

    static func body(groupName: String, mushroomName: String) -> String {
        "【\(groupName)】\(mushroomName) 的菇要重生了"
    }
}
```

- [ ] **Step 4: 執行測試確認通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 實作 NotificationService**

`MushroomTimer/Services/NotificationService.swift`：

```swift
import Foundation
import UserNotifications

/// 本機通知的排定與取消。不需要伺服器，也不需要遠端推播 entitlement。
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    /// 向使用者要求通知權限。首次呼叫會跳出系統對話框。
    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// 排定一則在 `date` 響起的本機通知。
    /// - Parameter id: 用計時的 UUID 當通知識別碼，取消時才找得到它。
    func schedule(id: UUID, groupName: String, mushroomName: String, at date: Date) async throws {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = NotificationPolicy.title
        content.body = NotificationPolicy.body(groupName: groupName, mushroomName: mushroomName)
        content.sound = .default
        content.interruptionLevel = NotificationPolicy.interruptionLevel

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: id.uuidString, content: content, trigger: trigger
        )
        try await center.add(request)
    }

    func cancel(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }
}
```

- [ ] **Step 6: 建立驗證畫面**

`MushroomTimer/Views/VerificationView.swift`。這個畫面在第 0 階段驗證用，Task 19 會整個移除。

```swift
import SwiftUI

/// 第 0 階段的實機驗證畫面。功能完成後（Task 19）整個檔案移除。
struct VerificationView: View {
    @State private var log: [String] = []

    var body: some View {
        List {
            Section("通知") {
                Button("要求通知權限") {
                    Task {
                        let granted = await NotificationService.shared.requestAuthorization()
                        append("通知權限：\(granted ? "已允許" : "被拒絕")")
                    }
                }
                Button("排定 20 秒後的通知") {
                    Task {
                        do {
                            try await NotificationService.shared.schedule(
                                id: UUID(),
                                groupName: "中山路口",
                                mushroomName: "7-11 門口",
                                at: Date().addingTimeInterval(20)
                            )
                            append("已排定 20 秒後的通知，請鎖屏等待")
                        } catch {
                            append("排定失敗：\(error.localizedDescription)")
                        }
                    }
                }
            }

            Section("記錄") {
                if log.isEmpty {
                    Text("尚無記錄").foregroundStyle(.secondary)
                } else {
                    ForEach(log, id: \.self, content: Text.init)
                }
            }
        }
        .navigationTitle("第 0 階段驗證")
    }

    private func append(_ line: String) {
        log.insert(line, at: 0)
    }
}
```

- [ ] **Step 7: 把驗證畫面接到 MainView**

`MushroomTimer/Views/MainView.swift` 全檔替換：

```swift
import SwiftUI

struct MainView: View {
    var body: some View {
        NavigationStack {
            VerificationView()
        }
    }
}
```

- [ ] **Step 8: 確認可以建置**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: 【使用者手動】實機驗證 Time Sensitive**

**必須停下來請使用者操作並回報結果。** 驗證項目：

1. App 能否安裝到實機（帶著 `com.apple.developer.usernotifications.time-sensitive` entitlement）
   - 若安裝失敗且錯誤提到 time-sensitive／capability → **Time Sensitive 不可用**
2. 若安裝成功：點「要求通知權限」→ 允許
3. 前往 iOS 設定 → 通知 → 打菇茜，確認是否出現「時效性通知」開關（有出現代表 entitlement 生效）
4. 開啟「勿擾模式」，回到 App 點「排定 20 秒後的通知」，鎖屏等待
5. 記錄通知是否在勿擾模式下準時響起

- [ ] **Step 10: 記錄驗證結果**

建立 `docs/verification-results.md`，把上一步的實際結果填進去（以下為格式範例，**必須換成真實觀察到的結果**）：

```markdown
# 第 0 階段驗證結果

## Time Sensitive 通知（Task 2）

- 日期：<實際驗證日期>
- 帶 time-sensitive entitlement 能否安裝到實機：<能／不能>
- 設定中是否出現「時效性通知」開關：<有／沒有>
- 勿擾模式下是否準時響起：<是／否，延遲約幾秒>
- **結論**：<使用 Time Sensitive／改用一般通知並在設定頁引導專注模式允許清單>
```

若結論是不可用，同時執行：從 `project.yml` 移除 `com.apple.developer.usernotifications.time-sensitive`、把 `NotificationPolicy.interruptionLevel` 改為 `.active`、重新 `xcodegen generate`，並確認測試仍通過。

- [ ] **Step 11: Commit**

```bash
cd ~/Developer/MushroomTimer && git add -A && git commit -m "$(cat <<'EOF'
feat: add local notification service and verify time-sensitive delivery

NotificationPolicy centralises copy and interruption level so the
free-account fallback is a one-line change. VerificationView is a
temporary phase-0 harness and is removed in the final task.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: 【驗證】Live Activity 最小版

驗證在**不使用 App Groups** 的情況下，Live Activity 能否從主 App 啟動並在鎖定畫面／動態島正確顯示。所有資料靠 `ContentState` 傳遞。

**Files:**
- Create: `Shared/MushroomActivityAttributes.swift`
- Create: `MushroomTimerWidgets/MushroomLiveActivity.swift`
- Modify: `MushroomTimerWidgets/MushroomTimerWidgetBundle.swift`
- Modify: `MushroomTimer/Views/VerificationView.swift`
- Modify: `docs/verification-results.md`
- Test: `MushroomTimerTests/MushroomActivityAttributesTests.swift`

**Interfaces:**
- Consumes: 無
- Produces:
  - `MushroomActivityAttributes`（`ActivityAttributes`），內含 `ContentState { mushroomName, groupName, fireAt, queuedCount, nextMushroomName: String? }`
  - `MushroomActivityAttributes.ContentState.queueLabel: String?`（例如 `"+2"`，沒有排隊時為 `nil`）

- [ ] **Step 1: 寫 ContentState 的失敗測試**

`MushroomTimerTests/MushroomActivityAttributesTests.swift`：

```swift
import XCTest
@testable import MushroomTimer

final class MushroomActivityAttributesTests: XCTestCase {
    private func state(queued: Int) -> MushroomActivityAttributes.ContentState {
        MushroomActivityAttributes.ContentState(
            mushroomName: "7-11 門口",
            groupName: "中山路口",
            fireAt: Date(timeIntervalSince1970: 1_000_000),
            queuedCount: queued,
            nextMushroomName: nil
        )
    }

    func testNoQueueLabelWhenNothingIsWaiting() {
        XCTAssertNil(state(queued: 0).queueLabel)
    }

    func testQueueLabelShowsPlusCount() {
        XCTAssertEqual(state(queued: 2).queueLabel, "+2")
    }

    /// ContentState 會被序列化送到 Widget process，必須是 Codable 且能完整還原。
    func testContentStateRoundTripsThroughJSON() throws {
        let original = state(queued: 3)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            MushroomActivityAttributes.ContentState.self, from: data
        )
        XCTAssertEqual(decoded, original)
    }
}
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 編譯失敗，`cannot find 'MushroomActivityAttributes' in scope`

- [ ] **Step 3: 實作 ActivityAttributes**

`Shared/MushroomActivityAttributes.swift`。**這個檔案放在 `Shared/`，會同時編進主 App 與 Widget extension 兩個 target**——因為主 App 要建立 Activity、Widget extension 要畫出來，兩邊都需要這個型別。

```swift
import ActivityKit
import Foundation

/// Live Activity 的資料契約。
///
/// 免費帳號不能用 App Groups，Widget extension 讀不到主 App 的資料庫，
/// 因此顯示所需的**全部**資料都必須放進 `ContentState` 一次帶過去。
struct MushroomActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// 最快到期那一筆的菇名稱。
        var mushroomName: String
        /// 該筆所屬的群組名稱。
        var groupName: String
        /// 提醒時間。畫面用 `Text(timerInterval:)` 自己逐秒跑，不需背景更新。
        var fireAt: Date
        /// 除了目前這筆之外，還有幾筆在排隊。
        var queuedCount: Int
        /// 下一筆的菇名稱。主 App 沒在執行時無法自動切換，
        /// 先帶著讓畫面在目前這筆結束後仍有意義。
        var nextMushroomName: String?

        /// 排隊筆數的顯示文字，例如 `"+2"`；沒有排隊時為 `nil`。
        var queueLabel: String? {
            queuedCount > 0 ? "+\(queuedCount)" : nil
        }
    }
}
```

- [ ] **Step 4: 執行測試確認通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 實作 Live Activity 的四種版面**

`MushroomTimerWidgets/MushroomLiveActivity.swift`：

```swift
import ActivityKit
import SwiftUI
import WidgetKit

/// 鎖定畫面與動態島的 Live Activity 版面。
/// 倒數一律用 `Text(timerInterval:)`：給定結束時間後元件自己逐秒跑動，
/// 不需要任何背景作業，也因此完全不需要讀取主 App 的資料庫。
struct MushroomLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MushroomActivityAttributes.self) { context in
            lockScreenView(context.state)
                .padding()
                .activityBackgroundTint(.black.opacity(0.6))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(to: context.state.fireAt)
                        .font(.title2.monospacedDigit().bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.mushroomName)
                                .font(.headline)
                            Text(context.state.groupName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let label = context.state.queueLabel {
                            Text(label)
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                countdown(to: context.state.fireAt)
                    .font(.caption.monospacedDigit())
                    .frame(width: 44)
            } minimal: {
                countdown(to: context.state.fireAt)
                    .font(.caption2.monospacedDigit())
                    .frame(width: 36)
            }
        }
    }

    private func lockScreenView(
        _ state: MushroomActivityAttributes.ContentState
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.mushroomName)
                    .font(.title3.bold())
                Text(state.groupName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                countdown(to: state.fireAt)
                    .font(.largeTitle.monospacedDigit().bold())
                if let label = state.queueLabel {
                    Text("還有 \(label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func countdown(to date: Date) -> some View {
        // `Text(timerInterval:)` 吃的是 ClosedRange，lowerBound > upperBound 會直接 trap。
        // 提醒時間過了之後這個 view 仍可能被重新求值（extension 重啟、狀態切換），
        // 所以一定要夾住範圍，不能直接寫 Date.now...date。
        let now = Date.now
        return Text(timerInterval: min(now, date)...max(now, date), countsDown: true)
            .multilineTextAlignment(.trailing)
    }
}
```

- [ ] **Step 6: 把 Live Activity 加進 WidgetBundle**

`MushroomTimerWidgets/MushroomTimerWidgetBundle.swift` 的 `body` 改成：

```swift
    var body: some Widget {
        EmptyWidget()
        MushroomLiveActivity()
    }
```

- [ ] **Step 7: 在驗證畫面加上 Live Activity 的啟動／結束按鈕**

在 `VerificationView.swift` 最上方加入 `import ActivityKit`，並在 `Section("通知")` 之後插入新的 section：

```swift
            Section("Live Activity") {
                Button("啟動 Live Activity（60 秒）") {
                    startActivity()
                }
                Button("結束全部 Live Activity", role: .destructive) {
                    Task {
                        for activity in Activity<MushroomActivityAttributes>.activities {
                            await activity.end(nil, dismissalPolicy: .immediate)
                        }
                        append("已結束全部 Live Activity")
                    }
                }
            }
```

並在 `append(_:)` 之前加入這個方法：

```swift
    private func startActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            append("Live Activity 未啟用，請到 設定 → 打菇茜 開啟「即時動態」")
            return
        }
        let state = MushroomActivityAttributes.ContentState(
            mushroomName: "7-11 門口",
            groupName: "中山路口",
            fireAt: Date().addingTimeInterval(60),
            queuedCount: 2,
            nextMushroomName: "天橋下"
        )
        do {
            _ = try Activity.request(
                attributes: MushroomActivityAttributes(),
                content: .init(state: state, staleDate: nil)
            )
            append("已啟動 Live Activity")
        } catch {
            append("啟動失敗：\(error.localizedDescription)")
        }
    }
```

- [ ] **Step 8: 確認可以建置**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: 【使用者手動】實機驗證 Live Activity**

**必須停下來請使用者操作並回報結果。** 驗證項目：

1. 點「啟動 Live Activity（60 秒）」
2. 鎖屏，確認鎖定畫面出現卡片，且倒數數字**自己逐秒減少**（這是零背景作業的關鍵證據）
3. 回到桌面，確認動態島（iPhone 14 Pro 以上）compact 區顯示倒數；長按展開確認顯示菇名稱、群組、倒數、`+2`
4. 若是沒有動態島的機型，只需確認鎖定畫面正常
5. 點「結束全部 Live Activity」確認卡片消失

- [ ] **Step 10: 記錄驗證結果**

在 `docs/verification-results.md` 追加一節，填入實際結果：

```markdown
## Live Activity（Task 3）

- 無 App Groups 下能否啟動：<能／不能>
- 鎖定畫面倒數是否自己逐秒跑動：<是／否>
- 動態島 compact／expanded 是否正常：<正常／異常說明／機型無動態島>
- **結論**：<可用／需調整，說明>
```

- [ ] **Step 11: Commit**

```bash
cd ~/Developer/MushroomTimer && git add -A && git commit -m "$(cat <<'EOF'
feat: add Live Activity layouts and verify they work without App Groups

All display data travels in ContentState because the widget process
cannot reach the app's database. Countdowns use Text(timerInterval:),
so no background work is needed to keep them ticking.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: 【驗證】共享 Keychain

驗證主 App 與 Widget extension 能否透過共享 Keychain 交換資料。這是小工具唯一能拿到「要顯示哪些菇」的管道（見設計文件 §3.2）。

**Files:**
- Create: `Shared/SharedKeychain.swift`
- Create: `Shared/WidgetPayload.swift`
- Modify: `MushroomTimerWidgets/MushroomTimerWidgetBundle.swift`
- Modify: `MushroomTimer/Views/VerificationView.swift`
- Modify: `docs/verification-results.md`
- Test: `MushroomTimerTests/WidgetPayloadTests.swift`

**Interfaces:**
- Consumes: 無
- Produces:
  - `WidgetPayload { groupName: String, mushrooms: [WidgetPayload.Item] }`、`WidgetPayload.Item { id: UUID, name: String }`
  - `WidgetPayload.empty: WidgetPayload`
  - `SharedKeychain.save(_ payload: WidgetPayload) -> Bool`
  - `SharedKeychain.load() -> WidgetPayload?`
  - `SharedKeychain.accessGroup: String?`（供驗證畫面顯示是否解析成功）

- [ ] **Step 1: 寫 WidgetPayload 的失敗測試**

`MushroomTimerTests/WidgetPayloadTests.swift`：

```swift
import XCTest
@testable import MushroomTimer

final class WidgetPayloadTests: XCTestCase {
    /// payload 會經過 JSON 存進 keychain 再被 widget 讀出，必須能完整還原。
    func testRoundTripsThroughJSON() throws {
        let original = WidgetPayload(
            groupName: "中山路口",
            mushrooms: [
                .init(id: UUID(), name: "7-11 門口"),
                .init(id: UUID(), name: "天橋下")
            ]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetPayload.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testEmptyPayloadHasNoMushrooms() {
        XCTAssertTrue(WidgetPayload.empty.mushrooms.isEmpty)
    }

    /// 小工具最多放 3 顆按鈕，超過的要截掉。
    func testMakeLimitsToThreeMushrooms() {
        let payload = WidgetPayload.make(
            groupName: "中山路口",
            mushrooms: [
                (UUID(), "一"), (UUID(), "二"), (UUID(), "三"), (UUID(), "四")
            ]
        )
        XCTAssertEqual(payload.mushrooms.map(\.name), ["一", "二", "三"])
    }
}
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 編譯失敗，`cannot find 'WidgetPayload' in scope`

- [ ] **Step 3: 實作 WidgetPayload**

`Shared/WidgetPayload.swift`：

```swift
import Foundation

/// 小工具要顯示的精簡資料。
///
/// Widget extension 讀不到主 App 的 SwiftData 資料庫，所以主 App 每次資料異動時
/// 把這份 payload 寫進共享 keychain，小工具只負責讀。
struct WidgetPayload: Codable, Equatable {
    struct Item: Codable, Equatable, Identifiable {
        var id: UUID
        var name: String
    }

    var groupName: String
    var mushrooms: [Item]

    static let empty = WidgetPayload(groupName: "", mushrooms: [])

    /// 小工具版面最多容納 3 顆按鈕。
    static let maxMushrooms = 3

    static func make(groupName: String, mushrooms: [(UUID, String)]) -> WidgetPayload {
        WidgetPayload(
            groupName: groupName,
            mushrooms: mushrooms.prefix(maxMushrooms).map { Item(id: $0.0, name: $0.1) }
        )
    }
}
```

- [ ] **Step 4: 執行測試確認通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 實作 SharedKeychain**

`Shared/SharedKeychain.swift`。

要點：keychain 的 access group 在程式碼裡必須寫成 `<TeamID>.com.chaoyu.MushroomTimer.shared`，但我們不想把 Team ID 放進 git。做法是在執行期探測：寫一個不指定 access group 的探測項目，再讀回它的 `kSecAttrAccessGroup`，字串的第一段就是 Team ID prefix。

```swift
import Foundation
import Security

/// 主 App 與 Widget extension 之間唯一的資料通道。
///
/// 免費帳號不能用 App Groups，但可以用 Keychain Sharing。
/// 主 App 寫、Widget extension 讀，兩邊的 entitlement 都宣告同一個 access group。
enum SharedKeychain {
    private static let groupSuffix = "com.chaoyu.MushroomTimer.shared"
    private static let service = "MushroomTimer"
    private static let account = "widget-payload"

    /// 完整的 access group（`<TeamID>.com.chaoyu.MushroomTimer.shared`）。
    /// Team ID 不寫死在程式碼裡，改成執行期探測，避免把個人 Team ID 提交進 git。
    ///
    /// 只快取成功的結果。若用 `static let` 連失敗也一起快取，那麼只要 process
    /// 第一次求值時剛好失敗，這個 process 的餘生就再也讀不到 payload 了。
    private static var cachedAccessGroup: String?

    static var accessGroup: String? {
        if let cachedAccessGroup { return cachedAccessGroup }
        guard let prefix = teamIdentifierPrefix() else { return nil }
        let group = "\(prefix).\(groupSuffix)"
        cachedAccessGroup = group
        return group
    }

    @discardableResult
    static func save(_ payload: WidgetPayload) -> Bool {
        guard let accessGroup, let data = try? JSONEncoder().encode(payload) else {
            return false
        }
        var query = baseQuery(accessGroup: accessGroup)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load() -> WidgetPayload? {
        guard let accessGroup else { return nil }
        var query = baseQuery(accessGroup: accessGroup)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(WidgetPayload.self, from: data)
    }

    private static func baseQuery(accessGroup: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: accessGroup
        ]
    }

    /// 用一個探測項目問系統「我的 Team ID prefix 是什麼」。
    /// 不指定 access group 時系統會塞進 entitlement 裡的第一個群組，
    /// 讀回該群組字串的第一段即為 prefix。
    private static func teamIdentifierPrefix() -> String? {
        // 探測項目的保護等級必須跟 payload 一致。少了 kSecAttrAccessible 會落到
        // 預設的 kSecAttrAccessibleWhenUnlocked，鎖屏時查不到也加不進去——
        // 而小工具的 timeline 更新剛好常在鎖屏狀態發生。
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "team-id-probe",
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecReturnAttributes as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        var status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            status = SecItemAdd(query as CFDictionary, &result)
        }
        guard status == errSecSuccess,
              let attributes = result as? [String: Any],
              let group = attributes[kSecAttrAccessGroup as String] as? String,
              let prefix = group.components(separatedBy: ".").first,
              !prefix.isEmpty else { return nil }
        return prefix
    }
}
```

- [ ] **Step 6: 讓佔位小工具顯示 keychain 讀到的內容**

把 `MushroomTimerWidgets/MushroomTimerWidgetBundle.swift` 裡的 `EmptyWidget`、`PlaceholderEntry`、`PlaceholderProvider` 三個型別整段替換成：

```swift
/// 第 0 階段驗證用：把從共享 keychain 讀到的內容直接畫出來。
/// Task 15 會換成真正的互動式小工具。
struct EmptyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Placeholder", provider: PlaceholderProvider()) { entry in
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.payload.groupName.isEmpty ? "（無群組）" : entry.payload.groupName)
                    .font(.caption.bold())
                ForEach(entry.payload.mushrooms) { item in
                    Text(item.name).font(.caption2)
                }
                if entry.payload.mushrooms.isEmpty {
                    Text("讀不到 payload").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("打菇茜")
        .description("快速登記一顆菇。")
        .supportedFamilies([.systemSmall])
    }
}

struct PlaceholderEntry: TimelineEntry {
    let date: Date
    let payload: WidgetPayload
}

struct PlaceholderProvider: TimelineProvider {
    private func currentEntry() -> PlaceholderEntry {
        PlaceholderEntry(date: .now, payload: SharedKeychain.load() ?? .empty)
    }

    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: .now, payload: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }
}
```

- [ ] **Step 7: 在驗證畫面加上 keychain 寫入按鈕**

在 `VerificationView.swift` 最上方加入 `import WidgetKit`，並在 `Section("記錄")` 之前插入：

```swift
            Section("共享 Keychain") {
                Button("顯示 access group") {
                    append("access group：\(SharedKeychain.accessGroup ?? "解析失敗")")
                }
                Button("寫入測試 payload") {
                    let payload = WidgetPayload.make(
                        groupName: "中山路口",
                        mushrooms: [(UUID(), "7-11 門口"), (UUID(), "天橋下")]
                    )
                    let ok = SharedKeychain.save(payload)
                    WidgetCenter.shared.reloadAllTimelines()
                    append("寫入 payload：\(ok ? "成功" : "失敗")")
                }
                Button("讀回 payload") {
                    if let payload = SharedKeychain.load() {
                        append("讀到：\(payload.groupName) / \(payload.mushrooms.map(\.name).joined(separator: "、"))")
                    } else {
                        append("讀取失敗")
                    }
                }
            }
```

- [ ] **Step 8: 確認可以建置**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: 【使用者手動】實機驗證 Keychain 共享**

**必須停下來請使用者操作並回報結果。** 驗證項目：

1. 點「顯示 access group」，確認顯示的是 `<一串英數>.com.chaoyu.MushroomTimer.shared` 而非「解析失敗」
2. 點「寫入測試 payload」，確認顯示「成功」
3. 點「讀回 payload」，確認讀到「中山路口 / 7-11 門口、天橋下」（這證明**同一個 process** 可讀寫）
4. 回到桌面，長按空白處 → 加入「打菇茜」小工具
5. 確認小工具顯示「中山路口 / 7-11 門口 / 天橋下」——**這才是跨 process 成功的證據**
6. **鎖屏狀態下再驗一次**：鎖住手機，等小工具自行更新一輪之後解鎖，確認內容仍然正確。
   小工具的 timeline 更新常在鎖屏時發生，若 keychain 項目的保護等級選錯，
   只有這一步抓得到——前面幾步都是在解鎖狀態下操作，一定會過。

- [ ] **Step 10: 記錄驗證結果並決定小工具方案**

在 `docs/verification-results.md` 追加：

```markdown
## 共享 Keychain（Task 4）

- access group 是否解析成功：<是／否>
- 主 App 內寫入後讀回：<成功／失敗>
- 小工具是否顯示出主 App 寫入的內容：<是／否>
- **結論**：<採用 keychain 方案，小工具按鈕顯示菇名／改用 fallback：按鈕顯示「最常用 #1/#2/#3」>
```

若小工具讀不到（跨 process 失敗），Task 15 改走設計文件 §3.2 的 fallback：小工具按鈕顯示固定文字「最常用 #1／#2／#3」，按下時才在主 App process 內解析對應到哪顆菇。

- [ ] **Step 11: Commit**

```bash
cd ~/Developer/MushroomTimer && git add -A && git commit -m "$(cat <<'EOF'
feat: add shared keychain channel between app and widget

The widget process cannot read the app's database without App Groups, so
the app writes a small JSON payload into a shared keychain item that the
widget's timeline provider reads. The team-ID prefix is probed at runtime
so it never has to be committed.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: 【驗證】小工具按鈕 Intent 的執行 process

驗證從小工具按鈕觸發的 App Intent 遵循 `LiveActivityIntent` 後，確實在**主 App 的 process** 執行（而非 Widget extension process）。這是小工具能寫入資料庫的前提（見設計文件 §3.1）。

**Files:**
- Create: `Shared/QuickLogIntent.swift`
- Modify: `MushroomTimerWidgets/MushroomTimerWidgetBundle.swift`
- Modify: `MushroomTimer/Views/VerificationView.swift`
- Modify: `docs/verification-results.md`
- Test: `MushroomTimerTests/IntentProcessMarkerTests.swift`

**Interfaces:**
- Consumes: `WidgetPayload`（Task 4）
- Produces:
  - `QuickLogIntent`（`AppIntent & LiveActivityIntent`），參數 `mushroomID: String`、`mushroomName: String`
  - `IntentProcessMarker.record(processName:bundleID:)`／`IntentProcessMarker.latest -> String?`（把 Intent 執行時所在的 process 記錄到 UserDefaults，供驗證畫面讀取）

- [ ] **Step 1: 寫 IntentProcessMarker 的失敗測試**

`MushroomTimerTests/IntentProcessMarkerTests.swift`：

```swift
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
}
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 編譯失敗，`cannot find 'IntentProcessMarker' in scope`

- [ ] **Step 3: 實作 QuickLogIntent 與 IntentProcessMarker**

`Shared/QuickLogIntent.swift`。放在 `Shared/` 是必要的：Widget extension 需要它來宣告按鈕，主 App 需要它來執行。

```swift
import AppIntents
import Foundation

/// 記錄 Intent 是在哪一個 process 執行的。第 0 階段驗證用，Task 19 移除。
enum IntentProcessMarker {
    private static let key = "intent-process-marker"

    static func record(
        processName: String,
        bundleID: String,
        defaults: UserDefaults = .standard
    ) {
        defaults.set("\(processName) / \(bundleID)", forKey: key)
    }

    static func latest(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: key)
    }
}

/// 小工具按鈕觸發的登記 Intent。
///
/// 關鍵：從小工具按鈕觸發的 App Intent **預設在 Widget extension 的 process 執行**，
/// 那個 process 讀不到主 App 的 SwiftData 資料庫。遵循 `LiveActivityIntent` 之後，
/// 系統會改在主 App 的 process 背景執行（不會開啟 App 畫面）。
struct QuickLogIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "快速登記"
    static var description = IntentDescription("以「剛爆」登記指定的菇。")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "菇 ID")
    var mushroomID: String

    @Parameter(title: "菇名稱")
    var mushroomName: String

    init() {}

    init(mushroomID: String, mushroomName: String) {
        self.mushroomID = mushroomID
        self.mushroomName = mushroomName
    }

    func perform() async throws -> some IntentResult {
        IntentProcessMarker.record(
            processName: ProcessInfo.processInfo.processName,
            bundleID: Bundle.main.bundleIdentifier ?? "unknown"
        )
        return .result()
    }
}
```

- [ ] **Step 4: 執行測試確認通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 在佔位小工具加上按鈕**

在 `MushroomTimerWidgetBundle.swift` 的 `EmptyWidget` 版面中，把 `ForEach(entry.payload.mushrooms) { item in Text(item.name).font(.caption2) }` 換成：

```swift
                ForEach(entry.payload.mushrooms) { item in
                    Button(
                        intent: QuickLogIntent(
                            mushroomID: item.id.uuidString,
                            mushroomName: item.name
                        )
                    ) {
                        Text(item.name).font(.caption2)
                    }
                    .buttonStyle(.bordered)
                }
```

- [ ] **Step 6: 在驗證畫面加上讀取 marker 的按鈕**

在 `VerificationView.swift` 的「共享 Keychain」section 之後插入：

```swift
            Section("Intent 執行 process") {
                Button("讀取最後一次 Intent 的 process") {
                    append("Intent process：\(IntentProcessMarker.latest() ?? "尚未執行過")")
                }
            }
```

- [ ] **Step 7: 確認可以建置**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: 【使用者手動】實機驗證 Intent 的執行 process**

**必須停下來請使用者操作並回報結果。** 驗證項目：

1. 在 App 內點「寫入測試 payload」，確保小工具有按鈕可按
2. 回到桌面，在小工具上按下其中一顆菇的按鈕（**注意 App 不應被開啟**）
3. 回到 App，點「讀取最後一次 Intent 的 process」
4. 期望顯示 `MushroomTimer / com.chaoyu.MushroomTimer`
   - 若顯示 `MushroomTimerWidgets / com.chaoyu.MushroomTimer.Widgets` → `LiveActivityIntent` 沒有生效，需另尋方案
   - 若顯示「尚未執行過」→ 按鈕根本沒觸發 Intent

> 為什麼讀 UserDefaults 就能證明？因為兩個 process 有各自獨立的 `UserDefaults.standard`（沒有 App Groups 就不共用）。主 App 讀得到這筆記錄，代表它就是寫入者，也就代表 Intent 是在主 App 的 process 執行的。

- [ ] **Step 9: 記錄驗證結果**

在 `docs/verification-results.md` 追加：

```markdown
## 小工具按鈕 Intent 的執行 process（Task 5）

- 按下小工具按鈕後 App 是否被開啟：<否／是>
- 主 App 讀到的 process 記錄：<實際字串>
- **結論**：<LiveActivityIntent 有效，Intent 在主 App process 執行／無效，說明>
```

- [ ] **Step 10: Commit**

```bash
cd ~/Developer/MushroomTimer && git add -A && git commit -m "$(cat <<'EOF'
verify: widget button intents run in the main app process

Conforming QuickLogIntent to LiveActivityIntent moves execution out of
the widget extension and into the app process, which is what lets it
reach SwiftData later. Proven by writing a marker to UserDefaults, which
is not shared between the two processes.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: DurationInput 輸入解析與格式化

使用者在數字鍵盤打「230」要被理解成 2:30（150 秒），計算結果要顯示成「7:15 後提醒 · 21:43:20」。這些都是純函式，是最適合 TDD 的部分。

**Files:**
- Create: `MushroomTimer/Models/DurationInput.swift`
- Test: `MushroomTimerTests/DurationInputTests.swift`

**Interfaces:**
- Consumes: 無
- Produces:
  - `DurationInput.seconds(fromDigits: String) -> Int?`（`nil` 代表輸入不合法）
  - `DurationInput.formatted(seconds: Int) -> String`（`435` → `"7:15"`）
  - `DurationInput.clockTime(_ date: Date) -> String`（`"21:43:20"`）
  - `DurationInput.maxDigits = 4`

- [ ] **Step 1: 寫失敗測試**

`MushroomTimerTests/DurationInputTests.swift`：

```swift
import XCTest
@testable import MushroomTimer

final class DurationInputTests: XCTestCase {
    func testFourDigitsAreMinutesAndSeconds() {
        XCTAssertEqual(DurationInput.seconds(fromDigits: "1230"), 12 * 60 + 30)
    }

    /// 規格範例：輸入「230」代表 2:30。
    func testThreeDigits() {
        XCTAssertEqual(DurationInput.seconds(fromDigits: "230"), 150)
    }

    func testTwoDigitsAreSecondsOnly() {
        XCTAssertEqual(DurationInput.seconds(fromDigits: "45"), 45)
    }

    func testOneDigitIsSecondsOnly() {
        XCTAssertEqual(DurationInput.seconds(fromDigits: "5"), 5)
    }

    /// 空字串代表使用者還沒輸入，視為 0 秒（等同「剛爆」）。
    func testEmptyIsZero() {
        XCTAssertEqual(DurationInput.seconds(fromDigits: ""), 0)
    }

    /// 秒數部分不可 ≥ 60，例如「270」不是合法的 2:70。
    func testRejectsSecondsAboveFiftyNine() {
        XCTAssertNil(DurationInput.seconds(fromDigits: "270"))
        XCTAssertNil(DurationInput.seconds(fromDigits: "160"))
    }

    func testRejectsNonDigits() {
        XCTAssertNil(DurationInput.seconds(fromDigits: "2:30"))
        XCTAssertNil(DurationInput.seconds(fromDigits: "abc"))
    }

    func testRejectsTooManyDigits() {
        XCTAssertNil(DurationInput.seconds(fromDigits: "12345"))
    }

    func testFormattedPadsSeconds() {
        XCTAssertEqual(DurationInput.formatted(seconds: 435), "7:15")
        XCTAssertEqual(DurationInput.formatted(seconds: 65), "1:05")
        XCTAssertEqual(DurationInput.formatted(seconds: 5), "0:05")
        XCTAssertEqual(DurationInput.formatted(seconds: 0), "0:00")
    }

    func testFormattedHandlesOverAnHour() {
        XCTAssertEqual(DurationInput.formatted(seconds: 3661), "61:01")
    }
}
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 編譯失敗，`cannot find 'DurationInput' in scope`

- [ ] **Step 3: 實作 DurationInput**

`MushroomTimer/Models/DurationInput.swift`：

```swift
import Foundation

/// 剩餘時間的輸入解析與顯示格式化。
///
/// 使用者只按數字鍵，最後兩位當秒、其餘當分：「230」= 2:30 = 150 秒。
enum DurationInput {
    /// 最多 4 位數，也就是 99:59。
    static let maxDigits = 4

    /// - Returns: 解析後的秒數；輸入含非數字、超長、或秒數 ≥ 60 時回傳 `nil`。
    static func seconds(fromDigits digits: String) -> Int? {
        guard digits.count <= maxDigits else { return nil }
        guard !digits.isEmpty else { return 0 }
        guard digits.allSatisfy(\.isNumber) else { return nil }

        let padded = String(repeating: "0", count: maxDigits - digits.count) + digits
        guard let minutes = Int(padded.prefix(2)),
              let seconds = Int(padded.suffix(2)),
              seconds < 60 else { return nil }
        return minutes * 60 + seconds
    }

    /// 秒數轉成 `分:秒`，秒補零。超過一小時仍以分計（例如 61:01）。
    static func formatted(seconds: Int) -> String {
        let clamped = max(0, seconds)
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }

    /// 時鐘時間，例如 `21:43:20`。用於「7:15 後提醒 · 21:43:20」的後半段。
    static func clockTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 4: 執行測試確認通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`，10 個 DurationInput 測試全數通過

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/MushroomTimer && git add -A && git commit -m "$(cat <<'EOF'
feat: parse digit-only duration input and format countdowns

Typing 230 means 2:30. The last two digits are seconds, the rest are
minutes, and a seconds component of 60 or more is rejected.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: SettingsStore

全域設定：菇的重生秒數與預設提前量。存 UserDefaults。

**Files:**
- Create: `MushroomTimer/Stores/SettingsStore.swift`
- Test: `MushroomTimerTests/SettingsStoreTests.swift`

**Interfaces:**
- Consumes: 無
- Produces:
  - `SettingsStore`（`ObservableObject`），`init(defaults: UserDefaults = .standard)`
  - `var respawnSeconds: Int`（預設 300，允許範圍 30...3600）
  - `var defaultLeadSeconds: Int`（預設 15，允許範圍 0...300）
  - `static let respawnRange`、`static let leadRange`

- [ ] **Step 1: 寫失敗測試**

`MushroomTimerTests/SettingsStoreTests.swift`：

```swift
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
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 編譯失敗，`cannot find 'SettingsStore' in scope`

- [ ] **Step 3: 實作 SettingsStore**

`MushroomTimer/Stores/SettingsStore.swift`：

```swift
import Foundation

/// 全域設定。存 UserDefaults 即可，資料量小且不需要跟資料庫一起查詢。
final class SettingsStore: ObservableObject {
    static let respawnRange = 30...3600
    static let leadRange = 0...300

    private enum Key {
        static let respawn = "respawnSeconds"
        static let lead = "defaultLeadSeconds"
    }

    private let defaults: UserDefaults

    /// 菇的重生時間。做成可調整，以防官方調整數值。
    @Published var respawnSeconds: Int {
        didSet {
            let clamped = Self.respawnRange.clamping(respawnSeconds)
            if clamped != respawnSeconds {
                respawnSeconds = clamped
                return
            }
            defaults.set(respawnSeconds, forKey: Key.respawn)
        }
    }

    /// 預設提前量。建立計時時會把當下的值快照進 `TimerEntry.leadSeconds`。
    @Published var defaultLeadSeconds: Int {
        didSet {
            let clamped = Self.leadRange.clamping(defaultLeadSeconds)
            if clamped != defaultLeadSeconds {
                defaultLeadSeconds = clamped
                return
            }
            defaults.set(defaultLeadSeconds, forKey: Key.lead)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedRespawn = defaults.object(forKey: Key.respawn) as? Int
        let storedLead = defaults.object(forKey: Key.lead) as? Int
        self.respawnSeconds = Self.respawnRange.clamping(storedRespawn ?? 300)
        self.defaultLeadSeconds = Self.leadRange.clamping(storedLead ?? 15)
    }
}

extension ClosedRange where Bound == Int {
    /// 把值夾在範圍內。
    func clamping(_ value: Int) -> Int {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
```

- [ ] **Step 4: 執行測試確認通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/MushroomTimer && git add -A && git commit -m "$(cat <<'EOF'
feat: add SettingsStore for respawn time and default lead

Values are clamped to sane ranges on both read and write so a corrupted
defaults entry cannot produce a nonsensical fireAt.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: SwiftData 資料模型

三張表與其關聯。SwiftData 是 iOS 17 的本機 ORM，等同帶 ORM 的本機 SQLite。

**Files:**
- Create: `MushroomTimer/Models/MushroomGroup.swift`
- Create: `MushroomTimer/Models/Mushroom.swift`
- Create: `MushroomTimer/Models/TimerEntry.swift`
- Modify: `MushroomTimer/MushroomTimerApp.swift`
- Test: `MushroomTimerTests/ModelTests.swift`

**Interfaces:**
- Consumes: 無
- Produces:
  - `@Model MushroomGroup`：`id, name, latitude, longitude, radius, createdAt, mushrooms`
  - `@Model Mushroom`：`id, name, useCount, lastUsedAt, group`
  - `@Model TimerEntry`：`id, mushroom, createdAt, remainingSeconds, leadSeconds, fireAt, statusRaw`，計算屬性 `status: TimerStatus`
  - `enum TimerStatus: String { active, fired, completed, cancelled }`
  - `ModelContainer.mushroomTimer(inMemory: Bool) throws -> ModelContainer`

- [ ] **Step 1: 寫失敗測試**

`MushroomTimerTests/ModelTests.swift`。測試用 in-memory container，不會碰到真實資料庫。

```swift
import SwiftData
import XCTest
@testable import MushroomTimer

@MainActor
final class ModelTests: XCTestCase {
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

    func testGroupDefaultsToEightyMetreRadius() {
        let group = MushroomGroup(name: "中山路口", latitude: 25.05, longitude: 121.52)
        XCTAssertEqual(group.radius, 80)
        XCTAssertTrue(group.mushrooms.isEmpty)
    }

    func testMushroomBelongsToGroup() throws {
        let group = MushroomGroup(name: "中山路口", latitude: 25.05, longitude: 121.52)
        context.insert(group)
        let mushroom = Mushroom(name: "7-11 門口", group: group)
        context.insert(mushroom)
        try context.save()

        let groups = try context.fetch(FetchDescriptor<MushroomGroup>())
        XCTAssertEqual(groups.first?.mushrooms.map(\.name), ["7-11 門口"])
        XCTAssertEqual(mushroom.useCount, 0)
        XCTAssertNil(mushroom.lastUsedAt)
    }

    /// 刪除群組要一併刪掉底下的菇（cascade）。
    func testDeletingGroupCascadesToMushrooms() throws {
        let group = MushroomGroup(name: "中山路口", latitude: 25.05, longitude: 121.52)
        context.insert(group)
        context.insert(Mushroom(name: "7-11 門口", group: group))
        context.insert(Mushroom(name: "天橋下", group: group))
        try context.save()

        context.delete(group)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Mushroom>()).count, 0)
    }

    func testTimerEntryStatusRoundTrips() throws {
        let group = MushroomGroup(name: "中山路口", latitude: 25.05, longitude: 121.52)
        context.insert(group)
        let mushroom = Mushroom(name: "7-11 門口", group: group)
        context.insert(mushroom)
        let entry = TimerEntry(
            mushroom: mushroom,
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            remainingSeconds: 150,
            leadSeconds: 15,
            fireAt: Date(timeIntervalSince1970: 1_000_435)
        )
        context.insert(entry)
        try context.save()

        XCTAssertEqual(entry.status, .active)
        entry.status = .completed
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<TimerEntry>())
        XCTAssertEqual(fetched.first?.status, .completed)
        XCTAssertEqual(fetched.first?.statusRaw, "completed")
    }

    /// leadSeconds 是快照：之後改全域設定不應影響已建立的計時。
    func testLeadSecondsIsStoredPerEntry() {
        let group = MushroomGroup(name: "中山路口", latitude: 25.05, longitude: 121.52)
        let mushroom = Mushroom(name: "7-11 門口", group: group)
        let entry = TimerEntry(
            mushroom: mushroom,
            createdAt: .now,
            remainingSeconds: 0,
            leadSeconds: 42,
            fireAt: .now.addingTimeInterval(258)
        )
        XCTAssertEqual(entry.leadSeconds, 42)
    }
}
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 編譯失敗，`cannot find 'MushroomGroup' in scope`

- [ ] **Step 3: 實作 MushroomGroup**

`MushroomTimer/Models/MushroomGroup.swift`。命名刻意不用 `Group`，因為 SwiftUI 已經有同名型別。

```swift
import Foundation
import SwiftData

/// 一個地理區域，例如「中山路口」。
@Model
final class MushroomGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    /// 判定半徑（公尺）。市區 GPS 誤差可達 10～30 公尺，預設放寬到 80。
    var radius: Double
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Mushroom.group)
    var mushrooms: [Mushroom]

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        radius: Double = 80,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.createdAt = createdAt
        self.mushrooms = []
    }
}
```

- [ ] **Step 4: 實作 Mushroom**

`MushroomTimer/Models/Mushroom.swift`：

```swift
import Foundation
import SwiftData

/// 隸屬於某個群組的一顆菇，例如「7-11 門口」。
@Model
final class Mushroom {
    @Attribute(.unique) var id: UUID
    var name: String
    /// 使用次數，主畫面的菇清單依此由高到低排序。
    var useCount: Int
    var lastUsedAt: Date?
    var group: MushroomGroup?

    init(
        id: UUID = UUID(),
        name: String,
        useCount: Int = 0,
        lastUsedAt: Date? = nil,
        group: MushroomGroup? = nil
    ) {
        self.id = id
        self.name = name
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
        self.group = group
    }
}
```

- [ ] **Step 5: 實作 TimerEntry 與 ModelContainer 工廠**

`MushroomTimer/Models/TimerEntry.swift`。命名不用 `Timer`，因為 Foundation 已經有同名型別。

狀態存成 `String` 而不是直接存 enum：SwiftData 在 iOS 17 對 enum 屬性的 `#Predicate` 查詢支援不完整，存字串可以正常寫查詢條件。

```swift
import Foundation
import SwiftData

enum TimerStatus: String, Codable, CaseIterable {
    /// 尚未到期。
    case active
    /// 已到期（開啟 App 或處理通知時才會被標記，因為本機通知不會喚醒 App）。
    case fired
    /// 使用者按了「已完成」。
    case completed
    /// 使用者左滑取消。
    case cancelled
}

/// 一筆進行中的提醒。
@Model
final class TimerEntry {
    @Attribute(.unique) var id: UUID
    var mushroom: Mushroom?
    var createdAt: Date
    /// 使用者輸入的剩餘秒數。
    var remainingSeconds: Int
    /// 本筆使用的提前量快照。使用者之後改全域預設值不影響已建立的計時。
    var leadSeconds: Int
    var fireAt: Date
    /// 以字串儲存，讓 `#Predicate` 能正常比對。請透過 `status` 讀寫。
    var statusRaw: String

    var status: TimerStatus {
        get { TimerStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        mushroom: Mushroom?,
        createdAt: Date,
        remainingSeconds: Int,
        leadSeconds: Int,
        fireAt: Date,
        status: TimerStatus = .active
    ) {
        self.id = id
        self.mushroom = mushroom
        self.createdAt = createdAt
        self.remainingSeconds = remainingSeconds
        self.leadSeconds = leadSeconds
        self.fireAt = fireAt
        self.statusRaw = status.rawValue
    }
}

extension ModelContainer {
    /// 全 App 唯一的 schema 定義。測試用 `inMemory: true` 取得不落地的容器。
    static func mushroomTimer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([MushroomGroup.self, Mushroom.self, TimerEntry.self])
        let configuration = ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
```

- [ ] **Step 6: 把 ModelContainer 接到 App**

`MushroomTimer/MushroomTimerApp.swift` 全檔替換：

```swift
import SwiftData
import SwiftUI

@main
struct MushroomTimerApp: App {
    private let container: ModelContainer
    @StateObject private var settings = SettingsStore()

    init() {
        do {
            container = try ModelContainer.mushroomTimer()
        } catch {
            fatalError("無法建立資料庫：\(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(settings)
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 7: 執行測試確認通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
cd ~/Developer/MushroomTimer && git add -A && git commit -m "$(cat <<'EOF'
feat: add SwiftData models for groups, mushrooms, and timers

Timer status is persisted as a raw string because #Predicate cannot
match enum properties reliably on iOS 17. leadSeconds is stored per
entry so changing the global default never rewrites existing timers.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: MushroomLogger 登記管線

「登記一顆菇」的唯一入口。主畫面、App Intents、桌面小工具全部走這條管線，確保三個入口的行為完全一致。同時提供查詢輔助函式給主畫面與後續的小工具／Live Activity 使用。

**Files:**
- Create: `MushroomTimer/Services/MushroomLogger.swift`
- Create: `MushroomTimer/Services/TimerQueries.swift`
- Test: `MushroomTimerTests/MushroomLoggerTests.swift`
- Test: `MushroomTimerTests/TimerQueriesTests.swift`

**Interfaces:**
- Consumes: `TimerCalculator.fireAt(now:remainingSeconds:respawnSeconds:leadSeconds:)`（Task 1）、`MushroomGroup`／`Mushroom`／`TimerEntry`／`TimerStatus`（Task 8）、`NotificationService.shared`（Task 2）
- Produces:
  - `MushroomLogger.log(mushroom:remainingSeconds:leadSeconds:respawnSeconds:context:now:) async throws -> TimerEntry`
  - `MushroomLogger.LogError.timeAlreadyPassed`
  - `MushroomLogger.cancel(_ entry: TimerEntry, context: ModelContext) throws`
  - `MushroomLogger.complete(_ entry: TimerEntry, context: ModelContext) throws`
  - `TimerQueries.active(in: ModelContext) throws -> [TimerEntry]`（依 `fireAt` 由近到遠）
  - `TimerQueries.markFired(in: ModelContext, now: Date) throws`
  - `TimerQueries.mostUsed(in: MushroomGroup, limit: Int) -> [Mushroom]`

- [ ] **Step 1: 寫 TimerQueries 的失敗測試**

`MushroomTimerTests/TimerQueriesTests.swift`：

```swift
import SwiftData
import XCTest
@testable import MushroomTimer

@MainActor
final class TimerQueriesTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private let now = Date(timeIntervalSince1970: 1_000_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer.mushroomTimer(inMemory: true)
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    private func makeGroup() -> MushroomGroup {
        let group = MushroomGroup(name: "中山路口", latitude: 25.05, longitude: 121.52)
        context.insert(group)
        return group
    }

    @discardableResult
    private func makeEntry(offset: TimeInterval, status: TimerStatus = .active) -> TimerEntry {
        let mushroom = Mushroom(name: "菇\(offset)", group: makeGroup())
        context.insert(mushroom)
        let entry = TimerEntry(
            mushroom: mushroom,
            createdAt: now,
            remainingSeconds: 0,
            leadSeconds: 15,
            fireAt: now.addingTimeInterval(offset),
            status: status
        )
        context.insert(entry)
        return entry
    }

    func testActiveIsSortedByFireAtAscending() throws {
        makeEntry(offset: 300)
        makeEntry(offset: 100)
        makeEntry(offset: 200)
        try context.save()

        let fireAts = try TimerQueries.active(in: context).map(\.fireAt)
        XCTAssertEqual(fireAts, [
            now.addingTimeInterval(100),
            now.addingTimeInterval(200),
            now.addingTimeInterval(300)
        ])
    }

    func testActiveExcludesNonActiveStatuses() throws {
        makeEntry(offset: 100)
        makeEntry(offset: 200, status: .cancelled)
        makeEntry(offset: 300, status: .completed)
        makeEntry(offset: 400, status: .fired)
        try context.save()

        XCTAssertEqual(try TimerQueries.active(in: context).count, 1)
    }

    /// 本機通知不會喚醒 App，所以到期的計時是在下次開 App 時才標記。
    func testMarkFiredFlipsExpiredActiveEntries() throws {
        makeEntry(offset: -10)
        makeEntry(offset: 100)
        try context.save()

        try TimerQueries.markFired(in: context, now: now)

        let all = try context.fetch(FetchDescriptor<TimerEntry>())
        XCTAssertEqual(all.filter { $0.status == .fired }.count, 1)
        XCTAssertEqual(all.filter { $0.status == .active }.count, 1)
    }

    func testMostUsedSortsByUseCountDescending() {
        let group = makeGroup()
        let a = Mushroom(name: "少", useCount: 1, group: group)
        let b = Mushroom(name: "多", useCount: 9, group: group)
        let c = Mushroom(name: "中", useCount: 5, group: group)
        [a, b, c].forEach(context.insert)
        group.mushrooms = [a, b, c]

        XCTAssertEqual(
            TimerQueries.mostUsed(in: group, limit: 2).map(\.name),
            ["多", "中"]
        )
    }
}
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 編譯失敗，`cannot find 'TimerQueries' in scope`

- [ ] **Step 3: 實作 TimerQueries**

`MushroomTimer/Services/TimerQueries.swift`：

```swift
import Foundation
import SwiftData

/// 資料庫查詢的集中處。主畫面、小工具 payload、Live Activity 都由這裡取資料，
/// 避免同樣的排序規則在多處各寫一次。
@MainActor
enum TimerQueries {
    /// 進行中的計時，依 `fireAt` 由近到遠。
    static func active(in context: ModelContext) throws -> [TimerEntry] {
        let activeRaw = TimerStatus.active.rawValue
        var descriptor = FetchDescriptor<TimerEntry>(
            predicate: #Predicate { $0.statusRaw == activeRaw },
            sortBy: [SortDescriptor(\.fireAt, order: .forward)]
        )
        descriptor.includePendingChanges = true
        return try context.fetch(descriptor)
    }

    /// 把已過期的 active 計時標記成 fired。
    ///
    /// 本機通知響起時不會喚醒 App，所以狀態是惰性更新的：
    /// 在 App 進入前景、或處理通知動作時呼叫一次即可。
    static func markFired(in context: ModelContext, now: Date = .now) throws {
        for entry in try active(in: context) where entry.fireAt <= now {
            entry.status = .fired
        }
        try context.save()
    }

    /// 群組內最常用的幾顆菇，依 `useCount` 由高到低。
    static func mostUsed(in group: MushroomGroup, limit: Int) -> [Mushroom] {
        Array(
            group.mushrooms
                .sorted { ($0.useCount, $0.name) > ($1.useCount, $1.name) }
                .prefix(limit)
        )
    }
}
```

- [ ] **Step 4: 執行測試確認通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 寫 MushroomLogger 的失敗測試**

`MushroomTimerTests/MushroomLoggerTests.swift`：

```swift
import SwiftData
import XCTest
@testable import MushroomTimer

@MainActor
final class MushroomLoggerTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private let now = Date(timeIntervalSince1970: 1_000_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer.mushroomTimer(inMemory: true)
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    private func makeMushroom() -> Mushroom {
        let group = MushroomGroup(name: "中山路口", latitude: 25.05, longitude: 121.52)
        context.insert(group)
        let mushroom = Mushroom(name: "7-11 門口", group: group)
        context.insert(mushroom)
        return mushroom
    }

    func testLogCreatesEntryWithCalculatedFireAt() async throws {
        let mushroom = makeMushroom()
        let entry = try await MushroomLogger.log(
            mushroom: mushroom,
            remainingSeconds: 150,
            leadSeconds: 15,
            respawnSeconds: 300,
            context: context,
            now: now
        )

        XCTAssertEqual(entry.fireAt, now.addingTimeInterval(435))
        XCTAssertEqual(entry.leadSeconds, 15)
        XCTAssertEqual(entry.remainingSeconds, 150)
        XCTAssertEqual(entry.status, .active)
        XCTAssertEqual(entry.mushroom?.id, mushroom.id)
    }

    func testLogBumpsUseCountAndLastUsedAt() async throws {
        let mushroom = makeMushroom()
        _ = try await MushroomLogger.log(
            mushroom: mushroom, remainingSeconds: 0, leadSeconds: 15,
            respawnSeconds: 300, context: context, now: now
        )
        _ = try await MushroomLogger.log(
            mushroom: mushroom, remainingSeconds: 0, leadSeconds: 15,
            respawnSeconds: 300, context: context, now: now
        )

        XCTAssertEqual(mushroom.useCount, 2)
        XCTAssertEqual(mushroom.lastUsedAt, now)
    }

    func testLogThrowsWhenResultIsInThePast() async {
        let mushroom = makeMushroom()
        do {
            _ = try await MushroomLogger.log(
                mushroom: mushroom, remainingSeconds: 0, leadSeconds: 400,
                respawnSeconds: 300, context: context, now: now
            )
            XCTFail("應該要丟出 timeAlreadyPassed")
        } catch MushroomLogger.LogError.timeAlreadyPassed {
            // 正確
        } catch {
            XCTFail("丟出非預期的錯誤：\(error)")
        }
    }

    func testFailedLogDoesNotCreateEntryOrBumpUseCount() async throws {
        let mushroom = makeMushroom()
        _ = try? await MushroomLogger.log(
            mushroom: mushroom, remainingSeconds: 0, leadSeconds: 400,
            respawnSeconds: 300, context: context, now: now
        )
        XCTAssertEqual(try context.fetch(FetchDescriptor<TimerEntry>()).count, 0)
        XCTAssertEqual(mushroom.useCount, 0)
    }

    func testCancelMarksEntryCancelled() async throws {
        let mushroom = makeMushroom()
        let entry = try await MushroomLogger.log(
            mushroom: mushroom, remainingSeconds: 0, leadSeconds: 15,
            respawnSeconds: 300, context: context, now: now
        )
        try MushroomLogger.cancel(entry, context: context)
        XCTAssertEqual(entry.status, .cancelled)
        XCTAssertEqual(try TimerQueries.active(in: context).count, 0)
    }

    func testCompleteMarksEntryCompleted() async throws {
        let mushroom = makeMushroom()
        let entry = try await MushroomLogger.log(
            mushroom: mushroom, remainingSeconds: 0, leadSeconds: 15,
            respawnSeconds: 300, context: context, now: now
        )
        try MushroomLogger.complete(entry, context: context)
        XCTAssertEqual(entry.status, .completed)
    }
}
```

- [ ] **Step 6: 執行測試確認失敗**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 編譯失敗，`cannot find 'MushroomLogger' in scope`

- [ ] **Step 7: 實作 MushroomLogger**

`MushroomTimer/Services/MushroomLogger.swift`：

```swift
import Foundation
import SwiftData

/// 「登記一顆菇」的唯一入口。主畫面、App Intents、桌面小工具全部走這裡，
/// 三個入口的副作用（寫資料庫、排通知、更新使用次數）因此保證一致。
@MainActor
enum MushroomLogger {
    enum LogError: LocalizedError {
        /// 剩餘時間加重生時間扣掉提前量後已經是過去，不建立計時。
        case timeAlreadyPassed

        var errorDescription: String? {
            switch self {
            case .timeAlreadyPassed:
                return "時間已過，無法建立提醒"
            }
        }
    }

    @discardableResult
    static func log(
        mushroom: Mushroom,
        remainingSeconds: Int,
        leadSeconds: Int,
        respawnSeconds: Int,
        context: ModelContext,
        now: Date = .now
    ) async throws -> TimerEntry {
        guard let fireAt = TimerCalculator.fireAt(
            now: now,
            remainingSeconds: remainingSeconds,
            respawnSeconds: respawnSeconds,
            leadSeconds: leadSeconds
        ) else {
            throw LogError.timeAlreadyPassed
        }

        let entry = TimerEntry(
            mushroom: mushroom,
            createdAt: now,
            remainingSeconds: remainingSeconds,
            leadSeconds: leadSeconds,
            fireAt: fireAt
        )
        context.insert(entry)
        mushroom.useCount += 1
        mushroom.lastUsedAt = now
        try context.save()

        try? await NotificationService.shared.schedule(
            id: entry.id,
            groupName: mushroom.group?.name ?? "",
            mushroomName: mushroom.name,
            at: fireAt
        )

        return entry
    }

    /// 使用者左滑取消。連帶把已排定的通知撤掉。
    static func cancel(_ entry: TimerEntry, context: ModelContext) throws {
        entry.status = .cancelled
        NotificationService.shared.cancel(id: entry.id)
        try context.save()
    }

    /// 使用者按「已完成」。
    static func complete(_ entry: TimerEntry, context: ModelContext) throws {
        entry.status = .completed
        NotificationService.shared.cancel(id: entry.id)
        try context.save()
    }
}
```

- [ ] **Step 8: 執行測試確認通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 9: Commit**

```bash
cd ~/Developer/MushroomTimer && git add -A && git commit -m "$(cat <<'EOF'
feat: add the shared mushroom logging pipeline

Every entry point — main screen, App Intents, widget button — creates
timers through MushroomLogger, so the side effects stay identical. A
fireAt in the past aborts before anything is written.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: 群組與菇的 CRUD 畫面

管理群組與菇的清單。刪除群組會連帶刪掉底下的菇，因此需要二次確認。

**Files:**
- Create: `MushroomTimer/Views/GroupListView.swift`
- Create: `MushroomTimer/Views/MushroomListView.swift`
- Modify: `MushroomTimer/Views/MainView.swift`

**Interfaces:**
- Consumes: `MushroomGroup`／`Mushroom`（Task 8）
- Produces:
  - `GroupListView`（無參數）
  - `MushroomListView(group: MushroomGroup)`

這個 task 沒有單元測試：內容全是 SwiftUI 版面與 SwiftData 的標準操作，值得測的邏輯（排序、cascade 刪除）已經在 Task 8、9 測過了。驗證方式是模擬器手動操作。

- [ ] **Step 1: 實作 GroupListView**

`MushroomTimer/Views/GroupListView.swift`：

```swift
import SwiftData
import SwiftUI

/// 群組的清單與 CRUD。
struct GroupListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MushroomGroup.createdAt, order: .reverse)
    private var groups: [MushroomGroup]

    @State private var pendingDeletion: MushroomGroup?

    var body: some View {
        List {
            if groups.isEmpty {
                ContentUnavailableView(
                    "還沒有群組",
                    systemImage: "mappin.slash",
                    description: Text("回主畫面按「建立新群組」，以目前位置建立第一個群組。")
                )
            }
            ForEach(groups) { group in
                NavigationLink(value: group) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                        Text("\(group.mushrooms.count) 顆菇 · 半徑 \(Int(group.radius)) 公尺")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button("刪除", role: .destructive) {
                        pendingDeletion = group
                    }
                }
            }
        }
        .navigationTitle("群組")
        .navigationDestination(for: MushroomGroup.self) { group in
            MushroomListView(group: group)
        }
        .alert(
            "刪除「\(pendingDeletion?.name ?? "")」？",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            )
        ) {
            Button("取消", role: .cancel) { pendingDeletion = nil }
            Button("刪除", role: .destructive) {
                if let group = pendingDeletion {
                    context.delete(group)
                    try? context.save()
                }
                pendingDeletion = nil
            }
        } message: {
            Text("底下的 \(pendingDeletion?.mushrooms.count ?? 0) 顆菇會一併刪除，且無法復原。")
        }
    }
}
```

- [ ] **Step 2: 實作 MushroomListView**

`MushroomTimer/Views/MushroomListView.swift`：

```swift
import SwiftData
import SwiftUI

/// 單一群組底下的菇清單與 CRUD。
struct MushroomListView: View {
    @Environment(\.modelContext) private var context
    let group: MushroomGroup

    @State private var isAddingMushroom = false
    @State private var draftName = ""
    @State private var editingGroupName = false
    @State private var draftGroupName = ""

    private var sortedMushrooms: [Mushroom] {
        TimerQueries.mostUsed(in: group, limit: group.mushrooms.count)
    }

    var body: some View {
        List {
            Section("菇") {
                if group.mushrooms.isEmpty {
                    Text("還沒有菇，按下方「新增菇」建立。")
                        .foregroundStyle(.secondary)
                }
                ForEach(sortedMushrooms) { mushroom in
                    HStack {
                        Text(mushroom.name)
                        Spacer()
                        Text("\(mushroom.useCount) 次")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("刪除", role: .destructive) {
                            context.delete(mushroom)
                            try? context.save()
                        }
                    }
                }
                Button("新增菇") {
                    draftName = ""
                    isAddingMushroom = true
                }
            }

            Section("群組設定") {
                Button("重新命名群組") {
                    draftGroupName = group.name
                    editingGroupName = true
                }
                LabeledContent("判定半徑", value: "\(Int(group.radius)) 公尺")
                Slider(
                    value: Binding(
                        get: { group.radius },
                        set: { group.radius = $0; try? context.save() }
                    ),
                    in: 20...300,
                    step: 10
                )
            }
        }
        .navigationTitle(group.name)
        .alert("新增菇", isPresented: $isAddingMushroom) {
            TextField("例如：7-11 門口", text: $draftName)
            Button("取消", role: .cancel) {}
            Button("新增") { addMushroom() }
        } message: {
            Text("取一個現場一眼認得出來的名字。")
        }
        .alert("重新命名群組", isPresented: $editingGroupName) {
            TextField("群組名稱", text: $draftGroupName)
            Button("取消", role: .cancel) {}
            Button("儲存") {
                let trimmed = draftGroupName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                group.name = trimmed
                try? context.save()
            }
        }
    }

    private func addMushroom() {
        let trimmed = draftName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let mushroom = Mushroom(name: trimmed, group: group)
        context.insert(mushroom)
        try? context.save()
    }
}
```

- [ ] **Step 3: 把群組管理接到 MainView**

`MushroomTimer/Views/MainView.swift` 全檔替換：

```swift
import SwiftUI

struct MainView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("群組與菇") {
                    GroupListView()
                }
                NavigationLink("第 0 階段驗證") {
                    VerificationView()
                }
            }
            .navigationTitle("打菇茜")
        }
    }
}
```

- [ ] **Step 4: 確認建置與測試通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 模擬器手動驗證**

在模擬器執行 App，依序確認：新增群組目前還沒有入口（Task 13 才會加上「以目前位置建立」），所以先確認清單顯示空狀態文字；用 Xcode 的 SwiftData 檢視或暫時在 `GroupListView` 加一顆測試按鈕都可以，但**不要把測試按鈕 commit 進去**。至少要確認：進入群組頁 → 新增兩顆菇 → 顯示使用次數 → 左滑刪除一顆 → 重新命名群組 → 調整半徑後數值有更新。

- [ ] **Step 6: Commit**

```bash
cd ~/Developer/MushroomTimer && git add -A && git commit -m "$(cat <<'EOF'
feat: add group and mushroom management screens

Deleting a group cascades to its mushrooms, so the delete action asks
for confirmation and states how many mushrooms will go with it.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: TimeInputSheet 剩餘時間輸入

點一顆菇之後跳出的輸入介面。要能在不打字（只按數字）的情況下完成，並即時顯示計算結果讓使用者確認。

**Files:**
- Create: `MushroomTimer/Views/TimeInputSheet.swift`
- Test: `MushroomTimerTests/TimeInputModelTests.swift`

**Interfaces:**
- Consumes: `DurationInput`（Task 6）、`TimerCalculator`（Task 1）
- Produces:
  - `TimeInputModel`（`@Observable` 的畫面狀態，可單獨測試）：`digits: String`、`leadSeconds: Int`、`append(_:)`、`deleteLast()`、`justPopped()`、`adjustLead(by:)`、`remainingSeconds -> Int?`、`preview(now:respawnSeconds:) -> String`
  - `TimeInputSheet(mushroomName:groupName:leadSeconds:respawnSeconds:onConfirm:)`，`onConfirm` 型別為 `(Int, Int) -> Void`（參數依序是 remainingSeconds、leadSeconds）

- [ ] **Step 1: 寫 TimeInputModel 的失敗測試**

`MushroomTimerTests/TimeInputModelTests.swift`：

```swift
import XCTest
@testable import MushroomTimer

final class TimeInputModelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testAppendBuildsDigits() {
        let model = TimeInputModel(leadSeconds: 15)
        model.append("2")
        model.append("3")
        model.append("0")
        XCTAssertEqual(model.digits, "230")
        XCTAssertEqual(model.remainingSeconds, 150)
    }

    func testAppendStopsAtMaxDigits() {
        let model = TimeInputModel(leadSeconds: 15)
        for digit in ["1", "2", "3", "4", "5"] {
            model.append(digit)
        }
        XCTAssertEqual(model.digits, "1234")
    }

    func testDeleteLast() {
        let model = TimeInputModel(leadSeconds: 15)
        model.append("2")
        model.append("3")
        model.deleteLast()
        XCTAssertEqual(model.digits, "2")
        model.deleteLast()
        model.deleteLast()
        XCTAssertEqual(model.digits, "")
    }

    func testJustPoppedClearsToZero() {
        let model = TimeInputModel(leadSeconds: 15)
        model.append("2")
        model.append("3")
        model.append("0")
        model.justPopped()
        XCTAssertEqual(model.digits, "")
        XCTAssertEqual(model.remainingSeconds, 0)
    }

    func testAdjustLeadStaysInRange() {
        let model = TimeInputModel(leadSeconds: 15)
        model.adjustLead(by: 5)
        XCTAssertEqual(model.leadSeconds, 20)
        model.adjustLead(by: -25)
        XCTAssertEqual(model.leadSeconds, 0)
        model.adjustLead(by: -5)
        XCTAssertEqual(model.leadSeconds, 0)
    }

    /// 規格範例：剩 2:30、重生 5:00、提前 15 秒 → 「7:15 後提醒 · 21:43:20」。
    func testPreviewShowsOffsetAndClockTime() {
        let model = TimeInputModel(leadSeconds: 15)
        model.append("2")
        model.append("3")
        model.append("0")
        let preview = model.preview(now: now, respawnSeconds: 300)
        XCTAssertTrue(preview.hasPrefix("7:15 後提醒 · "), "實際：\(preview)")
    }

    func testPreviewReportsInvalidInput() {
        let model = TimeInputModel(leadSeconds: 15)
        model.append("2")
        model.append("7")
        model.append("0")
        XCTAssertEqual(model.preview(now: now, respawnSeconds: 300), "輸入不正確")
    }

    func testPreviewReportsTimeAlreadyPassed() {
        let model = TimeInputModel(leadSeconds: 300)
        XCTAssertEqual(model.preview(now: now, respawnSeconds: 300), "時間已過")
    }
}
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 編譯失敗，`cannot find 'TimeInputModel' in scope`

- [ ] **Step 3: 實作 TimeInputModel 與 TimeInputSheet**

`MushroomTimer/Views/TimeInputSheet.swift`。畫面狀態抽成獨立的 `TimeInputModel`，才能不開模擬器就測到全部規則。

```swift
import SwiftUI

/// 輸入介面的狀態與規則。抽出來是為了能單獨測試。
@Observable
final class TimeInputModel {
    private(set) var digits = ""
    var leadSeconds: Int

    init(leadSeconds: Int) {
        self.leadSeconds = SettingsStore.leadRange.clamping(leadSeconds)
    }

    var remainingSeconds: Int? {
        DurationInput.seconds(fromDigits: digits)
    }

    func append(_ digit: String) {
        guard digits.count < DurationInput.maxDigits else { return }
        digits += digit
    }

    func deleteLast() {
        guard !digits.isEmpty else { return }
        digits.removeLast()
    }

    /// 「剛爆」：剩餘時間歸零。
    func justPopped() {
        digits = ""
    }

    func adjustLead(by delta: Int) {
        leadSeconds = SettingsStore.leadRange.clamping(leadSeconds + delta)
    }

    /// 即時預覽，例如「7:15 後提醒 · 21:43:20」。
    func preview(now: Date = .now, respawnSeconds: Int) -> String {
        guard let remainingSeconds else { return "輸入不正確" }
        guard let fireAt = TimerCalculator.fireAt(
            now: now,
            remainingSeconds: remainingSeconds,
            respawnSeconds: respawnSeconds,
            leadSeconds: leadSeconds
        ) else { return "時間已過" }

        let offset = Int(fireAt.timeIntervalSince(now).rounded())
        return "\(DurationInput.formatted(seconds: offset)) 後提醒 · \(DurationInput.clockTime(fireAt))"
    }
}

/// 剩餘時間輸入。所有按鈕都在畫面下半部，方便單手操作。
struct TimeInputSheet: View {
    let mushroomName: String
    let groupName: String
    let respawnSeconds: Int
    /// 參數依序是 remainingSeconds、leadSeconds。
    let onConfirm: (Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var model: TimeInputModel

    init(
        mushroomName: String,
        groupName: String,
        leadSeconds: Int,
        respawnSeconds: Int,
        onConfirm: @escaping (Int, Int) -> Void
    ) {
        self.mushroomName = mushroomName
        self.groupName = groupName
        self.respawnSeconds = respawnSeconds
        self.onConfirm = onConfirm
        _model = State(initialValue: TimeInputModel(leadSeconds: leadSeconds))
    }

    private var isConfirmable: Bool {
        guard let remaining = model.remainingSeconds else { return false }
        return TimerCalculator.fireAt(
            now: .now,
            remainingSeconds: remaining,
            respawnSeconds: respawnSeconds,
            leadSeconds: model.leadSeconds
        ) != nil
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(mushroomName).font(.title2.bold())
                Text(groupName).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.top, 24)

            Text(model.digits.isEmpty ? "剛爆" : DurationInput.formatted(
                seconds: model.remainingSeconds ?? 0
            ))
            .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(model.remainingSeconds == nil ? .red : .primary)

            Text(model.preview(respawnSeconds: respawnSeconds))
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("−5s") { model.adjustLead(by: -5) }
                Text("提前 \(model.leadSeconds) 秒")
                    .font(.subheadline)
                    .frame(minWidth: 90)
                Button("+5s") { model.adjustLead(by: 5) }
            }
            .buttonStyle(.bordered)

            Spacer(minLength: 0)

            keypad

            Button {
                guard let remaining = model.remainingSeconds else { return }
                onConfirm(remaining, model.leadSeconds)
                dismiss()
            } label: {
                Text("建立提醒")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isConfirmable)
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
    }

    private var keypad: some View {
        let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]
        return VStack(spacing: 10) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { digit in
                        keyButton(digit) { model.append(digit) }
                    }
                }
            }
            HStack(spacing: 10) {
                keyButton("剛爆") { model.justPopped() }
                keyButton("0") { model.append("0") }
                keyButton("⌫") { model.deleteLast() }
            }
        }
        .padding(.horizontal)
    }

    private func keyButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.title2.bold())
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.bordered)
    }
}
```

- [ ] **Step 4: 執行測試確認通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/MushroomTimer && git add -A && git commit -m "$(cat <<'EOF'
feat: add remaining-time input sheet

State lives in a testable TimeInputModel so the digit rules, lead
adjustment, and preview string are covered without a simulator. The
keypad sits at the bottom of the screen for one-handed use.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: MainView 主畫面

把 MVP 串起來：上半部是進行中的計時清單，下半部是快速登記區。

**Files:**
- Create: `MushroomTimer/Views/ActiveTimersSection.swift`
- Create: `MushroomTimer/Views/QuickLogSection.swift`
- Modify: `MushroomTimer/Views/MainView.swift`

**Interfaces:**
- Consumes: `TimerQueries`／`MushroomLogger`（Task 9）、`TimeInputSheet`（Task 11）、`SettingsStore`（Task 7）、`GroupListView`（Task 10）
- Produces:
  - `ActiveTimersSection`（無參數）
  - `QuickLogSection(group: MushroomGroup?, onChangeGroup: () -> Void, onCreateGroup: () -> Void)`
  - `MainView` 完整版

此時還沒有 GPS（Task 13），所以「目前群組」暫時用「最後使用過的群組」，並提供手動切換。Task 13 會把 GPS 判定接上去，手動切換保留。

- [ ] **Step 1: 實作 ActiveTimersSection**

`MushroomTimer/Views/ActiveTimersSection.swift`：

```swift
import SwiftData
import SwiftUI

/// `@Query` 的 filter 是屬性初始化式，不能引用型別自己的 static 成員，所以放在檔案層級。
private let activeStatusRaw = TimerStatus.active.rawValue

/// 主畫面上半部：進行中的計時，依 fireAt 由近到遠。
struct ActiveTimersSection: View {
    @Environment(\.modelContext) private var context

    @Query(
        filter: #Predicate<TimerEntry> { $0.statusRaw == activeStatusRaw },
        sort: \TimerEntry.fireAt,
        order: .forward
    )
    private var timers: [TimerEntry]

    var body: some View {
        Group {
            if timers.isEmpty {
                ContentUnavailableView(
                    "沒有進行中的提醒",
                    systemImage: "timer",
                    description: Text("在下方選一顆菇，輸入眼睛看到的剩餘時間就好。")
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(timers) { timer in
                        row(for: timer)
                            .swipeActions(edge: .leading) {
                                Button("取消", role: .destructive) {
                                    try? MushroomLogger.cancel(timer, context: context)
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func row(for timer: TimerEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(timer.mushroom?.name ?? "（已刪除的菇）")
                    .font(.headline)
                Text(timer.mushroom?.group?.name ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // 給定結束時間後元件自己逐秒跑動，不需要任何背景作業。
            // 範圍必須夾住：到期後這個 row 仍會被重新求值，
            // 而 lowerBound > upperBound 的 ClosedRange 會直接 trap。
            countdown(to: timer.fireAt)
                .font(.system(.title, design: .rounded).monospacedDigit().bold())
                .foregroundStyle(.orange)
        }
        .padding(.vertical, 4)
    }

    private func countdown(to date: Date) -> some View {
        let now = Date.now
        return Text(timerInterval: min(now, date)...max(now, date), countsDown: true)
    }
}
```

- [ ] **Step 2: 實作 QuickLogSection**

`MushroomTimer/Views/QuickLogSection.swift`：

```swift
import SwiftData
import SwiftUI

/// 主畫面下半部：目前群組 + 該群組的菇清單（依使用次數排序）。
struct QuickLogSection: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: SettingsStore

    let group: MushroomGroup?
    let onChangeGroup: () -> Void
    let onCreateGroup: () -> Void

    @State private var selectedMushroom: Mushroom?
    @State private var errorMessage: String?

    private var mushrooms: [Mushroom] {
        guard let group else { return [] }
        return TimerQueries.mostUsed(in: group, limit: group.mushrooms.count)
    }

    var body: some View {
        VStack(spacing: 8) {
            header

            if group == nil {
                Button("建立新群組", action: onCreateGroup)
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 8)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(mushrooms) { mushroom in
                            Button {
                                selectedMushroom = mushroom
                            } label: {
                                Text(mushroom.name)
                                    .font(.title3.bold())
                                    .frame(maxWidth: .infinity, minHeight: 60)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        if let group {
                            NavigationLink {
                                MushroomListView(group: group)
                            } label: {
                                Label("新增菇", systemImage: "plus")
                                    .frame(maxWidth: .infinity, minHeight: 60)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .sheet(item: $selectedMushroom) { mushroom in
            TimeInputSheet(
                mushroomName: mushroom.name,
                groupName: mushroom.group?.name ?? "",
                leadSeconds: settings.defaultLeadSeconds,
                respawnSeconds: settings.respawnSeconds
            ) { remainingSeconds, leadSeconds in
                log(mushroom, remainingSeconds: remainingSeconds, leadSeconds: leadSeconds)
            }
        }
        .alert(
            "無法建立",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.orange)
            Text(group?.name ?? "不在任何群組範圍內")
                .font(.headline)
            Spacer()
            Button("切換", action: onChangeGroup)
                .font(.subheadline)
        }
        .padding(.horizontal)
    }

    private func log(_ mushroom: Mushroom, remainingSeconds: Int, leadSeconds: Int) {
        Task {
            do {
                try await MushroomLogger.log(
                    mushroom: mushroom,
                    remainingSeconds: remainingSeconds,
                    leadSeconds: leadSeconds,
                    respawnSeconds: settings.respawnSeconds,
                    context: context
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
```

- [ ] **Step 3: 實作 MainView**

`MushroomTimer/Views/MainView.swift` 全檔替換：

```swift
import SwiftData
import SwiftUI

struct MainView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \MushroomGroup.createdAt, order: .reverse)
    private var groups: [MushroomGroup]

    @State private var selectedGroupID: UUID?
    @State private var isPickingGroup = false

    /// 目前群組。Task 13 會改成優先採用 GPS 判定的結果。
    private var currentGroup: MushroomGroup? {
        if let selectedGroupID,
           let match = groups.first(where: { $0.id == selectedGroupID }) {
            return match
        }
        return groups.first
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ActiveTimersSection()
                    .frame(maxHeight: .infinity)

                Divider()

                QuickLogSection(
                    group: currentGroup,
                    onChangeGroup: { isPickingGroup = true },
                    onCreateGroup: { isPickingGroup = true }
                )
                .frame(height: 300)
            }
            .navigationTitle("打菇茜")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        GroupListView()
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }
            }
            .confirmationDialog("選擇群組", isPresented: $isPickingGroup) {
                ForEach(groups) { group in
                    Button(group.name) { selectedGroupID = group.id }
                }
                Button("取消", role: .cancel) {}
            }
        }
        .task {
            await NotificationService.shared.requestAuthorization()
        }
        .onChange(of: scenePhase) { _, phase in
            // 本機通知不會喚醒 App，所以回到前景時補標記已到期的計時。
            if phase == .active {
                try? TimerQueries.markFired(in: context)
            }
        }
    }
}
```

- [ ] **Step 4: 確認建置與測試通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 模擬器手動驗證 MVP 全流程**

在模擬器執行 App，確認完整流程可走通：右上角進入群組管理 → 目前還沒有建立群組的入口，先用 `GroupListView` 手動確認空狀態 → **注意**：建立群組的按鈕要到 Task 13 才有，因此這一步先只驗證「已有群組時」的行為。若要提前驗證，可暫時在模擬器用 Xcode 的 Debug → Attach 手動插入資料，或直接跳到 Task 13 後回頭驗證。

至少確認：App 啟動不崩潰、通知權限對話框跳出、空狀態文字正確顯示、下半部顯示「不在任何群組範圍內」與「建立新群組」按鈕。

- [ ] **Step 6: Commit**

```bash
cd ~/Developer/MushroomTimer && git add -A && git commit -m "$(cat <<'EOF'
feat: assemble the main screen

Active timers on top sorted by fire time, quick-log grid at the bottom
within thumb reach. Expired timers are marked on foreground because a
local notification firing does not wake the app.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 13: GPS 群組自動辨識

App 進前景時取得一次位置，找出距離最近且在半徑內的群組。建立新群組時用反向地理編碼產生預設名稱。只要「使用 App 期間」權限，不使用背景定位。

**Files:**
- Create: `MushroomTimer/Models/GroupLocator.swift`
- Create: `MushroomTimer/Services/LocationService.swift`
- Modify: `MushroomTimer/Views/MainView.swift`
- Test: `MushroomTimerTests/GroupLocatorTests.swift`

**Interfaces:**
- Consumes: `MushroomGroup`（Task 8）
- Produces:
  - `GroupLocator.nearest(latitude:longitude:groups:) -> MushroomGroup?`（只回傳半徑內的；多個符合時取最近）
  - `GroupLocator.distance(from:to:group:) -> Double`（公尺）
  - `LocationService`（`ObservableObject`）：`requestAuthorization()`、`updateCurrentLocation() async -> CLLocationCoordinate2D?`、`suggestedName(for: CLLocationCoordinate2D) async -> String`
  - `LocationService.lastKnownGroupIDKey = "last-known-group-id"`（UserDefaults key，Task 14 的 `QuickLogHereIntent` 會讀）

- [ ] **Step 1: 寫 GroupLocator 的失敗測試**

`MushroomTimerTests/GroupLocatorTests.swift`：

```swift
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
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 編譯失敗，`cannot find 'GroupLocator' in scope`

- [ ] **Step 3: 實作 GroupLocator**

`MushroomTimer/Models/GroupLocator.swift`：

```swift
import CoreLocation
import Foundation

/// 由座標判定所在群組。純函式，不碰定位權限，方便測試。
enum GroupLocator {
    static func distance(
        latitude: Double, longitude: Double, group: MushroomGroup
    ) -> Double {
        CLLocation(latitude: latitude, longitude: longitude).distance(
            from: CLLocation(latitude: group.latitude, longitude: group.longitude)
        )
    }

    /// 距離最近且在該群組自己的 `radius` 內的群組；都不符合時回傳 `nil`。
    static func nearest(
        latitude: Double, longitude: Double, groups: [MushroomGroup]
    ) -> MushroomGroup? {
        groups
            .map { ($0, distance(latitude: latitude, longitude: longitude, group: $0)) }
            .filter { $0.1 <= $0.0.radius }
            .min { $0.1 < $1.1 }?
            .0
    }
}
```

- [ ] **Step 4: 執行測試確認通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 實作 LocationService**

`MushroomTimer/Services/LocationService.swift`：

```swift
import CoreLocation
import Foundation

/// 一次性定位與反向地理編碼。
///
/// 只要「使用 App 期間」權限：進入前景時取一次位置就好，不需要背景定位，
/// 也因此不會持續耗電。
@MainActor
final class LocationService: NSObject, ObservableObject {
    static let lastKnownGroupIDKey = "last-known-group-id"

    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var authorizationDenied = false

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// 取得目前位置。不論成功或失敗都會回傳（失敗時為 `nil`），不會卡住呼叫端。
    func updateCurrentLocation() async -> CLLocationCoordinate2D? {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            return nil
        case .denied, .restricted:
            authorizationDenied = true
            return nil
        default:
            break
        }

        if continuation != nil { return coordinate }

        let result = await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
        coordinate = result ?? coordinate
        return coordinate
    }

    /// 用反向地理編碼產生群組的預設名稱。這是全 App 唯一需要網路的功能；
    /// 失敗時退回座標字串，使用者可以自己改。
    func suggestedName(for coordinate: CLLocationCoordinate2D) async -> String {
        let location = CLLocation(
            latitude: coordinate.latitude, longitude: coordinate.longitude
        )
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(
            location, preferredLocale: Locale(identifier: "zh_Hant_TW")
        )
        guard let placemark = placemarks?.first else {
            return String(
                format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude
            )
        }
        let candidates = [
            placemark.name,
            placemark.thoroughfare,
            placemark.subLocality,
            placemark.locality
        ]
        return candidates.compactMap { $0 }.first ?? "新群組"
    }

    private func finish(with coordinate: CLLocationCoordinate2D?) {
        continuation?.resume(returning: coordinate)
        continuation = nil
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        let coordinate = locations.last?.coordinate
        Task { @MainActor in finish(with: coordinate) }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager, didFailWithError error: Error
    ) {
        Task { @MainActor in finish(with: nil) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationDenied = (status == .denied || status == .restricted)
        }
    }
}
```

- [ ] **Step 6: 把定位接進 MainView**

`MushroomTimer/Views/MainView.swift` 需要四處修改。

第一，加入 import 與新的狀態屬性（放在 `@State private var isPickingGroup = false` 之後）：

```swift
    @StateObject private var location = LocationService()
    @State private var gpsGroupID: UUID?
    @State private var isCreatingGroup = false
    @State private var draftGroupName = ""
    @State private var draftCoordinate: (latitude: Double, longitude: Double)?
```

檔案最上方加入 `import CoreLocation`。

第二，`currentGroup` 改成優先採用手動選擇、其次 GPS 判定、最後才是最近建立的群組：

```swift
    private var currentGroup: MushroomGroup? {
        if let selectedGroupID,
           let match = groups.first(where: { $0.id == selectedGroupID }) {
            return match
        }
        if let gpsGroupID,
           let match = groups.first(where: { $0.id == gpsGroupID }) {
            return match
        }
        return groups.first
    }
```

第三，`onCreateGroup` 改成呼叫新方法：

```swift
                QuickLogSection(
                    group: currentGroup,
                    onChangeGroup: { isPickingGroup = true },
                    onCreateGroup: { Task { await prepareNewGroup() } }
                )
                .frame(height: 300)
```

第四，`.onChange(of: scenePhase)` 之後追加定位邏輯與建立群組的對話框：

```swift
            .task {
                location.requestAuthorization()
                await refreshCurrentGroup()
            }
            .alert("建立新群組", isPresented: $isCreatingGroup) {
                TextField("群組名稱", text: $draftGroupName)
                Button("取消", role: .cancel) {}
                Button("建立") { createGroup() }
            } message: {
                Text("名稱已依目前位置預填，可以直接使用或改寫。")
            }
```

並在 `body` 之後加入三個方法：

```swift
    /// 取一次位置，判定目前在哪個群組。
    private func refreshCurrentGroup() async {
        guard let coordinate = await location.updateCurrentLocation() else { return }
        let match = GroupLocator.nearest(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            groups: groups
        )
        gpsGroupID = match?.id
        // QuickLogHereIntent 不觸發 GPS，改讀這裡記下的結果。
        UserDefaults.standard.set(
            match?.id.uuidString, forKey: LocationService.lastKnownGroupIDKey
        )
    }

    private func prepareNewGroup() async {
        guard let coordinate = await location.updateCurrentLocation() else {
            draftGroupName = "新群組"
            draftCoordinate = nil
            isCreatingGroup = true
            return
        }
        draftCoordinate = (coordinate.latitude, coordinate.longitude)
        draftGroupName = await location.suggestedName(for: coordinate)
        isCreatingGroup = true
    }

    private func createGroup() {
        let trimmed = draftGroupName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let draftCoordinate else { return }
        let group = MushroomGroup(
            name: trimmed,
            latitude: draftCoordinate.latitude,
            longitude: draftCoordinate.longitude
        )
        context.insert(group)
        try? context.save()
        selectedGroupID = group.id
    }
```

同時把 `.onChange(of: scenePhase)` 的內容補上重新判定群組：

```swift
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                // 本機通知不會喚醒 App，所以回到前景時補標記已到期的計時。
                try? TimerQueries.markFired(in: context)
                Task { await refreshCurrentGroup() }
            }
```

- [ ] **Step 7: 確認建置與測試通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 8: 模擬器手動驗證完整 MVP**

在模擬器執行 App，用 Xcode 的 Debug → Simulate Location（或模擬器選單 Features → Location → Custom Location）設定一組座標，然後：

1. 允許定位權限
2. 下半部按「建立新群組」，確認名稱已被反向地理編碼預填
3. 建立群組 → 新增兩顆菇
4. 點一顆菇 → 輸入「230」→ 確認預覽顯示「7:15 後提醒 · <時鐘時間>」→ 建立
5. 確認上半部出現該筆計時，倒數自己逐秒減少
6. 左滑取消，確認消失
7. 再建一筆，輸入「剛爆」，等待通知響起

- [ ] **Step 9: Commit**

```bash
cd ~/Developer/MushroomTimer && git add -A && git commit -m "$(cat <<'EOF'
feat: detect the current group from a one-shot location fix

GroupLocator picks the closest group whose own radius contains the
fix. Manual override still wins because urban GPS error can reach 30
metres. The result is cached in defaults for QuickLogHereIntent, which
must not trigger GPS itself.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 14: App Intents（捷徑整合）

把登記功能開放給捷徑 App、Siri、動作按鈕、控制中心。這是本專案價值最高的部分：使用者可以針對常打的菇各做一個捷徑放到桌面，一個 tap 完成登記，App 完全不用開啟。

**Files:**
- Create: `MushroomTimer/Intents/IntentSupport.swift`
- Create: `MushroomTimer/Intents/MushroomEntity.swift`
- Create: `MushroomTimer/Intents/LogMushroomIntent.swift`
- Create: `MushroomTimer/Intents/QuickLogHereIntent.swift`
- Create: `MushroomTimer/Intents/AppShortcuts.swift`
- Modify: `MushroomTimer/MushroomTimerApp.swift`
- Test: `MushroomTimerTests/IntentSupportTests.swift`

**Interfaces:**
- Consumes: `MushroomLogger`／`TimerQueries`（Task 9）、`SettingsStore`（Task 7）、`LocationService.lastKnownGroupIDKey`（Task 13）
- Produces:
  - `ModelContainer.shared`（主 App 與 Intents 共用同一個容器）
  - `IntentSupport.mushroom(id:context:) throws -> Mushroom?`
  - `IntentSupport.allMushrooms(context:) throws -> [Mushroom]`
  - `IntentSupport.preferredMushroom(context:defaults:) throws -> Mushroom?`（QuickLogHere 用：目前群組中最常用的那顆）
  - `MushroomEntity`（`AppEntity`）、`MushroomEntityQuery`
  - `LogMushroomIntent`、`QuickLogHereIntent`、`MushroomTimerShortcuts`

- [ ] **Step 1: 寫 IntentSupport 的失敗測試**

`MushroomTimerTests/IntentSupportTests.swift`：

```swift
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
}
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 編譯失敗，`cannot find 'IntentSupport' in scope`

- [ ] **Step 3: 實作 IntentSupport 與共用 ModelContainer**

`MushroomTimer/Intents/IntentSupport.swift`：

```swift
import Foundation
import SwiftData

extension ModelContainer {
    /// 主 App 與 App Intents 共用同一個容器。
    ///
    /// Intents 遵循 `LiveActivityIntent`，會在主 App 的 process 執行，
    /// 因此可以直接使用這個容器；Widget extension 則完全不碰它。
    @MainActor
    static let shared: ModelContainer = {
        do {
            return try ModelContainer.mushroomTimer()
        } catch {
            fatalError("無法建立資料庫：\(error)")
        }
    }()
}

/// Intents 共用的查詢邏輯。抽出來才能不經過 AppIntents 框架就測到。
@MainActor
enum IntentSupport {
    static func mushroom(id: UUID, context: ModelContext) throws -> Mushroom? {
        var descriptor = FetchDescriptor<Mushroom>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// 全部的菇，依使用次數由高到低——捷徑 App 的選單也照這個順序。
    static func allMushrooms(context: ModelContext) throws -> [Mushroom] {
        try context.fetch(
            FetchDescriptor<Mushroom>(
                sortBy: [SortDescriptor(\.useCount, order: .reverse)]
            )
        )
    }

    /// `QuickLogHereIntent` 用：目前群組中最常用的那顆菇。
    ///
    /// 這裡刻意不觸發 GPS——Intent 可能在 App 沒開的情況下執行，
    /// 定位會很慢也可能沒有權限。改讀主 App 上次判定並記在 UserDefaults 的群組。
    static func preferredMushroom(
        context: ModelContext,
        defaults: UserDefaults = .standard
    ) throws -> Mushroom? {
        if let raw = defaults.string(forKey: LocationService.lastKnownGroupIDKey),
           let groupID = UUID(uuidString: raw) {
            var descriptor = FetchDescriptor<MushroomGroup>(
                predicate: #Predicate { $0.id == groupID }
            )
            descriptor.fetchLimit = 1
            if let group = try context.fetch(descriptor).first,
               let best = TimerQueries.mostUsed(in: group, limit: 1).first {
                return best
            }
        }
        return try allMushrooms(context: context).first
    }
}
```

- [ ] **Step 4: 執行測試確認通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 實作 MushroomEntity**

`MushroomTimer/Intents/MushroomEntity.swift`。`AppEntity` 讓使用者在捷徑 App 裡是「用選的」而不是打字，也讓參數可以預先綁定。

```swift
import AppIntents
import Foundation
import SwiftData

/// 捷徑 App 中可挑選的一顆菇。
struct MushroomEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "菇")
    static var defaultQuery = MushroomEntityQuery()

    var id: UUID
    var name: String
    var groupName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(groupName)")
    }

    @MainActor
    init(_ mushroom: Mushroom) {
        self.id = mushroom.id
        self.name = mushroom.name
        self.groupName = mushroom.group?.name ?? ""
    }
}

struct MushroomEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [MushroomEntity.ID]) async throws -> [MushroomEntity] {
        let context = ModelContainer.shared.mainContext
        return try identifiers.compactMap { id in
            try IntentSupport.mushroom(id: id, context: context).map(MushroomEntity.init)
        }
    }

    /// 捷徑 App 的下拉選單內容，依使用次數排序。
    @MainActor
    func suggestedEntities() async throws -> [MushroomEntity] {
        try IntentSupport.allMushrooms(context: ModelContainer.shared.mainContext)
            .map(MushroomEntity.init)
    }
}
```

- [ ] **Step 6: 實作 LogMushroomIntent**

`MushroomTimer/Intents/LogMushroomIntent.swift`：

```swift
import AppIntents
import Foundation

/// 登記一顆菇。兩個參數都可以在捷徑 App 裡預先綁定，
/// 綁定之後就是「一個 tap 完成登記，App 完全不用開啟」。
struct LogMushroomIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "登記一顆菇"
    static var description = IntentDescription("為指定的菇建立重生提醒。")
    /// 不開啟 App 畫面，在主 App 的 process 背景執行。
    static var openAppWhenRun: Bool = false

    @Parameter(title: "菇")
    var mushroom: MushroomEntity?

    @Parameter(title: "剩餘秒數", default: 0, inclusiveRange: (0, 5999))
    var remainingSeconds: Int?

    init() {}

    init(mushroom: MushroomEntity?, remainingSeconds: Int?) {
        self.mushroom = mushroom
        self.remainingSeconds = remainingSeconds
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let entity = try await $mushroom.requestValue("要登記哪一顆菇？")
        let context = ModelContainer.shared.mainContext
        guard let target = try IntentSupport.mushroom(id: entity.id, context: context) else {
            return .result(dialog: "找不到這顆菇，可能已經被刪除了。")
        }

        let settings = SettingsStore()
        let entry = try await MushroomLogger.log(
            mushroom: target,
            remainingSeconds: remainingSeconds ?? 0,
            leadSeconds: settings.defaultLeadSeconds,
            respawnSeconds: settings.respawnSeconds,
            context: context
        )
        return .result(
            dialog: "已登記 \(target.name)，\(DurationInput.clockTime(entry.fireAt)) 提醒你。"
        )
    }
}
```

- [ ] **Step 7: 實作 QuickLogHereIntent 與 AppShortcuts**

`MushroomTimer/Intents/QuickLogHereIntent.swift`：

```swift
import AppIntents
import Foundation

/// 用目前群組中最常用的那顆菇建立計時。不需要指定菇，也不會觸發 GPS。
struct QuickLogHereIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "在這裡快速登記"
    static var description = IntentDescription("用目前群組中最常用的菇建立重生提醒。")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "剩餘秒數", default: 0, inclusiveRange: (0, 5999))
    var remainingSeconds: Int

    init() {}

    init(remainingSeconds: Int) {
        self.remainingSeconds = remainingSeconds
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContainer.shared.mainContext
        guard let target = try IntentSupport.preferredMushroom(context: context) else {
            return .result(dialog: "還沒有建立任何菇，請先開啟打菇茜新增。")
        }

        let settings = SettingsStore()
        let entry = try await MushroomLogger.log(
            mushroom: target,
            remainingSeconds: remainingSeconds,
            leadSeconds: settings.defaultLeadSeconds,
            respawnSeconds: settings.respawnSeconds,
            context: context
        )
        return .result(
            dialog: "已登記 \(target.name)，\(DurationInput.clockTime(entry.fireAt)) 提醒你。"
        )
    }
}
```

`MushroomTimer/Intents/AppShortcuts.swift`：

```swift
import AppIntents

/// 開放給 Siri 與捷徑 App 的預設捷徑。
struct MushroomTimerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickLogHereIntent(),
            phrases: [
                "在\(.applicationName)快速登記",
                "用\(.applicationName)登記菇"
            ],
            shortTitle: "快速登記",
            systemImageName: "circle.hexagongrid.fill"
        )
        AppShortcut(
            intent: LogMushroomIntent(),
            phrases: ["用\(.applicationName)登記一顆菇"],
            shortTitle: "登記一顆菇",
            systemImageName: "plus.circle.fill"
        )
    }
}
```

- [ ] **Step 8: 讓 App 改用共用容器**

`MushroomTimer/MushroomTimerApp.swift` 的 `init()` 與 `container` 屬性刪除，改成直接使用 `ModelContainer.shared`：

```swift
import SwiftData
import SwiftUI

@main
struct MushroomTimerApp: App {
    @StateObject private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(settings)
        }
        .modelContainer(ModelContainer.shared)
    }
}
```

- [ ] **Step 9: 確認建置與測試通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 10: 【使用者手動】實機驗證捷徑**

**必須停下來請使用者操作並回報結果。** 驗證項目：

1. 開啟捷徑 App → 新增捷徑 → 搜尋「打菇茜」，確認出現「登記一顆菇」與「在這裡快速登記」
2. 加入「登記一顆菇」，點「菇」參數，確認出現**下拉選單**列出已建立的菇（不是要打字）
3. 選定一顆菇、剩餘秒數填 0，儲存捷徑並加到桌面
4. 從桌面點該捷徑，確認：App **沒有被開啟**，且回到打菇茜後上半部多了一筆計時
5. 對 Siri 說「用打菇茜快速登記」，確認能執行

- [ ] **Step 11: Commit**

```bash
cd ~/Developer/MushroomTimer && git add -A && git commit -m "$(cat <<'EOF'
feat: expose logging through App Intents

MushroomEntity gives Shortcuts a pickable list instead of a text field,
which is what makes per-mushroom home screen shortcuts possible.
QuickLogHere reads the cached group rather than taking a GPS fix, since
it runs with the app closed.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 15: 互動式桌面小工具

預期會成為最主要的入口，因為速度最快：桌面上按一下就完成登記。

**先確認 Task 4 的驗證結果。** 若「小工具是否顯示出主 App 寫入的內容」為「否」，改走本 task Step 7 的 fallback 版本。

**Files:**
- Create: `MushroomTimer/Services/WidgetChannel.swift`
- Create: `MushroomTimerWidgets/QuickLogWidget.swift`
- Modify: `Shared/QuickLogIntent.swift`
- Modify: `MushroomTimer/Services/MushroomLogger.swift`
- Modify: `MushroomTimer/Views/MainView.swift`
- Modify: `MushroomTimerWidgets/MushroomTimerWidgetBundle.swift`
- Test: `MushroomTimerTests/WidgetChannelTests.swift`

**Interfaces:**
- Consumes: `WidgetPayload`／`SharedKeychain`（Task 4）、`TimerQueries`（Task 9）、`IntentSupport`（Task 14）
- Produces:
  - `WidgetChannel.makePayload(context:defaults:) throws -> WidgetPayload`
  - `WidgetChannel.refresh(context:defaults:)`（寫 keychain + `reloadAllTimelines()`）
  - `QuickLogWidget`

- [ ] **Step 1: 寫 WidgetChannel 的失敗測試**

`MushroomTimerTests/WidgetChannelTests.swift`。只測 payload 的組成規則；實際的 keychain 跨 process 讀寫已在 Task 4 於實機驗證過。

```swift
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
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 編譯失敗，`cannot find 'WidgetChannel' in scope`

- [ ] **Step 3: 實作 WidgetChannel**

`MushroomTimer/Services/WidgetChannel.swift`：

```swift
import Foundation
import SwiftData
import WidgetKit

/// 主 App 推送資料給小工具的唯一管道。
///
/// Widget extension 沒有資料庫連線，也不能有——它只讀主 App 放進共享 keychain
/// 的這份精簡 payload。所以每次資料異動後都要呼叫 `refresh`。
@MainActor
enum WidgetChannel {
    static func makePayload(
        context: ModelContext,
        defaults: UserDefaults = .standard
    ) throws -> WidgetPayload {
        guard let group = try currentGroup(context: context, defaults: defaults) else {
            return .empty
        }
        let mushrooms = TimerQueries.mostUsed(in: group, limit: WidgetPayload.maxMushrooms)
        return WidgetPayload.make(
            groupName: group.name,
            mushrooms: mushrooms.map { ($0.id, $0.name) }
        )
    }

    static func refresh(context: ModelContext, defaults: UserDefaults = .standard) {
        guard let payload = try? makePayload(context: context, defaults: defaults) else {
            return
        }
        SharedKeychain.save(payload)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func currentGroup(
        context: ModelContext,
        defaults: UserDefaults
    ) throws -> MushroomGroup? {
        if let raw = defaults.string(forKey: LocationService.lastKnownGroupIDKey),
           let id = UUID(uuidString: raw) {
            var descriptor = FetchDescriptor<MushroomGroup>(
                predicate: #Predicate { $0.id == id }
            )
            descriptor.fetchLimit = 1
            if let group = try context.fetch(descriptor).first {
                return group
            }
        }
        var descriptor = FetchDescriptor<MushroomGroup>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
```

- [ ] **Step 4: 執行測試確認通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 讓資料異動時自動更新小工具**

在 `MushroomTimer/Services/MushroomLogger.swift` 的 `log` 方法中，把 `return entry` 之前的部分改成：

```swift
        try? await NotificationService.shared.schedule(
            id: entry.id,
            groupName: mushroom.group?.name ?? "",
            mushroomName: mushroom.name,
            at: fireAt
        )
        WidgetChannel.refresh(context: context)

        return entry
```

在 `MushroomTimer/Views/MainView.swift` 的 `refreshCurrentGroup()` 結尾（`UserDefaults.standard.set(...)` 之後）加入：

```swift
        WidgetChannel.refresh(context: context)
```

- [ ] **Step 6: 讓 QuickLogIntent 真的建立計時**

`Shared/QuickLogIntent.swift` 全檔替換。`IntentProcessMarker` 的驗證用途到此結束，整個移除。

```swift
import AppIntents
import Foundation

/// 小工具按鈕觸發的登記 Intent，剩餘時間固定為 0（剛爆）。
///
/// 關鍵：從小工具按鈕觸發的 App Intent **預設在 Widget extension 的 process 執行**，
/// 那個 process 讀不到主 App 的 SwiftData 資料庫。遵循 `LiveActivityIntent` 之後，
/// 系統會改在主 App 的 process 背景執行（不會開啟 App 畫面）。
struct QuickLogIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "快速登記"
    static var description = IntentDescription("以「剛爆」登記指定的菇。")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "菇 ID")
    var mushroomID: String

    @Parameter(title: "菇名稱")
    var mushroomName: String

    init() {}

    init(mushroomID: String, mushroomName: String) {
        self.mushroomID = mushroomID
        self.mushroomName = mushroomName
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        guard let id = UUID(uuidString: mushroomID) else { return .result() }
        let context = ModelContainer.shared.mainContext
        guard let mushroom = try IntentSupport.mushroom(id: id, context: context) else {
            return .result()
        }
        let settings = SettingsStore()
        try await MushroomLogger.log(
            mushroom: mushroom,
            remainingSeconds: 0,
            leadSeconds: settings.defaultLeadSeconds,
            respawnSeconds: settings.respawnSeconds,
            context: context
        )
        #endif
        return .result()
    }
}
```

`#if !WIDGET_EXTENSION` 是必要的：這個檔案同時編進 Widget extension，而那邊不該（也無法）連結 SwiftData 模型。在 `project.yml` 的 `MushroomTimerWidgets` target 的 `settings.base` 加上：

```yaml
        SWIFT_ACTIVE_COMPILATION_CONDITIONS: WIDGET_EXTENSION
```

改完後執行 `xcodegen generate`。

- [ ] **Step 7: 實作 QuickLogWidget**

`MushroomTimerWidgets/QuickLogWidget.swift`：

```swift
import SwiftUI
import WidgetKit

/// 互動式桌面小工具：按一下就以「剛爆」建立計時，不需要開啟 App。
///
/// 小工具本身不做任何資料查詢——它讀的是主 App 寫進共享 keychain 的 payload。
struct QuickLogWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickLogWidget", provider: QuickLogProvider()) { entry in
            QuickLogWidgetView(payload: entry.payload)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("快速登記")
        .description("按一下常用的菇，直接以「剛爆」建立提醒。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct QuickLogEntry: TimelineEntry {
    let date: Date
    let payload: WidgetPayload
}

struct QuickLogProvider: TimelineProvider {
    private static let sample = WidgetPayload(
        groupName: "中山路口",
        mushrooms: [
            .init(id: UUID(), name: "7-11 門口"),
            .init(id: UUID(), name: "天橋下")
        ]
    )

    func placeholder(in context: Context) -> QuickLogEntry {
        QuickLogEntry(date: .now, payload: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickLogEntry) -> Void) {
        completion(QuickLogEntry(date: .now, payload: SharedKeychain.load() ?? Self.sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickLogEntry>) -> Void) {
        let entry = QuickLogEntry(date: .now, payload: SharedKeychain.load() ?? .empty)
        // 內容只有在主 App 呼叫 reloadAllTimelines() 時才會變，不需要定時刷新。
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct QuickLogWidgetView: View {
    let payload: WidgetPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(payload.groupName.isEmpty ? "打菇茜" : payload.groupName)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if payload.mushrooms.isEmpty {
                Text("開啟打菇茜建立群組與菇")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(payload.mushrooms) { item in
                    Button(
                        intent: QuickLogIntent(
                            mushroomID: item.id.uuidString,
                            mushroomName: item.name
                        )
                    ) {
                        Text(item.name)
                            .font(.footnote.bold())
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
```

- [ ] **Step 8: 用正式小工具取代驗證用的佔位小工具**

`MushroomTimerWidgets/MushroomTimerWidgetBundle.swift` 全檔替換。`EmptyWidget`、`PlaceholderEntry`、`PlaceholderProvider` 全部刪除。

```swift
import SwiftUI
import WidgetKit

@main
struct MushroomTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickLogWidget()
        MushroomLiveActivity()
    }
}
```

同時刪除 `MushroomTimer/Views/VerificationView.swift` 中的「Intent 執行 process」section（`IntentProcessMarker` 已不存在，留著會編譯失敗）。

- [ ] **Step 9: 確認建置與測試通過**

```bash
cd ~/Developer/MushroomTimer && xcodegen generate && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 10: 【使用者手動】實機驗證小工具**

**必須停下來請使用者操作並回報結果。** 驗證項目：

1. 開啟 App，確認有群組與至少 2 顆菇
2. 回桌面加入「快速登記」小工具
3. 確認小工具顯示目前群組名稱與最常用的菇（最多 3 顆）
4. 按下其中一顆菇的按鈕，確認 App **沒有被開啟**
5. 回到 App，確認上半部多了一筆該顆菇的計時，且倒數約為「重生秒數 − 提前量」
6. 確認小工具上的菇順序有依使用次數更新

**若小工具顯示不出菇名（Task 4 驗證失敗的情況）**，改用 fallback：`QuickLogWidgetView` 不讀 payload，固定畫三顆按鈕，文字分別為「最常用 #1」「最常用 #2」「最常用 #3」，並把 `QuickLogIntent` 的參數從 `mushroomID`／`mushroomName` 改成 `rank: Int`。同時在 `IntentSupport` 新增 `static func mushroomsInCurrentGroup(context:defaults:) throws -> [Mushroom]`——內容與 `WidgetChannel.makePayload` 取群組的邏輯相同（先讀 `LocationService.lastKnownGroupIDKey`，找不到就取最近建立的群組），回傳該群組依使用次數排序的菇；`perform()` 內取它的第 `rank` 個元素。這個做法功能相同，只是按鈕上看不到菇名。

- [ ] **Step 11: Commit**

```bash
cd ~/Developer/MushroomTimer && git add -A && git commit -m "$(cat <<'EOF'
feat: add the interactive quick-log widget

The widget renders a payload the app writes into shared keychain and
never queries the database itself. Its button intent runs in the app
process, so it can create the timer and schedule the notification.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 16: Live Activity 整合

把 Task 3 驗證過的版面接上真實資料。全程只維持一個 Live Activity，顯示最快到期的那一筆。

**Files:**
- Create: `MushroomTimer/Services/LiveActivityController.swift`
- Modify: `MushroomTimer/Services/MushroomLogger.swift`
- Modify: `MushroomTimer/Views/MainView.swift`
- Test: `MushroomTimerTests/LiveActivityStateTests.swift`

**Interfaces:**
- Consumes: `MushroomActivityAttributes`（Task 3）、`TimerQueries`（Task 9）
- Produces:
  - `LiveActivityController.state(from: [TimerEntry]) -> MushroomActivityAttributes.ContentState?`（純函式，可測）
  - `LiveActivityController.refresh(context: ModelContext) async`

- [ ] **Step 1: 寫 state 組成規則的失敗測試**

`MushroomTimerTests/LiveActivityStateTests.swift`：

```swift
import SwiftData
import XCTest
@testable import MushroomTimer

@MainActor
final class LiveActivityStateTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private let now = Date(timeIntervalSince1970: 1_000_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer.mushroomTimer(inMemory: true)
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    private func makeEntry(name: String, offset: TimeInterval) -> TimerEntry {
        let group = MushroomGroup(name: "中山路口", latitude: 25.05, longitude: 121.52)
        context.insert(group)
        let mushroom = Mushroom(name: name, group: group)
        context.insert(mushroom)
        let entry = TimerEntry(
            mushroom: mushroom,
            createdAt: now,
            remainingSeconds: 0,
            leadSeconds: 15,
            fireAt: now.addingTimeInterval(offset)
        )
        context.insert(entry)
        return entry
    }

    func testNilWhenNothingIsActive() {
        XCTAssertNil(LiveActivityController.state(from: []))
    }

    /// 只顯示最快到期的那一筆，其餘算進排隊筆數。
    func testUsesSoonestEntryAndCountsTheRest() {
        let soonest = makeEntry(name: "最快", offset: 100)
        let second = makeEntry(name: "第二", offset: 200)
        let third = makeEntry(name: "第三", offset: 300)

        let state = LiveActivityController.state(from: [soonest, second, third])
        XCTAssertEqual(state?.mushroomName, "最快")
        XCTAssertEqual(state?.groupName, "中山路口")
        XCTAssertEqual(state?.fireAt, now.addingTimeInterval(100))
        XCTAssertEqual(state?.queuedCount, 2)
        XCTAssertEqual(state?.queueLabel, "+2")
        XCTAssertEqual(state?.nextMushroomName, "第二")
    }

    func testSingleEntryHasNoQueue() {
        let only = makeEntry(name: "唯一", offset: 100)
        let state = LiveActivityController.state(from: [only])
        XCTAssertEqual(state?.queuedCount, 0)
        XCTAssertNil(state?.queueLabel)
        XCTAssertNil(state?.nextMushroomName)
    }
}
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 編譯失敗，`cannot find 'LiveActivityController' in scope`

- [ ] **Step 3: 實作 LiveActivityController**

`MushroomTimer/Services/LiveActivityController.swift`：

```swift
import ActivityKit
import Foundation
import SwiftData

/// 全程只維持一個 Live Activity，內容永遠是最快到期的那一筆。
///
/// 動態島同時只能顯示一個 Live Activity，所以不能一筆計時開一個。
///
/// 已知限制：免費帳號沒有遠端推播，主 App 沒在執行時無法在最快一筆到期的瞬間
/// 自動換成下一筆。因此 `ContentState` 會帶著下一筆的名稱，並在每次主 App
/// 有機會執行時（進前景、Intent 執行、處理通知動作）重新整理。
@MainActor
enum LiveActivityController {
    /// 由進行中的計時（已依 fireAt 排序）組出畫面狀態。
    static func state(
        from timers: [TimerEntry]
    ) -> MushroomActivityAttributes.ContentState? {
        guard let soonest = timers.first else { return nil }
        return MushroomActivityAttributes.ContentState(
            mushroomName: soonest.mushroom?.name ?? "菇",
            groupName: soonest.mushroom?.group?.name ?? "",
            fireAt: soonest.fireAt,
            queuedCount: max(0, timers.count - 1),
            nextMushroomName: timers.dropFirst().first?.mushroom?.name
        )
    }

    /// 依目前資料庫內容建立、更新或結束唯一的 Live Activity。
    static func refresh(context: ModelContext) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let timers = (try? TimerQueries.active(in: context)) ?? []
        let existing = Activity<MushroomActivityAttributes>.activities

        guard let state = state(from: timers) else {
            for activity in existing {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }

        let content = ActivityContent(state: state, staleDate: state.fireAt)
        if let activity = existing.first {
            await activity.update(content)
            // 保險起見，把多開的收掉，確保永遠只有一個。
            for extra in existing.dropFirst() {
                await extra.end(nil, dismissalPolicy: .immediate)
            }
        } else {
            _ = try? Activity.request(
                attributes: MushroomActivityAttributes(), content: content
            )
        }
    }
}
```

- [ ] **Step 4: 執行測試確認通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 在登記與取消後刷新 Live Activity**

`MushroomTimer/Services/MushroomLogger.swift`：在 `log` 的 `WidgetChannel.refresh(context: context)` 之後加入一行，並把 `cancel`／`complete` 改成 `async`。

`log` 內：

```swift
        WidgetChannel.refresh(context: context)
        await LiveActivityController.refresh(context: context)

        return entry
```

`cancel` 與 `complete` 改成：

```swift
    /// 使用者左滑取消。連帶把已排定的通知撤掉。
    static func cancel(_ entry: TimerEntry, context: ModelContext) async throws {
        entry.status = .cancelled
        NotificationService.shared.cancel(id: entry.id)
        try context.save()
        await LiveActivityController.refresh(context: context)
    }

    /// 使用者按「已完成」。
    static func complete(_ entry: TimerEntry, context: ModelContext) async throws {
        entry.status = .completed
        NotificationService.shared.cancel(id: entry.id)
        try context.save()
        await LiveActivityController.refresh(context: context)
    }
```

因為簽章改成 `async`，`MushroomTimerTests/MushroomLoggerTests.swift` 中兩處呼叫要改成 `try await MushroomLogger.cancel(...)` 與 `try await MushroomLogger.complete(...)`；`ActiveTimersSection` 的左滑動作改成：

```swift
                            .swipeActions(edge: .leading) {
                                Button("取消", role: .destructive) {
                                    Task { try? await MushroomLogger.cancel(timer, context: context) }
                                }
                            }
```

- [ ] **Step 6: 在進入前景時刷新 Live Activity**

`MushroomTimer/Views/MainView.swift` 的 `.onChange(of: scenePhase)` 內，把 `Task { await refreshCurrentGroup() }` 改成：

```swift
                Task {
                    await refreshCurrentGroup()
                    await LiveActivityController.refresh(context: context)
                }
```

- [ ] **Step 7: 確認建置與測試通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 8: 【使用者手動】實機驗證 Live Activity**

**必須停下來請使用者操作並回報結果。** 驗證項目：

1. 建立一筆計時，鎖屏確認出現 Live Activity 且倒數逐秒跑動
2. 再建立兩筆，確認卡片顯示的是**最快到期的那一筆**，並出現「還有 +2」
3. 取消最快的那一筆，確認卡片內容換成下一筆
4. 取消全部，確認卡片消失
5. 確認同時只會有一張卡片，不會每筆各開一張

- [ ] **Step 9: Commit**

```bash
cd ~/Developer/MushroomTimer && git add -A && git commit -m "$(cat <<'EOF'
feat: drive the Live Activity from real timer data

Only one activity exists at a time because the Dynamic Island can show
only one. It always renders the soonest entry and carries the next one
in its state, since without push there is no way to swap content while
the app is not running.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 17: 通知動作按鈕

在通知上直接按「已完成」或「延後 1 分鐘」，不用開 App。處理通知動作時系統會喚醒 App，因此這時可以寫資料庫、重排通知、更新 Live Activity。

**Files:**
- Modify: `MushroomTimer/Services/NotificationPolicy.swift`
- Modify: `MushroomTimer/Services/NotificationService.swift`
- Create: `MushroomTimer/Services/NotificationActionHandler.swift`
- Modify: `MushroomTimer/MushroomTimerApp.swift`
- Test: `MushroomTimerTests/NotificationActionHandlerTests.swift`

**Interfaces:**
- Consumes: `MushroomLogger`／`TimerQueries`（Task 9、16）、`NotificationService`（Task 2）
- Produces:
  - `NotificationPolicy.categoryID = "mushroom-respawn"`、`NotificationPolicy.completeActionID = "complete"`、`NotificationPolicy.snoozeActionID = "snooze"`、`NotificationPolicy.snoozeSeconds = 60`
  - `NotificationService.shared.registerCategories()`
  - `NotificationActionHandler.handle(actionID:timerID:context:now:) async throws`
  - `NotificationActionHandler.shared`（`UNUserNotificationCenterDelegate`）

- [ ] **Step 1: 寫失敗測試**

`MushroomTimerTests/NotificationActionHandlerTests.swift`：

```swift
import SwiftData
import XCTest
@testable import MushroomTimer

@MainActor
final class NotificationActionHandlerTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private let now = Date(timeIntervalSince1970: 1_000_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer.mushroomTimer(inMemory: true)
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    private func makeEntry(status: TimerStatus = .fired) -> TimerEntry {
        let group = MushroomGroup(name: "中山路口", latitude: 25.05, longitude: 121.52)
        context.insert(group)
        let mushroom = Mushroom(name: "7-11 門口", group: group)
        context.insert(mushroom)
        let entry = TimerEntry(
            mushroom: mushroom,
            createdAt: now,
            remainingSeconds: 0,
            leadSeconds: 15,
            fireAt: now,
            status: status
        )
        context.insert(entry)
        return entry
    }

    func testCompleteActionMarksCompleted() async throws {
        let entry = makeEntry()
        try await NotificationActionHandler.handle(
            actionID: NotificationPolicy.completeActionID,
            timerID: entry.id,
            context: context,
            now: now
        )
        XCTAssertEqual(entry.status, .completed)
    }

    /// 延後 1 分鐘：狀態回到 active，fireAt 從「現在」推遲 60 秒。
    func testSnoozeActionReschedulesOneMinuteFromNow() async throws {
        let entry = makeEntry()
        try await NotificationActionHandler.handle(
            actionID: NotificationPolicy.snoozeActionID,
            timerID: entry.id,
            context: context,
            now: now
        )
        XCTAssertEqual(entry.status, .active)
        XCTAssertEqual(entry.fireAt, now.addingTimeInterval(60))
    }

    func testUnknownTimerIDIsIgnored() async throws {
        try await NotificationActionHandler.handle(
            actionID: NotificationPolicy.completeActionID,
            timerID: UUID(),
            context: context,
            now: now
        )
        XCTAssertEqual(try context.fetch(FetchDescriptor<TimerEntry>()).count, 0)
    }

    func testUnknownActionLeavesStatusUnchanged() async throws {
        let entry = makeEntry(status: .active)
        try await NotificationActionHandler.handle(
            actionID: "something-else",
            timerID: entry.id,
            context: context,
            now: now
        )
        XCTAssertEqual(entry.status, .active)
    }
}
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 編譯失敗，`cannot find 'NotificationActionHandler' in scope`

- [ ] **Step 3: 在 NotificationPolicy 加入 category 與動作識別碼**

在 `MushroomTimer/Services/NotificationPolicy.swift` 的 `body(groupName:mushroomName:)` 之前插入：

```swift
    static let categoryID = "mushroom-respawn"
    static let completeActionID = "complete"
    static let snoozeActionID = "snooze"
    /// 「延後 1 分鐘」的秒數。
    static let snoozeSeconds = 60
```

- [ ] **Step 4: 讓通知帶上 category**

在 `MushroomTimer/Services/NotificationService.swift` 中，`schedule` 方法的 `content.interruptionLevel = ...` 之後加入：

```swift
        content.categoryIdentifier = NotificationPolicy.categoryID
        content.userInfo = ["timerID": id.uuidString]
```

並在 `cancel(id:)` 之前加入註冊方法：

```swift
    /// 註冊通知上的動作按鈕。App 啟動時呼叫一次即可。
    func registerCategories() {
        let complete = UNNotificationAction(
            identifier: NotificationPolicy.completeActionID,
            title: "已完成",
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: NotificationPolicy.snoozeActionID,
            title: "延後 1 分鐘",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: NotificationPolicy.categoryID,
            actions: [complete, snooze],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }
```

- [ ] **Step 5: 實作 NotificationActionHandler**

`MushroomTimer/Services/NotificationActionHandler.swift`：

```swift
import Foundation
import SwiftData
import UserNotifications

/// 處理通知上的動作按鈕。
///
/// 按下動作時系統會喚醒 App（即使原本沒在執行），所以這裡可以安全地
/// 寫資料庫、重排通知、更新 Live Activity。
final class NotificationActionHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationActionHandler()

    private override init() { super.init() }

    /// 實際的處理邏輯。抽成靜態方法才能不經過 UserNotifications 框架就測到。
    @MainActor
    static func handle(
        actionID: String,
        timerID: UUID,
        context: ModelContext,
        now: Date = .now
    ) async throws {
        var descriptor = FetchDescriptor<TimerEntry>(
            predicate: #Predicate { $0.id == timerID }
        )
        descriptor.fetchLimit = 1
        guard let entry = try context.fetch(descriptor).first else { return }

        switch actionID {
        case NotificationPolicy.completeActionID:
            try await MushroomLogger.complete(entry, context: context)

        case NotificationPolicy.snoozeActionID:
            entry.fireAt = now.addingTimeInterval(TimeInterval(NotificationPolicy.snoozeSeconds))
            entry.status = .active
            try context.save()
            try? await NotificationService.shared.schedule(
                id: entry.id,
                groupName: entry.mushroom?.group?.name ?? "",
                mushroomName: entry.mushroom?.name ?? "",
                at: entry.fireAt
            )
            await LiveActivityController.refresh(context: context)

        default:
            break
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let raw = userInfo["timerID"] as? String,
              let timerID = UUID(uuidString: raw) else { return }
        await MainActor.run {
            Task {
                try? await Self.handle(
                    actionID: response.actionIdentifier,
                    timerID: timerID,
                    context: ModelContainer.shared.mainContext
                )
            }
        }
    }

    /// App 在前景時也要看得到通知，否則使用者會以為沒響。
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
```

- [ ] **Step 6: 在 App 啟動時掛上 delegate 與 category**

`MushroomTimer/MushroomTimerApp.swift` 全檔替換：

```swift
import SwiftData
import SwiftUI
import UserNotifications

@main
struct MushroomTimerApp: App {
    @StateObject private var settings = SettingsStore()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationActionHandler.shared
        NotificationService.shared.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(settings)
        }
        .modelContainer(ModelContainer.shared)
    }
}
```

- [ ] **Step 7: 確認建置與測試通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 8: 【使用者手動】實機驗證通知動作**

**必須停下來請使用者操作並回報結果。** 驗證項目：

1. 建立一筆很短的計時（例如提前量調到最大、剩餘時間 0）
2. 鎖屏等通知響起，長按（或下拉）通知展開動作按鈕
3. 按「延後 1 分鐘」，確認 1 分鐘後再次響起，且 App 內該筆狀態回到進行中
4. 再次響起後按「已完成」，確認該筆從主畫面清單消失

- [ ] **Step 9: Commit**

```bash
cd ~/Developer/MushroomTimer && git add -A && git commit -m "$(cat <<'EOF'
feat: add complete and snooze actions to notifications

Handling an action wakes the app, which is the one moment a fired timer
can be updated without the user opening it. Snooze reschedules a minute
from now and flips the entry back to active.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 18: JSON 匯出與匯入

累積的群組與菇清單是本 App 最有價值的資產，必須能備份。

**Files:**
- Create: `MushroomTimer/Stores/BackupCodec.swift`
- Test: `MushroomTimerTests/BackupCodecTests.swift`

**Interfaces:**
- Consumes: `MushroomGroup`／`Mushroom`（Task 8）
- Produces:
  - `BackupDocument`（`Codable`）：`version: Int`、`groups: [BackupDocument.Group]`
  - `BackupCodec.export(context:) throws -> Data`
  - `BackupCodec.importing(_ data: Data, into context: ModelContext) throws -> Int`（回傳新增的群組數；同 id 的群組視為已存在，跳過）

- [ ] **Step 1: 寫失敗測試**

`MushroomTimerTests/BackupCodecTests.swift`：

```swift
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
}
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 編譯失敗，`cannot find 'BackupCodec' in scope`

- [ ] **Step 3: 實作 BackupCodec**

`MushroomTimer/Stores/BackupCodec.swift`。只備份群組與菇——進行中的計時是短期資料，備份沒有意義。

```swift
import Foundation
import SwiftData

/// 備份檔的格式。與 SwiftData 的 `@Model` 分開定義，
/// 這樣資料庫欄位改動時不會直接破壞既有備份檔。
struct BackupDocument: Codable {
    struct Mushroom: Codable {
        var id: UUID
        var name: String
        var useCount: Int
        var lastUsedAt: Date?
    }

    struct Group: Codable {
        var id: UUID
        var name: String
        var latitude: Double
        var longitude: Double
        var radius: Double
        var createdAt: Date
        var mushrooms: [Mushroom]
    }

    var version: Int
    var groups: [Group]
}

@MainActor
enum BackupCodec {
    static let currentVersion = 1

    static func export(context: ModelContext) throws -> Data {
        let groups = try context.fetch(
            FetchDescriptor<MushroomGroup>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
        )
        let document = BackupDocument(
            version: currentVersion,
            groups: groups.map { group in
                BackupDocument.Group(
                    id: group.id,
                    name: group.name,
                    latitude: group.latitude,
                    longitude: group.longitude,
                    radius: group.radius,
                    createdAt: group.createdAt,
                    mushrooms: group.mushrooms.map {
                        BackupDocument.Mushroom(
                            id: $0.id,
                            name: $0.name,
                            useCount: $0.useCount,
                            lastUsedAt: $0.lastUsedAt
                        )
                    }
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    /// - Returns: 實際新增的群組數。已存在（同 id）的群組會被跳過，不覆寫。
    @discardableResult
    static func importing(_ data: Data, into context: ModelContext) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(BackupDocument.self, from: data)

        let existingIDs = Set(
            try context.fetch(FetchDescriptor<MushroomGroup>()).map(\.id)
        )
        var added = 0
        for group in document.groups where !existingIDs.contains(group.id) {
            let model = MushroomGroup(
                id: group.id,
                name: group.name,
                latitude: group.latitude,
                longitude: group.longitude,
                radius: group.radius,
                createdAt: group.createdAt
            )
            context.insert(model)
            for mushroom in group.mushrooms {
                let mushroomModel = Mushroom(
                    id: mushroom.id,
                    name: mushroom.name,
                    useCount: mushroom.useCount,
                    lastUsedAt: mushroom.lastUsedAt,
                    group: model
                )
                context.insert(mushroomModel)
            }
            added += 1
        }
        try context.save()
        return added
    }
}
```

- [ ] **Step 4: 執行測試確認通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/MushroomTimer && git add -A && git commit -m "$(cat <<'EOF'
feat: add JSON backup export and import

BackupDocument is defined separately from the SwiftData models so schema
changes cannot silently invalidate existing backup files. Import skips
groups whose id already exists instead of duplicating them.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 19: 設定畫面與收尾

把設定、匯出匯入接上 UI，移除第 0 階段的驗證畫面，並依驗證結果補上專注模式的說明。

**Files:**
- Create: `MushroomTimer/Views/SettingsView.swift`
- Modify: `MushroomTimer/Views/MainView.swift`
- Delete: `MushroomTimer/Views/VerificationView.swift`
- Modify: `README.md`

**Interfaces:**
- Consumes: `SettingsStore`（Task 7）、`BackupCodec`（Task 18）
- Produces: `SettingsView`

- [ ] **Step 1: 實作 SettingsView**

`MushroomTimer/Views/SettingsView.swift`：

```swift
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: SettingsStore

    @State private var exportURL: URL?
    @State private var isImporting = false
    @State private var message: String?

    var body: some View {
        List {
            Section("時間") {
                Stepper(
                    "重生時間 \(DurationInput.formatted(seconds: settings.respawnSeconds))",
                    value: $settings.respawnSeconds,
                    in: SettingsStore.respawnRange,
                    step: 10
                )
                Stepper(
                    "預設提前 \(settings.defaultLeadSeconds) 秒",
                    value: $settings.defaultLeadSeconds,
                    in: SettingsStore.leadRange,
                    step: 5
                )
            } footer: {
                Text("提前量會在建立提醒時記錄下來，之後改這裡不會影響已建立的提醒。")
            }

            Section("備份") {
                Button("匯出 JSON") { export() }
                Button("匯入 JSON") { isImporting = true }
            } footer: {
                Text("累積的群組與菇清單是最有價值的資料，建議定期匯出保存。")
            }

            Section("通知準時性") {
                Text(focusModeGuidance)
            }
        }
        .navigationTitle("設定")
        .sheet(item: $exportURL) { url in
            ShareLink(item: url) { Text("分享備份檔") }
                .presentationDetents([.medium])
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json]
        ) { result in
            handleImport(result)
        }
        .alert(
            "備份",
            isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )
        ) {
            Button("好", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    /// 依 `docs/verification-results.md` 的第 0 階段結論擇一保留：
    /// Time Sensitive 可用時說明它已啟用；不可用時引導手動加入允許清單。
    private var focusModeGuidance: String {
        """
        若你使用「專注模式」，請到 設定 → 專注模式 → 你使用的模式 → App，
        把「打菇茜」加入允許通知的清單，提醒才不會被延後。
        """
    }

    private func export() {
        do {
            let data = try BackupCodec.export(context: context)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("打菇茜備份.json")
            try data.write(to: url)
            exportURL = url
        } catch {
            message = "匯出失敗：\(error.localizedDescription)"
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            guard url.startAccessingSecurityScopedResource() else {
                message = "無法讀取這個檔案"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            let added = try BackupCodec.importing(data, into: context)
            message = added > 0 ? "已匯入 \(added) 個群組" : "沒有新的群組可匯入"
        } catch {
            message = "匯入失敗：\(error.localizedDescription)"
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
```

- [ ] **Step 2: 把設定接到 MainView 並移除驗證入口**

`MushroomTimer/Views/MainView.swift` 的 `.toolbar` 區塊替換成：

```swift
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        GroupListView()
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }
            }
```

- [ ] **Step 3: 刪除驗證畫面**

```bash
cd ~/Developer/MushroomTimer && rm MushroomTimer/Views/VerificationView.swift && xcodegen generate
```

若 `MainView.swift` 中仍有 `VerificationView()` 的引用，一併移除。

- [ ] **Step 4: 更新 README**

在 `README.md` 的「文件」清單中加入實作計畫與驗證結果兩個連結：

```markdown
- [設計文件](docs/superpowers/specs/2026-07-25-mushroomtimer-design.md)
- [實作計畫](docs/superpowers/plans/2026-07-25-mushroomtimer.md)
- [第 0 階段驗證結果](docs/verification-results.md)
- [原始需求](docs/requirements.md)
```

- [ ] **Step 5: 確認建置與測試通過**

```bash
cd ~/Developer/MushroomTimer && xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: 確認 xcodegen 重新產生後零 diff**

```bash
cd ~/Developer/MushroomTimer && xcodegen generate && git status --short
```

Expected: 沒有 `MushroomTimer.xcodeproj` 相關的未提交變更（若有，表示產生結果不穩定，需要先解決）

- [ ] **Step 7: 【使用者手動】完整驗收**

**必須停下來請使用者操作並回報結果。** 依設計文件 §12 逐項確認：

1. 主畫面：建群組 → 新增菇 → 點菇 → 輸入「230」→ 建立 → 倒數跑動 → 左滑取消
2. 通知：準時響起、動作按鈕可用
3. Live Activity：只有一張卡、顯示最快的一筆
4. 小工具：按一下完成登記且不開 App
5. 捷徑：桌面捷徑一 tap 完成登記
6. 設定：調整重生時間與提前量、匯出 JSON、重新匯入
7. 單手可操作性、戶外可讀性（實際帶出門走一趟）

- [ ] **Step 8: Commit**

```bash
cd ~/Developer/MushroomTimer && git add -A && git commit -m "$(cat <<'EOF'
feat: add settings screen and remove the phase-0 verification harness

Settings covers respawn time, default lead, JSON backup, and the focus
mode guidance. VerificationView has served its purpose and is deleted.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

## 完成後

實作完畢後，使用 `superpowers:finishing-a-development-branch` 技能決定如何整合（合併、開 PR、或清理）。
