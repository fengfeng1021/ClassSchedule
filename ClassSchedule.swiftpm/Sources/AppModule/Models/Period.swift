import Foundation

/// 節次資料模型（支援全球大專院校與中學通用節次、自訂時長、自訂起訖時間）
public struct Period: Identifiable, Codable, Hashable {
    public var id: String           // 節次唯一標識（例如: "1", "2", "3", "M", "N", ...）
    public var name: String         // 節次完整名稱（例如: "第 1 節", "第 2 節"）
    public var shortName: String    // 簡稱（例如: "1", "2"）
    public var startTime: TimeOfDay // 開始時間點（例如: 08:10）
    public var endTime: TimeOfDay   // 結束時間點（例如: 09:00）
    public var isEnabled: Bool      // 是否啟用此節次（預設 true）

    public init(
        id: String,
        name: String,
        shortName: String? = nil,
        startTime: TimeOfDay,
        endTime: TimeOfDay,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName ?? id
        self.startTime = startTime
        self.endTime = endTime
        self.isEnabled = isEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.shortName = try container.decodeIfPresent(String.self, forKey: .shortName) ?? id
        self.startTime = try container.decode(TimeOfDay.self, forKey: .startTime)
        self.endTime = try container.decode(TimeOfDay.self, forKey: .endTime)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }

    /// 格式化時間區間文字（例如: "08:10 - 09:00"）
    public var timeRangeString: String {
        "\(startTime.formatted) - \(endTime.formatted)"
    }

    /// 依據通用規則動態批次生成連續節次（適用於任何大專院校與高中）
    public static func generatePeriods(
        count: Int,
        firstStartHour: Int,
        firstStartMinute: Int,
        periodDurationMinutes: Int,
        breakDurationMinutes: Int
    ) -> [Period] {
        var result: [Period] = []
        var currentMinutes = firstStartHour * 60 + firstStartMinute

        for i in 1...max(count, 1) {
            let startH = (currentMinutes / 60) % 24
            let startM = currentMinutes % 60
            let endMinutes = currentMinutes + periodDurationMinutes
            let endH = (endMinutes / 60) % 24
            let endM = endMinutes % 60

            let period = Period(
                id: "\(i)",
                name: "第 \(i) 節",
                shortName: "\(i)",
                startTime: TimeOfDay(hour: startH, minute: startM),
                endTime: TimeOfDay(hour: endH, minute: endM),
                isEnabled: true
            )
            result.append(period)
            currentMinutes = endMinutes + breakDurationMinutes
        }
        return result
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
