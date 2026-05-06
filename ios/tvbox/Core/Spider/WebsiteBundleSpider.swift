import Foundation
@preconcurrency import JavaScriptCore

/// Cat WebsiteBundle 运行适配层。
///
/// 先支持可直接暴露 Spider 方法的 WebsiteBundle；如果 bundle 是完整的
/// Node/Fastify server 包，则识别后给出明确错误，避免落回泛化的“不支持”。
final class WebsiteBundleSpider: Spider {
    let siteKey: String

    private let site: SiteBean
    private let httpUtil = HttpUtil.shared
    private var jsContext: JSContext?
    private var nativeSpider: WebsiteBundleNativeSpider?
    private var isInitialized = false

    init(site: SiteBean) {
        self.site = site
        self.siteKey = site.key
    }

    func initialize(ext: String?) async throws {
        if let nativeSpider = WebsiteBundleNativeSpiderFactory.make(site: site) {
            self.nativeSpider = nativeSpider
            try await nativeSpider.initialize(ext: ext)
            isInitialized = true
            AppLogger.debug("[WebsiteBundleSpider] 使用原生 WebsiteBundle 路由适配: \(site.key)")
            return
        }

        if let unsupportedReason = site.websiteBundleUnsupportedReason {
            throw SpiderError.unsupported(unsupportedReason)
        }

        let context = JSContext()
        guard let context else {
            throw SpiderError.scriptError("无法创建 WebsiteBundle JavaScript 上下文")
        }

        context.exceptionHandler = { _, exception in
            if let exception {
                AppLogger.debug("[WebsiteBundleSpider] JS Error: \(exception)")
            }
        }

        injectGlobals(context)

        let script = try await loadBundleScript()
        context.evaluateScript(script)

        if let exception = context.exception {
            throw SpiderError.scriptError("WebsiteBundle 加载失败: \(exception)")
        }

        guard context.evaluateScript("typeof globalThis.websiteBundle")?.toString() != "undefined" else {
            throw SpiderError.scriptError("脚本未定义 globalThis.websiteBundle")
        }

        let descriptor = try inspectAndBindSpider(in: context)
        AppLogger.debug("[WebsiteBundleSpider] bundle 描述: \(descriptor)")

        if descriptor.serverBundle {
            throw SpiderError.unsupported(
                "此 WebsiteBundle 是 Node/Fastify 服务包；当前站点尚未加入 iOS 原生路由适配"
            )
        }

        guard descriptor.hasCallableSpider else {
            throw SpiderError.unsupported("WebsiteBundle 未暴露 home/category/detail/search/play 等 Spider 方法")
        }

        if descriptor.hasInit {
            let extJson = Self.jsonLiteral(ext ?? "")
            context.evaluateScript("globalThis.__WEBSITE_SPIDER__.init(\(extJson));")
            if let exception = context.exception {
                throw SpiderError.scriptError("WebsiteBundle init 失败: \(exception)")
            }
        }

        jsContext = context
        isInitialized = true
    }

    func homeContent(filter: Bool) async throws -> HomeContent {
        if let nativeSpider {
            return try await nativeSpider.homeContent(filter: filter)
        }

        let result = try callStringMethod("home", arguments: [filter])
        let response = try decode(MovieCategoryResponse.self, from: result, method: "home")
        return HomeContent(
            categories: response.classData ?? [],
            videos: response.list ?? [],
            filters: response.filters ?? [:]
        )
    }

    func categoryContent(tid: String, page: Int, filter: Bool, extend: [String: String]) async throws -> CategoryContent {
        if let nativeSpider {
            return try await nativeSpider.categoryContent(tid: tid, page: page, filter: filter, extend: extend)
        }

        let result = try callStringMethod("category", arguments: [tid, String(page), filter, extend])
        let response = try decode(MovieListResponse.self, from: result, method: "category")
        return CategoryContent(
            videos: response.list ?? [],
            page: response.page ?? page,
            pageCount: response.pagecount ?? 1,
            total: response.total ?? 0
        )
    }

    func detailContent(ids: [String]) async throws -> [VodInfo] {
        if let nativeSpider {
            return try await nativeSpider.detailContent(ids: ids)
        }

        let id = ids.first ?? ""
        let result = try callStringMethod("detail", arguments: [id])
        let response = try decode(MovieDetailResponse.self, from: result, method: "detail")
        return response.list ?? []
    }

    func searchContent(keyword: String, quick: Bool, page: Int) async throws -> [MovieItem] {
        if let nativeSpider {
            return try await nativeSpider.searchContent(keyword: keyword, quick: quick, page: page)
        }

        let arguments: [Any] = page > 1 ? [keyword, quick, String(page)] : [keyword, quick]
        let result = try callStringMethod("search", arguments: arguments)
        let response = try decode(MovieListResponse.self, from: result, method: "search")
        return response.list ?? []
    }

    func playerContent(flag: String, id: String, vipFlags: [String]) async throws -> PlayerContent {
        if let nativeSpider {
            return try await nativeSpider.playerContent(flag: flag, id: id, vipFlags: vipFlags)
        }

        let result = try callStringMethod("play", arguments: [flag, id, vipFlags])

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

        let response = try decode(PlayerResponse.self, from: result, method: "play")
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

    var supportsQuickSearch: Bool {
        if let nativeSpider {
            return nativeSpider.supportsQuickSearch
        }
        return site.isQuickSearchable
    }

    func destroy() {
        nativeSpider?.destroy()
        nativeSpider = nil
        jsContext = nil
        isInitialized = false
    }

    private func injectGlobals(_ context: JSContext) {
        context.evaluateScript("""
            if (typeof globalThis === 'undefined') { var globalThis = this; }
            if (typeof window === 'undefined') { var window = globalThis; }
            if (typeof process === 'undefined') {
                var process = { env: {}, nextTick: function(fn) { if (typeof fn === 'function') fn(); } };
            }
            if (typeof navigator === 'undefined') { var navigator = { userAgent: 'TVBox iOS' }; }
            if (typeof document === 'undefined') {
                var document = {
                    createElement: function() { return { style: {}, setAttribute: function(){}, appendChild: function(){}, removeChild: function(){} }; },
                    querySelector: function() { return null; },
                    getSelection: function() { return { rangeCount: 0 }; },
                    body: { appendChild: function(){}, removeChild: function(){} },
                    head: { appendChild: function(){}, insertBefore: function(){} }
                };
            }
        """)

        let consoleLog: @convention(block) (String) -> Void = { message in
            AppLogger.debug("[WebsiteBundle Console] \(message)")
        }
        context.setObject(consoleLog, forKeyedSubscript: "_websiteBundleLog" as NSString)
        context.evaluateScript("var console = { log: _websiteBundleLog, warn: _websiteBundleLog, error: _websiteBundleLog };")

        let req: @convention(block) (String, JSValue?) -> String = { [weak self] urlString, options in
            guard let url = URL(string: urlString) else { return "" }

            var headers: [String: String] = [:]
            if let headerValue = options?.forProperty("headers"), !headerValue.isUndefined {
                headers = headerValue.toDictionary() as? [String: String] ?? [:]
            }

            let semaphore = DispatchSemaphore(value: 0)
            var result = ""

            Task {
                do {
                    result = try await self?.httpUtil.string(url: url, headers: headers) ?? ""
                } catch {
                    AppLogger.debug("[WebsiteBundleSpider] req 失败: \(error.localizedDescription)")
                }
                semaphore.signal()
            }

            semaphore.wait()
            return result
        }
        context.setObject(req, forKeyedSubscript: "req" as NSString)
        context.setObject(req, forKeyedSubscript: "http" as NSString)

        let require: @convention(block) (String) -> JSValue? = { name in
            AppLogger.debug("[WebsiteBundleSpider] Node require 未实现: \(name)")
            return JSValue(undefinedIn: context)
        }
        context.setObject(require, forKeyedSubscript: "require" as NSString)
    }

    private func loadBundleScript() async throws -> String {
        let scriptUrl = site.jar ?? site.api
        let resolvedUrl = scriptUrl.lowercased().hasSuffix(".js.md5")
            ? String(scriptUrl.dropLast(4))
            : scriptUrl

        guard let url = URL(string: resolvedUrl) else {
            throw SpiderError.scriptError("无效的 WebsiteBundle URL: \(resolvedUrl)")
        }

        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let bundleCacheDir = cacheDir.appendingPathComponent("website_bundle_scripts")
        try? FileManager.default.createDirectory(at: bundleCacheDir, withIntermediateDirectories: true)
        let cacheFile = bundleCacheDir.appendingPathComponent("\(resolvedUrl.md5).js")

        if let cached = try? String(contentsOf: cacheFile, encoding: .utf8), !cached.isEmpty,
           let attrs = try? FileManager.default.attributesOfItem(atPath: cacheFile.path),
           let modDate = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modDate) < 24 * 60 * 60 {
            return cached
        }

        let content = try await httpUtil.string(url: url)
        try? content.write(to: cacheFile, atomically: true, encoding: .utf8)
        return content
    }

    private struct BundleDescriptor: Decodable {
        let valueType: String
        let candidatePath: String
        let hasInit: Bool
        let hasHome: Bool
        let hasCategory: Bool
        let hasDetail: Bool
        let hasSearch: Bool
        let hasPlay: Bool
        let serverBundle: Bool

        var hasCallableSpider: Bool {
            hasHome || hasCategory || hasDetail || hasSearch || hasPlay
        }
    }

    private func inspectAndBindSpider(in context: JSContext) throws -> BundleDescriptor {
        let script = """
            (function() {
                var raw = globalThis.websiteBundle;
                var value = (typeof raw === 'function') ? raw() : raw;
                globalThis.__WEBSITE_BUNDLE_VALUE__ = value;

                function hasAnyMethod(obj) {
                    return !!obj && typeof obj === 'object' && (
                        typeof obj.home === 'function' ||
                        typeof obj.category === 'function' ||
                        typeof obj.detail === 'function' ||
                        typeof obj.search === 'function' ||
                        typeof obj.play === 'function'
                    );
                }

                var paths = [
                    { name: 'value', value: value },
                    { name: 'value.default', value: value && value.default },
                    { name: 'value.spider', value: value && value.spider },
                    { name: 'value.site', value: value && value.site },
                    { name: 'value.source', value: value && value.source },
                    { name: 'value.api', value: value && value.api }
                ];

                var candidate = null;
                var candidatePath = '';
                for (var i = 0; i < paths.length; i++) {
                    var item = paths[i];
                    var current = item.value;
                    if (typeof current === 'function') {
                        try { current = current(); } catch (_) {}
                    }
                    if (hasAnyMethod(current)) {
                        candidate = current;
                        candidatePath = item.name;
                        break;
                    }
                }

                globalThis.__WEBSITE_SPIDER__ = candidate;
                var stringValue = typeof value === 'string' ? value : '';
                return JSON.stringify({
                    valueType: typeof value,
                    candidatePath: candidatePath,
                    hasInit: !!candidate && typeof candidate.init === 'function',
                    hasHome: !!candidate && typeof candidate.home === 'function',
                    hasCategory: !!candidate && typeof candidate.category === 'function',
                    hasDetail: !!candidate && typeof candidate.detail === 'function',
                    hasSearch: !!candidate && typeof candidate.search === 'function',
                    hasPlay: !!candidate && typeof candidate.play === 'function',
                    serverBundle: stringValue.indexOf('fastify') !== -1 ||
                        stringValue.indexOf('catServerFactory') !== -1 ||
                        stringValue.indexOf('.listen({port') !== -1 ||
                        stringValue.indexOf('require("node:') !== -1 ||
                        stringValue.indexOf('require("os")') !== -1
                });
            })()
        """

        guard let json = context.evaluateScript(script)?.toString(),
              let data = json.data(using: .utf8) else {
            throw SpiderError.scriptError("无法检查 WebsiteBundle")
        }

        if let exception = context.exception {
            throw SpiderError.scriptError("检查 WebsiteBundle 失败: \(exception)")
        }

        return try JSONDecoder().decode(BundleDescriptor.self, from: data)
    }

    private func callStringMethod(_ method: String, arguments: [Any]) throws -> String {
        guard isInitialized, let context = jsContext else {
            throw SpiderError.notInitialized
        }

        let args = arguments.map(Self.jsonLiteral).joined(separator: ",")
        let script = """
            (function() {
                var result = globalThis.__WEBSITE_SPIDER__.\(method)(\(args));
                if (typeof result === 'string') return result;
                return JSON.stringify(result || {});
            })()
        """

        guard let result = context.evaluateScript(script)?.toString() else {
            throw SpiderError.scriptError("\(method) 返回空")
        }

        if let exception = context.exception {
            throw SpiderError.scriptError("\(method) 执行失败: \(exception)")
        }

        return result
    }

    private func decode<T: Decodable>(_ type: T.Type, from json: String, method: String) throws -> T {
        guard let data = json.data(using: .utf8) else {
            throw SpiderError.parseError("无法解析 \(method) 返回数据")
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            AppLogger.debug("[WebsiteBundleSpider] \(method) JSON 解码失败: \(json.prefix(500))")
            throw error
        }
    }

    private static func jsonLiteral(_ value: Any) -> String {
        if let string = value as? String {
            return jsonStringLiteral(string)
        }

        if let bool = value as? Bool {
            return bool ? "true" : "false"
        }

        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value),
           let json = String(data: data, encoding: .utf8) {
            return json
        }

        return "null"
    }

    private static func jsonStringLiteral(_ string: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [string]),
              let arrayJson = String(data: data, encoding: .utf8),
              arrayJson.count >= 2 else {
            return "\"\""
        }
        return String(arrayJson.dropFirst().dropLast())
    }
}
