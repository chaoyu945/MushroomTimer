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
            Section {
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
            } header: {
                Text("時間")
            } footer: {
                Text("提前量會在建立提醒時記錄下來，之後改這裡不會影響已建立的提醒。")
            }

            Section {
                Button("匯出 JSON") { export() }
                Button("匯入 JSON") { isImporting = true }
            } header: {
                Text("備份")
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

    /// 第 0 階段已驗證：免費帳號不支援 Time Sensitive，所以這段引導是必要的，
    /// 不是二選一。通知用的是 `.active`，會被「專注模式」擋下來。
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
            // 匯入會改到群組與菇，小工具與 Live Activity 都可能指著已經不存在
            // （或剛新增）的資料，跟 MushroomListView.save() 一樣要跟著刷新。
            WidgetChannel.refresh(context: context)
            Task { await LiveActivityController.refresh(context: context) }
            message = added > 0 ? "已匯入 \(added) 個群組" : "沒有新的群組可匯入"
        } catch {
            message = "匯入失敗：\(error.localizedDescription)"
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
