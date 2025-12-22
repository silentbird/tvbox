import Foundation

/// Spider 管理器 - 管理所有爬虫实例
class SpiderManager {
    static let shared = SpiderManager()
    
    private var spiders: [String: Spider] = [:]
    private let lock = NSLock()
    private let apiConfig = ApiConfig.shared
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 获取站点对应的 Spider
    /// - Parameter site: 站点配置
    /// - Returns: Spider 实例
    func getSpider(for site: SiteBean) async throws -> Spider {
        lock.lock()
        defer { lock.unlock() }
        
        // 检查缓存
        if let spider = spiders[site.key] {
            return spider
        }
        
        // 根据站点类型创建不同的 Spider
        let spider = try createSpider(for: site)
        try await spider.initialize(ext: site.ext)
        
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
        lock.lock()
        defer { lock.unlock() }
        
        if let spider = spiders[siteKey] {
            spider.destroy()
            spiders.removeValue(forKey: siteKey)
        }
    }
    
    /// 清除所有 Spider
    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        
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
            
        default:
            throw SpiderError.unsupported("未知站点类型: \(site.type)")
        }
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

