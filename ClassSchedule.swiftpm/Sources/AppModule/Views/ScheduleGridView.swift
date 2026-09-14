import SwiftUI

/// 全週格狀課表主視圖：支援節次制方正對齊、點選空白格設課、上下邊框拖曳擴展節次與一鍵匯入
public struct ScheduleGridView: View {
    @ObservedObject var store: CourseStore

    @State private var currentDate = Date()
    @State private var courseToEdit: Course?
    @State private var courseToAddDayAndPeriod: (day: Int, periodId: String)?
    @State private var selectedCourseId: UUID?

    @State private var showingAddSheet = false
    @State private var showingSettingsSheet = false
    @State private var showingImportSheet = false
    @State private var showingClearAlert = false

    // 拖曳縮放臨時狀態
    @State private var draggingBottomCourseId: UUID?
    @State private var dragBottomOffset: CGFloat = 0
    @State private var draggingTopCourseId: UUID?
    @State private var dragTopOffset: CGFloat = 0

    // 每 15 秒更新一次目前時間與狀態
    private let timer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    private let timeColumnWidth: CGFloat = 52.0

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
                // MARK: 1. 頂部教室速查橫幅
                classroomBanner
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                // MARK: 2. 星期標頭行 (固定於頂部)
                weekdayHeaderRow
                    .background(Color(uiColor: .secondarySystemGroupedBackground))

                Divider()

                // MARK: 3. 節次方性格狀課表矩陣
                GeometryReader { geometry in
                    let availableWidth = geometry.size.width
                    let columnWidth = max((availableWidth - timeColumnWidth) / CGFloat(visibleDays.count), 44.0)

                    ScrollView([.vertical, .horizontal], showsIndicators: true) {
                        HStack(alignment: .top, spacing: 0) {
                            // 左側：節次與時間軸列
                            periodsTimeColumn

                            // 右側：各星期的格子與課程矩陣
                            HStack(alignment: .top, spacing: 0) {
                                ForEach(visibleDays, id: \.self) { day in
                                    dayColumnView(day: day, columnWidth: columnWidth)
                                }
                            }
                        }
                        .frame(minWidth: availableWidth)
                    }
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
                            showingImportSheet = true
                        } label: {
                            Label("一鍵匯入課表", systemImage: "arrow.down.doc.fill")
                        }

                        Menu {
                            Button("緊湊 (52 pt)") { updateCellHeight(52) }
                            Button("標準 (65 pt)") { updateCellHeight(65) }
                            Button("寬敞 (80 pt)") { updateCellHeight(80) }
                            Button("超大 (96 pt)") { updateCellHeight(96) }
                        } label: {
                            Label("調整格子大小", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                        }

                        Button {
                            toggleWeekend()
                        } label: {
                            Label(settings.showWeekend ? "隱藏週末 (僅顯示週一至五)" : "顯示週末 (週一至週日)", systemImage: "calendar")
                        }

                        Divider()

                        Button {
                            showingSettingsSheet = true
                        } label: {
                            Label("課表自訂設定", systemImage: "gearshape")
                        }

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

                // MARK: 右上角新增課程按鈕
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showingImportSheet = true
                        } label: {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 15, weight: .medium))
                        }

                        Button {
                            courseToAddDayAndPeriod = (day: currentWeekday, periodId: "1")
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
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("上課中")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.green.opacity(0.12), in: Capsule())

                    Text("當前教室:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(current.classroom)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
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
            Button {
                courseToEdit = next.course
            } label: {
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.caption2)
                        Text(next.minutesUntil <= 30 ? "\(next.minutesUntil)分鐘後" : "下一節")
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
                        .font(.system(size: 17, weight: .bold, design: .rounded))
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
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.teal)
                Text(store.todayCourses(at: currentDate).isEmpty ? "今日無課程安排" : "今日課程已全部結束，好好休息！")
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

    // MARK: - 2. 星期標頭行

    private var weekdayHeaderRow: some View {
        HStack(spacing: 0) {
            // 左上角標題
            VStack(spacing: 1) {
                Text("節次")
                    .font(.system(size: 11, weight: .bold))
                Text("時間")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(width: timeColumnWidth, height: 40)
            .background(Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.4))

            // 週一至週五/週日標頭
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
                .frame(maxWidth: .infinity, maxHeight: 40)
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

    // MARK: - 3. 左側節次與時間軸列

    private var periodsTimeColumn: some View {
        VStack(spacing: 0) {
            ForEach(settings.periods) { period in
                VStack(spacing: 2) {
                    Text(period.shortName)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    VStack(spacing: 0) {
                        Text(period.startTime.formatted)
                        Text(period.endTime.formatted)
                    }
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                }
                .frame(width: timeColumnWidth, height: settings.gridCellHeight)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundStyle(Color.primary.opacity(0.08)),
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

    // MARK: - 4. 單日課程與空白格矩陣

    private func dayColumnView(day: Int, columnWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // 背景底層：空白網格線（點擊直接新增課程）
            VStack(spacing: 0) {
                ForEach(settings.periods) { period in
                    Button {
                        // 點選空白格，快速填寫該節次課程
                        courseToAddDayAndPeriod = (day: day, periodId: period.id)
                    } label: {
                        Rectangle()
                            .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.25))
                            .frame(width: columnWidth, height: settings.gridCellHeight)
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

            // 頂層：各課程卡片（精確跨節、支援上下手柄拖曳選格）
            ForEach(store.courses.filter { $0.dayOfWeek == day }) { course in
                if let startIndex = settings.indexOfPeriod(id: course.startPeriodId),
                   let endIndex = settings.indexOfPeriod(id: course.endPeriodId) {

                    let minIndex = min(startIndex, endIndex)
                    let maxIndex = max(startIndex, endIndex)
                    let spanCount = maxIndex - minIndex + 1

                    let topY = CGFloat(minIndex) * settings.gridCellHeight + 2.0
                    let baseHeight = CGFloat(spanCount) * settings.gridCellHeight - 4.0

                    // 拖曳中的臨時高度與位置計算
                    let isDraggingBottom = (draggingBottomCourseId == course.id)
                    let isDraggingTop = (draggingTopCourseId == course.id)
                    let actualHeight = max(baseHeight + (isDraggingBottom ? dragBottomOffset : 0) - (isDraggingTop ? dragTopOffset : 0), settings.gridCellHeight - 4.0)
                    let actualY = topY + (isDraggingTop ? dragTopOffset : 0)

                    CourseBlockCard(
                        course: course,
                        width: columnWidth - 4.0,
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
                            commitTopDrag(course: course, deltaY: deltaY, currentStartIndex: minIndex)
                        },
                        onBottomDragChanged: { deltaY in
                            draggingBottomCourseId = course.id
                            dragBottomOffset = deltaY
                        },
                        onBottomDragEnded: { deltaY in
                            commitBottomDrag(course: course, deltaY: deltaY, currentEndIndex: maxIndex)
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

    // MARK: - 5. 拖曳上下邊框框選節次邏輯

    private func commitBottomDrag(course: Course, deltaY: CGFloat, currentEndIndex: Int) {
        draggingBottomCourseId = nil
        dragBottomOffset = 0

        let periodSteps = Int(round(deltaY / settings.gridCellHeight))
        let newEndIndex = max(0, min(currentEndIndex + periodSteps, settings.periods.count - 1))

        if newEndIndex < settings.periods.count {
            let newEndPeriodId = settings.periods[newEndIndex].id
            store.updatePeriodRange(courseId: course.id, startPeriodId: course.startPeriodId, endPeriodId: newEndPeriodId)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func commitTopDrag(course: Course, deltaY: CGFloat, currentStartIndex: Int) {
        draggingTopCourseId = nil
        dragTopOffset = 0

        let periodSteps = Int(round(deltaY / settings.gridCellHeight))
        let newStartIndex = max(0, min(currentStartIndex + periodSteps, settings.periods.count - 1))

        if newStartIndex < settings.periods.count {
            let newStartPeriodId = settings.periods[newStartIndex].id
            store.updatePeriodRange(courseId: course.id, startPeriodId: newStartPeriodId, endPeriodId: course.endPeriodId)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    // MARK: - 快捷選單動作

    private func updateCellHeight(_ height: CGFloat) {
        store.settings.gridCellHeight = height
        store.saveSettings()
    }

    private func toggleWeekend() {
        store.settings.showWeekend.toggle()
        store.saveSettings()
    }
}

// MARK: - 課程卡片組件（支援上下邊框拖曳選格柄）

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
            // 卡片本體按鈕
            Button(action: onTap) {
                ZStack(alignment: .topLeading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(course.color.opacity(0.18))

                    // 左側色彩直條
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(course.color)
                        .frame(width: 4)

                    // 內容資訊
                    VStack(alignment: .leading, spacing: 2) {
                        // 課程名稱
                        Text(course.name)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(height > 55 ? 3 : 2)

                        // 教室地點 (最醒目核心)
                        HStack(spacing: 2) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 8))
                            Text(course.classroom)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(course.color)
                        .lineLimit(1)

                        // 授課教師與學分 (空間充裕時顯示)
                        if height >= 60 && !course.teacher.isEmpty {
                            Text(course.teacher)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if height >= 85 && !course.credits.isEmpty {
                            Text(course.credits)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary.opacity(0.8))
                        }

                        if height >= 110 {
                            Text(course.periodSpanString)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 8)
                    .padding(.trailing, 3)
                    .padding(.vertical, 4)
                }
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? course.color : course.color.opacity(0.55), lineWidth: isSelected ? 2.0 : 1.0)
                )
            }
            .buttonStyle(.plain)

            // MARK: 選中狀態下的上下邊框拖曳調整手柄 (Drag Handles)
            if isSelected {
                VStack {
                    // 頂部拖曳手柄
                    Capsule()
                        .fill(course.color)
                        .frame(width: 28, height: 5)
                        .padding(.top, 2)
                        .gesture(
                            DragGesture(minimumDistance: 4)
                                .onChanged { value in
                                    onTopDragChanged(value.translation.height)
                                }
                                .onEnded { value in
                                    onTopDragEnded(value.translation.height)
                                }
                        )

                    Spacer()

                    // 底部拖曳手柄
                    Capsule()
                        .fill(course.color)
                        .frame(width: 28, height: 5)
                        .padding(.bottom, 2)
                        .gesture(
                            DragGesture(minimumDistance: 4)
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
