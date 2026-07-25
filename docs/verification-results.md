> 狀態：Task 2 與 Task 3 已定案。Task 4 找到並修掉了 bug，與 Task 5 一起待實機重測。

# 第 0 階段驗證結果

## Time Sensitive 通知（Task 2）— ❌ 不可用，已改走 fallback

- 日期：2026-07-25
- 帶 time-sensitive entitlement 能否安裝到實機：**不能，連 provisioning profile 都建不出來**

  Xcode 錯誤訊息：

  ```
  Cannot create a iOS App Development provisioning profile for "com.chaoyu.MushroomTimer".
  Personal development teams do not support the
  Time Sensitive Notifications capability.
  ```

- 設定中是否出現「時效性通知」開關：無法驗證（App 裝不上去）
- 勿擾模式下是否準時響起：無法驗證
- **結論**：**改用一般通知（`.active`），並在設定頁引導使用者手動把本 App 加入
  「專注模式」的允許清單。** 效果相同且不需要任何 entitlement。

已套用的變更：

- `project.yml` 移除 `com.apple.developer.usernotifications.time-sensitive`
- `NotificationPolicy.interruptionLevel` 改為 `.active`
- Task 19 的設定頁保留專注模式允許清單的說明文字（不再是二選一）

日後若改用付費開發者帳號，把上述兩處改回去即可。

## Live Activity（Task 3）— ✅ 可用

- 日期：2026-07-25
- 無 App Groups 下能否啟動：**能**。

  補充說明：這一項不需要使用者另外檢查什麼。App Groups 是 iOS 上讓主 App 與
  extension 共用一塊檔案區的機制，需要付費帳號才能簽。本專案的 entitlements 裡
  從頭到尾就沒有它（只有 keychain-access-groups），所以 Live Activity 能正常啟動
  並顯示，本身就是「不靠 App Groups 也能運作」的證明。

- 鎖定畫面倒數是否自己逐秒跑動：**是**（證明 `Text(timerInterval:)` 的零背景作業做法成立）
- 動態島 compact／expanded 是否正常：**正常**
- **結論**：**可用，維持原設計。** 全部資料靠 `ContentState` 傳遞的做法確認可行。

## 共享 Keychain（Task 4）— ⚠️ 第一次失敗，已找到並修掉原因，待重測

第一次實機驗證（2026-07-25）：

- access group 是否解析成功：**否**
- 主 App 內寫入後讀回：**失敗**
- 小工具是否顯示出主 App 寫入的內容：**否**

### 根本原因

不是 Keychain Sharing 不能用，是程式碼有 bug，而且失敗得完全沒有聲音。

`teamIdentifierPrefix()` 把同一個字典同時餵給 `SecItemCopyMatching` 與 `SecItemAdd`，
字典裡含有 `kSecMatchLimit`。這是**搜尋專用**的 key，對 `SecItemAdd` 而言並不合法。

關鍵在於它的失敗方式：`SecItemAdd` **不會回傳錯誤**（status 仍是 `errSecSuccess`），
而是讓回傳值不再是屬性字典。於是 `result as? [String: Any]` 轉型失敗，
`agrp`（access group）被丟掉，prefix 變成 `nil`，整條主 App ↔ 小工具的通道靜默斷掉。

這個 bug 在模擬器上就能重現，也已寫成回歸測試（`MushroomTimerTests/SharedKeychainTests.swift`）。
拿掉 `kSecMatchLimit` 之後，探測正確回傳 `<TeamID>.com.chaoyu.MushroomTimer.shared`。
（`SecItemCopyMatching` 未指定 match limit 時本來就等同 `kSecMatchLimitOne`，
所以拿掉它不影響搜尋行為。）

原本這一項完全沒有單元測試涵蓋，才會等到實機才發現。現在補上了 4 個測試。

- **結論**：**待重測。** 修正後模擬器上 4 個測試全數通過，需要在實機上再跑一次
  Task 4 Step 9 才能定案要採用 keychain 方案還是 fallback。

## 小工具按鈕 Intent 的執行 process（Task 5）— ⚠️ 結果存疑，待重測

第一次實機驗證（2026-07-25）：

- 按下小工具按鈕後 App 是否被開啟：**是**
- 主 App 讀到的 process 記錄：`MushroomTimer / com.chaoyu.MushroomTimer`

### 為什麼存疑

這兩筆觀察跟 Task 4 的失敗互相矛盾：

1. Task 4 失敗代表 payload 讀不到，小工具當時只會顯示「讀不到 payload」，
   **根本沒有菇的按鈕可以按**。那這筆 marker 是哪裡來的？
2. `QuickLogIntent` 設了 `openAppWhenRun = false`，從小工具按鈕觸發時不該開啟 App。
   「App 被開啟」不符合預期。

最可能的情況是這次是從**捷徑 App** 執行 intent（`QuickLogIntent` 是 AppIntent，
會出現在捷徑裡），而不是從小工具按鈕。從捷徑執行本來就會在主 App process 跑、
也可能把 App 帶到前景——所以 marker 是對的，但**沒有驗證到小工具按鈕這條路徑**，
而那正是這一項要證明的事。

- **結論**：**待重測。** Task 4 修好之後小工具才會真的長出菇按鈕，
  屆時再依 Task 5 Step 8 的步驟重跑一次（記得先點「清除 marker」）。
