import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 界面统一用的颜色。强调色在 AccentColor 资源里，用 Color.accentColor
extension Color {
    /// 页面背景
    static let tvboxBackground = tvboxDynamic(light: 0xF3F4F6, dark: 0x0D0F14)
    /// 卡片、输入框
    static let tvboxSurface = tvboxDynamic(light: 0xFFFFFF, dark: 0x171A21)
    /// 卡片里的次级底色，如设置项的图标格
    static let tvboxSurfaceSecondary = tvboxDynamic(light: 0xE8EAEE, dark: 0x20242D)
    /// 卡片描边
    static let tvboxHairline = tvboxDynamic(light: 0x14161B, dark: 0xFFFFFF, alpha: 0.09)
    /// 压在深色图片上的强调色，不跟系统深浅色走（详情页、首页大卡）
    static let tvboxAccentOnDark = Color(red: 0xF0 / 255, green: 0xA9 / 255, blue: 0x3B / 255)

    private static func tvboxDynamic(light: UInt32, dark: UInt32, alpha: CGFloat = 1) -> Color {
        func components(_ hex: UInt32) -> (CGFloat, CGFloat, CGFloat) {
            (CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255)
        }
        let (lr, lg, lb) = components(light)
        let (dr, dg, db) = components(dark)
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: dr, green: dg, blue: db, alpha: alpha)
                : UIColor(red: lr, green: lg, blue: lb, alpha: alpha)
        })
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: dr, green: dg, blue: db, alpha: alpha)
                : NSColor(red: lr, green: lg, blue: lb, alpha: alpha)
        })
        #else
        return Color(red: lr, green: lg, blue: lb, opacity: alpha)
        #endif
    }
}

/// 海报角上的备注（更新至12集、HD），所有海报卡片统一半透明黑底白字
struct PosterBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.white)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 5))
    }
}

/// 压在封面底部的播放进度条
struct PlaybackProgressBar: View {
    /// 0...1
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.28))
                Capsule().fill(Color.tvboxAccentOnDark)
                    .frame(width: max(3, geometry.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 3)
    }
}

/// 卡片样式：底色加 1pt 描边，不用投影
extension View {
    func tvboxCard(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(Color.tvboxSurface, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.tvboxHairline, lineWidth: 1)
            }
    }
}
