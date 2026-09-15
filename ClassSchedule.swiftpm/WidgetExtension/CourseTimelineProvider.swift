import WidgetKit
import SwiftUI

/// 桌面小工具時間軸單點狀態實體模型
public struct CourseTimelineEntry: TimelineEntry {
    public let date: Date
    public let targetCourse: Course?
    public let currentCourse: Course?
    public let nextCourse: (course: Course, minutesUntil: Int)?
    public let todayCourses: [Course]
    public let progress: DayProgressInfo
    public let settings: WidgetSettings

    public init(
        date: Date,
        targetCourse: Course?,
        currentCourse: Course?,
        nextCourse: (course: Course, minutesUntil: Int)?,
        todayCourses: [Course],
        progress: DayProgressInfo,
        settings: WidgetSettings
    ) {
        self.date = date
        self.targetCourse = targetCourse
        self.currentCourse = currentCourse
        self.nextCourse = nextCourse
        self.todayCourses = todayCourses
        self.progress = progress
        self.settings = settings
    }
}

/// 課表桌面小工具時間軸調度中心
public struct CourseTimelineProvider: TimelineProvider {
    public typealias Entry = CourseTimelineEntry

    public init() {}

    public func placeholder(in context: Context) -> CourseTimelineEntry {
        let sampleCourses = WidgetSampleData.fallbackCourses
        let now = Date()
        return makeEntry(at: now, courses: sampleCourses, settings: WidgetSettings())
    }

    public func getSnapshot(in context: Context, completion: @escaping (CourseTimelineEntry) -> Void) {
        // 小工具庫的預覽快照必須「快速且不依賴共享容器」。
        // Apple 官方文件明確要求在 isPreview 時改用範例資料：若預覽階段去讀 App Group
        // 而發生任何失敗，WidgetKit 可能因此拿不到 descriptor，小工具就不會出現在小工具庫。
        if context.isPreview {
            let entry = makeEntry(at: Date(), courses: WidgetSampleData.fallbackCourses, settings: WidgetSettings())
            completion(entry)
            return
        }

        let data = WidgetDataStorage.loadData()
        let entry = makeEntry(at: Date(), courses: data.courses, settings: data.settings)
        completion(entry)
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<CourseTimelineEntry>) -> Void) {
        let data = WidgetDataStorage.loadData()
        let now = Date()
        var entries: [CourseTimelineEntry] = []

        let todayList = ScheduleCalculator.todayCourses(in: data.courses, at: now)

        if todayList.isEmpty {
            // 今日無課：產生單一狀態，1 小時後重新調度
            let entry = makeEntry(at: now, courses: data.courses, settings: data.settings)
            entries.append(entry)

            let reloadDate = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
            let timeline = Timeline(entries: entries, policy: .after(reloadDate))
            completion(timeline)
            return
        }

        // 今日有課：
        // 依照使用者需求「精確到分、以分做更新，每過一分鐘進度條就會更新它的百分比」
        // 預排未來 30 分鐘每一分鐘的 Entry，讓 iOS 系統每分鐘精確切換進度百分比
        for minuteOffset in 0..<30 {
            if let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: now) {
                let entry = makeEntry(at: entryDate, courses: data.courses, settings: data.settings)
                entries.append(entry)
            }
        }

        let reloadDate = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800)
        let timeline = Timeline(entries: entries, policy: .after(reloadDate))
        completion(timeline)
    }

    private func makeEntry(at date: Date, courses: [Course], settings: WidgetSettings) -> CourseTimelineEntry {
        let current = ScheduleCalculator.currentCourse(in: courses, at: date)
        let next = ScheduleCalculator.nextCourse(in: courses, at: date)
        let todayList = ScheduleCalculator.todayCourses(in: courses, at: date)
        let progress = ScheduleCalculator.todayProgress(in: courses, at: date)

        let target = current ?? next?.course ?? todayList.first ?? courses.first

        return CourseTimelineEntry(
            date: date,
            targetCourse: target,
            currentCourse: current,
            nextCourse: next,
            todayCourses: todayList,
            progress: progress,
            settings: settings
        )
    }
}
