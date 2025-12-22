import Foundation

/// 直播频道组 - 对应 Android 的 LiveChannelGroup
struct LiveChannelGroup: Codable, Identifiable {
    var id: String { groupName }
    
    var groupIndex: Int = 0
    var groupName: String = ""
    var groupPassword: String = ""
    var channels: [LiveChannelItem] = []
    
    enum CodingKeys: String, CodingKey {
        case groupName = "group"
        case channels
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        groupName = try container.decode(String.self, forKey: .groupName)
        
        // 处理分组名称和密码
        let splitName = groupName.components(separatedBy: "_")
        if splitName.count > 1 {
            groupName = splitName[0]
            groupPassword = splitName[1]
        }
        
        channels = try container.decodeIfPresent([LiveChannelItem].self, forKey: .channels) ?? []
    }
}

/// 直播频道项 - 对应 Android 的 LiveChannelItem
struct LiveChannelItem: Codable, Identifiable {
    var id: String { channelName }
    
    var channelIndex: Int = 0
    var channelNum: Int = 0
    var channelName: String = ""
    var channelUrls: [String] = []
    var channelSourceNames: [String] = []
    
    enum CodingKeys: String, CodingKey {
        case name, urls
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        channelName = try container.decode(String.self, forKey: .name)
        
        let urls = try container.decodeIfPresent([String].self, forKey: .urls) ?? []
        var sourceUrls: [String] = []
        var sourceNames: [String] = []
        
        for (index, url) in urls.enumerated() {
            let parts = url.components(separatedBy: "$")
            sourceUrls.append(parts[0])
            if parts.count > 1 {
                sourceNames.append(parts[1])
            } else {
                sourceNames.append("源\(index + 1)")
            }
        }
        
        channelUrls = sourceUrls
        channelSourceNames = sourceNames
    }
}

/// 直播配置 - lives 数组中的单个配置
struct LiveConfig: Codable {
    let name: String?
    let type: Int?
    let url: String?
    let api: String?
    let jar: String?
    let epg: String?
    let logo: String?
    let ua: String?
    let playerType: Int?
    let header: [String: String]?
    let ext: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        
        // type 可能是 Int 或 String
        if let typeInt = try? container.decode(Int.self, forKey: .type) {
            type = typeInt
        } else if let typeStr = try? container.decode(String.self, forKey: .type) {
            type = Int(typeStr)
        } else {
            type = nil
        }
        
        url = try container.decodeIfPresent(String.self, forKey: .url)
        api = try container.decodeIfPresent(String.self, forKey: .api)
        jar = try container.decodeIfPresent(String.self, forKey: .jar)
        epg = try container.decodeIfPresent(String.self, forKey: .epg)
        logo = try container.decodeIfPresent(String.self, forKey: .logo)
        ua = try container.decodeIfPresent(String.self, forKey: .ua)
        playerType = try container.decodeIfPresent(Int.self, forKey: .playerType)
        header = try container.decodeIfPresent([String: String].self, forKey: .header)
        ext = try container.decodeIfPresent(String.self, forKey: .ext)
    }
    
    enum CodingKeys: String, CodingKey {
        case name, type, url, api, jar, epg, logo, ua, playerType, header, ext
    }
}

