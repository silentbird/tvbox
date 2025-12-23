import Foundation
import JavaScriptCore
import Compression

/// JavaScript 类型站点的 Spider 实现
/// 使用 JavaScriptCore 执行 JS 脚本
/// 对应 Android 中的 JAR/JS 类型站点 (type = 3)
class JsSpider: Spider {
    let siteKey: String
    private let site: SiteBean
    private let httpUtil = HttpUtil.shared
    private var jsContext: JSContext?
    private var isInitialized = false
    
    init(site: SiteBean) {
        self.site = site
        self.siteKey = site.key
    }
    
    // MARK: - Spider Protocol
    
    func initialize(ext: String?) async throws {
        // 创建 JavaScript 上下文
        jsContext = JSContext()
        
        guard let context = jsContext else {
            throw SpiderError.scriptError("无法创建 JavaScript 上下文")
        }
        
        // 设置异常处理
        context.exceptionHandler = { context, exception in
            if let exc = exception {
                print("JS Error: \(exc)")
            }
        }
        
        // 注入全局对象和函数
        injectGlobalObjects(context)
        
        // 加载爬虫脚本
        try await loadSpiderScript(context, ext: ext)
        
        isInitialized = true
    }
    
    func homeContent(filter: Bool) async throws -> HomeContent {
        guard isInitialized, let context = jsContext else {
            throw SpiderError.notInitialized
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    let filterStr = filter ? "true" : "false"
                    
                    // 注意：JS 脚本中的方法名是 home，不是 homeContent（参照 Android JsSpider）
                    guard let result = context.evaluateScript("spider.home(\(filterStr))") else {
                        continuation.resume(throwing: SpiderError.scriptError("home 返回空"))
                        return
                    }
                    
                    let content = try self.parseHomeContent(result)
                    continuation.resume(returning: content)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func categoryContent(tid: String, page: Int, filter: Bool, extend: [String: String]) async throws -> CategoryContent {
        guard isInitialized, let context = jsContext else {
            throw SpiderError.notInitialized
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    let extendJson = try JSONEncoder().encode(extend)
                    let extendStr = String(data: extendJson, encoding: .utf8) ?? "{}"
                    
                    // 注意：JS 脚本中的方法名是 category，不是 categoryContent（参照 Android JsSpider）
                    // 参数顺序: tid, pg, filter, extend（extend 需要解析为 JS 对象）
                    guard let result = context.evaluateScript("spider.category('\(tid)', '\(page)', \(filter), JSON.parse('\(extendStr.replacingOccurrences(of: "'", with: "\\'"))'))") else {
                        continuation.resume(throwing: SpiderError.scriptError("category 返回空"))
                        return
                    }
                    
                    let content = try self.parseCategoryContent(result)
                    continuation.resume(returning: content)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func detailContent(ids: [String]) async throws -> [VodInfo] {
        guard isInitialized, let context = jsContext else {
            throw SpiderError.notInitialized
        }
        
        // 注意：Android 只传递第一个 id，而不是整个数组
        let firstId = ids.first ?? ""
        let escapedId = firstId.replacingOccurrences(of: "'", with: "\\'")
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    // 注意：JS 脚本中的方法名是 detail，不是 detailContent（参照 Android JsSpider）
                    guard let result = context.evaluateScript("spider.detail('\(escapedId)')") else {
                        continuation.resume(throwing: SpiderError.scriptError("detail 返回空"))
                        return
                    }
                    
                    let vodInfos = try self.parseDetailContent(result)
                    continuation.resume(returning: vodInfos)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func searchContent(keyword: String, quick: Bool, page: Int) async throws -> [MovieItem] {
        guard isInitialized, let context = jsContext else {
            throw SpiderError.notInitialized
        }
        
        let escapedKeyword = keyword.replacingOccurrences(of: "'", with: "\\'")
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    // 注意：JS 脚本中的方法名是 search，不是 searchContent（参照 Android JsSpider）
                    // Android 支持两种调用方式：search(key, quick) 和 search(key, quick, pg)
                    let script: String
                    if page > 1 {
                        script = "spider.search('\(escapedKeyword)', \(quick), '\(page)')"
                    } else {
                        script = "spider.search('\(escapedKeyword)', \(quick))"
                    }
                    
                    print("[JsSpider] 执行搜索: \(script)")
                    
                    guard let result = context.evaluateScript(script) else {
                        continuation.resume(throwing: SpiderError.scriptError("search 返回空"))
                        return
                    }
                    
                    let resultStr = result.toString() ?? ""
                    print("[JsSpider] 搜索结果: \(resultStr.prefix(500))")
                    
                    let movies = try self.parseSearchContent(result)
                    print("[JsSpider] 解析到 \(movies.count) 个搜索结果")
                    continuation.resume(returning: movies)
                } catch {
                    print("[JsSpider] 搜索解析错误: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func playerContent(flag: String, id: String, vipFlags: [String]) async throws -> PlayerContent {
        guard isInitialized, let context = jsContext else {
            throw SpiderError.notInitialized
        }
        
        let vipFlagsJson = try JSONEncoder().encode(vipFlags)
        let vipFlagsStr = String(data: vipFlagsJson, encoding: .utf8) ?? "[]"
        
        let escapedId = id.replacingOccurrences(of: "'", with: "\\'")
        let escapedFlag = flag.replacingOccurrences(of: "'", with: "\\'")
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    // 注意：JS 脚本中的方法名是 play，不是 playerContent（参照 Android JsSpider）
                    // vipFlags 需要作为 JS 数组传递
                    guard let result = context.evaluateScript("spider.play('\(escapedFlag)', '\(escapedId)', JSON.parse('\(vipFlagsStr)'))") else {
                        continuation.resume(throwing: SpiderError.scriptError("play 返回空"))
                        return
                    }
                    
                    let content = try self.parsePlayerContent(result)
                    continuation.resume(returning: content)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    var supportsQuickSearch: Bool {
        site.isQuickSearchable
    }
    
    func destroy() {
        jsContext = nil
        isInitialized = false
    }
    
    // MARK: - Private Methods
    
    private func injectGlobalObjects(_ context: JSContext) {
        // 注入 console.log
        let consoleLog: @convention(block) (String) -> Void = { message in
            print("[JS Console] \(message)")
        }
        context.setObject(consoleLog, forKeyedSubscript: "_consoleLog" as NSString)
        context.evaluateScript("var console = { log: _consoleLog, warn: _consoleLog, error: _consoleLog };")
        
        // 注入 fetch 函数 (简化版)
        let fetch: @convention(block) (String, JSValue?) -> JSValue = { [weak self] urlString, options in
            let promise = context.evaluateScript("new Promise(function(resolve, reject) {})")!
            
            guard let url = URL(string: urlString) else {
                return promise
            }
            
            Task {
                do {
                    let result = try await self?.httpUtil.string(url: url) ?? ""
                    DispatchQueue.main.async {
                        // 简化处理：直接返回文本
                        promise.setValue(result, forProperty: "text")
                    }
                } catch {
                    print("Fetch error: \(error)")
                }
            }
            
            return promise
        }
        context.setObject(fetch, forKeyedSubscript: "_fetch" as NSString)
        
        // 注入 JSON 全局对象 (确保存在)
        context.evaluateScript("""
            if (typeof JSON === 'undefined') {
                var JSON = {
                    parse: function(s) { return eval('(' + s + ')'); },
                    stringify: function(o) { return String(o); }
                };
            }
        """)
        
        // 注入 req 网络请求函数
        let req: @convention(block) (String, JSValue?) -> String = { [weak self] urlString, options in
            guard let url = URL(string: urlString) else {
                return ""
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var result = ""
            
            Task {
                do {
                    result = try await self?.httpUtil.string(url: url) ?? ""
                } catch {
                    print("Req error: \(error)")
                }
                semaphore.signal()
            }
            
            semaphore.wait()
            return result
        }
        context.setObject(req, forKeyedSubscript: "req" as NSString)
    }
    
    private func loadSpiderScript(_ context: JSContext, ext: String?) async throws {
        // 获取 JS 脚本 URL
        guard let jarUrl = site.jar, !jarUrl.isEmpty else {
            // 如果没有 jar 配置，尝试使用全局 spider
            let globalSpider = ApiConfig.shared.spider
            if !globalSpider.isEmpty {
                try await loadScript(context, from: globalSpider, ext: ext)
            } else {
                throw SpiderError.scriptError("未找到爬虫脚本配置")
            }
            return
        }
        
        try await loadScript(context, from: jarUrl, ext: ext)
    }
    
    private func loadScript(_ context: JSContext, from urlString: String, ext: String?) async throws {
        // 处理 URL，提取 md5 校验码（参照 Android 的处理方式）
        var scriptUrl = urlString
        var md5Hash = ""
        
        // 处理 ;md5; 格式的 URL
        if scriptUrl.contains(";md5;") {
            let parts = scriptUrl.components(separatedBy: ";md5;")
            scriptUrl = parts[0]
            if parts.count > 1 {
                md5Hash = parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        
        // 提取类名 (如果有)
        var className = "Spider"
        if scriptUrl.contains(".js#") || scriptUrl.contains(".js;") {
            let separator = scriptUrl.contains(".js#") ? ".js#" : ".js;"
            let parts = scriptUrl.components(separatedBy: separator)
            if parts.count >= 2 {
                scriptUrl = parts[0] + ".js"
                className = parts[1]
            }
        }
        
        // 下载脚本
        guard let url = URL(string: scriptUrl) else {
            throw SpiderError.scriptError("无效的脚本 URL: \(scriptUrl)")
        }
        
        print("[JsSpider] ========== 脚本下载信息 ==========")
        print("[JsSpider] 原始 URL: \(urlString)")
        print("[JsSpider] 处理后 URL: \(scriptUrl)")
        print("[JsSpider] 类名: \(className)")
        print("[JsSpider] MD5: \(md5Hash.isEmpty ? "无" : md5Hash)")
        print("[JsSpider] =====================================")
        
        // 尝试从缓存加载或下载脚本
        let scriptContent = try await loadScriptContent(from: url, md5: md5Hash, className: className)
        
        // 验证脚本内容不为空
        guard !scriptContent.isEmpty else {
            throw SpiderError.scriptError("脚本内容为空")
        }
        
        // 验证脚本内容不是 JSON 错误响应（服务器返回的错误信息）
        if scriptContent.trimmingCharacters(in: .whitespaces).hasPrefix("{") {
            // 可能是 JSON 错误响应
            if scriptContent.contains("\"code\"") && (scriptContent.contains("\"message\"") || scriptContent.contains("\"error\"")) {
                print("[JsSpider] 检测到可能的错误响应: \(scriptContent.prefix(200))")
                throw SpiderError.scriptError("服务器返回错误响应，可能文件不存在")
            }
        }
        
        // 执行脚本
        context.evaluateScript(scriptContent)
        
        // 检查脚本是否正确加载了 Spider 类
        let checkResult = context.evaluateScript("typeof \(className)")
        if checkResult?.toString() == "undefined" {
            throw SpiderError.scriptError("脚本未定义 \(className) 类")
        }
        
        // 初始化爬虫对象
        let initScript = """
            var spider = new \(className)();
            if (typeof spider.init === 'function') {
                spider.init('\(ext ?? "")');
            }
        """
        context.evaluateScript(initScript)
        
        // 验证 spider 对象是否创建成功
        let spiderCheck = context.evaluateScript("typeof spider")
        if spiderCheck?.toString() == "undefined" {
            throw SpiderError.scriptError("无法创建 spider 实例")
        }
    }
    
    /// 加载脚本内容，支持缓存（参照 Android 的 JarLoader 处理方式）
    private func loadScriptContent(from url: URL, md5: String, className: String) async throws -> String {
        // 计算缓存文件路径
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let spiderCacheDir = cacheDir.appendingPathComponent("spider_scripts")
        
        // 确保缓存目录存在
        try? FileManager.default.createDirectory(at: spiderCacheDir, withIntermediateDirectories: true)
        
        // 使用 URL 的 MD5 作为缓存文件名
        let urlHash = url.absoluteString.md5
        let cacheFile = spiderCacheDir.appendingPathComponent("\(urlHash).js")
        
        // 检查缓存是否有效
        if FileManager.default.fileExists(atPath: cacheFile.path) {
            let cachedContent = try? String(contentsOf: cacheFile, encoding: .utf8)
            
            if !md5.isEmpty, let content = cachedContent, !content.isEmpty {
                // 如果有 md5 校验，验证缓存文件的 md5
                let fileMd5 = content.md5
                if fileMd5.lowercased() == md5.lowercased() {
                    print("[JsSpider] 使用缓存脚本: \(cacheFile.path)")
                    return content
                }
            } else if let content = cachedContent, !content.isEmpty {
                // 没有 md5 校验，检查文件是否在一周内
                if let attrs = try? FileManager.default.attributesOfItem(atPath: cacheFile.path),
                   let modDate = attrs[.modificationDate] as? Date,
                   Date().timeIntervalSince(modDate) < 7 * 24 * 60 * 60 {
                    print("[JsSpider] 使用缓存脚本（一周内）: \(cacheFile.path)")
                    return content
                }
            }
        }
        
        // 下载脚本 - 使用 Data 而不是 String，以支持多种编码
        do {
            let data = try await httpUtil.data(url: url)
            print("[JsSpider] 下载脚本成功，数据长度: \(data.count)")
            
            var scriptContent: String?
            
            // 检查文件格式
            if data.count > 4 {
                let header = Array(data.prefix(4))
                
                // 检查 ZIP/JAR 格式（魔数: 50 4B 03 04 = "PK..")
                if header[0] == 0x50 && header[1] == 0x4B && header[2] == 0x03 && header[3] == 0x04 {
                    print("[JsSpider] 检测到 ZIP/JAR 格式，尝试解压")
                    scriptContent = try extractJsFromZip(data: data, className: className)
                }
            }
            
            // 如果不是 ZIP，尝试 UTF-8 解码
            if scriptContent == nil {
                if let utf8String = String(data: data, encoding: .utf8), !utf8String.isEmpty {
                    // 检查是否是 //bb 或 //DRPY 开头的 Base64 编码脚本（Android 特有格式）
                    if utf8String.hasPrefix("//bb") || utf8String.hasPrefix("//DRPY") {
                        print("[JsSpider] 检测到 \(utf8String.prefix(6)) 格式脚本，这是 Android QuickJS 字节码格式，iOS 暂不支持")
                        throw SpiderError.unsupported("此站点使用 Android QuickJS 字节码格式，iOS 暂不支持")
                    }
                    
                    // 检查脚本内容是否包含过多控制字符（可能是二进制格式被错误解码）
                    let controlCharCount = utf8String.prefix(1000).filter { $0.asciiValue ?? 0 < 32 && $0 != "\n" && $0 != "\r" && $0 != "\t" }.count
                    if controlCharCount > 10 {
                        print("[JsSpider] 脚本包含过多控制字符(\(controlCharCount)个)，可能是二进制格式")
                        throw SpiderError.unsupported("此站点使用二进制格式脚本，iOS 暂不支持")
                    }
                    
                    scriptContent = utf8String
                    print("[JsSpider] 使用 UTF-8 编码解码成功")
                } else {
                    // 检查是否是其他二进制格式
                    if data.count > 4 {
                        let header = Array(data.prefix(8))
                        let hasBinaryMarker = header.prefix(4).contains(where: { $0 < 0x09 && $0 != 0x00 })
                        if hasBinaryMarker {
                            print("[JsSpider] 检测到二进制格式脚本（前8字节: \(header.map { String(format: "%02X", $0) }.joined(separator: " "))），可能是 QuickJS 字节码，iOS 暂不支持")
                            throw SpiderError.unsupported("此站点使用 Android QuickJS 字节码格式，iOS 暂不支持")
                        }
                    }
                    
                    print("[JsSpider] UTF-8 解码失败，这可能是二进制格式的 QuickJS 字节码")
                    throw SpiderError.unsupported("此站点使用 Android QuickJS 字节码格式，iOS 暂不支持")
                }
            }
            
            guard let content = scriptContent, !content.isEmpty else {
                print("[JsSpider] 无法解码脚本内容，数据长度: \(data.count)")
                throw SpiderError.scriptError("无法解码脚本内容")
            }
            
            // 缓存脚本
            try? content.write(to: cacheFile, atomically: true, encoding: .utf8)
            print("[JsSpider] 脚本已缓存: \(cacheFile.path), 内容长度: \(content.count)")
            
            return content
        } catch let error as SpiderError {
            throw error
        } catch {
            // 下载失败，尝试使用旧缓存
            if let cachedContent = try? String(contentsOf: cacheFile, encoding: .utf8), !cachedContent.isEmpty {
                print("[JsSpider] 下载失败，使用旧缓存: \(error.localizedDescription)")
                return cachedContent
            }
            throw error
        }
    }
    
    /// 从 ZIP/JAR 文件中提取 JavaScript 源码
    private func extractJsFromZip(data: Data, className: String) throws -> String {
        var jsFiles: [(name: String, content: String)] = []
        var offset = 0
        
        while offset < data.count - 4 {
            guard data[offset] == 0x50 && data[offset + 1] == 0x4B else { break }
            
            // Central directory 或 End of central directory
            if data[offset + 2] != 0x03 || data[offset + 3] != 0x04 { break }
            
            guard offset + 30 <= data.count else { break }
            
            // 读取文件头信息
            let compressionMethod = UInt16(data[offset + 8]) | (UInt16(data[offset + 9]) << 8)
            let compressedSize = Int(UInt32(data[offset + 18]) | (UInt32(data[offset + 19]) << 8) | (UInt32(data[offset + 20]) << 16) | (UInt32(data[offset + 21]) << 24))
            let uncompressedSize = Int(UInt32(data[offset + 22]) | (UInt32(data[offset + 23]) << 8) | (UInt32(data[offset + 24]) << 16) | (UInt32(data[offset + 25]) << 24))
            let fileNameLength = Int(UInt16(data[offset + 26]) | (UInt16(data[offset + 27]) << 8))
            let extraFieldLength = Int(UInt16(data[offset + 28]) | (UInt16(data[offset + 29]) << 8))
            
            guard offset + 30 + fileNameLength <= data.count else { break }
            
            let fileNameData = data.subdata(in: (offset + 30)..<(offset + 30 + fileNameLength))
            let fileName = String(data: fileNameData, encoding: .utf8) ?? ""
            
            let dataOffset = offset + 30 + fileNameLength + extraFieldLength
            let dataSize = compressionMethod == 0 ? uncompressedSize : compressedSize
            
            guard dataOffset + dataSize <= data.count else { break }
            
            let fileData = data.subdata(in: dataOffset..<(dataOffset + dataSize))
            
            if fileName.hasSuffix(".js") {
                var jsContent: String?
                
                if compressionMethod == 0 {
                    jsContent = String(data: fileData, encoding: .utf8)
                } else if compressionMethod == 8 {
                    if let decompressed = decompressDeflate(data: fileData, expectedSize: uncompressedSize) {
                        jsContent = String(data: decompressed, encoding: .utf8)
                    }
                }
                
                if let content = jsContent, !content.isEmpty {
                    print("[JsSpider] 找到 JS 文件: \(fileName), 大小: \(content.count)")
                    jsFiles.append((name: fileName, content: content))
                }
            }
            
            offset = dataOffset + dataSize
        }
        
        // 优先查找与类名匹配的文件
        if !className.isEmpty && className != "Spider" {
            for file in jsFiles {
                let baseName = (file.name as NSString).deletingPathExtension
                if baseName.lowercased() == className.lowercased() ||
                   file.name.lowercased().contains(className.lowercased()) {
                    print("[JsSpider] 使用匹配的 JS 文件: \(file.name)")
                    return file.content
                }
            }
        }
        
        // 查找主入口文件
        let mainFileNames = ["index.js", "main.js", "spider.js", "app.js"]
        for mainName in mainFileNames {
            if let file = jsFiles.first(where: { $0.name.lowercased().hasSuffix(mainName) }) {
                print("[JsSpider] 使用入口文件: \(file.name)")
                return file.content
            }
        }
        
        // 返回第一个 JS 文件
        if let firstFile = jsFiles.first {
            print("[JsSpider] 使用第一个 JS 文件: \(firstFile.name)")
            return firstFile.content
        }
        
        throw SpiderError.scriptError("ZIP 中未找到 JavaScript 文件")
    }
    
    /// 解压 Deflate 压缩的数据
    private func decompressDeflate(data: Data, expectedSize: Int) -> Data? {
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
        
        return decompressedSize > 0 ? Data(bytes: destinationBuffer, count: decompressedSize) : nil
    }
    
    // MARK: - Parse Methods
    
    private func parseHomeContent(_ jsValue: JSValue) throws -> HomeContent {
        guard let jsonString = jsValue.toString() else {
            throw SpiderError.parseError("无法获取 homeContent 结果")
        }
        
        guard let data = jsonString.data(using: .utf8) else {
            throw SpiderError.parseError("无法解析 homeContent 数据")
        }
        
        let response = try JSONDecoder().decode(MovieCategoryResponse.self, from: data)
        
        return HomeContent(
            categories: response.classData ?? [],
            videos: response.list ?? [],
            filters: response.filters ?? [:]
        )
    }
    
    private func parseCategoryContent(_ jsValue: JSValue) throws -> CategoryContent {
        guard let jsonString = jsValue.toString() else {
            throw SpiderError.parseError("无法获取 categoryContent 结果")
        }
        
        guard let data = jsonString.data(using: .utf8) else {
            throw SpiderError.parseError("无法解析 categoryContent 数据")
        }
        
        let response = try JSONDecoder().decode(MovieListResponse.self, from: data)
        
        return CategoryContent(
            videos: response.list ?? [],
            page: response.page ?? 1,
            pageCount: response.pagecount ?? 1,
            total: response.total ?? 0
        )
    }
    
    private func parseDetailContent(_ jsValue: JSValue) throws -> [VodInfo] {
        guard let jsonString = jsValue.toString() else {
            throw SpiderError.parseError("无法获取 detailContent 结果")
        }
        
        guard let data = jsonString.data(using: .utf8) else {
            throw SpiderError.parseError("无法解析 detailContent 数据")
        }
        
        let response = try JSONDecoder().decode(MovieDetailResponse.self, from: data)
        
        return response.list ?? []
    }
    
    private func parseSearchContent(_ jsValue: JSValue) throws -> [MovieItem] {
        guard let jsonString = jsValue.toString() else {
            throw SpiderError.parseError("无法获取 searchContent 结果")
        }
        
        guard let data = jsonString.data(using: .utf8) else {
            throw SpiderError.parseError("无法解析 searchContent 数据")
        }
        
        let response = try JSONDecoder().decode(MovieListResponse.self, from: data)
        
        return response.list ?? []
    }
    
    private func parsePlayerContent(_ jsValue: JSValue) throws -> PlayerContent {
        guard let jsonString = jsValue.toString() else {
            throw SpiderError.parseError("无法获取 playerContent 结果")
        }
        
        guard let data = jsonString.data(using: .utf8) else {
            throw SpiderError.parseError("无法解析 playerContent 数据")
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

