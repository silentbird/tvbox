import Foundation

/// JSON 并发解析器 - 对应 Android 的 JsonParallel
/// 并发调用多个解析接口，返回第一个成功的结果
class JsonParser {
    static let shared = JsonParser()
    
    private let httpUtil = HttpUtil.shared
    private let timeout: TimeInterval = 15.0
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 并发解析
    /// - Parameters:
    ///   - parsers: 解析器列表
    ///   - videoUrl: 视频页面 URL
    /// - Returns: 解析结果
    func parse(parsers: [ParseBean], videoUrl: String) async throws -> ParseResult {
        guard !parsers.isEmpty else {
            throw ParserError.noParser
        }
        
        print("[JsonParser] 开始并发解析, 解析器数量: \(parsers.count)")
        
        // 使用 TaskGroup 并发请求
        return try await withThrowingTaskGroup(of: ParseResult?.self) { group in
            // 添加所有解析任务
            for parser in parsers {
                group.addTask { [self] in
                    do {
                        let result = try await self.singleParse(parser: parser, videoUrl: videoUrl)
                        print("[JsonParser] 解析成功: \(parser.name) -> \(result.url)")
                        return result
                    } catch {
                        print("[JsonParser] 解析失败: \(parser.name) - \(error.localizedDescription)")
                        return nil
                    }
                }
            }
            
            // 返回第一个成功的结果
            for try await result in group {
                if let validResult = result, !validResult.url.isEmpty {
                    // 取消其他任务
                    group.cancelAll()
                    return validResult
                }
            }
            
            throw ParserError.parseFailed
        }
    }
    
    /// 单个解析器解析
    /// - Parameters:
    ///   - parser: 解析器
    ///   - videoUrl: 视频页面 URL
    /// - Returns: 解析结果
    func singleParse(parser: ParseBean, videoUrl: String) async throws -> ParseResult {
        // 构建解析 URL
        let (parseUrl, headers) = buildRequest(parser: parser, videoUrl: videoUrl)
        
        guard let url = URL(string: parseUrl) else {
            throw ParserError.invalidUrl
        }
        
        // 请求解析接口
        let jsonString = try await httpUtil.string(url: url, headers: headers)
        
        // 解析响应
        return try parseResponse(jsonString: jsonString, parserName: parser.name)
    }
    
    // MARK: - Private Methods
    
    /// 构建请求
    private func buildRequest(parser: ParseBean, videoUrl: String) -> (url: String, headers: [String: String]) {
        var parseUrl = parser.url
        var headers: [String: String] = [
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "application/json, text/plain, */*"
        ]
        
        // 解析 ext 参数
        if let ext = parser.ext, !ext.isEmpty,
           let extData = ext.data(using: .utf8),
           let extJson = try? JSONSerialization.jsonObject(with: extData) as? [String: Any] {
            
            // 提取 headers
            if let headerDict = extJson["header"] as? [String: String] {
                headers.merge(headerDict) { _, new in new }
            }
            
            // 处理 flag 筛选 (如果有的话)
            if let flags = extJson["flag"] as? [String] {
                // 可以根据 flag 过滤
            }
            
            // 将 ext 编码到 URL
            if let extBase64 = ext.data(using: .utf8)?.base64EncodedString(options: [.endLineWithLineFeed]) {
                let safeBase64 = extBase64
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "\n", with: "")
                
                if parseUrl.contains("?") {
                    let parts = parseUrl.components(separatedBy: "?")
                    if parts.count == 2 {
                        parseUrl = parts[0] + "?cat_ext=" + safeBase64 + "&" + parts[1]
                    }
                }
            }
        }
        
        // 拼接视频 URL
        let encodedVideoUrl = videoUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? videoUrl
        
        if parseUrl.hasSuffix("=") {
            parseUrl += encodedVideoUrl
        } else if parseUrl.contains("?") {
            parseUrl += "&url=" + encodedVideoUrl
        } else {
            parseUrl += "?url=" + encodedVideoUrl
        }
        
        return (parseUrl, headers)
    }
    
    /// 解析响应
    private func parseResponse(jsonString: String, parserName: String) throws -> ParseResult {
        guard let data = jsonString.data(using: .utf8) else {
            throw ParserError.invalidResponse
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ParserError.invalidResponse
        }
        
        // 提取 URL - 支持多种格式
        var resultUrl: String?
        
        // 格式1: { "data": { "url": "..." } }
        if let dataObj = json["data"] as? [String: Any] {
            resultUrl = dataObj["url"] as? String
        }
        
        // 格式2: { "url": "..." }
        if resultUrl == nil {
            resultUrl = json["url"] as? String
        }
        
        // 格式3: { "data": "..." } (直接是 URL)
        if resultUrl == nil, let dataStr = json["data"] as? String, dataStr.contains("http") {
            resultUrl = dataStr
        }
        
        guard var url = resultUrl, !url.isEmpty else {
            throw ParserError.noUrl
        }
        
        // 处理相对协议
        if url.hasPrefix("//") {
            url = "https:" + url
        }
        
        // 验证 URL
        guard url.hasPrefix("http") else {
            throw ParserError.invalidUrl
        }
        
        // 提取 headers
        var headers: [String: String] = [:]
        
        if let ua = json["user-agent"] as? String, !ua.trimmingCharacters(in: .whitespaces).isEmpty {
            headers["User-Agent"] = ua.trimmingCharacters(in: .whitespaces)
        }
        if let referer = json["referer"] as? String, !referer.trimmingCharacters(in: .whitespaces).isEmpty {
            headers["Referer"] = referer.trimmingCharacters(in: .whitespaces)
        }
        if let headerObj = json["header"] as? [String: String] {
            headers.merge(headerObj) { _, new in new }
        }
        if let headersObj = json["headers"] as? [String: String] {
            headers.merge(headersObj) { _, new in new }
        }
        
        // 检查是否还需要继续解析
        let needParse = (json["parse"] as? Int ?? 0) == 1
        
        return ParseResult(
            url: url,
            headers: headers.isEmpty ? nil : headers,
            needParse: needParse,
            jxFrom: parserName,
            format: json["format"] as? String
        )
    }
}

// MARK: - Parse Result

struct ParseResult {
    let url: String
    let headers: [String: String]?
    let needParse: Bool
    let jxFrom: String?
    let format: String?
    
    init(url: String, headers: [String: String]? = nil, needParse: Bool = false, jxFrom: String? = nil, format: String? = nil) {
        self.url = url
        self.headers = headers
        self.needParse = needParse
        self.jxFrom = jxFrom
        self.format = format
    }
    
    /// 转换为 PlayerContent
    func toPlayerContent() -> PlayerContent {
        return PlayerContent(
            url: url,
            header: headers,
            parse: needParse ? 1 : 0,
            jxFrom: jxFrom,
            format: format
        )
    }
}

