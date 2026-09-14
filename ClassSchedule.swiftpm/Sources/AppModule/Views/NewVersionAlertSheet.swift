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

                // 操作按鈕區
                VStack(spacing: 10) {
                    // 立即下載更新 (一鍵 Safari 下載並調用自簽)
                    Button {
                        if let url = URL(string: updateService.downloadUrl) {
                            UIApplication.shared.open(url)
                        }
                        updateService.updateAvailable = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("立即下載更新 (IPA)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
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

                    // 稍後提醒 / 略過
                    HStack(spacing: 12) {
                        Button {
                            updateService.updateAvailable = false
                        } label: {
                            Text("稍後提醒")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .foregroundStyle(.primary)
                        }

                        Button {
                            updateService.skipVersion(updateService.latestVersion)
                        } label: {
                            Text("略過此版本")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
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
