# 打菇茜（MushroomTimer）— 設計文件

日期：2026-07-25

## 1. 背景與目標

使用者是 Pikmin Bloom 玩家。地圖上的「菇」被打爆後約 5 分鐘在原地重生，重生後前 5 名才能免費參戰，因此必須在重生當下人在現場。

現行做法是用 iOS 內建時鐘手動設鬧鐘並打字標註哪顆菇，痛點有二：現場沒空打字；同區域菇太多，光看鬧鐘標籤分不出是哪顆。

設計核心：

- 登記一顆菇壓縮到 2～3 個 tap，全程零打字
- 菇的身分靠「地點群組 + 預先建立的清單」辨識，不靠即時輸入
- 提醒時間自動計算，使用者只輸入眼睛看到的剩餘時間

完整原始需求保存於 [docs/requirements.md](../../requirements.md)。本文件是據此展開的設計決策，兩者衝突時以本文件為準（本文件第 3 節記載了對原始需求的兩項技術修正）。

### 明確排除

菇的種類／等級記錄、每日免費次數統計、任何遊戲資料自動抓取、帳號系統／雲端同步。

## 2. 技術約束

使用免費 Apple Developer 帳號（Personal Team），以下能力一律不可使用：App Groups、遠端推播、iCloud/CloudKit、Sign in with Apple、Associated Domains。

由此衍生的架構紅線：

- **Widget extension 與主 App 是不同 process，且無 App Groups 可共用檔案區。** Widget extension 不可存取主 App 的 SwiftData 資料庫。Live Activity 顯示所需的全部資料，必須在建立／更新當下透過 `ActivityAttributes` 與 `ContentState` 一次打包傳遞。entitlements 中絕不可出現任何 App Group 設定。
- **倒數不可用背景輪詢或定時推送實作。** 一律使用 SwiftUI 的 `Text(timerInterval:countsDown:)`：給定結束時間後元件自己逐秒跑動，零背景作業、零耗電。每筆提醒的結束時間在建立當下即已算出，因此這個做法同時繞開了上一條限制。
- **App ID 設定每 7 天僅能修改 10 次。** Bundle ID 與所有 entitlement 必須一開始就定案，見第 4 節。
- provisioning profile 每 7 天過期，需重新從 Xcode 安裝（使用者已知悉並接受）。
- 資料全部存本機，不需考慮同步或衝突處理。

### 2.1 通知可靠度（需第 0 階段驗證）

提前量可能只有 15 秒，通知必須準時響且不被「專注模式」擋掉。理想做法是 Time Sensitive（時效性通知），但這可能需要 entitlement，免費帳號未必能簽。

第 0 階段先驗證：可用則使用 Time Sensitive；不可用則改用一般通知，並在 App 說明頁引導使用者手動把本 App 加入專注模式允許清單（不需任何 entitlement，效果相同）。

## 3. 對原始需求的兩項技術修正

這兩點是設計階段查證後對原始需求文件的修正，實作時以本節為準。

### 3.1 小工具按鈕的 Intent 必須在主 App process 執行

從 widget 按鈕觸發的 App Intent，**預設在 widget extension 的 process 執行**。在無 App Groups 的前提下，該 process 讀寫不到主 App 的 SwiftData 資料庫，登記動作會失敗。

解法：所有登記類 Intent 遵循 `LiveActivityIntent` protocol。系統會改在主 App 的 process 背景執行該 Intent（不會開啟 App UI）。語意上也正確——這些 Intent 本來就要建立或更新 Live Activity。

### 3.2 小工具的資料來源改用 Keychain 共享

原始需求 §5.7 假設「主 App 主動把要顯示的菇清單推送給小工具」，但 WidgetKit 沒有這個機制：timeline 是由 widget extension 自己的 `TimelineProvider` 拉取的，而在無 App Groups 時 widget process 讀不到主 App 的任何資料。

解法：使用 **Keychain Sharing** entitlement（`keychain-access-groups`）。這不屬於 App Groups 那類受限能力，免費帳號一般可用。主 App 在資料異動時把一份精簡 payload（目前群組名稱 + 最常用 2～3 顆菇的 id 與名稱）寫入共享 keychain 並呼叫 `WidgetCenter.reloadAllTimelines()`；widget 的 TimelineProvider 只讀這份 payload，不做任何資料查詢。

此方案需在第 0 階段實測。若免費帳號無法使用 Keychain Sharing，退回 fallback：小工具按鈕顯示固定文字「最常用 #1 / #2 / #3」，按下時才在主 App process 內解析對應到哪顆菇。功能相同，只是按鈕上看不到菇名。

### 3.3 Live Activity 的已知限制

免費帳號無遠端推播，因此當主 App 沒有在執行時，Live Activity **無法**在最快一筆到期的瞬間自動切換到下一筆。

緩解方式：`ContentState` 一併攜帶「下一筆」的資訊，讓畫面在當前這筆結束後仍有意義；並在每次主 App process 有機會執行時（進入前景、Intent 執行、通知動作處理）都重新整理 Live Activity。這是免費帳號下的固有限制，不視為 bug。

## 4. 專案設定（一次定案）

| 項目 | 值 |
|---|---|
| 專案／repo 名稱 | MushroomTimer（公開 repo `chaoyu945/MushroomTimer`） |
| 主 App Bundle ID | `com.chaoyu.MushroomTimer` |
| Widget extension Bundle ID | `com.chaoyu.MushroomTimer.Widgets` |
| 顯示名稱 | 打菇茜 |
| 最低支援版本 | iOS 17.0 |
| 裝置 | iPhone only |
| UI 語言 | 繁體中文（zh-TW） |

專案以 XcodeGen 產生（沿用 StepCheat 慣例）：編輯 `project.yml` 後執行 `xcodegen generate`，產生的 `.xcodeproj` 進版控，且重新產生必須是零 diff。`DEVELOPMENT_TEAM` 不進 git（xcodegen 會將其移除，建置時在 Xcode 重新選 Team）。

### Targets

| Target | 型別 | 說明 |
|---|---|---|
| MushroomTimer | application | 主 App |
| MushroomTimerWidgets | app extension (WidgetKit) | 互動式小工具與 Live Activity 共用同一個 extension |
| MushroomTimerTests | unit test bundle | scheme 掛在主 target |

### Entitlements（一次到位，避免消耗 App ID 修改額度）

- 兩個 target 都加入 `keychain-access-groups`：`$(AppIdentifierPrefix)com.chaoyu.MushroomTimer.shared`
- 主 App 加入 `com.apple.developer.usernotifications.time-sensitive`。若第 0 階段驗證不可用，移除此項並改走專注模式引導。
- 絕不出現 App Groups。

### Info.plist（主 App）

`NSSupportsLiveActivities: true`、`NSLocationWhenInUseUsageDescription`、`CFBundleDisplayName: 打菇茜`。位置權限僅需「使用 App 期間」，不要求「永遠允許」。

## 5. 目錄結構

沿用 StepCheat 的分層：

```
MushroomTimer/
  MushroomTimerApp.swift
  Models/       # SwiftData models、TimerCalculator、輸入解析
  Services/     # Notification / Location / LiveActivity / WidgetChannel
  Stores/       # SettingsStore、匯出匯入
  Views/        # MainView、TimeInputSheet、CRUD、Settings
  Intents/      # LogMushroomIntent、QuickLogHereIntent、MushroomEntity
MushroomTimerWidgets/
MushroomTimerTests/
```

## 6. 資料模型（SwiftData）

SwiftData 是 iOS 17 的本機 ORM，等同於帶 ORM 的本機 SQLite；`@Query` 可讓 UI 自動跟著資料變動更新。

命名刻意避開系統型別衝突（`Group` 撞 SwiftUI、`Timer` 撞 Foundation）。

### MushroomGroup（地點群組）

代表一個地理區域，例如「中山路口」。

| 欄位 | 型別 | 說明 |
|---|---|---|
| id | UUID | PK |
| name | String | 可編輯 |
| latitude | Double | 建立當下的緯度 |
| longitude | Double | 建立當下的經度 |
| radius | Double | 判定半徑，預設 80 公尺 |
| createdAt | Date | |
| mushrooms | [Mushroom] | cascade delete |

### Mushroom（菇）

| 欄位 | 型別 | 說明 |
|---|---|---|
| id | UUID | PK |
| name | String | 例如「7-11 門口」「天橋下」 |
| useCount | Int | 使用次數，用於清單排序 |
| lastUsedAt | Date? | |
| group | MushroomGroup | 所屬群組 |

### TimerEntry（計時）

| 欄位 | 型別 | 說明 |
|---|---|---|
| id | UUID | PK |
| mushroom | Mushroom | |
| createdAt | Date | 登記當下的時間 |
| remainingSeconds | Int | 使用者輸入的剩餘秒數 |
| leadSeconds | Int | 本筆使用的提前量快照 |
| fireAt | Date | 計算後的提醒時間 |
| status | Enum | active / fired / completed / cancelled |

`leadSeconds` 存快照：使用者之後修改全域預設值，不影響已建立的計時。

`fired` 狀態採惰性判定——本機通知觸發不會喚醒 App，因此在 App 開啟或處理通知動作時，才把 `fireAt` 已過的 active 筆數標記為 fired。

### 全域設定（UserDefaults，`SettingsStore`）

| 項目 | 預設值 | 說明 |
|---|---|---|
| respawnSeconds | 300 | 菇的重生時間，可調整以防官方改動 |
| defaultLeadSeconds | 15 | 預設提前量 |

`ModelContainer` 由主 App 與 App Intents 共用（同一 process）。Widget extension 完全不接觸 SwiftData。

## 7. 核心計算

```
fireAt = now + remainingSeconds + respawnSeconds - leadSeconds
```

範例：菇還剩 2:30，重生 5:00，提前 15 秒 → 150 + 300 − 15 = 435 秒 = 7:15 後提醒。

邊界處理：

- 計算結果 ≤ 現在時間時，提示「時間已過」，不建立計時
- `remainingSeconds` 允許為 0（代表剛爆）
- 全部以秒（Int）計算，避免浮點誤差

輸入解析：數字字串「230」解讀為 2:30，即 150 秒。

`TimerCalculator` 與輸入解析都是純函式，是單元測試的主要對象。

## 8. 服務層

### NotificationService

本機通知，使用 `UNTimeIntervalNotificationTrigger`。內容格式：`【中山路口】7-11 門口 的菇要重生了`。

通知動作按鈕：「已完成」將該筆標記為 completed；「延後 1 分鐘」把 `fireAt` 加 60 秒並重新排定。動作由主 App 的 `UNUserNotificationCenterDelegate` 處理——處理時 App 會被喚醒，因此可以寫資料庫並更新 Live Activity。

`interruptionLevel` 依第 0 階段的 Time Sensitive 驗證結果決定。

### LocationService

App 進入前景時取得一次目前位置，不使用背景定位。找出距離最近且在 `radius` 內的 `MushroomGroup`。建立新群組時用 `CLGeocoder` 反向地理編碼產生預設名稱，使用者可直接採用或改寫。

判定出的「目前群組 id」寫入 UserDefaults，供 `QuickLogHereIntent` 在不觸發 GPS 的情況下使用。

### LiveActivityController

全程只維持**一個** Live Activity（動態島同時只能顯示一個），內容永遠是最快到期的那一筆，並附帶還有幾筆在排隊（例如「+2」）。全部計時結束時結束 Live Activity。

顯示所需的全部資料放進 `ContentState`：菇名稱、群組名稱、`fireAt`、排隊筆數、下一筆資訊。倒數一律用 `Text(timerInterval:)`。

四種版面：

| 版面 | 內容 |
|---|---|
| Compact leading | 菇 icon |
| Compact trailing | 倒數時間 |
| Minimal | 倒數時間 |
| Expanded | 菇名稱 + 群組 + 倒數 + 排隊筆數 |

限制與緩解見 §3.3。

### WidgetChannelStore

讀寫共享 keychain 中的 JSON payload（目前群組名稱 + 最常用 2～3 顆菇的 id 與名稱）。主 App 在資料異動時寫入並呼叫 `WidgetCenter.reloadAllTimelines()`。Widget 端只讀不寫。

## 9. App Intents

App Intents 可理解為「把 App 的功能開放成 API endpoint」，開放後捷徑 App、Siri、動作按鈕、背面輕點、控制中心、鎖定畫面都能呼叫。這是本專案價值最高的部分。

| Intent | 參數 | 行為 |
|---|---|---|
| `LogMushroomIntent` | 菇（可選）、剩餘時間（可選） | 建立一筆計時 |
| `QuickLogHereIntent` | 剩餘時間 | 用目前群組中最常用的菇建立計時 |
| 小工具按鈕 Intent | 菇 id（剩餘時間固定為 0） | 以「剛爆」建立一筆計時 |

`MushroomEntity` 搭配 `EntityQuery` 提供選項清單，讓使用者在捷徑 App 裡用選的而非打字，並支援參數預先綁定——使用者可針對常打的菇各做一個捷徑放到桌面，達成一個 tap 完成登記、App 完全不用開啟。

三個 Intent 都遵循 `LiveActivityIntent`（見 §3.1），在主 App process 背景執行，不開啟 App、不需要 GPS。執行內容一致：建立 `TimerEntry` → 排定通知 → 更新 Live Activity → `useCount` 加一 → 更新 keychain payload。

## 10. 使用者介面

所有主要操作按鈕位於畫面下半部（使用情境是邊走邊單手操作）。對比度要夠，倒數數字要大（戶外可讀性）。

### MainView

上半部是進行中的計時清單：依 `fireAt` 由近到遠排序，每筆顯示菇名稱、所屬群組、逐秒跑動的倒數，左滑取消該筆，空狀態顯示引導文字。

下半部是快速登記區：頂端顯示目前 GPS 判定的群組名稱，旁邊有切換按鈕可手動改選鄰近群組（市區 GPS 誤差可達 10～30 公尺，自動判定不一定準，此按鈕為必要）；不在任何已知群組範圍內時顯示「建立新群組」。下方列出該群組的菇清單，依 `useCount` 由高到低排序，末端固定一個「＋ 新增菇」。

### TimeInputSheet

點選一顆菇後跳出的剩餘時間輸入介面：數字鍵盤輸入（「230」自動解讀為 2:30）、「剛爆」按鈕（等同 0）、即時顯示計算結果供確認（例如「7:15 後提醒 · 21:43:20」）、`−5s` / `+5s` 兩顆按鈕微調提前量（預設帶入全域設定值）。

確認後建立 TimerEntry、排定通知、啟動 Live Activity。整個流程 2～3 個 tap，全程不需打字。

### 資料管理與設定

群組與菇的 CRUD 介面；刪除群組時 cascade 刪除其下的菇，需二次確認。設定頁包含 `respawnSeconds`、`defaultLeadSeconds`、JSON 匯出／匯入（累積的群組與菇清單是本 App 最有價值的資產），以及在 Time Sensitive 不可用時的專注模式允許清單引導說明。

### 互動式桌面小工具

顯示目前群組中最常用的 2～3 顆菇，每顆一顆按鈕，按下直接以「剛爆」建立計時。這預期會是最主要的入口，因為速度最快。資料來源見 §3.2，執行 process 見 §3.1。

## 11. 實作順序

### 第 0 階段：驗證（最先做，全部通過才往下）

1. 用 XcodeGen 建立骨架專案，entitlements 一次設定到位，確認免費帳號可安裝到實機
2. 驗證 Time Sensitive 通知能否簽署，並在專注模式下實測 → 決定通知策略
3. 驗證最小 Live Activity 在不使用 App Groups 下正常運作
4. 驗證小工具按鈕的 `LiveActivityIntent` 確實在主 App process 執行、可寫入 SwiftData、可排定通知
5. 驗證 app 與 widget 之間的 keychain 共享 → 決定小工具顯示方案（菇名 vs 通用按鈕）

### 第 1 階段：可用的 MVP

SwiftData models 與 TimerCalculator（含單元測試）→ 群組／菇 CRUD → TimeInputSheet → 本機通知 → MainView 計時清單。完成這一階段，App 已明顯優於內建時鐘。

### 第 2 階段：降低操作摩擦

GPS 群組自動辨識與反向地理編碼 → App Intents（含捷徑預先綁定）→ 互動式桌面小工具。

### 第 3 階段：體驗優化

Live Activity／動態島 → JSON 匯出匯入 → 通知動作按鈕。

## 12. 驗證方式

單元測試涵蓋：`TimerCalculator` 邊界（結果 ≤ now、剩餘時間為 0、`leadSeconds` 快照不受全域設定變動影響）、「230」輸入解析、最近群組判定、`useCount` 排序、JSON 匯出匯入 roundtrip。

```
xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

模擬器驗證：UI 流程，以及用模擬定位（自訂座標）驗證群組辨識。

實機驗證（需使用者手動操作）：通知準時性與專注模式行為、Live Activity 顯示、小工具按鈕、捷徑預先綁定的一 tap 登記。

## 13. 非功能性需求

- 最低支援 iOS 17.0（互動式小工具的需求）
- 單手可操作：主要操作按鈕位於畫面下半部
- 戶外可讀性：高對比、倒數數字大
- 離線運作：除反向地理編碼外全部功能不依賴網路
- 省電：不使用背景定位、不使用背景輪詢

App icon 先用 placeholder。若之後改用私人照片，比照 StepCheat 的做法：icon 原始檔與 `Assets.xcassets` 加入 gitignore，另以腳本在本機重建，絕不 commit。
