import Foundation
import SwiftUI
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

/// 課表核心資料管理與持久化中心（全正體中文）
public final class CourseStore: ObservableObject {
    @Published public var courses: [Course] = []
    @Published public var settings: ScheduleSettings = ScheduleSettings()

    private let coursesFilename = "courses.json"
    private let settingsFilename = "settings.json"

    public init() {
        loadSettings()
        loadCourses()
        if courses.isEmpty {
            self.courses = ScheduleParser.generalSampleCourses
            save()
        }
    }

    // MARK: - 查詢業務邏輯 (核心用於小組件、今日速覽與課表格狀定位)

    /// 取得目前正在進行的課程
    public func currentCourse(at date: Date = Date(), calendar: Calendar = .current) -> Course? {
        let dayOfWeek = normalizedDayOfWeek(from: date, calendar: calendar)
        let now = TimeOfDay(date: date, calendar: calendar)
        return courses.first { course in
            course.dayOfWeek == dayOfWeek && now >= course.startTime && now <= course.endTime
        }
    }

    /// 取得下一節即將開始的課程
    public func nextCourse(at date: Date = Date(), calendar: Calendar = .current) -> (course: Course, minutesUntil: Int)? {
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
    public func todayCourses(at date: Date = Date(), calendar: Calendar = .current) -> [Course] {
        let dayOfWeek = normalizedDayOfWeek(from: date, calendar: calendar)
        return courses(for: dayOfWeek)
    }

    /// 取得今日課程時間總進度（精確至分，每過一分鐘動態更新百分比）
    public func todayProgress(at date: Date = Date(), calendar: Calendar = .current) -> DayProgressInfo {
        let list = todayCourses(at: date, calendar: calendar)
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

    /// 取得某週幾的所有課程
    public func courses(for dayOfWeek: Int) -> [Course] {
        courses
            .filter { course in course.dayOfWeek == dayOfWeek }
            .sorted { a, b in a.startTime < b.startTime }
    }

    // MARK: - 碰撞防護與時段重疊檢測 (Collision Detection)

    /// 檢測在指定星期幾與起訖節次範圍內，是否與現有其他課程衝突重疊
    public func hasPeriodOverlap(
        dayOfWeek: Int,
        startPeriodId: String,
        endPeriodId: String,
        excludingCourseId: UUID? = nil
    ) -> Bool {
        guard let reqStartIndex = settings.indexOfPeriod(id: startPeriodId),
              let reqEndIndex = settings.indexOfPeriod(id: endPeriodId) else {
            return false
        }
        let minReq = min(reqStartIndex, reqEndIndex)
        let maxReq = max(reqStartIndex, reqEndIndex)

        for course in courses where course.dayOfWeek == dayOfWeek {
            if let excludingId = excludingCourseId, course.id == excludingId {
                continue
            }
            if let cStart = settings.indexOfPeriod(id: course.startPeriodId),
               let cEnd = settings.indexOfPeriod(id: course.endPeriodId) {
                let minC = min(cStart, cEnd)
                let maxC = max(cStart, cEnd)

                // 兩區間重疊判定: max(start1, start2) <= min(end1, end2)
                if max(minReq, minC) <= min(maxReq, maxC) {
                    return true
                }
            }
        }
        return false
    }

    /// 總學分統計（同日同課名且同教師的切開時段自動去重累計）
    public var totalUniqueCredits: Int {
        var seenKeys = Set<String>()
        var total = 0
        for course in courses {
            let key = "\(course.dayOfWeek)-\(course.name.trimmingCharacters(in: .whitespaces))-\(course.teacher.trimmingCharacters(in: .whitespaces))"
            if !seenKeys.contains(key) {
                seenKeys.insert(key)
                total += course.creditsInt
            }
        }
        return total
    }

    // MARK: - 手勢拖曳調整節次跨度 (Drag to Resize)

    public func updatePeriodRange(courseId: UUID, startPeriodId: String, endPeriodId: String) {
        guard let index = courses.firstIndex(where: { $0.id == courseId }) else { return }
        guard let startPeriod = settings.period(for: startPeriodId),
              let endPeriod = settings.period(for: endPeriodId) else { return }

        let startIndex = settings.indexOfPeriod(id: startPeriodId) ?? 0
        let endIndex = settings.indexOfPeriod(id: endPeriodId) ?? 0

        if startIndex <= endIndex {
            courses[index].startPeriodId = startPeriodId
            courses[index].endPeriodId = endPeriodId
            courses[index].startTime = startPeriod.startTime
            courses[index].endTime = endPeriod.endTime
        } else {
            courses[index].startPeriodId = endPeriodId
            courses[index].endPeriodId = startPeriodId
            courses[index].startTime = endPeriod.startTime
            courses[index].endTime = startPeriod.endTime
        }
        save()
    }

    // MARK: - 批次匯入與調適

    public func importCourses(_ newCourses: [Course], autoAdjustSettings: Bool = true) {
        self.courses = newCourses

        if autoAdjustSettings {
            // 檢查是否包含週末課程
            let hasWeekend = newCourses.contains { $0.dayOfWeek == 6 || $0.dayOfWeek == 7 }
            if hasWeekend {
                self.settings.showWeekend = true
            }

            // 檢查是否包含晨間 M 節
            let hasMorning = newCourses.contains { $0.startPeriodId == "M" }
            if hasMorning {
                self.settings.showMorningM = true
            }

            // 檢查是否包含夜間時段
            let hasEvening = newCourses.contains { course in
                ["R", "10", "11", "12", "13", "14"].contains(course.endPeriodId)
            }
            if hasEvening {
                self.settings.showEveningPeriods = true
            }
            saveSettings()
        }

        save()
    }

    // MARK: - 資料持久化 (本機極速讀寫，杜絕沙盒 IPC 啟動阻塞)

    private func storageURL(for filename: String) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(filename)
    }

    public func save() {
        do {
            let data = try JSONEncoder().encode(courses)
            let primaryURL = storageURL(for: coursesFilename)
            try data.write(to: primaryURL, options: [.atomicWrite])
        } catch {
            print("[CourseStore] 儲存課程資料失敗: \(error)")
        }

        saveSettings()
    }

    public func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            let primaryURL = storageURL(for: settingsFilename)
            try data.write(to: primaryURL, options: [.atomicWrite])
        } catch {
            print("[CourseStore] 儲存設定失敗: \(error)")
        }
    }

    private func loadCourses() {
        let primaryURL = storageURL(for: coursesFilename)
        if let data = try? Data(contentsOf: primaryURL),
           let decoded = try? JSONDecoder().decode([Course].self, from: data) {
            self.courses = decoded
        }
    }

    private func loadSettings() {
        let primaryURL = storageURL(for: settingsFilename)
        if let data = try? Data(contentsOf: primaryURL),
           let decoded = try? JSONDecoder().decode(ScheduleSettings.self, from: data) {
            self.settings = decoded
        }
    }

    // MARK: - 資料操作

    public func add(_ course: Course) {
        courses.append(course)
        save()
    }

    public func update(_ course: Course) {
        if let index = courses.firstIndex(where: { courseItem in courseItem.id == course.id }) {
            courses[index] = course
            save()
        }
    }

    public func delete(_ course: Course) {
        courses.removeAll { item in item.id == course.id }
        save()
    }

    public func updateSettings(_ newSettings: ScheduleSettings) {
        self.settings = newSettings
        saveSettings()
    }

    public func updateWidgetSettings(_ newSettings: WidgetSettings) {
        self.settings.widgetSettings = newSettings
        saveSettings()
    }

    // MARK: - 輔助計算

    public func normalizedDayOfWeek(from date: Date = Date(), calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 ? 7 : (weekday - 1)
    }
}
