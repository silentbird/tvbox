import Foundation

/// 本地存储管理器 - 对应 Android 的 Room 数据库功能
class StorageManager {
    static let shared = StorageManager()
    
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    
    // MARK: - Keys
    private enum Keys {
        static let searchHistory = "search_history"
        static let vodHistory = "vod_history"
        static let vodCollect = "vod_collect"
        static let playProgress = "play_progress"
    }
    
    private init() {}
    
    // MARK: - Documents Directory
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
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
    
    struct VodHistoryItem: Codable {
        let vodId: String
        let vodName: String
        let vodPic: String?
        let siteKey: String
        let playIndex: Int // 播放源索引
        let episodeIndex: Int // 剧集索引
        let progress: Double // 播放进度 (秒)
        let duration: Double // 总时长 (秒)
        let updateTime: Date
    }
    
    func getVodHistory() -> [VodHistoryItem] {
        guard let data = userDefaults.data(forKey: Keys.vodHistory) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([VodHistoryItem].self, from: data)
        } catch {
            print("Failed to decode vod history: \(error)")
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
    func addHistory(vodInfo: VodInfo, sourceIndex: Int, episodeIndex: Int, progress: Double) {
        guard let currentSite = ApiConfig.shared.currentSite else { return }
        
        let item = VodHistoryItem(
            vodId: vodInfo.vodId,
            vodName: vodInfo.vodName,
            vodPic: vodInfo.vodPic,
            siteKey: currentSite.key,
            playIndex: sourceIndex,
            episodeIndex: episodeIndex,
            progress: progress,
            duration: 0,
            updateTime: Date()
        )
        
        addVodHistory(item)
    }
    
    private func saveVodHistory(_ history: [VodHistoryItem]) {
        do {
            let data = try JSONEncoder().encode(history)
            userDefaults.set(data, forKey: Keys.vodHistory)
        } catch {
            print("Failed to encode vod history: \(error)")
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
            print("Failed to decode collects: \(error)")
            return []
        }
    }
    
    func addCollect(vodInfo: VodInfo) {
        guard let currentSite = ApiConfig.shared.currentSite else { return }
        
        let item = VodCollectItem(
            vodId: vodInfo.vodId,
            vodName: vodInfo.vodName,
            vodPic: vodInfo.vodPic,
            vodRemarks: vodInfo.vodRemarks,
            siteKey: currentSite.key,
            siteName: currentSite.name,
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
    
    func removeCollect(vodId: String) {
        guard let currentSite = ApiConfig.shared.currentSite else { return }
        
        var collects = getCollects()
        collects.removeAll { $0.vodId == vodId && $0.siteKey == currentSite.key }
        saveCollects(collects)
    }
    
    func isCollected(vodId: String) -> Bool {
        guard let currentSite = ApiConfig.shared.currentSite else { return false }
        
        let collects = getCollects()
        return collects.contains { $0.vodId == vodId && $0.siteKey == currentSite.key }
    }
    
    func clearCollects() {
        userDefaults.removeObject(forKey: Keys.vodCollect)
    }
    
    private func saveCollects(_ collects: [VodCollectItem]) {
        do {
            let data = try JSONEncoder().encode(collects)
            userDefaults.set(data, forKey: Keys.vodCollect)
        } catch {
            print("Failed to encode collects: \(error)")
        }
    }
    
    // MARK: - Play Progress
    
    struct PlayProgressItem: Codable {
        let vodId: String
        let siteKey: String
        let episodeIndex: Int
        let progress: Double // 播放位置 (秒)
        let duration: Double // 总时长 (秒)
    }
    
    func getPlayProgress(vodId: String, siteKey: String, episodeIndex: Int) -> PlayProgressItem? {
        let key = "\(Keys.playProgress)_\(siteKey)_\(vodId)_\(episodeIndex)"
        
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
        let key = "\(Keys.playProgress)_\(item.siteKey)_\(item.vodId)_\(item.episodeIndex)"
        
        do {
            let data = try JSONEncoder().encode(item)
            userDefaults.set(data, forKey: key)
        } catch {
            print("Failed to encode play progress: \(error)")
        }
    }
}

