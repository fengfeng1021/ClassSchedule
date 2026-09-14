import SwiftUI

/// 課表節次時段與全域檢視設定彈窗（支援各大專院校與中學通用時段自訂、各節次起訖時間自由微調）
public struct ScheduleSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CourseStore

    // 節次列表編輯快取
    @State private var periods: [Period] = []

    // 快速產生規則參數
    @State private var ruleCount: Int = 10
    @State private var ruleStartTime = Calendar.current.date(bySettingHour: 8, minute: 10, second: 0, of: Date()) ?? Date()
    @State private var ruleDuration: Int = 50
    @State private var ruleBreak: Int = 10
    @State private var isRuleExpanded: Bool = false

    // 當前展開編輯起訖時間的節次 ID
    @State private var expandedPeriodId: String?

    // 檢視範圍與顯示偏好
    @State private var showWeekend: Bool = false
    @State private var showCredits: Bool = true
    @State private var showTeacher: Bool = true
    @State private var showingClearAlert = false
    @State private var showingSuccessToast = false
    @State private var toastMessage = ""

    public init(store: CourseStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: 1. 通用節次規則批次產生器
                Section {
                    DisclosureGroup("依通用規則快速計算所有節次", isExpanded: $isRuleExpanded) {
                        VStack(spacing: 12) {
                            Stepper("每日節次數量: \(ruleCount) 節", value: $ruleCount, in: 4...16)

                            DatePicker("第一節開始時間", selection: $ruleStartTime, displayedComponents: .hourAndMinute)

                            HStack {
                                Text("每節課時長")
                                Spacer()
                                Picker("時長", selection: $ruleDuration) {
                                    Text("45 分鐘").tag(45)
                                    Text("50 分鐘").tag(50)
                                    Text("55 分鐘").tag(55)
                                    Text("60 分鐘").tag(60)
                                    Text("90 分鐘").tag(90)
                                }
                                .pickerStyle(.menu)
                            }

                            HStack {
                                Text("課間休息時間")
                                Spacer()
                                Picker("休息", selection: $ruleBreak) {
                                    Text("5 分鐘").tag(5)
                                    Text("10 分鐘").tag(10)
                                    Text("15 分鐘").tag(15)
                                    Text("20 分鐘").tag(20)
                                }
                                .pickerStyle(.menu)
                            }

                            Button {
                                applyRuleGeneration()
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("套用此規則並重新生成節次")
                                        .fontWeight(.bold)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                    }

                    // 快速載入常用範本
                    Menu("套用常用院校預設範本") {
                        Button("標準大專院校 (1~8 節 · 08:10 起)") {
                            periods = Period.generatePeriods(count: 8, firstStartHour: 8, firstStartMinute: 10, periodDurationMinutes: 50, breakDurationMinutes: 10)
                            showToast("已套用標準 8 節時段")
                        }
                        Button("標準大專院校 (1~10 節 · 08:10 起)") {
                            periods = Period.generatePeriods(count: 10, firstStartHour: 8, firstStartMinute: 10, periodDurationMinutes: 50, breakDurationMinutes: 10)
                            showToast("已套用標準 10 節時段")
                        }
                        Button("亞洲大學完整時段 (含 M/N/R 傍晚與夜間)") {
                            periods = Period.asiaUniversityStandardPeriods
                            showToast("已套用亞洲大學標準時段")
                        }
                    }
                } header: {
                    Text("節次時段快速設定")
                } footer: {
                    Text("支援各大專院校與中學自主排程，可設定任意節次數量與課堂時長。")
                }

                // MARK: 2. 各節次詳細清單與起訖時間微調
                Section {
                    ForEach($periods) { $period in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Toggle(isOn: $period.isEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(period.name)
                                            .font(.body.weight(.semibold))
                                        Text("\(period.startTime.formatted) ~ \(period.endTime.formatted)")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expandedPeriodId == period.id {
                                            expandedPeriodId = nil
                                        } else {
                                            expandedPeriodId = period.id
                                        }
                                    }
                                } label: {
                                    Image(systemName: expandedPeriodId == period.id ? "chevron.up.circle.fill" : "pencil.circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("編輯時間")
                            }

                            if expandedPeriodId == period.id {
                                VStack(spacing: 8) {
                                    Divider()
                                    DatePicker("開始時間", selection: Binding(
                                        get: { period.startTime.toDate() },
                                        set: { period.startTime = TimeOfDay(date: $0) }
                                    ), displayedComponents: .hourAndMinute)

                                    DatePicker("結束時間", selection: Binding(
                                        get: { period.endTime.toDate() },
                                        set: { period.endTime = TimeOfDay(date: $0) }
                                    ), displayedComponents: .hourAndMinute)
                                }
                                .padding(.top, 4)
                                .padding(.bottom, 2)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    Button {
                        addNewPeriod()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("新增自訂節次")
                        }
                    }
                } header: {
                    HStack {
                        Text("節次列表與時間微調")
                        Spacer()
                        Text("共 \(periods.filter { $0.isEnabled }.count) 節啟用")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("可單獨開關節次或點選右側圖示手動修改具體起訖時間。未啟用的節次不會佔用課表畫面。")
                }

                // MARK: 3. 星期檢視範圍
                Section {
                    Toggle("顯示週末 (週六與週日)", isOn: $showWeekend)
                } header: {
                    Text("星期檢視範圍")
                } footer: {
                    Text(showWeekend ? "目前呈現週一至週日全週 7 天課表。" : "關閉後僅呈現週一至週五 5 天課表，在螢幕上每一天的格子更加方正寬敞。")
                }

                // MARK: 4. 卡片內容顯示
                Section("卡片內容顯示") {
                    Toggle("顯示學分數", isOn: $showCredits)
                    Toggle("顯示授課教師", isOn: $showTeacher)
                }

                // MARK: 5. 資料維護
                Section("資料維護") {
                    HStack {
                        Text("目前已排入課程")
                        Spacer()
                        Text("\(store.courses.count) 門課程")
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        showingClearAlert = true
                    } label: {
                        Text("清空目前所有課程")
                    }
                }
            }
            .navigationTitle("課表設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        saveAndDismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .alert("確認清空所有課程？", isPresented: $showingClearAlert) {
                Button("取消", role: .cancel) {}
                Button("清空", role: .destructive) {
                    store.courses.removeAll()
                    store.save()
                    dismiss()
                }
            } message: {
                Text("此動作不可撤銷，已排入的課程資料將全數移除。")
            }
            .onAppear {
                self.periods = store.settings.periods
                self.showWeekend = store.settings.showWeekend
                self.showCredits = store.settings.showCredits
                self.showTeacher = store.settings.showTeacher
            }
        }
    }

    private func applyRuleGeneration() {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: ruleStartTime)
        let minute = cal.component(.minute, from: ruleStartTime)
        periods = Period.generatePeriods(
            count: ruleCount,
            firstStartHour: hour,
            firstStartMinute: minute,
            periodDurationMinutes: ruleDuration,
            breakDurationMinutes: ruleBreak
        )
        isRuleExpanded = false
        showToast("已成功產生 \(ruleCount) 個節次時段！")
    }

    private func addNewPeriod() {
        let nextIndex = periods.count + 1
        let lastEnd = periods.last?.endTime ?? TimeOfDay(hour: 8, minute: 0)
        let startMin = lastEnd.totalMinutes + 10
        let endMin = startMin + 50
        let newPeriod = Period(
            id: "\(nextIndex)",
            name: "第 \(nextIndex) 節",
            shortName: "\(nextIndex)",
            startTime: TimeOfDay(hour: (startMin / 60) % 24, minute: startMin % 60),
            endTime: TimeOfDay(hour: (endMin / 60) % 24, minute: endMin % 60),
            isEnabled: true
        )
        periods.append(newPeriod)
        expandedPeriodId = newPeriod.id
    }

    private func showToast(_ msg: String) {
        toastMessage = msg
        showingSuccessToast = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func saveAndDismiss() {
        var newSettings = store.settings
        newSettings.periods = periods
        newSettings.showWeekend = showWeekend
        newSettings.showCredits = showCredits
        newSettings.showTeacher = showTeacher
        store.updateSettings(newSettings)
        dismiss()
    }
}
