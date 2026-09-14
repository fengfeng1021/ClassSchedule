import Foundation
import SwiftUI

/// 課表節次矩陣與視圖自訂設定（全正體中文）
public struct ScheduleSettings: Codable, Equatable {
    /// 包含的所有節次列表（依序排列，預設使用亞洲大學標準節次）
    public var periods: [Period]

    /// 是否顯示週末 (週六與週日，預設 false 僅顯示週一至週五)
    public var showWeekend: Bool

    /// 每一節格子在網格中的高度像素 (預設 65.0，可自由快捷縮放)
    public var gridCellHeight: CGFloat

    /// 是否在格子內顯示學分數
    public var showCredits: Bool

    /// 是否在格子內顯示授課教師
    public var showTeacher: Bool

    public init(
        periods: [Period] = Period.asiaUniversityStandardPeriods,
        showWeekend: Bool = false,
        gridCellHeight: CGFloat = 65.0,
        showCredits: Bool = true,
        showTeacher: Bool = true
    ) {
        self.periods = periods.isEmpty ? Period.asiaUniversityStandardPeriods : periods
        self.showWeekend = showWeekend
        self.gridCellHeight = max(40.0, min(gridCellHeight, 110.0))
        self.showCredits = showCredits
        self.showTeacher = showTeacher
    }

    /// 目前顯示的星期陣列 (1: 週一 ... 5: 週五，或 1...7)
    public var visibleDays: [Int] {
        showWeekend ? Array(1...7) : Array(1...5)
    }

    /// 依據 ID 查找節次
    public func period(for id: String) -> Period? {
        periods.first { $0.id == id }
    }

    /// 取得節次在清單中的索引
    public func indexOfPeriod(id: String) -> Int? {
        periods.firstIndex { $0.id == id }
    }
}
