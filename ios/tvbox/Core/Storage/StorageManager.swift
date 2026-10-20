import Foundation

/// 本地存储管理器 - 对应 Android 的 Room 数据库功能
class StorageManager {
    static let shared = StorageManager()
    
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    
    // MARK: - Keys
    private enum Keys {
        static let apiHistory = "api_history"
        static let searchHistory = "search_history"
        static let vodHistory = "vod_history"
        static let vodCollect = "vod_collect"
        static let playProgress = "play_progress"
        static let playerConfig = "player_config"
        static let subtitleFile = "subtitle_file"
    }
    
    private init() {}
    
    // MARK: - Documents Directory
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - API History

    func getApiHistory() -> [String] {
        return userDefaults.stringArray(forKey: Keys.apiHistory) ?? []
    }

    func addApiHistory(_ url: String) {
        let trimmedUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUrl.isEmpty else { return }

        var history = getApiHistory()
        history.removeAll { $0 == trimmedUrl }
        history.insert(trimmedUrl, at: 0)

        if history.count > 20 {
            history = Array(history.prefix(20))
        }

        saveApiHistory(history)
    }

    func removeApiHistory(_ url: String) {
        var history = getApiHistory()
        history.removeAll { $0 == url }
        saveApiHistory(history)
    }

    func clearApiHistory() {
        userDefaults.removeObject(forKey: Keys.apiHistory)
    }

    private func saveApiHistory(_ history: [String]) {
        userDefaults.set(history, forKey: Keys.apiHistory)
    }
    
    // MARK: - Search History
    
    func getSearchHistory() -> [String] {
        return userDefaults.stringArray(forKey: Keys.searchHistory) ?? []
    }
    
    func saveSearchHistory(_ history: [String]) {
        userDefaults.set(history, forKey: Keys.searchHistory)
    }
    
    func clearSearchHistory() {
        userDefaults.removeObject(forKey: Keys.searchHistory)
    }
    
    // MARK: - Watch History
    
    struct VodHistoryItem: Codable, Identifiable {
        var id: String { "\(siteKey)_\(vodId)" }
        
        let vodId: String
        let vodName: String
        let vodPic: String?
        let siteKey: String
        let playIndex: Int // 播放源索引
        let episodeIndex: Int // 剧集索引
        let episodeName: String? // 剧集名称，对应 Android 的 playNote
        let progress: Double // 播放进度 (秒)
        let duration: Double // 总时长 (秒)
        let updateTime: Date
        /// 播放源名称和该播放源的剧集，用于从历史直接播放，不用再加载详情。旧记录没有这两项
        var playFlag: String?
        var episodes: [VodInfo.VodPlayItem]?
    }
    
    func getVodHistory() -> [VodHistoryItem] {
        guard let data = userDefaults.data(forKey: Keys.vodHistory) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([VodHistoryItem].self, from: data)
        } catch {
            AppLogger.debug("Failed to decode vod history: \(error)")
            return []
        }
    }
    
    func addVodHistory(_ item: VodHistoryItem) {
        var history = getVodHistory()
        
        // 移除已存在的相同记录
        history.removeAll { $0.vodId == item.vodId && $0.siteKey == item.siteKey }
        
        // 添加到开头
        history.insert(item, at: 0)
        
        // 限制历史记录数量
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
        
        saveVodHistory(history)
    }
    
    func updateVodHistory(vodId: String, siteKey: String, progress: Double, episodeIndex: Int) {
        var history = getVodHistory()
        
        if let index = history.firstIndex(where: { $0.vodId == vodId && $0.siteKey == siteKey }) {
            var item = history[index]
            item = VodHistoryItem(
                vodId: item.vodId,
                vodName: item.vodName,
                vodPic: item.vodPic,
                siteKey: item.siteKey,
                playIndex: item.playIndex,
                episodeIndex: episodeIndex,
                episodeName: item.episodeName,
                progress: progress,
                duration: item.duration,
                updateTime: Date()
            )
            history.remove(at: index)
            history.insert(item, at: 0)
            saveVodHistory(history)
        }
    }
    
    func removeVodHistory(vodId: String, siteKey: String) {
        var history = getVodHistory()
        history.removeAll { $0.vodId == vodId && $0.siteKey == siteKey }
        saveVodHistory(history)
    }
    
    func clearVodHistory() {
        userDefaults.removeObject(forKey: Keys.vodHistory)
    }
    
    /// 添加播放历史 (从 VodInfo)
    @discardableResult
    func addHistory(vodInfo: VodInfo, site: SiteBean, sourceIndex: Int, episodeIndex: Int, episodeName: String?, progress: Double, duration: Double) -> VodHistoryItem {
        let item = VodHistoryItem(
            vodId: vodInfo.vodId,
            vodName: vodInfo.vodName,
            vodPic: vodInfo.vodPic,
            siteKey: site.key,
            playIndex: sourceIndex,
            episodeIndex: episodeIndex,
            episodeName: episodeName,
            progress: progress,
            duration: duration,
            updateTime: Date(),
            playFlag: vodInfo.playFlags.indices.contains(sourceIndex) ? vodInfo.playFlags[sourceIndex] : nil,
            episodes: vodInfo.playUrls.indices.contains(sourceIndex) ? vodInfo.playUrls[sourceIndex] : nil
        )

        addVodHistory(item)
        return item
    }

    /// 从历史直接播放时更新进度，播放源和剧集沿用原记录
    func updateHistory(_ item: VodHistoryItem, episodeIndex: Int, progress: Double, duration: Double) {
        let episodeName = item.episodes.flatMap { $0.indices.contains(episodeIndex) ? $0[episodeIndex].name : nil }
        addVodHistory(VodHistoryItem(
            vodId: item.vodId,
            vodName: item.vodName,
            vodPic: item.vodPic,
            siteKey: item.siteKey,
            playIndex: item.playIndex,
            episodeIndex: episodeIndex,
            episodeName: episodeName,
            progress: progress,
            duration: duration,
            updateTime: Date(),
            playFlag: item.playFlag,
            episodes: item.episodes
        ))
    }
    
    private func saveVodHistory(_ history: [VodHistoryItem]) {
        do {
            let data = try JSONEncoder().encode(history)
            userDefaults.set(data, forKey: Keys.vodHistory)
        } catch {
            AppLogger.debug("Failed to encode vod history: \(error)")
        }
    }
    
    // MARK: - Collect (Favorites)
    
    struct VodCollectItem: Codable, Identifiable {
        var id: String { "\(siteKey)_\(vodId)" }
        
        let vodId: String
        let vodName: String
        let vodPic: String?
        let vodRemarks: String?
        let siteKey: String
        let siteName: String
        let createTime: Date
    }
    
    func getCollects() -> [VodCollectItem] {
        guard let data = userDefaults.data(forKey: Keys.vodCollect) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([VodCollectItem].self, from: data)
        } catch {
            AppLogger.debug("Failed to decode collects: \(error)")
            return []
        }
    }
    
    func addCollect(vodInfo: VodInfo, site: SiteBean) {
        let item = VodCollectItem(
            vodId: vodInfo.vodId,
            vodName: vodInfo.vodName,
            vodPic: vodInfo.vodPic,
            vodRemarks: vodInfo.vodRemarks,
            siteKey: site.key,
            siteName: site.name,
            createTime: Date()
        )
        
        var collects = getCollects()
        
        // 检查是否已存在
        if collects.contains(where: { $0.vodId == item.vodId && $0.siteKey == item.siteKey }) {
            return
        }
        
        collects.insert(item, at: 0)
        saveCollects(collects)
    }
    
    func removeCollect(vodId: String, siteKey: String) {
        var collects = getCollects()
        collects.removeAll { $0.vodId == vodId && $0.siteKey == siteKey }
        saveCollects(collects)
    }
    
    func isCollected(vodId: String, siteKey: String) -> Bool {
        let collects = getCollects()
        return collects.contains { $0.vodId == vodId && $0.siteKey == siteKey }
    }
    
    func clearCollects() {
        userDefaults.removeObject(forKey: Keys.vodCollect)
    }
    
    private func saveCollects(_ collects: [VodCollectItem]) {
        do {
            let data = try JSONEncoder().encode(collects)
            userDefaults.set(data, forKey: Keys.vodCollect)
        } catch {
            AppLogger.debug("Failed to encode collects: \(error)")
        }
    }
    
    // MARK: - Play Progress
    
    struct PlayProgressItem: Codable {
        let vodId: String
        let siteKey: String
        let flag: String // 播放源
        let episodeIndex: Int
        let episodeName: String
        let progress: Double // 播放位置 (秒)
        let duration: Double // 总时长 (秒)
    }
    
    /// 每一集单独记录进度，和 Android 的 progressKey 一样由站点、视频、播放源、剧集组成
    private func playProgressKey(vodId: String, siteKey: String, flag: String, episodeIndex: Int, episodeName: String) -> String {
        "\(Keys.playProgress)_\(siteKey)_\(vodId)_\(flag)_\(episodeIndex)_\(episodeName)"
    }
    
    func getPlayProgress(vodId: String, siteKey: String, flag: String, episodeIndex: Int, episodeName: String) -> PlayProgressItem? {
        let key = playProgressKey(vodId: vodId, siteKey: siteKey, flag: flag, episodeIndex: episodeIndex, episodeName: episodeName)
        
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(PlayProgressItem.self, from: data)
        } catch {
            return nil
        }
    }
    
    func savePlayProgress(_ item: PlayProgressItem) {
        let key = playProgressKey(vodId: item.vodId, siteKey: item.siteKey, flag: item.flag, episodeIndex: item.episodeIndex, episodeName: item.episodeName)
        
        do {
            let data = try JSONEncoder().encode(item)
            userDefaults.set(data, forKey: key)
        } catch {
            AppLogger.debug("Failed to encode play progress: \(error)")
        }
    }

    // MARK: - Player Config

    /// 每部剧单独保存的播放设置，对应 Android 的 VodInfo.playerCfg
    struct VodPlayerConfig: Codable, Equatable {
        /// 画面比例，对应 sc
        var scale = 0
        /// 倍速，对应 sp
        var speed: Float = 1
        /// 片头时长 (秒)，对应 st
        var openingTime: Double = 0
        /// 片尾时长 (秒)，对应 et
        var endingTime: Double = 0
    }

    /// key 由站点和视频组成，和历史记录的 id 一样
    func getPlayerConfig(key: String) -> VodPlayerConfig {
        guard let data = userDefaults.data(forKey: "\(Keys.playerConfig)_\(key)"),
              let config = try? JSONDecoder().decode(VodPlayerConfig.self, from: data) else {
            return VodPlayerConfig()
        }
        return config
    }

    func savePlayerConfig(_ config: VodPlayerConfig, key: String) {
        do {
            let data = try JSONEncoder().encode(config)
            userDefaults.set(data, forKey: "\(Keys.playerConfig)_\(key)")
        } catch {
            AppLogger.debug("Failed to encode player config: \(error)")
        }
    }

    // MARK: - Subtitle

    /// 手动选择的字幕文件放在这里，只记文件名，因为 App 目录的绝对路径会变
    var subtitleDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("subtitles", isDirectory: true)
    }

    /// 每集手动选择的字幕文件名，对应 Android 的 subtitleCacheKey
    func getSubtitleFile(key: String) -> String? {
        userDefaults.string(forKey: "\(Keys.subtitleFile)_\(key)")
    }

    func saveSubtitleFile(_ name: String?, key: String) {
        userDefaults.set(name, forKey: "\(Keys.subtitleFile)_\(key)")
    }
}
