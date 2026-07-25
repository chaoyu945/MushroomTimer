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
