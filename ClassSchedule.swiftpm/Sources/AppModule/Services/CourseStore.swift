import Foundation
import SwiftUI
import Combine

/// 課表核心資料管理與持久化中心（全正體中文）
public final class CourseStore: ObservableObject {
    @Published public var courses: [Course] = []
    @Published public var settings: ScheduleSettings = ScheduleSettings()

    private let coursesFilename = "courses.json"
    private let settingsFilename = "settings.json"
    private let appGroupSuite = "group.com.fengfeng.classschedule"

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

    /// 取得某週幾的所有課程
    public func courses(for dayOfWeek: Int) -> [Course] {
        courses
            .filter { course in course.dayOfWeek == dayOfWeek }
            .sorted { a, b in a.startTime < b.startTime }
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

    // MARK: - 資料持久化 (相容 App Group 共享)

    private func storageURL(for filename: String) -> URL {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupSuite) {
            return containerURL.appendingPathComponent(filename)
        }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(filename)
    }

    public func save() {
        do {
            let data = try JSONEncoder().encode(courses)
            let primaryURL = storageURL(for: coursesFilename)
            try data.write(to: primaryURL, options: [.atomicWrite])

            let backupURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(coursesFilename)
            try? data.write(to: backupURL, options: [.atomicWrite])
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

            let backupURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(settingsFilename)
            try? data.write(to: backupURL, options: [.atomicWrite])
        } catch {
            print("[CourseStore] 儲存設定失敗: \(error)")
        }
    }

    private func loadCourses() {
        let primaryURL = storageURL(for: coursesFilename)
        if let data = try? Data(contentsOf: primaryURL),
           let decoded = try? JSONDecoder().decode([Course].self, from: data) {
            self.courses = decoded
            return
        }

        let backupURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(coursesFilename)
        if let data = try? Data(contentsOf: backupURL),
           let decoded = try? JSONDecoder().decode([Course].self, from: data) {
            self.courses = decoded
        }
    }

    private func loadSettings() {
        let primaryURL = storageURL(for: settingsFilename)
        if let data = try? Data(contentsOf: primaryURL),
           let decoded = try? JSONDecoder().decode(ScheduleSettings.self, from: data) {
            self.settings = decoded
            return
        }

        let backupURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(settingsFilename)
        if let data = try? Data(contentsOf: backupURL),
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

    // MARK: - 輔助計算

    public func normalizedDayOfWeek(from date: Date = Date(), calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 ? 7 : (weekday - 1)
    }
}
