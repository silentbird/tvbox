import CryptoKit
import Foundation
import Combine

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
    var homeSites: [SiteBean] {
        sites.filter { $0.isFilterable || $0.isWebsiteBundle }
    }
    
    /// 设置当前站点
    func setCurrentSite(_ site: SiteBean) {
        currentSite = site
        userDefaults.set(site.key, forKey: Keys.homeApi)
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
        
        parseJavaScriptSourceConfig(scriptUrl: normalizeUrl(apiUrl))
    }
    
    private func isWebsiteBundleSource(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("globalThis.websiteBundle")
    }
    
    private func parseJavaScriptSourceConfig(scriptUrl: String) {
        AppLogger.debug("[parseConfig] 检测到 JS 视频源入口，按 JS 源配置处理: \(scriptUrl)")
        
        spider = scriptUrl
        wallpaper = ""
        parses = []
        liveConfigs = []
        vipParseFlags = []
        hosts = [:]
        adHosts = []
        loadDefaultAds()
        
        let site = SiteBean(
            key: "ios_website_bundle_source",
            name: "Cat WebsiteBundle",
            type: 8,
            api: scriptUrl,
            searchable: 0,
            quickSearch: 0,
            filterable: 0,
            jar: scriptUrl
        )
        
        sites = [site]
        currentSite = site
        userDefaults.set(site.key, forKey: Keys.homeApi)
        defaultParse = nil
        
        AppLogger.debug("[parseConfig] JS 视频源配置解析完成")
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
