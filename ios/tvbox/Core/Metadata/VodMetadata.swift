import Foundation

enum TMDBMediaType: String, Codable, Sendable {
    case movie, tv
}

/// 从 TMDB 补全的影视资料，图片只存路径，拼地址时才套用当前的代理设置
struct VodMetadata: Codable, Sendable {
    let tmdbID: Int
    let mediaType: TMDBMediaType
    let title: String
    let overview: String?
    let backdropPath: String?
    let logoPath: String?
    let rating: Double?
    let certification: String?
    let genres: [String]
    /// 首播或上映日期，yyyy-MM-dd
    let releaseDate: String?
    /// 单集或影片时长 (分钟)
    let runtime: Int?
    /// 当季总集数
    let episodeCount: Int?
    let episodes: [Episode]
    /// 第 0 季特别篇里当季播出期间的先导片、加更等
    let specials: [Episode]
    let cast: [Person]

    struct Episode: Codable, Sendable {
        let number: Int
        let name: String?
        let overview: String?
        let stillPath: String?
        let runtime: Int?
        let airDate: String?
    }

    struct Person: Codable, Sendable {
        let name: String
        /// 角色名，导演为 nil
        let character: String?
        let profilePath: String?
        let isDirector: Bool
    }

    func episode(number: Int) -> Episode? {
        episodes.first { $0.number == number }
    }

    func episode(_ ref: EpisodeRef) -> Episode? {
        switch ref {
        case .episode(let number): return episode(number: number)
        case .special(let number): return specials.first { $0.number == number }
        case .none: return nil
        }
    }

    /// 综艺按播出日期和名字对应：「20261010 第1期上」对正片「第1期上：xxx」，「先导片上」「第1期加更」对特别篇。
    /// 同一天有正片也有纯享等特别篇，所以日期之外还要比名字；正片排在前面优先
    func ref(matching title: String, airDate: String?) -> EpisodeRef? {
        let all = episodes.map { (EpisodeRef.episode($0.number), $0) } + specials.map { (EpisodeRef.special($0.number), $0) }
        let candidates = airDate.map { date in all.filter { $0.1.airDate == date } } ?? all
        let key = Self.normalize(title)
        if !key.isEmpty, let hit = candidates.first(where: { _, episode in
            let name = Self.normalize(episode.name ?? "")
            // 反过来包含（「第1集上」对 TMDB 只有一条的「第1期」）要求 TMDB 名字带数字，免得「加更」这种短名乱对
            return !name.isEmpty && (name.contains(key) || (key.contains(name) && name.contains(where: \.isNumber)))
        }) {
            return hit.0
        }
        // 名字对不上，但当天只播了一集
        return airDate != nil && candidates.count == 1 ? candidates[0].0 : nil
    }

    /// 「期」「集」当成一样，只比文字和数字
    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "期", with: "集")
            .filter { $0.isLetter || $0.isNumber }
    }
}

/// 站点的一集对应 TMDB 的哪一集。存成 "E5"、"S0E131"（第 0 季特别篇），"none" 表示不对应任何一集
enum EpisodeRef: Hashable, Sendable {
    case episode(Int)
    case special(Int)
    case none

    init?(rawValue: String) {
        let value = rawValue.uppercased()
        if value == "NONE" {
            self = .none
        } else if value.hasPrefix("S0E"), let number = Int(value.dropFirst(3)) {
            self = .special(number)
        } else if value.hasPrefix("E"), let number = Int(value.dropFirst()) {
            self = .episode(number)
        } else {
            return nil
        }
    }

    var rawValue: String {
        switch self {
        case .episode(let number): return "E\(number)"
        case .special(let number): return "S0E\(number)"
        case .none: return "none"
        }
    }
}

/// 重新匹配时的搜索结果
struct TMDBSearchItem: Identifiable, Sendable {
    var id: String { "\(mediaType.rawValue)_\(tmdbID)" }
    let tmdbID: Int
    let mediaType: TMDBMediaType
    let title: String
    let originalTitle: String?
    let year: String?
    let posterPath: String?
    let overview: String?
}
