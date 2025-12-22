import Foundation

/// JSON 类型站点的 Spider 实现
/// 对应 Android 中的 JSON 类型站点 (type = 1)
class JsonSpider: Spider {
    let siteKey: String
    private let site: SiteBean
    private let httpUtil = HttpUtil.shared
    private var isInitialized = false
    
    init(site: SiteBean) {
        self.site = site
        self.siteKey = site.key
    }
    
    // MARK: - Spider Protocol
    
    func initialize(ext: String?) async throws {
        isInitialized = true
    }
    
    func homeContent(filter: Bool) async throws -> HomeContent {
        guard isInitialized else {
            throw SpiderError.notInitialized
        }
        
        guard let url = URL(string: site.api) else {
            throw SpiderError.invalidSite
        }
        
        let jsonString = try await httpUtil.string(url: url)
        
        guard let data = jsonString.data(using: .utf8) else {
            throw SpiderError.parseError("无法解析JSON数据")
        }
        
        let response = try JSONDecoder().decode(MovieCategoryResponse.self, from: data)
        
        var content = HomeContent()
        content.categories = response.classData ?? []
        content.videos = response.list ?? []
        content.filters = response.filters ?? [:]
        
        return content
    }
    
    func categoryContent(tid: String, page: Int, filter: Bool, extend: [String: String]) async throws -> CategoryContent {
        guard isInitialized else {
            throw SpiderError.notInitialized
        }
        
        guard let baseUrl = URL(string: site.api) else {
            throw SpiderError.invalidSite
        }
        
        // 构建查询参数
        var params: [String: String] = [
            "ac": "videolist",
            "t": tid,
            "pg": String(page)
        ]
        
        // 添加筛选参数
        for (key, value) in extend {
            params[key] = value
        }
        
        let url = baseUrl.appendingQueryParameters(params)
        let jsonString = try await httpUtil.string(url: url)
        
        guard let data = jsonString.data(using: .utf8) else {
            throw SpiderError.parseError("无法解析JSON数据")
        }
        
        let response = try JSONDecoder().decode(MovieListResponse.self, from: data)
        
        return CategoryContent(
            videos: response.list ?? [],
            page: response.page ?? page,
            pageCount: response.pagecount ?? 1,
            total: response.total ?? 0
        )
    }
    
    func detailContent(ids: [String]) async throws -> [VodInfo] {
        guard isInitialized else {
            throw SpiderError.notInitialized
        }
        
        guard !ids.isEmpty else {
            return []
        }
        
        guard let baseUrl = URL(string: site.api) else {
            throw SpiderError.invalidSite
        }
        
        // 合并 ID 参数
        let idsString = ids.joined(separator: ",")
        let params: [String: String] = [
            "ac": "detail",
            "ids": idsString
        ]
        
        let url = baseUrl.appendingQueryParameters(params)
        let jsonString = try await httpUtil.string(url: url)
        
        guard let data = jsonString.data(using: .utf8) else {
            throw SpiderError.parseError("无法解析JSON数据")
        }
        
        let response = try JSONDecoder().decode(MovieDetailResponse.self, from: data)
        
        return response.list ?? []
    }
    
    func searchContent(keyword: String, quick: Bool, page: Int) async throws -> [MovieItem] {
        guard isInitialized else {
            throw SpiderError.notInitialized
        }
        
        guard let baseUrl = URL(string: site.api) else {
            throw SpiderError.invalidSite
        }
        
        let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        
        let params: [String: String] = [
            "ac": "videolist",
            "wd": encodedKeyword,
            "pg": String(page)
        ]
        
        let url = baseUrl.appendingQueryParameters(params)
        let jsonString = try await httpUtil.string(url: url)
        
        guard let data = jsonString.data(using: .utf8) else {
            throw SpiderError.parseError("无法解析JSON数据")
        }
        
        let response = try JSONDecoder().decode(MovieListResponse.self, from: data)
        
        return response.list ?? []
    }
    
    func playerContent(flag: String, id: String, vipFlags: [String]) async throws -> PlayerContent {
        // JSON 类型站点通常直接返回播放地址
        // 如果有 playerUrl 配置，则需要进行解析
        
        var content = PlayerContent()
        content.url = id
        
        // 检查是否需要解析
        if let playerUrl = site.playerUrl, !playerUrl.isEmpty {
            content.parse = 1
            content.playUrl = playerUrl
        } else if vipFlags.contains(flag) {
            // 需要 VIP 解析
            content.parse = 1
        } else {
            content.parse = 0
        }
        
        content.flag = flag
        
        return content
    }
    
    var supportsQuickSearch: Bool {
        site.isQuickSearchable
    }
    
    func destroy() {
        isInitialized = false
    }
}

