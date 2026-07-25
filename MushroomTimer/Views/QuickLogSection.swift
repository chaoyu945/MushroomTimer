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
