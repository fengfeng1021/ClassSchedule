import SwiftUI

/// 桌面小工具（WidgetKit）偏好設定與即時 Live 預覽中心
public struct WidgetSettingsView: View {
    @ObservedObject var store: CourseStore
    @State private var previewSize: WidgetPreviewSize = .medium
    @State private var mockDate = Date()

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

                // MARK: 2. 一鍵情境預設卡片 (操作極簡升級)
                quickPresetsSection
                    .padding(.horizontal, 16)

                // MARK: 3. 顯示模式切換
                displayModeSection
                    .padding(.horizontal, 16)

                // MARK: 4. 外觀主題配色
                themeSection
                    .padding(.horizontal, 16)

                // MARK: 5. 顯示項目開關組
                contentOptionsSection
                    .padding(.horizontal, 16)

                // MARK: 6. 桌面小工具安裝指南
                tutorialSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - 1. 即時桌面小工具 Live 預覽區塊

    private var widgetLivePreviewSection: some View {
        VStack(spacing: 14) {
            HStack {
                Label("桌面效果即時預覽", systemImage: "sparkles")
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
                // 模擬 iOS 桌面壁紙微背景
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(uiColor: .secondarySystemGroupedBackground),
                                Color(uiColor: .tertiarySystemGroupedBackground)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
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

        let targetCourse: Course? = current ?? next?.course ?? todayList.first ?? store.courses.first

        switch previewSize {
        case .small:
            smallWidgetView(targetCourse: targetCourse, isCurrent: current != nil, minutesUntil: next?.minutesUntil)
                .frame(width: 155, height: 155)
                .background(widgetBackground(for: targetCourse))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)

        case .medium:
            mediumWidgetView(targetCourse: targetCourse, current: current, next: next, todayList: todayList)
                .frame(maxWidth: 340, minHeight: 155, maxHeight: 155)
                .background(widgetBackground(for: targetCourse))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)

        case .large:
            largeWidgetView(targetCourse: targetCourse, current: current, next: next, todayList: todayList)
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

    // 小型小工具 (2x2)
    @ViewBuilder
    private func smallWidgetView(targetCourse: Course?, isCurrent: Bool, minutesUntil: Int?) -> some View {
        if let course = targetCourse {
            VStack(alignment: .leading, spacing: 6) {
                // 狀態標籤
                let countdownText: String = {
                    if isCurrent { return "上課中" }
                    if let m = minutesUntil { return "\(m)分後" }
                    return "即將開始"
                }()

                HStack {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(isCurrent ? Color.green : course.color)
                            .frame(width: 6, height: 6)
                        Text(countdownText)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isCurrent ? Color.green : course.color)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((isCurrent ? Color.green : course.color).opacity(0.14), in: Capsule())

                    Spacer()

                    if settings.showPeriodTime {
                        Text(course.timeRangeString)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // 核心：特大醒目教室
                if settings.showClassroom && !course.classroom.isEmpty {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("教室地點")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 3) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 11))
                            Text(course.classroom)
                                .font(.system(size: settings.highlightClassroom ? 24 : 19, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(course.color)
                    }
                }

                // 課程名稱
                Text(course.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                // 教師與學分
                if settings.showTeacher && !course.teacher.isEmpty {
                    Text(course.teacher)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
        } else {
            emptyWidgetContent
        }
    }

    // 中型小工具 (2x4)
    @ViewBuilder
    private func mediumWidgetView(targetCourse: Course?, current: Course?, next: (course: Course, minutesUntil: Int)?, todayList: [Course]) -> some View {
        if settings.displayMode == .dailyTimeline {
            // 今日日程時間線模式
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("今日課程清單", systemImage: "calendar")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("共 \(todayList.count) 堂課")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Divider()

                if todayList.isEmpty {
                    emptyWidgetContent
                } else {
                    VStack(spacing: 5) {
                        ForEach(todayList.prefix(3)) { c in
                            HStack(spacing: 6) {
                                Text(c.timeRangeString)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .frame(width: 82, alignment: .leading)
                                    .foregroundStyle(.primary)

                                Text(c.name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Spacer()

                                if settings.showClassroom && !c.classroom.isEmpty {
                                    HStack(spacing: 2) {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 7))
                                        Text(c.classroom)
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                    }
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
            }
            .padding(12)

        } else {
            // 教室速查與倒數模式
            if let course = targetCourse {
                HStack(spacing: 12) {
                    // 左側：教室特大焦點
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(current != nil ? Color.green : course.color)
                                .frame(width: 7, height: 7)
                            Text(current != nil ? "目前進行中" : "下一節課")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(current != nil ? Color.green : course.color)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background((current != nil ? Color.green : course.color).opacity(0.12), in: Capsule())

                        Spacer()

                        Text("上課教室")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)

                        Text(course.classroom.isEmpty ? "未設定" : course.classroom)
                            .font(.system(size: settings.highlightClassroom ? 32 : 26, weight: .black, design: .rounded))
                            .foregroundStyle(course.color)
                            .lineLimit(1)

                        if let next = next {
                            Text("倒數 \(next.minutesUntil) 分鐘上課")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(.orange)
                        } else {
                            Text(course.timeRangeString)
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    // 右側：課程詳情
                    VStack(alignment: .leading, spacing: 6) {
                        Text(course.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        if settings.showTeacher && !course.teacher.isEmpty {
                            Label(course.teacher, systemImage: "person.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        if settings.showCredits && !course.credits.isEmpty {
                            Label(course.credits, systemImage: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary.opacity(0.9))
                        }

                        Spacer()

                        HStack(spacing: 5) {
                            Text(course.periodSpanString)
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            Text("·")
                                .font(.system(size: 9, weight: .black))
                            Text(course.timeRangeString)
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
            } else {
                emptyWidgetContent
            }
        }
    }

    // 大型小工具 (4x4)
    @ViewBuilder
    private func largeWidgetView(targetCourse: Course?, current: Course?, next: (course: Course, minutesUntil: Int)?, todayList: [Course]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 頂部當前焦點橫幅
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
                                .font(.system(size: 9))
                            Text(course.classroom)
                                .font(.system(size: 16, weight: .black, design: .rounded))
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

            Divider()

            // 課表清單列表
            Text("今日課程進度表")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)

            if todayList.isEmpty {
                emptyWidgetContent
            } else {
                VStack(spacing: 6) {
                    ForEach(todayList.prefix(5)) { c in
                        HStack(spacing: 8) {
                            Text(c.timeRangeString)
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .frame(width: 86, alignment: .leading)
                                .foregroundStyle(.primary)

                            Text(c.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Spacer()

                            Text(c.classroom)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(c.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(c.color.opacity(0.12), in: Capsule())
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
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
                // 課程名稱 (無多餘圖示，大字清晰)
                Text(course.name)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                // 醒目教室代碼與完整時間範圍 (大字加粗)
                HStack(spacing: 5) {
                    Text(course.classroom)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.yellow)

                    Text("•")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white.opacity(0.6))

                    Text(course.timeRangeString)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.92))
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

    // 小工具背景外觀處理
    @ViewBuilder
    private func widgetBackground(for course: Course?) -> some View {
        switch settings.theme {
        case .systemBlur:
            Color(uiColor: .systemBackground)
        case .courseColor:
            LinearGradient(
                colors: [
                    (course?.color ?? .blue).opacity(0.22),
                    (course?.color ?? .blue).opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .background(Color(uiColor: .systemBackground))
        case .darkOLED:
            Color.black
        case .softGradient:
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.15),
                    Color.purple.opacity(0.12),
                    Color.pink.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .background(Color(uiColor: .systemBackground))
        }
    }

    // MARK: - 2. 一鍵情境預設卡片 (操作極簡升級)

    private var quickPresetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("一鍵情境預設", systemImage: "wand.and.stars")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    applyDefaultSettings()
                } label: {
                    Text("恢復預設")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    presetCard(
                        title: "趕堂換教室",
                        subtitle: "特大教室代號 · 30分提醒",
                        icon: "mappin.and.ellipse",
                        color: .orange,
                        isActive: settings.displayMode == .classroomFocus && settings.highlightClassroom
                    ) {
                        applyPreset(.classroomFocus, theme: .softGradient, highlight: true, teacher: false, time: true, reminder: 30)
                    }

                    presetCard(
                        title: "全日程管家",
                        subtitle: "完整節次時段 · 課程教師",
                        icon: "list.bullet.rectangle",
                        color: .blue,
                        isActive: settings.displayMode == .dailyTimeline
                    ) {
                        applyPreset(.dailyTimeline, theme: .courseColor, highlight: false, teacher: true, time: true, reminder: 15)
                    }

                    presetCard(
                        title: "極簡專注",
                        subtitle: "純黑極簡 · 簡約倒數",
                        icon: "timer",
                        color: .purple,
                        isActive: settings.displayMode == .countdown && settings.theme == .darkOLED
                    ) {
                        applyPreset(.countdown, theme: .darkOLED, highlight: true, teacher: false, time: false, reminder: 30)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func presetCard(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.18))
                            .frame(width: 32, height: 32)
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(color)
                    }

                    Spacer()

                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.blue)
                    }
                }

                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(width: 150, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? Color.blue.opacity(0.08) : Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isActive ? Color.blue.opacity(0.35) : Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func applyPreset(
        _ mode: WidgetDisplayMode,
        theme: WidgetTheme,
        highlight: Bool,
        teacher: Bool,
        time: Bool,
        reminder: Int
    ) {
        var updated = settings
        updated.displayMode = mode
        updated.theme = theme
        updated.highlightClassroom = highlight
        updated.showTeacher = teacher
        updated.showPeriodTime = time
        updated.upcomingReminderMinutes = reminder
        store.updateWidgetSettings(updated)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func applyDefaultSettings() {
        store.updateWidgetSettings(WidgetSettings())
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - 3. 顯示模式切換區塊

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
                            Image(systemName: mode.iconName)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(settings.displayMode == mode ? .blue : .secondary)
                                .frame(width: 28)

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

    // MARK: - 4. 外觀主題配色

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

    // MARK: - 5. 顯示項目與提醒開關組 (Inset Grouped)

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
                    Label("顯示教室位置", systemImage: "mappin.circle")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                Divider().padding(.leading, 44)

                Toggle(isOn: Binding(
                    get: { settings.highlightClassroom },
                    set: { val in
                        var updated = settings
                        updated.highlightClassroom = val
                        store.updateWidgetSettings(updated)
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                )) {
                    Label("教室代號特大加粗 (例如: M008)", systemImage: "textformat.size.larger")
                }
                .disabled(!settings.showClassroom)
                .opacity(settings.showClassroom ? 1.0 : 0.45)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                Divider().padding(.leading, 44)

                Toggle(isOn: Binding(
                    get: { settings.showTeacher },
                    set: { val in
                        var updated = settings
                        updated.showTeacher = val
                        store.updateWidgetSettings(updated)
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                )) {
                    Label("顯示授課教師姓名", systemImage: "person.text.rectangle")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                Divider().padding(.leading, 44)

                Toggle(isOn: Binding(
                    get: { settings.showPeriodTime },
                    set: { val in
                        var updated = settings
                        updated.showPeriodTime = val
                        store.updateWidgetSettings(updated)
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                )) {
                    Label("顯示上課節次與時段", systemImage: "clock")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                Divider().padding(.leading, 44)

                Toggle(isOn: Binding(
                    get: { settings.showCredits },
                    set: { val in
                        var updated = settings
                        updated.showCredits = val
                        store.updateWidgetSettings(updated)
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                )) {
                    Label("顯示學分數", systemImage: "rosette")
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
                    Label("上課倒數提醒門檻", systemImage: "bell.badge")
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

                Divider().padding(.leading, 44)

                Toggle(isOn: Binding(
                    get: { settings.showInspirationalQuote },
                    set: { val in
                        var updated = settings
                        updated.showInspirationalQuote = val
                        store.updateWidgetSettings(updated)
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                )) {
                    Label("無課時顯示貼心提示語", systemImage: "quote.bubble")
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
            Label("如何將小工具加入桌面？", systemImage: "questionmark.circle.fill")
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
