import Foundation

/// 節次資料模型（支援大專院校常規節次、早自修 M、中午 N、夜間 R 及 1~14 節）
public struct Period: Identifiable, Codable, Hashable {
    public var id: String           // 節次唯一標識（例如: "M", "1", "2", "3", "4", "N", "5", "6", "7", "8", "9", "R", "10", ...）
    public var name: String         // 節次完整名稱（例如: "第 1 節", "中午 N", "第 5 節"）
    public var shortName: String    // 簡稱（例如: "1", "N", "5"）
    public var startTime: TimeOfDay // 開始時間點（例如: 08:10）
    public var endTime: TimeOfDay   // 結束時間點（例如: 09:00）

    public init(
        id: String,
        name: String,
        shortName: String? = nil,
        startTime: TimeOfDay,
        endTime: TimeOfDay
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName ?? id
        self.startTime = startTime
        self.endTime = endTime
    }

    /// 格式化時間區間文字（例如: "08:10 - 09:00"）
    public var timeRangeString: String {
        "\(startTime.formatted) - \(endTime.formatted)"
    }

    /// 亞洲大學及多數大專院校標準節次時刻表預設集
    public static var asiaUniversityStandardPeriods: [Period] {
        [
            Period(id: "M", name: "晨間 M", shortName: "M", startTime: TimeOfDay(hour: 7, minute: 30), endTime: TimeOfDay(hour: 8, minute: 0)),
            Period(id: "1", name: "第 1 節", shortName: "1", startTime: TimeOfDay(hour: 8, minute: 10), endTime: TimeOfDay(hour: 9, minute: 0)),
            Period(id: "2", name: "第 2 節", shortName: "2", startTime: TimeOfDay(hour: 9, minute: 10), endTime: TimeOfDay(hour: 10, minute: 0)),
            Period(id: "3", name: "第 3 節", shortName: "3", startTime: TimeOfDay(hour: 10, minute: 10), endTime: TimeOfDay(hour: 11, minute: 0)),
            Period(id: "4", name: "第 4 節", shortName: "4", startTime: TimeOfDay(hour: 11, minute: 10), endTime: TimeOfDay(hour: 12, minute: 0)),
            Period(id: "N", name: "中午 N", shortName: "N", startTime: TimeOfDay(hour: 12, minute: 10), endTime: TimeOfDay(hour: 13, minute: 0)),
            Period(id: "5", name: "第 5 節", shortName: "5", startTime: TimeOfDay(hour: 13, minute: 10), endTime: TimeOfDay(hour: 14, minute: 0)),
            Period(id: "6", name: "第 6 節", shortName: "6", startTime: TimeOfDay(hour: 14, minute: 10), endTime: TimeOfDay(hour: 15, minute: 0)),
            Period(id: "7", name: "第 7 節", shortName: "7", startTime: TimeOfDay(hour: 15, minute: 10), endTime: TimeOfDay(hour: 16, minute: 0)),
            Period(id: "8", name: "第 8 節", shortName: "8", startTime: TimeOfDay(hour: 16, minute: 10), endTime: TimeOfDay(hour: 17, minute: 0)),
            Period(id: "9", name: "第 9 節", shortName: "9", startTime: TimeOfDay(hour: 17, minute: 10), endTime: TimeOfDay(hour: 18, minute: 0)),
            Period(id: "R", name: "傍晚 R", shortName: "R", startTime: TimeOfDay(hour: 18, minute: 0), endTime: TimeOfDay(hour: 18, minute: 25)),
            Period(id: "10", name: "第 10 節", shortName: "10", startTime: TimeOfDay(hour: 18, minute: 25), endTime: TimeOfDay(hour: 19, minute: 10)),
            Period(id: "11", name: "第 11 節", shortName: "11", startTime: TimeOfDay(hour: 19, minute: 10), endTime: TimeOfDay(hour: 19, minute: 55)),
            Period(id: "12", name: "第 12 節", shortName: "12", startTime: TimeOfDay(hour: 20, minute: 0), endTime: TimeOfDay(hour: 20, minute: 45)),
            Period(id: "13", name: "第 13 節", shortName: "13", startTime: TimeOfDay(hour: 20, minute: 50), endTime: TimeOfDay(hour: 21, minute: 35)),
            Period(id: "14", name: "第 14 節", shortName: "14", startTime: TimeOfDay(hour: 21, minute: 35), endTime: TimeOfDay(hour: 22, minute: 20))
        ]
    }
}
