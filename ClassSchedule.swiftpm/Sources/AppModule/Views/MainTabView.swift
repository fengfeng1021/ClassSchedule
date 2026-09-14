import SwiftUI

/// 根导航架构：整合“今日聚焦”、“周课表”、“课程管理”三大核心业务
public struct MainTabView: View {
    @ObservedObject var store: CourseStore
    @State private var selectedTab: Tab = .today

    public enum Tab: String, Hashable {
        case today = "今日"
        case schedule = "周课表"
        case courses = "课程库"
    }

    public init(store: CourseStore) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(store: store)
                .tabItem {
                    Label("今日", systemImage: "clock.badge.checkmark.fill")
                }
                .tag(Tab.today)

            WeeklyScheduleView(store: store)
                .tabItem {
                    Label("周课表", systemImage: "calendar")
                }
                .tag(Tab.schedule)

            CourseListView(store: store)
                .tabItem {
                    Label("课程库", systemImage: "books.vertical.fill")
                }
                .tag(Tab.courses)
        }
        .tint(.blue)
    }
}
