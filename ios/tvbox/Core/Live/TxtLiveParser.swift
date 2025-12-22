import Foundation

/// TXT 格式直播源解析器
/// 支持的格式:
/// 1. 标准格式: 分组名称,#genre#\n频道名称,播放地址
/// 2. 简单格式: 频道名称,播放地址
/// 3. 多源格式: 频道名称,播放地址$源名称#播放地址2$源名称2
class TxtLiveParser: LiveParser {
    
    static func canParse(content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        // TXT 格式不以 { [ # 开头
        return !trimmed.hasPrefix("{") && !trimmed.hasPrefix("[") && !trimmed.hasPrefix("#EXTM3U")
    }
    
    func parse(content: String) throws -> [LiveChannelGroup] {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var groups: [LiveChannelGroup] = []
        var currentGroup = LiveChannelGroup()
        currentGroup.groupName = "默认分组"
        currentGroup.groupIndex = 0
        
        var channelIndex = 0
        
        for line in lines {
            // 跳过注释行
            if line.hasPrefix("//") || line.hasPrefix("；") || line.hasPrefix(";") {
                continue
            }
            
            // 检查是否是分组标记
            if line.contains("#genre#") || line.contains(",#genre#") {
                // 保存之前的分组
                if !currentGroup.channels.isEmpty {
                    groups.append(currentGroup)
                }
                
                // 创建新分组
                let groupName = line
                    .replacingOccurrences(of: ",#genre#", with: "")
                    .replacingOccurrences(of: "#genre#", with: "")
                    .trimmingCharacters(in: .whitespaces)
                
                currentGroup = LiveChannelGroup()
                currentGroup.groupIndex = groups.count
                
                // 处理分组密码 (分组名_密码)
                let parts = groupName.components(separatedBy: "_")
                if parts.count > 1 {
                    currentGroup.groupName = parts[0]
                    currentGroup.groupPassword = parts[1]
                } else {
                    currentGroup.groupName = groupName.isEmpty ? "分组\(groups.count + 1)" : groupName
                }
                
                channelIndex = 0
                continue
            }
            
            // 解析频道
            if let channel = parseChannel(line: line, index: channelIndex) {
                var mutableChannel = channel
                mutableChannel.channelIndex = channelIndex
                mutableChannel.channelNum = channelIndex + 1
                currentGroup.channels.append(mutableChannel)
                channelIndex += 1
            }
        }
        
        // 添加最后一个分组
        if !currentGroup.channels.isEmpty {
            groups.append(currentGroup)
        }
        
        return groups
    }
    
    /// 解析单个频道行
    private func parseChannel(line: String, index: Int) -> LiveChannelItem? {
        // 分隔符可能是逗号、空格、制表符
        var parts: [String] = []
        
        if line.contains(",") {
            parts = line.components(separatedBy: ",")
        } else if line.contains("\t") {
            parts = line.components(separatedBy: "\t")
        } else if line.contains(" ") {
            // 按第一个空格分割
            if let spaceIndex = line.firstIndex(of: " ") {
                let name = String(line[..<spaceIndex])
                let url = String(line[line.index(after: spaceIndex)...])
                parts = [name, url]
            }
        }
        
        guard parts.count >= 2 else { return nil }
        
        let channelName = parts[0].trimmingCharacters(in: .whitespaces)
        let urlPart = parts[1...].joined(separator: ",").trimmingCharacters(in: .whitespaces)
        
        // 过滤无效频道
        guard !channelName.isEmpty, !urlPart.isEmpty else { return nil }
        guard urlPart.hasPrefix("http") || urlPart.hasPrefix("rtmp") || urlPart.hasPrefix("rtsp") else { return nil }
        
        var channel = LiveChannelItem()
        channel.channelName = channelName
        
        // 解析多源地址
        // 格式: url1$源名1#url2$源名2 或 url1#url2
        let urlSources = urlPart.components(separatedBy: "#")
        var urls: [String] = []
        var sourceNames: [String] = []
        
        for (sourceIndex, source) in urlSources.enumerated() {
            let sourceParts = source.components(separatedBy: "$")
            if sourceParts.count >= 1 {
                let url = sourceParts[0].trimmingCharacters(in: .whitespaces)
                if !url.isEmpty && (url.hasPrefix("http") || url.hasPrefix("rtmp") || url.hasPrefix("rtsp")) {
                    urls.append(url)
                    
                    if sourceParts.count > 1 {
                        sourceNames.append(sourceParts[1])
                    } else {
                        sourceNames.append("源\(sourceIndex + 1)")
                    }
                }
            }
        }
        
        guard !urls.isEmpty else { return nil }
        
        channel.channelUrls = urls
        channel.channelSourceNames = sourceNames
        
        return channel
    }
}

