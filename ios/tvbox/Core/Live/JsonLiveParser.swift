import Foundation

/// TVBOX JSON 格式直播源解析器
/// 支持的格式:
/// 1. 标准 TVBOX JSON 格式
/// 2. 数组格式 (直接是频道组数组)
class JsonLiveParser: LiveParser {
    
    static func canParse(content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("{") || trimmed.hasPrefix("[")
    }
    
    func parse(content: String) throws -> [LiveChannelGroup] {
        guard let data = content.data(using: .utf8) else {
            throw LiveParserError.parseError("无法解码 JSON 内容")
        }
        
        // 尝试解析为不同的 JSON 结构
        
        // 1. 尝试解析为标准 TVBOX 格式 { "group": [...] } 或直接数组
        if let groups = try? parseStandardFormat(data) {
            return groups
        }
        
        // 2. 尝试解析为包含 lives 数组的格式
        if let groups = try? parseLivesFormat(data) {
            return groups
        }
        
        // 3. 尝试解析为简单的分组格式
        if let groups = try? parseSimpleFormat(data) {
            return groups
        }
        
        throw LiveParserError.parseError("无法识别的 JSON 直播源格式")
    }
    
    /// 解析标准 TVBOX JSON 格式
    private func parseStandardFormat(_ data: Data) throws -> [LiveChannelGroup] {
        // 尝试直接解析为数组
        if let groups = try? JSONDecoder().decode([LiveChannelGroup].self, from: data) {
            return indexGroups(groups)
        }
        
        // 尝试解析为包含 group 字段的对象
        struct GroupWrapper: Codable {
            let group: [LiveChannelGroup]?
            let groups: [LiveChannelGroup]?
        }
        
        if let wrapper = try? JSONDecoder().decode(GroupWrapper.self, from: data) {
            let groups = wrapper.group ?? wrapper.groups ?? []
            return indexGroups(groups)
        }
        
        throw LiveParserError.parseError("不是标准格式")
    }
    
    /// 解析 lives 格式 (配置文件中的 lives 数组)
    private func parseLivesFormat(_ data: Data) throws -> [LiveChannelGroup] {
        struct LivesWrapper: Codable {
            let lives: [LiveSource]?
            
            struct LiveSource: Codable {
                let group: String?
                let channels: [JsonChannel]?
            }
        }
        
        if let wrapper = try? JSONDecoder().decode(LivesWrapper.self, from: data),
           let lives = wrapper.lives {
            
            var groups: [LiveChannelGroup] = []
            
            for (index, source) in lives.enumerated() {
                var group = LiveChannelGroup()
                group.groupIndex = index
                group.groupName = source.group ?? "分组\(index + 1)"
                
                if let channels = source.channels {
                    group.channels = channels.enumerated().map { channelIndex, channel in
                        var item = LiveChannelItem()
                        item.channelIndex = channelIndex
                        item.channelNum = channelIndex + 1
                        item.channelName = channel.name
                        item.channelUrls = channel.urls
                        item.channelSourceNames = channel.urls.enumerated().map { "源\($0.offset + 1)" }
                        return item
                    }
                }
                
                groups.append(group)
            }
            
            return groups
        }
        
        throw LiveParserError.parseError("不是 lives 格式")
    }
    
    /// 解析简单的分组格式
    private func parseSimpleFormat(_ data: Data) throws -> [LiveChannelGroup] {
        // 格式: { "分组名": { "频道名": "url" 或 ["url1", "url2"] } }
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            var groups: [LiveChannelGroup] = []
            var groupIndex = 0
            
            for (groupName, groupContent) in dict {
                // 跳过非字典类型的值
                guard let channelsDict = groupContent as? [String: Any] else { continue }
                
                var group = LiveChannelGroup()
                group.groupIndex = groupIndex
                group.groupName = groupName
                
                var channelIndex = 0
                for (channelName, urlValue) in channelsDict {
                    var channel = LiveChannelItem()
                    channel.channelIndex = channelIndex
                    channel.channelNum = channelIndex + 1
                    channel.channelName = channelName
                    
                    // URL 可能是字符串或数组
                    if let urlString = urlValue as? String {
                        channel.channelUrls = [urlString]
                        channel.channelSourceNames = ["源1"]
                    } else if let urlArray = urlValue as? [String] {
                        channel.channelUrls = urlArray
                        channel.channelSourceNames = urlArray.enumerated().map { "源\($0.offset + 1)" }
                    }
                    
                    if !channel.channelUrls.isEmpty {
                        group.channels.append(channel)
                        channelIndex += 1
                    }
                }
                
                if !group.channels.isEmpty {
                    groups.append(group)
                    groupIndex += 1
                }
            }
            
            if !groups.isEmpty {
                return groups
            }
        }
        
        throw LiveParserError.parseError("不是简单格式")
    }
    
    /// 重新索引分组和频道
    private func indexGroups(_ groups: [LiveChannelGroup]) -> [LiveChannelGroup] {
        return groups.enumerated().map { groupIndex, group in
            var mutableGroup = group
            mutableGroup.groupIndex = groupIndex
            mutableGroup.channels = group.channels.enumerated().map { channelIndex, channel in
                var mutableChannel = channel
                mutableChannel.channelIndex = channelIndex
                mutableChannel.channelNum = channelIndex + 1
                return mutableChannel
            }
            return mutableGroup
        }
    }
}

/// JSON 频道结构
private struct JsonChannel: Codable {
    let name: String
    let urls: [String]
    
    enum CodingKeys: String, CodingKey {
        case name, urls, url
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        
        // urls 可能是数组或单个字符串
        if let urlArray = try? container.decode([String].self, forKey: .urls) {
            urls = urlArray
        } else if let urlString = try? container.decode(String.self, forKey: .url) {
            urls = [urlString]
        } else if let urlString = try? container.decode(String.self, forKey: .urls) {
            urls = [urlString]
        } else {
            urls = []
        }
    }
}

