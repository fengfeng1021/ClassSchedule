import SwiftUI
import UIKit

/// 應用程式頂部主分頁類型
public enum AppMainTab: String, CaseIterable, Identifiable {
    case schedule = "課表"
    case widgetSettings = "小工具設定"

    public var id: String { rawValue }
}

/// 全螢幕自適應免滑動課表主視圖：
/// 1. 完全無 ScrollView，在 iPad 與 iPhone 上一屏全覽所有課程，無需滑動。
/// 2. 徹底消除拖曳抖動：以命名網格座標空間與頂部錨定保證手勢平滑穩定。
/// 3. 現代大專院校課表美學：大字居中、醒目獨立教室膠囊、柔和漸層粉彩質感。
/// 4. 頂部雙分頁切換：[ 課表 | 小工具設定 ]。
/// 5. 右上角獨立「匯入課表」與「新增課程」兩大按鈕。
public struct ScheduleGridView: View {
    @ObservedObject var store: CourseStore

    @State private var selectedTab: AppMainTab = .schedule
    @State private var currentDate = Date()
    @State private var courseToEdit: Course?
    @State private var courseToAddDayAndPeriod: (day: Int, periodId: String)?
    @State private var selectedCourseId: UUID?

    @State private var showingSettingsSheet = false
    @State private var showingImportSheet = false
    @State private var showingClearAlert = false

    // 拖曳縮放即時位移與觸覺步進狀態
    @State private var draggingBottomCourseId: UUID?
    @State private var dragBottomOffset: CGFloat = 0
    @State private var draggingTopCourseId: UUID?
    @State private var dragTopOffset: CGFloat = 0
    @State private var draggingWholeCourseId: UUID?
    @State private var dragWholeOffset: CGFloat = 0
    @State private var currentDragStep: Int = 0

    // 每 15 秒輕量更新一次目前時間與狀態
    private let timer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    private var timeColumnWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 64.0 : 54.0
    }

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
        let isPad = UIDevice.current.userInterfaceIdiom == .pad

        NavigationStack {
            ZStack {
                scheduleMatrixContentView
                    .opacity(selectedTab == .schedule ? 1 : 0)
                    .allowsHitTesting(selectedTab == .schedule)

                if selectedTab == .widgetSettings {
                    WidgetSettingsView(store: store)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.22), value: selectedTab)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // MARK: 頂部置中原生分頁切換 [ 課表 | 小工具設定 ] (iPhone 上適配為 160pt 避免兩側擁擠)
                ToolbarItem(placement: .principal) {
                    Picker("主要頁面分頁", selection: $selectedTab) {
                        ForEach(AppMainTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: isPad ? 220 : 160)
                }

                // MARK: 左上角功能選項選單按鈕 (課表頁面專屬)
                ToolbarItem(placement: .navigationBarLeading) {
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
                    .opacity(selectedTab == .schedule ? 1 : 0)
                    .disabled(selectedTab != .schedule)
                }

                // MARK: 右上角兩個獨立分開的按鈕：「匯入課表」與「新增課程」
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: isPad ? 14 : 10) {
                        // 按鈕一：匯入課表 (iPad 顯示文字圖示，iPhone 顯示精簡純圖示以防止按鈕重疊)
                        Button {
                            showingImportSheet = true
                        } label: {
                            if isPad {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.doc")
                                    Text("匯入課表")
                                        .font(.subheadline.weight(.medium))
                                }
                            } else {
                                Image(systemName: "arrow.down.doc")
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                        .accessibilityLabel("匯入課表")

                        // 按鈕二：新增課程
                        Button {
                            courseToAddDayAndPeriod = (day: currentWeekday, periodId: activePeriods.first?.id ?? "1")
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .accessibilityLabel("新增課程")
                    }
                    .opacity(selectedTab == .schedule ? 1 : 0)
                    .disabled(selectedTab != .schedule)
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

    // MARK: - 課表主矩陣內容 (全螢幕自適應、零滑動)

    private var scheduleMatrixContentView: some View {
        VStack(spacing: 0) {
            // 1. 頂部教室速查橫幅
            classroomBanner
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 4)

            // 2. 星期標頭行 (固定頂部)
            weekdayHeaderRow
                .background(Color(uiColor: .secondarySystemGroupedBackground))

            Divider()

            // 3. 全螢幕自適應免滑動課表矩陣 (Zero ScrollView，含尺寸保護防凍結)
            GeometryReader { geometry in
                let availableWidth = geometry.size.width
                let availableHeight = geometry.size.height

                if availableWidth > (timeColumnWidth + 50.0) && availableHeight > 50.0 {
                    let daysCount = max(CGFloat(visibleDays.count), 1.0)
                    let columnWidth = max((availableWidth - timeColumnWidth) / daysCount, 20.0)
                    let periodCount = max(CGFloat(activePeriods.count), 1.0)
                    let cellHeight = max(availableHeight / periodCount, 15.0)

                    HStack(alignment: .top, spacing: 0) {
                        // 左側：節次與時間軸
                        periodsColumnView(cellHeight: cellHeight)

                        // 右側：各星期課程網格
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(visibleDays, id: \.self) { day in
                                dayColumnView(day: day, columnWidth: columnWidth, cellHeight: cellHeight)
                            }
                        }
                    }
                    .frame(width: availableWidth, height: availableHeight)
                    .coordinateSpace(name: "ScheduleGridSpace")
                } else {
                    Color.clear
                }
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
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text(current.classroom)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("(\(current.name))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(current.color.opacity(0.35), lineWidth: 1)
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
                            .font(.system(size: 10, weight: .bold))
                        Text(next.minutesUntil <= 30 ? "\(next.minutesUntil)分後" : "下一節")
                            .font(.caption2.weight(.heavy))
                    }
                    .foregroundStyle(next.course.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(next.course.color.opacity(0.14), in: Capsule())

                    Text("前往教室:")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text(next.course.classroom)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("(\(next.course.startTime.formatted))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
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
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.teal)
                Text(store.todayCourses(at: currentDate).isEmpty ? "今日無排課" : "今日課程已全部結束")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.6))
            )
        }
    }

    // MARK: - 2. 星期標頭行

    private var weekdayHeaderRow: some View {
        HStack(spacing: 0) {
            // 左上角節次標題
            VStack(spacing: 1) {
                Text("節次")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(width: timeColumnWidth, height: 34)
            .background(Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.4))

            // 各星期標頭
            ForEach(visibleDays, id: \.self) { day in
                let isToday = (day == currentWeekday)
                HStack(spacing: 4) {
                    Text(Course.dayName(for: day))
                        .font(.system(size: 13, weight: isToday ? .heavy : .bold, design: .rounded))
                        .foregroundStyle(isToday ? .blue : .primary)

                    if isToday {
                        Circle()
                            .fill(.blue)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 34)
                .background(isToday ? Color.blue.opacity(0.09) : Color.clear)
                .overlay(
                    Rectangle()
                        .frame(width: 0.5)
                        .foregroundStyle(Color.primary.opacity(0.08)),
                    alignment: .trailing
                )
            }
        }
    }

    // MARK: - 3. 左側節次與時間軸列 (等比填滿高度、清晰大字)

    private func periodsColumnView(cellHeight: CGFloat) -> some View {
        let periodNumSize: CGFloat = min(max(cellHeight * 0.28, 13.0), 17.0)
        let timeFontSize: CGFloat = min(max(cellHeight * 0.19, 9.5), 12.0)

        return VStack(spacing: 0) {
            ForEach(activePeriods) { period in
                VStack(spacing: 2) {
                    Text(period.shortName)
                        .font(.system(size: periodNumSize, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)

                    VStack(spacing: 0.5) {
                        Text(period.startTime.formatted)
                            .font(.system(size: timeFontSize, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary.opacity(0.9))

                        Text(period.endTime.formatted)
                            .font(.system(size: timeFontSize * 0.92, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: timeColumnWidth, height: max(cellHeight, 15.0))
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
                .frame(width: 1.0)
                .foregroundStyle(Color.primary.opacity(0.14)),
            alignment: .trailing
        )
    }

    // MARK: - 4. 單日課程網格 (支援無抖動上下邊框拖曳調整)

    private func dayColumnView(day: Int, columnWidth: CGFloat, cellHeight: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // 底層：空白格線（點選任一格可直接新增課程）
            VStack(spacing: 0) {
                ForEach(activePeriods) { period in
                    Button {
                        courseToAddDayAndPeriod = (day: day, periodId: period.id)
                    } label: {
                        Rectangle()
                            .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.2))
                            .frame(width: max(columnWidth, 20.0), height: max(cellHeight, 15.0))
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

            // 頂層：課程卡片（精確跨節、絕對錨定定位、支援整卡拖曳平移與邊框手柄縮放）
            ForEach(store.courses.filter { $0.dayOfWeek == day }) { course in
                if let startIndex = settings.activeIndexOfPeriod(id: course.startPeriodId),
                   let endIndex = settings.activeIndexOfPeriod(id: course.endPeriodId) {

                    let minIndex = min(startIndex, endIndex)
                    let maxIndex = max(startIndex, endIndex)
                    let spanCount = maxIndex - minIndex + 1

                    let topY = CGFloat(minIndex) * cellHeight + 1.5
                    let baseHeight = max(CGFloat(spanCount) * cellHeight - 3.0, 15.0)

                    // 拖曳狀態計算：支援整卡平移與頂底部縮放，徹底杜絕中心點位移抖動
                    let isDraggingBottom = (draggingBottomCourseId == course.id)
                    let isDraggingTop = (draggingTopCourseId == course.id)
                    let isDraggingWhole = (draggingWholeCourseId == course.id)

                    let actualHeight = max(baseHeight + (isDraggingBottom ? dragBottomOffset : 0) - (isDraggingTop ? dragTopOffset : 0), 15.0)
                    let actualY = topY + (isDraggingWhole ? dragWholeOffset : (isDraggingTop ? dragTopOffset : 0))

                    CourseBlockCard(
                        course: course,
                        spanCount: spanCount,
                        width: max(columnWidth - 3.0, 15.0),
                        height: actualHeight,
                        isSelected: selectedCourseId == course.id,
                        isDraggingWhole: isDraggingWhole,
                        onTap: {
                            if selectedCourseId == course.id {
                                courseToEdit = course
                            } else {
                                selectedCourseId = course.id
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        },
                        onWholeDragChanged: { deltaY in
                            draggingWholeCourseId = course.id
                            dragWholeOffset = deltaY
                            handleHapticStepChange(deltaY: deltaY, cellHeight: cellHeight)
                        },
                        onWholeDragEnded: { deltaY in
                            commitWholeDrag(course: course, deltaY: deltaY, currentStartIndex: minIndex, spanCount: spanCount, cellHeight: cellHeight)
                        },
                        onTopDragChanged: { deltaY in
                            draggingTopCourseId = course.id
                            dragTopOffset = deltaY
                            handleHapticStepChange(deltaY: deltaY, cellHeight: cellHeight)
                        },
                        onTopDragEnded: { deltaY in
                            commitTopDrag(course: course, deltaY: deltaY, currentStartIndex: minIndex, cellHeight: cellHeight)
                        },
                        onBottomDragChanged: { deltaY in
                            draggingBottomCourseId = course.id
                            dragBottomOffset = deltaY
                            handleHapticStepChange(deltaY: deltaY, cellHeight: cellHeight)
                        },
                        onBottomDragEnded: { deltaY in
                            commitBottomDrag(course: course, deltaY: deltaY, currentEndIndex: maxIndex, cellHeight: cellHeight)
                        }
                    )
                    .offset(x: 1.5, y: actualY)
                    .zIndex(isDraggingWhole ? 10 : (selectedCourseId == course.id ? 5 : 1))
                }
            }
        }
        .frame(width: max(columnWidth, 20.0))
    }

    // MARK: - 5. 拖曳步進觸覺、碰撞檢測與吸附邏輯

    private func handleHapticStepChange(deltaY: CGFloat, cellHeight: CGFloat) {
        let step = Int(round(deltaY / cellHeight))
        if step != currentDragStep {
            currentDragStep = step
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private func commitWholeDrag(course: Course, deltaY: CGFloat, currentStartIndex: Int, spanCount: Int, cellHeight: CGFloat) {
        draggingWholeCourseId = nil
        dragWholeOffset = 0
        currentDragStep = 0

        let periodSteps = Int(round(deltaY / cellHeight))
        let maxStartIndex = max(0, activePeriods.count - spanCount)
        let newStartIndex = max(0, min(currentStartIndex + periodSteps, maxStartIndex))
        let newEndIndex = newStartIndex + spanCount - 1

        if newStartIndex < activePeriods.count && newEndIndex < activePeriods.count {
            let newStartPeriodId = activePeriods[newStartIndex].id
            let newEndPeriodId = activePeriods[newEndIndex].id

            // 碰撞防護：禁止重疊已存在的其他課程
            if store.hasPeriodOverlap(dayOfWeek: course.dayOfWeek, startPeriodId: newStartPeriodId, endPeriodId: newEndPeriodId, excludingCourseId: course.id) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }

            store.updatePeriodRange(courseId: course.id, startPeriodId: newStartPeriodId, endPeriodId: newEndPeriodId)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func commitBottomDrag(course: Course, deltaY: CGFloat, currentEndIndex: Int, cellHeight: CGFloat) {
        draggingBottomCourseId = nil
        dragBottomOffset = 0
        currentDragStep = 0

        let periodSteps = Int(round(deltaY / cellHeight))
        let newEndIndex = max(0, min(currentEndIndex + periodSteps, activePeriods.count - 1))

        if newEndIndex < activePeriods.count {
            let newEndPeriodId = activePeriods[newEndIndex].id
            let startIndex = settings.indexOfPeriod(id: course.startPeriodId) ?? 0

            // 必須保證起訖順序合法且不碰撞
            if startIndex <= newEndIndex {
                if store.hasPeriodOverlap(dayOfWeek: course.dayOfWeek, startPeriodId: course.startPeriodId, endPeriodId: newEndPeriodId, excludingCourseId: course.id) {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    return
                }

                store.updatePeriodRange(courseId: course.id, startPeriodId: course.startPeriodId, endPeriodId: newEndPeriodId)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
    }

    private func commitTopDrag(course: Course, deltaY: CGFloat, currentStartIndex: Int, cellHeight: CGFloat) {
        draggingTopCourseId = nil
        dragTopOffset = 0
        currentDragStep = 0

        let periodSteps = Int(round(deltaY / cellHeight))
        let newStartIndex = max(0, min(currentStartIndex + periodSteps, activePeriods.count - 1))

        if newStartIndex < activePeriods.count {
            let newStartPeriodId = activePeriods[newStartIndex].id
            let endIndex = settings.indexOfPeriod(id: course.endPeriodId) ?? (activePeriods.count - 1)

            // 必須保證起訖順序合法且不碰撞
            if newStartIndex <= endIndex {
                if store.hasPeriodOverlap(dayOfWeek: course.dayOfWeek, startPeriodId: newStartPeriodId, endPeriodId: course.endPeriodId, excludingCourseId: course.id) {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    return
                }

                store.updatePeriodRange(courseId: course.id, startPeriodId: newStartPeriodId, endPeriodId: course.endPeriodId)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
    }

    // MARK: - 快捷動作

    private func toggleEveningPeriods() {
        store.settings.showEveningPeriods.toggle()
        store.saveSettings()
    }

    private func toggleWeekend() {
        store.settings.showWeekend.toggle()
        store.saveSettings()
    }
}

// MARK: - 現代高校高質感課程卡片（Apple原生微光擬物 + 防透實體基底 + 單節課全景雙行佈局 + 整卡平移與邊框手柄）

struct CourseBlockCard: View {
    let course: Course
    let spanCount: Int
    let width: CGFloat
    let height: CGFloat
    let isSelected: Bool
    let isDraggingWhole: Bool
    let onTap: () -> Void
    let onWholeDragChanged: (CGFloat) -> Void
    let onWholeDragEnded: (CGFloat) -> Void
    let onTopDragChanged: (CGFloat) -> Void
    let onTopDragEnded: (CGFloat) -> Void
    let onBottomDragChanged: (CGFloat) -> Void
    let onBottomDragEnded: (CGFloat) -> Void

    // MARK: - 自適應比例計算 (依寬高動態縮放，保證非負非零)
    private var safeWidth: CGFloat {
        max(width, 15.0)
    }

    private var safeHeight: CGFloat {
        max(height, 15.0)
    }

    private var widthScale: CGFloat {
        min(max(safeWidth / 60.0, 0.88), 1.65)
    }

    private var heightScale: CGFloat {
        min(max(safeHeight / 55.0, 0.88), 1.5)
    }

    private var baseScale: CGFloat {
        min(widthScale, heightScale)
    }

    // 課程名稱字級：自適應 11pt ~ 18pt，極粗圓潤
    private var titleFontSize: CGFloat {
        let base: CGFloat = spanCount > 1 ? 12.5 : 11.2
        return min(max(base * widthScale, 10.5), 18.0)
    }

    // 教室標籤字級：自適應 10pt ~ 15.5pt，極黑圓潤
    private var classroomFontSize: CGFloat {
        min(max(10.5 * widthScale, 10.0), 15.5)
    }

    // 授課教師與學分微標籤：自適應 8.5pt ~ 12pt，粗體圓潤
    private var metaFontSize: CGFloat {
        min(max(8.5 * widthScale, 8.0), 12.0)
    }

    private var cardCornerRadius: CGFloat {
        min(max(8.5 * baseScale, 7.5), 13.0)
    }

    private var elementSpacing: CGFloat {
        min(max(3.0 * heightScale, 2.0), 6.5)
    }

    // 是否為緊湊模式（單節課或高度較小）
    private var isCompact: Bool {
        spanCount == 1 || safeHeight < 58
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 卡片本體 (點擊選中/編輯，按住直接上下拖曳平移整門課程)
            ZStack {
                // 1. 防穿透實體基底（杜絕系統深色遮罩穿透導致卡片變黑消失）
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))

                // 2. Apple 柔和雙色微光漸變（高透晶亮光感，告別死板灰色）
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                course.color.opacity(0.24),
                                course.color.opacity(0.13),
                                course.color.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // 3. 核心內容排版
                if isCompact {
                    compactContentLayout
                } else {
                    standardContentLayout
                }
            }
            .frame(width: safeWidth, height: safeHeight)
            // 4. Apple 微光邊框（模擬玻璃折射 Specular Highlight + 主題色輪廓）
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.40),
                                course.color.opacity(0.18),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .stroke(
                        course.color.opacity(isSelected ? 0.92 : 0.38),
                        lineWidth: isSelected ? 2.5 : 1.0
                    )
            )
            .shadow(
                color: isDraggingWhole ? course.color.opacity(0.42) : (isSelected ? course.color.opacity(0.28) : Color.black.opacity(0.05)),
                radius: isDraggingWhole ? 10 : (isSelected ? 5 : 2),
                x: 0,
                y: isDraggingWhole ? 5 : 1
            )
            .scaleEffect(isDraggingWhole ? 1.03 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isDraggingWhole)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            .gesture(
                DragGesture(minimumDistance: 5, coordinateSpace: .named("ScheduleGridSpace"))
                    .onChanged { value in
                        onWholeDragChanged(value.translation.height)
                    }
                    .onEnded { value in
                        onWholeDragEnded(value.translation.height)
                    }
            )

            // MARK: 選中狀態下的上下邊框拖曳手柄 (全域網格座標空間，零抖動)
            if isSelected {
                VStack {
                    // 頂部拖曳把手
                    HStack {
                        Spacer()
                        Capsule()
                            .fill(course.color)
                            .frame(width: max(22 * widthScale, 20), height: 4.5)
                            .shadow(color: Color.black.opacity(0.18), radius: 2, y: 1)
                        Spacer()
                    }
                    .frame(height: 18)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .named("ScheduleGridSpace"))
                            .onChanged { value in
                                onTopDragChanged(value.translation.height)
                            }
                            .onEnded { value in
                                onTopDragEnded(value.translation.height)
                            }
                    )

                    Spacer()

                    // 底部拖曳把手
                    HStack {
                        Spacer()
                        Capsule()
                            .fill(course.color)
                            .frame(width: max(22 * widthScale, 20), height: 4.5)
                            .shadow(color: Color.black.opacity(0.18), radius: 2, y: 1)
                        Spacer()
                    }
                    .frame(height: 18)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .named("ScheduleGridSpace"))
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

    // MARK: - 單節課（緊湊模式）專屬排版：雙行全景佈局，長課名、教室、教師與學分 100% 完整顯示

    private var compactContentLayout: some View {
        VStack(spacing: 2) {
            Spacer(minLength: 0)

            // 行 1: 課程名稱（支援雙行換行與縮小係數 0.65，長課名絕不被省略截斷）
            Text(course.name)
                .font(.system(size: titleFontSize, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .padding(.horizontal, 2)

            // 行 2: 橫向一體化緊湊標籤：📍 教室 · 教師 · 學分
            HStack(spacing: 2) {
                if !course.classroom.isEmpty {
                    Image(systemName: "location.fill")
                        .font(.system(size: metaFontSize * 0.72, weight: .bold))
                    Text(course.classroom)
                        .font(.system(size: metaFontSize, weight: .black, design: .rounded))
                }

                if !course.teacher.isEmpty {
                    if !course.classroom.isEmpty {
                        Text("·")
                            .font(.system(size: metaFontSize * 0.8, weight: .bold))
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                    Text(course.teacher)
                        .font(.system(size: metaFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                if !course.credits.isEmpty {
                    Text("·")
                        .font(.system(size: metaFontSize * 0.8, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.6))
                    Text(course.credits)
                        .font(.system(size: metaFontSize * 0.95, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.9))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.68)
            .padding(.horizontal, 4)
            .padding(.vertical, 1.5)
            .background(
                Capsule()
                    .fill(course.color.opacity(0.16))
            )

            Spacer(minLength: 0)
        }
        .padding(2.5)
    }

    // MARK: - 多節課（標準模式）排版：三行式現代大氣美學

    private var standardContentLayout: some View {
        VStack(spacing: elementSpacing) {
            Spacer(minLength: 0)

            // 1. 課程名稱 (自適應大字、超重圓潤、多行優化)
            Text(course.name)
                .font(.system(size: titleFontSize, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(spanCount > 2 ? 3 : 2)
                .lineSpacing(1.5)
                .minimumScaleFactor(0.70)
                .padding(.horizontal, max(3.0 * widthScale, 2.0))

            // 2. 獨立教室膠囊 (極黑字重、鮮明雙色漸層、微光外框)
            if !course.classroom.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "location.fill")
                        .font(.system(size: classroomFontSize * 0.72, weight: .bold))
                    Text(course.classroom)
                        .font(.system(size: classroomFontSize, weight: .black, design: .rounded))
                }
                .foregroundStyle(course.color)
                .padding(.horizontal, max(6.0 * widthScale, 4.5))
                .padding(.vertical, max(2.5 * heightScale, 1.8))
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    course.color.opacity(0.28),
                                    course.color.opacity(0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(course.color.opacity(0.25), lineWidth: 0.5)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }

            // 3. 授課教師與學分微標籤
            if !course.teacher.isEmpty || !course.credits.isEmpty {
                HStack(spacing: 3) {
                    if !course.teacher.isEmpty {
                        Text(course.teacher)
                            .font(.system(size: metaFontSize, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if !course.teacher.isEmpty && !course.credits.isEmpty {
                        Text("•")
                            .font(.system(size: metaFontSize * 0.9, weight: .black, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                    if !course.credits.isEmpty {
                        Text(course.credits)
                            .font(.system(size: metaFontSize, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary.opacity(0.9))
                            .lineLimit(1)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)
        }
        .padding(3)
    }
}
