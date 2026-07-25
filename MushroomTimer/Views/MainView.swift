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
