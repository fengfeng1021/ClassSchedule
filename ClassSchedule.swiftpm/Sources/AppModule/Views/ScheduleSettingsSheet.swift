import SwiftUI

/// 課表節次時段與全域檢視設定彈窗（支援各大專院校與中學通用時段自訂、各節次起訖時間自由微調、外觀模式切換）
public struct ScheduleSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CourseStore

    // 節次列表編輯快取
    @State private var periods: [Period] = []

    // 外觀模式
    @State private var appearanceMode: AppAppearanceMode = .system

    // 快速產生規則參數
    @State private var ruleCount: Int = 10
    @State private var ruleStartTime = Calendar.current.date(bySettingHour: 8, minute: 10, second: 0, of: Date()) ?? Date()
    @State private var ruleDuration: Int = 50
    @State private var ruleBreak: Int = 10
    @State private var isRuleExpanded: Bool = false

    // 檢視範圍與顯示偏好
    @State private var showWeekend: Bool = false
    @State private var showCredits: Bool = true
    @State private var showTeacher: Bool = true
    @State private var showingClearAlert = false
    @State private var showingSuccessToast = false
    @State private var toastMessage = ""

    public init(store: CourseStore) {
        self.store = store
        _periods = State(initialValue: store.settings.periods)
        _appearanceMode = State(initialValue: store.settings.appearanceMode)
        _showWeekend = State(initialValue: store.settings.showWeekend)
        _showCredits = State(initialValue: store.settings.showCredits)
        _showTeacher = State(initialValue: store.settings.showTeacher)
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: 1. 外觀模式設定
                Section("外觀風格") {
                    Picker("外觀風格", selection: $appearanceMode) {
                        ForEach(AppAppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: 2. 通用節次規則批次產生器
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

                // MARK: 3. 專屬獨立頁面：各節次詳細清單與起訖時間微調 (避免主頁冗長列出14節)
                Section {
                    NavigationLink {
                        PeriodDetailCustomizationView(periods: $periods)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("自訂節次起訖時間")
                                    .font(.body.weight(.semibold))
                                Text("進入詳細調整各節次時間與單獨開關")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("共 \(periods.filter { $0.isEnabled }.count) 節啟用")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.1), in: Capsule())
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("節次時段管理")
                } footer: {
                    Text("點選進入專屬頁面自訂各節次時間。每行均可直接點擊展開調整時間，或單獨開關節次。未啟用的節次不會佔用課表畫面。")
                }

                // MARK: 4. 星期檢視範圍
                Section {
                    Toggle("顯示週末 (週六與週日)", isOn: $showWeekend)
                } header: {
                    Text("星期檢視範圍")
                } footer: {
                    Text(showWeekend ? "目前呈現週一至週日全週 7 天課表。" : "關閉後僅呈現週一至週五 5 天課表，在螢幕上每一天的格子更加方正寬敞。")
                }

                // MARK: 5. 卡片內容顯示
                Section("卡片內容顯示") {
                    Toggle("顯示學分數", isOn: $showCredits)
                    Toggle("顯示授課教師", isOn: $showTeacher)
                }

                // MARK: 6. 資料維護
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

                // MARK: 7. 版本與 SideStore 更新
                Section {
                    HStack {
                        Text("目前版本")
                        Spacer()
                        Text("v\(AppUpdateService.shared.currentVersion)")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task {
                            await AppUpdateService.shared.checkForUpdates(silent: false)
                        }
                    } label: {
                        HStack {
                            Text("檢查新版本")
                            Spacer()
                            if AppUpdateService.shared.isChecking {
                                ProgressView()
                            }
                        }
                    }

                    Button {
                        let sourceUrl = "https://raw.githubusercontent.com/fengfeng1021/ClassSchedule/main/apps.json"
                        if let encoded = sourceUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                           let url = URL(string: "sidestore://source?url=\(encoded)") {
                            UIApplication.shared.open(url) { success in
                                if !success, let altUrl = URL(string: "altstore://source?url=\(encoded)") {
                                    UIApplication.shared.open(altUrl)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Label("將課表加入 SideStore 官方源", systemImage: "plus.app")
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("版本與更新")
                } footer: {
                    Text("加入 SideStore 軟體源後，未來有新版時可在 SideStore 內直接點擊 UPDATE 一鍵升級。覆蓋升級沿用同一 App ID，不消耗每週 10 個簽名配額。")
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

    private func showToast(_ msg: String) {
        toastMessage = msg
        showingSuccessToast = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func saveAndDismiss() {
        var newSettings = store.settings
        newSettings.periods = periods
        newSettings.appearanceMode = appearanceMode
        newSettings.showWeekend = showWeekend
        newSettings.showCredits = showCredits
        newSettings.showTeacher = showTeacher
        store.updateSettings(newSettings)
        dismiss()
    }
}

/// 專屬頁面：自訂節次起訖時間（點擊整行直接展開、美觀易操作）
public struct PeriodDetailCustomizationView: View {
    @Binding var periods: [Period]
    @State private var expandedPeriodId: String?

    public var body: some View {
        List {
            Section {
                ForEach($periods) { $period in
                    VStack(alignment: .leading, spacing: 0) {
                        // 點擊整行直接展開或收起起訖時間編輯區
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                if expandedPeriodId == period.id {
                                    expandedPeriodId = nil
                                } else {
                                    expandedPeriodId = period.id
                                }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(period.name)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(period.isEnabled ? .primary : .secondary)

                                        if !period.isEnabled {
                                            Text("已停用")
                                                .font(.caption2.weight(.bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 1.5)
                                                .background(Color.secondary.opacity(0.15), in: Capsule())
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Text("\(period.startTime.formatted) ~ \(period.endTime.formatted)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(period.isEnabled ? .secondary : .tertiary)
                                }

                                Spacer()

                                Toggle("", isOn: $period.isEnabled)
                                    .labelsHidden()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.tertiary)
                                    .rotationEffect(.degrees(expandedPeriodId == period.id ? 90 : 0))
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)

                        // 展開編輯區
                        if expandedPeriodId == period.id {
                            VStack(spacing: 10) {
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
                            .padding(.vertical, 6)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }

                Button {
                    addNewPeriod()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                        Text("新增自訂節次")
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                HStack {
                    Text("節次列表")
                    Spacer()
                    Text("共 \(periods.filter { $0.isEnabled }.count) 節啟用")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("直接點擊任意節次即可展開修改開始與結束時間；點擊開關可啟用或停用該節次。")
            }
        }
        .navigationTitle("調節節次與時間")
        .navigationBarTitleDisplayMode(.inline)
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
        withAnimation {
            expandedPeriodId = newPeriod.id
        }
    }
}
