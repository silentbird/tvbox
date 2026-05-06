import Foundation

/// Spider 管理器 - 管理所有爬虫实例
actor SpiderManager {
    static let shared = SpiderManager()
    
    private var spiders: [String: Spider] = [:]
    private let apiConfig = ApiConfig.shared
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 获取站点对应的 Spider
    /// - Parameter site: 站点配置
    /// - Returns: Spider 实例
    func getSpider(for site: SiteBean) async throws -> Spider {
        let site = resolveLegacyWebsiteBundleSite(site)

        // 检查缓存
        if let spider = spiders[site.key] {
            return spider
        }
        
        // 根据站点类型创建不同的 Spider
        var spider = try createSpider(for: site)
        
        do {
            try await spider.initialize(ext: site.ext)
        } catch let error as SpiderError {
            // 如果是 JsSpider 且因为 QuickJS 格式失败，尝试使用 QuickJSSpider
            if case .unsupported(let msg) = error,
               msg.contains("QuickJS") || msg.contains("字节码") || msg.contains("二进制"),
               site.type == 3 {
                AppLogger.debug("[SpiderManager] JsSpider 失败，尝试 QuickJSSpider: \(msg)")
                spider = QuickJSSpider(site: site)
                try await spider.initialize(ext: site.ext)
            } else {
                throw error
            }
        }
        
        spiders[site.key] = spider
        
        return spider
    }
    
    /// 获取当前站点的 Spider
    func getCurrentSpider() async throws -> Spider {
        guard let currentSite = apiConfig.currentSite else {
            throw SpiderError.invalidSite
        }
        return try await getSpider(for: currentSite)
    }
    
    /// 清除指定站点的 Spider
    func clearSpider(for siteKey: String) {
        if let spider = spiders[siteKey] {
            spider.destroy()
            spiders.removeValue(forKey: siteKey)
        }
    }
    
    /// 清除所有 Spider
    func clearAll() {
        for spider in spiders.values {
            spider.destroy()
        }
        spiders.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func createSpider(for site: SiteBean) throws -> Spider {
        switch site.type {
        case 0:
            // XML 类型 - TODO: 实现 XML Spider
            throw SpiderError.unsupported("XML类型站点暂不支持")
            
        case 1:
            // JSON 类型
            return JsonSpider(site: site)
            
        case 3:
            // JS/JAR 类型 - 使用 JsSpider
            return JsSpider(site: site)
            
        case 4:
            // 远程类型 - 需要先加载远程配置
            throw SpiderError.unsupported("远程类型站点暂不支持")
            
        case 8:
            return WebsiteBundleSpider(site: site)
            
        default:
            throw SpiderError.unsupported("未知站点类型: \(site.type)")
        }
    }

    private func resolveLegacyWebsiteBundleSite(_ site: SiteBean) -> SiteBean {
        guard site.key == "ios_website_bundle_source" else {
            return site
        }

        if let adaptedSite = apiConfig.sites.first(where: \.isWebsiteBundleAdapted) {
            AppLogger.debug("[SpiderManager] 旧 WebsiteBundle 占位站点已迁移到原生适配站点: \(adaptedSite.key)")
            return adaptedSite
        }

        return site
    }
}

// MARK: - 便捷方法

extension SpiderManager {
    /// 获取首页内容
    func homeContent(filter: Bool = true) async throws -> HomeContent {
        let spider = try await getCurrentSpider()
        return try await spider.homeContent(filter: filter)
    }
    
    /// 获取分类内容
    func categoryContent(tid: String, page: Int = 1, filter: Bool = false, extend: [String: String] = [:]) async throws -> CategoryContent {
        let spider = try await getCurrentSpider()
        return try await spider.categoryContent(tid: tid, page: page, filter: filter, extend: extend)
    }
    
    /// 获取详情
    func detailContent(ids: [String]) async throws -> [VodInfo] {
        let spider = try await getCurrentSpider()
        return try await spider.detailContent(ids: ids)
    }
    
    /// 搜索
    func searchContent(keyword: String, quick: Bool = false, page: Int = 1) async throws -> [MovieItem] {
        let spider = try await getCurrentSpider()
        return try await spider.searchContent(keyword: keyword, quick: quick, page: page)
    }
    
    /// 获取播放地址
    func playerContent(flag: String, id: String) async throws -> PlayerContent {
        let spider = try await getCurrentSpider()
        let vipFlags = apiConfig.vipParseFlags
        return try await spider.playerContent(flag: flag, id: id, vipFlags: vipFlags)
    }
}
