import SwiftUI

/// 課程新增 / 編輯表單視圖（全正體中文，支援大專院校節次快速選擇與連堂設定）
public struct CourseEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CourseStore

    var courseToEdit: Course?
    var initialDay: Int?
    var initialPeriodId: String?

    @State private var name: String = ""
    @State private var teacher: String = ""
    @State private var classroom: String = ""
    @State private var credits: String = "3學分"
    @State private var dayOfWeek: Int = 1
    @State private var startPeriodId: String = "1"
    @State private var endPeriodId: String = "1"
    @State private var selectedColor: String = "indigo"
    @State private var notes: String = ""
    @State private var showingDeleteAlert = false

    private let availableColors = [
        "indigo", "blue", "teal", "mint", "green", "orange", "purple", "pink", "red"
    ]

    private var isEditing: Bool {
        courseToEdit != nil
    }

    private var periods: [Period] {
        store.settings.periods
    }

    private var spanCount: Int {
        let startIndex = store.settings.indexOfPeriod(id: startPeriodId) ?? 0
        let endIndex = store.settings.indexOfPeriod(id: endPeriodId) ?? startIndex
        return max(endIndex - startIndex + 1, 1)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !classroom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init(
        store: CourseStore,
        courseToEdit: Course? = nil,
        initialDay: Int? = nil,
        initialPeriodId: String? = nil
    ) {
        self.store = store
        self.courseToEdit = courseToEdit
        self.initialDay = initialDay
        self.initialPeriodId = initialPeriodId
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: 課程基本資訊
                Section {
                    HStack(spacing: 12) {
                        Label {
                            TextField("課程名稱 (如: 商業模式創新 B)", text: $name)
                        } icon: {
                            Image(systemName: "book.closed.fill")
                                .foregroundStyle(colorForName(selectedColor))
                        }
                    }

                    HStack(spacing: 12) {
                        Label {
                            TextField("上課教室 (如: M008 或 創意工坊)", text: $classroom)
                        } icon: {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(.red)
                        }
                    }

                    HStack(spacing: 12) {
                        Label {
                            TextField("授課教師 (如: 黃建元 教授)", text: $teacher)
                        } icon: {
                            Image(systemName: "person.crop.circle")
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        Label {
                            TextField("學分數 (如: 3學分)", text: $credits)
                        } icon: {
                            Image(systemName: "graduationcap")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("基本資訊")
                } footer: {
                    Text("上課教室地點將在課表格子與頂部即時橫幅以醒目大字凸顯，助您準確趕往教室。")
                }

                // MARK: 星期與節次安排
                Section {
                    Picker("星期", selection: $dayOfWeek) {
                        ForEach(1...7, id: \.self) { day in
                            Text(Course.dayName(for: day)).tag(day)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("起始節次", selection: $startPeriodId) {
                        ForEach(periods) { period in
                            Text("\(period.name) (\(period.startTime.formatted))").tag(period.id)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("結束節次", selection: $endPeriodId) {
                        ForEach(periods) { period in
                            Text("\(period.name) (\(period.endTime.formatted))").tag(period.id)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("時段安排")
                } footer: {
                    Text("共計 \(spanCount) 節課。建立後亦可在課表首頁直接拖曳卡片邊框快速多選或縮減節次。")
                }

                // MARK: 課程主題色彩
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

                // MARK: 備註與考核說明
                Section("備註與說明") {
                    TextField("選修/必修、實習教室、分組報告說明等...", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }

                // MARK: 編輯模式下的刪除操作
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("刪除此門課程")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "編輯課程" : "新增課程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        saveCourse()
                        dismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .alert("確定要刪除這門課程？", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("刪除", role: .destructive) {
                    if let course = courseToEdit {
                        store.delete(course)
                    }
                    dismiss()
                }
            } message: {
                Text("刪除後將從課表格子中移除該課程及其教室時段。")
            }
            .onAppear {
                initializeData()
            }
        }
    }

    private func initializeData() {
        if let course = courseToEdit {
            self.name = course.name
            self.teacher = course.teacher
            self.classroom = course.classroom
            self.credits = course.credits
            self.dayOfWeek = course.dayOfWeek
            self.startPeriodId = course.startPeriodId
            self.endPeriodId = course.endPeriodId
            self.selectedColor = course.colorName
            self.notes = course.notes
        } else {
            if let day = initialDay {
                self.dayOfWeek = day
            }
            if let periodId = initialPeriodId {
                self.startPeriodId = periodId
                self.endPeriodId = periodId
            }
        }
    }

    private func saveCourse() {
        guard let startP = store.settings.period(for: startPeriodId),
              let endP = store.settings.period(for: endPeriodId) else { return }

        // 確保起始與結束順序
        let startIndex = store.settings.indexOfPeriod(id: startPeriodId) ?? 0
        let endIndex = store.settings.indexOfPeriod(id: endPeriodId) ?? startIndex

        let finalStartId = startIndex <= endIndex ? startPeriodId : endPeriodId
        let finalEndId = startIndex <= endIndex ? endPeriodId : startPeriodId
        let finalStartTime = startIndex <= endIndex ? startP.startTime : endP.startTime
        let finalEndTime = startIndex <= endIndex ? endP.endTime : startP.endTime

        if var course = courseToEdit {
            course.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            course.teacher = teacher.trimmingCharacters(in: .whitespacesAndNewlines)
            course.classroom = classroom.trimmingCharacters(in: .whitespacesAndNewlines)
            course.credits = credits.trimmingCharacters(in: .whitespacesAndNewlines)
            course.dayOfWeek = dayOfWeek
            course.startPeriodId = finalStartId
            course.endPeriodId = finalEndId
            course.startTime = finalStartTime
            course.endTime = finalEndTime
            course.colorName = selectedColor
            course.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            store.update(course)
        } else {
            let newCourse = Course(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                teacher: teacher.trimmingCharacters(in: .whitespacesAndNewlines),
                classroom: classroom.trimmingCharacters(in: .whitespacesAndNewlines),
                credits: credits.trimmingCharacters(in: .whitespacesAndNewlines),
                dayOfWeek: dayOfWeek,
                startPeriodId: finalStartId,
                endPeriodId: finalEndId,
                startTime: finalStartTime,
                endTime: finalEndTime,
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
