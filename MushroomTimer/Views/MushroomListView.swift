import SwiftData
import SwiftUI

/// 單一群組底下的菇清單與 CRUD。
struct MushroomListView: View {
    @Environment(\.modelContext) private var context
    let group: MushroomGroup

    @State private var isAddingMushroom = false
    @State private var draftName = ""
    @State private var editingGroupName = false
    @State private var draftGroupName = ""
    @State private var saveError: String?

    private var sortedMushrooms: [Mushroom] {
        TimerQueries.mostUsed(in: group, limit: group.mushrooms.count)
    }

    var body: some View {
        List {
            Section("菇") {
                if group.mushrooms.isEmpty {
                    Text("還沒有菇，按下方「新增菇」建立。")
                        .foregroundStyle(.secondary)
                }
                ForEach(sortedMushrooms) { mushroom in
                    HStack {
                        Text(mushroom.name)
                        Spacer()
                        Text("\(mushroom.useCount) 次")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("刪除", role: .destructive) {
                            context.delete(mushroom)
                            save()
                        }
                    }
                }
                Button("新增菇") {
                    draftName = ""
                    isAddingMushroom = true
                }
            }

            Section("群組設定") {
                Button("重新命名群組") {
                    draftGroupName = group.name
                    editingGroupName = true
                }
                LabeledContent("判定半徑", value: "\(Int(group.radius)) 公尺")
                Slider(
                    value: Binding(
                        get: { group.radius },
                        set: { group.radius = $0; save() }
                    ),
                    in: 20...300,
                    step: 10
                )
            }
        }
        .navigationTitle(group.name)
        .alert("新增菇", isPresented: $isAddingMushroom) {
            TextField("例如：7-11 門口", text: $draftName)
            Button("取消", role: .cancel) {}
            Button("新增") { addMushroom() }
        } message: {
            Text("取一個現場一眼認得出來的名字。")
        }
        .alert("重新命名群組", isPresented: $editingGroupName) {
            TextField("群組名稱", text: $draftGroupName)
            Button("取消", role: .cancel) {}
            Button("儲存") {
                let trimmed = draftGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                group.name = trimmed
                save()
            }
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
        }
    }

    private func addMushroom() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let mushroom = Mushroom(name: trimmed, group: group)
        context.insert(mushroom)
        save()
    }
}
