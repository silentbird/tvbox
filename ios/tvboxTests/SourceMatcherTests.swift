import Testing
@testable import tvbox

/// 站点片名样本来自常见的苹果 CMS 站点写法
struct SourceMatcherTests {
    private static func tv(season: Int?, year: Int? = 2019, episodes: Int? = 46) -> SourceMatcher.Target {
        SourceMatcher.Target(mediaType: .tv, titles: ["庆余年", "Joy of Life"], season: season, year: year, episodeCount: episodes)
    }

    private static let movie = SourceMatcher.Target(mediaType: .movie, titles: ["流浪地球2"], season: nil, year: 2023, episodeCount: nil)

    @Test(arguments: ["庆余年", "庆余年 第一季", "庆余年[国语]", "庆余年（2019）", "庆余年 国语版", "Joy of Life"])
    func sureForFirstSeason(name: String) {
        #expect(SourceMatcher.match(name: name, year: "2019", target: Self.tv(season: 1))?.confidence == .sure)
    }

    @Test(arguments: ["庆余年之少年范闲", "庆余年番外", "说庆余年"])
    func otherTitlesDoNotMatch(name: String) {
        #expect(SourceMatcher.match(name: name, year: nil, target: Self.tv(season: 1)) == nil)
    }

    @Test func seasonMarkers() {
        let second = Self.tv(season: 2, year: 2024)
        #expect(SourceMatcher.match(name: "庆余年第二季", year: "2024", target: second)?.confidence == .sure)
        #expect(SourceMatcher.match(name: "庆余年2", year: "2024", target: second)?.confidence == .sure)
        #expect(SourceMatcher.match(name: "庆余年 Season 2", year: nil, target: second)?.confidence == .sure)
        #expect(SourceMatcher.match(name: "庆余年第二季", year: "2024", target: Self.tv(season: 1)) == nil)
    }

    /// 没标季数时靠年份判断是不是要看的那一季
    @Test func unmarkedSeasonUsesYear() {
        let second = Self.tv(season: 2, year: 2024)
        #expect(SourceMatcher.match(name: "庆余年", year: "2024", target: second)?.confidence == .sure)
        #expect(SourceMatcher.match(name: "庆余年", year: nil, target: second) == SourceMatcher.Match(confidence: .possible, reason: "未标季数"))
        let old = SourceMatcher.match(name: "庆余年", year: "2019", target: second)
        #expect(old?.confidence == .possible)
    }

    @Test func yearMismatchIsPossible() {
        #expect(SourceMatcher.match(name: "庆余年", year: "2017", target: Self.tv(season: 1)) == SourceMatcher.Match(confidence: .possible, reason: "年份不符 · 2017"))
        // 差一年算对得上，站点常写成上线年份
        #expect(SourceMatcher.match(name: "庆余年", year: "2020", target: Self.tv(season: 1))?.confidence == .sure)
    }

    /// 搜索页还不知道看哪一季，各季都算
    @Test func anySeasonOnSearchPage() {
        let any = Self.tv(season: nil)
        #expect(SourceMatcher.match(name: "庆余年第二季", year: "2024", target: any)?.confidence == .sure)
        #expect(SourceMatcher.match(name: "庆余年", year: "2024", target: any)?.confidence == .sure)
    }

    /// TMDB 上有单独一部叫「庆余年第二季」的，整个片名对得上就不再拆季数
    @Test func tmdbTitleWithSeason() {
        let target = SourceMatcher.Target(mediaType: .tv, titles: ["庆余年第二季"], season: 1, year: 2024, episodeCount: 1)
        #expect(SourceMatcher.match(name: "庆余年第二季", year: "2024", target: target)?.confidence == .sure)
        #expect(SourceMatcher.match(name: "庆余年", year: "2024", target: target) == nil)
    }

    @Test func movieTitleWithNumber() {
        #expect(SourceMatcher.match(name: "流浪地球2", year: "2023", target: Self.movie)?.confidence == .sure)
        #expect(SourceMatcher.match(name: "流浪地球", year: "2019", target: Self.movie) == nil)
        #expect(SourceMatcher.match(name: "流浪地球2 第二季", year: nil, target: Self.movie) == nil)
    }

    @Test func episodeCounts() {
        #expect(SourceMatcher.episodeMismatch(count: 1, target: Self.tv(season: 1)) == "只有 1 集")
        #expect(SourceMatcher.episodeMismatch(count: 12, target: Self.tv(season: 1)) == nil)
        #expect(SourceMatcher.episodeMismatch(count: 2, target: Self.movie) == nil)
        #expect(SourceMatcher.episodeMismatch(count: 30, target: Self.movie) == "集数不符 · 30 集")
    }
}
