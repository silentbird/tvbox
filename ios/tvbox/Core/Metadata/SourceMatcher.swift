import Foundation

/// 判断站点搜到的影片是不是某部 TMDB 作品（剧集还要对上季）
enum SourceMatcher {
    enum Confidence: String, Codable, Sendable {
        /// 片名、季、年份都对得上
        case sure
        /// 片名对得上，但年份、季或集数有疑问，不自动选用
        case possible
    }

    struct Match: Equatable, Sendable {
        let confidence: Confidence
        /// 为什么只是可能相关，例如「年份不符 · 2017」
        let reason: String?
    }

    struct Target: Sendable {
        let mediaType: TMDBMediaType
        /// TMDB 的片名、原名，以及手动搜索时用的片名
        let titles: [String]
        /// 剧集的季，nil 表示哪一季都算（搜索页还不知道看哪一季）
        var season: Int?
        /// 当季首播或电影上映年份
        let year: Int?
        /// 当季集数
        let episodeCount: Int?
    }

    /// 片名对不上返回 nil
    static func match(name: String, year: String?, target: Target) -> Match? {
        let titles = Set(target.titles.map(normalize).filter { !$0.isEmpty })
        guard !titles.isEmpty else { return nil }
        let stripped = stripVersion(name)
        let parsed = TMDBService.parseTitle(stripped)
        var key = normalize(parsed.query)
        var season = parsed.season

        if titles.contains(normalize(stripped)) {
            // TMDB 片名本身带季数或数字，如单独一部的「庆余年第二季」「流浪地球2」
            key = normalize(stripped)
            season = nil
        } else if !titles.contains(key) {
            // 「庆余年2」这种直接在片名后面跟数字的当作第几季
            guard target.mediaType == .tv, season == nil,
                  let split = splitTrailingNumber(key), titles.contains(split.name) else { return nil }
            key = split.name
            season = split.number
        }

        var reasons: [String] = []
        switch target.mediaType {
        case .movie:
            // 电影片名带季数的是同名剧集
            guard season == nil else { return nil }
        case .tv:
            if let wanted = target.season {
                if let season {
                    guard season == wanted else { return nil }
                } else if wanted > 1 {
                    // 没标季数一般是第一季，要看第几季时靠年份确认
                    reasons.append("未标季数")
                }
            }
        }

        // 搜索页剧集还不知道看哪一季，不比年份
        let checksYear = target.mediaType == .movie || target.season != nil
        if checksYear, let targetYear = target.year, let siteYear = year.flatMap({ Int($0.prefix(4)) }), siteYear > 1900 {
            if abs(siteYear - targetYear) > 1 {
                reasons.append("年份不符 · \(siteYear)")
            } else if reasons == ["未标季数"] {
                reasons.removeAll()
            }
        }

        return reasons.isEmpty ? Match(confidence: .sure, reason: nil) : Match(confidence: .possible, reason: reasons.joined(separator: " · "))
    }

    /// 拉到站点详情后按集数再查一次，对不上返回原因
    static func episodeMismatch(count: Int, target: Target) -> String? {
        switch target.mediaType {
        case .tv:
            return count == 1 && (target.episodeCount ?? 2) > 1 ? "只有 1 集" : nil
        case .movie:
            // 电影线路里常带预告、花絮，集数很多才是剧集
            return count > 5 ? "集数不符 · \(count) 集" : nil
        }
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// 去掉片名后面的语言、版本说明
    private static func stripVersion(_ name: String) -> String {
        name.replacingOccurrences(
            of: "\\s*(国语|粤语|普通话|台配|日语|英语|中字|未删减|完整|导演剪辑|加长|蓝光|高清)版?\\s*$",
            with: "",
            options: .regularExpression
        )
    }

    /// 「庆余年2」拆成「庆余年」和 2；纯数字或数字太大（年份）的不拆
    private static func splitTrailingNumber(_ key: String) -> (name: String, number: Int)? {
        let digits = key.reversed().prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, digits.count < key.count,
              let number = Int(String(digits.reversed())), (2...30).contains(number) else { return nil }
        return (String(key.dropLast(digits.count)), number)
    }
}
