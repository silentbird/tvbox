import Foundation
import Combine

/// 远程配置数据结构
struct RemoteConfig: Codable {
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
    
    struct VideoRule: Codable {
        let host: String?
        let hosts: [String]?
        let rule: [String]?
        let filter: [String]?
        let regex: [String]?
    }
    
    struct DohConfig: Codable {
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
        set { userDefaults.set(newValue, forKey: Keys.apiUrl) }
    }
    
    /// 获取直播 API URL
    var liveApiUrl: String {
        get { userDefaults.string(forKey: Keys.liveApiUrl) ?? "" }
        set { userDefaults.set(newValue, forKey: Keys.liveApiUrl) }
    }
    
    /// 加载配置
    func loadConfig(useCache: Bool = true) async throws {
        guard !apiUrl.isEmpty else {
            throw ConfigError.noApiUrl
        }
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let configUrl = normalizeUrl(apiUrl)
            
            // 尝试从缓存加载
            if useCache, let cachedData = getCachedConfig(for: apiUrl) {
                try parseConfig(jsonString: cachedData, apiUrl: apiUrl)
                await MainActor.run {
                    isLoading = false
                    configLoaded = true
                }
                return
            }
            
            // 从网络加载
            guard let url = URL(string: configUrl) else {
                throw ConfigError.invalidUrl
            }
            
            let jsonString = try await httpUtil.string(url: url)
            let processedJson = processConfigJson(jsonString)
            
            // 缓存配置
            cacheConfig(processedJson, for: apiUrl)
            
            // 解析配置
            try parseConfig(jsonString: processedJson, apiUrl: apiUrl)
            
            await MainActor.run {
                isLoading = false
                configLoaded = true
            }
        } catch {
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
        guard let data = jsonString.data(using: .utf8) else {
            throw ConfigError.invalidData
        }
        
        let decoder = JSONDecoder()
        let config = try decoder.decode(RemoteConfig.self, from: data)
        
        // 解析 spider
        spider = config.spider ?? ""
        
        // 解析 wallpaper
        wallpaper = config.wallpaper ?? ""
        if wallpaper.hasPrefix("./") {
            let baseUrl = String(apiUrl[..<(apiUrl.lastIndex(of: "/") ?? apiUrl.endIndex)])
            wallpaper = baseUrl + "/" + String(wallpaper.dropFirst(2))
        }
        
        // 解析站点
        sites = config.sites ?? []
        
        // 设置当前站点
        let savedHomeKey = userDefaults.string(forKey: Keys.homeApi) ?? ""
        if let savedSite = sites.first(where: { $0.key == savedHomeKey }) {
            currentSite = savedSite
        } else if let firstFilterable = sites.first(where: { $0.isFilterable }) {
            currentSite = firstFilterable
        } else {
            currentSite = sites.first
        }
        
        // 解析解析器
        parses = config.parses ?? []
        
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
        liveConfigs = config.lives ?? []
        
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

