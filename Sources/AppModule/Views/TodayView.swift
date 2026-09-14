import SwiftUI

/// 今日聚焦主视图：专门强化“当前时间要去哪个教室”的核心诉求
public struct TodayView: View {
    @ObservedObject var store: CourseStore
    @State private var currentDate = Date()
    @State private var courseToEdit: Course?
    @State private var showingAddSheet = false

    // 每 15 秒轻量刷新一次当前时刻，自动切换正在进行/下一节课状态
    private let timer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    public init(store: CourseStore) {
        self.store = store
    }

    private var todayCourses: [Course] {
        store.todayCourses(at: currentDate)
    }

    private var currentCourse: Course? {
        store.currentCourse(at: currentDate)
    }

    private var nextCourseInfo: (course: Course, minutesUntil: Int)? {
        store.nextCourse(at: currentDate)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: 1. 核心教室聚焦大卡片 (Hero Card)
                    classroomHeroCard

                    // MARK: 2. 今日时间线课程列表
                    todayTimelineSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("今日日程")
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
            .onReceive(timer) { input in
                currentDate = input
            }
        }
    }

    // MARK: - 核心大卡片组件

    @ViewBuilder
    private var classroomHeroCard: some View {
        if let current = currentCourse {
            // 状态 1: 当前正在上课
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("当前正在上课")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.12), in: Capsule())

                    Spacer()

                    Text(current.timeRangeString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // 核心突出：超大醒目教室名称
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前教室")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.title)
                            .foregroundStyle(current.color)

                        Text(current.classroom)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(current.name)
                            .font(.title3)
                            .fontWeight(.bold)

                        if !current.teacher.isEmpty {
                            Text(current.teacher)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        courseToEdit = current
                    } label: {
                        Text("详情")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(current.color.opacity(0.3), lineWidth: 1.5)
            )

        } else if let next = nextCourseInfo {
            // 状态 2: 当前空闲，下一节课即将开始
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.caption)
                        Text(next.minutesUntil <= 30 ? "下节即将开始 · 还有 \(next.minutesUntil) 分钟" : "下一节课")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(next.course.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(next.course.color.opacity(0.12), in: Capsule())

                    Spacer()

                    Text(next.course.startTime.formatted + " 开始")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // 核心突出：下一节教室地点
                VStack(alignment: .leading, spacing: 4) {
                    Text("前往教室")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Image(systemName: "figure.walk")
                            .font(.title2)
                            .foregroundStyle(next.course.color)

                        Text(next.course.classroom)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(next.course.name)
                            .font(.title3)
                            .fontWeight(.bold)

                        if !next.course.teacher.isEmpty {
                            Text(next.course.teacher)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        courseToEdit = next.course
                    } label: {
                        Text("详情")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 3)
            )

        } else {
            // 状态 3: 今日无更多课程
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.teal)

                Text(todayCourses.isEmpty ? "今天没有任何课程" : "今日课程已全部结束")
                    .font(.headline)

                Text(todayCourses.isEmpty ? "可以点击右上角「+」安排今天的课表" : "好好休息，享受属于你的大学闲暇时光吧！")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
    }

    // MARK: - 今日时间线列表

    @ViewBuilder
    private var todayTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日全部课程 (\(todayCourses.count))")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 4)

            if todayCourses.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("暂无安排")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(todayCourses) { course in
                        TodayCourseRowCard(
                            course: course,
                            status: course.status(at: currentDate),
                            onTap: {
                                courseToEdit = course
                            }
                        )
                    }
                }
            }
        }
    }
}

/// 今日课表卡片子组件
struct TodayCourseRowCard: View {
    let course: Course
    let status: CourseStatus
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // 左侧色彩竖条条
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(course.color)
                    .frame(width: 5)
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(course.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()

                        statusBadge(for: status)
                    }

                    HStack(spacing: 16) {
                        // 教室醒目标签
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(course.color)
                            Text(course.classroom)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }

                        // 教师信息
                        if !course.teacher.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.secondary)
                                Text(course.teacher)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        // 时间区间
                        Text(course.timeRangeString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statusBadge(for status: CourseStatus) -> some View {
        switch status {
        case .inProgress:
            Text("上课中")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.green.opacity(0.15), in: Capsule())
        case .upcoming:
            Text("即将开始")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.orange.opacity(0.15), in: Capsule())
        case .finished:
            Text("已结束")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Capsule())
        case .future:
            EmptyView()
        }
    }
}
