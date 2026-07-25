import SwiftData
import SwiftUI

/// 群組的清單與 CRUD。
struct GroupListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MushroomGroup.createdAt, order: .reverse)
    private var groups: [MushroomGroup]

    @State private var pendingDeletion: MushroomGroup?
    @State private var saveError: String?

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
                // 這裡刻意用 destination closure，而不是 value + navigationDestination。
                // GroupListView 本身是被 MainView 的 NavigationStack 推進來的，
                // 在這裡宣告 navigationDestination 註冊得太晚：第一次點只會播動畫、
                // 不會真的推入，要返回再進去才會生效。
                NavigationLink {
                    MushroomListView(group: group)
                } label: {
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
                    save()
                }
                pendingDeletion = nil
            }
        } message: {
            Text("底下的 \(pendingDeletion?.mushrooms.count ?? 0) 顆菇會一併刪除，且無法復原。")
        }
        .alert(
            "儲存失敗",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("好", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    /// 存檔失敗時要讓使用者看到。這兩個畫面管的是全 App 最有價值的資料，
    /// 靜默失敗會讓人以為改動生效了。
    private func save() {
        do {
            try context.save()
        } catch {
            saveError = error.localizedDescription
            return
        }
        // 群組與菇的任何異動都會改變小工具該顯示什麼。漏掉這行，小工具就會
        // 留著已刪除的菇的按鈕，按下去是無聲的沒反應。
        WidgetChannel.refresh(context: context)
    }
}
