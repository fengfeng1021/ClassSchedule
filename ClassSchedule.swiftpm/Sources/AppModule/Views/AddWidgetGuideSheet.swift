import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

/// 快捷加入桌面小工具導引與 SideStore 排查中心彈窗
public struct AddWidgetGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hasSynced: Bool = false
    @State private var syncToastVisible: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: 1. 一鍵前往桌面行動卡片
                    quickActionCard
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    // MARK: 2. 桌面加入 3 步驟教學
                    stepsTutorialCard
                        .padding(.horizontal, 16)

                    // MARK: 3. SideStore / iOS 找不到小工具專屬排查秘笈
                    troubleshootingCard
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("加入桌面小工具")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - 1. 一鍵前往桌面行動卡片

    private var quickActionCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color(red: 0.1, green: 0.5, blue: 1.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 3)

                    Image(systemName: "plus.app.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("小工具時間軸狀態")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("已就緒")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.12), in: Capsule())
                    }

                    Text("所有課程資料已完成 App Group 共享同步")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // 核心行動按鈕：自動最小化退回主畫面長按加入
            Button {
                #if canImport(WidgetKit)
                WidgetCenter.shared.reloadAllTimelines()
                #endif
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                
                // 延遲 0.2 秒退回主畫面，讓使用者順暢切換到桌面
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    UIControl().sendAction(#selector(NSXPCConnection.suspend), to: UIApplication.shared, for: nil)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 16, weight: .bold))

                    Text("立即退回桌面長按加入")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color(red: 0.08, green: 0.48, blue: 0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .shadow(color: Color.blue.opacity(0.28), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)

            // 次要按鈕：手動刷新時間軸快取
            Button {
                #if canImport(WidgetKit)
                WidgetCenter.shared.reloadAllTimelines()
                #endif
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring()) {
                    hasSynced = true
                    syncToastVisible = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        syncToastVisible = false
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: syncToastVisible ? "checkmark.circle.fill" : "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(syncToastVisible ? .green : .blue)

                    Text(syncToastVisible ? "時間軸已強制重新整理！" : "重新整理小工具快取時間軸")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(syncToastVisible ? .green : .blue)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - 2. 桌面加入 3 步驟教學

    private var stepsTutorialCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("三步驟加入主畫面")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                stepItemRow(
                    number: "1",
                    icon: "hand.draw.fill",
                    color: .blue,
                    title: "長按主畫面空白處",
                    detail: "直到所有桌面 App 圖示開始抖動，進入編輯主畫面模式。"
                )

                Divider()

                stepItemRow(
                    number: "2",
                    icon: "plus.circle.fill",
                    color: .indigo,
                    title: "點擊左上角「+」號",
                    detail: "打開 iOS 系統小工具庫選單（或點選左上角「編輯」->「加入小工具」）。"
                )

                Divider()

                stepItemRow(
                    number: "3",
                    icon: "magnifyingglass",
                    color: .teal,
                    title: "搜尋「課表」並加入",
                    detail: "在上方搜尋欄輸入「課表」，挑選小型、中型、大型或鎖定畫面小工具放置於主畫面！"
                )
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private func stepItemRow(number: String, icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("第 \(number) 步：\(title)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 3. SideStore / iOS 找不到小工具專屬排查秘笈

    private var troubleshootingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.orange)

                Text("在小工具清單找不到「課表」？排查指南")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 12) {
                // 排查點 1：SideStore 安裝時務必保留擴展 (Keep App Extensions)
                troubleshootingRow(
                    badge: "重點 1",
                    title: "SideStore 務必選擇「Keep App Extensions」",
                    content: "小工具屬於獨立 Widget Extension（需占用 1 個 App ID，免費帳號共可簽 3 個，剛好滿額）。\n👉 解法：在 SideStore 安裝或更新 IPA 時，若跳出擴展提示，務必點選「Keep App Extensions (保留擴展)」或「Use Main Profile」！若選了「Remove App Extensions」，小工具就會被 SideStore 剔除。\n👉 若 App ID 滿額：可至 SideStore 底部「DIAGNOSTICS」->「Experimental Features」清理過期 App ID。"
                )

                Divider()

                // 排查點 2：iPadOS / iOS 系統快取重新索引（最常見、最有效！）
                troubleshootingRow(
                    badge: "重點 2",
                    title: "強制觸發 iPadOS 重整小工具快取庫（最靈驗）",
                    content: "自簽 App 安裝後，系統進程（pkd）經常存在快取延遲，不會立即把新 App 加入小工具搜尋索引。\n👉 解法：至 iPad「設定 -> 一般 -> 語言與地區」，隨意新增或切換一種語言（或重新開機 iPad），系統就會立刻被動強制重新掃描所有 App，桌面小工具清單即可立即出現「課表」！"
                )

                Divider()

                // 排查點 3：至少開啟過 App 一次
                troubleshootingRow(
                    badge: "重點 3",
                    title: "安裝後必須開啟過一次 App",
                    content: "iOS 規定任何應用程式必須在設備上至少打開過一次，系統才會向小工具框架註冊該應用的 Extension。"
                )

                Divider()

                // 快捷打開系統設定
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 13))
                        Text("開啟系統「設定」檢查")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.blue)
                    .padding(.vertical, 4)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private func troubleshootingRow(badge: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(badge)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12), in: Capsule())

                Text(title)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(.primary)
            }

            Text(content)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
