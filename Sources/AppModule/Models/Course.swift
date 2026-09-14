import SwiftUI

/// 课程状态
public enum CourseStatus: String, Codable {
    case inProgress = \"进行中\"
    case upcoming = \"即将上课\"
    case finished = \"已结束\"
    case future = \"未开始\"
}

/// 课程实体模型
public struct Course: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String             // 课程名称 (例如: 高等数学)
    public var teacher: String          // 任课教师 (例如: 张教授)
    public var classroom: String        // 教室地点 (例如: 第三教学楼 302)
    public var dayOfWeek: Int           // 星期几 (1: 周一, 2: 周二 ... 7: 周日)
    public var startTime: TimeOfDay     // 开始时间
    public var endTime: TimeOfDay       // 结束时间
    public var colorName: String        // 预设语义化主题色
    public var notes: String            // 选修/必修或备注说明

    public init(
        id: UUID = UUID(),
        name: String,
        teacher: String = \"\",
        classroom: String = \"\",
        dayOfWeek: Int = 1,
        startTime: TimeOfDay = TimeOfDay(hour: 8, minute: 30),
        endTime: TimeOfDay = TimeOfDay(hour: 10, minute: 5),
        colorName: String = \"indigo\",
        notes: String = \"\"
    ) {
        self.id = id
        self.name = name
        self.teacher = teacher
        self.classroom = classroom
        self.dayOfWeek = min(max(dayOfWeek, 1), 7)
        self.startTime = startTime
        self.endTime = endTime
        self.colorName = colorName
        self.notes = notes
    }

    /// 课程时长 (分钟)
    public var durationMinutes: Int {
        max(endTime.totalMinutes - startTime.totalMinutes, 0)
    }

    /// 时间范围字符串 \"08:30 - 10:05\"
    public var timeRangeString: String {
        \"\(startTime.formatted) - \(endTime.formatted)\"
    }

    /// 星期中文显示
    public var dayOfWeekString: String {
        Self.dayName(for: dayOfWeek)
    }

    public static func dayName(for day: Int) -> String {
        switch day {
        case 1: return \"周一\"
        case 2: return \"周二\"
        case 3: return \"周三\"
        case 4: return \"周四\"
        case 5: return \"周五\"
        case 6: return \"周六\"
        case 7: return \"周日\"
        default: return \"\"
        }
    }

    /// 计算在指定时刻的状态
    public func status(at date: Date = Date(), calendar: Calendar = .current) -> CourseStatus {
        let currentDay = calendar.component(.weekday, from: date)
        // 苹果 Calendar 默认周日为 1, 周一为 2... 转换为我们标准的 1(周一) 到 7(周日)
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

    /// 对应系统颜色
    public var color: Color {
        switch colorName.lowercased() {
        case \"blue\": return .blue
        case \"indigo\": return .indigo
        case \"purple\": return .purple
        case \"orange\": return .orange
        case \"green\": return .green
        case \"mint\": return .mint
        case \"teal\": return .teal
        case \"pink\": return .pink
        case \"red\": return .red
        default: return .indigo
        }
    }
}
