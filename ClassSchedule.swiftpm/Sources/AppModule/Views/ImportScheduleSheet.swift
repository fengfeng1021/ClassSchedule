import SwiftUI
import UniformTypeIdentifiers

/// 資源一鍵匯入課表視圖（通用大專院校課表匯入器，支援 PDF 檔案解析與剪貼簿文字智能識別）
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
                // MARK: 1. 各校 PDF 課表文件選取
                Section {
                    Button {
                        showingFilePicker = true
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(.orange.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "doc.viewfinder.fill")
                                    .font(.title3)
                                    .foregroundStyle(.orange)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("選取各校 PDF 課表文件")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("透過 PDFKit 自動提取節次、課名、教室與教師")
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
                    Text("PDF 檔案匯入")
                } footer: {
                    Text("支援各大專院校校務選課系統匯出的課表 PDF 檔案，App 會在您的 iPad 本地進行智能解析，絕不上傳伺服器。")
                }

                // MARK: 2. 剪貼簿文字貼上解析
                Section {
                    TextField("請在此貼上選課系統複製的課表文字或表格內容...", text: $rawText, axis: .vertical)
                        .lineLimit(5...10)
                        .font(.system(.caption, design: .monospaced))

                    Button {
                        parseAndImportText()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "wand.and.stars")
                            Text("智能解析並匯入")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text("選課系統文字貼上")
                } footer: {
                    Text("若沒有 PDF 檔案，也可直接將學校選課系統畫面中的課表文字選取複製，貼於上方進行自動識別排課。")
                }
            }
            .navigationTitle("匯入課表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
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
                Text(importedSuccessMessage ?? "已成功為您排入課表。")
            }
        }
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
