import Foundation

/// 小工具註冊診斷中心。
///
/// 目的：在**不需要 Xcode、也不需要連接電腦**的前提下，判斷桌面小工具為什麼沒有出現在
/// 小工具庫。整個鏈路只有三個環節會失敗，逐項檢查即可定位：
///
/// 1. `PlugIns/*.appex` 是否真的被安裝進 App bundle（SideStore 在更新時會自動剔除
///    「新版有、裝置上舊版沒有」的擴展，這是最常見的失敗點）。
/// 2. 主程式與擴展的 `embedded.mobileprovision` 是否都帶有
///    `com.apple.security.application-groups` 授權（缺少時小工具讀不到共享課表）。
/// 3. 系統是否已完成小工具擴展註冊（只能由 iOS 端決定，App 無法強制）。
///
/// 全部使用公開 API 讀取自己 bundle 內的檔案，不涉及任何私有 API。
enum WidgetDiagnostics {

    struct Summary {
        let appIdentifier: String
        let appDisplayName: String
        let appVersion: String
        let appBuild: String
        let osVersion: String
        let appGroupStatus: String
        let extensionProbes: [ExtensionProbe]
        let appProvisioning: String

        /// 產生可直接複製貼上的純文字報告。
        var report: String {
            var lines: [String] = []
            lines.append("=== ClassSchedule 小工具診斷 ===")
            lines.append("系統版本: \(osVersion)")
            lines.append("App bundle ID: \(appIdentifier)")
            lines.append("App 顯示名稱: \(appDisplayName)")
            lines.append("App 版本: \(appVersion) (\(appBuild))")
            lines.append("")
            lines.append("[1] App Group 共享授權")
            lines.append("    \(appGroupStatus)")
            lines.append("")
            lines.append("[2] 主程式 embedded.mobileprovision")
            lines.append("    \(appProvisioning)")
            lines.append("")
            lines.append("[3] 擴展是否被安裝進 App bundle")
            if extensionProbes.isEmpty {
                lines.append("    ✗ PlugIns/ 內找不到任何 .appex")
                lines.append("      → 擴展沒有被安裝，簽名階段就被側載工具剔除了。")
            } else {
                for probe in extensionProbes {
                    lines.append("    ✓ \(probe.folderName)")
                    lines.append("      bundle ID: \(probe.identifier)")
                    lines.append("      版本: \(probe.version) (\(probe.build))")
                    lines.append("      擴展點: \(probe.extensionPoint)")
                    lines.append("      執行檔: \(probe.executableExists ? "存在" : "遺失")")
                    lines.append("      簽章授權: \(probe.provisioning)")
                }
            }
            lines.append("")
            lines.append("=== 報告結束 ===")
            return lines.joined(separator: "\n")
        }
    }

    struct ExtensionProbe {
        let folderName: String
        let identifier: String
        let version: String
        let build: String
        let extensionPoint: String
        let executableExists: Bool
        let provisioning: String
    }

    static func makeSummary() -> Summary {
        let info = Bundle.main.infoDictionary ?? [:]

        return Summary(
            appIdentifier: Bundle.main.bundleIdentifier ?? "unknown",
            appDisplayName: (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String) ?? "unknown",
            appVersion: (info["CFBundleShortVersionString"] as? String) ?? "?",
            appBuild: (info["CFBundleVersion"] as? String) ?? "?",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            appGroupStatus: appGroupStatus(),
            extensionProbes: extensionProbes(),
            appProvisioning: provisioningSummary(at: Bundle.main.bundleURL)
                ?? "找不到 embedded.mobileprovision（此 App 可能未被側載工具重新簽名）"
        )
    }

    // MARK: - 1. App Group 授權

    private static func appGroupStatus() -> String {
        let candidates = SharedAppGroup.candidates.joined(separator: ", ")
        if let resolved = SharedAppGroup.resolvedGroupID {
            return "已取得授權，實際容器 = \(resolved)\n    候選清單 = \(candidates)"
        }
        return "尚未取得授權，候選清單 = \(candidates)"
    }

    // MARK: - 2. 擴展清單

    private static func extensionProbes() -> [ExtensionProbe] {
        guard let pluginsURL = Bundle.main.builtInPlugInsURL,
              let entries = try? FileManager.default.contentsOfDirectory(
                  at: pluginsURL,
                  includingPropertiesForKeys: nil,
                  options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        return entries
            .filter { $0.pathExtension.lowercased() == "appex" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { url in
                let bundle = Bundle(url: url)
                let info = bundle?.infoDictionary ?? [:]
                let executableName = (info["CFBundleExecutable"] as? String) ?? ""
                let extensionDictionary = info["NSExtension"] as? [String: Any]
                let extensionKitDictionary = info["EXAppExtensionAttributes"] as? [String: Any]
                let extensionPoint = (extensionDictionary?["NSExtensionPointIdentifier"] as? String)
                    ?? (extensionKitDictionary?["EXExtensionPointIdentifier"] as? String)
                    ?? "未宣告"

                return ExtensionProbe(
                    folderName: url.lastPathComponent,
                    identifier: bundle?.bundleIdentifier ?? (info["CFBundleIdentifier"] as? String) ?? "unknown",
                    version: (info["CFBundleShortVersionString"] as? String) ?? "?",
                    build: (info["CFBundleVersion"] as? String) ?? "?",
                    extensionPoint: extensionPoint,
                    executableExists: !executableName.isEmpty
                        && FileManager.default.fileExists(atPath: url.appendingPathComponent(executableName).path),
                    provisioning: provisioningSummary(at: url) ?? "找不到 embedded.mobileprovision"
                )
            }
    }

    // MARK: - 3. 讀取 embedded.mobileprovision

    /// 側載工具（SideStore / AltStore）會把新的 provisioning profile 寫進 bundle，
    /// 其中 `Entitlements` 就是最終實際生效的授權，可據此確認 App Group 是否真的被指派。
    private static func provisioningSummary(at bundleURL: URL) -> String? {
        let profileURL = bundleURL.appendingPathComponent("embedded.mobileprovision")
        guard let data = try? Data(contentsOf: profileURL) else { return nil }

        // .mobileprovision 是 CMS 容器，內含一段 XML plist，直接切出該區段解析。
        guard let xmlStart = data.range(of: Data("<?xml".utf8)),
              let xmlEnd = data.range(of: Data("</plist>".utf8), in: xmlStart.lowerBound..<data.endIndex) else {
            return "embedded.mobileprovision 格式無法解析"
        }

        let plistData = data.subdata(in: xmlStart.lowerBound..<xmlEnd.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
            return "embedded.mobileprovision 格式無法解析"
        }

        let entitlements = (plist["Entitlements"] as? [String: Any]) ?? [:]
        let applicationIdentifier = (entitlements["application-identifier"] as? String) ?? "未提供"
        let applicationGroups = (entitlements["com.apple.security.application-groups"] as? [String]) ?? []
        let teamIdentifier = (plist["TeamIdentifier"] as? [String])?.first ?? "未提供"
        let name = (plist["Name"] as? String) ?? "未命名"

        let groupText = applicationGroups.isEmpty
            ? "無 App Group 授權 ✗"
            : "App Group = \(applicationGroups.joined(separator: ", "))"
        return "名稱 = \(name)，Team = \(teamIdentifier)，App ID = \(applicationIdentifier)，\(groupText)"
    }
}
