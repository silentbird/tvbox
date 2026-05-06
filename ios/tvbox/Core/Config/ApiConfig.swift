import CryptoKit
import Foundation
import Combine
@preconcurrency import JavaScriptCore

/// API 配置管理器 - 对应 Android 的 ApiConfig
class ApiConfig: ObservableObject {
    static let shared = ApiConfig()
    
    // MARK: - Published Properties
    @Published var sites: [SiteBean] = []
    @Published var parses: [ParseBean] = []
    @Published var liveConfigs: [LiveConfig] = []
    @Published var currentSite: SiteBean?
    @Published var defaultParse: ParseBean?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var configLoaded = false
    
    // MARK: - Properties
    var spider: String = ""
    var wallpaper: String = ""
    var vipParseFlags: [String] = []
    var hosts: [String: String] = [:]
    var adHosts: Set<String> = []
    
    private let userDefaults = UserDefaults.standard
    private let httpUtil = HttpUtil.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let apiUrl = "api_url"
        static let liveApiUrl = "live_api_url"
        static let homeApi = "home_api"
        static let defaultParse = "default_parse"
        static let cachedConfig = "cached_config"
    }
    
    private init() {
        loadDefaultAds()
    }
    
    // MARK: - Public Methods
    
    /// 获取当前 API URL
    var apiUrl: String {
        get { userDefaults.string(forKey: Keys.apiUrl) ?? "" }
        set { 
            AppLogger.debug("[ApiConfig] apiUrl setter: \(newValue)")
            userDefaults.set(newValue, forKey: Keys.apiUrl)
        }
    }
    
    /// 获取直播 API URL
    var liveApiUrl: String {
        get { userDefaults.string(forKey: Keys.liveApiUrl) ?? "" }
        set { userDefaults.set(newValue, forKey: Keys.liveApiUrl) }
    }
    
    /// 加载配置
    func loadConfig(useCache: Bool = true) async throws {
        AppLogger.debug("[ApiConfig] ========== loadConfig 开始 ==========")
        AppLogger.debug("[ApiConfig] useCache: \(useCache), apiUrl: \(apiUrl)")
        
        guard !apiUrl.isEmpty else {
            AppLogger.debug("[ApiConfig] 错误: apiUrl 为空")
            throw ConfigError.noApiUrl
        }
        
        // 防止重复加载
        guard !isLoading else {
            AppLogger.debug("[ApiConfig] 配置正在加载中，跳过重复请求")
            return
        }
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let configUrl = normalizeUrl(apiUrl)
            AppLogger.debug("[ApiConfig] 规范化后的URL: \(configUrl)")
            
            // 尝试从缓存加载
            if useCache, let cachedData = getCachedConfig(for: apiUrl) {
                AppLogger.debug("[ApiConfig] 从缓存加载配置，数据长度: \(cachedData.count)")
                do {
                    await SpiderManager.shared.clearAll()
                    try await MainActor.run {
                        try parseConfig(scriptContent: cachedData, apiUrl: apiUrl)
                        isLoading = false
                        configLoaded = true
                    }
                    AppLogger.debug("[ApiConfig] 缓存加载完成")
                    return
                } catch {
                    AppLogger.debug("[ApiConfig] 缓存解析失败，清除缓存并重新从网络加载: \(error.localizedDescription)")
                    clearCache()
                    // 继续从网络加载
                }
            }
            
            let jsonString = try await loadConfigContent(normalizedUrl: configUrl)
            AppLogger.debug("[ApiConfig] 配置内容加载完成，响应长度: \(jsonString.count)")
            
            // 缓存配置
            cacheConfig(jsonString, for: apiUrl)
            AppLogger.debug("[ApiConfig] 配置已缓存")
            
            // 解析配置 (在主线程上执行，因为会修改 @Published 属性)
            AppLogger.debug("[ApiConfig] 开始解析配置...")
            await SpiderManager.shared.clearAll()
            try await MainActor.run {
                try parseConfig(scriptContent: jsonString, apiUrl: apiUrl)
                isLoading = false
                configLoaded = true
            }
            AppLogger.debug("[ApiConfig] ========== loadConfig 完成 ==========")
        } catch {
            AppLogger.debug("[ApiConfig] 加载失败: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
                isLoading = false
            }
            throw error
        }
    }
    
    /// 获取可搜索的站点列表
    var searchableSites: [SiteBean] {
        sites.filter { $0.isSearchable }
    }
    
    /// 获取可显示在首页的站点列表
    var filterableSites: [SiteBean] {
        sites.filter { $0.isFilterable }
    }

    /// 获取首页站点选择器中应该可见的站点列表
    /// - WebsiteBundle 站点：全部保留（包含 baseset/push 等配置项，用户可进去配置网盘等）
    /// - 其它类型：沿用 `isFilterable` 判断
    var homeSites: [SiteBean] {
        sites.filter { site in
            if site.isWebsiteBundle {
                return true
            }
            return site.isFilterable
        }
    }
    
    /// 设置当前站点
    func setCurrentSite(_ site: SiteBean) {
        let selectedSite = resolveSelectableSite(site)

        Task {
            await SpiderManager.shared.clearAll()
            await MainActor.run {
                self.currentSite = selectedSite
                self.userDefaults.set(selectedSite.key, forKey: Keys.homeApi)
                AppLogger.debug("[ApiConfig] 当前站点已切换: \(selectedSite.key)")
            }
        }
    }
    
    /// 设置豆瓣热门为首页
    func setDoubanHome() {
        currentSite = nil
        userDefaults.set("douban_home", forKey: Keys.homeApi)
    }
    
    /// 设置默认解析
    func setDefaultParse(_ parse: ParseBean) {
        if var oldDefault = defaultParse {
            oldDefault.isDefault = false
        }
        var newDefault = parse
        newDefault.isDefault = true
        defaultParse = newDefault
        userDefaults.set(parse.name, forKey: Keys.defaultParse)
    }
    
    /// 清除配置
    func clearConfig() {
        sites.removeAll()
        parses.removeAll()
        liveConfigs.removeAll()
        currentSite = nil
        defaultParse = nil
        spider = ""
        wallpaper = ""
        configLoaded = false
    }
    
    /// 清除缓存
    func clearCache() {
        let url = apiUrl
        if !url.isEmpty {
            let cacheKey = "\(Keys.cachedConfig)_\(url.md5)"
            userDefaults.removeObject(forKey: cacheKey)
            AppLogger.debug("[ApiConfig] 已清除缓存: \(cacheKey)")
        }
    }
    
    /// 重置所有配置（包括 URL 和缓存）
    func resetAll() {
        clearCache()
        clearConfig()
        userDefaults.removeObject(forKey: Keys.apiUrl)
        AppLogger.debug("[ApiConfig] 已重置所有配置")
    }
    
    // MARK: - Private Methods
    
    private func normalizeUrl(_ url: String) -> String {
        var configUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !configUrl.hasPrefix("http://"), !configUrl.hasPrefix("https://") {
            configUrl = "https://\(configUrl)"
        }
        
        if configUrl.lowercased().hasSuffix(".js.md5") {
            configUrl = String(configUrl.dropLast(4))
        }
        
        return configUrl
    }

    private func loadConfigContent(normalizedUrl: String) async throws -> String {
        AppLogger.debug("[ApiConfig] 尝试创建URL: \(normalizedUrl)")
        guard let url = createURL(from: normalizedUrl) else {
            AppLogger.debug("[ApiConfig] 错误: 无效的URL - '\(normalizedUrl)'")
            throw ConfigError.invalidUrl
        }
        
        AppLogger.debug("[ApiConfig] 创建的URL对象: \(url.absoluteString)")
        AppLogger.debug("[ApiConfig] 开始网络请求...")
        return try await httpUtil.string(url: url)
    }
    
    /// 将 URL 字符串转换为 URL 对象（支持中文域名）
    private func createURL(from urlString: String) -> URL? {
        AppLogger.debug("[ApiConfig] createURL 输入: \(urlString)")
        
        // 方法1: 直接使用 URL(string:) - iOS 会自动处理 IDN
        if let url = URL(string: urlString) {
            AppLogger.debug("[ApiConfig] 方法1成功: \(url.absoluteString)")
            return url
        }
        
        // 方法2: 使用 URLComponents
        if let components = URLComponents(string: urlString), let url = components.url {
            AppLogger.debug("[ApiConfig] 方法2成功: \(url.absoluteString)")
            return url
        }
        
        // 方法3: 对域名进行 Punycode 编码
        if let encoded = encodeIDNUrl(urlString) {
            AppLogger.debug("[ApiConfig] 方法3成功: \(encoded.absoluteString)")
            return encoded
        }
        
        // 方法4: 百分号编码整个 URL
        if let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            let fixedEncoded = encoded
                .replacingOccurrences(of: "%3A", with: ":")
                .replacingOccurrences(of: "%2F", with: "/")
                .replacingOccurrences(of: "%3F", with: "?")
                .replacingOccurrences(of: "%3D", with: "=")
                .replacingOccurrences(of: "%26", with: "&")
            if let url = URL(string: fixedEncoded) {
                AppLogger.debug("[ApiConfig] 方法4成功: \(url.absoluteString)")
                return url
            }
        }
        
        AppLogger.debug("[ApiConfig] 所有方法都失败了")
        return nil
    }
    
    /// 对 IDN URL 进行编码
    private func encodeIDNUrl(_ urlString: String) -> URL? {
        // 解析 URL 各部分
        guard let regex = try? NSRegularExpression(pattern: "^(https?://)([^/]+)(.*)$", options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(urlString.startIndex..., in: urlString)
        guard let match = regex.firstMatch(in: urlString, options: [], range: range) else {
            return nil
        }
        
        let schemeRange = Range(match.range(at: 1), in: urlString)!
        let hostRange = Range(match.range(at: 2), in: urlString)!
        let pathRange = Range(match.range(at: 3), in: urlString)!
        
        let scheme = String(urlString[schemeRange])
        let host = String(urlString[hostRange])
        let path = String(urlString[pathRange])
        
        // 对 host 进行 Punycode 编码
        guard let encodedHost = host.idnaEncoded else {
            return nil
        }
        
        let encodedUrlString = scheme + encodedHost + path
        return URL(string: encodedUrlString)
    }
    
    private func parseConfig(scriptContent: String, apiUrl: String) throws {
        AppLogger.debug("[parseConfig] 开始解析配置...")
        
        guard isWebsiteBundleSource(scriptContent) else {
            AppLogger.debug("[parseConfig] 不支持的配置源内容前200字符: \(String(scriptContent.prefix(200)))")
            throw ConfigError.invalidData
        }
        
        parseJavaScriptSourceConfig(scriptContent: scriptContent, scriptUrl: normalizeUrl(apiUrl))
    }
    
    private func isWebsiteBundleSource(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("globalThis.websiteBundle")
    }
    
    private func parseJavaScriptSourceConfig(scriptContent: String, scriptUrl: String) {
        AppLogger.debug("[parseConfig] 检测到 JS 视频源入口，按 JS 源配置处理: \(scriptUrl)")
        
        spider = scriptUrl
        wallpaper = ""
        parses = []
        liveConfigs = []
        vipParseFlags = []
        hosts = [:]
        adHosts = []
        loadDefaultAds()
        
        let bundleSites = extractWebsiteBundleSites(from: scriptContent, scriptUrl: scriptUrl)
        let fallbackSite = SiteBean(
            key: "ios_website_bundle_source",
            name: "Cat WebsiteBundle",
            type: 8,
            api: scriptUrl,
            searchable: 0,
            quickSearch: 0,
            filterable: 0,
            jar: scriptUrl
        )

        sites = bundleSites.isEmpty ? [fallbackSite] : bundleSites

        // baseset 这类 type=4 的网盘配置条目会被保留在 sites 中（留给配置界面使用），
        // 但它们没有 Spider 方法，不能当作首页内容源。选默认只在内容源里挑，
        // 优先级：已保存的内容站点 → 已适配的原生站点 → 其它任何内容站点 → 首个站点兜底。
        let savedHomeKey = userDefaults.string(forKey: Keys.homeApi)
        let preferredSite = bundleSites.first(where: \.isWebsiteBundleAdapted)
            ?? bundleSites.first(where: \.isWebsiteBundleContentSource)
            ?? bundleSites.first
        let savedSite = sites.first { $0.key == savedHomeKey && $0.isWebsiteBundleContentSource }
        currentSite = savedSite ?? preferredSite ?? sites.first
        if let currentSite {
            userDefaults.set(currentSite.key, forKey: Keys.homeApi)
        }
        defaultParse = nil
        
        AppLogger.debug("[parseConfig] JS 视频源配置解析完成，站点数: \(sites.count), 当前站点: \(currentSite?.key ?? "nil"), 站点: \(sites.map(\.key).joined(separator: ","))")
    }

    private func resolveSelectableSite(_ site: SiteBean) -> SiteBean {
        guard site.key == "ios_website_bundle_source",
              let adaptedSite = sites.first(where: \.isWebsiteBundleAdapted) else {
            return site
        }

        AppLogger.debug("[ApiConfig] 旧 WebsiteBundle 占位站点已切换到原生适配站点: \(adaptedSite.key)")
        return adaptedSite
    }

    private struct WebsiteBundleSiteMeta {
        let key: String
        let name: String
        let type: Int
        let nativeAdapter: String?
    }

    private struct WebsiteBundleRawMeta {
        let keyExpression: String
        let nameExpression: String
        let type: Int
        let offset: String.Index
    }

    private func extractWebsiteBundleSites(from scriptContent: String, scriptUrl: String) -> [SiteBean] {
        guard scriptContent.contains("globalThis.websiteBundle"),
              scriptContent.contains("wexDuBoKu") else {
            return []
        }

        return extractWebsiteBundleSiteMetas(from: scriptContent).map { meta in
            let isAdapted = meta.nativeAdapter != nil
            let unsupportedReason = isAdapted ? "" : "此 WebsiteBundle 子站点尚未适配: \(meta.name) (\(meta.key))"
            let extPayload: [String: Any] = [
                "websiteBundleUrl": scriptUrl,
                "websiteBundleKey": meta.key,
                "websiteBundleType": meta.type,
                "nativeAdapter": meta.nativeAdapter ?? "",
                "isAdapted": isAdapted,
                "unsupportedReason": unsupportedReason
            ]
            let extData = try? JSONSerialization.data(withJSONObject: extPayload)
            let ext = extData.flatMap { String(data: $0, encoding: .utf8) }

            return SiteBean(
                key: "nodejs_\(meta.key)",
                name: meta.name,
                type: 8,
                api: "\(scriptUrl)#/spider/\(meta.key)/\(meta.type)",
                searchable: isAdapted ? 1 : 0,
                quickSearch: isAdapted ? 1 : 0,
                filterable: isAdapted ? 1 : 0,
                ext: ext,
                jar: scriptUrl
            )
        }
    }

    private func extractWebsiteBundleSiteMetas(from scriptContent: String) -> [WebsiteBundleSiteMeta] {
        let extractedMetas = extractAllWebsiteBundleSiteMetas(from: scriptContent)
        let metas = extractedMetas.isEmpty
            ? fallbackWebsiteBundleSiteMetas()
            : extractedMetas
        var seen = Set<String>()

        return metas.filter { meta in
            guard !seen.contains(meta.key) else {
                return false
            }
            seen.insert(meta.key)
            return true
        }
    }

    private func extractAllWebsiteBundleSiteMetas(from scriptContent: String) -> [WebsiteBundleSiteMeta] {
        extractWebsiteBundleRawMetas(from: scriptContent).compactMap { rawMeta in
            guard let key = evaluateWebsiteBundleMetaExpression(rawMeta.keyExpression, at: rawMeta.offset, in: scriptContent),
                  let name = evaluateWebsiteBundleMetaExpression(rawMeta.nameExpression, at: rawMeta.offset, in: scriptContent),
                  isPlausibleWebsiteBundleKey(key),
                  isPlausibleWebsiteBundleName(name) else {
                return nil
            }

            return WebsiteBundleSiteMeta(
                key: key,
                name: name,
                type: rawMeta.type,
                nativeAdapter: nativeAdapter(forWebsiteBundleKey: key)
            )
        }
    }

    private static let websiteBundleRejectedDecodedValues: Set<String> = [
        "undefined", "null", "NaN", "[object Object]"
    ]

    private func isPlausibleWebsiteBundleKey(_ key: String) -> Bool {
        guard !key.isEmpty, key.count < 64 else { return false }
        if Self.websiteBundleRejectedDecodedValues.contains(key) { return false }
        for character in key {
            let isAsciiAlphaNum = character.isASCII && (character.isLetter || character.isNumber)
            guard isAsciiAlphaNum || character == "_" else { return false }
        }
        return true
    }

    private func isPlausibleWebsiteBundleName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        if Self.websiteBundleRejectedDecodedValues.contains(name) { return false }
        var total = 0
        var suspicious = 0
        for scalar in name.unicodeScalars {
            total += 1
            let value = scalar.value
            if value < 0x20, value != 0x09, value != 0x0A, value != 0x0D {
                return false
            }
            if value == 0xFFFD {
                return false
            }
            // Latin-1 supplement chars (0x80-0xFF) rarely appear in real WebsiteBundle names;
            // a high density usually means the decoder emitted raw UTF-8 bytes.
            if (0x80...0xFF).contains(value) {
                suspicious += 1
            }
        }
        return suspicious * 3 < total
    }

    private func extractLiteralWebsiteBundleSiteMetas(from scriptContent: String) -> [WebsiteBundleSiteMeta] {
        let pattern = #"meta:\{key:"([^"]+)",name:"((?:\\.|[^"\\])*)",type:(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsRange = NSRange(scriptContent.startIndex..<scriptContent.endIndex, in: scriptContent)
        return regex.matches(in: scriptContent, range: nsRange).compactMap { match in
            guard let keyRange = Range(match.range(at: 1), in: scriptContent),
                  let nameRange = Range(match.range(at: 2), in: scriptContent),
                  let typeRange = Range(match.range(at: 3), in: scriptContent),
                  let type = Int(scriptContent[typeRange]) else {
                return nil
            }

            let key = String(scriptContent[keyRange])
            let name = decodeJavaScriptStringLiteral(String(scriptContent[nameRange]))
            return WebsiteBundleSiteMeta(
                key: key,
                name: name,
                type: type,
                nativeAdapter: nativeAdapter(forWebsiteBundleKey: key)
            )
        }
    }

    private func extractWebsiteBundleRawMetas(from scriptContent: String) -> [WebsiteBundleRawMeta] {
        let marker = "meta:{key:"
        var metas: [WebsiteBundleRawMeta] = []
        var searchStart = scriptContent.startIndex

        while let markerRange = scriptContent.range(of: marker, range: searchStart..<scriptContent.endIndex) {
            let keyStart = markerRange.upperBound
            guard let keyResult = readJavaScriptExpression(
                in: scriptContent,
                from: keyStart,
                until: ",name:"
            ) else {
                searchStart = markerRange.upperBound
                continue
            }

            guard let nameResult = readJavaScriptExpression(
                in: scriptContent,
                from: keyResult.nextIndex,
                until: ",type:"
            ) else {
                searchStart = markerRange.upperBound
                continue
            }

            let typeStart = nameResult.nextIndex
            var typeEnd = typeStart
            while typeEnd < scriptContent.endIndex, scriptContent[typeEnd].isNumber {
                typeEnd = scriptContent.index(after: typeEnd)
            }

            if typeStart < typeEnd,
               let type = Int(scriptContent[typeStart..<typeEnd]) {
                metas.append(
                    WebsiteBundleRawMeta(
                        keyExpression: keyResult.expression,
                        nameExpression: nameResult.expression,
                        type: type,
                        offset: markerRange.lowerBound
                    )
                )
            }

            searchStart = markerRange.upperBound
        }

        return metas
    }

    private func readJavaScriptExpression(in source: String, from start: String.Index, until delimiter: String) -> (expression: String, nextIndex: String.Index)? {
        var index = start
        var depth = 0
        var quote: Character?
        var isEscaped = false

        while index < source.endIndex {
            let character = source[index]

            if let activeQuote = quote {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == activeQuote {
                    quote = nil
                }
                index = source.index(after: index)
                continue
            }

            switch character {
            case "\"", "'", "`":
                quote = character
            case "(", "[", "{":
                depth += 1
            case ")", "]", "}":
                depth = max(0, depth - 1)
            default:
                if depth == 0,
                   source[index...].hasPrefix(delimiter) {
                    return (
                        String(source[start..<index]).trimmingCharacters(in: .whitespacesAndNewlines),
                        source.index(index, offsetBy: delimiter.count)
                    )
                }
            }

            index = source.index(after: index)
        }

        return nil
    }

    private func evaluateWebsiteBundleMetaExpression(_ expression: String, at offset: String.Index, in scriptContent: String) -> String? {
        let trimmedExpression = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedExpression.isEmpty else {
            return nil
        }

        if let directValue = evaluateJavaScriptStringExpression(trimmedExpression, setupScript: "") {
            return directValue
        }

        guard let decoderName = firstJavaScriptCallee(in: trimmedExpression),
              let scaffold = buildWebsiteBundleDecoderScaffold(
                for: decoderName,
                before: offset,
                in: scriptContent
              ) else {
            return nil
        }

        return evaluateJavaScriptStringExpression(trimmedExpression, setupScript: scaffold)
    }

    /// 构建可独立执行的最小 JS 脚手架：alias 函数体 + 数组函数体 + `var NAME=ALIAS;` + 可选洗牌 IIFE。
    /// 不会把原脚本里夹带的业务代码拖进来，避免 `require(...)` 等在空 JSContext 中炸掉。
    private func buildWebsiteBundleDecoderScaffold(
        for decoderName: String,
        before offset: String.Index,
        in source: String
    ) -> String? {
        let prefixes = [
            "var \(decoderName)=",
            "let \(decoderName)=",
            "const \(decoderName)=",
            ",\(decoderName)="
        ]

        var bestRhs: String.Index?
        var bestDecl: String.Index?
        for prefix in prefixes {
            if let range = source.range(
                of: prefix,
                options: .backwards,
                range: source.startIndex..<offset
            ) {
                if bestDecl == nil || range.lowerBound > bestDecl! {
                    bestDecl = range.lowerBound
                    bestRhs = range.upperBound
                }
            }
        }

        guard let rhsStart = bestRhs else {
            return nil
        }

        let rhsCursor = skipJSWhitespace(from: rhsStart, in: source)
        guard let aliasEnd = readJSIdentifierEnd(from: rhsCursor, in: source),
              aliasEnd > rhsCursor else {
            return nil
        }
        let aliasName = String(source[rhsCursor..<aliasEnd])
        let afterIdentifier = skipJSWhitespace(from: aliasEnd, in: source)
        guard afterIdentifier < source.endIndex, source[afterIdentifier] == ";" else {
            return nil
        }
        let afterSemi = source.index(after: afterIdentifier)

        var iifeText = ""
        var arrayFunctionName: String?
        if let iife = parseWebsiteBundleShuffleIIFE(from: afterSemi, in: source) {
            iifeText = iife.text
            arrayFunctionName = iife.arrayFunctionName
        } else if let iife = findWebsiteBundleShuffleIIFE(referencingAlias: aliasName, in: source) {
            iifeText = iife.text
            arrayFunctionName = iife.arrayFunctionName
        }

        guard let declStart = bestDecl,
              let aliasFunctionSource = nearestFunctionDefinition(named: aliasName, to: declStart, in: source) else {
            return nil
        }

        if arrayFunctionName == nil {
            arrayFunctionName = firstZeroArgInitializerCallee(in: aliasFunctionSource)
        }

        guard let arrayName = arrayFunctionName,
              let arrayFunctionSource = nearestFunctionDefinition(named: arrayName, to: declStart, in: source) else {
            return nil
        }

        return aliasFunctionSource
            + "\n"
            + arrayFunctionSource
            + "\nvar \(decoderName)=\(aliasName);"
            + iifeText
    }

    /// 找到"让数组自洗到正确顺序"的 IIFE：`(function(n,r){let t=ALIAS,o=n();for(;;)...})(ARRAY,NUM);`。
    /// 相比紧跟 `var X=ALIAS;` 的写法更健壮 —— 不同 bundler 会把 IIFE 放在 ARRAY 函数声明之后。
    /// 唯一锚点：`let t=ALIAS,o=n()`，每个 alias 在 bundle 里只出现一次。
    private func findWebsiteBundleShuffleIIFE(
        referencingAlias aliasName: String,
        in source: String
    ) -> (text: String, arrayFunctionName: String)? {
        let anchor = "let t=\(aliasName),o=n()"
        guard let anchorRange = source.range(of: anchor) else {
            return nil
        }

        var cursor = anchorRange.lowerBound
        while cursor > source.startIndex {
            cursor = source.index(before: cursor)
            if source[cursor...].hasPrefix("(function(") {
                return extractShuffleIIFE(openParen: cursor, in: source)
            }
        }
        return nil
    }

    private func extractShuffleIIFE(
        openParen: String.Index,
        in source: String
    ) -> (text: String, arrayFunctionName: String)? {
        guard let outerClose = matchClosingBracket(
            from: openParen,
            in: source,
            openChar: "(",
            closeChar: ")"
        ) else {
            return nil
        }

        let argsOpenCursor = skipJSWhitespace(from: source.index(after: outerClose), in: source)
        guard argsOpenCursor < source.endIndex, source[argsOpenCursor] == "(" else {
            return nil
        }

        let firstArgCursor = skipJSWhitespace(from: source.index(after: argsOpenCursor), in: source)
        guard let arrayNameEnd = readJSIdentifierEnd(from: firstArgCursor, in: source),
              arrayNameEnd > firstArgCursor else {
            return nil
        }
        let arrayName = String(source[firstArgCursor..<arrayNameEnd])
        let afterArg = skipJSWhitespace(from: arrayNameEnd, in: source)
        guard afterArg < source.endIndex, source[afterArg] == "," else {
            return nil
        }

        guard let argsClose = matchClosingBracket(
            from: argsOpenCursor,
            in: source,
            openChar: "(",
            closeChar: ")"
        ) else {
            return nil
        }
        let afterArgs = skipJSWhitespace(from: source.index(after: argsClose), in: source)
        guard afterArgs < source.endIndex, source[afterArgs] == ";" else {
            return nil
        }
        let end = source.index(after: afterArgs)
        return (String(source[openParen..<end]), arrayName)
    }

    /// 识别紧跟在 `var NAME=alias;` 之后的洗牌 IIFE：`(function(...){...})(ARR, NUM);`
    private func parseWebsiteBundleShuffleIIFE(
        from start: String.Index,
        in source: String
    ) -> (text: String, arrayFunctionName: String)? {
        let opening = skipJSWhitespace(from: start, in: source)
        guard opening < source.endIndex, source[opening] == "(",
              source[opening...].hasPrefix("(function") else {
            return nil
        }

        guard let outerClose = matchClosingBracket(
            from: opening,
            in: source,
            openChar: "(",
            closeChar: ")"
        ) else {
            return nil
        }

        let argsOpenCursor = skipJSWhitespace(from: source.index(after: outerClose), in: source)
        guard argsOpenCursor < source.endIndex, source[argsOpenCursor] == "(" else {
            return nil
        }

        let firstArgCursor = skipJSWhitespace(from: source.index(after: argsOpenCursor), in: source)
        guard let arrayNameEnd = readJSIdentifierEnd(from: firstArgCursor, in: source),
              arrayNameEnd > firstArgCursor else {
            return nil
        }
        let arrayName = String(source[firstArgCursor..<arrayNameEnd])
        let afterArg = skipJSWhitespace(from: arrayNameEnd, in: source)
        guard afterArg < source.endIndex, source[afterArg] == "," else {
            return nil
        }

        guard let argsClose = matchClosingBracket(
            from: argsOpenCursor,
            in: source,
            openChar: "(",
            closeChar: ")"
        ) else {
            return nil
        }
        let afterArgs = skipJSWhitespace(from: source.index(after: argsClose), in: source)
        guard afterArgs < source.endIndex, source[afterArgs] == ";" else {
            return nil
        }
        let iifeEnd = source.index(after: afterArgs)
        return (String(source[start..<iifeEnd]), arrayName)
    }

    /// 返回与 `reference` 位置最接近的 `function NAME(...){...}` 声明文本。
    /// 用就近匹配是因为同一 bundle 里前段库代码和后段混淆解码器经常同名（如 React 组件 `function Vi()` 与解码器 `function Vi(n,r)`），
    /// 全文第一个匹配常常会拿错函数。
    private func nearestFunctionDefinition(named name: String, to reference: String.Index, in source: String) -> String? {
        let prefix = "function \(name)"

        let beforeCandidate = lastFunctionDefinition(
            prefix: prefix,
            in: source,
            range: source.startIndex..<reference
        )
        let afterCandidate = firstValidFunctionDefinition(
            prefix: prefix,
            in: source,
            searchStart: reference
        )

        switch (beforeCandidate, afterCandidate) {
        case (nil, nil):
            return nil
        case let (.some(before), nil):
            return before.source
        case let (nil, .some(after)):
            return after.source
        case let (.some(before), .some(after)):
            let beforeDistance = source.distance(from: before.start, to: reference)
            let afterDistance = source.distance(from: reference, to: after.start)
            return beforeDistance <= afterDistance ? before.source : after.source
        }
    }

    private func firstValidFunctionDefinition(
        prefix: String,
        in source: String,
        searchStart: String.Index
    ) -> (source: String, start: String.Index)? {
        var cursor = searchStart
        while let match = source.range(of: prefix, range: cursor..<source.endIndex) {
            cursor = match.upperBound
            if let body = functionDefinitionBody(matchStart: match.lowerBound, matchEnd: match.upperBound, in: source) {
                return (body, match.lowerBound)
            }
        }
        return nil
    }

    private func lastFunctionDefinition(
        prefix: String,
        in source: String,
        range: Range<String.Index>
    ) -> (source: String, start: String.Index)? {
        var upperBound = range.upperBound
        while let match = source.range(of: prefix, options: .backwards, range: range.lowerBound..<upperBound) {
            if let body = functionDefinitionBody(matchStart: match.lowerBound, matchEnd: match.upperBound, in: source) {
                return (body, match.lowerBound)
            }
            upperBound = match.lowerBound
        }
        return nil
    }

    private func functionDefinitionBody(matchStart: String.Index, matchEnd: String.Index, in source: String) -> String? {
        guard matchEnd < source.endIndex else { return nil }
        let following = source[matchEnd]
        guard following == "(" || following.isWhitespace else { return nil }

        guard let parenOpen = source[matchEnd...].firstIndex(of: "("),
              let parenClose = matchClosingBracket(
                  from: parenOpen,
                  in: source,
                  openChar: "(",
                  closeChar: ")"
              ),
              let braceOpen = source.range(
                  of: "{",
                  range: source.index(after: parenClose)..<source.endIndex
              )?.lowerBound,
              let braceClose = matchClosingBracket(
                  from: braceOpen,
                  in: source,
                  openChar: "{",
                  closeChar: "}"
              ) else {
            return nil
        }

        return String(source[matchStart..<source.index(after: braceClose)])
    }

    /// 在 alias 函数体里找 `let t=NAME()` / `var t=NAME()` / `const t=NAME()`，用以定位数组函数名。
    private func firstZeroArgInitializerCallee(in source: String) -> String? {
        let pattern = #"(?:let|var|const)\s+[A-Za-z_$][A-Za-z0-9_$]*\s*=\s*([A-Za-z_$][A-Za-z0-9_$]*)\s*\(\s*\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        guard let match = regex.firstMatch(in: source, range: nsRange),
              let range = Range(match.range(at: 1), in: source) else {
            return nil
        }
        return String(source[range])
    }

    private func skipJSWhitespace(from start: String.Index, in source: String) -> String.Index {
        var index = start
        while index < source.endIndex, source[index].isWhitespace {
            index = source.index(after: index)
        }
        return index
    }

    private func readJSIdentifierEnd(from start: String.Index, in source: String) -> String.Index? {
        guard start < source.endIndex else { return nil }
        let first = source[start]
        guard first.isLetter || first == "_" || first == "$" else { return nil }
        var index = source.index(after: start)
        while index < source.endIndex {
            let character = source[index]
            if character.isLetter || character.isNumber || character == "_" || character == "$" {
                index = source.index(after: index)
            } else {
                break
            }
        }
        return index
    }

    private func matchClosingBracket(
        from openIndex: String.Index,
        in source: String,
        openChar: Character,
        closeChar: Character
    ) -> String.Index? {
        var index = openIndex
        var depth = 0
        var quote: Character?
        var isEscaped = false

        while index < source.endIndex {
            let character = source[index]
            if let activeQuote = quote {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == activeQuote {
                    quote = nil
                }
            } else {
                switch character {
                case "\"", "'", "`":
                    quote = character
                case openChar:
                    depth += 1
                case closeChar:
                    depth -= 1
                    if depth == 0 {
                        return index
                    }
                default:
                    break
                }
            }
            index = source.index(after: index)
        }
        return nil
    }

    private func evaluateJavaScriptStringExpression(_ expression: String, setupScript: String) -> String? {
        guard let context = JSContext() else {
            return nil
        }

        // 自定义 handler 会“吞掉”异常，不再写入 context.exception。
        // 用外部标志回读，避免把抛出的 undefined 当成合法值返回。
        var didThrow = false
        context.exceptionHandler = { _, exception in
            didThrow = true
            if let exception {
                AppLogger.debug("[ApiConfig] WebsiteBundle meta 表达式还原失败: \(exception)")
            }
        }

        if !setupScript.isEmpty {
            context.evaluateScript(setupScript)
            if didThrow {
                return nil
            }
        }

        let script = """
            (function() {
                try {
                    var value = \(expression);
                    return (typeof value === 'string') ? value : null;
                } catch (e) {
                    return null;
                }
            })()
        """

        didThrow = false
        guard let result = context.evaluateScript(script), !didThrow else {
            return nil
        }
        if result.isNull || result.isUndefined || !result.isString {
            return nil
        }
        guard let value = result.toString(), !value.isEmpty else {
            return nil
        }
        return value
    }

    private func firstJavaScriptCallee(in expression: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"([A-Za-z_$][A-Za-z0-9_$]*)\s*\("#) else {
            return nil
        }

        let nsRange = NSRange(expression.startIndex..<expression.endIndex, in: expression)
        guard let match = regex.firstMatch(in: expression, range: nsRange),
              let range = Range(match.range(at: 1), in: expression) else {
            return nil
        }

        return String(expression[range])
    }

    private func fallbackWebsiteBundleSiteMetas() -> [WebsiteBundleSiteMeta] {
        [
            WebsiteBundleSiteMeta(key: "dongli", name: "🍉短剧|星芽🍉", type: 3, nativeAdapter: nil),
            WebsiteBundleSiteMeta(key: "push", name: "推送", type: 4, nativeAdapter: nil),
            WebsiteBundleSiteMeta(key: "bili", name: "🅱哔哩|集合🅱", type: 3, nativeAdapter: nil),
            WebsiteBundleSiteMeta(key: "bookWuWei", name: "🎃无忧|听书🎃", type: 3, nativeAdapter: nil),
            WebsiteBundleSiteMeta(key: "animemodu", name: "🐱魔都|动漫🐱", type: 2, nativeAdapter: nil),
            WebsiteBundleSiteMeta(key: "wexDuBoKu", name: "🌺独播|秒播🌺", type: 3, nativeAdapter: "wexDuBoKu"),
            WebsiteBundleSiteMeta(key: "wexYueYue", name: "🌺悦悦|秒播🌺", type: 3, nativeAdapter: nil),
            WebsiteBundleSiteMeta(key: "duanjuweiguan", name: "🍉短剧|小薇🍉", type: 3, nativeAdapter: nil),
            WebsiteBundleSiteMeta(key: "hanxiaoquan", name: "🌺韩剧|秒播🌺", type: 3, nativeAdapter: nil)
        ]
    }

    private func nativeAdapter(forWebsiteBundleKey key: String) -> String? {
        WebsiteBundleNativeSpiderFactory.hasAdapter(forKey: key) ? key : nil
    }

    private func decodeJavaScriptStringLiteral(_ value: String) -> String {
        var result = ""
        var index = value.startIndex

        while index < value.endIndex {
            let character = value[index]
            guard character == "\\" else {
                result.append(character)
                index = value.index(after: index)
                continue
            }

            let nextIndex = value.index(after: index)
            guard nextIndex < value.endIndex else {
                result.append(character)
                index = nextIndex
                continue
            }

            let escaped = value[nextIndex]
            switch escaped {
            case "n":
                result.append("\n")
                index = value.index(after: nextIndex)
            case "r":
                result.append("\r")
                index = value.index(after: nextIndex)
            case "t":
                result.append("\t")
                index = value.index(after: nextIndex)
            case "\"", "\\", "/":
                result.append(escaped)
                index = value.index(after: nextIndex)
            case "u":
                index = appendUnicodeEscape(from: value, escapeStart: index, unicodeMarker: nextIndex, to: &result)
            default:
                result.append(escaped)
                index = value.index(after: nextIndex)
            }
        }

        return result
    }

    private func appendUnicodeEscape(from value: String, escapeStart: String.Index, unicodeMarker: String.Index, to result: inout String) -> String.Index {
        let braceStart = value.index(after: unicodeMarker)
        if braceStart < value.endIndex, value[braceStart] == "{" {
            guard let braceEnd = value[braceStart...].firstIndex(of: "}") else {
                result.append("\\u")
                return braceStart
            }

            let hexStart = value.index(after: braceStart)
            let hex = String(value[hexStart..<braceEnd])
            if let scalarValue = UInt32(hex, radix: 16),
               let scalar = UnicodeScalar(scalarValue) {
                result.append(Character(scalar))
            }
            return value.index(after: braceEnd)
        }

        let hexStart = value.index(after: unicodeMarker)
        guard let hexEnd = value.index(hexStart, offsetBy: 4, limitedBy: value.endIndex) else {
            result.append("\\u")
            return hexStart
        }

        let hex = String(value[hexStart..<hexEnd])
        if let scalarValue = UInt32(hex, radix: 16),
           let scalar = UnicodeScalar(scalarValue) {
            result.append(Character(scalar))
        } else {
            result.append(String(value[escapeStart..<hexEnd]))
        }
        return hexEnd
    }
    
    private func loadDefaultAds() {
        let defaultAds = [
            "mimg.0c1q0l.cn", "www.googletagmanager.com", "www.google-analytics.com",
            "mc.usihnbcq.cn", "mg.g1mm3d.cn", "mscs.svaeuzh.cn", "cnzz.hhttm.top",
            "tp.vinuxhome.com", "cnzz.mmstat.com", "www.baihuillq.com", "s23.cnzz.com",
            "z3.cnzz.com", "c.cnzz.com", "stj.v1vo.top", "z12.cnzz.com", "hm.baidu.com"
        ]
        adHosts.formUnion(defaultAds)
    }
    
    private func getCachedConfig(for url: String) -> String? {
        let cacheKey = "\(Keys.cachedConfig)_\(url.md5)"
        return userDefaults.string(forKey: cacheKey)
    }
    
    private func cacheConfig(_ config: String, for url: String) {
        let cacheKey = "\(Keys.cachedConfig)_\(url.md5)"
        userDefaults.set(config, forKey: cacheKey)
    }
}

// MARK: - Errors
enum ConfigError: LocalizedError {
    case noApiUrl
    case invalidUrl
    case invalidData
    case networkError(Error)
    case parseError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noApiUrl:
            return "请先配置API地址"
        case .invalidUrl:
            return "无效的URL地址"
        case .invalidData:
            return "无效的数据格式"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .parseError(let error):
            return "解析错误: \(error.localizedDescription)"
        }
    }
}

// MARK: - String Extension
extension String {
    var md5: String {
        let data = Data(self.utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
