import Foundation

/// M3U/M3U8 格式直播源解析器
/// 支持的格式:
/// #EXTM3U
/// #EXTINF:-1 tvg-id="xxx" tvg-name="xxx" tvg-logo="xxx" group-title="xxx",频道名称
/// 播放地址
class M3uLiveParser: LiveParser {
    
    static func canParse(content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("#EXTM3U")
    }
    
    func parse(content: String) throws -> [LiveChannelGroup] {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        
        var groupsDict: [String: LiveChannelGroup] = [:]
        var currentChannelInfo: M3uChannelInfo?
        var groupOrder: [String] = [] // 保持分组顺序
        
        for line in lines {
            // 跳过空行和 #EXTM3U 头
            if line.isEmpty || line == "#EXTM3U" {
                continue
            }
            
            // 解析 #EXTINF 行
            if line.hasPrefix("#EXTINF:") {
                currentChannelInfo = parseExtInf(line)
                continue
            }
            
            // 跳过其他 # 开头的行 (如 #EXTVLCOPT)
            if line.hasPrefix("#") {
                continue
            }
            
            // 播放地址行
            if let info = currentChannelInfo,
               (line.hasPrefix("http") || line.hasPrefix("rtmp") || line.hasPrefix("rtsp")) {
                
                let groupName = info.groupTitle.isEmpty ? "默认分组" : info.groupTitle
                
                // 创建或获取分组
                if groupsDict[groupName] == nil {
                    var newGroup = LiveChannelGroup()
                    newGroup.groupName = groupName
                    newGroup.groupIndex = groupOrder.count
                    groupsDict[groupName] = newGroup
                    groupOrder.append(groupName)
                }
                
                // 检查是否已存在同名频道 (添加多源)
                if let existingIndex = groupsDict[groupName]?.channels.firstIndex(where: { $0.channelName == info.channelName }) {
                    // 添加到已有频道的源列表
                    groupsDict[groupName]?.channels[existingIndex].channelUrls.append(line)
                    let sourceIndex = groupsDict[groupName]?.channels[existingIndex].channelUrls.count ?? 1
                    groupsDict[groupName]?.channels[existingIndex].channelSourceNames.append("源\(sourceIndex)")
                } else {
                    // 创建新频道
                    var channel = LiveChannelItem()
                    channel.channelName = info.channelName
                    channel.channelIndex = groupsDict[groupName]?.channels.count ?? 0
                    channel.channelNum = channel.channelIndex + 1
                    channel.channelUrls = [line]
                    channel.channelSourceNames = ["源1"]
                    
                    groupsDict[groupName]?.channels.append(channel)
                }
                
                currentChannelInfo = nil
            }
        }
        
        // 按顺序返回分组
        return groupOrder.compactMap { groupsDict[$0] }
    }
    
    /// 解析 #EXTINF 行
    private func parseExtInf(_ line: String) -> M3uChannelInfo {
        var info = M3uChannelInfo()
        
        // 格式: #EXTINF:-1 tvg-id="xxx" tvg-name="xxx" tvg-logo="xxx" group-title="分组",频道名称
        
        // 提取频道名称 (逗号后面的部分)
        if let commaIndex = line.lastIndex(of: ",") {
            info.channelName = String(line[line.index(after: commaIndex)...]).trimmingCharacters(in: .whitespaces)
        }
        
        // 提取属性
        info.tvgId = extractAttribute(from: line, attribute: "tvg-id")
        info.tvgName = extractAttribute(from: line, attribute: "tvg-name")
        info.tvgLogo = extractAttribute(from: line, attribute: "tvg-logo")
        info.groupTitle = extractAttribute(from: line, attribute: "group-title")
        
        // 如果没有频道名称，使用 tvg-name
        if info.channelName.isEmpty && !info.tvgName.isEmpty {
            info.channelName = info.tvgName
        }
        
        return info
    }
    
    /// 提取属性值
    private func extractAttribute(from line: String, attribute: String) -> String {
        // 匹配 attribute="value" 或 attribute='value'
        let patterns = [
            "\(attribute)=\"([^\"]+)\"",
            "\(attribute)='([^']+)'"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range(at: 1), in: line) {
                return String(line[range])
            }
        }
        
        return ""
    }
}

/// M3U 频道信息
private struct M3uChannelInfo {
    var tvgId: String = ""
    var tvgName: String = ""
    var tvgLogo: String = ""
    var groupTitle: String = ""
    var channelName: String = ""
}

