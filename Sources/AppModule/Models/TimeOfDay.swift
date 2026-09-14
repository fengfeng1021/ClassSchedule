import Foundation

/// 结构化一天中的具体时间点 (小时:分钟)
public struct TimeOfDay: Codable, Hashable, Comparable, Identifiable {
    public var id: String { formatted }
    
    public var hour: Int    // 0 - 23
    public var minute: Int  // 0 - 59

    public init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    public init(date: Date = Date(), calendar: Calendar = .current) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        self.hour = components.hour ?? 0
        self.minute = components.minute ?? 0
    }

    /// 转换为今日的具体 Date
    public func toDate(baseDate: Date = Date(), calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = self.hour
        components.minute = self.minute
        components.second = 0
        return calendar.date(from: components) ?? baseDate
    }

    /// 格式化为 \"HH:mm\" (如 \"08:30\")
    public var formatted: String {
        String(format: \"%02d:%02d\", hour, minute)
    }

    /// 总分钟数，用于快速比较
    public var totalMinutes: Int {
        hour * 60 + minute
    }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.totalMinutes < rhs.totalMinutes
    }
}
