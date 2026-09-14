import Foundation

/// 桌面小工具資料讀取中心（支援 App Group 共享記憶體與群組容器目錄）
public struct WidgetDataStorage {
    public static let appGroupSuite = "group.com.fengfeng.classschedule"
    public static let coursesFilename = "courses.json"
    public static let settingsFilename = "settings.json"

    public static func loadData() -> (courses: [Course], settings: WidgetSettings) {
        var loadedCourses: [Course]? = nil
        var loadedSettings: WidgetSettings? = nil

        // 1. 優先從 App Group UserDefaults 共享空間讀取
        if let sharedDefaults = UserDefaults(suiteName: appGroupSuite) {
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
        if loadedCourses == nil || loadedSettings == nil {
            if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupSuite) {
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
        }

        let finalCourses = loadedCourses ?? WidgetSampleData.fallbackCourses
        let finalSettings = loadedSettings ?? WidgetSettings()
        return (finalCourses, finalSettings)
    }
}
