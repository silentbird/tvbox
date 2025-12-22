import Foundation

/// 直播源解析器协议
protocol LiveParser {
    /// 解析直播源内容
    /// - Parameter content: 直播源内容字符串
    /// - Returns: 频道组列表
    func parse(content: String) throws -> [LiveChannelGroup]
    
    /// 检测是否能解析该内容
    /// - Parameter content: 直播源内容字符串
    /// - Returns: 是否能解析
    static func canParse(content: String) -> Bool
}

/// 直播源格式类型
enum LiveSourceType: Int {
    case txt = 0      // TXT 格式
    case m3u = 1      // M3U/M3U8 格式
    case json = 2     // TVBOX JSON 格式
    case unknown = -1
    
    /// 自动检测格式
    static func detect(from content: String) -> LiveSourceType {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查 JSON 格式
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            return .json
        }
        
        // 检查 M3U 格式
        if trimmed.hasPrefix("#EXTM3U") {
            return .m3u
        }
        
        // 默认为 TXT 格式
        return .txt
    }
}

/// 直播源解析管理器
class LiveParserManager {
    static let shared = LiveParserManager()
    
    private let httpUtil = HttpUtil.shared
    
    private init() {}
    
    /// 从 URL 加载并解析直播源
    /// - Parameters:
    ///   - urlString: 直播源 URL
    ///   - type: 直播源类型 (可选，不指定则自动检测)
    /// - Returns: 频道组列表
    func loadLiveSource(from urlString: String, type: LiveSourceType? = nil) async throws -> [LiveChannelGroup] {
        guard let url = URL(string: urlString) else {
            throw LiveParserError.invalidUrl
        }
        
        let content = try await httpUtil.string(url: url)
        return try parse(content: content, type: type)
    }
    
    /// 解析直播源内容
    /// - Parameters:
    ///   - content: 直播源内容
    ///   - type: 直播源类型 (可选，不指定则自动检测)
    /// - Returns: 频道组列表
    func parse(content: String, type: LiveSourceType? = nil) throws -> [LiveChannelGroup] {
        let sourceType = type ?? LiveSourceType.detect(from: content)
        
        let parser: LiveParser
        switch sourceType {
        case .txt:
            parser = TxtLiveParser()
        case .m3u:
            parser = M3uLiveParser()
        case .json:
            parser = JsonLiveParser()
        case .unknown:
            throw LiveParserError.unknownFormat
        }
        
        return try parser.parse(content: content)
    }
    
    /// 从 LiveConfig 加载直播源
    /// - Parameter config: 直播配置
    /// - Returns: 频道组列表
    func loadFromConfig(_ config: LiveConfig) async throws -> [LiveChannelGroup] {
        guard let urlString = config.url ?? config.api else {
            throw LiveParserError.noUrl
        }
        
        let type: LiveSourceType?
        if let configType = config.type {
            type = LiveSourceType(rawValue: configType)
        } else {
            type = nil
        }
        
        return try await loadLiveSource(from: urlString, type: type)
    }
}

/// 直播源解析错误
enum LiveParserError: LocalizedError {
    case invalidUrl
    case noUrl
    case unknownFormat
    case parseError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "无效的直播源地址"
        case .noUrl:
            return "未配置直播源地址"
        case .unknownFormat:
            return "未知的直播源格式"
        case .parseError(let message):
            return "解析错误: \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}

