import SwiftUI

/// 课程管理视图：提供全局搜索、列表分组、侧滑删除与快速编辑能力
public struct CourseListView: View {
    @ObservedObject var store: CourseStore
    @State private var searchText: String = ""
    @State private var courseToEdit: Course?
    @State private var showingAddSheet = false

    public init(store: CourseStore) {
        self.store = store
    }

    private var filteredCourses: [Course] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return store.courses
        } else {
            let query = searchText.lowercased()
            return store.courses.filter { course in
                course.name.lowercased().contains(query) ||
                course.classroom.lowercased().contains(query) ||
                course.teacher.lowercased().contains(query) ||
                course.notes.lowercased().contains(query)
            }
        }
    }

    public var body: some View {
        NavigationStack {
            List {
                ForEach(1...7, id: \.self) { day in
                    let coursesForDay = filteredCourses.filter { $0.dayOfWeek == day }
                    if !coursesForDay.isEmpty {
                        Section(header: Text(Course.dayName(for: day))) {
                            ForEach(coursesForDay) { course in
                                CourseRowView(course: course)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        courseToEdit = course
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                store.delete(course)
                                            }
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }

                                        Button {
                                            courseToEdit = course
                                        } label: {
                                            Label("编辑", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                            }
                        }
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("共计 \(store.courses.count) 门课程安排")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("支持左滑快速删除或修改")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "搜索课程、教室或教师")
            .navigationTitle("所有课程")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                CourseEditSheet(store: store)
            }
            .sheet(item: $courseToEdit) { course in
                CourseEditSheet(store: store, courseToEdit: course)
            }
        }
    }
}

/// 课程行视图
struct CourseRowView: View {
    let course: Course

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(course.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.body.weight(.medium))

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .foregroundStyle(course.color)
                        Text(course.classroom)
                            .font(.caption.weight(.semibold))
                    }

                    if !course.teacher.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person")
                                .foregroundStyle(.secondary)
                            Text(course.teacher)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            Text(course.timeRangeString)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
