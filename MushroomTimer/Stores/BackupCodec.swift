import Foundation
import SwiftData

/// 備份檔的格式。與 SwiftData 的 `@Model` 分開定義，
/// 這樣資料庫欄位改動時不會直接破壞既有備份檔。
struct BackupDocument: Codable {
    struct Mushroom: Codable {
        var id: UUID
        var name: String
        var useCount: Int
        var lastUsedAt: Date?
    }

    struct Group: Codable {
        var id: UUID
        var name: String
        var latitude: Double
        var longitude: Double
        var radius: Double
        var createdAt: Date
        var mushrooms: [Mushroom]
    }

    var version: Int
    var groups: [Group]
}

@MainActor
enum BackupCodec {
    static let currentVersion = 1

    enum ImportError: LocalizedError {
        /// 檔案來自比這個版本更新的 App。硬讀下去只會靜默丟掉看不懂的欄位。
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version):
                return "這個備份檔的格式版本是 \(version)，這個版本的打菇茜看不懂。請更新 App 後再匯入。"
            }
        }
    }

    static func export(context: ModelContext) throws -> Data {
        let groups = try context.fetch(
            FetchDescriptor<MushroomGroup>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
        )
        let document = BackupDocument(
            version: currentVersion,
            groups: groups.map { group in
                BackupDocument.Group(
                    id: group.id,
                    name: group.name,
                    latitude: group.latitude,
                    longitude: group.longitude,
                    radius: group.radius,
                    createdAt: group.createdAt,
                    mushrooms: group.mushrooms.map {
                        BackupDocument.Mushroom(
                            id: $0.id,
                            name: $0.name,
                            useCount: $0.useCount,
                            lastUsedAt: $0.lastUsedAt
                        )
                    }
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    /// - Returns: 實際新增的群組數。已存在（同 id）的群組會被跳過，不覆寫。
    @discardableResult
    static func importing(_ data: Data, into context: ModelContext) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(BackupDocument.self, from: data)
        // 解碼與檢查都做完才動資料庫。這裡不能靠 rollback 收拾——本專案先前實測過，
        // `ModelContext.rollback()` 不會丟掉尚未存檔的 insert。
        guard document.version <= currentVersion else {
            throw ImportError.unsupportedVersion(document.version)
        }

        let existingIDs = Set(
            try context.fetch(FetchDescriptor<MushroomGroup>()).map(\.id)
        )
        var added = 0
        for group in document.groups where !existingIDs.contains(group.id) {
            let model = MushroomGroup(
                id: group.id,
                name: group.name,
                latitude: group.latitude,
                longitude: group.longitude,
                radius: group.radius,
                createdAt: group.createdAt
            )
            context.insert(model)
            for mushroom in group.mushrooms {
                let mushroomModel = Mushroom(
                    id: mushroom.id,
                    name: mushroom.name,
                    useCount: mushroom.useCount,
                    lastUsedAt: mushroom.lastUsedAt,
                    group: model
                )
                context.insert(mushroomModel)
            }
            added += 1
        }
        try context.save()
        return added
    }
}
