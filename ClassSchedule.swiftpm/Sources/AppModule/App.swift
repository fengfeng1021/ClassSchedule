import SwiftUI

@main
struct ClassScheduleApp: App {
    @StateObject private var store = CourseStore()

    public init() {
        // ProMotion 高刷新率僅能由 Info.plist 解鎖，這裡只做狀態檢查，
        // 不再安裝常駐 CADisplayLink（詳見 ProMotionOptimizer 的說明）。
        ProMotionOptimizer.shared.enable120Hz()
    }

    var body: some Scene {
        WindowGroup {
            ScheduleGridView(store: store)
                .environmentObject(store)
        }
    }
}
