import Foundation
import JavaScriptCore

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
                    
                    guard let result = context.evaluateScript("spider.homeContent(\(filterStr))") else {
                        continuation.resume(throwing: SpiderError.scriptError("homeContent 返回空"))
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
                    
                    guard let result = context.evaluateScript("spider.categoryContent('\(tid)', \(page), \(filter), '\(extendStr)')") else {
                        continuation.resume(throwing: SpiderError.scriptError("categoryContent 返回空"))
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
        
        let idsJson = try JSONEncoder().encode(ids)
        let idsStr = String(data: idsJson, encoding: .utf8) ?? "[]"
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    guard let result = context.evaluateScript("spider.detailContent('\(idsStr)')") else {
                        continuation.resume(throwing: SpiderError.scriptError("detailContent 返回空"))
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
                    guard let result = context.evaluateScript("spider.searchContent('\(escapedKeyword)', \(quick), \(page))") else {
                        continuation.resume(throwing: SpiderError.scriptError("searchContent 返回空"))
                        return
                    }
                    
                    let movies = try self.parseSearchContent(result)
                    continuation.resume(returning: movies)
                } catch {
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
                    guard let result = context.evaluateScript("spider.playerContent('\(escapedFlag)', '\(escapedId)', '\(vipFlagsStr)')") else {
                        continuation.resume(throwing: SpiderError.scriptError("playerContent 返回空"))
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
        // 处理 URL
        var scriptUrl = urlString
        
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
        
        let scriptContent = try await httpUtil.string(url: url)
        
        // 执行脚本
        context.evaluateScript(scriptContent)
        
        // 初始化爬虫对象
        let initScript = """
            var spider = new \(className)();
            if (typeof spider.init === 'function') {
                spider.init('\(ext ?? "")');
            }
        """
        context.evaluateScript(initScript)
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

