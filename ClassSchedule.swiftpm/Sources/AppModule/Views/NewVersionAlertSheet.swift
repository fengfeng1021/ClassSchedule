import SwiftUI

/// 課表新版本推播更新彈窗（Apple 原生液態毛玻璃風格）
public struct NewVersionAlertSheet: View {
    @ObservedObject var updateService: AppUpdateService
    @Environment(\.dismiss) private var dismiss

    public init(updateService: AppUpdateService) {
        self.updateService = updateService
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 頂部晶瑩圖示與版本標題
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 72, height: 72)
                            .shadow(color: Color.blue.opacity(0.20), radius: 12, x: 0, y: 4)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.60),
                                                Color.blue.opacity(0.30),
                                                Color.white.opacity(0.15)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )

                        Image(systemName: "sparkles")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.blue, Color(red: 0.1, green: 0.6, blue: 1.0)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .padding(.top, 10)

                    VStack(spacing: 4) {
                        Text("發現課表新版本")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)

                        HStack(spacing: 6) {
                            Text("目前 v\(updateService.currentVersion)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Image(systemName: "arrow.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)

                            Text(updateService.latestVersion)
                                .font(.caption.weight(.black))
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12), in: Capsule())
                        }
                    }
                }

                // 更新內容說明卡片 (毛玻璃材質)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.blue)
                        Text("更新內容與優化項目")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    ScrollView {
                        Text(updateService.releaseNotes)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.9))
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 180)
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .padding(.horizontal, 16)

                Spacer(minLength: 0)

                // 說明卡片：消除簽名與配額疑慮
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.blue)
                        Text("覆蓋更新安全說明")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }

                    Text("• 不耗費 App ID：沿用同一個識別碼，不會消耗每週 10 個 App ID 配額。\n• 不佔用額外名額：原位覆寫，在 SideStore 中依然只佔用 1 個已安裝 App 槽位。\n• 課表資料完整保留：原有課表、節次設定與個人資料絕不遺失。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 16)

                Spacer(minLength: 0)

                // 操作按鈕區
                VStack(spacing: 10) {
                    // 1. 透過 SideStore 一鍵自動升級 (自動下載、簽名與覆蓋安裝)
                    Button {
                        let rawUrl = updateService.downloadUrl
                        if let encoded = rawUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                           let sideStoreUrl = URL(string: "sidestore://install?url=\(encoded)") {
                            UIApplication.shared.open(sideStoreUrl) { success in
                                if !success {
                                    if let altStoreUrl = URL(string: "altstore://install?url=\(encoded)") {
                                        UIApplication.shared.open(altStoreUrl) { altSuccess in
                                            if !altSuccess, let webUrl = URL(string: rawUrl) {
                                                UIApplication.shared.open(webUrl)
                                            }
                                        }
                                    } else if let webUrl = URL(string: rawUrl) {
                                        UIApplication.shared.open(webUrl)
                                    }
                                }
                            }
                        }
                        updateService.updateAvailable = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("透過 SideStore 一鍵自動升級")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color(red: 0.05, green: 0.45, blue: 0.95)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .shadow(color: Color.blue.opacity(0.30), radius: 6, x: 0, y: 2)
                    }

                    // 2. 加入 SideStore 官方軟體源 (以後直接在 SideStore 內點擊 UPDATE)
                    Button {
                        let sourceUrl = "https://raw.githubusercontent.com/fengfeng1021/ClassSchedule/main/apps.json"
                        if let encoded = sourceUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                           let url = URL(string: "sidestore://source?url=\(encoded)") {
                            UIApplication.shared.open(url) { success in
                                if !success, let altUrl = URL(string: "altstore://source?url=\(encoded)") {
                                    UIApplication.shared.open(altUrl)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.app.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("綁定 SideStore 軟體源 (直接在裡面點 UPDATE)")
                                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.primary)
                    }

                    // 3. 在 Safari 瀏覽器中下載 IPA (手動備用)
                    Button {
                        if let url = URL(string: updateService.downloadUrl) {
                            UIApplication.shared.open(url)
                        }
                        updateService.updateAvailable = false
                    } label: {
                        Text("在 Safari 瀏覽器中手動下載 IPA")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    }

                    // 4. 稍後提醒 / 略過
                    HStack(spacing: 12) {
                        Button {
                            updateService.updateAvailable = false
                        } label: {
                            Text("稍後提醒")
                                .font(.system(size: 13.5, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            updateService.skipVersion(updateService.latestVersion)
                        } label: {
                            Text("略過此版本")
                                .font(.system(size: 13.5, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") {
                        updateService.updateAvailable = false
                    }
                }
            }
        }
    }
}
