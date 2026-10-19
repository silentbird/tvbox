import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

extension EnvironmentValues {
    /// 窗口够宽（Mac、横屏 iPad）时为 true，各页面据此改用 Android 那套横屏布局
    @Entry var tvboxWideLayout = false
}

enum TVBoxLayout {
    /// 宽布局的最小窗口宽度，横屏 iPad 和默认尺寸的 Mac 窗口都超过它，竖屏 iPad 不到
    static let wideMinWidth: CGFloat = 900

    @MainActor
    static func isWide(width: CGFloat) -> Bool {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        // iPhone 横屏也可能超过阈值，但屏幕太矮，仍用手机布局
        if UIDevice.current.userInterfaceIdiom == .phone { return false }
        #endif
        return width >= wideMinWidth
    }
}
