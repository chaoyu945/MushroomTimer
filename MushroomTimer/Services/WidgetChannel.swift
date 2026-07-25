import Foundation
import SwiftData
import WidgetKit

/// 主 App 推送資料給小工具的唯一管道。
///
/// Widget extension 沒有資料庫連線，也不能有——它只讀主 App 放進共享 keychain
/// 的這份精簡 payload。所以每次資料異動後都要呼叫 `refresh`。
@MainActor
enum WidgetChannel {
    static func makePayload(
        context: ModelContext,
        defaults: UserDefaults = .standard
    ) throws -> WidgetPayload {
        guard let group = try currentGroup(context: context, defaults: defaults) else {
            return .empty
        }
        let mushrooms = TimerQueries.mostUsed(in: group, limit: WidgetPayload.maxMushrooms)
        return WidgetPayload.make(
            groupName: group.name,
            mushrooms: mushrooms.map { ($0.id, $0.name) }
        )
    }

    static func refresh(context: ModelContext, defaults: UserDefaults = .standard) {
        guard let payload = try? makePayload(context: context, defaults: defaults) else {
            return
        }
        SharedKeychain.save(payload)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func currentGroup(
        context: ModelContext,
        defaults: UserDefaults
    ) throws -> MushroomGroup? {
        if let raw = defaults.string(forKey: LocationService.lastKnownGroupIDKey),
           let id = UUID(uuidString: raw) {
            var descriptor = FetchDescriptor<MushroomGroup>(
                predicate: #Predicate { $0.id == id }
            )
            descriptor.fetchLimit = 1
            if let group = try context.fetch(descriptor).first {
                return group
            }
        }
        var descriptor = FetchDescriptor<MushroomGroup>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
