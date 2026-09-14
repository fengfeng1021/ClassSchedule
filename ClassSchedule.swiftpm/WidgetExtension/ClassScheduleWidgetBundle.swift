import WidgetKit
import SwiftUI

@main
struct ClassScheduleWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClassScheduleWidget()
    }
}

struct ClassScheduleWidget: Widget {
    let kind: String = "ClassScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CourseTimelineProvider()) { entry in
            ClassScheduleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("課表")
        .description("即時顯示當前與下一節課程、上課教室及今日日程進度。")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
