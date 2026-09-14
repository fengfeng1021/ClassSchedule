import SwiftUI
import UIKit

/// 乾淨課表照片導出與儲存視圖
public struct CleanScheduleExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CourseStore

    @State private var renderedImage: UIImage?
    @State private var isRendering: Bool = true
    @State private var showingSaveSuccessAlert = false
    @State private var saveErrorMessage: String?
    @State private var showingShareSheet = false

    public init(store: CourseStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
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
                            // 課表預覽畫布
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                                .padding(.horizontal, 16)
                                .padding(.top, 12)

                            // 操作按鈕組
                            VStack(spacing: 12) {
                                Button {
                                    saveImageToPhotos(image)
                                } label: {
                                    HStack {
                                        Image(systemName: "square.and.arrow.down.fill")
                                        Text("儲存課表圖片至相簿")
                                            .fontWeight(.bold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }

                                Button {
                                    showingShareSheet = true
                                } label: {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("分享 / 儲存至檔案...")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .foregroundStyle(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                    )
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
            .alert("儲存成功", isPresented: $showingSaveSuccessAlert) {
                Button("完成") {
                    dismiss()
                }
            } message: {
                Text("乾淨課表照片已成功儲存至本機相簿！")
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
        let exportView = CleanScheduleCanvasView(store: store)
            .frame(width: 1200, height: 820)
            .background(Color.white)

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

/// 專用於圖片匯出的純淨課表畫布（無拖曳把手、無按鈕、排版精美大氣）
public struct CleanScheduleCanvasView: View {
    @ObservedObject var store: CourseStore

    private var settings: ScheduleSettings {
        store.settings
    }

    private var activePeriods: [Period] {
        settings.activePeriods
    }

    private var visibleDays: [Int] {
        settings.visibleDays
    }

    public init(store: CourseStore) {
        self.store = store
    }

    private let weekdayNames = ["週一", "週二", "週三", "週四", "週五", "週六", "週日"]

    public var body: some View {
        VStack(spacing: 0) {
            // 頂部課表標題與精美裝飾
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("我的課程表")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("共 \(store.courses.count) 門課程 · 總計 \(totalCredits) 學分")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("ClassSchedule")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // 星期列
            HStack(spacing: 0) {
                Text("節次")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 80, height: 40)

                ForEach(visibleDays, id: \.self) { day in
                    let name = day >= 1 && day <= 7 ? weekdayNames[day - 1] : "第\(day)天"
                    Text(name)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
            }
            .background(Color(uiColor: .systemGray6))

            Divider()

            // 課表主矩陣
            HStack(alignment: .top, spacing: 0) {
                // 節次時間軸
                VStack(spacing: 0) {
                    ForEach(activePeriods) { period in
                        VStack(spacing: 2) {
                            Text(period.shortName)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(.primary)

                            Text(period.startTime.formatted)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Text(period.endTime.formatted)
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(width: 80)
                        .frame(maxHeight: .infinity)
                        .overlay(
                            Rectangle()
                                .fill(Color.primary.opacity(0.04))
                                .frame(height: 1),
                            alignment: .bottom
                        )
                    }
                }
                .background(Color(uiColor: .systemGray6).opacity(0.5))

                // 各星期課程網格
                HStack(spacing: 0) {
                    ForEach(visibleDays, id: \.self) { day in
                        ZStack(alignment: .top) {
                            // 背景網格線
                            VStack(spacing: 0) {
                                ForEach(activePeriods) { _ in
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(maxHeight: .infinity)
                                        .overlay(
                                            Rectangle()
                                                .fill(Color.primary.opacity(0.06))
                                                .frame(height: 1),
                                            alignment: .bottom
                                        )
                                }
                            }

                            // 該日所有課程卡片
                            GeometryReader { colGeo in
                                let totalPeriods = CGFloat(max(activePeriods.count, 1))
                                let cellHeight = colGeo.size.height / totalPeriods
                                let dayCourses = store.courses.filter { $0.dayOfWeek == day }

                                ForEach(dayCourses) { course in
                                    if let startIdx = settings.activeIndexOfPeriod(id: course.startPeriodId),
                                       let endIdx = settings.activeIndexOfPeriod(id: course.endPeriodId),
                                       endIdx >= startIdx {
                                        let topY = CGFloat(startIdx) * cellHeight
                                        let h = CGFloat(endIdx - startIdx + 1) * cellHeight

                                        cleanCourseCard(course)
                                            .frame(width: colGeo.size.width - 6, height: max(h - 6, 20))
                                            .offset(x: 3, y: topY + 3)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(
                            Rectangle()
                                .fill(Color.primary.opacity(0.06))
                                .frame(width: 1),
                            alignment: .trailing
                        )
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var totalCredits: String {
        let total = store.courses.reduce(0.0) { sum, c in
            let numStr = c.credits.replacingOccurrences(of: "學分", with: "").trimmingCharacters(in: .whitespaces)
            return sum + (Double(numStr) ?? 0.0)
        }
        return total.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", total) : String(format: "%.1f", total)
    }

    private func cleanCourseCard(_ course: Course) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [course.color.opacity(0.24), course.color.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(course.color.opacity(0.4), lineWidth: 1)
                )

            VStack(spacing: 3) {
                Text(course.name)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                if !course.classroom.isEmpty {
                    Text(course.classroom)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(course.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.85), in: Capsule())
                }

                if settings.showTeacher && !course.teacher.isEmpty {
                    Text(course.teacher)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(4)
        }
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
