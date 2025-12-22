import Foundation

/// 解析管理器 - 对应 Android 的解析功能
/// 负责将 VIP 视频链接解析为可播放的直链
class ParserManager {
    static let shared = ParserManager()
    
    private let httpUtil = HttpUtil.shared
    private let apiConfig = ApiConfig.shared
    private var snifferWebView: SnifferWebView?
    
    /// 嗅探超时时间 (秒)
    var sniffTimeout: TimeInterval = 20.0
    
    /// 最大递归解析次数
    private let maxParseDepth = 3
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 解析播放地址
    /// - Parameters:
    ///   - content: 播放内容
    ///   - parseBean: 指定的解析器 (可选，默认使用配置的默认解析器)
    /// - Returns: 解析后的播放内容
    func parse(content: PlayerContent, parseBean: ParseBean? = nil) async throws -> PlayerContent {
        return try await parseWithDepth(content: content, parseBean: parseBean, depth: 0)
    }
    
    /// 递归解析 (支持多次解析)
    private func parseWithDepth(content: PlayerContent, parseBean: ParseBean?, depth: Int) async throws -> PlayerContent {
        // 如果不需要解析，直接返回
        guard content.needParse else {
            return content
        }
        
        // 防止无限递归
        guard depth < maxParseDepth else {
            print("[ParserManager] 达到最大解析深度 \(maxParseDepth)，停止递归")
            return content
        }
        
        // 确定使用的解析器
        let parser = parseBean ?? getParser(for: content)
        
        guard let parser = parser else {
            // 没有可用的解析器，返回原始内容
            return content
        }
        
        var result = try await doParse(content: content, parser: parser)
        
        // 如果结果仍需解析，递归调用
        if result.needParse && !result.url.isEmpty {
            print("[ParserManager] 解析结果仍需继续解析 (depth=\(depth + 1))")
            result = try await parseWithDepth(content: result, parseBean: nil, depth: depth + 1)
        }
        
        return result
    }
    
    /// 使用指定解析器解析
    /// - Parameters:
    ///   - url: 视频页面 URL
    ///   - parser: 解析器
    /// - Returns: 解析后的播放内容
    func parse(url: String, parser: ParseBean) async throws -> PlayerContent {
        var content = PlayerContent(url: url, parse: 1)
        return try await doParse(content: content, parser: parser)
    }
    
    // MARK: - Private Methods
    
    /// 获取解析器
    private func getParser(for content: PlayerContent) -> ParseBean? {
        // 如果指定了 playUrl，创建临时解析器
        if let playUrl = content.playUrl, !playUrl.isEmpty {
            if playUrl.hasPrefix("json:") {
                return ParseBean(name: "临时解析", url: String(playUrl.dropFirst(5)), type: 1)
            } else if playUrl.hasPrefix("parse:") {
                let parseName = String(playUrl.dropFirst(6))
                return apiConfig.parses.first { $0.name == parseName }
            } else {
                return ParseBean(name: "临时解析", url: playUrl, type: 0)
            }
        }
        
        // 使用默认解析器
        return apiConfig.defaultParse
    }
    
    /// 执行解析
    private func doParse(content: PlayerContent, parser: ParseBean) async throws -> PlayerContent {
        switch parser.type {
        case 0:
            // WebView 嗅探
            return try await webViewSniff(content: content, parser: parser)
            
        case 1:
            // JSON 解析
            return try await jsonParse(content: content, parser: parser)
            
        case 2:
            // JSON 扩展 - 并发解析所有 JSON 解析器
            return try await jsonExtParse(content: content)
            
        case 3:
            // JSON 聚合
            return try await jsonMixParse(content: content, parser: parser)
            
        case 4:
            // 超级解析
            return try await superParse(content: content)
            
        default:
            return content
        }
    }
    
    /// JSON 解析 (type=1)
    private func jsonParse(content: PlayerContent, parser: ParseBean) async throws -> PlayerContent {
        let parseUrl = buildParseUrl(parser: parser, videoUrl: content.url)
        
        guard let url = URL(string: parseUrl) else {
            throw ParserError.invalidUrl
        }
        
        // 构建请求头
        var headers: [String: String] = [:]
        if let ext = parser.ext, let extData = ext.data(using: .utf8) {
            if let extJson = try? JSONSerialization.jsonObject(with: extData) as? [String: Any],
               let headerDict = extJson["header"] as? [String: String] {
                headers = headerDict
            }
        }
        
        let jsonString = try await httpUtil.string(url: url, headers: headers)
        return try parseJsonResponse(jsonString: jsonString, originalUrl: content.url)
    }
    
    /// JSON 扩展解析 (type=2) - 并发解析
    private func jsonExtParse(content: PlayerContent) async throws -> PlayerContent {
        let jsonParsers = apiConfig.parses.filter { $0.type == 1 }
        
        guard !jsonParsers.isEmpty else {
            throw ParserError.noParser
        }
        
        // 并发请求所有解析器
        return try await withThrowingTaskGroup(of: PlayerContent?.self) { group in
            for parser in jsonParsers {
                group.addTask {
                    do {
                        let result = try await self.jsonParse(content: content, parser: parser)
                        if !result.url.isEmpty && result.url.hasPrefix("http") {
                            return result
                        }
                        return nil
                    } catch {
                        return nil
                    }
                }
            }
            
            // 返回第一个成功的结果
            for try await result in group {
                if let validResult = result {
                    group.cancelAll()
                    return validResult
                }
            }
            
            throw ParserError.parseFailed
        }
    }
    
    /// JSON 聚合解析 (type=3)
    private func jsonMixParse(content: PlayerContent, parser: ParseBean) async throws -> PlayerContent {
        // 先尝试 JSON 扩展解析
        do {
            return try await jsonExtParse(content: content)
        } catch {
            // 失败则返回原始内容
            return content
        }
    }
    
    /// 超级解析 (type=4)
    private func superParse(content: PlayerContent) async throws -> PlayerContent {
        // 获取所有可用的解析器
        let availableParsers = apiConfig.parses.filter { $0.type == 1 || $0.type == 0 }
        
        // 使用 SuperParse 分析解析器
        let flag = content.flag ?? "default"
        let superResult = SuperParse.shared.parse(
            parsers: availableParsers,
            flag: flag,
            videoUrl: content.url
        )
        
        // 1. 先尝试 JSON 并发解析
        if superResult.hasJsonParsers {
            do {
                let result = try await jsonParallelParse(
                    parsers: superResult.jsonParsers,
                    videoUrl: content.url
                )
                if !result.url.isEmpty && result.url.hasPrefix("http") {
                    return result
                }
            } catch {
                print("[ParserManager] JSON 并发解析失败: \(error)")
            }
        }
        
        // 2. 如果有 WebView 解析器，尝试嗅探
        if superResult.hasWebParsers {
            // 生成包含多个 iframe 的 HTML
            if let html = SuperParse.shared.loadHtml(
                flag: flag,
                encodedUrl: Data(content.url.utf8).base64EncodedString()
            ) {
                do {
                    return try await superWebViewSniff(html: html, videoUrl: content.url)
                } catch {
                    print("[ParserManager] SuperParse WebView 嗅探失败: \(error)")
                }
            }
            
            // 降级：逐个尝试 WebView 解析器
            for parserUrl in superResult.webParsers {
                let tempParser = ParseBean(name: "temp", url: parserUrl, type: 0)
                do {
                    return try await webViewSniff(content: content, parser: tempParser)
                } catch {
                    print("[ParserManager] WebView 嗅探失败: \(parserUrl)")
                }
            }
        }
        
        return content
    }
    
    /// JSON 并发解析
    private func jsonParallelParse(parsers: [String: String], videoUrl: String) async throws -> PlayerContent {
        guard !parsers.isEmpty else {
            throw ParserError.noParser
        }
        
        return try await withThrowingTaskGroup(of: PlayerContent?.self) { group in
            for (name, parseUrl) in parsers {
                group.addTask {
                    do {
                        let fullUrl = parseUrl + (videoUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? videoUrl)
                        guard let url = URL(string: fullUrl) else { return nil }
                        
                        let jsonString = try await self.httpUtil.string(url: url, headers: [:])
                        var result = try self.parseJsonResponse(jsonString: jsonString, originalUrl: videoUrl)
                        result.jxFrom = name
                        
                        if !result.url.isEmpty && result.url.hasPrefix("http") {
                            return result
                        }
                        return nil
                    } catch {
                        return nil
                    }
                }
            }
            
            // 返回第一个成功的结果
            for try await result in group {
                if let validResult = result {
                    group.cancelAll()
                    return validResult
                }
            }
            
            throw ParserError.parseFailed
        }
    }
    
    /// SuperParse WebView 嗅探 (使用生成的 HTML)
    private func superWebViewSniff(html: String, videoUrl: String) async throws -> PlayerContent {
        let sniffer = SnifferWebView()
        
        // 创建 data URL 加载 HTML
        let dataUrl = "data:text/html;charset=utf-8," + (html.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? html)
        
        let sniffedVideo = try await sniffer.sniff(
            url: dataUrl,
            timeout: sniffTimeout,
            userAgent: nil,
            headers: nil
        )
        
        print("[ParserManager] SuperParse 嗅探成功: \(sniffedVideo.url)")
        
        return sniffedVideo.toPlayerContent()
    }
    
    // MARK: - WebView 嗅探
    
    /// WebView 嗅探解析 (type=0)
    private func webViewSniff(content: PlayerContent, parser: ParseBean) async throws -> PlayerContent {
        let parseUrl = buildParseUrl(parser: parser, videoUrl: content.url)
        
        print("[ParserManager] 开始 WebView 嗅探: \(parseUrl)")
        
        // 解析 ext 获取 headers 和 ua
        var headers: [String: String]?
        var userAgent: String?
        
        if let ext = parser.ext, !ext.isEmpty {
            if let extData = ext.data(using: .utf8),
               let extJson = try? JSONSerialization.jsonObject(with: extData) as? [String: Any] {
                headers = extJson["header"] as? [String: String]
                userAgent = extJson["ua"] as? String ?? extJson["user-agent"] as? String
            }
        }
        
        // 创建嗅探器
        let sniffer = SnifferWebView()
        
        let sniffedVideo = try await sniffer.sniff(
            url: parseUrl,
            timeout: sniffTimeout,
            userAgent: userAgent,
            headers: headers
        )
        
        print("[ParserManager] 嗅探成功: \(sniffedVideo.url)")
        
        return sniffedVideo.toPlayerContent()
    }
    
    /// 构建解析 URL
    private func buildParseUrl(parser: ParseBean, videoUrl: String) -> String {
        var parseUrl = parser.url
        
        // 处理 ext 参数
        if let ext = parser.ext, !ext.isEmpty {
            if let extBase64 = ext.data(using: .utf8)?.base64EncodedString() {
                if parseUrl.contains("?") {
                    parseUrl = parseUrl.replacingOccurrences(
                        of: "?",
                        with: "?cat_ext=\(extBase64)&"
                    )
                } else {
                    parseUrl += "?cat_ext=\(extBase64)"
                }
            }
        }
        
        // 拼接视频 URL
        let encodedVideoUrl = videoUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? videoUrl
        
        if parseUrl.contains("?") {
            return parseUrl + "&url=" + encodedVideoUrl
        } else {
            return parseUrl + encodedVideoUrl
        }
    }
    
    /// 解析 JSON 响应
    private func parseJsonResponse(jsonString: String, originalUrl: String) throws -> PlayerContent {
        guard let data = jsonString.data(using: .utf8) else {
            throw ParserError.invalidResponse
        }
        
        // 尝试解析 JSON
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ParserError.invalidResponse
        }
        
        // 提取 URL
        var resultUrl: String?
        if let dataObj = json["data"] as? [String: Any] {
            resultUrl = dataObj["url"] as? String
        } else {
            resultUrl = json["url"] as? String
        }
        
        guard var url = resultUrl, !url.isEmpty else {
            throw ParserError.noUrl
        }
        
        // 处理相对协议
        if url.hasPrefix("//") {
            url = "http:" + url
        }
        
        // 验证 URL
        guard url.hasPrefix("http") else {
            throw ParserError.invalidUrl
        }
        
        // 提取 headers
        var headers: [String: String] = [:]
        if let ua = json["user-agent"] as? String, !ua.isEmpty {
            headers["User-Agent"] = ua
        }
        if let referer = json["referer"] as? String, !referer.isEmpty {
            headers["Referer"] = referer
        }
        if let headerObj = json["header"] as? [String: String] {
            headers.merge(headerObj) { _, new in new }
        }
        
        // 检查是否还需要继续解析
        let needParse = (json["parse"] as? Int ?? 0) == 1
        
        return PlayerContent(
            url: url,
            header: headers.isEmpty ? nil : headers,
            parse: needParse ? 1 : 0,
            jxFrom: json["jxFrom"] as? String
        )
    }
}

// MARK: - Parser Errors

enum ParserError: LocalizedError {
    case noParser
    case invalidUrl
    case invalidResponse
    case noUrl
    case parseFailed
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .noParser:
            return "没有可用的解析器"
        case .invalidUrl:
            return "无效的解析地址"
        case .invalidResponse:
            return "解析响应格式错误"
        case .noUrl:
            return "解析未返回播放地址"
        case .parseFailed:
            return "解析失败"
        case .timeout:
            return "解析超时"
        }
    }
}

