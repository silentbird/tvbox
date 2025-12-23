import Foundation

/// 影视分类 - 对应 Android 的 MovieSort.SortData
struct MovieCategory: Decodable, Identifiable, Hashable {
    var id: String { tid }
    
    let tid: String
    let name: String
    var flag: String?
    var filters: [MovieFilter]?
    
    enum CodingKeys: String, CodingKey {
        case tid = "type_id"
        case name = "type_name"
        case flag = "type_flag"
        case filters
    }
    
    init(tid: String, name: String, flag: String? = nil, filters: [MovieFilter]? = nil) {
        self.tid = tid
        self.name = name
        self.flag = flag
        self.filters = filters
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // tid 可能是 Int 或 String
        if let tidInt = try? container.decode(Int.self, forKey: .tid) {
            tid = String(tidInt)
        } else {
            tid = try container.decode(String.self, forKey: .tid)
        }
        
        name = try container.decode(String.self, forKey: .name)
        flag = try container.decodeIfPresent(String.self, forKey: .flag)
        filters = try container.decodeIfPresent([MovieFilter].self, forKey: .filters)
    }
}

/// 影视筛选条件
struct MovieFilter: Decodable, Hashable {
    let key: String
    let name: String
    let values: [MovieFilterValue]
    
    enum CodingKeys: String, CodingKey {
        case key, name
        case values = "value"
    }
}

struct MovieFilterValue: Decodable, Hashable {
    let n: String // 显示名称
    let v: String // 值
}

/// 影视项 - 对应 Android 的 Movie.Video
struct MovieItem: Decodable, Identifiable, Hashable {
    var id: String { vodId }
    
    let vodId: String
    let vodName: String
    let vodPic: String?
    let vodRemarks: String?
    let vodYear: String?
    let vodArea: String?
    let vodActor: String?
    let vodDirector: String?
    let vodContent: String?
    let vodPlayFrom: String?
    let vodPlayUrl: String?
    let vodTag: String?
    let typeName: String?
    
    enum CodingKeys: String, CodingKey {
        case vodId = "vod_id"
        case vodName = "vod_name"
        case vodPic = "vod_pic"
        case vodRemarks = "vod_remarks"
        case vodYear = "vod_year"
        case vodArea = "vod_area"
        case vodActor = "vod_actor"
        case vodDirector = "vod_director"
        case vodContent = "vod_content"
        case vodPlayFrom = "vod_play_from"
        case vodPlayUrl = "vod_play_url"
        case vodTag = "vod_tag"
        case typeName = "type_name"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // vodId 可能是 Int 或 String
        if let vodIdInt = try? container.decode(Int.self, forKey: .vodId) {
            vodId = String(vodIdInt)
        } else {
            vodId = try container.decode(String.self, forKey: .vodId)
        }
        
        vodName = try container.decode(String.self, forKey: .vodName)
        vodPic = try container.decodeIfPresent(String.self, forKey: .vodPic)
        vodRemarks = try container.decodeIfPresent(String.self, forKey: .vodRemarks)
        vodYear = try container.decodeIfPresent(String.self, forKey: .vodYear)
        vodArea = try container.decodeIfPresent(String.self, forKey: .vodArea)
        vodActor = try container.decodeIfPresent(String.self, forKey: .vodActor)
        vodDirector = try container.decodeIfPresent(String.self, forKey: .vodDirector)
        vodContent = try container.decodeIfPresent(String.self, forKey: .vodContent)
        vodPlayFrom = try container.decodeIfPresent(String.self, forKey: .vodPlayFrom)
        vodPlayUrl = try container.decodeIfPresent(String.self, forKey: .vodPlayUrl)
        vodTag = try container.decodeIfPresent(String.self, forKey: .vodTag)
        typeName = try container.decodeIfPresent(String.self, forKey: .typeName)
    }
    
    /// 便捷初始化器 - 用于手动创建 MovieItem（如豆瓣热门）
    init(vodId: String, vodName: String, vodPic: String? = nil, vodRemarks: String? = nil,
         vodYear: String? = nil, vodArea: String? = nil, vodActor: String? = nil,
         vodDirector: String? = nil, vodContent: String? = nil, vodPlayFrom: String? = nil,
         vodPlayUrl: String? = nil, vodTag: String? = nil, typeName: String? = nil) {
        self.vodId = vodId
        self.vodName = vodName
        self.vodPic = vodPic
        self.vodRemarks = vodRemarks
        self.vodYear = vodYear
        self.vodArea = vodArea
        self.vodActor = vodActor
        self.vodDirector = vodDirector
        self.vodContent = vodContent
        self.vodPlayFrom = vodPlayFrom
        self.vodPlayUrl = vodPlayUrl
        self.vodTag = vodTag
        self.typeName = typeName
    }
}

/// 影视详情 - 对应 Android 的 VodInfo
struct VodInfo: Decodable, Identifiable {
    var id: String { vodId }
    
    let vodId: String
    let vodName: String
    let vodPic: String?
    let vodYear: String?
    let vodArea: String?
    let vodActor: String?
    let vodDirector: String?
    let vodContent: String?
    let vodRemarks: String?
    let typeName: String?
    
    /// 播放源列表
    var playFlags: [String] = []
    /// 播放地址列表 - 对应每个源的集数列表
    var playUrls: [[VodPlayItem]] = []
    
    struct VodPlayItem: Identifiable, Hashable {
        var id: String { "\(name)_\(url)" }
        let name: String
        let url: String
    }
    
    enum CodingKeys: String, CodingKey {
        case vodId = "vod_id"
        case vodName = "vod_name"
        case vodPic = "vod_pic"
        case vodYear = "vod_year"
        case vodArea = "vod_area"
        case vodActor = "vod_actor"
        case vodDirector = "vod_director"
        case vodContent = "vod_content"
        case vodRemarks = "vod_remarks"
        case typeName = "type_name"
        case vodPlayFrom = "vod_play_from"
        case vodPlayUrl = "vod_play_url"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // vodId 可能是 Int 或 String
        if let vodIdInt = try? container.decode(Int.self, forKey: .vodId) {
            vodId = String(vodIdInt)
        } else {
            vodId = try container.decode(String.self, forKey: .vodId)
        }
        
        vodName = try container.decode(String.self, forKey: .vodName)
        vodPic = try container.decodeIfPresent(String.self, forKey: .vodPic)
        vodYear = try container.decodeIfPresent(String.self, forKey: .vodYear)
        vodArea = try container.decodeIfPresent(String.self, forKey: .vodArea)
        vodActor = try container.decodeIfPresent(String.self, forKey: .vodActor)
        vodDirector = try container.decodeIfPresent(String.self, forKey: .vodDirector)
        vodContent = try container.decodeIfPresent(String.self, forKey: .vodContent)
        vodRemarks = try container.decodeIfPresent(String.self, forKey: .vodRemarks)
        typeName = try container.decodeIfPresent(String.self, forKey: .typeName)
        
        // 解析播放源和地址
        let playFrom = try container.decodeIfPresent(String.self, forKey: .vodPlayFrom) ?? ""
        let playUrl = try container.decodeIfPresent(String.self, forKey: .vodPlayUrl) ?? ""
        
        playFlags = playFrom.components(separatedBy: "$$$")
        let urlGroups = playUrl.components(separatedBy: "$$$")
        
        playUrls = urlGroups.map { group in
            group.components(separatedBy: "#").compactMap { item -> VodPlayItem? in
                let parts = item.components(separatedBy: "$")
                guard parts.count >= 2 else {
                    if !item.isEmpty {
                        return VodPlayItem(name: item, url: item)
                    }
                    return nil
                }
                return VodPlayItem(name: parts[0], url: parts[1])
            }
        }
    }
    
    init(vodId: String, vodName: String, vodPic: String? = nil, vodYear: String? = nil,
         vodArea: String? = nil, vodActor: String? = nil, vodDirector: String? = nil,
         vodContent: String? = nil, vodRemarks: String? = nil, typeName: String? = nil) {
        self.vodId = vodId
        self.vodName = vodName
        self.vodPic = vodPic
        self.vodYear = vodYear
        self.vodArea = vodArea
        self.vodActor = vodActor
        self.vodDirector = vodDirector
        self.vodContent = vodContent
        self.vodRemarks = vodRemarks
        self.typeName = typeName
    }
}

/// API 响应结构
struct MovieListResponse: Decodable {
    let list: [MovieItem]?
    let total: Int?
    let pagecount: Int?
    let page: Int?
    let limit: Int?
    
    enum CodingKeys: String, CodingKey {
        case list, total, pagecount, page, limit
    }
}

struct MovieDetailResponse: Decodable {
    let list: [VodInfo]?
    
    enum CodingKeys: String, CodingKey {
        case list
    }
}

struct MovieCategoryResponse: Decodable {
    let classData: [MovieCategory]?
    let list: [MovieItem]?
    let filters: [String: [MovieFilter]]?
    
    enum CodingKeys: String, CodingKey {
        case classData = "class"
        case list, filters
    }
}

