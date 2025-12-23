import Foundation

/// 站点源配置 - 对应 Android 的 SourceBean
struct SiteBean: Decodable, Identifiable, Hashable {
    var id: String { key }
    
    let key: String
    let name: String
    let type: Int // 0: xml, 1: json, 3: jar, 4: remote
    let api: String
    let searchable: Int
    let quickSearch: Int
    let filterable: Int
    let playerUrl: String?
    let ext: String?  // 可能是字符串或 JSON 对象
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
        
        // ext 可能是字符串或字典，需要特殊处理
        ext = try SiteBean.decodeFlexibleString(container: container, key: .ext)
        
        jar = try container.decodeIfPresent(String.self, forKey: .jar)
        playerType = try container.decodeIfPresent(Int.self, forKey: .playerType) ?? -1
        categories = try container.decodeIfPresent([String].self, forKey: .categories)
        click = try container.decodeIfPresent(String.self, forKey: .click)
    }
    
    /// 解析可能是字符串或字典的字段
    private static func decodeFlexibleString(container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> String? {
        // 首先尝试解码为字符串
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }
        
        // 如果失败，尝试解码为字典并转换为 JSON 字符串
        if let dictValue = try? container.decodeIfPresent([String: AnyCodable].self, forKey: key) {
            let jsonData = try? JSONEncoder().encode(dictValue)
            if let data = jsonData {
                return String(data: data, encoding: .utf8)
            }
        }
        
        // 如果还是失败，尝试解码为任意 JSON 值
        if let anyValue = try? container.decodeIfPresent(AnyCodable.self, forKey: key) {
            let jsonData = try? JSONEncoder().encode(anyValue)
            if let data = jsonData {
                return String(data: data, encoding: .utf8)
            }
        }
        
        return nil
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

/// 用于处理任意 JSON 值的包装类型
struct AnyCodable: Codable, Hashable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "无法解码的值类型")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "无法编码的值类型"))
        }
    }
    
    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // 简单比较 - 转换为 JSON 字符串比较
        let lhsData = try? JSONEncoder().encode(lhs)
        let rhsData = try? JSONEncoder().encode(rhs)
        return lhsData == rhsData
    }
    
    func hash(into hasher: inout Hasher) {
        if let data = try? JSONEncoder().encode(self) {
            hasher.combine(data)
        }
    }
}
