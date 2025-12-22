import Foundation

/// 超级解析 - 对应 Android 的 SuperParse.java
/// 支持生成包含多个 iframe 的 HTML 页面用于并发嗅探
class SuperParse {
    static let shared = SuperParse()
    
    /// 缓存的 flag -> webJx 映射
    private var flagWebJx: [String: [String]] = [:]
    
    /// 缓存的解析配置
    private var configs: [String: [String]]?
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 执行超级解析
    /// - Parameters:
    ///   - parsers: 解析器列表 (包含 name, url, type, ext)
    ///   - flag: 播放标志
    ///   - videoUrl: 视频 URL
    /// - Returns: 解析结果
    func parse(parsers: [ParseBean], flag: String, videoUrl: String) -> SuperParseResult {
        // 初始化配置
        initConfigs(parsers: parsers)
        
        // 分离 JSON 解析器和 WebView 解析器
        var jsonJx: [String: String] = [:]
        var webJx: [String] = []
        
        // 根据 flag 查找对应的解析器
        if let targetKeys = configs?[flag], !targetKeys.isEmpty {
            for key in targetKeys {
                if let parser = parsers.first(where: { $0.name == key }) {
                    if parser.type == 1 {
                        jsonJx[parser.name] = mixUrl(parser.url, ext: parser.ext)
                    } else if parser.type == 0 {
                        webJx.append(parser.url)
                    }
                }
            }
        } else {
            // 没有特定 flag 配置，使用所有解析器
            for parser in parsers {
                if parser.type == 1 {
                    jsonJx[parser.name] = mixUrl(parser.url, ext: parser.ext)
                } else if parser.type == 0 {
                    webJx.append(parser.url)
                }
            }
        }
        
        // 缓存 webJx
        if !webJx.isEmpty {
            flagWebJx[flag] = webJx
        }
        
        return SuperParseResult(
            jsonParsers: jsonJx,
            webParsers: webJx,
            flag: flag,
            videoUrl: videoUrl
        )
    }
    
    /// 生成用于 WebView 嗅探的 HTML 页面
    /// - Parameters:
    ///   - flag: 播放标志
    ///   - videoUrl: 视频 URL (Base64 编码)
    /// - Returns: HTML 内容
    func loadHtml(flag: String, encodedUrl: String) -> String? {
        guard let urlData = Data(base64Encoded: encodedUrl, options: [.ignoreUnknownCharacters]),
              let videoUrl = String(data: urlData, encoding: .utf8) else {
            return nil
        }
        
        guard let webJxList = flagWebJx[flag], !webJxList.isEmpty else {
            return nil
        }
        
        let jxsString = webJxList.map { "\"\($0)\"" }.joined(separator: ",")
        
        let html = """
        <!doctype html>
        <html>
        <head>
        <title>解析</title>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
        <meta http-equiv="X-UA-Compatible" content="IE=EmulateIE10" />
        <meta name="renderer" content="webkit|ie-comp|ie-stand">
        <meta name="viewport" content="width=device-width">
        <style>
        body { margin: 0; padding: 0; background: #000; }
        iframe { width: 100%; height: 100%; border: none; position: absolute; }
        </style>
        </head>
        <body>
        <script>
        var apiArray=[\(jxsString)];
        var urlPs="\(videoUrl)";
        var iframeHtml="";
        for(var i=0;i<apiArray.length;i++){
            var URL=apiArray[i]+urlPs;
            iframeHtml=iframeHtml+"<iframe sandbox='allow-scripts allow-same-origin allow-forms' frameborder='0' allowfullscreen='true' webkitallowfullscreen='true' mozallowfullscreen='true' src="+URL+"></iframe>";
        }
        document.write(iframeHtml);
        </script>
        </body>
        </html>
        """
        
        return html
    }
    
    /// 清除缓存
    func clearCache() {
        configs = nil
        flagWebJx.removeAll()
    }
    
    // MARK: - Private Methods
    
    /// 初始化配置 - 解析 ext 中的 flag 数组
    private func initConfigs(parsers: [ParseBean]) {
        if configs != nil { return }
        
        configs = [:]
        
        for parser in parsers {
            guard parser.type == 0 || parser.type == 1,
                  let ext = parser.ext,
                  !ext.isEmpty else {
                continue
            }
            
            // 解析 ext JSON
            guard let extData = ext.data(using: .utf8),
                  let extJson = try? JSONSerialization.jsonObject(with: extData) as? [String: Any],
                  let flags = extJson["flag"] as? [String] else {
                continue
            }
            
            // 为每个 flag 添加该解析器
            for flag in flags {
                if configs![flag] == nil {
                    configs![flag] = []
                }
                configs![flag]?.append(parser.name)
            }
        }
    }
    
    /// 混合 URL 和 ext 参数
    private func mixUrl(_ url: String, ext: String?) -> String {
        guard let ext = ext, !ext.isEmpty else {
            return url
        }
        
        let extBase64 = Data(ext.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        if let idx = url.firstIndex(of: "?") {
            let prefix = String(url[..<url.index(after: idx)])
            let suffix = String(url[url.index(after: idx)...])
            return "\(prefix)cat_ext=\(extBase64)&\(suffix)"
        }
        
        return url
    }
}

// MARK: - SuperParseResult

/// 超级解析结果
struct SuperParseResult {
    /// JSON 解析器 (name -> url)
    let jsonParsers: [String: String]
    
    /// WebView 解析器 URLs
    let webParsers: [String]
    
    /// 播放标志
    let flag: String
    
    /// 原始视频 URL
    let videoUrl: String
    
    /// 是否有 WebView 解析器
    var hasWebParsers: Bool {
        !webParsers.isEmpty
    }
    
    /// 是否有 JSON 解析器
    var hasJsonParsers: Bool {
        !jsonParsers.isEmpty
    }
    
    /// 生成代理 URL (用于 WebView 嗅探)
    func proxyUrl() -> String? {
        guard hasWebParsers else { return nil }
        
        let encodedUrl = Data(videoUrl.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        return "proxy://go=SuperParse&flag=\(flag)&url=\(encodedUrl)"
    }
}

