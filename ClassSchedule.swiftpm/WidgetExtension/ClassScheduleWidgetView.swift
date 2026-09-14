import WidgetKit
import SwiftUI

/// 桌面小工具實際視圖呈現器（支援所有尺寸與顯示模式）
public struct ClassScheduleWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    public let entry: CourseTimelineEntry

    public init(entry: CourseTimelineEntry) {
        self.entry = entry
    }

    public var body: some View {
        if family == .accessoryRectangular || family == .accessoryInline {
            if #available(iOS 17.0, *) {
                contentView
                    .containerBackground(for: .widget) {
                        Color.clear
                    }
            } else {
                contentView
            }
        } else {
            if #available(iOS 17.0, *) {
                contentView
                    .containerBackground(for: .widget) {
                        widgetBackground(for: entry.targetCourse, theme: entry.settings.theme)
                    }
            } else {
                contentView
                    .background(widgetBackground(for: entry.targetCourse, theme: entry.settings.theme))
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch family {
        case .systemSmall:
            smallWidgetView
        case .systemMedium:
            mediumWidgetView
        case .systemLarge:
            largeWidgetView
        case .accessoryRectangular:
            accessoryRectangularView
        case .accessoryInline:
            accessoryInlineView
        default:
            mediumWidgetView
        }
    }

    // MARK: - 1. 小型小工具 (2x2)

    @ViewBuilder
    private var smallWidgetView: some View {
        let settings = entry.settings
        if let course = entry.targetCourse {
            switch settings.displayMode {
            case .classroomFocus:
                // 模式 1：教室速查
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        let isCurrent = entry.currentCourse != nil
                        let statusColor = isCurrent ? Color.green : course.color
                        HStack(spacing: 3) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 6, height: 6)
                            Text(isCurrent ? "上課中" : (entry.nextCourse != nil ? "\(entry.nextCourse!.minutesUntil)分後" : "下一節"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(statusColor)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.14), in: Capsule())

                        Spacer()

                        if settings.showPeriodTime {
                            Text(course.timeRangeString)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if settings.showClassroom && !course.classroom.isEmpty {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("上課教室")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 3) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 11))
                                Text(course.classroom)
                                    .font(.system(size: settings.highlightClassroom ? 24 : 18, weight: .black, design: .rounded))
                            }
                            .foregroundStyle(course.color)
                        }
                    }

                    Text(course.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if settings.showTeacher && !course.teacher.isEmpty {
                        Text(course.teacher)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(12)

            case .dailyTimeline:
                // 模式 2：今日日程
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("今日日程")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("共\(entry.todayCourses.count)堂")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    if entry.todayCourses.isEmpty {
                        emptyWidgetContent
                    } else {
                        VStack(spacing: 5) {
                            ForEach(entry.todayCourses.prefix(2)) { c in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(c.color)
                                            .frame(width: 5, height: 5)
                                        Text(c.name)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                    }

                                    HStack(spacing: 4) {
                                        if settings.showPeriodTime {
                                            Text(c.startTime.formatted)
                                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                                .monospacedDigit()
                                                .foregroundStyle(.secondary)
                                        }

                                        if settings.showClassroom && !c.classroom.isEmpty {
                                            Text("·")
                                                .foregroundStyle(.secondary)
                                            Text(c.classroom)
                                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                                .foregroundStyle(c.color)
                                        }
                                    }
                                }
                                .padding(.vertical, 1)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)

            case .countdown:
                // 模式 3：簡約倒數
                VStack(spacing: 4) {
                    Spacer()
                    if entry.currentCourse != nil {
                        Text("課程進行中")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.12), in: Capsule())

                        Text(course.name)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .padding(.top, 2)
                    } else if let next = entry.nextCourse {
                        Text("\(next.minutesUntil)")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(.orange)
                        Text("分鐘後上課")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)

                        Text(course.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.blue)
                        Text("今日無課")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                    }

                    if settings.showClassroom && !course.classroom.isEmpty {
                        Text(course.classroom)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(course.color)
                    }

                    if settings.showPeriodTime {
                        Text(course.timeRangeString)
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
            }
        } else {
            emptyWidgetContent
        }
    }

    // MARK: - 2. 中型小工具 (2x4)

    @ViewBuilder
    private var mediumWidgetView: some View {
        let settings = entry.settings
        if let course = entry.targetCourse {
            switch settings.displayMode {
            case .classroomFocus:
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        let isCurrent = entry.currentCourse != nil
                        let statusColor = isCurrent ? Color.green : course.color
                        HStack(spacing: 4) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 7, height: 7)
                            Text(isCurrent ? "目前進行中" : (entry.nextCourse != nil ? "下一節" : "本日排課"))
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(statusColor)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(statusColor.opacity(0.12), in: Capsule())

                        Spacer()

                        if settings.showClassroom {
                            Text("上課教室")
                                .font(.system(size: 9.5))
                                .foregroundStyle(.secondary)

                            Text(course.classroom.isEmpty ? "未指定" : course.classroom)
                                .font(.system(size: settings.highlightClassroom ? 30 : 22, weight: .black, design: .rounded))
                                .foregroundStyle(course.color)
                                .lineLimit(1)
                        }

                        if settings.showPeriodTime {
                            Text(course.timeRangeString)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    VStack(alignment: .leading, spacing: 5) {
                        Text(course.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if settings.showTeacher && !course.teacher.isEmpty {
                            Text(course.teacher)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        if settings.showCredits && !course.credits.isEmpty {
                            Text(course.credits)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary.opacity(0.85))
                        }

                        Spacer()

                        progressBarView(progressInfo: entry.progress, color: course.color)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)

            case .dailyTimeline:
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("今日課程清單")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("共 \(entry.todayCourses.count) 堂課")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    if entry.todayCourses.isEmpty {
                        emptyWidgetContent
                    } else {
                        VStack(spacing: 5) {
                            ForEach(entry.todayCourses.prefix(2)) { c in
                                HStack(spacing: 6) {
                                    if settings.showPeriodTime {
                                        Text(c.timeRangeString)
                                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                            .monospacedDigit()
                                            .frame(width: 80, alignment: .leading)
                                            .foregroundStyle(.primary)
                                    }

                                    Text(c.name)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    Spacer()

                                    if settings.showTeacher && !c.teacher.isEmpty {
                                        Text(c.teacher)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                    }

                                    if settings.showClassroom && !c.classroom.isEmpty {
                                        Text(c.classroom)
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(c.color.opacity(0.15), in: Capsule())
                                            .foregroundStyle(c.color)
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    progressBarView(progressInfo: entry.progress, color: course.color)
                }
                .padding(12)

            case .countdown:
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        if entry.currentCourse != nil {
                            Text("上課中")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(.green)
                            Text("進行中")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundStyle(.green)
                        } else if let next = entry.nextCourse {
                            Text("\(next.minutesUntil)")
                                .font(.system(size: 38, weight: .black, design: .rounded))
                                .foregroundStyle(.orange)
                            Text("分鐘後開始")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("全部完成")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(.blue)
                        }

                        if settings.showPeriodTime {
                            Text(course.timeRangeString)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 100, alignment: .leading)

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if settings.showClassroom && !course.classroom.isEmpty {
                            Text(course.classroom)
                                .font(.system(size: settings.highlightClassroom ? 14 : 12, weight: .black, design: .rounded))
                                .foregroundStyle(course.color)
                        }

                        if settings.showTeacher && !course.teacher.isEmpty {
                            Text(course.teacher)
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        progressBarView(progressInfo: entry.progress, color: course.color)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
            }
        } else {
            emptyWidgetContent
        }
    }

    // MARK: - 3. 大型小工具 (4x4)

    @ViewBuilder
    private var largeWidgetView: some View {
        let settings = entry.settings
        VStack(alignment: .leading, spacing: 8) {
            switch settings.displayMode {
            case .classroomFocus:
                if let course = entry.targetCourse {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.currentCourse != nil ? "● 進行中課程" : "▶ 下一節預告")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(entry.currentCourse != nil ? Color.green : course.color)

                            Text(course.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if settings.showClassroom && !course.classroom.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10))
                                Text(course.classroom)
                                    .font(.system(size: settings.highlightClassroom ? 18 : 14, weight: .black, design: .rounded))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(course.color.opacity(0.18), in: Capsule())
                            .foregroundStyle(course.color)
                        }
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                progressBarView(progressInfo: entry.progress, color: entry.targetCourse?.color ?? .blue)
                    .padding(.vertical, 2)

                Divider()

                Text("今日教室速查表")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)

                if entry.todayCourses.isEmpty {
                    emptyWidgetContent
                } else {
                    VStack(spacing: 6) {
                        ForEach(entry.todayCourses.prefix(4)) { c in
                            HStack(spacing: 8) {
                                if settings.showPeriodTime {
                                    Text(c.timeRangeString)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .frame(width: 82, alignment: .leading)
                                        .foregroundStyle(.primary)
                                }

                                Text(c.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Spacer()

                                if settings.showClassroom && !c.classroom.isEmpty {
                                    Text(c.classroom)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(c.color)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(c.color.opacity(0.12), in: Capsule())
                                }
                            }
                            .padding(.vertical, 1.5)
                        }
                    }
                }

            case .dailyTimeline:
                HStack {
                    Text("今日全日程進度")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("共 \(entry.todayCourses.count) 堂課")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                progressBarView(progressInfo: entry.progress, color: entry.targetCourse?.color ?? .blue)
                    .padding(.vertical, 2)

                Divider()

                if entry.todayCourses.isEmpty {
                    emptyWidgetContent
                } else {
                    VStack(spacing: 6) {
                        ForEach(entry.todayCourses.prefix(5)) { c in
                            HStack(spacing: 8) {
                                if settings.showPeriodTime {
                                    Text(c.timeRangeString)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .frame(width: 82, alignment: .leading)
                                        .foregroundStyle(.primary)
                                }

                                Text(c.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Spacer()

                                if settings.showTeacher && !c.teacher.isEmpty {
                                    Text(c.teacher)
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)
                                }

                                if settings.showCredits && !c.credits.isEmpty {
                                    Text(c.credits)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary.opacity(0.8))
                                }

                                if settings.showClassroom && !c.classroom.isEmpty {
                                    Text(c.classroom)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(c.color)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1.5)
                                        .background(c.color.opacity(0.12), in: Capsule())
                                }
                            }
                            .padding(.vertical, 1)
                        }
                    }
                }

            case .countdown:
                VStack(alignment: .leading, spacing: 4) {
                    if let next = entry.nextCourse {
                        HStack(spacing: 12) {
                            Text("\(next.minutesUntil)")
                                .font(.system(size: 44, weight: .black, design: .rounded))
                                .foregroundStyle(.orange)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("分鐘後開始下一堂課")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)
                                Text(next.course.name)
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundStyle(.primary)
                            }
                        }
                    } else if let cur = entry.currentCourse {
                        Text("課堂進行中")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.green)
                        Text(cur.name)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                    } else {
                        Text("今日課程已全數完成")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                progressBarView(progressInfo: entry.progress, color: entry.targetCourse?.color ?? .blue)
                    .padding(.vertical, 2)

                Divider()

                Text("後續待辦課程")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)

                if entry.todayCourses.isEmpty {
                    emptyWidgetContent
                } else {
                    VStack(spacing: 6) {
                        ForEach(entry.todayCourses.prefix(4)) { c in
                            HStack(spacing: 8) {
                                if settings.showPeriodTime {
                                    Text(c.timeRangeString)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(.primary)
                                }

                                Text(c.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Spacer()

                                if settings.showClassroom && !c.classroom.isEmpty {
                                    Text(c.classroom)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(c.color)
                                }
                            }
                            .padding(.vertical, 1)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
    }

    // MARK: - 4. 鎖定畫面小工具 (Accessory)

    @ViewBuilder
    private var accessoryRectangularView: some View {
        let settings = entry.settings
        let isTodayEmpty = entry.todayCourses.isEmpty
        let isTodayFinished = !entry.todayCourses.isEmpty && entry.currentCourse == nil && entry.nextCourse == nil

        if isTodayFinished {
            VStack(alignment: .leading, spacing: 2) {
                Text("當日課程已全部結束")
                    .font(.system(size: 12.5, weight: .black, design: .rounded))
                Text("今日所有課程已完成！")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
        } else if isTodayEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text("今日無排課")
                    .font(.system(size: 12.5, weight: .black, design: .rounded))
                Text("享受美好自由時光")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
        } else if let course = entry.targetCourse {
            VStack(alignment: .leading, spacing: 2.5) {
                Text(course.name)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .lineLimit(1)

                HStack(spacing: 5) {
                    if settings.showClassroom && !course.classroom.isEmpty {
                        Text(course.classroom)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                    }

                    if settings.showPeriodTime {
                        if settings.showClassroom && !course.classroom.isEmpty {
                            Text("•")
                                .font(.system(size: 9, weight: .black))
                        }

                        Text(course.timeRangeString)
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                }
            }
        } else {
            Text("今日無課")
                .font(.system(size: 12, weight: .bold))
        }
    }

    @ViewBuilder
    private var accessoryInlineView: some View {
        if let course = entry.targetCourse {
            Text("\(course.name) \(course.classroom.isEmpty ? "" : "· " + course.classroom)")
        } else {
            Text("今日無課")
        }
    }

    // MARK: - 輔助視圖

    private func progressBarView(progressInfo: DayProgressInfo, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text("今日進度")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(progressInfo.percentage)%")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
            }

            GeometryReader { barGeo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 5)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.75)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(barGeo.size.width * CGFloat(progressInfo.progress), progressInfo.progress > 0 ? 5 : 0), height: 5)
                }
            }
            .frame(height: 5)
        }
    }

    private var emptyWidgetContent: some View {
        VStack(spacing: 6) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
            Text("今日無課表安排")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)
            if entry.settings.showInspirationalQuote {
                Text("享受美好的自由時光吧！")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func widgetBackground(for course: Course?, theme: WidgetTheme) -> some View {
        switch theme {
        case .systemBlur:
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.35),
                        Color.white.opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case .courseColor:
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [
                        (course?.color ?? .blue).opacity(0.35),
                        (course?.color ?? .blue).opacity(0.12),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case .darkOLED:
            Color.black
        case .softGradient:
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.20),
                        Color.purple.opacity(0.14),
                        Color.pink.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}
