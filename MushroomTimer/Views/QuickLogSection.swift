import SwiftData
import SwiftUI

/// 主畫面下半部：目前群組 + 該群組的菇清單（依使用次數排序）。
struct QuickLogSection: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: SettingsStore

    let group: MushroomGroup?
    /// 沒有任何群組時不顯示「切換」，否則按下去只會開一個空的選單。
    let canSwitchGroup: Bool
    /// 定位被拒時要講出來，否則使用者只會覺得判定壞掉。
    let locationDenied: Bool
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
                    // 一個地點可能有二十顆以上的菇，所以格子要夠密才不用一直捲動。
                    // 高度仍保持 44pt——那是點擊目標的下限，再小就容易按錯，
                    // 而按錯的代價是替錯的菇設了提醒。
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 82), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(mushrooms) { mushroom in
                            Button {
                                selectedMushroom = mushroom
                            } label: {
                                Text(mushroom.name)
                                    .font(.subheadline.bold())
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.7)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        if let group {
                            NavigationLink {
                                MushroomListView(group: group)
                            } label: {
                                Label("新增", systemImage: "plus")
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(maxWidth: .infinity, minHeight: 44)
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
            VStack(alignment: .leading, spacing: 2) {
                Text(group?.name ?? "不在任何群組範圍內")
                    .font(.headline)
                if locationDenied {
                    Text("定位權限已關閉，請手動選擇群組")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if canSwitchGroup {
                Button("切換", action: onChangeGroup)
                    .font(.subheadline)
            }
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
