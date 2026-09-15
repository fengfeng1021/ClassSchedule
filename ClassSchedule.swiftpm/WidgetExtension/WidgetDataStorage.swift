import Foundation

/// 桌面小工具資料讀取中心（支援 App Group 共享記憶體與群組容器目錄）。
///
/// 側載工具（SideStore / AltStore）在簽名時會把 App Group 識別碼改寫為
/// `group.com.fengfeng.classschedule.<TeamID>`，並將真正可用的識別碼寫進
/// 本擴展 Info.plist 的 `ALTAppGroups` 鍵。因此這裡一律透過 `SharedAppGroup`
/// 於執行期解析，而不是寫死原始字串——寫死會導致小工具永遠只拿到範例資料。
public struct WidgetDataStorage {
    public static let coursesFilename = "courses.json"
    public static let settingsFilename = "settings.json"

    /// 目前小工具是否真的取得 App Group 共享授權（供除錯與顯示層判斷）。
    public static var isSharedGroupAvailable: Bool {
        SharedAppGroup.isAvailable
    }

    public static func loadData() -> (courses: [Course], settings: WidgetSettings) {
        var loadedCourses: [Course]? = nil
        var loadedSettings: WidgetSettings? = nil

        // 1. 優先從 App Group UserDefaults 共享空間讀取
        if let sharedDefaults = SharedAppGroup.sharedDefaults {
            if let data = sharedDefaults.data(forKey: "saved_courses"),
               let decoded = try? JSONDecoder().decode([Course].self, from: data),
               !decoded.isEmpty {
                loadedCourses = decoded
            }
            if let data = sharedDefaults.data(forKey: "saved_settings"),
               let decoded = try? JSONDecoder().decode(ScheduleSettings.self, from: data) {
                loadedSettings = decoded.widgetSettings
            }
        }

        // 2. 次要從 App Group Container 實體共享目錄讀取
        if loadedCourses == nil || loadedSettings == nil,
           let groupURL = SharedAppGroup.containerURL {
            let coursesURL = groupURL.appendingPathComponent(coursesFilename)
            if loadedCourses == nil,
               let data = try? Data(contentsOf: coursesURL),
               let decoded = try? JSONDecoder().decode([Course].self, from: data),
               !decoded.isEmpty {
                loadedCourses = decoded
            }

            let settingsURL = groupURL.appendingPathComponent(settingsFilename)
            if loadedSettings == nil,
               let data = try? Data(contentsOf: settingsURL),
               let decoded = try? JSONDecoder().decode(ScheduleSettings.self, from: data) {
                loadedSettings = decoded.widgetSettings
            }
        }

        let finalCourses = loadedCourses ?? WidgetSampleData.fallbackCourses
        let finalSettings = loadedSettings ?? WidgetSettings()
        return (finalCourses, finalSettings)
    }
}
