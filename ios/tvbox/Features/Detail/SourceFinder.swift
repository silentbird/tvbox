import Foundation

/// TMDB 详情页的一个播放来源：某个站点上的这部影片
struct VodSource: Identifiable {
    var id: String { "\(site.key)|\(vodInfo.vodId)" }
    let site: SiteBean
    let vodInfo: VodInfo
    let match: SourceMatcher.Match
}

/// 在各站点查找一部 TMDB 作品的资源：搜片名，片名对上的再拉站点详情，按集数复查
enum SourceFinder {
    /// 同时拉取的站点详情数
    static let concurrentDetailCount = 4

    enum Event {
        /// 搜完了几个站点
        case progress(finished: Int, total: Int)
        /// 站点搜到、片名对得上这部作品任一季的影片，保存下来切季时用
        case hit(MovieItem)
        /// 开始、拉完一个站点详情
        case detailStarted
        case detailFinished
        case found(VodSource)
    }

    /// - Parameters:
    ///   - trusted: 上次播放的影片，不比片名直接拉详情
    ///   - candidates: 搜索页已经搜到的影片，和搜索结果一样比过片名再拉详情
    ///   - sites: 要搜索的站点，为空时只拉 trusted 和 candidates 的详情
    static func find(
        keyword: String,
        trusted: [(MovieItem, SiteBean)],
        candidates: [(MovieItem, SiteBean)],
        target: SourceMatcher.Target,
        sites: [SiteBean]
    ) -> AsyncStream<Event> {
        AsyncStream { continuation in
            let task = Task {
                let limiter = Limiter(count: concurrentDetailCount)
                var requested = Set<String>()

                /// 同一部影片只拉一次详情，返回拉详情的任务
                func fetch(_ item: MovieItem, site: SiteBean, match: SourceMatcher.Match) -> (@Sendable () async -> Void)? {
                    guard requested.insert("\(site.key)|\(item.vodId)").inserted else { return nil }
                    continuation.yield(.detailStarted)
                    return {
                        await limiter.acquire()
                        let source = Task.isCancelled ? nil : await loadSource(item, site: site, match: match, target: target)
                        await limiter.release()
                        if let source { continuation.yield(.found(source)) }
                        continuation.yield(.detailFinished)
                    }
                }
                var anySeason = target
                anySeason.season = nil

                await withTaskGroup(of: Void.self) { group in
                    for (item, site) in trusted {
                        guard let operation = fetch(item, site: site, match: SourceMatcher.Match(confidence: .sure, reason: nil)) else { continue }
                        group.addTask(operation: operation)
                    }
                    for (item, site) in candidates {
                        guard let match = SourceMatcher.match(name: item.vodName, year: item.vodYear, target: target),
                              let operation = fetch(item, site: site, match: match) else { continue }
                        group.addTask(operation: operation)
                    }

                    guard !sites.isEmpty else { return }
                    var finished = 0
                    continuation.yield(.progress(finished: 0, total: sites.count))
                    for await (site, items) in SiteSearcher.searchAll(keyword: keyword, sites: sites) {
                        finished += 1
                        continuation.yield(.progress(finished: finished, total: sites.count))
                        for item in items {
                            if SourceMatcher.match(name: item.vodName, year: item.vodYear, target: anySeason) != nil {
                                continuation.yield(.hit(item))
                            }
                            guard let match = SourceMatcher.match(name: item.vodName, year: item.vodYear, target: target),
                                  let operation = fetch(item, site: site, match: match) else { continue }
                            group.addTask(operation: operation)
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// 拉站点详情，没有可播的线路时返回 nil
    private static func loadSource(_ item: MovieItem, site: SiteBean, match: SourceMatcher.Match, target: SourceMatcher.Target) async -> VodSource? {
        let vodInfo = await SiteSearcher.withTimeout(seconds: SiteSearcher.siteTimeoutSeconds) {
            do {
                return try await SpiderManager.shared.detailContent(site: site, ids: [item.vodId]).first
            } catch {
                AppLogger.debug("[SourceFinder] \(site.name) 详情失败: \(error)")
                return nil
            }
        } ?? nil
        guard let vodInfo, vodInfo.playUrls.contains(where: { !$0.isEmpty }) else { return nil }

        let episodeCount = vodInfo.playUrls.map(\.count).max() ?? 0
        guard let mismatch = SourceMatcher.episodeMismatch(count: episodeCount, target: target) else {
            return VodSource(site: site, vodInfo: vodInfo, match: match)
        }
        let reason = [match.reason, mismatch].compactMap { $0 }.joined(separator: " · ")
        return VodSource(site: site, vodInfo: vodInfo, match: SourceMatcher.Match(confidence: .possible, reason: reason))
    }

    /// 限制同时进行的任务数
    private actor Limiter {
        private var available: Int
        private var waiters: [CheckedContinuation<Void, Never>] = []

        init(count: Int) {
            available = count
        }

        func acquire() async {
            if available > 0 {
                available -= 1
                return
            }
            await withCheckedContinuation { waiters.append($0) }
        }

        func release() {
            if waiters.isEmpty {
                available += 1
            } else {
                waiters.removeFirst().resume()
            }
        }
    }
}
