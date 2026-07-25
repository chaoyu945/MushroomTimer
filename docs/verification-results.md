> 待補：Task 3／4／5 的結果尚未填寫，需由 repo owner 在實機上完成手動驗證後填入。
> Task 2 已有結論。

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

## Live Activity（Task 3）

- 無 App Groups 下能否啟動：<能／不能>
- 鎖定畫面倒數是否自己逐秒跑動：<是／否>
- 動態島 compact／expanded 是否正常：<正常／異常說明／機型無動態島>
- **結論**：<可用／需調整，說明>

## 共享 Keychain（Task 4）

- access group 是否解析成功：<是／否>
- 主 App 內寫入後讀回：<成功／失敗>
- 小工具是否顯示出主 App 寫入的內容：<是／否>
- **結論**：<採用 keychain 方案，小工具按鈕顯示菇名／改用 fallback：按鈕顯示「最常用 #1/#2/#3」>

## 小工具按鈕 Intent 的執行 process（Task 5）

- 按下小工具按鈕後 App 是否被開啟：<否／是>
- 主 App 讀到的 process 記錄：<實際字串>
- **結論**：<LiveActivityIntent 有效，Intent 在主 App process 執行／無效，說明>
