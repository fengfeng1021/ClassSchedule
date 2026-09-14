import SwiftUI

/// 桌面小工具（WidgetKit）偏好設定與即時 Live 預覽中心
public struct WidgetSettingsView: View {
    @ObservedObject var store: CourseStore
    @State private var previewSize: WidgetPreviewSize = .medium
    @State private var mockDate = Date()

    // 每分鐘輕量更新一次，使進度條真實跳動
    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    public init(store: CourseStore) {
        self.store = store
    }

    private var settings: WidgetSettings {
        get { store.settings.widgetSettings }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: 1. 即時桌面小工具 Live 預覽區塊
                widgetLivePreviewSection
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                // MARK: 2. 顯示模式切換
                displayModeSection
                    .padding(.horizontal, 16)

                // MARK: 3. 外觀主題配色
                themeSection
                    .padding(.horizontal, 16)

                // MARK: 4. 顯示項目開關組
                contentOptionsSection
                    .padding(.horizontal, 16)

                // MARK: 5. 桌面小工具安裝指南
                tutorialSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .onReceive(minuteTimer) { input in
            mockDate = input
        }
    }

    // MARK: - 1. 即時桌面小工具 Live 預覽區塊

    private var widgetLivePreviewSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("桌面效果即時預覽")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("即時渲染")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.12), in: Capsule())
            }

            // 預覽尺寸選擇器
            Picker("小工具尺寸", selection: $previewSize) {
                ForEach(WidgetPreviewSize.allCases) { size in
                    Text(size.rawValue).tag(size)
                }
            }
            .pickerStyle(.segmented)

            // 小工具預覽畫布卡片
            ZStack {
                // 模擬 iOS 桌面生動微光背景 (讓液態毛玻璃效果在真機上完美折射顯現)
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.18, green: 0.28, blue: 0.44),
                                Color(red: 0.12, green: 0.16, blue: 0.28),
                                Color(red: 0.22, green: 0.18, blue: 0.32)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.25),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )

                // 實際渲染的小工具模型
                widgetCardRenderer
                    .padding(18)
            }
            .frame(minHeight: previewCanvasHeight)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )

    }

    private var previewCanvasHeight: CGFloat {
        switch previewSize {
        case .small: return 200
        case .medium: return 210
        case .large: return 360
        case .accessory: return 110
        }
    }

    // MARK: - 小工具動態渲染器

    @ViewBuilder
    private var widgetCardRenderer: some View {
        let current = store.currentCourse(at: mockDate)
        let next = store.nextCourse(at: mockDate)
        let todayList = store.todayCourses(at: mockDate)
        let progress = store.todayProgress(at: mockDate)

        let targetCourse: Course? = current ?? next?.course ?? todayList.first ?? store.courses.first

        switch previewSize {
        case .small:
            smallWidgetView(targetCourse: targetCourse, current: current, next: next, todayList: todayList)
                .frame(width: 155, height: 155)
                .background(widgetBackground(for: targetCourse))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)

        case .medium:
            mediumWidgetView(targetCourse: targetCourse, current: current, next: next, todayList: todayList, progress: progress)
                .frame(maxWidth: 340, minHeight: 155, maxHeight: 155)
                .background(widgetBackground(for: targetCourse))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)

        case .large:
            largeWidgetView(targetCourse: targetCourse, current: current, next: next, todayList: todayList, progress: progress)
                .frame(maxWidth: 340, minHeight: 310, maxHeight: 310)
                .background(widgetBackground(for: targetCourse))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 5)

        case .accessory:
            let isTodayEmpty = todayList.isEmpty
            let isTodayFinished = !todayList.isEmpty && current == nil && next == nil
            accessoryWidgetView(targetCourse: targetCourse, isCurrent: current != nil, isTodayFinished: isTodayFinished, isTodayEmpty: isTodayEmpty)
                .frame(width: 160, height: 60)
                .background(Color.black.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - 小型小工具 (2x2) — 3 種模式真實不同顯示效果

    @ViewBuilder
    private func smallWidgetView(targetCourse: Course?, current: Course?, next: (course: Course, minutesUntil: Int)?, todayList: [Course]) -> some View {
        if let course = targetCourse {
            switch settings.displayMode {
            case .classroomFocus:
                // 模式 1：教室速查（強調特大教室地點標籤與換堂導航）
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        let isCurrent = current != nil
                        let statusColor = isCurrent ? Color.green : course.color
                        HStack(spacing: 3) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 6, height: 6)
                            Text(isCurrent ? "上課中" : (next != nil ? "\(next!.minutesUntil)分後" : "下一節"))
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

                    // 醒目教室
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
                // 模式 2：今日日程（條列今日課程清單）
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("今日日程")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("共\(todayList.count)堂")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    if todayList.isEmpty {
                        emptyWidgetContent
                    } else {
                        VStack(spacing: 5) {
                            ForEach(todayList.prefix(2)) { c in
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
                // 模式 3：簡約倒數（極簡大字倒數時間）
                VStack(spacing: 4) {
                    Spacer()
                    if current != nil {
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
                    } else if let next = next {
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
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding(10)
            }
        } else {
            emptyWidgetContent
        }
    }

    // MARK: - 中型小工具 (2x4) — 3 種模式真實不同 + 分鐘進度條

    @ViewBuilder
    private func mediumWidgetView(
        targetCourse: Course?,
        current: Course?,
        next: (course: Course, minutesUntil: Int)?,
        todayList: [Course],
        progress: DayProgressInfo
    ) -> some View {
        if let course = targetCourse {
            switch settings.displayMode {
            case .classroomFocus:
                // 模式 1：教室速查（左右二分焦點）
                HStack(spacing: 12) {
                    // 左側：教室核心焦點
                    VStack(alignment: .leading, spacing: 4) {
                        let isCurrent = current != nil
                        let statusColor = isCurrent ? Color.green : course.color
                        HStack(spacing: 4) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 7, height: 7)
                            Text(isCurrent ? "目前進行中" : (next != nil ? "下一節" : "本日排課"))
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

                    // 右側：課程詳情與今日進度條
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

                        // 今日課程時間百分比進度條（以分更新）
                        progressBarView(progressInfo: progress, color: course.color)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)

            case .dailyTimeline:
                // 模式 2：今日日程清單 + 進度條
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("今日課程清單")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("共 \(todayList.count) 堂課")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    if todayList.isEmpty {
                        emptyWidgetContent
                    } else {
                        VStack(spacing: 5) {
                            ForEach(todayList.prefix(2)) { c in
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

                    // 今日課程時間百分比進度條
                    progressBarView(progressInfo: progress, color: targetCourse?.color ?? .blue)
                }
                .padding(12)

            case .countdown:
                // 模式 3：簡約倒數儀表板 + 進度條
                HStack(spacing: 14) {
                    // 左側：倒數大數字
                    VStack(alignment: .leading, spacing: 2) {
                        if current != nil {
                            Text("上課中")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(.green)
                            Text("進行中")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundStyle(.green)
                        } else if let next = next {
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

                    // 右側：課堂概覽與進度條
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

                        progressBarView(progressInfo: progress, color: targetCourse?.color ?? .blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
            }
        } else {
            emptyWidgetContent
        }
    }

    // MARK: - 大型小工具 (4x4) — 3 種模式真實不同 + 分鐘進度條

    @ViewBuilder
    private func largeWidgetView(
        targetCourse: Course?,
        current: Course?,
        next: (course: Course, minutesUntil: Int)?,
        todayList: [Course],
        progress: DayProgressInfo
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch settings.displayMode {
            case .classroomFocus:
                // 模式 1：教室速查全天大卡
                if let course = targetCourse {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(current != nil ? "● 進行中課程" : "▶ 下一節預告")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(current != nil ? Color.green : course.color)

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

                // 今日進度條
                progressBarView(progressInfo: progress, color: targetCourse?.color ?? .blue)
                    .padding(.vertical, 2)

                Divider()

                Text("今日教室速查表")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)

                if todayList.isEmpty {
                    emptyWidgetContent
                } else {
                    VStack(spacing: 6) {
                        ForEach(todayList.prefix(4)) { c in
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
                // 模式 2：今日全日程時間軸
                HStack {
                    Text("今日全日程進度")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("共 \(todayList.count) 堂課")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                progressBarView(progressInfo: progress, color: targetCourse?.color ?? .blue)
                    .padding(.vertical, 2)

                Divider()

                if todayList.isEmpty {
                    emptyWidgetContent
                } else {
                    VStack(spacing: 6) {
                        ForEach(todayList.prefix(5)) { c in
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
                // 模式 3：簡約倒數大儀表板
                VStack(alignment: .leading, spacing: 4) {
                    if let next = next {
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
                    } else if current != nil {
                        Text("課堂進行中")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.green)
                        Text(current!.name)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                    } else {
                        Text("今日課程已全數完成")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                progressBarView(progressInfo: progress, color: targetCourse?.color ?? .blue)
                    .padding(.vertical, 2)

                Divider()

                Text("後續待辦課程")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)

                if todayList.isEmpty {
                    emptyWidgetContent
                } else {
                    VStack(spacing: 6) {
                        ForEach(todayList.prefix(4)) { c in
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

    // MARK: - 輔助：以分更新的百分比進度條

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

    // 鎖定畫面小組件 (無多餘圖示、顯示完整時間範圍、支援全天結束樣式)
    @ViewBuilder
    private func accessoryWidgetView(targetCourse: Course?, isCurrent: Bool, isTodayFinished: Bool, isTodayEmpty: Bool) -> some View {
        if isTodayFinished {
            VStack(alignment: .leading, spacing: 2) {
                Text("當日課程已全部結束")
                    .font(.system(size: 12.5, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("今日所有課程已完成！")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 10)
        } else if isTodayEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text("今日無排課")
                    .font(.system(size: 12.5, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("享受美好自由時光")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 10)
        } else if let course = targetCourse {
            VStack(alignment: .leading, spacing: 2.5) {
                Text(course.name)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    if settings.showClassroom && !course.classroom.isEmpty {
                        Text(course.classroom)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(.yellow)
                    }

                    if settings.showPeriodTime {
                        if settings.showClassroom && !course.classroom.isEmpty {
                            Text("•")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        Text(course.timeRangeString)
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.92))
                    }
                }
            }
            .padding(.horizontal, 10)
        } else {
            Text("今日無課")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    // 無課時提示
    private var emptyWidgetContent: some View {
        VStack(spacing: 6) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
            Text("今日無課表安排")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)
            if settings.showInspirationalQuote {
                Text("享受美好的自由時光吧！")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // 小工具背景外觀處理 (支援 Apple 原生液態毛玻璃材質)
    @ViewBuilder
    private func widgetBackground(for course: Course?) -> some View {
        switch settings.theme {
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

    // MARK: - 2. 顯示模式切換區塊

    private var displayModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("小工具顯示模式")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(WidgetDisplayMode.allCases) { mode in
                    Button {
                        var updated = settings
                        updated.displayMode = mode
                        store.updateWidgetSettings(updated)
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.rawValue)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.primary)

                                Text(mode.description)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if settings.displayMode == mode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                                    .font(.system(size: 18))
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(settings.displayMode == mode ? Color.blue.opacity(0.08) : Color(uiColor: .secondarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(settings.displayMode == mode ? Color.blue.opacity(0.35) : Color.primary.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 3. 外觀主題配色

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("小工具外觀主題")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(WidgetTheme.allCases) { theme in
                    Button {
                        var updated = settings
                        updated.theme = theme
                        store.updateWidgetSettings(updated)
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(themeColorPreview(theme))
                                .frame(width: 14, height: 14)

                            Text(theme.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)

                            Spacer()

                            if settings.theme == theme {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(settings.theme == theme ? Color.blue.opacity(0.08) : Color(uiColor: .secondarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(settings.theme == theme ? Color.blue.opacity(0.35) : Color.primary.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func themeColorPreview(_ theme: WidgetTheme) -> Color {
        switch theme {
        case .systemBlur: return .gray
        case .courseColor: return .blue
        case .darkOLED: return .black
        case .softGradient: return .purple
        }
    }

    // MARK: - 4. 顯示項目與提醒開關組 (Inset Grouped)

    private var contentOptionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("小工具顯示內容")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)

            // 課程與教室資訊開關
            VStack(spacing: 0) {
                Toggle(isOn: Binding(
                    get: { settings.showClassroom },
                    set: { val in
                        var updated = settings
                        updated.showClassroom = val
                        store.updateWidgetSettings(updated)
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                )) {
                    Text("顯示教室位置")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                Divider().padding(.leading, 14)

                Toggle(isOn: Binding(
                    get: { settings.highlightClassroom },
                    set: { val in
                        var updated = settings
                        updated.highlightClassroom = val
                        store.updateWidgetSettings(updated)
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                )) {
                    Text("教室代號特大加粗 (例如: M008)")
                }
                .disabled(!settings.showClassroom)
                .opacity(settings.showClassroom ? 1.0 : 0.45)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                Divider().padding(.leading, 14)

                Toggle(isOn: Binding(
                    get: { settings.showTeacher },
                    set: { val in
                        var updated = settings
                        updated.showTeacher = val
                        store.updateWidgetSettings(updated)
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                )) {
                    Text("顯示授課教師姓名")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                Divider().padding(.leading, 14)

                Toggle(isOn: Binding(
                    get: { settings.showPeriodTime },
                    set: { val in
                        var updated = settings
                        updated.showPeriodTime = val
                        store.updateWidgetSettings(updated)
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                )) {
                    Text("顯示上課節次與時段")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                Divider().padding(.leading, 14)

                Toggle(isOn: Binding(
                    get: { settings.showCredits },
                    set: { val in
                        var updated = settings
                        updated.showCredits = val
                        store.updateWidgetSettings(updated)
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                )) {
                    Text("顯示學分數")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )

            // 提醒與提示卡片
            VStack(spacing: 0) {
                HStack {
                    Text("上課倒數提醒門檻")
                    Spacer()
                    Picker("倒數提醒門檻", selection: Binding(
                        get: { settings.upcomingReminderMinutes },
                        set: { val in
                            var updated = settings
                            updated.upcomingReminderMinutes = val
                            store.updateWidgetSettings(updated)
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                    )) {
                        Text("15 分鐘前").tag(15)
                        Text("30 分鐘前").tag(30)
                        Text("45 分鐘前").tag(45)
                        Text("60 分鐘前").tag(60)
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Divider().padding(.leading, 14)

                Toggle(isOn: Binding(
                    get: { settings.showInspirationalQuote },
                    set: { val in
                        var updated = settings
                        updated.showInspirationalQuote = val
                        store.updateWidgetSettings(updated)
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                )) {
                    Text("無課時顯示貼心提示語")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
    }

    // MARK: - 5. 桌面小工具加入指南

    private var tutorialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("如何將小工具加入桌面？")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                stepRow(number: "1", title: "長按主畫面空白處", detail: "長按桌面背景直到所有 App 圖示開始晃動。")
                stepRow(number: "2", title: "點擊左上角的「+」號", detail: "打開 iOS 小組件庫選單。")
                stepRow(number: "3", title: "搜尋「課表」或尋找本 App", detail: "在列表中選取課表小工具。")
                stepRow(number: "4", title: "選擇尺寸並點選「加入小工具」", detail: "挑選小型、中型或大型小工具放置於主畫面。")
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
    }

    private func stepRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.blue))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
