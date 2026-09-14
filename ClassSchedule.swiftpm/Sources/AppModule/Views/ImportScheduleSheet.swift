import SwiftUI
import UniformTypeIdentifiers

/// 資源一鍵匯入課表視圖（支援亞洲大學示範一鍵載入、PDF 文件選取解析、剪貼簿文字智能識別）
public struct ImportScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CourseStore

    @State private var showingFilePicker = false
    @State private var rawText: String = ""
    @State private var importedSuccessMessage: String?
    @State private var showingSuccessAlert = false

    public init(store: CourseStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: 1. 亞洲大學專屬一鍵載入 (官方範例)
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Image(systemName: "graduationcap.circle.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("亞洲大學 115 學年度課表")
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text("汪俊鋒同學 · 資傳系 4A · 總計 29 學分")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text("涵蓋《商業模式創新 B》、《模型製作(一) B》、《服務業管理 B》、《數位創作與行銷 A》、《智慧傳播應用實務 B》、《電腦繪圖 B》、《梳髮實務 A》、《妝髮整體造型設計 A》等完整跨節次課表。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 2)

                        Button {
                            loadAsiaUniversitySchedule()
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.down.doc.fill")
                                Text("一鍵匯入此課表")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("亞洲大學專用一鍵載入")
                } footer: {
                    Text("直接套用您的 PDF 課表配置，自動完成課程名稱、學分、授課教師、上課教室及跨節次排定。")
                }

                // MARK: 2. PDF 文件匯入
                Section {
                    Button {
                        showingFilePicker = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.viewfinder.fill")
                                .font(.title3)
                                .foregroundStyle(.orange)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("選取 PDF 課表文件")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text("透過 PDFKit 自動提取各校課表欄位")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("各校 PDF 課表解析")
                } footer: {
                    Text("支援各大專院校校務系統匯出的課表 PDF 檔案，App 會在您的 iPad 本地進行解析與自動排課。")
                }

                // MARK: 3. 文字智能識別
                Section {
                    TextField("請在此貼上校務系統複製的課表文字...", text: $rawText, axis: .vertical)
                        .lineLimit(4...8)
                        .font(.system(.caption, design: .monospaced))

                    Button {
                        parseAndImportText()
                    } label: {
                        HStack {
                            Spacer()
                            Text("智能解析並匯入")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text("剪貼簿文字智能解析")
                } footer: {
                    Text("如果沒有 PDF 檔案，也可直接將選課系統網頁上的課表格子文字複製並貼於此處進行識別。")
                }
            }
            .navigationTitle("匯入課表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }
            .alert("匯入成功！", isPresented: $showingSuccessAlert) {
                Button("完成") {
                    dismiss()
                }
            } message: {
                Text(importedSuccessMessage ?? "已成功匯入課表資料。")
            }
        }
    }

    private func loadAsiaUniversitySchedule() {
        let sampleCourses = ScheduleParser.asiaUniversitySampleCourses
        store.importCourses(sampleCourses, autoAdjustSettings: true)
        importedSuccessMessage = "已成功載入汪俊鋒同學亞洲大學 115 學年度第 1 學期 29 學分課表（共 14 門課次），教室與跨節次已完全就位！"
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showingSuccessAlert = true
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        do {
            guard let selectedURL = try result.get().first else { return }
            guard selectedURL.startAccessingSecurityScopedResource() else { return }
            defer { selectedURL.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: selectedURL)
            let parsed = ScheduleParser.parsePDF(data: data)

            if !parsed.isEmpty {
                store.importCourses(parsed, autoAdjustSettings: true)
                importedSuccessMessage = "成功從 PDF 檔案解析出 \(parsed.count) 門課程安排，已為您自動排入課表格子中！"
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showingSuccessAlert = true
            }
        } catch {
            print("[ImportScheduleSheet] PDF 讀取錯誤: \(error)")
        }
    }

    private func parseAndImportText() {
        let parsed = ScheduleParser.parseGeneralText(rawText)
        if !parsed.isEmpty {
            store.importCourses(parsed, autoAdjustSettings: true)
            importedSuccessMessage = "文字智能識別成功！已解析出 \(parsed.count) 門課程並完成填寫。"
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showingSuccessAlert = true
        }
    }
}
