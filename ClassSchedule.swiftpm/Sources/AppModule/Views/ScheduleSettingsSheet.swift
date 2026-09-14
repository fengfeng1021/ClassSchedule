import SwiftUI

/// 課表節次與檢視設定彈窗（全正體中文，支援自由增減顯示節次與時段）
public struct ScheduleSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CourseStore

    @State private var showMorningM: Bool = false
    @State private var showNoonN: Bool = true
    @State private var showEveningPeriods: Bool = false
    @State private var showWeekend: Bool = false
    @State private var showCredits: Bool = true
    @State private var showTeacher: Bool = true
    @State private var showingClearAlert = false

    public init(store: CourseStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: 1. 節次時段範圍自訂
                Section {
                    Toggle("顯示晨間 M 時段 (07:30 ~ 08:00)", isOn: $showMorningM)
                    Toggle("顯示中午 N 時段 (12:10 ~ 13:00)", isOn: $showNoonN)
                    Toggle("顯示夜間時段 (第 10~14 節及 R 時段)", isOn: $showEveningPeriods)
                } header: {
                    Text("節次時段自訂")
                } footer: {
                    Text("若沒有夜間部或晨間課程，關閉後課表將自動去除下方多餘空白欄位，並等比例放大白天課程格子，填滿螢幕更清晰。")
                }

                // MARK: 2. 檢視範圍
                Section {
                    Toggle("顯示週末 (週六與週日)", isOn: $showWeekend)
                } header: {
                    Text("星期檢視範圍")
                } footer: {
                    Text(showWeekend ? "目前呈現週一至週日全週 7 天課表。" : "關閉後僅呈現週一至週五 5 天課表，在 iPad 螢幕上每一天的格子更加方正寬敞。")
                }

                // MARK: 3. 卡片呈現設定
                Section("卡片內容顯示") {
                    Toggle("顯示學分數", isOn: $showCredits)
                    Toggle("顯示授課教師", isOn: $showTeacher)
                }

                // MARK: 4. 節次資訊統計
                Section("目前配置架構") {
                    HStack {
                        Text("目前顯示節次總數")
                        Spacer()
                        Text("\(store.settings.activePeriods.count) 節")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("全螢幕適應模式")
                        Spacer()
                        Text("一屏全覽 · 免滾動")
                            .foregroundStyle(.blue)
                    }
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
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
                self.showMorningM = store.settings.showMorningM
                self.showNoonN = store.settings.showNoonN
                self.showEveningPeriods = store.settings.showEveningPeriods
                self.showWeekend = store.settings.showWeekend
                self.showCredits = store.settings.showCredits
                self.showTeacher = store.settings.showTeacher
            }
        }
    }

    private func saveAndDismiss() {
        var newSettings = store.settings
        newSettings.showMorningM = showMorningM
        newSettings.showNoonN = showNoonN
        newSettings.showEveningPeriods = showEveningPeriods
        newSettings.showWeekend = showWeekend
        newSettings.showCredits = showCredits
        newSettings.showTeacher = showTeacher
        store.updateSettings(newSettings)
        dismiss()
    }
}
