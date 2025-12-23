import Foundation
import Combine

/// 远程配置数据结构
struct RemoteConfig: Decodable {
    let spider: String?
    let wallpaper: String?
    let sites: [SiteBean]?
    let parses: [ParseBean]?
    let lives: [LiveConfig]?
    let rules: [VideoRule]?
    let doh: [DohConfig]?
    let hosts: [String]?
    let ads: [String]?
    let flags: [String]?
    
    struct VideoRule: Decodable {
        let host: String?
        let hosts: [String]?
        let rule: [String]?
        let filter: [String]?
        let regex: [String]?
    }
    
    struct DohConfig: Decodable {
        let name: String
        let url: String
    }
}

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
            print("[ApiConfig] apiUrl setter: \(newValue)")
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
        print("[ApiConfig] ========== loadConfig 开始 ==========")
        print("[ApiConfig] useCache: \(useCache), apiUrl: \(apiUrl)")
        
        guard !apiUrl.isEmpty else {
            print("[ApiConfig] 错误: apiUrl 为空")
            throw ConfigError.noApiUrl
        }
        
        // 防止重复加载
        guard !isLoading else {
            print("[ApiConfig] 配置正在加载中，跳过重复请求")
            return
        }
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let configUrl = normalizeUrl(apiUrl)
            print("[ApiConfig] 规范化后的URL: \(configUrl)")
            
            // 尝试从缓存加载
            if useCache, let cachedData = getCachedConfig(for: apiUrl) {
                print("[ApiConfig] 从缓存加载配置，数据长度: \(cachedData.count)")
                do {
                    try await MainActor.run {
                        try parseConfig(jsonString: cachedData, apiUrl: apiUrl)
                        isLoading = false
                        configLoaded = true
                    }
                    print("[ApiConfig] 缓存加载完成")
                    return
                } catch {
                    print("[ApiConfig] 缓存解析失败，清除缓存并重新从网络加载: \(error.localizedDescription)")
                    clearCache()
                    // 继续从网络加载
                }
            }
            
            // 从网络加载
            print("[ApiConfig] 尝试创建URL: \(configUrl)")
            guard let url = createURL(from: configUrl) else {
                print("[ApiConfig] 错误: 无效的URL - '\(configUrl)'")
                throw ConfigError.invalidUrl
            }
            
            print("[ApiConfig] 创建的URL对象: \(url.absoluteString)")
            print("[ApiConfig] 开始网络请求...")
            let jsonString = try await httpUtil.string(url: url)
            print("[ApiConfig] 网络请求完成，响应长度: \(jsonString.count)")
            
            let processedJson = processConfigJson(jsonString)
            print("[ApiConfig] 处理后的JSON长度: \(processedJson.count)")
            
            // 缓存配置
            cacheConfig(processedJson, for: apiUrl)
            print("[ApiConfig] 配置已缓存")
            
            // 解析配置 (在主线程上执行，因为会修改 @Published 属性)
            print("[ApiConfig] 开始解析配置...")
            try await MainActor.run {
                try parseConfig(jsonString: processedJson, apiUrl: apiUrl)
                isLoading = false
                configLoaded = true
            }
            print("[ApiConfig] ========== loadConfig 完成 ==========")
        } catch {
            print("[ApiConfig] 加载失败: \(error.localizedDescription)")
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
            print("[ApiConfig] 已清除缓存: \(cacheKey)")
        }
    }
    
    /// 重置所有配置（包括 URL 和缓存）
    func resetAll() {
        clearCache()
        clearConfig()
        userDefaults.removeObject(forKey: Keys.apiUrl)
        print("[ApiConfig] 已重置所有配置")
    }
    
    // MARK: - Private Methods
    
    private func normalizeUrl(_ url: String) -> String {
        var configUrl = url
        
        // 处理 clan:// 协议
        if configUrl.hasPrefix("clan://localhost/") {
            configUrl = configUrl.replacingOccurrences(of: "clan://localhost/", with: "http://127.0.0.1:9978/file/")
        } else if configUrl.hasPrefix("clan://") {
            let link = String(configUrl.dropFirst(7))
            if let endIndex = link.firstIndex(of: "/") {
                let host = String(link[..<endIndex])
                let path = String(link[link.index(after: endIndex)...])
                configUrl = "http://\(host)/file/\(path)"
            }
        } else if configUrl.hasPrefix("file://") {
            configUrl = configUrl.replacingOccurrences(of: "file://", with: "http://127.0.0.1:9978/file/")
        } else if !configUrl.hasPrefix("http") {
            configUrl = "http://\(configUrl)"
        }
        
        // 处理加密 key
        if configUrl.contains(";pk;") {
            let parts = configUrl.components(separatedBy: ";pk;")
            configUrl = parts[0]
        }
        
        return configUrl
    }
    
    /// 将 URL 字符串转换为 URL 对象（支持中文域名）
    private func createURL(from urlString: String) -> URL? {
        print("[ApiConfig] createURL 输入: \(urlString)")
        
        // 方法1: 直接使用 URL(string:) - iOS 会自动处理 IDN
        if let url = URL(string: urlString) {
            print("[ApiConfig] 方法1成功: \(url.absoluteString)")
            return url
        }
        
        // 方法2: 使用 URLComponents
        if let components = URLComponents(string: urlString), let url = components.url {
            print("[ApiConfig] 方法2成功: \(url.absoluteString)")
            return url
        }
        
        // 方法3: 对域名进行 Punycode 编码
        if let encoded = encodeIDNUrl(urlString) {
            print("[ApiConfig] 方法3成功: \(encoded.absoluteString)")
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
                print("[ApiConfig] 方法4成功: \(url.absoluteString)")
                return url
            }
        }
        
        print("[ApiConfig] 所有方法都失败了")
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
    
    private func processConfigJson(_ json: String) -> String {
        var content = json
        
        // 处理加密配置
        if let range = content.range(of: "[A-Za-z0]{8}\\*\\*", options: .regularExpression) {
            let startIndex = content.index(range.upperBound, offsetBy: 2, limitedBy: content.endIndex) ?? range.upperBound
            let base64Content = String(content[startIndex...])
            if let data = Data(base64Encoded: base64Content) {
                content = String(data: data, encoding: .utf8) ?? json
            }
        }
        
        return content
    }
    
    private func parseConfig(jsonString: String, apiUrl: String) throws {
        print("[parseConfig] 开始解析配置...")
        
        guard let data = jsonString.data(using: .utf8) else {
            print("[parseConfig] 错误: 无法转换为 Data")
            throw ConfigError.invalidData
        }
        
        print("[parseConfig] 开始 JSON 解码...")
        print("[parseConfig] JSON 内容前500字符: \(String(jsonString.prefix(500)))")
        let decoder = JSONDecoder()
        let config: RemoteConfig
        do {
            config = try decoder.decode(RemoteConfig.self, from: data)
        } catch let DecodingError.keyNotFound(key, context) {
            print("[parseConfig] 解码错误 - 缺少键: \(key.stringValue)")
            print("[parseConfig] 上下文: \(context.debugDescription)")
            print("[parseConfig] 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            throw ConfigError.parseError(DecodingError.keyNotFound(key, context))
        } catch let DecodingError.typeMismatch(type, context) {
            print("[parseConfig] 解码错误 - 类型不匹配: 期望 \(type)")
            print("[parseConfig] 上下文: \(context.debugDescription)")
            print("[parseConfig] 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            throw ConfigError.parseError(DecodingError.typeMismatch(type, context))
        } catch let DecodingError.valueNotFound(type, context) {
            print("[parseConfig] 解码错误 - 值为空: \(type)")
            print("[parseConfig] 上下文: \(context.debugDescription)")
            print("[parseConfig] 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            throw ConfigError.parseError(DecodingError.valueNotFound(type, context))
        } catch let DecodingError.dataCorrupted(context) {
            print("[parseConfig] 解码错误 - 数据损坏")
            print("[parseConfig] 上下文: \(context.debugDescription)")
            print("[parseConfig] 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            throw ConfigError.parseError(DecodingError.dataCorrupted(context))
        }
        print("[parseConfig] JSON 解码完成")
        
        // 解析 spider
        spider = config.spider ?? ""
        print("[parseConfig] spider: \(spider.prefix(50))...")
        
        // 解析 wallpaper
        wallpaper = config.wallpaper ?? ""
        if wallpaper.hasPrefix("./") {
            let baseUrl = String(apiUrl[..<(apiUrl.lastIndex(of: "/") ?? apiUrl.endIndex)])
            wallpaper = baseUrl + "/" + String(wallpaper.dropFirst(2))
        }
        
        // 解析站点 - 使用字典存储，相同 key 的站点会被后面的覆盖（与 Android LinkedHashMap 保持一致）
        print("[parseConfig] 开始解析站点...")
        var siteMap: [String: SiteBean] = [:]
        var orderedKeys: [String] = []  // 保持插入顺序
        for site in config.sites ?? [] {
            if siteMap[site.key] == nil {
                orderedKeys.append(site.key)  // 只在第一次出现时记录顺序
            }
            siteMap[site.key] = site  // 相同 key 后面覆盖前面
        }
        sites = orderedKeys.compactMap { siteMap[$0] }
        print("[parseConfig] 解析到 \(sites.count) 个站点（去重后）")
        
        // 设置当前站点
        // 只有在有保存的站点设置时才恢复，否则默认显示豆瓣热门（currentSite = nil）
        let savedHomeKey = userDefaults.string(forKey: Keys.homeApi) ?? ""
        if savedHomeKey == "douban_home" {
            // 用户选择了豆瓣热门
            currentSite = nil
        } else if !savedHomeKey.isEmpty, let savedSite = sites.first(where: { $0.key == savedHomeKey }) {
            // 恢复保存的站点
            currentSite = savedSite
        } else {
            // 默认显示豆瓣热门
            currentSite = nil
        }
        print("[parseConfig] 当前站点: \(currentSite?.name ?? "豆瓣热门")")
        
        // 解析解析器
        print("[parseConfig] 开始解析解析器...")
        parses = config.parses ?? []
        print("[parseConfig] 解析到 \(parses.count) 个解析器")
        
        // 添加超级解析
        if !parses.isEmpty {
            let superParse = ParseBean(name: "超级解析", url: "SuperParse", type: 4)
            parses.insert(superParse, at: 0)
        }
        
        // 设置默认解析
        let savedParseName = userDefaults.string(forKey: Keys.defaultParse) ?? ""
        if let savedParse = parses.first(where: { $0.name == savedParseName }) {
            var parse = savedParse
            parse.isDefault = true
            defaultParse = parse
        } else if let firstParse = parses.first {
            var parse = firstParse
            parse.isDefault = true
            defaultParse = parse
        }
        
        // 解析 VIP 标识
        vipParseFlags = config.flags ?? []
        
        // 解析直播配置
        print("[parseConfig] 开始解析直播配置...")
        liveConfigs = config.lives ?? []
        print("[parseConfig] 解析到 \(liveConfigs.count) 个直播配置")
        
        // 解析 hosts
        if let hostsList = config.hosts {
            for entry in hostsList {
                let parts = entry.components(separatedBy: "=")
                if parts.count == 2 {
                    hosts[parts[0]] = parts[1]
                }
            }
        }
        
        // 解析广告
        if let ads = config.ads {
            adHosts.formUnion(ads)
        }
        
        print("[parseConfig] 配置解析完成!")
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
        var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_MD5($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

import CommonCrypto

