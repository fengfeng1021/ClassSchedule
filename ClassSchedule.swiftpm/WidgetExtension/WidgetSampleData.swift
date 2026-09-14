import Foundation

/// 桌面小工具離線示範資料（免除對主模組與 PDFKit 的依賴，輕量快速載入）
public struct WidgetSampleData {
    public static var fallbackCourses: [Course] {
        [
            Course(
                name: "數位創作與行銷 A",
                teacher: "石金龍",
                classroom: "I426",
                credits: "2學分",
                dayOfWeek: 1,
                startPeriodId: "3",
                endPeriodId: "4",
                startTime: TimeOfDay(hour: 10, minute: 10),
                endTime: TimeOfDay(hour: 12, minute: 0),
                colorName: "blue",
                notes: "上機創作與行銷分析"
            ),
            Course(
                name: "商業模式創新 B",
                teacher: "黃建元",
                classroom: "M008",
                credits: "3學分",
                dayOfWeek: 1,
                startPeriodId: "N",
                endPeriodId: "6",
                startTime: TimeOfDay(hour: 12, minute: 10),
                endTime: TimeOfDay(hour: 15, minute: 0),
                colorName: "teal",
                notes: "個案研討與創新提案"
            ),
            Course(
                name: "行銷管理 D",
                teacher: "陳崇昊",
                classroom: "M003",
                credits: "3學分",
                dayOfWeek: 1,
                startPeriodId: "7",
                endPeriodId: "9",
                startTime: TimeOfDay(hour: 15, minute: 10),
                endTime: TimeOfDay(hour: 18, minute: 0),
                colorName: "indigo",
                notes: "個案分析與行銷策略"
            ),
            Course(
                name: "使用者經驗設計",
                teacher: "林美華",
                classroom: "A105",
                credits: "3學分",
                dayOfWeek: 2,
                startPeriodId: "2",
                endPeriodId: "4",
                startTime: TimeOfDay(hour: 9, minute: 10),
                endTime: TimeOfDay(hour: 12, minute: 0),
                colorName: "purple"
            ),
            Course(
                name: "資料結構與演算法",
                teacher: "張景翔",
                classroom: "C201",
                credits: "3學分",
                dayOfWeek: 3,
                startPeriodId: "5",
                endPeriodId: "7",
                startTime: TimeOfDay(hour: 13, minute: 10),
                endTime: TimeOfDay(hour: 16, minute: 0),
                colorName: "orange"
            ),
            Course(
                name: "人工智慧應用實務",
                teacher: "王國華",
                classroom: "E302",
                credits: "3學分",
                dayOfWeek: 4,
                startPeriodId: "3",
                endPeriodId: "4",
                startTime: TimeOfDay(hour: 10, minute: 10),
                endTime: TimeOfDay(hour: 12, minute: 0),
                colorName: "green"
            ),
            Course(
                name: "專題討論與實作",
                teacher: "陳士農",
                classroom: "M008",
                credits: "2學分",
                dayOfWeek: 5,
                startPeriodId: "6",
                endPeriodId: "7",
                startTime: TimeOfDay(hour: 14, minute: 10),
                endTime: TimeOfDay(hour: 16, minute: 0),
                colorName: "mint"
            )
        ]
    }
}
