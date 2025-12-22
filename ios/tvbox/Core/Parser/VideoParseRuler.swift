import Foundation

/// 视频解析规则管理器 - 对应 Android 的 VideoParseRuler.java
/// 用于管理自定义的视频嗅探规则
class VideoParseRuler {
    static let shared = VideoParseRuler()
    
    /// 自定义规则 (host -> [[rule1, rule2], [rule3]])
    /// 每个内部数组是一组规则，全部匹配才算匹配
    private var hostsRule: [String: [[String]]] = [:]
    
    /// 过滤规则 (host -> [[filter1], [filter2]])
    private var hostsFilter: [String: [[String]]] = [:]
    
    /// 正则规则 (host -> [regex1, regex2])
    private var hostsRegex: [String: [String]] = [:]
    
    /// 自定义脚本 (host -> [script])
    private var hostsScript: [String: [String]] = [:]
    
    private init() {}
    
    // MARK: - Rule Management
    
    /// 清除所有规则
    func clearRules() {
        hostsRule.removeAll()
        hostsFilter.removeAll()
        hostsRegex.removeAll()
        hostsScript.removeAll()
    }
    
    /// 添加匹配规则
    func addHostRule(host: String, rule: [String]) {
        guard !rule.isEmpty else { return }
        
        if hostsRule[host] == nil {
            hostsRule[host] = []
        }
        hostsRule[host]?.append(rule)
    }
    
    /// 添加过滤规则
    func addHostFilter(host: String, filter: [String]) {
        guard !filter.isEmpty else { return }
        
        if hostsFilter[host] == nil {
            hostsFilter[host] = []
        }
        hostsFilter[host]?.append(filter)
    }
    
    /// 添加正则规则
    func addHostRegex(host: String, regex: [String]) {
        guard !regex.isEmpty else { return }
        
        if hostsRegex[host] == nil {
            hostsRegex[host] = []
        }
        hostsRegex[host]?.append(contentsOf: regex)
    }
    
    /// 添加脚本
    func addHostScript(host: String, script: [String]) {
        guard !script.isEmpty else { return }
        
        if hostsScript[host] == nil {
            hostsScript[host] = []
        }
        hostsScript[host]?.append(contentsOf: script)
    }
    
    // MARK: - Checking
    
    /// 检查 URL 是否是视频 (根据自定义规则)
    /// - Parameters:
    ///   - webUrl: 原始网页 URL
    ///   - url: 要检查的 URL
    /// - Returns: 是否是视频
    func checkIsVideoForParse(webUrl: String?, url: String) -> Bool {
        // 先用默认规则检查
        let isVideo = VideoSniffer.shared.isVideoUrl(url)
        
        // 如果没有自定义规则或默认已匹配，直接返回
        guard !hostsRule.isEmpty, !isVideo, let webUrl = webUrl else {
            return isVideo
        }
        
        // 提取 host
        guard let webHost = URL(string: webUrl)?.host else {
            return isVideo
        }
        
        // 检查特定 host 的规则
        if let rules = hostsRule[webHost] {
            if checkVideoForHostRules(rules: rules, url: url) {
                return true
            }
        }
        
        // 检查通配规则
        if let wildcardRules = hostsRule["*"] {
            if checkVideoForHostRules(rules: wildcardRules, url: url) {
                return true
            }
        }
        
        return false
    }
    
    /// 检查 URL 是否应该被过滤
    func isFilter(webUrl: String?, url: String) -> Bool {
        guard !hostsFilter.isEmpty, let webUrl = webUrl else {
            return false
        }
        
        guard let webHost = URL(string: webUrl)?.host else {
            return false
        }
        
        guard let filters = hostsFilter[webHost] else {
            return false
        }
        
        return checkFilterForHostRules(rules: filters, url: url)
    }
    
    /// 获取 host 对应的脚本
    func getHostScript(url: String) -> String? {
        for (host, scripts) in hostsScript {
            if url.contains(host), let script = scripts.first {
                return script
            }
        }
        return nil
    }
    
    /// 获取正则规则
    func getHostsRegex() -> [String: [String]] {
        return hostsRegex
    }
    
    // MARK: - Private Methods
    
    /// 检查 URL 是否匹配规则组
    private func checkVideoForHostRules(rules: [[String]], url: String) -> Bool {
        for ruleGroup in rules {
            var allMatch = true
            for pattern in ruleGroup {
                if !matchPattern(pattern: pattern, url: url) {
                    allMatch = false
                    break
                }
            }
            if allMatch && !ruleGroup.isEmpty {
                return true
            }
        }
        return false
    }
    
    /// 检查 URL 是否匹配过滤规则
    private func checkFilterForHostRules(rules: [[String]], url: String) -> Bool {
        for ruleGroup in rules {
            var allMatch = true
            for pattern in ruleGroup {
                if !matchPattern(pattern: pattern, url: url) {
                    allMatch = false
                    break
                }
            }
            if allMatch && !ruleGroup.isEmpty {
                return true
            }
        }
        return false
    }
    
    /// 匹配正则模式
    private func matchPattern(pattern: String, url: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(url.startIndex..., in: url)
            return regex.firstMatch(in: url, options: [], range: range) != nil
        } catch {
            // 如果不是有效正则，尝试简单包含匹配
            return url.lowercased().contains(pattern.lowercased())
        }
    }
}

// MARK: - Parse Rule Configuration

extension VideoParseRuler {
    
    /// 从配置加载规则
    /// - Parameter config: 配置 JSON
    func loadFromConfig(_ config: [String: Any]) {
        // 加载规则
        if let rules = config["rules"] as? [String: [[String]]] {
            for (host, ruleGroups) in rules {
                for rule in ruleGroups {
                    addHostRule(host: host, rule: rule)
                }
            }
        }
        
        // 加载过滤规则
        if let filters = config["filter"] as? [String: [[String]]] {
            for (host, filterGroups) in filters {
                for filter in filterGroups {
                    addHostFilter(host: host, filter: filter)
                }
            }
        }
        
        // 加载正则
        if let regexes = config["regex"] as? [String: [String]] {
            for (host, patterns) in regexes {
                addHostRegex(host: host, regex: patterns)
            }
        }
        
        // 加载脚本
        if let scripts = config["script"] as? [String: [String]] {
            for (host, scriptList) in scripts {
                addHostScript(host: host, script: scriptList)
            }
        }
    }
}

