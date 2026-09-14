import SwiftUI
import UIKit

/// 課表照片匯出外觀主題
public enum ScheduleExportTheme: String, CaseIterable, Identifiable {
    case light = "淺色模式"
    case dark = "深色模式"

    public var id: String { rawValue }
}

/// 課表照片匯出比例與版型方向
public enum ScheduleExportLayout: String, CaseIterable, Identifiable {
    case phonePortrait = "手機直向"
    case padLandscape = "平板橫向"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .phonePortrait: return "iphone"
        case .padLandscape: return "ipad.landscape"
        }
    }

    public var canvasSize: CGSize {
        switch self {
        case .phonePortrait:
            // 900 x 1600: 9:16 黃金比例，完美契合 iPhone 全螢幕與手機相簿
            return CGSize(width: 900, height: 1600)
        case .padLandscape:
            // 1400 x 950: 16:10 寬螢幕比例，適合 iPad 平板與電腦大圖
            return CGSize(width: 1400, height: 950)
        }
    }
}

/// 導出主題色彩配置（100% 嚴格對齊 App 原生外觀）
public struct ExportThemePalette {
    public let isDark: Bool
    public let canvasBackground: Color
    public let surfaceBackground: Color
    public let primaryText: Color
    public let secondaryText: Color
    public let tertiaryText: Color
    public let gridLine: Color
    public let cardBaseBackground: Color

    public static func forTheme(_ theme: ScheduleExportTheme) -> ExportThemePalette {
        switch theme {
        case .light:
            return ExportThemePalette(
                isDark: false,
                canvasBackground: Color(red: 242/255, green: 242/255, blue: 247/255), // systemGroupedBackground
                surfaceBackground: Color.white, // secondarySystemGroupedBackground
                primaryText: Color.black.opacity(0.88),
                secondaryText: Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.60), // secondaryLabel
                tertiaryText: Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.32),
                gridLine: Color.black.opacity(0.06),
                cardBaseBackground: Color.white
            )
        case .dark:
            return ExportThemePalette(
                isDark: true,
                canvasBackground: Color.black, // pure OLED black
                surfaceBackground: Color(red: 28/255, green: 28/255, blue: 30/255), // secondarySystemGroupedBackground #1C1C1E
                primaryText: Color.white.opacity(0.92),
                secondaryText: Color(red: 235/255, green: 235/255, blue: 245/255).opacity(0.60), // secondaryLabel
                tertiaryText: Color(red: 235/255, green: 235/255, blue: 245/255).opacity(0.35),
                gridLine: Color.white.opacity(0.08),
                cardBaseBackground: Color(red: 28/255, green: 28/255, blue: 30/255)
            )
        }
    }
}

/// 乾淨課表照片導出與儲存視圖（支援深淺雙模式切換、手機直向與平板橫向自選）
public struct CleanScheduleExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CourseStore

    @State private var exportTheme: ScheduleExportTheme
    @State private var exportLayout: ScheduleExportLayout
    @State private var renderedImage: UIImage?
    @State private var isRendering: Bool = true
    @State private var showingSaveSuccessAlert = false
    @State private var saveErrorMessage: String?
    @State private var showingShareSheet = false

    public init(store: CourseStore) {
        self.store = store

        // 智慧初值：跟隨 App 目前外觀模式設定
        let initialTheme: ScheduleExportTheme
        switch store.settings.appearanceMode {
        case .dark: initialTheme = .dark
        case .light: initialTheme = .light
        case .system:
            let isSystemDark = UITraitCollection.current.userInterfaceStyle == .dark
            initialTheme = isSystemDark ? .dark : .light
        }
        _exportTheme = State(initialValue: initialTheme)

        // 智慧初值：根據當前裝置自動選擇版型 (iPhone 預設手機直向，iPad 預設平板橫向)
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        _exportLayout = State(initialValue: isPhone ? .phonePortrait : .padLandscape)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // 頂部設定選區 (外觀模式 + 圖片版型)
                VStack(spacing: 10) {
                    // 1. 照片外觀風格
                    HStack {
                        Text("照片外觀")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 64, alignment: .leading)

                        Picker("外觀風格", selection: $exportTheme) {
                            ForEach(ScheduleExportTheme.allCases) { theme in
                                Text(theme.rawValue).tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // 2. 圖片版型方向
                    HStack {
                        Text("圖片版型")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 64, alignment: .leading)

                        Picker("圖片版型", selection: $exportLayout) {
                            ForEach(ScheduleExportLayout.allCases) { layout in
                                Label(layout.rawValue, systemImage: layout.icon).tag(layout)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                Divider()
                    .padding(.horizontal, 8)

                if isRendering {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("正在生成高解析度乾淨課表圖片...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let image = renderedImage {
                    ScrollView {
                        VStack(spacing: 16) {
                            // 課表即時預覽畫布 (自適應直橫向高度)
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: exportLayout == .phonePortrait ? 400 : 270)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                    )
                                .shadow(color: Color.black.opacity(exportTheme == .dark ? 0.35 : 0.08), radius: 12, x: 0, y: 4)
                                .padding(.horizontal, 20)
                                .padding(.top, 4)

                            // 操作按鈕組 (Apple 原生微光與液態毛玻璃按鈕)
                            VStack(spacing: 12) {
                                Button {
                                    saveImageToPhotos(image)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "square.and.arrow.down.fill")
                                        Text("儲存課表圖片至相簿 (\(exportLayout.rawValue) · \(exportTheme.rawValue))")
                                            .fontWeight(.bold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.blue, Color(red: 0.05, green: 0.45, blue: 0.95)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.white.opacity(0.30), lineWidth: 1)
                                    )
                                    .shadow(color: Color.blue.opacity(0.32), radius: 8, x: 0, y: 3)
                                }

                                Button {
                                    showingShareSheet = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("分享 / 儲存至檔案...")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .foregroundStyle(.primary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.38),
                                                        Color.white.opacity(0.12)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1.5)
                                }
                            }

                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                    }
                } else {
                    Text("圖片生成失敗，請重試")
                        .foregroundStyle(.secondary)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("儲存課表圖片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
            .task {
                renderScheduleImage()
            }
            .onChange(of: exportTheme) { _ in
                renderScheduleImage()
            }
            .onChange(of: exportLayout) { _ in
                renderScheduleImage()
            }
            .alert("儲存成功", isPresented: $showingSaveSuccessAlert) {
                Button("完成") {
                    dismiss()
                }
            } message: {
                Text("乾淨課表照片（\(exportLayout.rawValue) · \(exportTheme.rawValue)）已成功儲存至本機相簿！")
            }
            .sheet(isPresented: $showingShareSheet) {
                if let image = renderedImage {
                    ActivityView(activityItems: [image])
                }
            }
        }
    }

    @MainActor
    private func renderScheduleImage() {
        isRendering = true
        let size = exportLayout.canvasSize
        let exportView = CleanScheduleCanvasView(store: store, theme: exportTheme, layout: exportLayout)
            .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: exportView)
        renderer.scale = 2.0 // 高清 2x 視網膜畫質

        if let image = renderer.uiImage {
            self.renderedImage = image
            self.isRendering = false
        } else {
            self.isRendering = false
        }
    }

    private func saveImageToPhotos(_ image: UIImage) {
        let saver = ImageSaver { success, error in
            if success {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                self.showingSaveSuccessAlert = true
            } else {
                self.saveErrorMessage = error?.localizedDescription ?? "儲存失敗"
                self.showingShareSheet = true
            }
        }
        saver.save(image)
    }
}

/// 專用於圖片匯出的純淨課表畫布（嚴格支援深淺主題、手機直向與平板橫向自適應）
public struct CleanScheduleCanvasView: View {
    @ObservedObject var store: CourseStore
    let theme: ScheduleExportTheme
    let layout: ScheduleExportLayout

    private var settings: ScheduleSettings {
        store.settings
    }

    private var activePeriods: [Period] {
        settings.activePeriods
    }

    private var visibleDays: [Int] {
        settings.visibleDays
    }

    private var palette: ExportThemePalette {
        ExportThemePalette.forTheme(theme)
    }

    private var isPhonePortrait: Bool {
        layout == .phonePortrait
    }

    private var timeColumnWidth: CGFloat {
        isPhonePortrait ? 66.0 : 82.0
    }

    private var weekdayBarHeight: CGFloat {
        isPhonePortrait ? 40.0 : 44.0
    }

    public init(store: CourseStore, theme: ScheduleExportTheme = .light, layout: ScheduleExportLayout = .phonePortrait) {
        self.store = store
        self.theme = theme
        self.layout = layout
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 頂部課表標題與學分資訊
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("我的課程表")
                        .font(.system(size: isPhonePortrait ? 24 : 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text("共 \(store.courses.count) 門課程 · 總計 \(totalCredits) 學分")
                        .font(.system(size: isPhonePortrait ? 12 : 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()

                Text("ClassSchedule")
                    .font(.system(size: isPhonePortrait ? 11.5 : 13, weight: .black, design: .monospaced))
                    .foregroundStyle(palette.tertiaryText)
            }
            .padding(.horizontal, isPhonePortrait ? 20 : 26)
            .padding(.top, isPhonePortrait ? 22 : 26)
            .padding(.bottom, isPhonePortrait ? 14 : 16)

            // 星期標頭行
            HStack(spacing: 0) {
                Text("節次")
                    .font(.system(size: isPhonePortrait ? 11.5 : 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(palette.secondaryText)
                    .frame(width: timeColumnWidth, height: weekdayBarHeight)

                ForEach(visibleDays, id: \.self) { day in
                    let name = Course.dayName(for: day)
                    Text(name)
                        .font(.system(size: isPhonePortrait ? 12.5 : 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: weekdayBarHeight)
                        .overlay(
                            Rectangle()
                                .fill(palette.gridLine)
                                .frame(width: 0.5),
                            alignment: .trailing
                        )
                }
            }
            .background(palette.surfaceBackground)

            // 水平分隔線
            Rectangle()
                .fill(palette.gridLine)
                .frame(height: 1)

            // 課表主矩陣
            HStack(alignment: .top, spacing: 0) {
                // 左側：節次時間軸
                VStack(spacing: 0) {
                    ForEach(activePeriods) { period in
                        VStack(spacing: 2) {
                            Text(period.shortName)
                                .font(.system(size: isPhonePortrait ? 12.5 : 14, weight: .black, design: .rounded))
                                .foregroundStyle(palette.primaryText)

                            VStack(spacing: 0.5) {
                                Text(period.startTime.formatted)
                                    .font(.system(size: isPhonePortrait ? 9.2 : 10.5, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(palette.primaryText.opacity(0.85))

                                Text(period.endTime.formatted)
                                    .font(.system(size: isPhonePortrait ? 8.5 : 9.5, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(palette.secondaryText)
                            }
                        }
                        .frame(width: timeColumnWidth)
                        .frame(maxHeight: .infinity)
                        .overlay(
                            Rectangle()
                                .fill(palette.gridLine)
                                .frame(height: 0.5),
                            alignment: .bottom
                        )
                    }
                }
                .background(palette.surfaceBackground)
                .overlay(
                    Rectangle()
                        .fill(palette.gridLine)
                        .frame(width: 1.0),
                    alignment: .trailing
                )

                // 右側：各星期課程網格
                HStack(spacing: 0) {
                    ForEach(visibleDays, id: \.self) { day in
                        ZStack(alignment: .top) {
                            // 背景網格底色與底線
                            VStack(spacing: 0) {
                                ForEach(activePeriods) { _ in
                                    Rectangle()
                                        .fill(palette.surfaceBackground.opacity(0.18))
                                        .frame(maxHeight: .infinity)
                                        .overlay(
                                            Rectangle()
                                                .fill(palette.gridLine)
                                                .frame(height: 0.5),
                                            alignment: .bottom
                                        )
                                }
                            }

                            // 當日所有課程卡片 (100% 精確對齊與色調完全復刻)
                            GeometryReader { colGeo in
                                let totalPeriods = CGFloat(max(activePeriods.count, 1))
                                let cellHeight = colGeo.size.height / totalPeriods
                                let dayCourses = store.courses.filter { $0.dayOfWeek == day }

                                ForEach(dayCourses) { course in
                                    if let startIdx = settings.activeIndexOfPeriod(id: course.startPeriodId),
                                       let endIdx = settings.activeIndexOfPeriod(id: course.endPeriodId) {
                                        let minIndex = min(startIdx, endIdx)
                                        let maxIndex = max(startIdx, endIdx)
                                        let spanCount = maxIndex - minIndex + 1

                                        let topY = CGFloat(minIndex) * cellHeight + 1.5
                                        let h = max(CGFloat(spanCount) * cellHeight - 3.0, 18.0)
                                        let cardWidth = max(colGeo.size.width - 3.0, 15.0)

                                        cleanCourseCard(
                                            course: course,
                                            spanCount: spanCount,
                                            width: cardWidth,
                                            height: h
                                        )
                                        .offset(x: 1.5, y: topY)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(
                            Rectangle()
                                .fill(palette.gridLine)
                                .frame(width: 0.5),
                            alignment: .trailing
                        )
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .background(palette.canvasBackground)
    }

    private var totalCredits: String {
        let total = store.courses.reduce(0.0) { sum, c in
            let numStr = c.credits.replacingOccurrences(of: "學分", with: "").trimmingCharacters(in: .whitespaces)
            return sum + (Double(numStr) ?? 0.0)
        }
        return total.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", total) : String(format: "%.1f", total)
    }

    // MARK: - 乾淨課程卡片（100% 完整復刻 App 內真實卡片顏色、上課教室膠囊與字體質感）
    private func cleanCourseCard(course: Course, spanCount: Int, width: CGFloat, height: CGFloat) -> some View {
        let safeWidth = max(width, 15.0)
        let safeHeight = max(height, 15.0)

        let widthScale = min(max(safeWidth / 60.0, 0.88), 1.65)
        let heightScale = min(max(safeHeight / 55.0, 0.88), 1.5)
        let baseScale = min(widthScale, heightScale)

        let titleBase: CGFloat = spanCount > 1 ? (isPhonePortrait ? 12.0 : 13.0) : (isPhonePortrait ? 11.2 : 11.8)
        let titleFontSize = min(max(titleBase * widthScale, 10.5), 18.0)

        let classroomFontSize = min(max((isPhonePortrait ? 10.5 : 11.5) * widthScale, 10.0), 16.0)
        let metaFontSize = min(max((isPhonePortrait ? 8.5 : 9.2) * widthScale, 8.0), 12.5)
        let cardCornerRadius = min(max(8.5 * baseScale, 7.5), 13.0)
        let isCompact = spanCount == 1 || safeHeight < 60

        return ZStack {
            // 1. 防穿透實體基底（與 App 相同）
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(palette.cardBaseBackground)

            // 2. Apple 柔和雙色微光漸變（與 App 相同）
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            course.color.opacity(0.24),
                            course.color.opacity(0.13),
                            course.color.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 3. 核心內容排版 (完美匹配 App 中教室膠囊顏色、位置圖示與字級)
            if isCompact {
                VStack(spacing: 1.5) {
                    Spacer(minLength: 0)

                    // 課程名稱
                    Text(course.name)
                        .font(.system(size: titleFontSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.65)
                        .padding(.horizontal, 2)

                    // 教室膠囊：嚴格使用 course.color 與 location.fill 圖示，與 App 徹底一致！
                    if !course.classroom.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "location.fill")
                                .font(.system(size: classroomFontSize * 0.72, weight: .bold))
                            Text(course.classroom)
                                .font(.system(size: classroomFontSize * 0.95, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(course.color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule()
                                .fill(course.color.opacity(0.20))
                        )
                        .overlay(
                            Capsule()
                                .stroke(course.color.opacity(0.35), lineWidth: 0.5)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                    } else if !course.teacher.isEmpty {
                        Text(course.teacher)
                            .font(.system(size: metaFontSize, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(palette.primaryText.opacity(0.06)))
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            } else {
                VStack(spacing: min(max(3.0 * heightScale, 2.0), 6.5)) {
                    Spacer(minLength: 0)

                    // 課程名稱
                    Text(course.name)
                        .font(.system(size: titleFontSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(spanCount > 2 ? 3 : 2)
                        .lineSpacing(1.5)
                        .minimumScaleFactor(0.70)
                        .padding(.horizontal, max(3.0 * widthScale, 2.0))

                    // 獨立教室膠囊 (醒目雙色漸變與 location 圖示)
                    if !course.classroom.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "location.fill")
                                .font(.system(size: classroomFontSize * 0.72, weight: .bold))
                            Text(course.classroom)
                                .font(.system(size: classroomFontSize, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(course.color)
                        .padding(.horizontal, max(6.0 * widthScale, 4.5))
                        .padding(.vertical, max(2.5 * heightScale, 1.8))
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            course.color.opacity(0.28),
                                            course.color.opacity(0.16)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(course.color.opacity(0.25), lineWidth: 0.5)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    }

                    // 授課教師與學分
                    if !course.teacher.isEmpty || !course.credits.isEmpty {
                        HStack(spacing: 3) {
                            if !course.teacher.isEmpty {
                                Text(course.teacher)
                                    .font(.system(size: metaFontSize, weight: .bold, design: .rounded))
                                    .foregroundStyle(palette.secondaryText)
                                    .lineLimit(1)
                            }
                            if !course.teacher.isEmpty && !course.credits.isEmpty {
                                Text("•")
                                    .font(.system(size: metaFontSize * 0.9, weight: .black, design: .rounded))
                                    .foregroundStyle(palette.tertiaryText)
                            }
                            if !course.credits.isEmpty {
                                Text(course.credits)
                                    .font(.system(size: metaFontSize, weight: .bold, design: .rounded))
                                    .foregroundStyle(palette.secondaryText.opacity(0.9))
                                    .lineLimit(1)
                            }
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    }

                    Spacer(minLength: 0)
                }
                .padding(3)
            }
        }
        .frame(width: safeWidth, height: safeHeight)
        // 4. Apple 微光玻璃折射外框
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(palette.isDark ? 0.22 : 0.40),
                            course.color.opacity(0.18),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(
                    course.color.opacity(0.38),
                    lineWidth: 1.0
                )
        )
        .shadow(
            color: Color.black.opacity(palette.isDark ? 0.25 : 0.05),
            radius: 3,
            x: 0,
            y: 1.5
        )
    }
}

/// 系統相簿儲存輔助器
private class ImageSaver: NSObject {
    private let completion: (Bool, Error?) -> Void

    init(completion: @escaping (Bool, Error?) -> Void) {
        self.completion = completion
    }

    func save(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    @objc private func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            completion(false, error)
        } else {
            completion(true, nil)
        }
    }
}

/// 系統原生分享視圖 (UIActivityViewController)
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
