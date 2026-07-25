import Foundation
import SwiftData

extension ModelContainer {
    /// 主 App 與 App Intents 共用同一個容器。
    ///
    /// Intents 遵循 `LiveActivityIntent`，會在主 App 的 process 執行，
    /// 因此可以直接使用這個容器；Widget extension 則完全不碰它。
    @MainActor
    static let shared: ModelContainer = {
        do {
            return try ModelContainer.mushroomTimer()
        } catch {
            fatalError("無法建立資料庫：\(error)")
        }
    }()
}

/// Intents 共用的查詢邏輯。抽出來才能不經過 AppIntents 框架就測到。
@MainActor
enum IntentSupport {
    static func mushroom(id: UUID, context: ModelContext) throws -> Mushroom? {
        var descriptor = FetchDescriptor<Mushroom>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// 全部的菇，依使用次數由高到低——捷徑 App 的選單也照這個順序。
    static func allMushrooms(context: ModelContext) throws -> [Mushroom] {
        try context.fetch(
            FetchDescriptor<Mushroom>(
                sortBy: [
                    SortDescriptor(\.useCount, order: .reverse),
                    // 次數相同時要有確定的先後，否則捷徑選單的排序每次都會跳。
                    SortDescriptor(\.name, order: .forward)
                ]
            )
        )
    }

    /// `QuickLogHereIntent` 用：目前群組中最常用的那顆菇。
    ///
    /// 這裡刻意不觸發 GPS——Intent 可能在 App 沒開的情況下執行，
    /// 定位會很慢也可能沒有權限。改讀主 App 上次判定並記在 UserDefaults 的群組。
    static func preferredMushroom(
        context: ModelContext,
        defaults: UserDefaults = .standard
    ) throws -> Mushroom? {
        if let raw = defaults.string(forKey: LocationService.lastKnownGroupIDKey),
           let groupID = UUID(uuidString: raw) {
            var descriptor = FetchDescriptor<MushroomGroup>(
                predicate: #Predicate { $0.id == groupID }
            )
            descriptor.fetchLimit = 1
            if let group = try context.fetch(descriptor).first,
               let best = TimerQueries.mostUsed(in: group, limit: 1).first {
                return best
            }
        }
        return try allMushrooms(context: context).first
    }
}
