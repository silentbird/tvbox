import Foundation

/// 按关键词并发搜索多个站点，快速搜索、TMDB 搜索页和 TMDB 详情页共用。
/// 同一站点同一关键词 10 分钟内只搜一次，搜索页搜过的词进详情页不用再搜
enum SiteSearcher {
    /// 同时搜索的站点数，对应 Android SEARCH_THREAD_COUNT
    static let concurrentSiteCount = 6
    /// 单站点超时，对应 Android SEARCH_SITE_TIMEOUT_SECONDS
    static let siteTimeoutSeconds: UInt64 = 15

    private static let cache = SearchCache()

    /// 可搜索的站点，和 Android 一样把当前站点排在最前面
    @MainActor
    static var sites: [SiteBean] {
        let apiConfig = ApiConfig.shared
        var sites = apiConfig.searchableSites
        if let homeKey = apiConfig.currentSite?.key, let index = sites.firstIndex(where: { $0.key == homeKey }) {
            sites.insert(sites.remove(at: index), at: 0)
        }
        return sites
    }

    /// 每搜完一个站点给出一次结果，没结果的站点给空数组；结果都带上来源站点 key
    static func searchAll(keyword: String, sites: [SiteBean]) -> AsyncStream<(SiteBean, [MovieItem])> {
        AsyncStream { continuation in
            let task = Task {
                await withTaskGroup(of: (SiteBean, [MovieItem]).self) { group in
                    var pending = sites[...]
                    for _ in 0..<concurrentSiteCount {
                        guard let site = pending.popFirst() else { break }
                        group.addTask { (site, await search(site: site, keyword: keyword)) }
                    }
                    for await result in group {
                        continuation.yield(result)
                        if let site = pending.popFirst(), !Task.isCancelled {
                            group.addTask { (site, await search(site: site, keyword: keyword)) }
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// 搜索单个站点，失败或超时返回空结果
    static func search(site: SiteBean, keyword: String) async -> [MovieItem] {
        let key = "\(site.key)|\(keyword)"
        if let cached = await cache.get(key) { return cached }

        let items = await withTimeout(seconds: siteTimeoutSeconds) {
            do {
                let spider = try await SpiderManager.shared.getSpider(for: site)
                return try await spider.searchContent(keyword: keyword, quick: false, page: 1)
            } catch {
                AppLogger.debug("[SiteSearcher] \(site.name) 搜索失败: \(error)")
                return []
            }
        }
        guard let items else {
            AppLogger.debug("[SiteSearcher] \(site.name) 搜索超时")
            return []
        }
        let tagged = items.map { item -> MovieItem in
            var item = item
            item.sourceKey = site.key
            return item
        }
        // 超时、出错不缓存，下次还能再试
        if !tagged.isEmpty { await cache.set(key, tagged) }
        return tagged
    }

    /// 超时返回 nil
    static func withTimeout<T: Sendable>(seconds: UInt64, _ operation: @escaping @Sendable () async -> T) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private actor SearchCache {
        private static let ttl: TimeInterval = 10 * 60
        private var entries: [String: (date: Date, items: [MovieItem])] = [:]

        func get(_ key: String) -> [MovieItem]? {
            guard let entry = entries[key], Date().timeIntervalSince(entry.date) < Self.ttl else { return nil }
            return entry.items
        }

        func set(_ key: String, _ items: [MovieItem]) {
            entries[key] = (Date(), items)
        }
    }
}
