import Foundation

/// 今日課程時間總進度資料模型（精確到分，每分鐘即時更新）
public struct DayProgressInfo: Equatable {
    public let percentage: Int     // 0 ~ 100
    public let progress: Double    // 0.0 ~ 1.0
    public let elapsedMinutes: Int
    public let totalMinutes: Int
    public let statusText: String
    public let isCompleted: Bool
    public let hasStarted: Bool

    public init(
        percentage: Int,
        progress: Double,
        elapsedMinutes: Int,
        totalMinutes: Int,
        statusText: String,
        isCompleted: Bool,
        hasStarted: Bool
    ) {
        self.percentage = percentage
        self.progress = progress
        self.elapsedMinutes = elapsedMinutes
        self.totalMinutes = totalMinutes
        self.statusText = statusText
        self.isCompleted = isCompleted
        self.hasStarted = hasStarted
    }
}

/// 課表狀態與時程核心演算法（供主 App 與桌面小工具 WidgetKit 共享運算）
public struct ScheduleCalculator {

    /// 將標準 Calendar 週幾 (週日=1, 週一=2... 週六=7) 轉換為標準 1 (週一) ~ 7 (週日)
    public static func normalizedDayOfWeek(from date: Date = Date(), calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 ? 7 : (weekday - 1)
    }

    /// 取得指定週幾的所有課程（按開始時間升序排列）
    public static func courses(in courses: [Course], for dayOfWeek: Int) -> [Course] {
        courses
            .filter { $0.dayOfWeek == dayOfWeek }
            .sorted { $0.startTime < $1.startTime }
    }

    /// 取得目前正在進行中的課程
    public static func currentCourse(in courses: [Course], at date: Date = Date(), calendar: Calendar = .current) -> Course? {
        let dayOfWeek = normalizedDayOfWeek(from: date, calendar: calendar)
        let now = TimeOfDay(date: date, calendar: calendar)
        return courses.first { course in
            course.dayOfWeek == dayOfWeek && now >= course.startTime && now <= course.endTime
        }
    }

    /// 取得下一節即將開始的課程及距離分鐘數
    public static func nextCourse(in courses: [Course], at date: Date = Date(), calendar: Calendar = .current) -> (course: Course, minutesUntil: Int)? {
        let dayOfWeek = normalizedDayOfWeek(from: date, calendar: calendar)
        let now = TimeOfDay(date: date, calendar: calendar)

        let upcomingToday = courses
            .filter { course in
                course.dayOfWeek == dayOfWeek && course.startTime > now
            }
            .sorted { a, b in
                a.startTime < b.startTime
            }

        if let next = upcomingToday.first {
            let minutes = next.startTime.totalMinutes - now.totalMinutes
            return (next, minutes)
        }
        return nil
    }

    /// 取得今天的所有課程 (按時間升序排序)
    public static func todayCourses(in courses: [Course], at date: Date = Date(), calendar: Calendar = .current) -> [Course] {
        let dayOfWeek = normalizedDayOfWeek(from: date, calendar: calendar)
        return self.courses(in: courses, for: dayOfWeek)
    }

    /// 今日是否已經「完全結束」：今天有課，但已經沒有正在上、也沒有接下來要上的課。
    ///
    /// 這個判斷很重要：晚上 9 點時若仍把 `todayCourses.first` 當成主角，
    /// 小工具就會顯示早上已經上完的第一堂課（看起來像「時間沒同步」）。
    public static func isDayFinished(in courses: [Course], at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let list = todayCourses(in: courses, at: date, calendar: calendar)
        guard !list.isEmpty else { return false }
        return currentCourse(in: courses, at: date, calendar: calendar) == nil
            && nextCourse(in: courses, at: date, calendar: calendar) == nil
    }

    /// 取得「今天之後」最近的一堂課，用於今日已結束或今日無課時顯示下一堂。
    /// 回傳值同時包含該堂課實際發生的日期，讓顯示層可標示「明天」「週三」。
    public static func nextUpcomingCourse(
        in courses: [Course],
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> (course: Course, date: Date)? {
        for dayOffset in 1...7 {
            guard let candidateDate = calendar.date(byAdding: .day, value: dayOffset, to: date) else { continue }
            let dayOfWeek = normalizedDayOfWeek(from: candidateDate, calendar: calendar)
            if let first = self.courses(in: courses, for: dayOfWeek).first {
                return (first, candidateDate)
            }
        }
        return nil
    }

    /// 取得隔日零點，用於小工具時間軸在跨日時重新調度。
    public static func startOfNextDay(after date: Date = Date(), calendar: Calendar = .current) -> Date {
        let startOfToday = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? date.addingTimeInterval(86400)
    }

    /// 取得今日課程時間總進度（精確至分，每過一分鐘動態更新百分比）
    public static func todayProgress(in courses: [Course], at date: Date = Date(), calendar: Calendar = .current) -> DayProgressInfo {
        let list = todayCourses(in: courses, at: date, calendar: calendar)
        guard !list.isEmpty else {
            return DayProgressInfo(percentage: 0, progress: 0.0, elapsedMinutes: 0, totalMinutes: 0, statusText: "今日無課程", isCompleted: false, hasStarted: false)
        }

        let earliestStart = list.map { $0.startTime.totalMinutes }.min() ?? 0
        let latestEnd = list.map { $0.endTime.totalMinutes }.max() ?? 0
        let now = TimeOfDay(date: date, calendar: calendar).totalMinutes
        let total = max(latestEnd - earliestStart, 1)

        if now < earliestStart {
            return DayProgressInfo(percentage: 0, progress: 0.0, elapsedMinutes: 0, totalMinutes: total, statusText: "尚未開始 · 0%", isCompleted: false, hasStarted: false)
        } else if now >= latestEnd {
            return DayProgressInfo(percentage: 100, progress: 1.0, elapsedMinutes: total, totalMinutes: total, statusText: "今日已全部完成 · 100%", isCompleted: true, hasStarted: true)
        } else {
            let elapsed = now - earliestStart
            let frac = min(max(Double(elapsed) / Double(total), 0.0), 1.0)
            let pct = min(max(Int(round(frac * 100.0)), 0), 100)
            return DayProgressInfo(percentage: pct, progress: frac, elapsedMinutes: elapsed, totalMinutes: total, statusText: "今日進度 \(pct)%", isCompleted: false, hasStarted: true)
        }
    }
}
