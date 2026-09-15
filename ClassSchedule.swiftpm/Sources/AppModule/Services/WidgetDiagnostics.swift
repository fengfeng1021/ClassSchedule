import Foundation

/// 小工具註冊診斷中心。
///
/// 目的：在**不需要 Xcode、也不需要連接電腦**的前提下，判斷桌面小工具為什麼沒有出現在
/// 小工具庫。整個鏈路只有三個環節會失敗，逐項檢查即可定位：
///
/// 1. `PlugIns/*.appex` 是否真的被安裝進 App bundle。
/// 2. 擴展的 provisioning profile「是否涵蓋擴展自己的 bundle ID」。
///    這是側載最隱蔽的失敗點：SideStore 安裝時若選擇
///    「Keep App Extensions (Use Main Profile)」，會讓擴展沿用主程式的 profile，
///    於是擴展的 `application-identifier` 指向主程式而非擴展本身，
///    iOS 的 installd 就不會註冊這個擴展 —— App 完全正常、擴展檔案也在，
///    但小工具永遠不會出現在小工具庫。
/// 3. App Group 共享授權是否生效（只影響小工具讀不讀得到課表資料）。
///
/// 全部使用公開 API 讀取自己 bundle 內的檔案，不涉及任何私有 API。
enum WidgetDiagnostics {

    // MARK: - Provisioning Profile 資訊

    struct ProvisioningInfo {
        let name: String
        let teamIdentifier: String
        let applicationIdentifier: String
        let applicationGroups: [String]

        var summary: String {
            let groupText = applicationGroups.isEmpty
                ? "無 App Group 授權"
                : "App Group = \(applicationGroups.joined(separator: ", "))"
            return "名稱 = \(name)，Team = \(teamIdentifier)，App ID = \(applicationIdentifier)，\(groupText)"
        }

        /// `application-identifier` 的格式為 `<TeamID>.<AppID>`，
        /// 若 App ID 使用萬用字元則為 `<TeamID>.*`。
        /// 回傳這份 profile 是否涵蓋指定的 bundle ID。
        func covers(bundleIdentifier: String) -> Bool {
            guard let firstDot = applicationIdentifier.firstIndex(of: ".") else { return false }
            let identifier = String(applicationIdentifier[applicationIdentifier.index(after: firstDot)...])

            if identifier == "*" {
                return true
            }
            if identifier.hasSuffix(".*") {
                let prefix = String(identifier.dropLast(2))
                return bundleIdentifier.hasPrefix(prefix + ".")
            }
            return identifier == bundleIdentifier
        }
    }

    // MARK: - 擴展探測結果

    struct ExtensionProbe {
        let folderName: String
        let identifier: String
        let version: String
        let build: String
        let extensionPoint: String
        let executableExists: Bool
        let provisioning: ProvisioningInfo?

        /// 簽章是否涵蓋擴展自己的 bundle ID（nil 表示找不到 profile）。
        var isProvisioningValid: Bool? {
            provisioning.map { $0.covers(bundleIdentifier: identifier) }
        }
    }

    // MARK: - 環境摘要

    struct Summary {
        let appIdentifier: String
        let appDisplayName: String
        let appVersion: String
        let appBuild: String
        let osVersion: String
        let appGroupStatus: String
        let appProvisioning: ProvisioningInfo?
        let extensionProbes: [ExtensionProbe]

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
            lines.append("    \(appProvisioning?.summary ?? "找不到 embedded.mobileprovision")")
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
                    lines.append("      簽章授權: \(probe.provisioning?.summary ?? "找不到 embedded.mobileprovision")")

                    if probe.isProvisioningValid == false {
                        lines.append("      ⚠️ 簽章不符：這份 profile 的 App ID 沒有涵蓋擴展的 bundle ID，")
                        lines.append("         iOS 不會註冊這個擴展，小工具因此不會出現在小工具庫。")
                        lines.append("         原因：安裝時選了「Keep App Extensions (Use Main Profile)」。")
                        lines.append("         解法：重新安裝，改選「Keep App Extensions (Register App ID for Each Extension)」。")
                    }
                }
            }
            lines.append("")
            lines.append("=== 報告結束 ===")
            return lines.joined(separator: "\n")
        }
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
            appProvisioning: provisioningInfo(at: Bundle.main.bundleURL),
            extensionProbes: extensionProbes()
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
                    provisioning: provisioningInfo(at: url)
                )
            }
    }

    // MARK: - 3. 讀取 embedded.mobileprovision

    /// 側載工具（SideStore / AltStore）會把新的 provisioning profile 寫進 bundle，
    /// 其中 `Entitlements` 就是最終實際生效的授權。
    private static func provisioningInfo(at bundleURL: URL) -> ProvisioningInfo? {
        let profileURL = bundleURL.appendingPathComponent("embedded.mobileprovision")
        guard let data = try? Data(contentsOf: profileURL) else { return nil }

        // .mobileprovision 是 CMS 容器，內含一段 XML plist，直接切出該區段解析。
        guard let xmlStart = data.range(of: Data("<?xml".utf8)),
              let xmlEnd = data.range(of: Data("</plist>".utf8), in: xmlStart.lowerBound..<data.endIndex) else {
            return nil
        }

        let plistData = data.subdata(in: xmlStart.lowerBound..<xmlEnd.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
            return nil
        }

        let entitlements = (plist["Entitlements"] as? [String: Any]) ?? [:]

        return ProvisioningInfo(
            name: (plist["Name"] as? String) ?? "未命名",
            teamIdentifier: (plist["TeamIdentifier"] as? [String])?.first ?? "未提供",
            applicationIdentifier: (entitlements["application-identifier"] as? String) ?? "未提供",
            applicationGroups: (entitlements["com.apple.security.application-groups"] as? [String]) ?? []
        )
    }
}
