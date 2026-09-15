import Foundation
import UserNotifications
import WidgetKit

/// 上課提醒服務：負責「課前 X 分鐘」的本機通知。
///
/// 為什麼主力是本機通知而不是其他機制：
/// - 本機通知由**系統**在指定時間遞送，App 關著也會準時跳 —— 這是唯一可靠的管道。
/// - Live Activity 可以在鎖屏顯示會跳動的大倒數，但 **ActivityKit 只能在 App 處於前景時
///   才能啟動**（背景啟動需要推播或 LiveActivityIntent），所以它只能當作加分項，
///   由 `ClassLiveActivityController` 在前景時接手。
///
/// 通知數量上限：iOS 每個 App 最多保留 64 則待遞送通知，因此這裡只排最近的若干堂課。
public final class ClassReminderService {

    public static let shared = ClassReminderService()

    /// iOS 允許的待遞送通知上限，保守留一點餘裕。
    private let maximumPendingNotifications = 60
    /// 往後排程的天數（排越長越容易被系統丟棄，一週足夠涵蓋連假以外的情況）。
    private let schedulingHorizonDays = 14

    private let center = UNUserNotificationCenter.current()
    private let identifierPrefix = "class-reminder-"

    private init() {}

    // MARK: - 權限

    /// 目前的通知授權狀態。
    public func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// 要求通知權限（第一次才會跳系統對話框）。
    @discardableResult
    public func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("[ClassReminderService] 要求通知權限失敗: \(error)")
            return false
        }
    }

    // MARK: - 排程

    /// 依課表與設定重新排程所有提醒。
    ///
    /// 會先清掉自己先前排的所有通知（只清 `class-reminder-` 前綴，
    /// 不影響使用者在其他地方排的通知）。
    public func reschedule(courses: [Course], settings: ScheduleSettings, calendar: Calendar = .current) async {
        cancelAll()

        guard let minutes = settings.classReminderMinutes, minutes > 0 else { return }

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let occurrences = Self.upcomingOccurrences(
            courses: courses,
            from: Date(),
            horizonDays: schedulingHorizonDays,
            calendar: calendar
        )

        for occurrence in occurrences.prefix(maximumPendingNotifications) {
            let fireDate = occurrence.startDate.addingTimeInterval(TimeInterval(-minutes * 60))
            guard fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(occurrence.course.name) 即將上課"
            if !occurrence.course.classroom.isEmpty {
                content.subtitle = "教室 \(occurrence.course.classroom)"
            }
            content.body = "還有 \(minutes) 分鐘 · \(occurrence.course.timeRangeString)"
            content.sound = .default
            content.userInfo = ["courseId": occurrence.course.id.uuidString]

            var components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            components.second = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = "\(identifierPrefix)\(occurrence.course.id.uuidString)-\(Int(occurrence.startDate.timeIntervalSince1970))"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            do {
                try await center.add(request)
            } catch {
                print("[ClassReminderService] 排程通知失敗: \(error)")
            }
        }
    }

    /// 清掉本服務排的所有通知。
    public func cancelAll() {
        center.getPendingNotificationRequests { [identifierPrefix] requests in
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(identifierPrefix) }
            guard !identifiers.isEmpty else { return }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    /// 立即送出一則測試通知（讓使用者不必等真正上課就能確認設定成功）。
    public func sendTestNotification(minutes: Int?) async {
        let granted = await authorizationStatus() == .authorized
        if !granted {
            _ = await requestAuthorization()
        }

        let content = UNMutableNotificationContent()
        content.title = "上課提醒測試"
        content.subtitle = "教室 I426"
        content.body = minutes.map { "正式提醒會在課前 \($0) 分鐘跳出，就像這樣。" }
            ?? "尚未設定提醒分鐘數，請先在下方輸入。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(identifierPrefix)test",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        )
        do {
            try await center.add(request)
        } catch {
            print("[ClassReminderService] 測試通知失敗: \(error)")
        }
    }

    // MARK: - 課堂時間點計算

    public struct CourseOccurrence {
        public let course: Course
        public let startDate: Date
        public let endDate: Date
    }

    /// 往後找出每一堂課的實際開始與結束時間點。
    ///
    /// 與小工具共用同一套邏輯：以「星期幾 + 節次時間」推算日期，
    /// 產生的時間點是絕對時間，可直接餵給通知與 Live Activity。
    public static func upcomingOccurrences(
        courses: [Course],
        from date: Date = Date(),
        horizonDays: Int,
        calendar: Calendar = .current
    ) -> [CourseOccurrence] {
        guard !courses.isEmpty else { return [] }

        var results: [CourseOccurrence] = []
        let startOfToday = calendar.startOfDay(for: date)

        for dayOffset in 0..<horizonDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
            let weekday = ScheduleCalculator.normalizedDayOfWeek(from: day, calendar: calendar)

            for course in courses where course.dayOfWeek == weekday {
                guard let startDate = course.startTime.toDate(baseDate: day, calendar: calendar),
                      let endDate = course.endTime.toDate(baseDate: day, calendar: calendar) else { continue }
                // 今天已開始的課就不必再提醒
                guard endDate > date else { continue }
                results.append(CourseOccurrence(course: course, startDate: startDate, endDate: endDate))
            }
        }

        return results.sorted { $0.startDate < $1.startDate }
    }

    /// 下一堂即將開始的課（含「已經開始但還沒結束」的那一堂）。
    public static func nextOccurrence(
        courses: [Course],
        from date: Date = Date(),
        calendar: Calendar = .current
    ) -> CourseOccurrence? {
        upcomingOccurrences(courses: courses, from: date, horizonDays: 14, calendar: calendar).first
    }
}
