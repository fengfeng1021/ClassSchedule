import Foundation

/// App Group 共享容器解析中心。
///
/// 為什麼不能寫死 `group.com.fengfeng.classschedule`：
/// 側載工具（SideStore / AltStore）在簽名前會向 Apple 開發者後台註冊 App Group，
/// 並在**原始識別碼尾端加上 Team ID**，例如：
///
///     group.com.fengfeng.classschedule  ->  group.com.fengfeng.classschedule.XXXXXXXXXX
///
/// 同時它會把「簽名後真正可用的 App Group 清單」寫進每個 Bundle（主 App 與小工具
/// 擴展各自一份）Info.plist 的 `ALTAppGroups` 鍵。因此執行期必須先讀這個鍵，
/// 再去解析容器；否則會拿到 nil，主 App 寫不進共享區、小工具也讀不到資料。
///
/// 解析順序：
/// 1. `ALTAppGroups`：SideStore / AltStore 側載簽名後注入的真實識別碼。
/// 2. `ClassScheduleAppGroups`：一般簽名流程（或未來 CI）可自訂的宣告鍵。
/// 3. `group.com.fengfeng.classschedule`：未經改寫的預設值（App Store / Playgrounds）。
public enum SharedAppGroup {

    /// 專案預設（未經側載工具改寫）的 App Group 識別碼。
    public static let defaultGroupID = "group.com.fengfeng.classschedule"

    /// 側載工具注入鍵。
    private static let sideloadInjectedKey = "ALTAppGroups"

    /// 專案自訂宣告鍵。
    private static let declaredKey = "ClassScheduleAppGroups"

    /// Info.plist 中可用的 App Group 候選清單（已去重、保持優先順序）。
    public static var candidates: [String] {
        var identifiers: [String] = []

        if let injected = Bundle.main.object(forInfoDictionaryKey: sideloadInjectedKey) as? [String] {
            identifiers.append(contentsOf: injected)
        }
        if let declared = Bundle.main.object(forInfoDictionaryKey: declaredKey) as? [String] {
            identifiers.append(contentsOf: declared)
        }
        identifiers.append(defaultGroupID)

        var seen = Set<String>()
        return identifiers.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// 第一個「目前簽章真的授權」的 App Group 識別碼；完全不可用時為 nil。
    ///
    /// 注意：不能用 `UserDefaults(suiteName:)` 是否為 nil 來判斷，因為即使沒有
    /// entitlement，`UserDefaults(suiteName:)` 仍會回傳一個物件（只是讀寫失敗）。
    /// `containerURL(forSecurityApplicationGroupIdentifier:)` 才是可靠的授權探測。
    public static var resolvedGroupID: String? {
        candidates.first { identifier in
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
        }
    }

    /// 共享容器目錄（供放置 courses.json / settings.json）。
    public static var containerURL: URL? {
        guard let identifier = resolvedGroupID else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// 共享 UserDefaults（供放置 saved_courses / saved_settings）。
    public static var sharedDefaults: UserDefaults? {
        guard let identifier = resolvedGroupID else { return nil }
        return UserDefaults(suiteName: identifier)
    }

    /// 目前是否真的取得共享容器授權（供站內排查中心顯示診斷資訊）。
    public static var isAvailable: Bool {
        resolvedGroupID != nil
    }
}
