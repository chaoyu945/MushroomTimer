import AppIntents
import Foundation
import SwiftData

/// 捷徑 App 中可挑選的一顆菇。
struct MushroomEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "菇")
    static var defaultQuery = MushroomEntityQuery()

    var id: UUID
    var name: String
    var groupName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(groupName)")
    }

    @MainActor
    init(_ mushroom: Mushroom) {
        self.id = mushroom.id
        self.name = mushroom.name
        self.groupName = mushroom.group?.name ?? ""
    }
}

struct MushroomEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [MushroomEntity.ID]) async throws -> [MushroomEntity] {
        let context = ModelContainer.shared.mainContext
        return try identifiers.compactMap { id in
            try IntentSupport.mushroom(id: id, context: context).map(MushroomEntity.init)
        }
    }

    /// 捷徑 App 的下拉選單內容，依使用次數排序。
    @MainActor
    func suggestedEntities() async throws -> [MushroomEntity] {
        try IntentSupport.allMushrooms(context: ModelContainer.shared.mainContext)
            .map(MushroomEntity.init)
    }
}
