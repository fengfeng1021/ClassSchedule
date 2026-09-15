import Foundation

/// ProMotion 高刷新率（120Hz）狀態檢查中心。
///
/// 重要修正（v1.1.0）：
/// iOS 只信任 Info.plist 中的 `CADisableMinimumFrameDurationOnPhone` 與
/// `CADisableMinimumFrameDuration` 兩個鍵來解除 60Hz 上限，App 端「無法」也
/// 「不需要」用 `CADisplayLink` 去強迫系統維持 120Hz。
///
/// 舊版曾在主 RunLoop 常駐一條 `CADisplayLink` 心跳，企圖讓彈窗與轉場維持
/// 120Hz，實際上：
/// 1. 它會讓螢幕永遠鎖在最高刷新率，即使畫面靜止也一樣，明顯增加耗電。
/// 2. 它不會改變 Sheet 轉場與滾動的渲染管線，那些本來就由系統依手勢動態調度。
/// 3. Swift Playgrounds 原生執行時完全沒有這段程式碼——這也是兩邊體感不一致的來源之一。
///
/// 因此改為與 Swift Playgrounds 完全一致的做法：只由 Info.plist 解鎖，
/// 其餘交給系統原生調度。
public final class ProMotionOptimizer {
    public static let shared = ProMotionOptimizer()

    private init() {}

    /// Info.plist 是否已正確解鎖 ProMotion 高刷新率。
    public var isHighRefreshRateUnlocked: Bool {
        let onPhone = Bundle.main.object(forInfoDictionaryKey: "CADisableMinimumFrameDurationOnPhone") as? Bool ?? false
        let generic = Bundle.main.object(forInfoDictionaryKey: "CADisableMinimumFrameDuration") as? Bool ?? false
        return onPhone && generic
    }

    /// 相容舊呼叫點：現在僅回報解鎖狀態，不再安裝常駐 `CADisplayLink`。
    @discardableResult
    public func enable120Hz() -> Bool {
        isHighRefreshRateUnlocked
    }
}
