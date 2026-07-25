# 打菇茜 MushroomTimer

Pikmin Bloom 打菇重生提醒 App（iOS 17+）。

菇被打爆後約 5 分鐘原地重生，重生名額有限，必須在重生當下人在現場。本 App 把「登記一顆菇」壓縮到 2～3 個 tap、全程零打字：菇的身分靠「地點群組 + 預先建立的清單」辨識，提醒時間自動計算。

## 文件

- [設計文件](docs/superpowers/specs/2026-07-25-mushroomtimer-design.md)
- [實作計畫](docs/superpowers/plans/2026-07-25-mushroomtimer.md)
- [第 0 階段驗證結果](docs/verification-results.md)
- [原始需求](docs/requirements.md)

## 開發

專案以 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 產生。修改 `project.yml` 後執行：

```bash
xcodegen generate
```

測試：

```bash
xcodebuild -project MushroomTimer.xcodeproj -scheme MushroomTimer \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

使用免費 Apple Developer 帳號（Personal Team）簽署，因此不使用 App Groups、遠端推播、iCloud 等需要 entitlement 的能力。詳見設計文件第 2 節。
