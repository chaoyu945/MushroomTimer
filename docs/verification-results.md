> 狀態：**第 0 階段四項全部完成，可以進入第 1 階段。**

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

## 共享 Keychain（Task 4）— ✅ 可用（修掉一個 bug 之後）

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

### 修正後的實機重測（2026-07-25）

- access group 是否解析成功：**是**
- 主 App 內寫入後讀回：**成功**
- 小工具是否顯示出主 App 寫入的內容：**是**
- 鎖屏一輪後內容是否還在：**是**（保護等級 `kSecAttrAccessibleAfterFirstUnlock` 正確）

- **結論**：**採用 keychain 方案，小工具按鈕直接顯示菇名。**
  不需要走「最常用 #1/#2/#3」的 fallback。Task 15 照原設計實作。

## 小工具按鈕 Intent 的執行 process（Task 5）— ✅ LiveActivityIntent 有效

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

### 修正後的實機重測（2026-07-25）

Task 4 修好之後小工具才真的長出菇按鈕，這次是**從小工具按鈕**觸發，不是從捷徑：

- 清除 marker 後按下小工具上的菇按鈕：**App 沒有被開啟**
- 主 App 讀到的 process 記錄：`MushroomTimer / com.chaoyu.MushroomTimer`

- **結論**：**`LiveActivityIntent` 有效。** 小工具按鈕觸發的 Intent 確實在主 App 的
  process 背景執行，因此可以寫入 SwiftData、排定通知、更新 Live Activity。
  Task 14 的 App Intents 與 Task 15 的互動式小工具照原設計實作。

---

## 第 0 階段總結

| 項目 | 結果 | 對設計的影響 |
|---|---|---|
| Time Sensitive 通知 | ❌ 免費帳號不支援 | 改用 `.active` + 設定頁引導專注模式允許清單 |
| Live Activity（無 App Groups） | ✅ 可用 | 維持原設計，資料全靠 `ContentState` 傳遞 |
| 共享 Keychain | ✅ 可用 | 維持原設計，小工具按鈕顯示菇名，不走 fallback |
| 小工具 Intent 執行 process | ✅ `LiveActivityIntent` 有效 | 維持原設計，Intent 在主 App process 背景執行 |

四項中只有一項需要改設計，且改動已完成。可以進入第 1 階段。

---

## 待實機驗證的項目（第 2、3 階段）

以下無法用單元測試或模擬器涵蓋，需要在實機上確認：

### App Intents（Task 14）

- [ ] 捷徑 App 裡「菇」的參數是**下拉選單**，不是要打字的欄位
- [ ] 把某顆菇預先綁定、存成桌面捷徑，點一下能建立計時，**且 App 不會被開啟**
- [ ] Siri 唸出設定的語句能觸發
- [ ] **預先綁定的菇被刪掉之後**再點該捷徑會怎樣（靜默失敗？錯誤訊息？）
- [ ] **關掉通知權限後**點桌面捷徑：`notificationFailed` 在沒有畫面的情況下
      使用者看得到任何提示嗎？這是最可能靜默失敗的族群

---

## 實機使用回饋與處置（2026-07-26）

### 捷徑不能選時間 — 已修

三個 Intent 都缺 `parameterSummary`。App Intents 在捷徑編輯器裡顯示哪些參數是由它決定的，
沒有它，剩餘秒數欄位根本不會出現——菇選得到、時間選不到。

補上之後，「登記一顆菇」可以把**菇和秒數各自預先綁定**，做成
「7-11 門口 · 剛爆」「7-11 門口 · 2:30」這類桌面捷徑，一點即完成、App 不用開。
這才是需求文件 §5.6 說的「價值最高的部分」原本該有的樣子。

「快速登記」（`QuickLogIntent`）已設為不可探索——它只服務小工具按鈕，
參數是菇的 UUID 字串，出現在捷徑清單裡只會造成混淆。

### 小工具只顯示三顆 — 已改善

實機確認：**互動式小工具本來就正常運作**，按下去計時確實會建立
（有時會跳成功提示、有時不會，取決於系統當下是否顯示 dialog）。
問題純粹是可用性：任何尺寸都只露出三顆，而一個地點常有二十顆以上。

已改成依尺寸決定：小 3、中 6、大 12，並新增支援大尺寸。

**小工具無法選時間，這是先天限制**：widget 的按鈕只能執行參數固定的 intent，
沒有辦法在 widget 裡叫出輸入介面。所以它固定用「剛爆」——那本來就是它要服務的情境
（你剛打爆一顆，需要立刻設提醒）。要指定剩餘時間請用捷徑或開 App。

### 動態島到期後停在 0:00 — 符合設計，但呈現方式已改善

這是免費帳號的硬限制：沒有遠端推播，App 沒在執行時卡片無法自己換成下一筆。
原本會停在 0:00，看起來像當掉。現在改成顯示「已到期 · 開啟看下一個」，
誠實表達「我需要你開一下 App」。要真正做到自動換下一筆，只能改用付費帳號加推播。

---

## App 圖示：通知中心顯示占位圖（2026-08-04）

症狀：主畫面顯示正確的圖示，但通知中心／鎖定畫面的通知顯示灰色占位圖。

### 兩個獨立的原因，依序發生

**第一個是真的 bug（已修）。** `make-appicon.sh` 原本只寫一張 1024 的
`Contents.json`，指望資產編譯器自己衍生尺寸——它沒有。用 `assetutil` 檢查
建置產物可以直接看出來：

```
修正前：Assets.car 內 AppIcon rendition = 1（只有 1024 原圖）
修正後：實機組態 = 23，含 40px@2x 與 60px@3x（通知用的 20pt）
```

主畫面之所以正常，是因為 bundle 裡剛好另有一張鬆散的 120×120。
通知用的 20pt 圖示則完全不存在，所以 iOS 沒東西可畫。

腳本現在明確產生 20/29/40/60pt 的 @2x 與 @3x 加 1024，不再依賴編譯器代勞。

**第二個不是 bug，是 iOS 的快取。** 修好之後重新建置、甚至刪除重裝，通知中心
仍可能顯示舊圖或占位圖——通知中心的圖示快取與 SpringBoard 是分開的，
iOS 18.1 之後有已知的不更新問題。**解法是重新開機**，重裝沒有用。

參考：<https://developer.apple.com/forums/thread/780074>

### ⚠️ 刪除 App 會清掉全部資料

沒有 iCloud、沒有帳號，資料只在 App 容器裡。**刪除前務必先用設定頁的
JSON 匯出備份**，否則累積的群組與菇清單會全部消失，而那是這個 App 最有價值的資產。
排查圖示問題時請優先重開機，不要刪除重裝。
