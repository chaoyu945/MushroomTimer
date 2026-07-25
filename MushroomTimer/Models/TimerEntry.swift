import Foundation
import SwiftData

enum TimerStatus: String, Codable, CaseIterable {
    /// 尚未到期。
    case active
    /// 已到期（開啟 App 或處理通知時才會被標記，因為本機通知不會喚醒 App）。
    case fired
    /// 使用者按了「已完成」。
    case completed
    /// 使用者左滑取消。
    case cancelled
}

/// 一筆進行中的提醒。
@Model
final class TimerEntry {
    @Attribute(.unique) var id: UUID
    var mushroom: Mushroom?
    var createdAt: Date
    /// 使用者輸入的剩餘秒數。
    var remainingSeconds: Int
    /// 本筆使用的提前量快照。使用者之後改全域預設值不影響已建立的計時。
    var leadSeconds: Int
    var fireAt: Date
    /// 以字串儲存，讓 `#Predicate` 能正常比對。請透過 `status` 讀寫。
    var statusRaw: String

    var status: TimerStatus {
        get { TimerStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        mushroom: Mushroom?,
        createdAt: Date,
        remainingSeconds: Int,
        leadSeconds: Int,
        fireAt: Date,
        status: TimerStatus = .active
    ) {
        self.id = id
        self.mushroom = mushroom
        self.createdAt = createdAt
        self.remainingSeconds = remainingSeconds
        self.leadSeconds = leadSeconds
        self.fireAt = fireAt
        self.statusRaw = status.rawValue
    }
}

extension ModelContainer {
    /// 全 App 唯一的 schema 定義。測試用 `inMemory: true` 取得不落地的容器。
    static func mushroomTimer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([MushroomGroup.self, Mushroom.self, TimerEntry.self])
        let configuration = ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
