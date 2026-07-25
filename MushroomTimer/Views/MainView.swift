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
    @State private var gpsGroupID: UUID?
    @State private var isCreatingGroup = false
    @State private var draftGroupName = ""
    @State private var draftCoordinate: (latitude: Double, longitude: Double)?
    @State private var errorMessage: String?

    /// 目前群組。優先採用手動選擇、其次 GPS 判定，最後才是最近建立的群組。
    private var currentGroup: MushroomGroup? {
        if let selectedGroupID,
           let match = groups.first(where: { $0.id == selectedGroupID }) {
            return match
        }
        if let gpsGroupID,
           let match = groups.first(where: { $0.id == gpsGroupID }) {
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
                    canSwitchGroup: !groups.isEmpty,
                    locationDenied: location.authorizationDenied,
                    onChangeGroup: { isPickingGroup = true },
                    onCreateGroup: { Task { await prepareNewGroup() } }
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
            guard phase == .active else { return }
            // 本機通知不會喚醒 App，所以回到前景時補標記已到期的計時。
            do {
                try TimerQueries.markFired(in: context)
            } catch {
                // 這是全 App 唯一的到期回收點，壞掉的話會讓所有過期計時卡在畫面上。
                logger.error("markFired 失敗：\(error.localizedDescription, privacy: .public)")
            }
            Task { await refreshCurrentGroup() }
        }
        .task {
            location.requestAuthorization()
            await refreshCurrentGroup()
        }
        .onChange(of: location.authorizationStatus) { _, status in
            // 第一次啟動時，上面那個 .task 會在使用者還沒回答權限對話框時就跑完，
            // 所以按下「允許」之後要在這裡補判定一次。少了這段，首次安裝的
            // GPS 判定要等到 App 切到背景再回來才會生效。
            guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
            Task { await refreshCurrentGroup() }
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
        gpsGroupID = match?.id
        // QuickLogHereIntent 不觸發 GPS，改讀這裡記下的結果。
        UserDefaults.standard.set(
            match?.id.uuidString, forKey: LocationService.lastKnownGroupIDKey
        )
        WidgetChannel.refresh(context: context)
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
