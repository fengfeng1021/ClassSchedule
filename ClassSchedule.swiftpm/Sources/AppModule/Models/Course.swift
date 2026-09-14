import SwiftUI

/// 課程狀態
public enum CourseStatus: String, Codable {
    case inProgress = "進行中"
    case upcoming = "即將上課"
    case finished = "已結束"
    case future = "未開始"
}

/// 課程實體模型
public struct Course: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String             // 課程名稱 (例如: 商業模式創新 B)
    public var teacher: String          // 授課教師 (例如: 黃建元)
    public var classroom: String        // 上課教室 (例如: M008，核心醒目)
    public var credits: String          // 學分數 (例如: 3學分)
    public var dayOfWeek: Int           // 星期幾 (1: 週一, 2: 週二 ... 7: 週日)
    public var startPeriodId: String    // 起始節次編號 (例如: "2" 或 "N")
    public var endPeriodId: String      // 結束節次編號 (例如: "4" 或 "6")
    public var startTime: TimeOfDay     // 開始時間點
    public var endTime: TimeOfDay       // 結束時間點
    public var colorName: String        // 預設語意化主題色
    public var notes: String            // 備註說明

    public init(
        id: UUID = UUID(),
        name: String,
        teacher: String = "",
        classroom: String = "",
        credits: String = "",
        dayOfWeek: Int = 1,
        startPeriodId: String = "1",
        endPeriodId: String = "1",
        startTime: TimeOfDay = TimeOfDay(hour: 8, minute: 10),
        endTime: TimeOfDay = TimeOfDay(hour: 9, minute: 0),
        colorName: String = "indigo",
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.teacher = teacher
        self.classroom = classroom
        self.credits = credits
        self.dayOfWeek = min(max(dayOfWeek, 1), 7)
        self.startPeriodId = startPeriodId
        self.endPeriodId = endPeriodId
        self.startTime = startTime
        self.endTime = endTime
        self.colorName = colorName
        self.notes = notes
    }

    /// 節次跨度文字（例如: "第 2 - 4 節" 或 "第 1 節"）
    public var periodSpanString: String {
        if startPeriodId == endPeriodId {
            return "第 \(startPeriodId) 節"
        } else {
            return "第 \(startPeriodId) - \(endPeriodId) 節"
        }
    }

    /// 課程時長 (分鐘)
    public var durationMinutes: Int {
        max(endTime.totalMinutes - startTime.totalMinutes, 0)
    }

    /// 時間範圍字串 "08:10 - 10:00"
    public var timeRangeString: String {
        "\(startTime.formatted) - \(endTime.formatted)"
    }

    /// 星期中文顯示
    public var dayOfWeekString: String {
        Self.dayName(for: dayOfWeek)
    }

    public static func dayName(for day: Int) -> String {
        switch day {
        case 1: return "週一"
        case 2: return "週二"
        case 3: return "週三"
        case 4: return "週四"
        case 5: return "週五"
        case 6: return "週六"
        case 7: return "週日"
        default: return ""
        }
    }

    /// 計算在指定時刻的狀態
    public func status(at date: Date = Date(), calendar: Calendar = .current) -> CourseStatus {
        let currentDay = calendar.component(.weekday, from: date)
        // 蘋果 Calendar 預設週日為 1, 週一為 2... 轉換為我們標準的 1(週一) 到 7(週日)
        let normalizedDay = currentDay == 1 ? 7 : (currentDay - 1)

        if normalizedDay != dayOfWeek {
            return .future
        }

        let now = TimeOfDay(date: date, calendar: calendar)
        if now < startTime {
            let minutesUntil = startTime.totalMinutes - now.totalMinutes
            return minutesUntil <= 30 ? .upcoming : .future
        } else if now >= startTime && now <= endTime {
            return .inProgress
        } else {
            return .finished
        }
    }

    /// 解析學分整數 (如 "3學分" -> 3，若無或解析失敗則回傳 0)
    public var creditsInt: Int {
        let numbers = credits.filter { $0.isNumber }
        return Int(numbers) ?? 0
    }

    /// 對應系統顏色
    public var color: Color {
        switch colorName.lowercased() {
        case "blue": return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "orange": return .orange
        case "green": return .green
        case "mint": return .mint
        case "teal": return .teal
        case "pink": return .pink
        case "red": return .red
        default: return .indigo
        }
    }
}
