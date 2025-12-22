import Foundation

/// Spider 爬虫协议 - 对应 Android 的 Spider 接口
/// 所有类型的爬虫都需要实现此协议
protocol Spider {
    /// 站点 key
    var siteKey: String { get }
    
    /// 初始化爬虫
    /// - Parameters:
    ///   - ext: 扩展参数
    func initialize(ext: String?) async throws
    
    /// 获取首页内容
    /// - Parameter filter: 是否获取筛选数据
    /// - Returns: 首页数据 (包含分类和视频列表)
    func homeContent(filter: Bool) async throws -> HomeContent
    
    /// 获取首页视频列表
    /// - Returns: 视频列表
    func homeVideoContent() async throws -> [MovieItem]
    
    /// 获取分类视频列表
    /// - Parameters:
    ///   - tid: 分类ID
    ///   - page: 页码
    ///   - filter: 是否启用筛选
    ///   - extend: 筛选扩展参数
    /// - Returns: 分类视频列表
    func categoryContent(tid: String, page: Int, filter: Bool, extend: [String: String]) async throws -> CategoryContent
    
    /// 获取视频详情
    /// - Parameter ids: 视频ID列表
    /// - Returns: 视频详情列表
    func detailContent(ids: [String]) async throws -> [VodInfo]
    
    /// 搜索视频
    /// - Parameters:
    ///   - keyword: 搜索关键字
    ///   - quick: 是否快速搜索
    ///   - page: 页码
    /// - Returns: 搜索结果列表
    func searchContent(keyword: String, quick: Bool, page: Int) async throws -> [MovieItem]
    
    /// 获取播放地址
    /// - Parameters:
    ///   - flag: 播放源标识
    ///   - id: 播放ID
    ///   - vipFlags: VIP标识列表
    /// - Returns: 播放信息
    func playerContent(flag: String, id: String, vipFlags: [String]) async throws -> PlayerContent
    
    /// 是否支持快速搜索
    var supportsQuickSearch: Bool { get }
    
    /// 销毁爬虫资源
    func destroy()
}

// MARK: - Spider 数据结构

/// 首页内容
struct HomeContent {
    var categories: [MovieCategory]
    var videos: [MovieItem]
    var filters: [String: [MovieFilter]]
    
    init(categories: [MovieCategory] = [], videos: [MovieItem] = [], filters: [String: [MovieFilter]] = [:]) {
        self.categories = categories
        self.videos = videos
        self.filters = filters
    }
}

/// 分类内容
struct CategoryContent {
    var videos: [MovieItem]
    var page: Int
    var pageCount: Int
    var total: Int
    
    init(videos: [MovieItem] = [], page: Int = 1, pageCount: Int = 1, total: Int = 0) {
        self.videos = videos
        self.page = page
        self.pageCount = pageCount
        self.total = total
    }
    
    var hasMore: Bool {
        page < pageCount
    }
}

/// 播放内容
struct PlayerContent {
    var url: String
    var header: [String: String]?
    var parse: Int // 0: 直接播放, 1: 需要解析
    var playUrl: String?
    var jxFrom: String?
    var flag: String?
    var danmaku: String?
    var format: String?
    var subs: [SubtitleInfo]?
    
    init(url: String = "", header: [String: String]? = nil, parse: Int = 0,
         playUrl: String? = nil, jxFrom: String? = nil, flag: String? = nil,
         danmaku: String? = nil, format: String? = nil, subs: [SubtitleInfo]? = nil) {
        self.url = url
        self.header = header
        self.parse = parse
        self.playUrl = playUrl
        self.jxFrom = jxFrom
        self.flag = flag
        self.danmaku = danmaku
        self.format = format
        self.subs = subs
    }
    
    /// 是否需要解析
    var needParse: Bool {
        parse == 1
    }
}

/// 字幕信息
struct SubtitleInfo: Codable {
    let name: String
    let url: String
    let lang: String?
    let format: String?
    
    init(name: String, url: String, lang: String? = nil, format: String? = nil) {
        self.name = name
        self.url = url
        self.lang = lang
        self.format = format
    }
}

// MARK: - Spider 错误

enum SpiderError: LocalizedError {
    case notInitialized
    case invalidSite
    case networkError(Error)
    case parseError(String)
    case scriptError(String)
    case unsupported(String)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "爬虫未初始化"
        case .invalidSite:
            return "无效的站点配置"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .parseError(let message):
            return "解析错误: \(message)"
        case .scriptError(let message):
            return "脚本错误: \(message)"
        case .unsupported(let feature):
            return "不支持的功能: \(feature)"
        }
    }
}

// MARK: - Spider 默认实现

extension Spider {
    var supportsQuickSearch: Bool { true }
    
    func homeVideoContent() async throws -> [MovieItem] {
        let content = try await homeContent(filter: false)
        return content.videos
    }
}

