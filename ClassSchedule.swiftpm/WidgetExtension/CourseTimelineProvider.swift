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

    /// 使用者設定的課前提醒分鐘數（來自 ScheduleSettings；未設定時為 nil）
    public let classReminderMinutes: Int?

    /// 今日之後最近的一堂課（今日已結束或今日無課時顯示用）。
    public let nextCourseAfterToday: Course?
    /// `nextCourseAfterToday` 實際發生的日期，用於產生「明天」「週三」標示。
    public let nextCourseDate: Date?

    public init(
        date: Date,
        targetCourse: Course?,
        currentCourse: Course?,
        nextCourse: (course: Course, minutesUntil: Int)?,
        todayCourses: [Course],
        progress: DayProgressInfo,
        settings: WidgetSettings,
        classReminderMinutes: Int? = nil,
        nextCourseAfterToday: Course? = nil,
        nextCourseDate: Date? = nil
    ) {
        self.date = date
        self.targetCourse = targetCourse
        self.currentCourse = currentCourse
        self.nextCourse = nextCourse
        self.todayCourses = todayCourses
        self.progress = progress
        self.settings = settings
        self.classReminderMinutes = classReminderMinutes
        self.nextCourseAfterToday = nextCourseAfterToday
        self.nextCourseDate = nextCourseDate
    }

    /// 今日課程是否已全部結束（今天有課，但已經沒有正在上或接下來要上的課）。
    ///
    /// 這是「時間有沒有同步」的關鍵狀態：晚上 9 點時必須為 true，
    /// 顯示層才會呈現「今日課程已結束」，而不是早上第一堂課。
    public var isTodayFinished: Bool {
        !todayCourses.isEmpty && currentCourse == nil && nextCourse == nil
    }

    /// 今日「還沒結束」的課程，供今日日程清單使用。
    ///
    /// 下午三點時清單應該顯示下午還沒上的課，而不是早上已經上完的課。
    /// 全部結束時退回完整清單，避免清單變空。
    public var remainingTodayCourses: [Course] {
        let now = TimeOfDay(date: date)
        let remaining = todayCourses.filter { $0.endTime >= now }
        return remaining.isEmpty ? todayCourses : remaining
    }

    /// 「明天」「週三」等下一堂課的時間標示。
    public var nextCourseDayLabel: String? {
        guard let nextCourseDate else { return nil }
        let calendar = Calendar.current
        if calendar.isDateInTomorrow(nextCourseDate) {
            return "明天"
        }
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        let weekday = calendar.component(.weekday, from: nextCourseDate)
        guard names.indices.contains(weekday - 1) else { return nil }
        return "週" + names[weekday - 1]
    }

    /// 下一堂課的**實際開始時間**：把「哪一天」與「第幾節的時刻」組成完整時間點。
    public var nextCourseStartDate: Date? {
        guard let nextCourseDate, let course = nextCourseAfterToday else { return nil }
        return course.startTime.toDate(baseDate: nextCourseDate)
    }

    /// 距下一堂課的倒數；沒有下一堂課時為 nil。
    public var countdownToNextCourse: CourseCountdown? {
        guard let start = nextCourseStartDate else { return nil }
        return CourseCountdown(secondsRemaining: Int(start.timeIntervalSince(date)))
    }

    // MARK: - 課前提醒窗口

    /// 下一堂課（今天還沒開始的那一堂）的實際開始時間。
    public var upcomingCourseStartDate: Date? {
        guard let nextCourse else { return nil }
        return nextCourse.course.startTime.toDate(baseDate: date)
    }

    /// 使用者設定的課前提醒分鐘數（只保留有效值）。
    public var reminderMinutes: Int? {
        guard let minutes = classReminderMinutes, minutes > 0 else { return nil }
        return minutes
    }

    /// 是否已進入「課前提醒窗口」——可以開始倒數下一堂課。
    public var isInClassReminderWindow: Bool {
        guard let start = upcomingCourseStartDate, let minutes = reminderMinutes else { return false }
        return date >= start.addingTimeInterval(TimeInterval(-minutes * 60)) && date < start
    }

    /// 提醒窗口的起點。
    ///
    /// 這個值同時當作倒數計時區間的下界：區間必須永遠「下界 < 上界」，
    /// 否則 `ClosedRange` 會直接觸發執行期崩潰。
    /// 用「上課時間 − 提醒分鐘數」當下界可保證成立（連時間軸往後多排的 entry 也安全）。
    public var classReminderWindowStart: Date? {
        guard let start = upcomingCourseStartDate, let minutes = reminderMinutes else { return nil }
        return start.addingTimeInterval(TimeInterval(-minutes * 60))
    }
}

/// 距下一堂課的倒數。
///
/// 小工具做不到「每秒跳動」—— 時間軸最快的精度就是每分鐘一格。
/// 因此這裡把剩餘時間整理成適合當大字的字串，並由時間軸在「今日已結束」期間
/// 每分鐘產生一個 entry，讓倒數在畫面上真的會走動。
public struct CourseCountdown {
    public let secondsRemaining: Int

    public init(secondsRemaining: Int) {
        self.secondsRemaining = secondsRemaining
    }

    /// 剩餘不到一小時（改用強調色顯示）。
    public var isImminent: Bool {
        secondsRemaining < 3600
    }

    /// 剩餘不到一分鐘。
    public var isStartingSoon: Bool {
        secondsRemaining < 60
    }

    /// 大字顯示用。例如「11 小時 20 分」「48 分鐘」「2 天 5 小時」「即將開始」。
    public var valueText: String {
        let total = max(secondsRemaining, 0)
        if total < 60 {
            return "即將開始"
        }

        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60

        if days > 0 {
            return hours > 0 ? "\(days) 天 \(hours) 小時" : "\(days) 天"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours) 小時 \(minutes) 分" : "\(hours) 小時"
        }
        return "\(minutes) 分鐘"
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
        let entry = makeEntry(at: Date(), courses: data.courses, settings: data.settings, reminderMinutes: data.reminderMinutes)
        completion(entry)
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<CourseTimelineEntry>) -> Void) {
        let data = WidgetDataStorage.loadData()
        let now = Date()
        let todayList = ScheduleCalculator.todayCourses(in: data.courses, at: now)

        // 今日無課，或今日課程已全部結束：
        // 若還有下一堂課，就改為顯示「倒數下一堂」。
        if todayList.isEmpty || ScheduleCalculator.isDayFinished(in: data.courses, at: now) {
            let upcoming = ScheduleCalculator.nextUpcomingCourse(in: data.courses, at: now)

            // 倒數要會走動：產生接下來 60 分鐘、每分鐘一個 entry，
            // 讓「還有 N 小時 N 分」在跨分鐘或跨小時時自動跳動。
            if upcoming != nil {
                var entries: [CourseTimelineEntry] = []
                for minuteOffset in 0..<60 {
                    if let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: now) {
                        entries.append(makeEntry(at: entryDate, courses: data.courses, settings: data.settings, reminderMinutes: data.reminderMinutes))
                    }
                }
                let reloadDate = Calendar.current.date(byAdding: .minute, value: 60, to: now) ?? now.addingTimeInterval(3600)
                completion(Timeline(entries: entries, policy: .after(reloadDate)))
                return
            }

            // 完全沒有下一堂課：只需要單一狀態，跨日再重新調度。
            let entry = makeEntry(at: now, courses: data.courses, settings: data.settings, reminderMinutes: data.reminderMinutes)
            let reloadDate = ScheduleCalculator.startOfNextDay(after: now)
            completion(Timeline(entries: [entry], policy: .after(reloadDate)))
            return
        }

        // 今日還有課：
        // 依照使用者需求「精確到分、以分做更新，每過一分鐘進度條就會更新它的百分比」
        // 預排未來 30 分鐘每一分鐘的 Entry，讓 iOS 系統每分鐘精確切換進度百分比。
        var entries: [CourseTimelineEntry] = []
        for minuteOffset in 0..<30 {
            if let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: now) {
                entries.append(makeEntry(at: entryDate, courses: data.courses, settings: data.settings, reminderMinutes: data.reminderMinutes))
            }
        }

        let reloadDate = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800)
        completion(Timeline(entries: entries, policy: .after(reloadDate)))
    }

    private func makeEntry(
        at date: Date,
        courses: [Course],
        settings: WidgetSettings,
        reminderMinutes: Int? = nil
    ) -> CourseTimelineEntry {
        let current = ScheduleCalculator.currentCourse(in: courses, at: date)
        let next = ScheduleCalculator.nextCourse(in: courses, at: date)
        let todayList = ScheduleCalculator.todayCourses(in: courses, at: date)
        let progress = ScheduleCalculator.todayProgress(in: courses, at: date)
        let upcoming = ScheduleCalculator.nextUpcomingCourse(in: courses, at: date)

        // 主角課程的選擇必須看「時間」：
        // 只有正在上課、或今天還有下一堂課時，才把課程當成主角。
        // 今日課程全部結束後若退回 todayList.first，晚上就會顯示早上已上完的第一堂課
        // （這正是先前「小工具顯示早上的課、看起來沒同步」的原因）。
        let target: Course?
        if let current {
            target = current
        } else if let next {
            target = next.course
        } else {
            target = nil
        }

        return CourseTimelineEntry(
            date: date,
            targetCourse: target,
            currentCourse: current,
            nextCourse: next,
            todayCourses: todayList,
            progress: progress,
            settings: settings,
            classReminderMinutes: reminderMinutes,
            nextCourseAfterToday: upcoming?.course,
            nextCourseDate: upcoming?.date
        )
    }
}
