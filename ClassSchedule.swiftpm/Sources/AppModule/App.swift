import SwiftUI

@main
struct ClassScheduleApp: App {
    @StateObject private var store = CourseStore()

    public init() {
        ProMotionOptimizer.shared.enable120Hz()
    }

    var body: some Scene {
        WindowGroup {
            ScheduleGridView(store: store)
                .environmentObject(store)
        }
    }
}
