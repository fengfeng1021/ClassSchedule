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

    /// 倒數卡片最早提前幾分鐘開始顯示。
    ///
    /// Live Activity 只能在 App 處於前景時啟動，若只在「課前 X 分鐘」才開，
    /// 使用者沒在那段時間打開 App 就會完全看不到。
    /// 因此改成提前 3 小時就允許顯示 —— 使用者只要在這段期間內開過一次 App，
    /// 卡片就會留在鎖定畫面上持續倒數。
    private static let leadTimeMinutes = 180

    private init() {}

    /// 依目前課表與設定，讓 Live Activity 呈現正確狀態。
    ///
    /// - 若下一堂課已進入**提前顯示窗口**（見 `leadTimeMinutes`）→ 啟動倒數卡片
    /// - 已在倒數中的同一堂課不會重複建立；換課或時間變動會先收掉舊的
    /// - 課堂結束後收掉卡片
    public func sync(courses: [Course], settings: ScheduleSettings, calendar: Calendar = .current) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let occurrence = ClassReminderService.nextOccurrence(courses: courses, calendar: calendar) else {
            endAllActivities()
            return
        }

        let now = Date()

        // 課已經結束 → 收掉卡片
        if now >= occurrence.endDate {
            endAllActivities()
            return
        }

        // 提前顯示窗口：使用者設定的提醒分鐘數，但至少提前 leadTime 分鐘開始顯示，
        // 讓卡片能「一直放在鎖定畫面上」，而不是只在課前幾分鐘突然出現。
        let leadMinutes = max(settings.classReminderMinutes ?? 0, Self.leadTimeMinutes)
        let windowStart = occurrence.startDate.addingTimeInterval(TimeInterval(-leadMinutes * 60))
        guard now >= windowStart else { return }

        let running = Activity<ClassSessionActivityAttributes>.activities

        // 已經有同一堂課的卡片就不重複建立
        if let existing = running.first(where: { $0.attributes.startDate == occurrence.startDate }) {
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
