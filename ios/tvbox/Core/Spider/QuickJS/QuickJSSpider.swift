import Foundation
import WebKit
import Compression

/// QuickJS 格式脚本的 Spider 实现
/// 由于 iOS 无法直接执行 QuickJS 字节码，使用 WKWebView 作为 JavaScript 运行环境
/// 支持解析 //bb 和 //DRPY 格式的 Base64 编码脚本
class QuickJSSpider: Spider {
    let siteKey: String
    private let site: SiteBean
    private let httpUtil = HttpUtil.shared
    private var webView: WKWebView?
    private var isInitialized = false
    private let key: String
    
    // 网络请求处理器
    private var messageHandler: QuickJSMessageHandler?
    
    init(site: SiteBean) {
        self.site = site
        self.siteKey = site.key
        self.key = "spider_\(site.key.md5.prefix(8))"
    }
    
    // MARK: - Spider Protocol
    
    func initialize(ext: String?) async throws {
        // 在主线程创建 WKWebView
        try await MainActor.run {
            // 配置 WKWebView
            let config = WKWebViewConfiguration()
            config.preferences.javaScriptEnabled = true
            
            // 添加消息处理器
            let handler = QuickJSMessageHandler()
            self.messageHandler = handler
            config.userContentController.add(handler, name: "log")
            config.userContentController.add(handler, name: "req")
            config.userContentController.add(handler, name: "local")
            
            webView = WKWebView(frame: .zero, configuration: config)
        }
        
        guard webView != nil else {
            throw SpiderError.scriptError("无法创建 WebView")
        }
        
        // 加载爬虫脚本
        try await loadSpiderScript(ext: ext)
        
        isInitialized = true
    }
    
    func homeContent(filter: Bool) async throws -> HomeContent {
        guard isInitialized else {
            throw SpiderError.notInitialized
        }
        
        let result = try await callJS("home", args: [filter])
        return try parseHomeContent(result)
    }
    
    func categoryContent(tid: String, page: Int, filter: Bool, extend: [String: String]) async throws -> CategoryContent {
        guard isInitialized else {
            throw SpiderError.notInitialized
        }
        
        let extendJson = try JSONEncoder().encode(extend)
        let extendStr = String(data: extendJson, encoding: .utf8) ?? "{}"
        
        let result = try await callJS("category", args: [tid, "\(page)", filter, extendStr])
        return try parseCategoryContent(result)
    }
    
    func detailContent(ids: [String]) async throws -> [VodInfo] {
        guard isInitialized else {
            throw SpiderError.notInitialized
        }
        
        let firstId = ids.first ?? ""
        let result = try await callJS("detail", args: [firstId])
        return try parseDetailContent(result)
    }
    
    func searchContent(keyword: String, quick: Bool, page: Int) async throws -> [MovieItem] {
        guard isInitialized else {
            throw SpiderError.notInitialized
        }
        
        let result = try await callJS("search", args: [keyword, quick, "\(page)"])
        return try parseSearchContent(result)
    }
    
    func playerContent(flag: String, id: String, vipFlags: [String]) async throws -> PlayerContent {
        guard isInitialized else {
            throw SpiderError.notInitialized
        }
        
        let vipFlagsJson = try JSONEncoder().encode(vipFlags)
        let vipFlagsStr = String(data: vipFlagsJson, encoding: .utf8) ?? "[]"
        
        let result = try await callJS("play", args: [flag, id, vipFlagsStr])
        return try parsePlayerContent(result)
    }
    
    var supportsQuickSearch: Bool {
        site.isQuickSearchable
    }
    
    func destroy() {
        Task { @MainActor in
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "log")
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "req")
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "local")
            webView = nil
        }
        isInitialized = false
    }
    
    // MARK: - Private Methods
    
    private func loadSpiderScript(ext: String?) async throws {
        // 获取脚本 URL
        var scriptUrl = site.jar ?? ApiConfig.shared.spider
        guard !scriptUrl.isEmpty else {
            throw SpiderError.scriptError("未找到爬虫脚本配置")
        }
        
        // 提取类名
        var className = "Spider"
        if scriptUrl.contains(".js#") || scriptUrl.contains(".js;") {
            let separator = scriptUrl.contains(".js#") ? ".js#" : ".js;"
            let parts = scriptUrl.components(separatedBy: separator)
            if parts.count >= 2 {
                scriptUrl = parts[0] + ".js"
                className = parts[1]
            }
        }
        
        // 处理 ;md5; 格式
        if scriptUrl.contains(";md5;") {
            scriptUrl = scriptUrl.components(separatedBy: ";md5;")[0]
        }
        
        // 下载脚本
        guard let url = URL(string: scriptUrl) else {
            throw SpiderError.scriptError("无效的脚本 URL")
        }
        
        let data = try await httpUtil.data(url: url)
        print("[QuickJSSpider] 下载脚本成功，数据长度: \(data.count)")
        
        // 解析脚本内容
        var scriptContent: String?
        
        // 检查文件格式
        if data.count > 4 {
            let header = Array(data.prefix(4))
            
            // 检查 ZIP/JAR 格式（魔数: 50 4B 03 04 = "PK..")
            if header[0] == 0x50 && header[1] == 0x4B && header[2] == 0x03 && header[3] == 0x04 {
                print("[QuickJSSpider] 检测到 ZIP/JAR 格式，尝试解压")
                scriptContent = try extractJsFromZip(data: data, className: className)
            }
        }
        
        // 如果不是 ZIP，检查 UTF-8 文本格式
        if scriptContent == nil, let utf8Str = String(data: data, encoding: .utf8) {
            if utf8Str.hasPrefix("//bb") {
                // Base64 编码的脚本
                let base64Str = String(utf8Str.dropFirst(4))
                if let decodedData = Data(base64Encoded: base64Str) {
                    // 检查解码后是否是 ZIP
                    if decodedData.count > 4 {
                        let header = Array(decodedData.prefix(4))
                        if header[0] == 0x50 && header[1] == 0x4B {
                            print("[QuickJSSpider] //bb 格式解码后是 ZIP，尝试解压")
                            scriptContent = try extractJsFromZip(data: decodedData, className: className)
                        }
                    }
                }
                
                if scriptContent == nil {
                    print("[QuickJSSpider] 检测到 //bb 格式，尝试查找源码版本")
                    scriptContent = try await tryFetchSourceVersion(originalUrl: scriptUrl)
                }
            } else if utf8Str.hasPrefix("//DRPY") {
                // DRPY 格式
                print("[QuickJSSpider] 检测到 //DRPY 格式，尝试查找源码版本")
                scriptContent = try await tryFetchSourceVersion(originalUrl: scriptUrl)
            } else {
                // 普通 JavaScript 源码
                scriptContent = utf8Str
            }
        }
        
        // 如果是二进制格式（UTF-8 解码失败且不是 ZIP）
        if scriptContent == nil {
            print("[QuickJSSpider] 检测到未知二进制格式，尝试查找源码版本")
            scriptContent = try await tryFetchSourceVersion(originalUrl: scriptUrl)
        }
        
        guard let content = scriptContent, !content.isEmpty else {
            throw SpiderError.unsupported("无法获取脚本源码，此站点可能仅支持 Android")
        }
        
        // 处理脚本格式
        var processedContent = content
        
        if content.contains("__jsEvalReturn") {
            processedContent = content + "\nwindow.\(key) = __jsEvalReturn();"
        } else if content.contains("__JS_SPIDER__") {
            processedContent = content.replacingOccurrences(of: "__JS_SPIDER__", with: "window.\(key)")
        } else if content.contains("export default") {
            // 移除 export 语句，直接赋值给全局变量
            processedContent = content
                .replacingOccurrences(of: "export default", with: "window.\(key) =")
                .replacingOccurrences(of: "export ", with: "// export ")
        }
        
        // 注入全局对象和辅助函数
        let helperScript = buildHelperScript()
        let fullScript = helperScript + "\n\n" + processedContent
        
        // 初始化 Spider
        let initScript = """
        (function() {
            if (window.\(key) && typeof window.\(key).init === 'function') {
                window.\(key).init('\(ext?.replacingOccurrences(of: "'", with: "\\'") ?? "")');
            }
            return 'initialized';
        })();
        """
        
        // 在 WebView 中执行脚本
        try await MainActor.run {
            webView?.loadHTMLString("<html><head></head><body></body></html>", baseURL: nil)
        }
        
        // 等待页面加载
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // 执行脚本
        let _ = try await evaluateJS(fullScript)
        let initResult = try await evaluateJS(initScript)
        print("[QuickJSSpider] 初始化结果: \(initResult)")
    }
    
    /// 从 ZIP/JAR 文件中提取 JavaScript 源码
    private func extractJsFromZip(data: Data, className: String) throws -> String {
        // 使用 iOS 内置的 Archive 支持解压 ZIP
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let zipPath = tempDir.appendingPathComponent("spider.zip")
        let extractPath = tempDir.appendingPathComponent("extracted")
        
        do {
            // 创建临时目录
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: extractPath, withIntermediateDirectories: true)
            
            // 写入 ZIP 文件
            try data.write(to: zipPath)
            
            // 解压 ZIP（使用 Process 或手动解析）
            // iOS 没有内置的 ZIP 解压 API，需要手动解析 ZIP 格式
            let jsContent = try parseZipAndExtractJS(data: data, className: className)
            
            // 清理临时文件
            try? FileManager.default.removeItem(at: tempDir)
            
            return jsContent
        } catch {
            // 清理临时文件
            try? FileManager.default.removeItem(at: tempDir)
            throw error
        }
    }
    
    /// 解析 ZIP 格式并提取 JavaScript 文件
    private func parseZipAndExtractJS(data: Data, className: String) throws -> String {
        // ZIP 文件格式解析
        // Local file header 签名: 50 4B 03 04
        
        var offset = 0
        var jsFiles: [(name: String, content: String)] = []
        
        while offset < data.count - 4 {
            // 检查 Local file header 签名
            guard data[offset] == 0x50 && data[offset + 1] == 0x4B else {
                break
            }
            
            // 检查是文件头还是目录结束
            if data[offset + 2] == 0x01 && data[offset + 3] == 0x02 {
                // Central directory header
                break
            }
            
            if data[offset + 2] == 0x03 && data[offset + 3] == 0x04 {
                // Local file header
                guard offset + 30 <= data.count else { break }
                
                // 读取文件头信息
                let compressionMethod = UInt16(data[offset + 8]) | (UInt16(data[offset + 9]) << 8)
                let compressedSize = Int(UInt32(data[offset + 18]) | (UInt32(data[offset + 19]) << 8) | (UInt32(data[offset + 20]) << 16) | (UInt32(data[offset + 21]) << 24))
                let uncompressedSize = Int(UInt32(data[offset + 22]) | (UInt32(data[offset + 23]) << 8) | (UInt32(data[offset + 24]) << 16) | (UInt32(data[offset + 25]) << 24))
                let fileNameLength = Int(UInt16(data[offset + 26]) | (UInt16(data[offset + 27]) << 8))
                let extraFieldLength = Int(UInt16(data[offset + 28]) | (UInt16(data[offset + 29]) << 8))
                
                guard offset + 30 + fileNameLength <= data.count else { break }
                
                // 读取文件名
                let fileNameData = data.subdata(in: (offset + 30)..<(offset + 30 + fileNameLength))
                let fileName = String(data: fileNameData, encoding: .utf8) ?? ""
                
                // 计算文件数据偏移
                let dataOffset = offset + 30 + fileNameLength + extraFieldLength
                let dataSize = compressionMethod == 0 ? uncompressedSize : compressedSize
                
                guard dataOffset + dataSize <= data.count else { break }
                
                // 读取文件内容
                let fileData = data.subdata(in: dataOffset..<(dataOffset + dataSize))
                
                // 如果是 .js 文件，尝试解压并保存
                if fileName.hasSuffix(".js") {
                    var jsContent: String?
                    
                    if compressionMethod == 0 {
                        // 无压缩
                        jsContent = String(data: fileData, encoding: .utf8)
                    } else if compressionMethod == 8 {
                        // Deflate 压缩
                        if let decompressed = decompressDeflate(data: fileData, expectedSize: uncompressedSize) {
                            jsContent = String(data: decompressed, encoding: .utf8)
                        }
                    }
                    
                    if let content = jsContent, !content.isEmpty {
                        print("[QuickJSSpider] 找到 JS 文件: \(fileName), 大小: \(content.count)")
                        jsFiles.append((name: fileName, content: content))
                    }
                }
                
                // 移动到下一个文件
                offset = dataOffset + dataSize
            } else {
                break
            }
        }
        
        // 优先查找与类名匹配的文件
        if !className.isEmpty && className != "Spider" {
            for file in jsFiles {
                let baseName = (file.name as NSString).deletingPathExtension
                if baseName.lowercased() == className.lowercased() ||
                   file.name.lowercased().contains(className.lowercased()) {
                    print("[QuickJSSpider] 使用匹配的 JS 文件: \(file.name)")
                    return file.content
                }
            }
        }
        
        // 查找主入口文件
        let mainFileNames = ["index.js", "main.js", "spider.js", "app.js"]
        for mainName in mainFileNames {
            if let file = jsFiles.first(where: { $0.name.lowercased().hasSuffix(mainName) }) {
                print("[QuickJSSpider] 使用入口文件: \(file.name)")
                return file.content
            }
        }
        
        // 返回第一个 JS 文件
        if let firstFile = jsFiles.first {
            print("[QuickJSSpider] 使用第一个 JS 文件: \(firstFile.name)")
            return firstFile.content
        }
        
        throw SpiderError.scriptError("ZIP 中未找到 JavaScript 文件")
    }
    
    /// 解压 Deflate 压缩的数据
    private func decompressDeflate(data: Data, expectedSize: Int) -> Data? {
        // 使用 Compression framework 解压
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: expectedSize)
        defer { destinationBuffer.deallocate() }
        
        let decompressedSize = data.withUnsafeBytes { sourcePtr -> Int in
            guard let sourceAddress = sourcePtr.baseAddress else { return 0 }
            
            return compression_decode_buffer(
                destinationBuffer,
                expectedSize,
                sourceAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        
        if decompressedSize > 0 {
            return Data(bytes: destinationBuffer, count: decompressedSize)
        }
        
        return nil
    }
    
    /// 尝试获取脚本的源码版本
    private func tryFetchSourceVersion(originalUrl: String) async throws -> String {
        // 尝试常见的源码 URL 后缀
        let sourceUrls = [
            originalUrl.replacingOccurrences(of: ".txt", with: ".js"),
            originalUrl.replacingOccurrences(of: ".qjs", with: ".js"),
            originalUrl + ".src",
            originalUrl.replacingOccurrences(of: "/qjs/", with: "/js/"),
            originalUrl.replacingOccurrences(of: "_qjs", with: ""),
        ]
        
        for urlStr in sourceUrls where urlStr != originalUrl {
            guard let url = URL(string: urlStr) else { continue }
            
            do {
                print("[QuickJSSpider] 尝试获取源码: \(urlStr)")
                let data = try await httpUtil.data(url: url)
                
                if let content = String(data: data, encoding: .utf8),
                   !content.isEmpty,
                   !content.hasPrefix("//bb"),
                   !content.hasPrefix("//DRPY") {
                    // 验证是否是有效的 JavaScript
                    if content.contains("function") || content.contains("class") || content.contains("var") {
                        print("[QuickJSSpider] 找到源码版本: \(urlStr)")
                        return content
                    }
                }
            } catch {
                // 继续尝试下一个 URL
            }
        }
        
        throw SpiderError.unsupported("无法找到脚本源码版本")
    }
    
    /// 构建辅助脚本
    private func buildHelperScript() -> String {
        return """
        // 模拟 Node.js/QuickJS 环境
        if (typeof globalThis === 'undefined') {
            window.globalThis = window;
        }
        globalThis = window;
        
        // Console
        var console = window.console || {
            log: function() { window.webkit.messageHandlers.log.postMessage(Array.from(arguments).join(' ')); },
            warn: function() { window.webkit.messageHandlers.log.postMessage('[WARN] ' + Array.from(arguments).join(' ')); },
            error: function() { window.webkit.messageHandlers.log.postMessage('[ERROR] ' + Array.from(arguments).join(' ')); }
        };
        
        // Local Storage
        var local = {
            _data: {},
            get: function(key, def) { 
                return localStorage.getItem('spider_' + key) || this._data[key] || def || ''; 
            },
            set: function(key, val) { 
                try { localStorage.setItem('spider_' + key, val); } catch(e) {}
                this._data[key] = val; 
            },
            delete: function(key) { 
                try { localStorage.removeItem('spider_' + key); } catch(e) {}
                delete this._data[key]; 
            },
            clear: function() { this._data = {}; }
        };
        
        // 同步网络请求 (使用 XMLHttpRequest)
        function req(url, options) {
            var xhr = new XMLHttpRequest();
            var method = (options && options.method) || 'GET';
            xhr.open(method, url, false);
            
            if (options && options.headers) {
                for (var key in options.headers) {
                    xhr.setRequestHeader(key, options.headers[key]);
                }
            }
            
            try {
                xhr.send(options && options.body);
                return xhr.responseText;
            } catch (e) {
                console.error('req error:', e);
                return '';
            }
        }
        
        // 异步 fetch 封装
        var http = {
            get: function(url, headers) {
                return new Promise(function(resolve, reject) {
                    fetch(url, { headers: headers || {} })
                        .then(function(r) { return r.text(); })
                        .then(resolve)
                        .catch(reject);
                });
            },
            post: function(url, body, headers) {
                return new Promise(function(resolve, reject) {
                    fetch(url, { method: 'POST', body: body, headers: headers || {} })
                        .then(function(r) { return r.text(); })
                        .then(resolve)
                        .catch(reject);
                });
            }
        };
        
        // Base64 编解码
        function base64Encode(str) {
            return btoa(unescape(encodeURIComponent(str)));
        }
        
        function base64Decode(str) {
            return decodeURIComponent(escape(atob(str)));
        }
        
        // MD5 (简单实现)
        var MD5 = function(s) {
            // 使用 Web Crypto API 或简单 hash
            var hash = 0;
            for (var i = 0; i < s.length; i++) {
                hash = ((hash << 5) - hash) + s.charCodeAt(i);
                hash = hash & hash;
            }
            return Math.abs(hash).toString(16);
        };
        
        // 模块导出处理
        if (typeof module === 'undefined') {
            var module = { exports: {} };
        }
        if (typeof exports === 'undefined') {
            var exports = module.exports;
        }
        """
    }
    
    /// 调用 JavaScript 方法
    private func callJS(_ method: String, args: [Any]) async throws -> String {
        // 构建参数字符串
        let argsStr = args.map { arg -> String in
            switch arg {
            case let str as String:
                return "'\(str.replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: "\\n"))'"
            case let bool as Bool:
                return bool ? "true" : "false"
            case let num as Int:
                return "\(num)"
            case let num as Double:
                return "\(num)"
            default:
                return "'\(String(describing: arg))'"
            }
        }.joined(separator: ", ")
        
        let script = """
        (function() {
            try {
                var spider = window.\(key);
                if (!spider) return JSON.stringify({error: 'spider not found'});
                if (typeof spider.\(method) !== 'function') return JSON.stringify({error: 'method not found: \(method)'});
                var result = spider.\(method)(\(argsStr));
                if (result && typeof result.then === 'function') {
                    // 不支持异步
                    return JSON.stringify({error: 'async not supported in sync call'});
                }
                return typeof result === 'string' ? result : JSON.stringify(result);
            } catch (e) {
                return JSON.stringify({error: e.message || String(e)});
            }
        })();
        """
        
        return try await evaluateJS(script)
    }
    
    /// 执行 JavaScript
    private func evaluateJS(_ script: String) async throws -> String {
        guard let webView = webView else {
            throw SpiderError.notInitialized
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                webView.evaluateJavaScript(script) { result, error in
                    if let error = error {
                        continuation.resume(throwing: SpiderError.scriptError(error.localizedDescription))
                    } else if let result = result as? String {
                        continuation.resume(returning: result)
                    } else if let result = result {
                        continuation.resume(returning: String(describing: result))
                    } else {
                        continuation.resume(returning: "")
                    }
                }
            }
        }
    }
    
    // MARK: - Parse Methods
    
    private func parseHomeContent(_ jsonString: String) throws -> HomeContent {
        guard let data = jsonString.data(using: .utf8) else {
            throw SpiderError.parseError("无法解析 homeContent 数据")
        }
        
        // 检查错误
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? String {
            throw SpiderError.scriptError(error)
        }
        
        let response = try JSONDecoder().decode(MovieCategoryResponse.self, from: data)
        
        return HomeContent(
            categories: response.classData ?? [],
            videos: response.list ?? [],
            filters: response.filters ?? [:]
        )
    }
    
    private func parseCategoryContent(_ jsonString: String) throws -> CategoryContent {
        guard let data = jsonString.data(using: .utf8) else {
            throw SpiderError.parseError("无法解析 categoryContent 数据")
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? String {
            throw SpiderError.scriptError(error)
        }
        
        let response = try JSONDecoder().decode(MovieListResponse.self, from: data)
        
        return CategoryContent(
            videos: response.list ?? [],
            page: response.page ?? 1,
            pageCount: response.pagecount ?? 1,
            total: response.total ?? 0
        )
    }
    
    private func parseDetailContent(_ jsonString: String) throws -> [VodInfo] {
        guard let data = jsonString.data(using: .utf8) else {
            throw SpiderError.parseError("无法解析 detailContent 数据")
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? String {
            throw SpiderError.scriptError(error)
        }
        
        let response = try JSONDecoder().decode(MovieDetailResponse.self, from: data)
        return response.list ?? []
    }
    
    private func parseSearchContent(_ jsonString: String) throws -> [MovieItem] {
        guard let data = jsonString.data(using: .utf8) else {
            throw SpiderError.parseError("无法解析 searchContent 数据")
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? String {
            throw SpiderError.scriptError(error)
        }
        
        let response = try JSONDecoder().decode(MovieListResponse.self, from: data)
        return response.list ?? []
    }
    
    private func parsePlayerContent(_ jsonString: String) throws -> PlayerContent {
        guard let data = jsonString.data(using: .utf8) else {
            throw SpiderError.parseError("无法解析 playerContent 数据")
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? String {
            throw SpiderError.scriptError(error)
        }
        
        struct PlayerResponse: Codable {
            let url: String?
            let header: [String: String]?
            let parse: Int?
            let playUrl: String?
            let jx: String?
            let flag: String?
            let danmaku: String?
            let format: String?
            let subs: [SubtitleInfo]?
        }
        
        let response = try JSONDecoder().decode(PlayerResponse.self, from: data)
        
        return PlayerContent(
            url: response.url ?? "",
            header: response.header,
            parse: response.parse ?? 0,
            playUrl: response.playUrl,
            jxFrom: response.jx,
            flag: response.flag,
            danmaku: response.danmaku,
            format: response.format,
            subs: response.subs
        )
    }
}

// MARK: - WKScriptMessageHandler

class QuickJSMessageHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "log":
            print("[QuickJS] \(message.body)")
        case "req":
            // 处理网络请求
            break
        case "local":
            // 处理本地存储
            break
        default:
            break
        }
    }
}

