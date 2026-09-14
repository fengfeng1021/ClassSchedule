import Foundation
import SwiftUI

/// 桌面小工具（WidgetKit）顯示模式
public enum WidgetDisplayMode: String, Codable, CaseIterable, Identifiable {
    case classroomFocus = "教室速查"
    case dailyTimeline = "今日日程"
    case countdown = "簡約倒數"

    public var id: String { rawValue }

    /// 模式簡短說明
    public var description: String {
        switch self {
        case .classroomFocus:
            return "專為換教室設計，醒目呈現當前或下一節「教室代碼」與倒數"
        case .dailyTimeline:
            return "條列今日所有節次、課程名稱與教室地點，進度一目了然"
        case .countdown:
            return "極簡視覺風格，大字顯示下堂課倒數時間與課程簡稱"
        }
    }

    /// 對應系統圖示
    public var iconName: String {
        switch self {
        case .classroomFocus:
            return "mappin.and.ellipse"
        case .dailyTimeline:
            return "list.bullet.rectangle"
        case .countdown:
            return "timer"
        }
    }
}

/// 桌面小工具主題外觀
public enum WidgetTheme: String, Codable, CaseIterable, Identifiable {
    case systemBlur = "系統毛玻璃"
    case courseColor = "課程代表色"
    case darkOLED = "純黑極簡"
    case softGradient = "柔和漸層"

    public var id: String { rawValue }
}

/// 桌面小工具尺寸預覽類型
public enum WidgetPreviewSize: String, CaseIterable, Identifiable {
    case small = "小型 (2×2)"
    case medium = "中型 (2×4)"
    case large = "大型 (4×4)"
    case accessory = "鎖定畫面"

    public var id: String { rawValue }
}

/// 桌面小工具使用者偏好設定模型（全正體中文）
public struct WidgetSettings: Codable, Equatable {
    /// 當前選定的顯示模式
    public var displayMode: WidgetDisplayMode

    /// 小工具視覺主題
    public var theme: WidgetTheme

    /// 是否顯示教室位置
    public var showClassroom: Bool

    /// 是否特大加粗顯示教室編號 (例如: M008)
    public var highlightClassroom: Bool

    /// 是否顯示授課教師姓名
    public var showTeacher: Bool

    /// 是否顯示上課節次與時段
    public var showPeriodTime: Bool

    /// 是否顯示學分數
    public var showCredits: Bool

    /// 距離上課倒數提醒 (分鐘)
    public var upcomingReminderMinutes: Int

    /// 無課時是否顯示貼心提示語句
    public var showInspirationalQuote: Bool

    public init(
        displayMode: WidgetDisplayMode = .classroomFocus,
        theme: WidgetTheme = .systemBlur,
        showClassroom: Bool = true,
        highlightClassroom: Bool = true,
        showTeacher: Bool = true,
        showPeriodTime: Bool = true,
        showCredits: Bool = true,
        upcomingReminderMinutes: Int = 30,
        showInspirationalQuote: Bool = true
    ) {
        self.displayMode = displayMode
        self.theme = theme
        self.showClassroom = showClassroom
        self.highlightClassroom = highlightClassroom
        self.showTeacher = showTeacher
        self.showPeriodTime = showPeriodTime
        self.showCredits = showCredits
        self.upcomingReminderMinutes = upcomingReminderMinutes
        self.showInspirationalQuote = showInspirationalQuote
    }
}
