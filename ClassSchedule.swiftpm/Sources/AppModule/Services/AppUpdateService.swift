import Foundation
import SwiftUI

/// GitHub Releases API 回傳格式模型
public struct GitHubReleaseInfo: Codable {
    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlUrl: String?
    public let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case assets
    }
}

public struct GitHubReleaseAsset: Codable {
    public let name: String
    public let browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
    }
}

/// 應用程式自動更新檢測服務（於 App 開啟時自動執行，支援無感背景檢測與一鍵調用更新）
@MainActor
public class AppUpdateService: ObservableObject {
    public static let shared = AppUpdateService()

    @Published public var isChecking: Bool = false
    @Published public var updateAvailable: Bool = false
    @Published public var latestVersion: String = ""
    @Published public var releaseTitle: String = ""
    @Published public var releaseNotes: String = ""
    @Published public var downloadUrl: String = ""
    @Published public var releasePageUrl: String = ""

    // 手動檢測提示彈窗狀態
    @Published public var manualCheckFinished: Bool = false
    @Published public var manualCheckMessage: String = ""

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private let skippedVersionKey = "SkippedAppVersion"

    public init() {}

    /// 檢查是否有新版本發布
    /// - Parameter silent: 若為 true，代表開啟 App 時的靜默背景檢測；若無新版則不打擾使用者。
    public func checkForUpdates(silent: Bool = true) async {
        if isChecking { return }
        isChecking = true
        manualCheckFinished = false

        defer { isChecking = false }

        guard let url = URL(string: "https://api.github.com/repos/fengfeng1021/ClassSchedule/releases/latest") else {
            if !silent {
                manualCheckMessage = "無法連線至更新伺服器。"
                manualCheckFinished = true
            }
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 8

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if !silent {
                    manualCheckMessage = "暫無新版本資訊或伺服器回應異常。"
                    manualCheckFinished = true
                }
                return
            }

            let release = try JSONDecoder().decode(GitHubReleaseInfo.self, from: data)
            let rawTag = release.tagName
            let remoteVersion = rawTag.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))

            let skipped = UserDefaults.standard.string(forKey: skippedVersionKey)

            if isNewerVersion(remoteVersion, than: currentVersion) {
                if silent && skipped == remoteVersion {
                    // 使用者先前已選擇略過此版本
                    return
                }

                self.latestVersion = rawTag
                self.releaseTitle = release.name ?? "ClassSchedule \(rawTag)"
                self.releaseNotes = release.body ?? "包含穩定性優化與細節微調。"
                self.releasePageUrl = release.htmlUrl ?? "https://github.com/fengfeng1021/ClassSchedule/releases"

                // 優先尋找 IPA 檔案的直接下載網址
                if let ipaAsset = release.assets.first(where: { $0.name.hasSuffix(".ipa") }) {
                    self.downloadUrl = ipaAsset.browserDownloadUrl
                } else {
                    self.downloadUrl = "https://github.com/fengfeng1021/ClassSchedule/releases/download/\(rawTag)/ClassSchedule.ipa"
                }

                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    self.updateAvailable = true
                }
            } else {
                if !silent {
                    manualCheckMessage = "目前已是最新版本 (v\(currentVersion))！"
                    manualCheckFinished = true
                }
            }
        } catch {
            if !silent {
                manualCheckMessage = "檢查更新失敗，請確認網路連線是否正常。"
                manualCheckFinished = true
            }
        }
    }

    /// 略過特定版本
    public func skipVersion(_ version: String) {
        let clean = version.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        UserDefaults.standard.set(clean, forKey: skippedVersionKey)
        withAnimation {
            self.updateAvailable = false
        }
    }

    /// 語意化版本大小判定 (例如 1.0.1 > 1.0.0 回傳 true)
    private func isNewerVersion(_ newVer: String, than currentVer: String) -> Bool {
        let v1 = newVer.split(separator: ".").compactMap { Int($0) }
        let v2 = currentVer.split(separator: ".").compactMap { Int($0) }

        let count = max(v1.count, v2.count)
        for i in 0..<count {
            let num1 = i < v1.count ? v1[i] : 0
            let num2 = i < v2.count ? v2[i] : 0
            if num1 > num2 { return true }
            if num1 < num2 { return false }
        }
        return false
    }
}
