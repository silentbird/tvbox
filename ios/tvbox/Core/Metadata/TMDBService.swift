import Foundation

/// TMDB 相关设置
enum TMDBSettings {
    private enum Keys {
        static let enabled = "tmdb_enabled"
        static let apiKey = "tmdb_api_key"
        static let proxy = "tmdb_proxy"
        static let language = "tmdb_language"
        static let overrides = "tmdb_overrides"
        static let episodeOverrides = "tmdb_episode_overrides"
    }

    static let languages: [(code: String, name: String)] = [
        ("zh-CN", "简体中文"),
        ("zh-TW", "繁體中文"),
        ("en-US", "English"),
    ]

    /// 默认开启，搜索和详情页以 TMDB 作品为主
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Keys.enabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.enabled) }
    }

    /// App 内置的 Key，设置里没填时用它
    static let builtInApiKey = "18ecaade61d81dcfbcfd19966163bd7b"

    /// 设置里填的 Key，v3 的 API Key 或 v4 的读取令牌都可以
    static var customApiKey: String {
        get { UserDefaults.standard.string(forKey: Keys.apiKey) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.apiKey) }
    }

    static var apiKey: String {
        customApiKey.isEmpty ? builtInApiKey : customApiKey
    }

    /// 代理地址，接口 /3/ 和图片 /t/p/ 都走它
    static var proxy: String {
        get { UserDefaults.standard.string(forKey: Keys.proxy) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.proxy) }
    }

    static var language: String {
        get { UserDefaults.standard.string(forKey: Keys.language) ?? "zh-CN" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.language) }
    }

    static var isConfigured: Bool { isEnabled && !apiKey.isEmpty }

    /// 用 TMDB 的备用域名，国内 api.themoviedb.org 被 DNS 污染，解析到错误地址导致证书校验失败
    static var apiBase: String { proxyBase ?? "https://api.tmdb.org" }
    static var imageBase: String { proxyBase ?? "https://image.tmdb.org" }

    private static var proxyBase: String? {
        var base = proxy
        while base.hasSuffix("/") { base.removeLast() }
        return base.isEmpty ? nil : base
    }

    /// 手动重新匹配的结果，值为 "tv:123"、"movie:456"，"none" 表示不使用 TMDB 资料
    static var overrides: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: Keys.overrides) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: Keys.overrides) }
    }

    /// 手动对应的分集，按 站点|片名|TMDB ID 分组，组内是 集名 → EpisodeRef.rawValue
    static var episodeOverrides: [String: [String: String]] {
        get { UserDefaults.standard.dictionary(forKey: Keys.episodeOverrides) as? [String: [String: String]] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: Keys.episodeOverrides) }
    }

    static func imageURL(_ path: String?, size: String) -> String? {
        guard let path, !path.isEmpty else { return nil }
        return "\(imageBase)/t/p/\(size)\(path)"
    }
}

enum TMDBError: LocalizedError {
    case notConfigured
    case unauthorized
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "未填写 TMDB API Key"
        case .unauthorized: return "API Key 无效"
        case .http(let code): return "TMDB 返回错误 \(code)"
        }
    }
}

/// 按片名和年份去 TMDB 匹配影视资料，结果按 站点+片名 缓存在磁盘
actor TMDBService {
    static let shared = TMDBService()

    /// 匹配上的资料缓存 7 天，正在更新的剧集能拿到新的分集；没匹配上的 1 天后再试
    private static let matchedTTL: TimeInterval = 7 * 24 * 3600
    private static let unmatchedTTL: TimeInterval = 24 * 3600

    private struct CacheEntry: Codable {
        let metadata: VodMetadata?
        let date: Date
    }

    private var memoryCache: [String: CacheEntry] = [:]

    private var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tmdb", isDirectory: true)
    }

    // MARK: - 对外接口

    /// 详情页的补全资料，没开启、没匹配上或网络出错时返回 nil
    /// - Parameter episodeCount: 站点当前线路的集数，用来判断是剧集还是电影
    func metadata(siteKey: String, vodName: String, year: String?, episodeCount: Int) async -> VodMetadata? {
        guard TMDBSettings.isConfigured else { return nil }
        let key = Self.cacheKey(siteKey: siteKey, vodName: vodName)
        let cached = readCache(key: key)
        if let cached {
            let ttl = cached.metadata == nil ? Self.unmatchedTTL : Self.matchedTTL
            if Date().timeIntervalSince(cached.date) < ttl { return cached.metadata }
        }

        let parsed = Self.parseTitle(vodName)
        do {
            let target: (TMDBMediaType, Int)?
            switch TMDBSettings.overrides[key] {
            case "none":
                target = nil
            case let value?:
                target = Self.parseOverride(value)
            case nil:
                target = try await match(query: parsed.query, year: year, preferTV: episodeCount > 1 || parsed.season != nil)
            }
            var metadata: VodMetadata?
            if let target {
                metadata = try await load(type: target.0, id: target.1, season: parsed.season ?? 1)
            }
            writeCache(CacheEntry(metadata: metadata, date: Date()), key: key)
            return metadata
        } catch {
            AppLogger.debug("[TMDB] \(vodName) 获取资料失败: \(error)")
            // 网络出错时用过期的缓存顶上
            return cached?.metadata
        }
    }

    /// 按 TMDB 作品取资料，TMDB 详情页用；剧集取指定的季，电影忽略季
    func metadata(type: TMDBMediaType, id: Int, season: Int) async -> VodMetadata? {
        guard TMDBSettings.isConfigured else { return nil }
        let key = "tmdb|\(type.rawValue):\(id)|\(type == .tv ? season : 0)"
        let cached = readCache(key: key)
        if let cached, cached.metadata != nil, Date().timeIntervalSince(cached.date) < Self.matchedTTL {
            return cached.metadata
        }
        do {
            let metadata = try await load(type: type, id: id, season: season)
            writeCache(CacheEntry(metadata: metadata, date: Date()), key: key)
            return metadata
        } catch {
            AppLogger.debug("[TMDB] \(type.rawValue):\(id) 获取资料失败: \(error)")
            return cached?.metadata
        }
    }

    func search(query: String) async throws -> [TMDBSearchItem] {
        let response: SearchResponse = try await get("/search/multi", query: ["query": query])
        return response.results.compactMap { $0.item }
    }

    /// 手动选定匹配结果，nil 表示不使用 TMDB 资料
    func setOverride(siteKey: String, vodName: String, type: TMDBMediaType?, id: Int?) {
        let key = Self.cacheKey(siteKey: siteKey, vodName: vodName)
        var overrides = TMDBSettings.overrides
        if let type, let id {
            overrides[key] = "\(type.rawValue):\(id)"
        } else {
            overrides[key] = "none"
        }
        TMDBSettings.overrides = overrides
        removeCache(key: key)
    }

    func testConnection() async throws {
        let _: ConfigurationResponse = try await get("/configuration")
    }

    func cachedCount() -> Int {
        (try? FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path).count) ?? 0
    }

    func clearCache() {
        memoryCache.removeAll()
        try? FileManager.default.removeItem(at: cacheDirectory)
    }

    // MARK: - 匹配

    /// 去掉季数和括号里的附加信息，作为搜索词
    static func parseTitle(_ name: String) -> (query: String, season: Int?) {
        var query = name.replacingOccurrences(of: "[\\[【(（][^\\]】)）]*[\\]】)）]", with: " ", options: .regularExpression)
        var season: Int?
        let patterns = [
            "第\\s*([0-9一二三四五六七八九十]+)\\s*季",
            "(?i)season\\s*([0-9]+)",
            "(?i)\\bS([0-9]{1,2})$",
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
                  let numberRange = Range(match.range(at: 1), in: query),
                  let fullRange = Range(match.range, in: query) else { continue }
            season = Int(query[numberRange]) ?? chineseNumber(String(query[numberRange]))
            query.removeSubrange(fullRange)
            break
        }
        return (query.trimmingCharacters(in: .whitespacesAndNewlines), season)
    }

    private static func chineseNumber(_ text: String) -> Int? {
        let digits: [Character: Int] = ["一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9]
        if text == "十" { return 10 }
        if let tenIndex = text.firstIndex(of: "十") {
            let tens = text[..<tenIndex].first.flatMap { digits[$0] } ?? 1
            let ones = text[text.index(after: tenIndex)...].first.flatMap { digits[$0] } ?? 0
            return tens * 10 + ones
        }
        return text.first.flatMap { digits[$0] }
    }

    /// 片名要对得上（相同或互相包含），再按年份和类型打分取最高的
    private func match(query: String, year: String?, preferTV: Bool) async throws -> (TMDBMediaType, Int)? {
        guard !query.isEmpty else { return nil }
        let items = try await search(query: query)
        let normalizedQuery = Self.normalize(query)
        let targetYear = year.flatMap { Int($0.prefix(4)) }

        var best: (score: Int, item: TMDBSearchItem)?
        for item in items {
            let names = [item.title, item.originalTitle].compactMap { $0 }.map(Self.normalize)
            let isExact = names.contains(normalizedQuery)
            let isPartial = names.contains { !$0.isEmpty && ($0.contains(normalizedQuery) || normalizedQuery.contains($0)) }
            guard isExact || isPartial else { continue }

            var score = isExact ? 4 : 1
            var yearMatches = false
            if let targetYear, let itemYear = item.year.flatMap({ Int($0) }) {
                let diff = abs(itemYear - targetYear)
                score += diff == 0 ? 3 : diff == 1 ? 1 : -3
                yearMatches = diff <= 1
            }
            // 只是包含关系时必须年份也对上，否则容易配错
            guard isExact || yearMatches else { continue }
            if (item.mediaType == .tv) == preferTV { score += 2 }
            if score > (best?.score ?? Int.min) { best = (score, item) }
        }
        return best.map { ($0.item.mediaType, $0.item.tmdbID) }
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func parseOverride(_ value: String) -> (TMDBMediaType, Int)? {
        let parts = value.split(separator: ":")
        guard parts.count == 2, let type = TMDBMediaType(rawValue: String(parts[0])), let id = Int(parts[1]) else { return nil }
        return (type, id)
    }

    // MARK: - 资料

    private func load(type: TMDBMediaType, id: Int, season: Int) async throws -> VodMetadata {
        switch type {
        case .tv: return try await loadTV(id: id, season: season)
        case .movie: return try await loadMovie(id: id)
        }
    }

    private var imageLanguages: String {
        "\(TMDBSettings.language.prefix(2)),en,ja,null"
    }

    private func loadTV(id: Int, season: Int) async throws -> VodMetadata {
        let detail: TVDetail = try await get("/tv/\(id)", query: [
            "append_to_response": "aggregate_credits,content_ratings,images",
            "include_image_language": imageLanguages,
        ])

        var episodes: [VodMetadata.Episode] = []
        var episodeCount = detail.numberOfEpisodes
        // 站点标的季在 TMDB 上不存在时不显示分集，免得配到别的季
        if detail.seasons?.contains(where: { $0.seasonNumber == season }) == true {
            let seasonDetail: SeasonDetail = try await get("/tv/\(id)/season/\(season)")
            var rawEpisodes = seasonDetail.episodes ?? []
            // 没有当前语言的分集标题和简介时用原语言的
            let original = detail.originalLanguage ?? ""
            if !original.isEmpty, !TMDBSettings.language.hasPrefix(original),
               rawEpisodes.contains(where: { ($0.overview ?? "").isEmpty || Self.isPlaceholderName($0.name) }),
               let originalSeason: SeasonDetail = try? await get("/tv/\(id)/season/\(season)", language: original) {
                let fallback = Dictionary((originalSeason.episodes ?? []).map { ($0.episodeNumber, $0) }) { first, _ in first }
                rawEpisodes = rawEpisodes.map { episode in
                    guard let other = fallback[episode.episodeNumber] else { return episode }
                    var merged = episode
                    if (merged.overview ?? "").isEmpty { merged.overview = other.overview }
                    if Self.isPlaceholderName(merged.name), !Self.isPlaceholderName(other.name) { merged.name = other.name }
                    return merged
                }
            }
            episodes = rawEpisodes.map(Self.makeEpisode)
            episodeCount = rawEpisodes.count
        }

        // 综艺的先导片、加更、彩蛋放在第 0 季特别篇里，只留当季播出期间的，详情页按日期和名字对应
        var specials: [VodMetadata.Episode] = []
        if season != 0, let seasons = detail.seasons,
           seasons.contains(where: { $0.seasonNumber == 0 }),
           let start = seasons.first(where: { $0.seasonNumber == season })?.airDate,
           let specialSeason: SeasonDetail = try? await get("/tv/\(id)/season/0") {
            // 先导片会比第 1 期早播
            let from = Self.shiftDate(start, days: -30)
            let end = seasons.filter { $0.seasonNumber > season }.compactMap(\.airDate).min()
            specials = (specialSeason.episodes ?? [])
                .filter { episode in
                    guard let date = episode.airDate else { return false }
                    return date >= from && end.map { date < $0 } ?? true
                }
                .map(Self.makeEpisode)
        }

        let credits = detail.aggregateCredits
        let directors = (credits?.crew ?? [])
            .filter { $0.jobs?.contains { $0.job == "Director" || $0.job == "Series Director" } == true }
            .prefix(2)
            .map { VodMetadata.Person(name: $0.name, character: nil, profilePath: $0.profilePath, isDirector: true) }
        let cast = (credits?.cast ?? []).prefix(20).map {
            VodMetadata.Person(name: $0.name, character: $0.roles?.first?.character, profilePath: $0.profilePath, isDirector: false)
        }
        let ratings = (detail.contentRatings?.results ?? []).map { ($0.iso31661, $0.rating) }
        let seasons = (detail.seasons ?? [])
            .filter { $0.seasonNumber > 0 }
            .map { VodMetadata.Season(number: $0.seasonNumber, name: $0.name, episodeCount: $0.episodeCount, airDate: $0.airDate) }

        return VodMetadata(
            tmdbID: id,
            mediaType: .tv,
            title: detail.name,
            originalTitle: detail.originalName,
            overview: detail.overview.flatMap { $0.isEmpty ? nil : $0 },
            backdropPath: detail.backdropPath,
            logoPath: Self.pickLogo(detail.images?.logos, originalLanguage: detail.originalLanguage),
            rating: detail.voteAverage.flatMap { $0 > 0 ? $0 : nil },
            certification: Self.pickCertification(ratings),
            genres: detail.genres?.map(\.name) ?? [],
            // 第二季以后显示当季的首播日期
            releaseDate: seasons.first { $0.number == season }?.airDate ?? detail.firstAirDate,
            runtime: detail.episodeRunTime?.first ?? episodes.first?.runtime,
            episodeCount: episodeCount,
            episodes: episodes,
            specials: specials,
            cast: Array(directors) + cast,
            seasons: seasons,
            season: season
        )
    }

    private static func makeEpisode(_ episode: SeasonDetail.Episode) -> VodMetadata.Episode {
        VodMetadata.Episode(
            number: episode.episodeNumber,
            name: isPlaceholderName(episode.name) ? nil : episode.name,
            overview: episode.overview.flatMap { $0.isEmpty ? nil : $0 },
            stillPath: episode.stillPath,
            runtime: episode.runtime,
            airDate: episode.airDate
        )
    }

    /// yyyy-MM-dd 加减天数
    private static func shiftDate(_ date: String, days: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let value = formatter.date(from: date),
              let shifted = Calendar(identifier: .gregorian).date(byAdding: .day, value: days, to: value) else { return date }
        return formatter.string(from: shifted)
    }

    private func loadMovie(id: Int) async throws -> VodMetadata {
        let detail: MovieDetail = try await get("/movie/\(id)", query: [
            "append_to_response": "credits,release_dates,images",
            "include_image_language": imageLanguages,
        ])
        let directors = (detail.credits?.crew ?? [])
            .filter { $0.job == "Director" }
            .prefix(2)
            .map { VodMetadata.Person(name: $0.name, character: nil, profilePath: $0.profilePath, isDirector: true) }
        let cast = (detail.credits?.cast ?? []).prefix(20).map {
            VodMetadata.Person(name: $0.name, character: $0.character, profilePath: $0.profilePath, isDirector: false)
        }
        let ratings = (detail.releaseDates?.results ?? []).map { result in
            (result.iso31661, result.releaseDates?.first { !($0.certification ?? "").isEmpty }?.certification)
        }

        return VodMetadata(
            tmdbID: id,
            mediaType: .movie,
            title: detail.title,
            originalTitle: detail.originalTitle,
            overview: detail.overview.flatMap { $0.isEmpty ? nil : $0 },
            backdropPath: detail.backdropPath,
            logoPath: Self.pickLogo(detail.images?.logos, originalLanguage: detail.originalLanguage),
            rating: detail.voteAverage.flatMap { $0 > 0 ? $0 : nil },
            certification: Self.pickCertification(ratings),
            genres: detail.genres?.map(\.name) ?? [],
            releaseDate: detail.releaseDate,
            runtime: detail.runtime.flatMap { $0 > 0 ? $0 : nil },
            episodeCount: nil,
            episodes: [],
            specials: [],
            cast: Array(directors) + cast,
            seasons: [],
            season: nil
        )
    }

    /// 没有标题时 TMDB 返回「第 1 集」「Episode 1」这样的占位名
    private static func isPlaceholderName(_ name: String?) -> Bool {
        guard let name, !name.isEmpty else { return true }
        return name.range(of: "^(第\\s*\\d+\\s*[集話话]|Episode\\s*\\d+)$", options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// 优先当前语言的 Logo，其次英文、原语言、无文字的
    private static func pickLogo(_ logos: [ImageItem]?, originalLanguage: String?) -> String? {
        guard let logos, !logos.isEmpty else { return nil }
        let order = [String(TMDBSettings.language.prefix(2)), "en", originalLanguage, nil]
        for language in order {
            if let logo = logos.first(where: { $0.iso6391 == language }) { return logo.filePath }
        }
        return logos.first?.filePath
    }

    /// ratings 为 (地区, 分级)
    private static func pickCertification(_ ratings: [(String?, String?)]) -> String? {
        let valid = ratings.filter { !($0.1 ?? "").isEmpty }
        for region in ["CN", "US", "JP"] {
            if let rating = valid.first(where: { $0.0 == region })?.1 { return rating }
        }
        return valid.first?.1
    }

    // MARK: - 网络

    private func get<T: Decodable>(_ path: String, query: [String: String] = [:], language: String? = nil) async throws -> T {
        let key = TMDBSettings.apiKey
        guard !key.isEmpty else { throw TMDBError.notConfigured }
        guard var components = URLComponents(string: TMDBSettings.apiBase + "/3" + path) else { throw URLError(.badURL) }
        var items = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        items.append(URLQueryItem(name: "language", value: language ?? TMDBSettings.language))
        // v4 读取令牌是 JWT，放在请求头里；v3 Key 放在参数里
        let isBearer = key.hasPrefix("eyJ")
        if !isBearer {
            items.append(URLQueryItem(name: "api_key", value: key))
        }
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if isBearer {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
            throw status == 401 ? TMDBError.unauthorized : TMDBError.http(status)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - 缓存

    private static func cacheKey(siteKey: String, vodName: String) -> String {
        "\(siteKey)|\(vodName)"
    }

    private func cacheFile(key: String) -> URL {
        let name = Data(key.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
        return cacheDirectory.appendingPathComponent(name + ".json")
    }

    private func readCache(key: String) -> CacheEntry? {
        if let entry = memoryCache[key] { return entry }
        guard let data = try? Data(contentsOf: cacheFile(key: key)),
              let entry = try? JSONDecoder().decode(CacheEntry.self, from: data) else { return nil }
        memoryCache[key] = entry
        return entry
    }

    private func writeCache(_ entry: CacheEntry, key: String) {
        memoryCache[key] = entry
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(entry) {
            try? data.write(to: cacheFile(key: key))
        }
    }

    private func removeCache(key: String) {
        memoryCache[key] = nil
        try? FileManager.default.removeItem(at: cacheFile(key: key))
    }
}

// MARK: - TMDB 接口结构

private struct ConfigurationResponse: Decodable {
    let images: Images?
    struct Images: Decodable {
        let secureBaseUrl: String?
    }
}

private struct SearchResponse: Decodable {
    let results: [Result]

    struct Result: Decodable {
        let id: Int
        let mediaType: String?
        let title: String?
        let name: String?
        let originalTitle: String?
        let originalName: String?
        let releaseDate: String?
        let firstAirDate: String?
        let posterPath: String?
        let overview: String?

        /// 搜索结果里还有人物，只要影视
        var item: TMDBSearchItem? {
            guard let type = mediaType.flatMap(TMDBMediaType.init(rawValue:)),
                  let title = title ?? name else { return nil }
            let date = releaseDate ?? firstAirDate ?? ""
            return TMDBSearchItem(
                tmdbID: id,
                mediaType: type,
                title: title,
                originalTitle: originalTitle ?? originalName,
                year: date.count >= 4 ? String(date.prefix(4)) : nil,
                posterPath: posterPath,
                overview: overview
            )
        }
    }
}

private struct Genre: Decodable {
    let name: String
}

private struct ImageItem: Decodable {
    let filePath: String
    let iso6391: String?
}

private struct Images: Decodable {
    let logos: [ImageItem]?
}

private struct TVDetail: Decodable {
    let name: String
    let originalName: String?
    let overview: String?
    let backdropPath: String?
    let voteAverage: Double?
    let genres: [Genre]?
    let firstAirDate: String?
    let episodeRunTime: [Int]?
    let numberOfEpisodes: Int?
    let originalLanguage: String?
    let seasons: [Season]?
    let aggregateCredits: Credits?
    let contentRatings: ContentRatings?
    let images: Images?

    struct Season: Decodable {
        let seasonNumber: Int
        let name: String?
        let episodeCount: Int?
        let airDate: String?
    }

    struct Credits: Decodable {
        let cast: [Cast]?
        let crew: [Crew]?
    }

    struct Cast: Decodable {
        let name: String
        let profilePath: String?
        let roles: [Role]?
    }

    struct Role: Decodable {
        let character: String?
    }

    struct Crew: Decodable {
        let name: String
        let profilePath: String?
        let jobs: [Job]?
    }

    struct Job: Decodable {
        let job: String?
    }

    struct ContentRatings: Decodable {
        let results: [Rating]?
    }

    struct Rating: Decodable {
        let iso31661: String?
        let rating: String?
    }
}

private struct SeasonDetail: Decodable {
    let episodes: [Episode]?

    struct Episode: Decodable {
        let episodeNumber: Int
        var name: String?
        var overview: String?
        let stillPath: String?
        let runtime: Int?
        let airDate: String?
    }
}

private struct MovieDetail: Decodable {
    let title: String
    let originalTitle: String?
    let overview: String?
    let backdropPath: String?
    let voteAverage: Double?
    let genres: [Genre]?
    let releaseDate: String?
    let runtime: Int?
    let originalLanguage: String?
    let credits: Credits?
    let releaseDates: ReleaseDates?
    let images: Images?

    struct Credits: Decodable {
        let cast: [Cast]?
        let crew: [Crew]?
    }

    struct Cast: Decodable {
        let name: String
        let character: String?
        let profilePath: String?
    }

    struct Crew: Decodable {
        let name: String
        let job: String?
        let profilePath: String?
    }

    struct ReleaseDates: Decodable {
        let results: [Region]?
    }

    struct Region: Decodable {
        let iso31661: String?
        let releaseDates: [Release]?
    }

    struct Release: Decodable {
        let certification: String?
    }
}
