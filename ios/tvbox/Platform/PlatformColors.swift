import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    static var tvboxSystemBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor.systemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: NSColor.windowBackgroundColor)
        #else
        Color.white
        #endif
    }

    static var tvboxSystemGroupedBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor.systemGroupedBackground)
        #elseif canImport(AppKit)
        Color(nsColor: NSColor.windowBackgroundColor)
        #else
        Color(red: 0.95, green: 0.95, blue: 0.97)
        #endif
    }

    static var tvboxSystemGray5: Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor.systemGray5)
        #elseif canImport(AppKit)
        // AppKit 没有 systemGray5，按 iOS 的浅色/深色取值，否则深色模式下是浅灰底配白字
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.173, green: 0.173, blue: 0.180, alpha: 1)
                : NSColor(red: 0.898, green: 0.898, blue: 0.918, alpha: 1)
        })
        #else
        Color(red: 0.82, green: 0.82, blue: 0.84)
        #endif
    }

    static var tvboxSystemGray6: Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor.systemGray6)
        #elseif canImport(AppKit)
        Color(nsColor: NSColor.controlBackgroundColor)
        #else
        Color(red: 0.94, green: 0.94, blue: 0.96)
        #endif
    }
}
