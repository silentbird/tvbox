import Foundation

/// EPG 电子节目单管理器
class EpgManager {
    static let shared = EpgManager()
    
    private let httpUtil = HttpUtil.shared
    private var epgCache: [String: [EpgProgram]] = [:] // 频道ID -> 节目列表
    private var epgUpdateTime: Date?
    private let cacheExpiry: TimeInterval = 3600 * 6 // 6小时过期
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 加载 EPG 数据
    /// - Parameter urlString: EPG 数据源 URL
    func loadEpg(from urlString: String) async throws {
        guard let url = URL(string: urlString) else {
            throw EpgError.invalidUrl
        }
        
        // 检查缓存是否有效
        if let updateTime = epgUpdateTime,
           Date().timeIntervalSince(updateTime) < cacheExpiry,
           !epgCache.isEmpty {
            return
        }
        
        let content = try await httpUtil.string(url: url)
        let programs = try parseEpg(content: content, urlString: urlString)
        
        // 按频道分组
        var channelPrograms: [String: [EpgProgram]] = [:]
        for program in programs {
            if channelPrograms[program.channelId] == nil {
                channelPrograms[program.channelId] = []
            }
            channelPrograms[program.channelId]?.append(program)
        }
        
        // 排序节目
        for (channelId, programs) in channelPrograms {
            channelPrograms[channelId] = programs.sorted { $0.startTime < $1.startTime }
        }
        
        epgCache = channelPrograms
        epgUpdateTime = Date()
    }
    
    /// 获取频道当前节目
    /// - Parameter channelName: 频道名称
    /// - Returns: 当前节目
    func getCurrentProgram(for channelName: String) -> EpgProgram? {
        let normalizedName = normalizeChannelName(channelName)
        guard let programs = epgCache[normalizedName] else { return nil }
        
        let now = Date()
        return programs.first { program in
            program.startTime <= now && program.endTime > now
        }
    }
    
    /// 获取频道节目列表
    /// - Parameters:
    ///   - channelName: 频道名称
    ///   - date: 日期 (可选，默认今天)
    /// - Returns: 节目列表
    func getPrograms(for channelName: String, date: Date? = nil) -> [EpgProgram] {
        let normalizedName = normalizeChannelName(channelName)
        guard let programs = epgCache[normalizedName] else { return [] }
        
        if let targetDate = date {
            let calendar = Calendar.current
            return programs.filter { program in
                calendar.isDate(program.startTime, inSameDayAs: targetDate)
            }
        }
        
        return programs
    }
    
    /// 获取频道下一个节目
    /// - Parameter channelName: 频道名称
    /// - Returns: 下一个节目
    func getNextProgram(for channelName: String) -> EpgProgram? {
        let normalizedName = normalizeChannelName(channelName)
        guard let programs = epgCache[normalizedName] else { return nil }
        
        let now = Date()
        return programs.first { program in
            program.startTime > now
        }
    }
    
    /// 清除缓存
    func clearCache() {
        epgCache.removeAll()
        epgUpdateTime = nil
    }
    
    // MARK: - Private Methods
    
    /// 解析 EPG 数据
    private func parseEpg(content: String, urlString: String) throws -> [EpgProgram] {
        // 判断格式
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.hasPrefix("<?xml") || trimmed.hasPrefix("<tv") {
            return try parseXmltvEpg(content)
        } else if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            return try parseJsonEpg(content)
        } else {
            // 尝试作为简单文本格式解析
            return try parseTextEpg(content)
        }
    }
    
    /// 解析 XMLTV 格式的 EPG
    private func parseXmltvEpg(_ content: String) throws -> [EpgProgram] {
        var programs: [EpgProgram] = []
        
        // 使用正则表达式提取节目信息
        let programPattern = "<programme start=\"([^\"]+)\" stop=\"([^\"]+)\" channel=\"([^\"]+)\"[^>]*>.*?<title[^>]*>([^<]+)</title>.*?(?:<desc[^>]*>([^<]*)</desc>)?.*?</programme>"
        
        guard let regex = try? NSRegularExpression(pattern: programPattern, options: [.dotMatchesLineSeparators]) else {
            throw EpgError.parseError("无法创建正则表达式")
        }
        
        let nsContent = content as NSString
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss Z"
        
        let altDateFormatter = DateFormatter()
        altDateFormatter.dateFormat = "yyyyMMddHHmmss"
        
        for match in matches {
            let startStr = nsContent.substring(with: match.range(at: 1))
            let endStr = nsContent.substring(with: match.range(at: 2))
            let channelId = nsContent.substring(with: match.range(at: 3))
            let title = nsContent.substring(with: match.range(at: 4))
            let desc = match.range(at: 5).location != NSNotFound ? nsContent.substring(with: match.range(at: 5)) : ""
            
            // 解析时间
            guard let startTime = dateFormatter.date(from: startStr) ?? altDateFormatter.date(from: String(startStr.prefix(14))),
                  let endTime = dateFormatter.date(from: endStr) ?? altDateFormatter.date(from: String(endStr.prefix(14))) else {
                continue
            }
            
            let program = EpgProgram(
                channelId: normalizeChannelName(channelId),
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: desc.trimmingCharacters(in: .whitespacesAndNewlines),
                startTime: startTime,
                endTime: endTime
            )
            programs.append(program)
        }
        
        return programs
    }
    
    /// 解析 JSON 格式的 EPG
    private func parseJsonEpg(_ content: String) throws -> [EpgProgram] {
        guard let data = content.data(using: .utf8) else {
            throw EpgError.parseError("无法解码 JSON")
        }
        
        var programs: [EpgProgram] = []
        
        // 尝试不同的 JSON 结构
        if let epgDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // 格式1: { "channelId": [{ "title": "", "start": "", "end": "" }] }
            for (channelId, value) in epgDict {
                if let programsArray = value as? [[String: Any]] {
                    for programDict in programsArray {
                        if let program = parseJsonProgram(channelId: channelId, dict: programDict) {
                            programs.append(program)
                        }
                    }
                }
            }
        }
        
        return programs
    }
    
    /// 解析简单文本格式的 EPG
    private func parseTextEpg(_ content: String) throws -> [EpgProgram] {
        // 格式: 频道名称,开始时间,结束时间,节目名称
        var programs: [EpgProgram] = []
        let lines = content.components(separatedBy: .newlines)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        let today = Calendar.current.startOfDay(for: Date())
        
        for line in lines {
            let parts = line.components(separatedBy: ",")
            guard parts.count >= 4 else { continue }
            
            let channelId = parts[0].trimmingCharacters(in: .whitespaces)
            let startTimeStr = parts[1].trimmingCharacters(in: .whitespaces)
            let endTimeStr = parts[2].trimmingCharacters(in: .whitespaces)
            let title = parts[3].trimmingCharacters(in: .whitespaces)
            
            // 解析时间 (只有时分，补上今天的日期)
            guard let startTimeOfDay = timeFormatter.date(from: startTimeStr),
                  let endTimeOfDay = timeFormatter.date(from: endTimeStr) else {
                continue
            }
            
            let startComponents = Calendar.current.dateComponents([.hour, .minute], from: startTimeOfDay)
            let endComponents = Calendar.current.dateComponents([.hour, .minute], from: endTimeOfDay)
            
            guard let startTime = Calendar.current.date(byAdding: startComponents, to: today),
                  let endTime = Calendar.current.date(byAdding: endComponents, to: today) else {
                continue
            }
            
            let program = EpgProgram(
                channelId: normalizeChannelName(channelId),
                title: title,
                description: "",
                startTime: startTime,
                endTime: endTime
            )
            programs.append(program)
        }
        
        return programs
    }
    
    /// 解析 JSON 格式的单个节目
    private func parseJsonProgram(channelId: String, dict: [String: Any]) -> EpgProgram? {
        guard let title = dict["title"] as? String ?? dict["name"] as? String else {
            return nil
        }
        
        let description = dict["desc"] as? String ?? dict["description"] as? String ?? ""
        
        // 尝试不同的时间字段和格式
        let startTimeValue = dict["start"] ?? dict["startTime"] ?? dict["start_time"]
        let endTimeValue = dict["end"] ?? dict["endTime"] ?? dict["end_time"] ?? dict["stop"]
        
        guard let startTime = parseTime(startTimeValue),
              let endTime = parseTime(endTimeValue) else {
            return nil
        }
        
        return EpgProgram(
            channelId: normalizeChannelName(channelId),
            title: title,
            description: description,
            startTime: startTime,
            endTime: endTime
        )
    }
    
    /// 解析时间
    private func parseTime(_ value: Any?) -> Date? {
        if let timestamp = value as? TimeInterval {
            return Date(timeIntervalSince1970: timestamp)
        } else if let timestampInt = value as? Int {
            return Date(timeIntervalSince1970: TimeInterval(timestampInt))
        } else if let timeString = value as? String {
            let formatters = [
                "yyyy-MM-dd HH:mm:ss",
                "yyyy-MM-dd HH:mm",
                "yyyyMMddHHmmss",
                "HH:mm:ss",
                "HH:mm"
            ]
            
            for format in formatters {
                let formatter = DateFormatter()
                formatter.dateFormat = format
                if let date = formatter.date(from: timeString) {
                    // 如果只有时间，补上今天的日期
                    if format.hasPrefix("HH") {
                        let today = Calendar.current.startOfDay(for: Date())
                        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
                        return Calendar.current.date(byAdding: components, to: today)
                    }
                    return date
                }
            }
        }
        return nil
    }
    
    /// 标准化频道名称 (用于匹配)
    private func normalizeChannelName(_ name: String) -> String {
        return name
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "高清", with: "")
            .replacingOccurrences(of: "hd", with: "")
            .replacingOccurrences(of: "标清", with: "")
            .replacingOccurrences(of: "sd", with: "")
    }
}

// MARK: - EPG 数据模型

/// EPG 节目信息
struct EpgProgram: Identifiable {
    var id: String { "\(channelId)_\(startTime.timeIntervalSince1970)" }
    
    let channelId: String
    let title: String
    let description: String
    let startTime: Date
    let endTime: Date
    
    /// 节目时长 (分钟)
    var duration: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }
    
    /// 是否正在播出
    var isLive: Bool {
        let now = Date()
        return startTime <= now && endTime > now
    }
    
    /// 播出进度 (0.0 - 1.0)
    var progress: Double {
        guard isLive else { return 0 }
        let now = Date()
        let total = endTime.timeIntervalSince(startTime)
        let elapsed = now.timeIntervalSince(startTime)
        return min(1.0, max(0.0, elapsed / total))
    }
    
    /// 格式化的时间范围
    var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
}

/// EPG 错误
enum EpgError: LocalizedError {
    case invalidUrl
    case parseError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "无效的 EPG 地址"
        case .parseError(let message):
            return "EPG 解析错误: \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}

