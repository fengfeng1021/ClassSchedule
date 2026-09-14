import Foundation
import SwiftUI

/// 課表節次矩陣與檢視自訂設定（全正體中文）
public struct ScheduleSettings: Codable, Equatable {
    /// 包含的所有節次列表（依序排列）
    public var periods: [Period]

    /// 是否顯示晨間 M 時段 (07:30 ~ 08:00，預設 false)
    public var showMorningM: Bool

    /// 是否顯示中午 N 時段 (12:10 ~ 13:00，預設 true)
    public var showNoonN: Bool

    /// 是否顯示夜間時段 (第 10~14 節及 R 時段，預設 false，可自由開啟)
    public var showEveningPeriods: Bool

    /// 是否顯示週末 (週六與週日，預設 false 僅顯示週一至週五)
    public var showWeekend: Bool

    /// 是否在格子內顯示學分數
    public var showCredits: Bool

    /// 是否在格子內顯示授課教師
    public var showTeacher: Bool

    /// 桌面小工具設定
    public var widgetSettings: WidgetSettings

    public init(
        periods: [Period] = Period.asiaUniversityStandardPeriods,
        showMorningM: Bool = false,
        showNoonN: Bool = true,
        showEveningPeriods: Bool = false,
        showWeekend: Bool = false,
        showCredits: Bool = true,
        showTeacher: Bool = true,
        widgetSettings: WidgetSettings = WidgetSettings()
    ) {
        self.periods = periods.isEmpty ? Period.asiaUniversityStandardPeriods : periods
        self.showMorningM = showMorningM
        self.showNoonN = showNoonN
        self.showEveningPeriods = showEveningPeriods
        self.showWeekend = showWeekend
        self.showCredits = showCredits
        self.showTeacher = showTeacher
        self.widgetSettings = widgetSettings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.periods = try container.decodeIfPresent([Period].self, forKey: .periods) ?? Period.asiaUniversityStandardPeriods
        self.showMorningM = try container.decodeIfPresent(Bool.self, forKey: .showMorningM) ?? false
        self.showNoonN = try container.decodeIfPresent(Bool.self, forKey: .showNoonN) ?? true
        self.showEveningPeriods = try container.decodeIfPresent(Bool.self, forKey: .showEveningPeriods) ?? false
        self.showWeekend = try container.decodeIfPresent(Bool.self, forKey: .showWeekend) ?? false
        self.showCredits = try container.decodeIfPresent(Bool.self, forKey: .showCredits) ?? true
        self.showTeacher = try container.decodeIfPresent(Bool.self, forKey: .showTeacher) ?? true
        self.widgetSettings = try container.decodeIfPresent(WidgetSettings.self, forKey: .widgetSettings) ?? WidgetSettings()
    }

    /// 目前實際參與渲染的活躍節次列表（自動過濾使用者未開啟的時段）
    public var activePeriods: [Period] {
        periods.filter { period in
            if period.id == "M" && !showMorningM {
                return false
            }
            if period.id == "N" && !showNoonN {
                return false
            }
            if ["R", "10", "11", "12", "13", "14"].contains(period.id) && !showEveningPeriods {
                return false
            }
            return true
        }
    }

    /// 目前顯示的星期陣列 (1: 週一 ... 5: 週五，或 1...7)
    public var visibleDays: [Int] {
        showWeekend ? Array(1...7) : Array(1...5)
    }

    /// 依據 ID 查找節次
    public func period(for id: String) -> Period? {
        periods.first { $0.id == id }
    }

    /// 取得節次在活躍清單中的索引
    public func activeIndexOfPeriod(id: String) -> Int? {
        activePeriods.firstIndex { $0.id == id }
    }

    /// 取得節次在完整清單中的索引
    public func indexOfPeriod(id: String) -> Int? {
        periods.firstIndex { $0.id == id }
    }
}
