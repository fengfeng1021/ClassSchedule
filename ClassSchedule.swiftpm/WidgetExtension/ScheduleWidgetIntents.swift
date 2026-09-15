import AppIntents
import WidgetKit

/// 課表小工具可用的 App Intent。
///
/// 存在這個型別有兩個目的：
/// 1. 使用者可透過「捷徑」App 或互動式小工具按鈕，立即重新整理課表時間軸。
/// 2. 讓 Xcode 的「Extract App Intents Metadata」建置階段產生
///    `Metadata.appintents/extract.actionsdata` 與 `version.json`。
///    iOS 26 的 WidgetKit 在列舉小工具擴展能力時會讀取這份中介資料；
///    手工以 swiftc 組裝的擴展不會有這個目錄，這也是先前小工具始終無法
///    出現在小工具庫的關鍵差異（可正常側載的樣本擴展都含有此目錄）。
///
/// `AppIntent` 自 iOS 16 起可用，因此不需要提高小工具的最低系統版本。
public struct RefreshScheduleIntent: AppIntent {
    public static var title: LocalizedStringResource = "重新整理課表小工具"
    public static var description = IntentDescription("立即重新載入課表小工具的時間軸，顯示最新的課程與進度。")

    /// 只更新時間軸，不需要把 App 帶到前景。
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
