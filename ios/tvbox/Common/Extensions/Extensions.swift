import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Color Extensions
extension Color {
    static let tvboxBlue = Color(red: 0.2, green: 0.5, blue: 0.9)
    static let tvboxPurple = Color(red: 0.6, green: 0.3, blue: 0.8)
    static let tvboxGreen = Color(red: 0.3, green: 0.7, blue: 0.5)
    static let tvboxOrange = Color(red: 0.9, green: 0.5, blue: 0.2)
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - String Extensions
extension String {
    /// 移除 HTML 标签
    var stripHTML: String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
    
    /// 是否为有效 URL
    var isValidURL: Bool {
        if let url = URL(string: self) {
            return url.scheme != nil && url.host != nil
        }
        return false
    }
    
    /// Base64 编码
    var base64Encoded: String? {
        data(using: .utf8)?.base64EncodedString()
    }
    
    /// Base64 解码
    var base64Decoded: String? {
        guard let data = Data(base64Encoded: self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// IDNA 编码（国际化域名转 Punycode）
    /// 例如: "王二小放牛娃.top" -> "xn--xyz.top"
    var idnaEncoded: String? {
        // 检查是否包含非 ASCII 字符
        guard self.contains(where: { !$0.isASCII }) else {
            return self
        }
        
        // 分割域名各部分
        let labels = self.split(separator: ".").map(String.init)
        var encodedLabels: [String] = []
        
        for label in labels {
            if label.contains(where: { !$0.isASCII }) {
                // 对非 ASCII 部分进行 Punycode 编码
                if let encoded = label.punycodeEncoded {
                    encodedLabels.append("xn--" + encoded)
                } else {
                    return nil
                }
            } else {
                encodedLabels.append(label)
            }
        }
        
        return encodedLabels.joined(separator: ".")
    }
    
    /// Punycode 编码
    var punycodeEncoded: String? {
        let base = 36
        let tmin = 1
        let tmax = 26
        let initialBias = 72
        let initialN = 128
        
        var n = initialN
        var delta = 0
        var bias = initialBias
        var output = ""
        
        // 复制所有基本码点
        for char in self.unicodeScalars {
            if char.value < 128 {
                output.append(Character(char))
            }
        }
        
        var h = output.count
        let b = h
        
        if h > 0 {
            output.append("-")
        }
        
        let inputLength = self.unicodeScalars.count
        
        while h < inputLength {
            var m = Int.max
            
            // 找到下一个最小的非基本码点
            for char in self.unicodeScalars {
                let c = Int(char.value)
                if c >= n && c < m {
                    m = c
                }
            }
            
            delta += (m - n) * (h + 1)
            n = m
            
            for char in self.unicodeScalars {
                let c = Int(char.value)
                
                if c < n {
                    delta += 1
                }
                
                if c == n {
                    var q = delta
                    var k = base
                    
                    while true {
                        let t: Int
                        if k <= bias {
                            t = tmin
                        } else if k >= bias + tmax {
                            t = tmax
                        } else {
                            t = k - bias
                        }
                        
                        if q < t {
                            break
                        }
                        
                        let digit = t + (q - t) % (base - t)
                        output.append(encodeDigit(digit))
                        q = (q - t) / (base - t)
                        k += base
                    }
                    
                    output.append(encodeDigit(q))
                    bias = adapt(delta: delta, numPoints: h + 1, firstTime: h == b)
                    delta = 0
                    h += 1
                }
            }
            
            delta += 1
            n += 1
        }
        
        return output
    }
    
    private func encodeDigit(_ d: Int) -> Character {
        if d < 26 {
            return Character(UnicodeScalar(d + 97)!) // a-z
        } else {
            return Character(UnicodeScalar(d - 26 + 48)!) // 0-9
        }
    }
    
    private func adapt(delta: Int, numPoints: Int, firstTime: Bool) -> Int {
        var delta = firstTime ? delta / 700 : delta / 2
        delta += delta / numPoints
        
        var k = 0
        while delta > 455 {
            delta /= 35
            k += 36
        }
        
        return k + 36 * delta / (delta + 38)
    }
}

// MARK: - Date Extensions
extension Date {
    /// 格式化为字符串
    func formatted(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
    
    /// 相对时间描述
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - View Extensions
extension View {
    /// 条件修饰符
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// 隐藏键盘
    #if canImport(UIKit)
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    #endif
}

// MARK: - URL Extensions
extension URL {
    /// 添加查询参数
    func appendingQueryParameters(_ parameters: [String: String]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return self
        }
        
        var queryItems = components.queryItems ?? []
        queryItems.append(contentsOf: parameters.map { URLQueryItem(name: $0.key, value: $0.value) })
        components.queryItems = queryItems
        
        return components.url ?? self
    }
}

// MARK: - Array Extensions
extension Array {
    /// 安全下标访问
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Data Extensions
extension Data {
    /// 转换为十六进制字符串
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - UserDefaults Extensions
extension UserDefaults {
    /// 获取 Codable 对象
    func object<T: Codable>(forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    /// 存储 Codable 对象
    func setCodable<T: Codable>(_ object: T, forKey key: String) {
        let data = try? JSONEncoder().encode(object)
        set(data, forKey: key)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let configDidLoad = Notification.Name("configDidLoad")
    static let siteDidChange = Notification.Name("siteDidChange")
    static let playbackDidStart = Notification.Name("playbackDidStart")
    static let playbackDidEnd = Notification.Name("playbackDidEnd")
}

