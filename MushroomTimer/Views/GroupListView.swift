import SwiftData
import SwiftUI

/// 群組的清單與 CRUD。
struct GroupListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MushroomGroup.createdAt, order: .reverse)
    private var groups: [MushroomGroup]

    @State private var pendingDeletion: MushroomGroup?

    var body: some View {
        List {
            if groups.isEmpty {
                ContentUnavailableView(
                    "還沒有群組",
                    systemImage: "mappin.slash",
                    description: Text("回主畫面按「建立新群組」，以目前位置建立第一個群組。")
                )
            }
            ForEach(groups) { group in
                NavigationLink(value: group) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                        Text("\(group.mushrooms.count) 顆菇 · 半徑 \(Int(group.radius)) 公尺")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button("刪除", role: .destructive) {
                        pendingDeletion = group
                    }
                }
            }
        }
        .navigationTitle("群組")
        .navigationDestination(for: MushroomGroup.self) { group in
            MushroomListView(group: group)
        }
        .alert(
            "刪除「\(pendingDeletion?.name ?? "")」？",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            )
        ) {
            Button("取消", role: .cancel) { pendingDeletion = nil }
            Button("刪除", role: .destructive) {
                if let group = pendingDeletion {
                    context.delete(group)
                    try? context.save()
                }
                pendingDeletion = nil
            }
        } message: {
            Text("底下的 \(pendingDeletion?.mushrooms.count ?? 0) 顆菇會一併刪除，且無法復原。")
        }
    }
}
