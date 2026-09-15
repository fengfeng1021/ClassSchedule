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
/// 擴展各自一份）Info.plist 的 `ALTAppGroups` 鍵，該清單就是簽章實際授權的群組。
///
/// 重要：**只探測簽章授權過的群組**。
/// 對未授權的群組呼叫 `containerURL(forSecurityApplicationGroupIdentifier:)` 會被
/// containermanagerd 拒絕；在小工具擴展程序中，這個拒絕可能直接導致該程序被終止，
/// 讓 WidgetKit 取不到小工具的 descriptor，小工具就永遠不會出現在小工具庫。
/// 因此若 Info.plist 已提供授權清單，就完全不再退回去探測其他識別碼。
public enum SharedAppGroup {

    /// 專案預設（未經側載工具改寫）的 App Group 識別碼。
    public static let defaultGroupID = "group.com.fengfeng.classschedule"

    /// 側載工具注入鍵。
    private static let sideloadInjectedKey = "ALTAppGroups"

    /// 專案自訂宣告鍵。
    private static let declaredKey = "ClassScheduleAppGroups"

    /// Info.plist 提供、且來自簽章授權的 App Group 清單（可能為空）。
    public static var declaredGroupIDs: [String] {
        var identifiers: [String] = []

        if let injected = Bundle.main.object(forInfoDictionaryKey: sideloadInjectedKey) as? [String] {
            identifiers.append(contentsOf: injected)
        }
        if let declared = Bundle.main.object(forInfoDictionaryKey: declaredKey) as? [String] {
            identifiers.append(contentsOf: declared)
        }

        var seen = Set<String>()
        return identifiers.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// 可安全探測的候選清單。
    ///
    /// 只有在完全沒有簽章授權資訊時（App Store 或 Swift Playgrounds 建置），
    /// 才會退回硬式預設值。
    public static var candidates: [String] {
        let declared = declaredGroupIDs
        return declared.isEmpty ? [defaultGroupID] : declared
    }

    /// 第一個「目前簽章真的授權」的 App Group 識別碼；完全不可用時為 nil。
    ///
    /// 注意：不能用 `UserDefaults(suiteName:)` 是否為 nil 來判斷，因為即使沒有
    /// entitlement，`UserDefaults(suiteName:)` 仍會回傳一個物件（只是讀寫失敗）。
    /// `containerURL(forSecurityApplicationGroupIdentifier:)` 才是可靠的授權探測。
    public static var resolvedGroupID: String? {
        for identifier in candidates {
            if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil {
                return identifier
            }
        }
        return nil
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
