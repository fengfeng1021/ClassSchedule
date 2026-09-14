import SwiftUI

/// 全周网格课表主视图：采用双层绝对几何投影模型，确保方方正正、严丝合缝、永不形变
public struct ScheduleGridView: View {
    @ObservedObject var store: CourseStore

    @State private var currentDate = Date()
    @State private var courseToEdit: Course?
    @State private var showingAddSheet = false
    @State private var showingSettingsSheet = false

    // 每 15 秒更新一次当前时刻与状态指示
    private let timer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    private let timeColumnWidth: CGFloat = 46.0

    public init(store: CourseStore) {
        self.store = store
    }

    private var settings: ScheduleSettings {
        store.settings
    }

    private var visibleDays: [Int] {
        settings.visibleDays
    }

    private var currentWeekday: Int {
        store.normalizedDayOfWeek(from: currentDate)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: 1. 顶部当前/下一节教室速查胶囊
                classroomBanner
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                // MARK: 2. 星期标头行 (固定在顶部不随纵向滚动)
                weekdayHeaderRow
                    .background(Color(uiColor: .secondarySystemGroupedBackground))

                Divider()

                // MARK: 3. 核心双层严谨几何时间网格
                GeometryReader { geometry in
                    let availableWidth = geometry.size.width
                    let columnWidth = max((availableWidth - timeColumnWidth) / CGFloat(visibleDays.count), 42.0)
                    let totalHeight = CGFloat(settings.totalHours) * settings.hourHeight

                    ScrollView(.vertical, showsIndicators: true) {
                        ZStack(alignment: .topLeading) {
                            // 层 1：背景固定刻度网格 (绝对方正几何线，不受任何内容挤压)
                            backgroundGridLayer(columnWidth: columnWidth, totalHeight: totalHeight)

                            // 层 2：当前时刻红色时间线
                            if visibleDays.contains(currentWeekday) {
                                currentTimeIndicatorLayer(columnWidth: columnWidth)
                            }

                            // 层 3：顶层课程卡片 (根据开始分钟与持续分钟精确绝对定位)
                            courseCardsLayer(columnWidth: columnWidth)
                        }
                        .frame(width: availableWidth, height: totalHeight)
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("课表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Text(currentDate, format: .dateTime.month().day())
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(Course.dayName(for: currentWeekday))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showingSettingsSheet = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16, weight: .medium))
                        }

                        Button {
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                CourseEditSheet(store: store)
            }
            .sheet(item: $courseToEdit) { course in
                CourseEditSheet(store: store, courseToEdit: course)
            }
            .sheet(isPresented: $showingSettingsSheet) {
                ScheduleSettingsSheet(store: store)
            }
            .onReceive(timer) { input in
                currentDate = input
            }
        }
    }

    // MARK: - 1. 顶部教室速查横幅

    @ViewBuilder
    private var classroomBanner: some View {
        let current = store.currentCourse(at: currentDate)
        let next = store.nextCourse(at: currentDate)

        if let current = current {
            // 正在上课
            Button {
                courseToEdit = current
            } label: {
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("上课中")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.green.opacity(0.12), in: Capsule())

                    Text("当前教室:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(current.classroom)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("(\(current.name))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(current.color.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

        } else if let next = next {
            // 下一节即将开始
            Button {
                courseToEdit = next.course
            } label: {
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.caption2)
                        Text(next.minutesUntil <= 30 ? "\(next.minutesUntil)分钟后" : "下一节")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(next.course.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(next.course.color.opacity(0.12), in: Capsule())

                    Text("前往教室:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(next.course.classroom)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("(\(next.course.startTime.formatted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
                )
            }
            .buttonStyle(.plain)

        } else {
            // 今日课程结束或无课
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.teal)
                Text(store.todayCourses(at: currentDate).isEmpty ? "今日无课程安排" : "今日课程已全部结束，尽享自由时光")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.6))
            )
        }
    }

    // MARK: - 2. 星期标头行

    private var weekdayHeaderRow: some View {
        HStack(spacing: 0) {
            // 左上角留白，对齐左侧时间列
            Text("")
                .frame(width: timeColumnWidth, height: 36)

            // 各星期列标头
            ForEach(visibleDays, id: \.self) { day in
                let isToday = (day == currentWeekday)
                VStack(spacing: 2) {
                    Text(Course.dayName(for: day))
                        .font(.system(size: 13, weight: isToday ? .bold : .medium))
                        .foregroundStyle(isToday ? .blue : .primary)

                    if isToday {
                        Circle()
                            .fill(.blue)
                            .frame(width: 4, height: 4)
                    } else {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 36)
                .background(
                    isToday ?
                    Color.blue.opacity(0.08) :
                    Color.clear
                )
            }
        }
    }

    // MARK: - 3. 层 1：背景固定刻度网格 (绝对几何尺寸，永不被挤压)

    private func backgroundGridLayer(columnWidth: CGFloat, totalHeight: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // 横向整点分割线与时间文本
            ForEach(settings.startHour...settings.endHour, id: \.self) { hour in
                let y = CGFloat(hour - settings.startHour) * settings.hourHeight

                // 时间文本
                Text(String(format: "%02d:00", hour))
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .frame(width: timeColumnWidth - 4, alignment: .trailing)
                    .position(x: (timeColumnWidth - 4) / 2, y: y)

                // 整点横向刻度线 (贯穿整个课表)
                Path { path in
                    path.move(to: CGPoint(x: timeColumnWidth, y: y))
                    path.addLine(to: CGPoint(x: timeColumnWidth + columnWidth * CGFloat(visibleDays.count), y: y))
                }
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)

                // 半点虚线辅助参考 (如果不是最后一行)
                if hour < settings.endHour {
                    let halfY = y + (settings.hourHeight / 2)
                    Path { path in
                        path.move(to: CGPoint(x: timeColumnWidth + 6, y: halfY))
                        path.addLine(to: CGPoint(x: timeColumnWidth + columnWidth * CGFloat(visibleDays.count), y: halfY))
                    }
                    .stroke(Color.primary.opacity(0.04), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                }
            }

            // 纵向星期分割线
            ForEach(0...visibleDays.count, id: \.self) { index in
                let x = timeColumnWidth + CGFloat(index) * columnWidth
                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: totalHeight))
                }
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
            }
        }
    }

    // MARK: - 4. 层 2：当前时刻红色时间线

    private func currentTimeIndicatorLayer(columnWidth: CGFloat) -> some View {
        guard let todayIndex = visibleDays.firstIndex(of: currentWeekday) else {
            return AnyView(EmptyView())
        }

        let now = TimeOfDay(date: currentDate)
        let totalMinutes = now.totalMinutes
        let startMinutes = settings.startHour * 60
        let endMinutes = settings.endHour * 60

        // 仅在当前时间轴跨度内绘制
        guard totalMinutes >= startMinutes && totalMinutes <= endMinutes else {
            return AnyView(EmptyView())
        }

        let y = CGFloat(totalMinutes - startMinutes) * (settings.hourHeight / 60.0)
        let startX = timeColumnWidth + CGFloat(todayIndex) * columnWidth
        let endX = startX + columnWidth

        return AnyView(
            ZStack(alignment: .leading) {
                // 红点
                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
                    .position(x: startX + 3, y: y)

                // 红线
                Path { path in
                    path.move(to: CGPoint(x: startX, y: y))
                    path.addLine(to: CGPoint(x: endX, y: y))
                }
                .stroke(Color.red, lineWidth: 1.5)
            }
        )
    }

    // MARK: - 5. 层 3：顶层课程卡片 (绝对投影，精确到每一分钟)

    private func courseCardsLayer(columnWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(store.courses) { course in
                if let dayIndex = visibleDays.firstIndex(of: course.dayOfWeek) {
                    let startMinutes = course.startTime.totalMinutes
                    let endMinutes = course.endTime.totalMinutes
                    let axisStartMinutes = settings.startHour * 60

                    // 计算 Y 轴偏移与卡片高度
                    let yOffset = CGFloat(startMinutes - axisStartMinutes) * (settings.hourHeight / 60.0)
                    let durationMinutes = max(endMinutes - startMinutes, 20)
                    let cardHeight = max(CGFloat(durationMinutes) * (settings.hourHeight / 60.0) - 2.0, 26.0)
                    let cardWidth = columnWidth - 4.0
                    let xOffset = timeColumnWidth + CGFloat(dayIndex) * columnWidth + 2.0

                    // 仅当课程在可见时间轴范围内时渲染
                    if yOffset + cardHeight >= 0 && yOffset <= CGFloat(settings.totalHours) * settings.hourHeight {
                        CourseGridCard(
                            course: course,
                            width: cardWidth,
                            height: cardHeight,
                            onTap: {
                                courseToEdit = course
                            }
                        )
                        .position(x: xOffset + cardWidth / 2, y: yOffset + cardHeight / 2)
                        .contextMenu {
                            Button {
                                courseToEdit = course
                            } label: {
                                Label("编辑课程", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                store.delete(course)
                            } label: {
                                Label("删除课程", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
}

/// 课程卡片几何组件：紧凑贴合网格，突出课程与教室
struct CourseGridCard: View {
    let course: Course
    let width: CGFloat
    let height: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topLeading) {
                // 卡片纯色微透背景
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(course.color.opacity(0.18))

                // 左侧色彩标尺
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(course.color)
                    .frame(width: 3.5)

                // 核心文本内容
                VStack(alignment: .leading, spacing: 2) {
                    // 课程名称
                    Text(course.name)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(height > 46 ? 2 : 1)
                        .fixedSize(horizontal: false, vertical: true)

                    // 上课教室 (核心醒目标注)
                    HStack(spacing: 2) {
                        Image(systemName: "mappin")
                            .font(.system(size: 8, weight: .bold))
                        Text(course.classroom)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(course.color)
                    .lineLimit(1)

                    // 若卡片高度充裕，显示教师或时间
                    if height >= 60 && !course.teacher.isEmpty {
                        Text(course.teacher)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if height >= 80 {
                        Text(course.timeRangeString)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 7)
                .padding(.trailing, 3)
                .padding(.vertical, 3)
            }
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(course.color.opacity(0.55), lineWidth: 0.9)
            )
            .clipped()
        }
        .buttonStyle(.plain)
    }
}
