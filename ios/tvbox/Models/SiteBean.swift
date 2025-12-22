import Foundation

/// 站点源配置 - 对应 Android 的 SourceBean
struct SiteBean: Codable, Identifiable, Hashable {
    var id: String { key }
    
    let key: String
    let name: String
    let type: Int // 0: xml, 1: json, 3: jar, 4: remote
    let api: String
    let searchable: Int
    let quickSearch: Int
    let filterable: Int
    let playerUrl: String?
    let ext: String?
    let jar: String?
    let playerType: Int
    let categories: [String]?
    let click: String?
    
    enum CodingKeys: String, CodingKey {
        case key, name, type, api, searchable, quickSearch, filterable
        case playerUrl = "playUrl"
        case ext, jar, playerType, categories, click
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? key
        type = try container.decode(Int.self, forKey: .type)
        api = try container.decode(String.self, forKey: .api)
        searchable = try container.decodeIfPresent(Int.self, forKey: .searchable) ?? 1
        quickSearch = try container.decodeIfPresent(Int.self, forKey: .quickSearch) ?? 1
        filterable = try container.decodeIfPresent(Int.self, forKey: .filterable) ?? 1
        playerUrl = try container.decodeIfPresent(String.self, forKey: .playerUrl)
        ext = try container.decodeIfPresent(String.self, forKey: .ext)
        jar = try container.decodeIfPresent(String.self, forKey: .jar)
        playerType = try container.decodeIfPresent(Int.self, forKey: .playerType) ?? -1
        categories = try container.decodeIfPresent([String].self, forKey: .categories)
        click = try container.decodeIfPresent(String.self, forKey: .click)
    }
    
    init(key: String, name: String, type: Int, api: String, searchable: Int = 1,
         quickSearch: Int = 1, filterable: Int = 1, playerUrl: String? = nil,
         ext: String? = nil, jar: String? = nil, playerType: Int = -1,
         categories: [String]? = nil, click: String? = nil) {
        self.key = key
        self.name = name
        self.type = type
        self.api = api
        self.searchable = searchable
        self.quickSearch = quickSearch
        self.filterable = filterable
        self.playerUrl = playerUrl
        self.ext = ext
        self.jar = jar
        self.playerType = playerType
        self.categories = categories
        self.click = click
    }
    
    var isSearchable: Bool { searchable == 1 }
    var isQuickSearchable: Bool { quickSearch == 1 }
    var isFilterable: Bool { filterable == 1 }
}

