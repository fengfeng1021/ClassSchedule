import Foundation
import SwiftUI

/// 课表时间轴与视图自定义设置
public struct ScheduleSettings: Codable, Equatable {
    /// 每日最早起始小时 (0-23，默认 8:00)
    public var startHour: Int
    /// 每日最晚结束小时 (0-23，默认 21:00)
    public var endHour: Int
    /// 是否显示周末 (周六与周日，默认 false 仅显示周一至周五以获得更方正的列宽)
    public var showWeekend: Bool
    /// 每小时在网格中的高度像素点 (默认 64.0)
    public var hourHeight: CGFloat

    public init(
        startHour: Int = 8,
        endHour: Int = 21,
        showWeekend: Bool = false,
        hourHeight: CGFloat = 64.0
    ) {
        self.startHour = max(0, min(startHour, 12))
        self.endHour = max(self.startHour + 4, min(endHour, 23))
        self.showWeekend = showWeekend
        self.hourHeight = max(40.0, min(hourHeight, 100.0))
    }

    /// 当前显示的星期数组 (1: 周一 ... 5: 周五，或 1...7)
    public var visibleDays: [Int] {
        showWeekend ? Array(1...7) : Array(1...5)
    }

    /// 总小时数跨度
    public var totalHours: Int {
        max(1, endHour - startHour)
    }
}
