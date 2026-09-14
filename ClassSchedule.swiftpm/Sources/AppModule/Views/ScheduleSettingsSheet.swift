import SwiftUI

/// 課表節次與檢視設定彈窗（全正體中文）
public struct ScheduleSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CourseStore

    @State private var showWeekend: Bool = false
    @State private var cellHeightPreset: CellHeightPreset = .standard
    @State private var showCredits: Bool = true
    @State private var showTeacher: Bool = true
    @State private var showingClearAlert = false
    @State private var showingResetAlert = false

    enum CellHeightPreset: CGFloat, CaseIterable, Identifiable {
        case compact = 52.0
        case standard = 65.0
        case spacious = 80.0
        case extraSpacious = 96.0

        var id: CGFloat { rawValue }

        var title: String {
            switch self {
            case .compact: return "緊湊"
            case .standard: return "標準"
            case .spacious: return "寬敞"
            case .extraSpacious: return "超大"
            }
        }
    }

    public init(store: CourseStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: 1. 格子尺寸比例
                Section {
                    Picker("格子高度", selection: $cellHeightPreset) {
                        ForEach(CellHeightPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("格子尺寸縮放")
                } footer: {
                    Text("可依據個人喜好與螢幕大小自由調節每節課的高度比例。")
                }

                // MARK: 2. 檢視範圍
                Section {
                    Toggle("顯示週末 (週六與週日)", isOn: $showWeekend)
                } header: {
                    Text("課表檢視範圍")
                } footer: {
                    Text(showWeekend ? "目前呈現週一至週日全週 7 天課表。" : "關閉後僅呈現週一至週五 5 天課表，在 iPad 螢幕上每一天的格子更加寬闊方正。")
                }

                // MARK: 3. 卡片呈現設定
                Section("卡片內容顯示") {
                    Toggle("顯示學分數", isOn: $showCredits)
                    Toggle("顯示授課教師", isOn: $showTeacher)
                }

                // MARK: 4. 節次資訊
                Section("節次配置架構") {
                    HStack {
                        Text("節次排程標準")
                        Spacer()
                        Text("亞洲大學 / 大專標準 14 節")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("總計節次數")
                        Spacer()
                        Text("\(store.settings.periods.count) 節")
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: 5. 資料維護
                Section("資料維護與重設") {
                    HStack {
                        Text("目前已排入課程")
                        Spacer()
                        Text("\(store.courses.count) 門課程")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showingResetAlert = true
                    } label: {
                        Text("恢復載入亞洲大學示範課表")
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
            .alert("確定恢復亞洲大學示範課表？", isPresented: $showingResetAlert) {
                Button("取消", role: .cancel) {}
                Button("確定載入") {
                    store.importCourses(ScheduleParser.asiaUniversitySampleCourses, autoAdjustSettings: true)
                    dismiss()
                }
            } message: {
                Text("這將載入汪俊鋒同學亞洲大學 115 學年度的 29 學分完整課表資料。")
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
                self.showWeekend = store.settings.showWeekend
                self.showCredits = store.settings.showCredits
                self.showTeacher = store.settings.showTeacher
                if let matched = CellHeightPreset.allCases.first(where: { abs($0.rawValue - store.settings.gridCellHeight) < 4 }) {
                    self.cellHeightPreset = matched
                }
            }
        }
    }

    private func saveAndDismiss() {
        var newSettings = store.settings
        newSettings.showWeekend = showWeekend
        newSettings.gridCellHeight = cellHeightPreset.rawValue
        newSettings.showCredits = showCredits
        newSettings.showTeacher = showTeacher
        store.updateSettings(newSettings)
        dismiss()
    }
}
