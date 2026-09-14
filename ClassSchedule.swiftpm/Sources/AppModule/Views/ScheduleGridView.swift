import SwiftUI

/// 全螢幕自適應免滑動課表主視圖：
/// 1. 完全無 ScrollView，在 iPad 與 iPhone 上一屏全覽所有課程，無需滑動。
/// 2. 支援點選空白格設課、課程上下邊框拖曳調整節次跨度（不被滑動搶走手勢）。
/// 3. 右上角獨立「匯入課表」與「新增課程」兩大按鈕。
/// 4. 現代大專院校課表質感，醒目教室膠囊標籤。
public struct ScheduleGridView: View {
    @ObservedObject var store: CourseStore

    @State private var currentDate = Date()
    @State private var courseToEdit: Course?
    @State private var courseToAddDayAndPeriod: (day: Int, periodId: String)?
    @State private var selectedCourseId: UUID?

    @State private var showingSettingsSheet = false
    @State private var showingImportSheet = false
    @State private var showingClearAlert = false

    // 拖曳縮放即時位移
    @State private var draggingBottomCourseId: UUID?
    @State private var dragBottomOffset: CGFloat = 0
    @State private var draggingTopCourseId: UUID?
    @State private var dragTopOffset: CGFloat = 0

    // 每 15 秒輕量更新一次目前時間與狀態
    private let timer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    private let timeColumnWidth: CGFloat = 46.0

    public init(store: CourseStore) {
        self.store = store
    }

    private var settings: ScheduleSettings {
        store.settings
    }

    private var activePeriods: [Period] {
        settings.activePeriods
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
                // MARK: 1. 頂部動態島風格教室速查橫幅
                classroomBanner
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .padding(.bottom, 4)

                // MARK: 2. 星期標頭行 (固定於頂部)
                weekdayHeaderRow
                    .background(Color(uiColor: .secondarySystemGroupedBackground))

                Divider()

                // MARK: 3. 全螢幕自適應免滑動課表矩陣 (Zero ScrollView)
                GeometryReader { geometry in
                    let availableWidth = geometry.size.width
                    let availableHeight = geometry.size.height
                    let columnWidth = (availableWidth - timeColumnWidth) / CGFloat(visibleDays.count)
                    let periodCount = max(activePeriods.count, 1)
                    let cellHeight = availableHeight / CGFloat(periodCount)

                    HStack(alignment: .top, spacing: 0) {
                        // 左側：節次與時間標籤列
                        periodsColumnView(cellHeight: cellHeight)

                        // 右側：各星期課程格子矩陣
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(visibleDays, id: \.self) { day in
                                dayColumnView(day: day, columnWidth: columnWidth, cellHeight: cellHeight)
                            }
                        }
                    }
                    .frame(width: availableWidth, height: availableHeight)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("課表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // MARK: 左上角功能選項選單按鈕
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            showingSettingsSheet = true
                        } label: {
                            Label("課表自訂設定", systemImage: "gearshape")
                        }

                        Button {
                            toggleEveningPeriods()
                        } label: {
                            Label(settings.showEveningPeriods ? "隱藏夜間時段 (10~14節)" : "顯示夜間時段 (10~14節)", systemImage: "moon.stars")
                        }

                        Button {
                            toggleWeekend()
                        } label: {
                            Label(settings.showWeekend ? "隱藏週末 (僅顯示週一至五)" : "顯示週末 (週一至週日)", systemImage: "calendar")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showingClearAlert = true
                        } label: {
                            Label("清空目前課表", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .medium))
                    }
                }

                // MARK: 右上角兩個獨立分開的按鈕：「匯入課表」與「新增課程」
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        // 按鈕一：匯入課表
                        Button {
                            showingImportSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.doc")
                                Text("匯入課表")
                                    .font(.subheadline.weight(.medium))
                            }
                        }

                        // 按鈕二：新增課程
                        Button {
                            courseToAddDayAndPeriod = (day: currentWeekday, periodId: activePeriods.first?.id ?? "1")
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                }
            }
            .sheet(item: Binding<Course?>(
                get: { courseToEdit },
                set: { courseToEdit = $0 }
            )) { course in
                CourseEditSheet(store: store, courseToEdit: course)
            }
            .sheet(isPresented: Binding<Bool>(
                get: { courseToAddDayAndPeriod != nil },
                set: { if !$0 { courseToAddDayAndPeriod = nil } }
            )) {
                if let param = courseToAddDayAndPeriod {
                    CourseEditSheet(store: store, initialDay: param.day, initialPeriodId: param.periodId)
                }
            }
            .sheet(isPresented: $showingSettingsSheet) {
                ScheduleSettingsSheet(store: store)
            }
            .sheet(isPresented: $showingImportSheet) {
                ImportScheduleSheet(store: store)
            }
            .alert("確定要清空課表？", isPresented: $showingClearAlert) {
                Button("取消", role: .cancel) {}
                Button("清空", role: .destructive) {
                    store.courses.removeAll()
                    store.save()
                }
            } message: {
                Text("此動作將移除所有已建立的課程資料。")
            }
            .onReceive(timer) { input in
                currentDate = input
            }
        }
    }

    // MARK: - 1. 頂部教室速查橫幅

    @ViewBuilder
    private var classroomBanner: some View {
        let current = store.currentCourse(at: currentDate)
        let next = store.nextCourse(at: currentDate)

        if let current = current {
            Button {
                courseToEdit = current
            } label: {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 7, height: 7)
                        Text("上課中")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.12), in: Capsule())

                    Text("當前教室:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(current.classroom)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("(\(current.name))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(current.color.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

        } else if let next = next {
            Button {
                courseToEdit = next.course
            } label: {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 9))
                        Text(next.minutesUntil <= 30 ? "\(next.minutesUntil)分後" : "下一節")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(next.course.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(next.course.color.opacity(0.12), in: Capsule())

                    Text("前往教室:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(next.course.classroom)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("(\(next.course.startTime.formatted))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
                )
            }
            .buttonStyle(.plain)

        } else {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(.teal)
                Text(store.todayCourses(at: currentDate).isEmpty ? "今日無排課" : "今日課程已全部結束")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.6))
            )
        }
    }

    // MARK: - 2. 星期標頭行

    private var weekdayHeaderRow: some View {
        HStack(spacing: 0) {
            // 左上角標題
            VStack(spacing: 1) {
                Text("節次")
                    .font(.system(size: 10, weight: .bold))
            }
            .frame(width: timeColumnWidth, height: 32)
            .background(Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.4))

            // 各星期標頭
            ForEach(visibleDays, id: \.self) { day in
                let isToday = (day == currentWeekday)
                HStack(spacing: 3) {
                    Text(Course.dayName(for: day))
                        .font(.system(size: 12, weight: isToday ? .bold : .medium))
                        .foregroundStyle(isToday ? .blue : .primary)

                    if isToday {
                        Circle()
                            .fill(.blue)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 32)
                .background(isToday ? Color.blue.opacity(0.08) : Color.clear)
                .overlay(
                    Rectangle()
                        .frame(width: 0.5)
                        .foregroundStyle(Color.primary.opacity(0.08)),
                    alignment: .trailing
                )
            }
        }
    }

    // MARK: - 3. 左側節次與時間軸列 (等比填滿高度)

    private func periodsColumnView(cellHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(activePeriods) { period in
                VStack(spacing: 1) {
                    Text(period.shortName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    VStack(spacing: 0) {
                        Text(period.startTime.formatted)
                        Text(period.endTime.formatted)
                    }
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.85))
                }
                .frame(width: timeColumnWidth, height: cellHeight)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundStyle(Color.primary.opacity(0.06)),
                    alignment: .bottom
                )
            }
        }
        .overlay(
            Rectangle()
                .frame(width: 0.8)
                .foregroundStyle(Color.primary.opacity(0.12)),
            alignment: .trailing
        )
    }

    // MARK: - 4. 單日課程矩陣 (點選空白格設課 + 邊框拖曳上下擴展)

    private func dayColumnView(day: Int, columnWidth: CGFloat, cellHeight: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // 背景底層：各節次空白格線（點擊直接新增課程）
            VStack(spacing: 0) {
                ForEach(activePeriods) { period in
                    Button {
                        courseToAddDayAndPeriod = (day: day, periodId: period.id)
                    } label: {
                        Rectangle()
                            .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.2))
                            .frame(width: columnWidth, height: cellHeight)
                            .overlay(
                                Rectangle()
                                    .frame(height: 0.5)
                                    .foregroundStyle(Color.primary.opacity(0.06)),
                                alignment: .bottom
                            )
                            .overlay(
                                Rectangle()
                                    .frame(width: 0.5)
                                    .foregroundStyle(Color.primary.opacity(0.06)),
                                alignment: .trailing
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // 頂層：課程卡片（精確跨節、支援無衝突上下邊框拖曳）
            ForEach(store.courses.filter { $0.dayOfWeek == day }) { course in
                if let startIndex = settings.activeIndexOfPeriod(id: course.startPeriodId),
                   let endIndex = settings.activeIndexOfPeriod(id: course.endPeriodId) {

                    let minIndex = min(startIndex, endIndex)
                    let maxIndex = max(startIndex, endIndex)
                    let spanCount = maxIndex - minIndex + 1

                    let topY = CGFloat(minIndex) * cellHeight + 1.5
                    let baseHeight = CGFloat(spanCount) * cellHeight - 3.0

                    // 拖曳中的臨時高度與位置計算
                    let isDraggingBottom = (draggingBottomCourseId == course.id)
                    let isDraggingTop = (draggingTopCourseId == course.id)
                    let actualHeight = max(baseHeight + (isDraggingBottom ? dragBottomOffset : 0) - (isDraggingTop ? dragTopOffset : 0), cellHeight - 3.0)
                    let actualY = topY + (isDraggingTop ? dragTopOffset : 0)

                    CourseBlockCard(
                        course: course,
                        width: columnWidth - 3.0,
                        height: actualHeight,
                        isSelected: selectedCourseId == course.id,
                        onTap: {
                            if selectedCourseId == course.id {
                                courseToEdit = course
                            } else {
                                selectedCourseId = course.id
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        },
                        onTopDragChanged: { deltaY in
                            draggingTopCourseId = course.id
                            dragTopOffset = deltaY
                        },
                        onTopDragEnded: { deltaY in
                            commitTopDrag(course: course, deltaY: deltaY, currentStartIndex: minIndex, cellHeight: cellHeight)
                        },
                        onBottomDragChanged: { deltaY in
                            draggingBottomCourseId = course.id
                            dragBottomOffset = deltaY
                        },
                        onBottomDragEnded: { deltaY in
                            commitBottomDrag(course: course, deltaY: deltaY, currentEndIndex: maxIndex, cellHeight: cellHeight)
                        }
                    )
                    .position(x: columnWidth / 2, y: actualY + actualHeight / 2)
                    .contextMenu {
                        Button {
                            courseToEdit = course
                        } label: {
                            Label("編輯課程", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            store.delete(course)
                        } label: {
                            Label("刪除此課程", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .frame(width: columnWidth)
    }

    // MARK: - 5. 邊框拖曳上下擴展節次邏輯

    private func commitBottomDrag(course: Course, deltaY: CGFloat, currentEndIndex: Int, cellHeight: CGFloat) {
        draggingBottomCourseId = nil
        dragBottomOffset = 0

        let periodSteps = Int(round(deltaY / cellHeight))
        let newEndIndex = max(0, min(currentEndIndex + periodSteps, activePeriods.count - 1))

        if newEndIndex < activePeriods.count {
            let newEndPeriodId = activePeriods[newEndIndex].id
            store.updatePeriodRange(courseId: course.id, startPeriodId: course.startPeriodId, endPeriodId: newEndPeriodId)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func commitTopDrag(course: Course, deltaY: CGFloat, currentStartIndex: Int, cellHeight: CGFloat) {
        draggingTopCourseId = nil
        dragTopOffset = 0

        let periodSteps = Int(round(deltaY / cellHeight))
        let newStartIndex = max(0, min(currentStartIndex + periodSteps, activePeriods.count - 1))

        if newStartIndex < activePeriods.count {
            let newStartPeriodId = activePeriods[newStartIndex].id
            store.updatePeriodRange(courseId: course.id, startPeriodId: newStartPeriodId, endPeriodId: course.endPeriodId)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    // MARK: - 快捷切換動作

    private func toggleEveningPeriods() {
        store.settings.showEveningPeriods.toggle()
        store.saveSettings()
    }

    private func toggleWeekend() {
        store.settings.showWeekend.toggle()
        store.saveSettings()
    }
}

// MARK: - 現代高校質感課程卡片（醒目教室膠囊 + 上下拖曳柄）

struct CourseBlockCard: View {
    let course: Course
    let width: CGFloat
    let height: CGFloat
    let isSelected: Bool
    let onTap: () -> Void
    let onTopDragChanged: (CGFloat) -> Void
    let onTopDragEnded: (CGFloat) -> Void
    let onBottomDragChanged: (CGFloat) -> Void
    let onBottomDragEnded: (CGFloat) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            // 卡片本體
            Button(action: onTap) {
                ZStack(alignment: .topLeading) {
                    // 柔和微透背景
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(course.color.opacity(0.16))

                    // 左側質感色彩指示條
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(course.color)
                        .frame(width: 3.5)

                    // 核心內容文字
                    VStack(alignment: .leading, spacing: 2) {
                        // 課程名稱
                        Text(course.name)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(height > 50 ? 2 : 1)

                        // 教室膠囊 (核心醒目標記)
                        HStack(spacing: 2) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 8))
                            Text(course.classroom)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(course.color)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(course.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .lineLimit(1)

                        // 授課教師與學分 (卡片高度充裕時自動呈現)
                        if height >= 58 && !course.teacher.isEmpty {
                            Text(course.teacher)
                                .font(.system(size: 8.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if height >= 78 && !course.credits.isEmpty {
                            Text(course.credits)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                    .padding(.leading, 7)
                    .padding(.trailing, 2)
                    .padding(.vertical, 3)
                }
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(isSelected ? course.color : course.color.opacity(0.45), lineWidth: isSelected ? 2.0 : 0.8)
                )
                .clipped()
            }
            .buttonStyle(.plain)

            // MARK: 選中狀態下的上下邊框拖曳手柄 (因為無 ScrollView，拖曳手勢 100% 靈敏)
            if isSelected {
                VStack {
                    // 頂部拖曳把手
                    Capsule()
                        .fill(course.color)
                        .frame(width: 24, height: 4)
                        .padding(.top, 2)
                        .contentShape(Rectangle().inset(by: -10))
                        .gesture(
                            DragGesture(minimumDistance: 2)
                                .onChanged { value in
                                    onTopDragChanged(value.translation.height)
                                }
                                .onEnded { value in
                                    onTopDragEnded(value.translation.height)
                                }
                        )

                    Spacer()

                    // 底部拖曳把手
                    Capsule()
                        .fill(course.color)
                        .frame(width: 24, height: 4)
                        .padding(.bottom, 2)
                        .contentShape(Rectangle().inset(by: -10))
                        .gesture(
                            DragGesture(minimumDistance: 2)
                                .onChanged { value in
                                    onBottomDragChanged(value.translation.height)
                                }
                                .onEnded { value in
                                    onBottomDragEnded(value.translation.height)
                                }
                        )
                }
                .frame(width: width, height: height)
            }
        }
    }
}
