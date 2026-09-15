import ActivityKit
import Foundation

/// 上課倒數 Live Activity 的資料模型。
///
/// 這個檔案放在 `Models/`，因為主程式與小工具擴展**都**會編譯這個目錄 ——
/// Live Activity 的 `ActivityAttributes` 必須兩邊看到同一個型別，否則
/// 擴展端會渲染不出來。
///
/// 設計重點：課前倒數期間**不需要更新任何內容**。
/// 倒數交給系統依 `createdAt` 與 `startDate` 自行渲染（`Text(timerInterval:)`），
/// 所以 `ContentState` 是空的 —— App 不必持續在前景或背景喚醒就能讓倒數跳動。
@available(iOS 16.2, *)
public struct ClassSessionActivityAttributes: ActivityAttributes, Sendable {

    /// 動態內容（本功能不需要，保留空結構以符合 ActivityAttributes）。
    public struct ContentState: Codable, Hashable, Sendable {
        public init() {}
    }

    /// 課程名稱
    public let courseName: String
    /// 上課教室
    public let classroom: String
    /// 授課教師
    public let teacher: String
    /// 課程開始時間（倒數的終點）
    public let startDate: Date
    /// 課程結束時間
    public let endDate: Date
    /// Live Activity 建立時間（倒數區間的下界；區間必須永遠有效）
    public let createdAt: Date
    /// 課程代表色名稱，讓卡片顏色與課表一致
    public let colorName: String

    public init(
        courseName: String,
        classroom: String,
        teacher: String,
        startDate: Date,
        endDate: Date,
        createdAt: Date,
        colorName: String
    ) {
        self.courseName = courseName
        self.classroom = classroom
        self.teacher = teacher
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.colorName = colorName
    }

    /// 由課程建立（`startDate` 為該堂課的實際開始時間）。
    public init(course: Course, startDate: Date, endDate: Date, createdAt: Date) {
        self.init(
            courseName: course.name,
            classroom: course.classroom,
            teacher: course.teacher,
            startDate: startDate,
            endDate: endDate,
            createdAt: createdAt,
            colorName: course.colorName
        )
    }
}
