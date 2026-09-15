import ActivityKit
import SwiftUI
import WidgetKit

/// 上課倒數 Live Activity。
///
/// 鎖屏卡片以**超大倒數**為主角，搭配課程名稱與教室（像中型小工具那樣的資訊量）。
///
/// 倒數為什麼會自己跳動：`Text(timerInterval:countsDown:)` 由系統渲染，
/// 每秒更新一次，**不需要 App 在前景、也不需要推播**。
/// 區間刻意取「建立時間 → 上課時間」，因為這個範圍在卡片存活期間永遠有效。
@available(iOS 16.2, *)
struct ClassSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClassSessionActivityAttributes.self) { context in
            lockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("即將上課")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text(context.attributes.courseName)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    countdownText(context: context, size: 22)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 6) {
                        if !context.attributes.classroom.isEmpty {
                            Label(context.attributes.classroom, systemImage: "location.fill")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(courseColor(context))
                        }
                        Spacer(minLength: 0)
                        Text(context.attributes.startDate, style: .time)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "graduationcap.fill")
                    .foregroundStyle(courseColor(context))
            } compactTrailing: {
                countdownText(context: context, size: 13)
            } minimal: {
                Image(systemName: "graduationcap.fill")
                    .foregroundStyle(courseColor(context))
            }
            .keylineTint(courseColor(context))
        }
    }

    // MARK: - 鎖屏卡片

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<ClassSessionActivityAttributes>) -> some View {
        let attributes = context.attributes

        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("即將上課")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)

                Text(attributes.courseName)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 6) {
                    if !attributes.classroom.isEmpty {
                        Label(attributes.classroom, systemImage: "location.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(courseColor(context))
                    }

                    Text(attributes.startDate, style: .time)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("距上課")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)

                // 由系統渲染、每秒自動更新的大倒數
                countdownText(context: context, size: 38)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    /// 倒數本體。區間取「建立時間 → 上課時間」，`countsDown: true` 讓它倒數到上課時刻。
    @ViewBuilder
    private func countdownText(context: ActivityViewContext<ClassSessionActivityAttributes>, size: CGFloat) -> some View {
        let attributes = context.attributes
        Text(timerInterval: attributes.createdAt...attributes.startDate, countsDown: true)
            .font(.system(size: size, weight: .black, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(courseColor(context))
    }

    private func courseColor(_ context: ActivityViewContext<ClassSessionActivityAttributes>) -> Color {
        Course.color(for: context.attributes.colorName)
    }
}
