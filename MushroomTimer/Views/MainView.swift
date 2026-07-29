import CoreLocation
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.chaoyu.MushroomTimer", category: "MainView")

struct MainView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \MushroomGroup.createdAt, order: .reverse)
    private var groups: [MushroomGroup]

    @State private var selectedGroupID: UUID?
    @State private var isPickingGroup = false
    @StateObject private var location = LocationService()
    @State private var gps: GPSResolution = .pending
    @State private var isCreatingGroup = false
    @State private var draftGroupName = ""
    @State private var draftCoordinate: (latitude: Double, longitude: Double)?
    @State private var errorMessage: String?

    /// 目前群組：手動選擇優先，其次 GPS 判定。
    ///
    /// 「GPS 還沒回答」和「GPS 回答了，你不在任何群組裡」是兩件事。
    /// 後者是有意義的答案——它正是「該建立新群組了」的訊號——所以不能拿
    /// 「最近建立的群組」把它蓋掉。蓋掉的話會同時壞掉兩件事：走到新地點時
    /// 畫面會賴在舊群組不動，而且因為 `currentGroup` 永遠不是 nil，
    /// 「建立新群組」按鈕在你有了第一個群組之後就再也不會出現。
    private var currentGroup: MushroomGroup? {
        CurrentGroupResolver.resolve(
            manualSelection: selectedGroupID, gps: gps, groups: groups
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ActiveTimersSection()
                    .frame(maxHeight: .infinity)

                Divider()

                QuickLogSection(
                    group: currentGroup,
                    canSwitchGroup: !groups.isEmpty,
                    locationDenied: location.authorizationDenied,
                    onChangeGroup: { isPickingGroup = true },
                    onCreateGroup: { Task { await prepareNewGroup() } }
                )
                // 下半部是主要操作區（單手、邊走邊用），給它足夠高度一次看到約 20 顆菇。
                .frame(height: 340)
            }
            .navigationTitle("打菇茜")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
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
                // 人站在既有群組範圍內、但想在附近再開一個新群組時，
                // 下面那顆「建立新群組」不會出現，所以這裡也要留一個入口。
                Button("建立新群組") { Task { await prepareNewGroup() } }
                Button("取消", role: .cancel) {}
            }
        }
        .task {
            await NotificationService.shared.requestAuthorization()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // 本機通知不會喚醒 App，所以回到前景時補標記已到期的計時。
            do {
                try TimerQueries.markFired(in: context)
            } catch {
                // 這是全 App 唯一的到期回收點，壞掉的話會讓所有過期計時卡在畫面上。
                logger.error("markFired 失敗：\(error.localizedDescription, privacy: .public)")
            }
            Task {
                await refreshCurrentGroup()
                await LiveActivityController.refresh(context: context)
            }
        }
        .task {
            location.requestAuthorization()
            await refreshCurrentGroup()
            // 冷啟動時明確對一次帳：上次執行留下的卡片可能還掛在鎖定畫面上，
            // 而 scenePhase 的第一次轉換不保證會觸發。
            await LiveActivityController.refresh(context: context)
        }
        .onChange(of: location.authorizationStatus) { _, status in
            // 第一次啟動時，上面那個 .task 會在使用者還沒回答權限對話框時就跑完，
            // 所以按下「允許」之後要在這裡補判定一次。少了這段，首次安裝的
            // GPS 判定要等到 App 切到背景再回來才會生效。
            guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
            Task { await refreshCurrentGroup() }
        }
        .onChange(of: currentGroup?.id, initial: true) { _, id in
            // 目前群組換了就要同步出去，不管是 GPS 判定、手動切換還是剛建立的。
            // 少了任何一條路徑，小工具就會停在舊群組，按鈕會登記到錯的菇。
            // 順序不能反：WidgetChannel 會讀這個 key 來決定要放哪個群組的菇。
            UserDefaults.standard.set(
                id?.uuidString, forKey: LocationService.lastKnownGroupIDKey
            )
            WidgetChannel.refresh(context: context)
        }
        .alert("建立新群組", isPresented: $isCreatingGroup) {
            TextField("群組名稱", text: $draftGroupName)
            Button("取消", role: .cancel) {}
            Button("建立") { createGroup() }
        } message: {
            Text("名稱已依目前位置預填，可以直接使用或改寫。")
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

    /// 取一次位置，判定目前在哪個群組。
    private func refreshCurrentGroup() async {
        guard let coordinate = await location.updateCurrentLocation() else { return }
        let match = GroupLocator.nearest(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            groups: groups
        )
        // 走出所有已知群組的範圍時，把手動選擇一起放掉。
        // 不放掉的話，先前為了修正 GPS 誤差而手動選的群組會一路跟著你到別的地點。
        if let match {
            gps = .matched(match.id)
        } else {
            gps = .outsideAllGroups
            selectedGroupID = nil
        }
        // 記錄與小工具的更新統一由下面的 onChange(of: currentGroup?.id) 處理，
        // 這裡只負責更新 GPS 判定的結果。
    }

    private func prepareNewGroup() async {
        guard let coordinate = await location.updateCurrentLocation() else {
            // 群組就是「一個地點」，沒有座標的群組之後永遠不會被 GPS 判定到。
            // 所以這裡不開命名對話框——開了也只會讓使用者打完名字按建立卻毫無反應。
            errorMessage = "拿不到目前位置，無法建立群組。請確認已允許本 App 在使用期間取得位置。"
            return
        }
        draftCoordinate = (coordinate.latitude, coordinate.longitude)
        draftGroupName = await location.suggestedName(for: coordinate)
        isCreatingGroup = true
    }

    private func createGroup() {
        let trimmed = draftGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let draftCoordinate else { return }
        let group = MushroomGroup(
            name: trimmed,
            latitude: draftCoordinate.latitude,
            longitude: draftCoordinate.longitude
        )
        context.insert(group)
        do {
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        selectedGroupID = group.id
    }
}
