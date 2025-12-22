import Foundation

/// 视频嗅探工具 - 对应 Android 的 DefaultConfig.isVideoFormat 和 VideoParseRuler
class VideoSniffer {
    static let shared = VideoSniffer()
    
    // MARK: - 视频格式匹配正则
    
    /// 视频格式正则 - 匹配常见视频链接
    private let videoFormatPattern: NSRegularExpression? = {
        let pattern = """
        http((?!http).)*?(\\.m3u8|\\.mp4|\\.flv|\\.avi|\\.mkv|\\.rm|\\.wmv|\\.mpg|\\.m4a|\\.mp3\
        |\\.ts|\\.ts\\?|\\.mp4\\?|\\.m3u8\\?|/m3u8\\?|/index\\.m3u8|/index\\.mp4|\\.m3u8&|/video\\/tos\\/)\
        |http((?!http).)*?video/tos/|http.*?/download.aspx\\?.*|http.*?/api/up_api.php\\?.*\
        |https.*?\\.66yk\\.cn.*|http((?!http).)*?netease\\.com/file/.*
        """
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()
    
    /// 常见视频扩展名
    private let videoExtensions = Set([
        ".m3u8", ".mp4", ".flv", ".avi", ".mkv", ".rm", ".wmv", ".mpg",
        ".mpeg", ".m4v", ".3gp", ".webm", ".ts", ".mov"
    ])
    
    /// 排除的扩展名/关键字
    private let excludeKeywords = [
        ".js", ".css", ".jpg", ".png", ".gif", ".ico", ".html", ".htm",
        ".woff", ".woff2", ".ttf", ".svg", ".json", "rl=", "url=http"
    ]
    
    /// VIP 视频网站
    private let vipHosts = [
        "iqiyi.com", "v.qq.com", "youku.com", "le.com", "tudou.com",
        "mgtv.com", "sohu.com", "acfun.cn", "bilibili.com", "baofeng.com", "pptv.com"
    ]
    
    /// 黑名单 URL 关键字
    private let blacklistKeywords = [
        "google", "facebook", "analytics", "cnzz", "baidu.com/s",
        "umeng", "beacon", "adservice", "doubleclick"
    ]
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 检查 URL 是否是视频链接
    /// - Parameters:
    ///   - url: 要检查的 URL
    ///   - webUrl: 原始网页 URL (可选，用于自定义规则)
    /// - Returns: 是否是视频链接
    func isVideoUrl(_ url: String, webUrl: String? = nil) -> Bool {
        // 排除包含特定关键字的链接
        for keyword in excludeKeywords {
            if url.lowercased().contains(keyword) {
                return false
            }
        }
        
        // 排除黑名单
        for keyword in blacklistKeywords {
            if url.lowercased().contains(keyword) {
                return false
            }
        }
        
        // 检查扩展名
        let lowercasedUrl = url.lowercased()
        for ext in videoExtensions {
            if lowercasedUrl.contains(ext) {
                return true
            }
        }
        
        // 使用正则匹配
        if let pattern = videoFormatPattern {
            let range = NSRange(url.startIndex..., in: url)
            if pattern.firstMatch(in: url, options: [], range: range) != nil {
                return true
            }
        }
        
        // 检查特殊视频 URL 模式
        if isSpecialVideoUrl(url) {
            return true
        }
        
        // 检查自定义规则
        if let webUrl = webUrl {
            if VideoParseRuler.shared.checkIsVideoForParse(webUrl: webUrl, url: url) {
                return true
            }
        }
        
        return false
    }
    
    /// 检查是否是 VIP 视频网站
    /// - Parameter url: URL
    /// - Returns: 是否是 VIP 网站
    func isVipUrl(_ url: String) -> Bool {
        let lowercasedUrl = url.lowercased()
        for host in vipHosts {
            if lowercasedUrl.contains(host) {
                return true
            }
        }
        return false
    }
    
    /// 检查是否应该过滤该 URL
    /// - Parameters:
    ///   - url: URL
    ///   - webUrl: 原始网页 URL (可选)
    /// - Returns: 是否应该过滤
    func shouldFilter(_ url: String, webUrl: String? = nil) -> Bool {
        let lowercasedUrl = url.lowercased()
        
        // 过滤广告和统计链接
        for keyword in blacklistKeywords {
            if lowercasedUrl.contains(keyword) {
                return true
            }
        }
        
        // 检查自定义过滤规则
        if VideoParseRuler.shared.isFilter(webUrl: webUrl, url: url) {
            return true
        }
        
        return false
    }
    
    /// 从 URL 提取视频格式
    /// - Parameter url: 视频 URL
    /// - Returns: 视频格式 (如 m3u8, mp4)
    func getVideoFormat(_ url: String) -> String? {
        let lowercasedUrl = url.lowercased()
        
        // 检查常见格式
        if lowercasedUrl.contains(".m3u8") || lowercasedUrl.contains("/m3u8") {
            return "m3u8"
        }
        if lowercasedUrl.contains(".mp4") {
            return "mp4"
        }
        if lowercasedUrl.contains(".flv") {
            return "flv"
        }
        if lowercasedUrl.contains(".ts") {
            return "ts"
        }
        
        // 检查 URL 路径中的格式
        if let urlObj = URL(string: url) {
            let ext = urlObj.pathExtension.lowercased()
            if !ext.isEmpty && videoExtensions.contains(".\(ext)") {
                return ext
            }
        }
        
        return nil
    }
    
    // MARK: - Private Methods
    
    /// 检查特殊视频 URL 模式
    private func isSpecialVideoUrl(_ url: String) -> Bool {
        let patterns = [
            "video/tos",           // 抖音等
            "/video/",             // 通用视频路径
            "/stream/",            // 流媒体
            "/playlist.m3u8",      // HLS 播放列表
            "/index.m3u8",         // HLS 索引
            "/manifest",           // DASH 清单
            "mime=video",          // 视频 MIME 类型
            "type=video",
            "videoplayback",       // YouTube
            "/play/",
            "/vod/",
            "/live/"
        ]
        
        let lowercasedUrl = url.lowercased()
        for pattern in patterns {
            if lowercasedUrl.contains(pattern) {
                return true
            }
        }
        
        return false
    }
}

