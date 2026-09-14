import UIKit
import QuartzCore

/// ProMotion 120Hz 全域流暢渲染最佳化中心
public final class ProMotionOptimizer {
    public static let shared = ProMotionOptimizer()
    private var displayLink: CADisplayLink?

    private init() {}

    /// 啟用全域 120Hz 高更新率支援（包含所有彈窗 Sheet、轉場動畫與滾動視圖）
    public func enable120Hz() {
        guard displayLink == nil else { return }

        let link = CADisplayLink(target: self, selector: #selector(displayLinkDidFire))
        if #available(iOS 15.0, *) {
            // 要求系統螢幕更新率維持在 80Hz ~ 120Hz，最優 120Hz
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
        }
        // 加入 .common 模式，使彈窗拖曳、手勢滑動與轉場動畫全程保持 120Hz ProMotion
        link.add(to: .main, forMode: .common)
        self.displayLink = link
    }

    @objc private func displayLinkDidFire() {
        // 心跳回呼：促使 CoreAnimation 與 UIKit 動畫引擎以 120Hz ProMotion 同步更新
    }
}
