import SwiftUI

/// 课程添加 / 编辑表单视图 (遵循 Apple HIG 原生表单规范)
public struct CourseEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CourseStore

    var courseToEdit: Course?

    @State private var name: String = ""
    @State private var teacher: String = ""
    @State private var classroom: String = ""
    @State private var dayOfWeek: Int = 1
    @State private var startDate: Date = Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: Date()) ?? Date()
    @State private var endDate: Date = Calendar.current.date(bySettingHour: 10, minute: 5, second: 0, of: Date()) ?? Date()
    @State private var selectedColor: String = "indigo"
    @State private var notes: String = ""
    @State private var showingDeleteAlert = false

    private let availableColors = [
        "indigo", "blue", "teal", "mint", "green", "orange", "purple", "pink", "red"
    ]

    private var isEditing: Bool {
        courseToEdit != nil
    }

    private var durationMinutes: Int {
        let start = TimeOfDay(date: startDate)
        let end = TimeOfDay(date: endDate)
        return max(end.totalMinutes - start.totalMinutes, 0)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !classroom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        durationMinutes > 0
    }

    public init(store: CourseStore, courseToEdit: Course? = nil) {
        self.store = store
        self.courseToEdit = courseToEdit
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: 课程基础信息
                Section {
                    HStack(spacing: 12) {
                        Label {
                            TextField("课程名称 (如: 高等数学)", text: $name)
                        } icon: {
                            Image(systemName: "book.closed.fill")
                                .foregroundStyle(colorForName(selectedColor))
                        }
                    }

                    HStack(spacing: 12) {
                        Label {
                            TextField("上课教室 (如: 教三楼 302)", text: $classroom)
                        } icon: {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(.red)
                        }
                    }

                    HStack(spacing: 12) {
                        Label {
                            TextField("任课教师 (可选)", text: $teacher)
                        } icon: {
                            Image(systemName: "person.crop.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("基本信息")
                } footer: {
                    Text("教室地点将在课表与小工具中以醒目字号重点展示。")
                }

                // MARK: 时间与星期
                Section {
                    Picker("星期", selection: $dayOfWeek) {
                        ForEach(1...7, id: \.self) { day in
                            Text(Course.dayName(for: day)).tag(day)
                        }
                    }
                    .pickerStyle(.menu)

                    DatePicker("开始时间", selection: $startDate, displayedComponents: .hourAndMinute)
                    DatePicker("结束时间", selection: $endDate, displayedComponents: .hourAndMinute)
                } header: {
                    Text("时间安排")
                } footer: {
                    if durationMinutes > 0 {
                        Text("上课时长：\(durationMinutes) 分钟（将精确映射至课表时间轴对应位置）。")
                    } else {
                        Text("⚠️ 结束时间必须晚于开始时间。")
                            .foregroundStyle(.red)
                    }
                }

                // MARK: 课程主题色
                Section("卡片色彩") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(availableColors, id: \.self) { colorName in
                                ZStack {
                                    Circle()
                                        .fill(colorForName(colorName))
                                        .frame(width: 38, height: 38)

                                    if selectedColor == colorName {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(selectedColor == colorName ? 0.35 : 0.08), lineWidth: 2)
                                )
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedColor = colorName
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }

                // MARK: 备注说明
                Section("备注与考核说明") {
                    TextField("选修/必修、携带教材、课堂小测要求等...", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }

                // MARK: 编辑时提供删除操作
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("删除此课程")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "编辑课程" : "添加课程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveCourse()
                        dismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .alert("确认删除课程？", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let course = courseToEdit {
                        store.delete(course)
                    }
                    dismiss()
                }
            } message: {
                Text("删除后无法恢复该课程的时间与教室记录。")
            }
            .onAppear {
                initializeData()
            }
        }
    }

    private func initializeData() {
        guard let course = courseToEdit else { return }
        self.name = course.name
        self.teacher = course.teacher
        self.classroom = course.classroom
        self.dayOfWeek = course.dayOfWeek
        self.startDate = course.startTime.toDate()
        self.endDate = course.endTime.toDate()
        self.selectedColor = course.colorName
        self.notes = course.notes
    }

    private func saveCourse() {
        let start = TimeOfDay(date: startDate)
        let end = TimeOfDay(date: endDate)

        if var course = courseToEdit {
            course.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            course.teacher = teacher.trimmingCharacters(in: .whitespacesAndNewlines)
            course.classroom = classroom.trimmingCharacters(in: .whitespacesAndNewlines)
            course.dayOfWeek = dayOfWeek
            course.startTime = start
            course.endTime = end
            course.colorName = selectedColor
            course.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            store.update(course)
        } else {
            let newCourse = Course(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                teacher: teacher.trimmingCharacters(in: .whitespacesAndNewlines),
                classroom: classroom.trimmingCharacters(in: .whitespacesAndNewlines),
                dayOfWeek: dayOfWeek,
                startTime: start,
                endTime: end,
                colorName: selectedColor,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            store.add(newCourse)
        }
    }

    private func colorForName(_ name: String) -> Color {
        switch name.lowercased() {
        case "blue": return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "orange": return .orange
        case "green": return .green
        case "mint": return .mint
        case "teal": return .teal
        case "pink": return .pink
        case "red": return .red
        default: return .indigo
        }
    }
}
