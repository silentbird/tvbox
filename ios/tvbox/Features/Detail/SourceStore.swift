import Foundation

/// 按 TMDB 作品保存在各站点检索到的资源，重启 App 也在。
/// 不自动过期，详情页点「重新检索」或换片名搜索时才覆盖
actor SourceStore {
    static let shared = SourceStore()

    struct Entry: Codable {
        /// 检索用的片名
        var keyword: String
        /// 手动换过的片名，没换过为 nil
        var customKeyword: String?
        /// 上次检索的时间
        var date: Date
        /// 检索了几个站点
        var siteCount: Int
        /// 站点搜到、片名对得上这部作品的影片（各季都有），切到没看过的季时从这里找
        var hits: [Hit]
        /// 季 → 找到的来源，电影用 0
        var seasons: [Int: [Source]]
    }

    struct Hit: Codable {
        let siteKey: String
        let vodId: String
        let vodName: String
        let vodYear: String?

        init(_ item: MovieItem) {
            siteKey = item.sourceKey ?? ""
            vodId = item.vodId
            vodName = item.vodName
            vodYear = item.vodYear
        }

        var movie: MovieItem {
            MovieItem(vodId: vodId, vodName: vodName, vodYear: vodYear, sourceKey: siteKey)
        }
    }

    struct Source: Codable {
        let siteKey: String
        let vodInfo: VodInfo
        let confidence: SourceMatcher.Confidence
        let reason: String?

        init(_ source: VodSource) {
            siteKey = source.site.key
            vodInfo = source.vodInfo
            confidence = source.match.confidence
            reason = source.match.reason
        }

        /// 站点已经不在配置里时返回 nil
        func restore(sites: [SiteBean]) -> VodSource? {
            guard let site = sites.first(where: { $0.key == siteKey }) else { return nil }
            return VodSource(site: site, vodInfo: vodInfo, match: SourceMatcher.Match(confidence: confidence, reason: reason))
        }
    }

    private var memoryCache: [String: Entry] = [:]

    private var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sources", isDirectory: true)
    }

    func entry(for ref: TMDBRef) -> Entry? {
        let key = Self.key(ref)
        if let entry = memoryCache[key] { return entry }
        guard let data = try? Data(contentsOf: file(key)),
              let entry = try? JSONDecoder().decode(Entry.self, from: data) else { return nil }
        memoryCache[key] = entry
        return entry
    }

    func save(_ entry: Entry, for ref: TMDBRef) {
        let key = Self.key(ref)
        memoryCache[key] = entry
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(entry) {
            try? data.write(to: file(key))
        }
    }

    /// 同一部作品各季共用一份
    private static func key(_ ref: TMDBRef) -> String {
        "\(ref.mediaType.rawValue)_\(ref.id)"
    }

    private func file(_ key: String) -> URL {
        directory.appendingPathComponent(key + ".json")
    }
}
