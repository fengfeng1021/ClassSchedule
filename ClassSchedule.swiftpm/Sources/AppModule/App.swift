import SwiftUI

@main
struct ClassScheduleApp: App {
    @StateObject private var store = CourseStore()

    var body: some Scene {
        WindowGroup {
            MainTabView(store: store)
                .environmentObject(store)
        }
    }
}
