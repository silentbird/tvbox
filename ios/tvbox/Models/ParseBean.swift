import Foundation

/// 解析配置 - 对应 Android 的 ParseBean
struct ParseBean: Decodable, Identifiable, Hashable {
    var id: String { name }
    
    let name: String
    let url: String
    let ext: String?
    let type: Int // 0: 嗅探, 1: 解析返回直链
    var isDefault: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case name, url, ext, type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(String.self, forKey: .url)
        ext = try container.decodeIfPresent(String.self, forKey: .ext)
        type = try container.decodeIfPresent(Int.self, forKey: .type) ?? 0
    }
    
    init(name: String, url: String, ext: String? = nil, type: Int = 0, isDefault: Bool = false) {
        self.name = name
        self.url = url
        self.ext = ext
        self.type = type
        self.isDefault = isDefault
    }
}

