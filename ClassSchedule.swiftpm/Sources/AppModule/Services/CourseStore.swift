import Foundation
import SwiftUI
import Combine

/// 课表核心数据管理与持久化中心
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
            loadSampleCourses()
        }
    }

    // MARK: - 查询业务逻辑 (核心用于小组件与今日速览)

    /// 获取当前正在进行的课程
    public func currentCourse(at date: Date = Date(), calendar: Calendar = .current) -> Course? {
        let dayOfWeek = normalizedDayOfWeek(from: date, calendar: calendar)
        let now = TimeOfDay(date: date, calendar: calendar)
        return courses.first { course in
            course.dayOfWeek == dayOfWeek && now >= course.startTime && now <= course.endTime
        }
    }

    /// 获取下一节即将开始的课程
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

    /// 获取今天的所有课程 (按时间升序排序)
    public func todayCourses(at date: Date = Date(), calendar: Calendar = .current) -> [Course] {
        let dayOfWeek = normalizedDayOfWeek(from: date, calendar: calendar)
        return courses(for: dayOfWeek)
    }

    /// 获取某周几的所有课程
    public func courses(for dayOfWeek: Int) -> [Course] {
        courses
            .filter { course in course.dayOfWeek == dayOfWeek }
            .sorted { a, b in a.startTime < b.startTime }
    }

    // MARK: - 数据持久化 (兼容 App Group 共享)

    private func storageURL(for filename: String) -> URL {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupSuite) {
            return containerURL.appendingPathComponent(filename)
        }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(filename)
    }

    public func save() {
        // 保存课程列表
        do {
            let data = try JSONEncoder().encode(courses)
            let primaryURL = storageURL(for: coursesFilename)
            try data.write(to: primaryURL, options: [.atomicWrite])

            // 备份到 Documents
            let backupURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(coursesFilename)
            try? data.write(to: backupURL, options: [.atomicWrite])
        } catch {
            print("[CourseStore] 保存课程数据失败: \(error)")
        }

        // 保存课表设置
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
            print("[CourseStore] 保存设置失败: \(error)")
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

    // MARK: - 数据操作

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

    public func delete(at offsets: IndexSet, in dayCourses: [Course]) {
        let idsToDelete = offsets.map { index in dayCourses[index].id }
        courses.removeAll { course in idsToDelete.contains(course.id) }
        save()
    }

    public func delete(_ course: Course) {
        courses.removeAll { item in item.id == course.id }
        save()
    }

    public func updateSettings(_ newSettings: ScheduleSettings) {
        self.settings = newSettings
        saveSettings()
    }

    // MARK: - 辅助计算

    public func normalizedDayOfWeek(from date: Date = Date(), calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 ? 7 : (weekday - 1)
    }

    // MARK: - 初始预置示例数据

    private func loadSampleCourses() {
        courses = [
            Course(
                name: "高等数学 (下)",
                teacher: "张建国 教授",
                classroom: "教三楼 302",
                dayOfWeek: 1,
                startTime: TimeOfDay(hour: 8, minute: 30),
                endTime: TimeOfDay(hour: 10, minute: 5),
                colorName: "indigo",
                notes: "必修课，带微积分教材"
            ),
            Course(
                name: "计算机网络体系",
                teacher: "李明 博士",
                classroom: "实验楼 405 机房",
                dayOfWeek: 1,
                startTime: TimeOfDay(hour: 10, minute: 25),
                endTime: TimeOfDay(hour: 12, minute: 0),
                colorName: "blue",
                notes: "Wireshark 抓包实验"
            ),
            Course(
                name: "大学通用英语 (IV)",
                teacher: "Sarah Johnson",
                classroom: "文科楼 108",
                dayOfWeek: 2,
                startTime: TimeOfDay(hour: 14, minute: 0),
                endTime: TimeOfDay(hour: 15, minute: 35),
                colorName: "orange",
                notes: "小组 Presentation"
            ),
            Course(
                name: "数据结构与算法",
                teacher: "陈华 副教授",
                classroom: "教二楼 201",
                dayOfWeek: 2,
                startTime: TimeOfDay(hour: 8, minute: 30),
                endTime: TimeOfDay(hour: 10, minute: 5),
                colorName: "purple",
                notes: "红黑树与最短路径"
            ),
            Course(
                name: "线性代数",
                teacher: "刘敏 教授",
                classroom: "教三楼 104",
                dayOfWeek: 3,
                startTime: TimeOfDay(hour: 9, minute: 0),
                endTime: TimeOfDay(hour: 10, minute: 40),
                colorName: "teal",
                notes: "特征值与特征向量"
            ),
            Course(
                name: "操作系统核心原理",
                teacher: "赵强 博士",
                classroom: "软件楼 301",
                dayOfWeek: 4,
                startTime: TimeOfDay(hour: 14, minute: 0),
                endTime: TimeOfDay(hour: 16, minute: 30),
                colorName: "mint",
                notes: "进程并发与虚拟内存"
            ),
            Course(
                name: "移动应用交互设计",
                teacher: "王雪峰 讲师",
                classroom: "艺术楼 502",
                dayOfWeek: 5,
                startTime: TimeOfDay(hour: 10, minute: 25),
                endTime: TimeOfDay(hour: 12, minute: 0),
                colorName: "pink",
                notes: "Apple HIG 人机设计规范实操"
            )
        ]
        save()
    }
}
