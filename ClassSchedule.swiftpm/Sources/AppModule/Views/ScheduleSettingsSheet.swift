import SwiftUI

/// 课表时间轴与排课设置弹窗
public struct ScheduleSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CourseStore

    @State private var startHour: Int = 8
    @State private var endHour: Int = 21
    @State private var showWeekend: Bool = false
    @State private var hourHeightPreset: HourHeightPreset = .standard
    @State private var showingClearAlert = false

    enum HourHeightPreset: CGFloat, CaseIterable, Identifiable {
        case compact = 52.0
        case standard = 64.0
        case spacious = 78.0

        var id: CGFloat { rawValue }

        var title: String {
            switch self {
            case .compact: return "紧凑"
            case .standard: return "标准"
            case .spacious: return "宽阔"
            }
        }
    }

    public init(store: CourseStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: 1. 时间轴跨度
                Section {
                    Picker("最早起始时间", selection: $startHour) {
                        ForEach(6...10, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }

                    Picker("最晚结束时间", selection: $endHour) {
                        ForEach(18...23, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }
                } header: {
                    Text("时间轴跨度")
                } footer: {
                    Text("根据你所在学校的最早晨课与最晚晚自习时间灵活调整，时间轴将精确展示该区间内的所有课程。")
                }

                // MARK: 2. 周末显示
                Section {
                    Toggle("显示周末 (周六与周日)", isOn: $showWeekend)
                } header: {
                    Text("视图范围")
                } footer: {
                    Text(showWeekend ? "当前显示周一至周日全周 7 天课表。" : "关闭后仅显示周一至周五 5 天课表，在 iPad 上每一列将更宽阔方正。")
                }

                // MARK: 3. 网格行高比例
                Section("网格行高比例") {
                    Picker("行高比例", selection: $hourHeightPreset) {
                        ForEach(HourHeightPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: 4. 统计与维护
                Section("数据维护") {
                    HStack {
                        Text("当前已录入课程")
                        Spacer()
                        Text("\(store.courses.count) 门")
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        showingClearAlert = true
                    } label: {
                        Text("清空所有课程数据")
                    }
                }
            }
            .navigationTitle("课表设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("确认清空所有课程？", isPresented: $showingClearAlert) {
                Button("取消", role: .cancel) {}
                Button("清空", role: .destructive) {
                    store.courses.removeAll()
                    store.save()
                }
            } message: {
                Text("此操作不可撤销，已录入的课程将全部删除。")
            }
            .onAppear {
                self.startHour = store.settings.startHour
                self.endHour = store.settings.endHour
                self.showWeekend = store.settings.showWeekend
                if let matched = HourHeightPreset.allCases.first(where: { abs($0.rawValue - store.settings.hourHeight) < 5 }) {
                    self.hourHeightPreset = matched
                }
            }
        }
    }

    private func saveAndDismiss() {
        let finalEnd = max(startHour + 4, endHour)
        let newSettings = ScheduleSettings(
            startHour: startHour,
            endHour: finalEnd,
            showWeekend: showWeekend,
            hourHeight: hourHeightPreset.rawValue
        )
        store.updateSettings(newSettings)
        dismiss()
    }
}
