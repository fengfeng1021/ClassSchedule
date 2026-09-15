import ActivityKit
import Foundation

/// 上課倒數 Live Activity 的生命週期管理。
///
/// **重要限制**：ActivityKit 只允許 App 在**前景**時啟動 Live Activity
/// （背景啟動需要推播權杖或 `LiveActivityIntent`）。
/// 因此這裡採「有機會就開」的策略：
/// - App 進入前景（開啟、切回）時同步
/// - 課表資料或提醒設定變更時同步
/// - 使用者點擊上課提醒通知而開啟 App 時也會同步
///
/// 真正「一定會響」的提醒由 `ClassReminderService` 的本機通知負責。
@available(iOS 16.2, *)
public final class ClassLiveActivityController {

    public static let shared = ClassLiveActivityController()

    private init() {}

    /// 依目前課表與設定，讓 Live Activity 呈現正確狀態。
    ///
    /// - 若下一堂課**已經進入提醒窗口**（課前 N 分鐘內）→ 啟動倒數卡片
    /// - 若正在上課的那堂課已有卡片 → 課堂結束後結束它
    /// - 若沒有符合條件的課 → 不動作（保留現有卡片，交由系統或使用者關閉）
    public func sync(courses: [Course], settings: ScheduleSettings, calendar: Calendar = .current) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let minutes = settings.classReminderMinutes, minutes > 0 else {
            // 提醒被關掉時，把還在畫面上的卡片收掉
            endAllActivities()
            return
        }
        guard let occurrence = ClassReminderService.nextOccurrence(courses: courses, calendar: calendar) else {
            endAllActivities()
            return
        }

        let now = Date()
        let windowStart = occurrence.startDate.addingTimeInterval(TimeInterval(-minutes * 60))

        // 課已經結束 → 收掉卡片
        if now >= occurrence.endDate {
            endAllActivities()
            return
        }

        // 還不到提醒窗口 → 不要提早跳卡片
        guard now >= windowStart else { return }

        let running = Activity<ClassSessionActivityAttributes>.activities

        // 已經有同一堂課的卡片就不再重複建立
        if let existing = running.first(where: { $0.attributes.startDate == occurrence.startDate }) {
            // 其他殘留的卡片（換課、改時間）順手收掉
            for activity in running where activity.id != existing.id {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
            return
        }

        // 換課或改時間：先收掉舊的再開新的
        endAllActivities()

        let attributes = ClassSessionActivityAttributes(
            course: occurrence.course,
            startDate: occurrence.startDate,
            endDate: occurrence.endDate,
            createdAt: now
        )

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: ClassSessionActivityAttributes.ContentState(), staleDate: occurrence.startDate),
                pushType: nil
            )
        } catch {
            // 被系統拒絕（例如使用者關閉了即時動態）時不影響其他功能
            print("[ClassLiveActivityController] 無法啟動 Live Activity: \(error)")
        }
    }

    /// 收掉本 App 所有還在畫面／背景的卡片。
    public func endAllActivities() {
        for activity in Activity<ClassSessionActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
