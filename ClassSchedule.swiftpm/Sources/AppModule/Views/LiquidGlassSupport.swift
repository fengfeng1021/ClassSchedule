import SwiftUI

// MARK: - 為什麼需要這一層
//
// Liquid Glass（液態玻璃）是隨 iOS / iPadOS 26 推出的全新材質系統，但**只有在使用
// iOS 26 SDK（Xcode 26 以上）建置時才會被系統啟用**。用舊 SDK 建置的 App 即使安裝在
// iPadOS 26 / 27 上，系統仍會以「相容模式」渲染：工具列按鈕不會出現液態玻璃圓盤、
// 彈窗與工具列也不會使用新的流體材質。這正是本專案在 Swift Playgrounds（使用裝置
// 原生 SDK 建置）與 CI 打包 IPA 之間產生視覺落差的主因。
//
// 這一層處理兩件事：
// 1. 讓 CI 改用 Xcode 26（iOS 26 SDK）建置，使系統自動套用 Liquid Glass。
// 2. 自製元件改呼叫真正的 `glassEffect` API，而不是用半透明純色「模仿」玻璃，
//    避免玻璃疊玻璃造成混濁，也讓動效與系統同步。
//
// 雙重防護：
// - `#if compiler(>=6.2)`：Swift 6.2 隨 Xcode 26 推出，是「這份 SDK 認識
//   Liquid Glass 符號」的編譯期指標。用較舊的 Swift Playgrounds 開啟本專案時，
//   會直接編譯舊版路徑，不會出現「找不到成員」的編譯錯誤。
// - `if #available(iOS 26.0, *)`：執行期判斷，確保在 iOS 16~18 裝置上仍走舊版外觀。

// MARK: - 工具列按鈕

extension View {
    /// 一般工具列動作按鈕（選單、匯入、新增課程⋯）。
    ///
    /// iOS 26 以上交給系統工具列自動提供液態玻璃圓盤底盤，因此**不再**疊加任何
    /// `buttonStyle`；舊版會用 `.bordered` 手動畫底框，在新系統上反而會與系統底盤
    /// 形成雙層外框。
    @ViewBuilder
    func appleToolbarActionStyle() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self
        } else {
            self.buttonStyle(.bordered).tint(.primary)
        }
        #else
        self.buttonStyle(.bordered).tint(.primary)
        #endif
    }
}

// MARK: - 分頁選取膠囊

/// 分頁選取狀態的玻璃底盤。
///
/// iOS 26 以上使用 `glassEffect` + `glassEffectID`，讓被選取的膠囊在
/// `GlassEffectContainer` 內以流體形變方式在分頁之間移動；舊系統則沿用
/// `matchedGeometryEffect` 的白色藥丸滑塊。
struct AppleSelectionPill: ViewModifier {
    let isSelected: Bool
    let identity: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(isSelected ? .regular.interactive() : .identity, in: Capsule())
                .glassEffectID(isSelected ? identity : nil, in: namespace)
        } else {
            content.appleLegacySelectionPill(isSelected: isSelected, namespace: namespace)
        }
        #else
        content.appleLegacySelectionPill(isSelected: isSelected, namespace: namespace)
        #endif
    }
}

/// 分頁切換器的外框軌道。
///
/// iOS 26 以上的工具列本身就會提供玻璃底盤，因此不再額外鋪一層純色軌道，
/// 避免玻璃疊玻璃造成混濁；舊系統則保留原本的淡色膠囊軌道。
struct AppleSegmentedTrack: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.padding(3)
        } else {
            content.appleLegacySegmentedTrack()
        }
        #else
        content.appleLegacySegmentedTrack()
        #endif
    }
}

// MARK: - 舊版材質（iOS 26 之前）

extension View {
    /// 舊版選取藥丸滑塊。
    @ViewBuilder
    fileprivate func appleLegacySelectionPill(isSelected: Bool, namespace: Namespace.ID) -> some View {
        self.background {
            if isSelected {
                Capsule()
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 1.5)
                    .matchedGeometryEffect(id: "ACTIVE_CAPSULE_PILL", in: namespace)
            }
        }
    }

    /// 舊版分頁切換器軌道。
    fileprivate func appleLegacySegmentedTrack() -> some View {
        self
            .padding(3)
            .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
            .overlay(Capsule().stroke(Color.primary.opacity(0.06), lineWidth: 0.8))
    }
}
