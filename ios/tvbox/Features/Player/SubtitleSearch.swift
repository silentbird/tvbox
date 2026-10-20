import Foundation

/// 在线字幕搜索，可以切换字幕网站。各网站的实现见 SubtitleSearch+*.swift
enum SubtitleSearch {
    enum Source: String, CaseIterable, Identifiable {
        case xunlei
        case assrt
        case openSubtitles

        var id: String { rawValue }

        var name: String {
            switch self {
            case .xunlei: return "迅雷"
            case .assrt: return "射手网(伪)"
            case .openSubtitles: return "OpenSubtitles"
            }
        }

        /// 搜索框下面的提示
        var hint: String? {
            switch self {
            case .xunlei: return "按时长排序，越靠前越可能对得上。剧集可搜「片名 S01E01」"
            case .assrt: return nil
            case .openSubtitles: return "中文片名搜不到，请用英文片名"
            }
        }
    }

    struct Item: Identifiable, Hashable {
        let source: Source
        let name: String
        /// 名字下面的小字，如语言、下载次数
        var detail: String?
        let url: URL
        /// 字幕包，要先列出里面的文件再选
        var isPackage = false
        var id: URL { url }
    }

    enum SearchError: LocalizedError {
        case badResponse(Int)
        case badData

        var errorDescription: String? {
            switch self {
            case .badResponse(402): return "下载次数超过限制，请稍后再试"
            case .badResponse(429), .badResponse(503): return "网站繁忙或请求太频繁，请稍后再试"
            case .badResponse(let code): return "请求失败 (\(code))"
            case .badData: return "字幕文件无法读取"
            }
        }
    }

    /// 和 Android 一样用浏览器的 User-Agent
    static let userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.54 Safari/537.36"
    /// 能解析的格式，见 KSPlayer 的 KSOptions.subtitleParses
    static let supportedExtensions: Set<String> = ["srt", "ass", "ssa", "vtt"]

    /// 返回这一页的结果和总页数。duration 是正在播放的视频时长 (秒)，能用来排序的网站会用到
    static func search(_ keyword: String, page: Int, source: Source, duration: Double = 0) async throws -> (items: [Item], pageCount: Int) {
        switch source {
        case .xunlei: return (try await searchXunlei(keyword, duration: duration), 1)
        case .assrt: return try await searchAssrt(keyword, page: page)
        case .openSubtitles: return (try await searchOpenSubtitles(keyword), 1)
        }
    }

    /// 字幕包里能用的字幕文件
    static func files(in item: Item) async throws -> [Item] {
        switch item.source {
        case .assrt: return try await assrtFiles(in: item)
        case .xunlei, .openSubtitles: return [item]
        }
    }

    static func download(_ file: Item) async throws -> Data {
        var request = URLRequest(url: file.url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if file.source == .assrt {
            request.setValue("https://secure.assrt.net", forHTTPHeaderField: "Referer")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response)
        // OpenSubtitles 给的是 .gz
        if data.starts(with: [0x1F, 0x8B]) {
            guard let unzipped = gunzip(data) else { throw SearchError.badData }
            return unzipped
        }
        return data
    }

    // MARK: - 工具

    static func fetch(_ request: URLRequest) async throws -> Data {
        var request = request
        if request.value(forHTTPHeaderField: "User-Agent") == nil {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response)
        return data
    }

    private static func check(_ response: URLResponse) throws {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SearchError.badResponse(http.statusCode)
        }
    }

    static func isSupported(_ name: String) -> Bool {
        supportedExtensions.contains((name as NSString).pathExtension.lowercased())
    }

    /// 每个匹配的整体和各分组
    static func matches(of pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let string = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: string.length)).map { match in
            (0..<match.numberOfRanges).map { index in
                let range = match.range(at: index)
                return range.location == NSNotFound ? "" : string.substring(with: range)
            }
        }
    }

    static func decodeEntities(_ text: String) -> String {
        text.replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    /// 去掉 gzip 的头尾，中间是系统能解的 DEFLATE 数据
    private static func gunzip(_ data: Data) -> Data? {
        let bytes = [UInt8](data)
        guard bytes.count > 18, bytes[2] == 8 else { return nil }
        let flags = bytes[3]
        var index = 10
        if flags & 0x04 != 0 { // FEXTRA
            guard index + 2 <= bytes.count else { return nil }
            index += 2 + Int(bytes[index]) + Int(bytes[index + 1]) << 8
        }
        for flag: UInt8 in [0x08, 0x10] where flags & flag != 0 { // FNAME、FCOMMENT，以 0 结尾
            while index < bytes.count, bytes[index] != 0 { index += 1 }
            index += 1
        }
        if flags & 0x02 != 0 { index += 2 } // FHCRC
        guard index < bytes.count - 8 else { return nil }
        let deflated = Data(bytes[index..<(bytes.count - 8)]) as NSData
        return try? deflated.decompressed(using: .zlib) as Data
    }
}
