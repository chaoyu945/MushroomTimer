import Foundation
import SwiftData

/// 資料庫查詢的集中處。主畫面、小工具 payload、Live Activity 都由這裡取資料，
/// 避免同樣的排序規則在多處各寫一次。
@MainActor
enum TimerQueries {
    /// 進行中的計時，依 `fireAt` 由近到遠。
    static func active(in context: ModelContext) throws -> [TimerEntry] {
        let activeRaw = TimerStatus.active.rawValue
        var descriptor = FetchDescriptor<TimerEntry>(
            predicate: #Predicate { $0.statusRaw == activeRaw },
            sortBy: [SortDescriptor(\.fireAt, order: .forward)]
        )
        descriptor.includePendingChanges = true
        return try context.fetch(descriptor)
    }

    /// 把已過期的 active 計時標記成 fired。
    ///
    /// 本機通知響起時不會喚醒 App，所以狀態是惰性更新的：
    /// 在 App 進入前景、或處理通知動作時呼叫一次即可。
    static func markFired(in context: ModelContext, now: Date = .now) throws {
        for entry in try active(in: context) where entry.fireAt <= now {
            entry.status = .fired
        }
        try context.save()
    }

    /// 群組內最常用的幾顆菇，依 `useCount` 由高到低。
    static func mostUsed(in group: MushroomGroup, limit: Int) -> [Mushroom] {
        Array(
            group.mushrooms
                .sorted { ($0.useCount, $0.name) > ($1.useCount, $1.name) }
                .prefix(limit)
        )
    }
}
