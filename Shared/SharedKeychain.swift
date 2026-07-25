import Foundation
import Security

/// 主 App 與 Widget extension 之間唯一的資料通道。
///
/// 免費帳號不能用 App Groups，但可以用 Keychain Sharing。
/// 主 App 寫、Widget extension 讀，兩邊的 entitlement 都宣告同一個 access group。
enum SharedKeychain {
    private static let groupSuffix = "com.chaoyu.MushroomTimer.shared"
    private static let service = "MushroomTimer"
    private static let account = "widget-payload"

    /// 完整的 access group（`<TeamID>.com.chaoyu.MushroomTimer.shared`）。
    /// Team ID 不寫死在程式碼裡，改成執行期探測，避免把個人 Team ID 提交進 git。
    ///
    /// 只快取成功的結果。若用 `static let` 連失敗也一起快取，那麼只要 process
    /// 第一次求值時剛好失敗，這個 process 的餘生就再也讀不到 payload 了。
    private static var cachedAccessGroup: String?

    static var accessGroup: String? {
        if let cachedAccessGroup { return cachedAccessGroup }
        guard let prefix = teamIdentifierPrefix() else { return nil }
        let group = "\(prefix).\(groupSuffix)"
        cachedAccessGroup = group
        return group
    }

    @discardableResult
    static func save(_ payload: WidgetPayload) -> Bool {
        guard let accessGroup, let data = try? JSONEncoder().encode(payload) else {
            return false
        }
        var query = baseQuery(accessGroup: accessGroup)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load() -> WidgetPayload? {
        guard let accessGroup else { return nil }
        var query = baseQuery(accessGroup: accessGroup)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(WidgetPayload.self, from: data)
    }

    private static func baseQuery(accessGroup: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: accessGroup
        ]
    }

    /// 用一個探測項目問系統「我的 Team ID prefix 是什麼」。
    /// 不指定 access group 時系統會塞進 entitlement 裡的第一個群組，
    /// 讀回該群組字串的第一段即為 prefix。
    private static func teamIdentifierPrefix() -> String? {
        // 探測項目的保護等級必須跟 payload 一致。少了 kSecAttrAccessible 會落到
        // 預設的 kSecAttrAccessibleWhenUnlocked，鎖屏時查不到也加不進去——
        // 而小工具的 timeline 更新剛好常在鎖屏狀態發生。
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "team-id-probe",
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecReturnAttributes as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        var status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            status = SecItemAdd(query as CFDictionary, &result)
        }
        guard status == errSecSuccess,
              let attributes = result as? [String: Any],
              let group = attributes[kSecAttrAccessGroup as String] as? String,
              let prefix = group.components(separatedBy: ".").first,
              !prefix.isEmpty else { return nil }
        return prefix
    }
}
