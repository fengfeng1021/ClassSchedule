import SwiftUI

/// 周课表视图：提供「按天浏览」与「全周网格」两种专业视图，自适应 iPad 大屏与 iPhone
public struct WeeklyScheduleView: View {
    @ObservedObject var store: CourseStore
    @State private var selectedDay: Int = 1
    @State private var viewMode: ViewMode = .dayByDay
    @State private var courseToEdit: Course?
    @State private var showingAddSheet = false

    enum ViewMode: String, CaseIterable {
        case dayByDay = "按日列表"
        case weekGrid = "全周网格"
    }

    public init(store: CourseStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部模式切换与快捷星期选择器
                VStack(spacing: 12) {
                    Picker("浏览模式", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    if viewMode == .dayByDay {
                        daySelectorBar
                    }
                }
                .padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemGroupedBackground))

                Divider()

                // 内容呈现区
                if viewMode == .dayByDay {
                    dayCourseList
                } else {
                    weekGridView
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("完整课表")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                CourseEditSheet(store: store)
            }
            .sheet(item: $courseToEdit) { course in
                CourseEditSheet(store: store, courseToEdit: course)
            }
            .onAppear {
                setTodayAsDefault()
            }
        }
    }

    // MARK: - 星期选择胶囊栏

    private var daySelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(1...7, id: \.self) { day in
                    let isSelected = (selectedDay == day)
                    let isToday = (currentNormalizedWeekday == day)

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedDay = day
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(Course.dayName(for: day))
                                .font(.subheadline)
                                .fontWeight(isSelected ? .bold : .medium)

                            if isToday {
                                Circle()
                                    .fill(isSelected ? .white : .blue)
                                    .frame(width: 5, height: 5)
                            } else {
                                Circle()
                                    .fill(Color.clear)
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ?
                            Capsule().fill(.blue) :
                            Capsule().fill(Color(uiColor: .tertiarySystemGroupedBackground))
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - 视图 1: 单日卡片流

    private var dayCourseList: some View {
        let dayCourses = store.courses(for: selectedDay)

        return ScrollView {
            LazyVStack(spacing: 14) {
                if dayCourses.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.tertiary)
                        Text("\(Course.dayName(for: selectedDay)) 没有课程安排")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(dayCourses) { course in
                        Button {
                            courseToEdit = course
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(course.timeRangeString)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(course.color)

                                    Spacer()

                                    Text("\(course.durationMinutes) 分钟")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Text(course.name)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.primary)

                                HStack(spacing: 16) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "mappin.and.ellipse")
                                            .foregroundStyle(course.color)
                                        Text(course.classroom)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.primary)
                                    }

                                    if !course.teacher.isEmpty {
                                        HStack(spacing: 5) {
                                            Image(systemName: "person.crop.circle")
                                                .foregroundStyle(.secondary)
                                            Text(course.teacher)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .font(.subheadline)

                                if !course.notes.isEmpty {
                                    Text(course.notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .padding(.top, 2)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(course.color.opacity(0.35), lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - 视图 2: iPad / 横屏沉浸式全周网格

    private var weekGridView: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 1) {
                // 顶部星期标头
                HStack(spacing: 1) {
                    Text("时间")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 50, height: 36)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))

                    ForEach(1...7, id: \.self) { day in
                        Text(Course.dayName(for: day))
                            .font(.caption.bold())
                            .frame(width: 100, height: 36)
                            .background(
                                currentNormalizedWeekday == day ?
                                Color.blue.opacity(0.15) :
                                Color(uiColor: .secondarySystemGroupedBackground)
                            )
                            .foregroundStyle(currentNormalizedWeekday == day ? .blue : .primary)
                    }
                }

                // 纵向时间轴 (8:00 - 21:00)
                ForEach(8..<21, id: \.self) { hour in
                    HStack(spacing: 1) {
                        // 时间列
                        Text(String(format: "%02d:00", hour))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 50, height: 60)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))

                        // 各个星期的格子
                        ForEach(1...7, id: \.self) { day in
                            let matchingCourses = coursesInHour(day: day, hour: hour)
                            ZStack {
                                Rectangle()
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                    .frame(width: 100, height: 60)

                                if let course = matchingCourses.first {
                                    Button {
                                        courseToEdit = course
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(course.name)
                                                .font(.system(size: 11, weight: .bold))
                                                .lineLimit(1)
                                            Text(course.classroom)
                                                .font(.system(size: 10, weight: .semibold))
                                                .lineLimit(1)
                                        }
                                        .padding(4)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                        .background(course.color.opacity(0.2), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .stroke(course.color, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .padding(2)
                                }
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
    }

    private func coursesInHour(day: Int, hour: Int) -> [Course] {
        store.courses(for: day).filter { course in
            course.startTime.hour == hour
        }
    }

    private var currentNormalizedWeekday: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 ? 7 : (weekday - 1)
    }

    private func setTodayAsDefault() {
        selectedDay = currentNormalizedWeekday
    }
}
