import Testing
@testable import tvbox

/// 集名样本来自实际遇到的站点和网盘
struct EpisodeMatcherTests {
    @Test(arguments: [
        ("第01集", 1),
        ("第12话", 12),
        ("EP05", 5),
        ("Episode 7", 7),
        ("01", 1),
        ("01 国语", 1),
        ("[5.4GB]01.mkv【JIAJINCHAI8-1】", 1),
        ("[5.0GB]10.mkv【JIAJINCHAI8-1】", 10),
        ("[5.7GB]E04.mkv【JIAJINCHAI8-1】", 4),
        ("[1.3GB]E09.mkv", 9),
        ("[3.2GB]The.Affair.Was.Just.The.Beginning.2026.S01E03.1080p.friDay.WEB-DL.H.264.AAC.mkv【X 现在不是出轨的问题】", 3),
    ])
    func episodeNumber(name: String, expected: Int) {
        #expect(EpisodeMatcher.episodeNumber(name) == expected)
    }

    @Test(arguments: ["正片", "先导片上", "The.Beginning.mkv"])
    func episodeNumberMissing(name: String) {
        #expect(EpisodeMatcher.episodeNumber(name) == nil)
    }

    @Test func varietyKey() {
        let key = EpisodeMatcher.varietyKey("[9.1GB]20261010 第1期上.mp4【现在4】")
        #expect(key.airDate == "2026-10-10")
        #expect(key.title == "第1期上")
        #expect(key.isPart)

        let plain = EpisodeMatcher.varietyKey("[5.4GB]01.mkv【JIAJINCHAI8-1】")
        #expect(plain.airDate == nil)
        #expect(!plain.isPart)
    }

    @Test func varietyEpisodes() {
        let names = [
            "[5.5GB]20261001 先导片上.mp4【现在4】",
            "[4.1GB]20261001 先导片下.mp4【现在4】",
            "[9.1GB]20261010 第1期上.mp4【现在4】",
            "[11.0GB]20261011 第1期下.mp4【现在4】",
            "[4.0GB]20261012 第1期加更.mp4【现在4】",
            "[2.9GB]20261013 第1期还有加更.mp4【现在4】",
            "[7.9GB]20261017 第2期上.mp4【现在4】",
            "[6.6GB]20261018 第2期下.mp4【现在4】",
        ]
        let expected: [EpisodeRef] = [
            .special(131), .special(132), .episode(1), .episode(2),
            .special(133), .special(134), .episode(3), .episode(4),
        ]
        let byOrder = EpisodeMatcher.numberByOrder(names)
        #expect(!byOrder)
        for (index, name) in names.enumerated() {
            #expect(EpisodeMatcher.match(name: name, index: index, numberByOrder: byOrder, metadata: Self.variety) == expected[index], "\(name)")
        }
    }

    /// 网盘文件名混着「01.mkv」「E04.mkv」，顺序也是乱的，只能按集名里的数字对
    @Test func netdiskEpisodes() {
        let names = [
            "[64.6MB]00 4K .mp4【JIAJINCHAI8-1】",
            "[5.4GB]01.mkv【JIAJINCHAI8-1】",
            "[5.0GB]10.mkv【JIAJINCHAI8-1】",
            "[5.7GB]E04.mkv【JIAJINCHAI8-1】",
            "[5.1GB]E11.mkv【JIAJINCHAI8-1】",
        ]
        let expected: [EpisodeRef?] = [nil, .episode(1), .episode(10), .episode(4), .episode(11)]
        let byOrder = EpisodeMatcher.numberByOrder(names)
        for (index, name) in names.enumerated() {
            #expect(EpisodeMatcher.match(name: name, index: index, numberByOrder: byOrder, metadata: Self.drama) == expected[index], "\(name)")
        }
    }

    @Test func numberByOrderWhenNamesHaveNoDigits() {
        let names = ["正片", "大结局"]
        #expect(EpisodeMatcher.numberByOrder(names))
        #expect(EpisodeMatcher.match(name: names[1], index: 1, numberByOrder: true, metadata: Self.drama) == .episode(2))
    }

    @Test func refRawValue() {
        for ref in [EpisodeRef.episode(5), .special(131), .none] {
            #expect(EpisodeRef(rawValue: ref.rawValue) == ref)
        }
        #expect(EpisodeRef(rawValue: "s0e3") == .special(3))
        #expect(EpisodeRef(rawValue: "第1集") == nil)
    }

    // MARK: - 样本资料

    private static func episode(_ number: Int, _ name: String?, _ airDate: String?) -> VodMetadata.Episode {
        VodMetadata.Episode(number: number, name: name, overview: nil, stillPath: nil, runtime: nil, airDate: airDate)
    }

    private static func metadata(episodes: [VodMetadata.Episode], specials: [VodMetadata.Episode] = []) -> VodMetadata {
        VodMetadata(
            tmdbID: 1, mediaType: .tv, title: "", overview: nil, backdropPath: nil, logoPath: nil, rating: nil,
            certification: nil, genres: [], releaseDate: nil, runtime: nil, episodeCount: episodes.count,
            episodes: episodes, specials: specials, cast: []
        )
    }

    static let variety = metadata(
        episodes: [
            episode(1, "第1期上：出发", "2026-10-10"),
            episode(2, "第1期下：出发", "2026-10-11"),
            episode(3, "第2期上", "2026-10-17"),
            episode(4, "第2期下", "2026-10-18"),
        ],
        specials: [
            episode(131, "第4季 先导片上", "2026-10-01"),
            episode(132, "第4季 先导片下", "2026-10-01"),
            episode(133, "第4季 第1期加更", "2026-10-12"),
            episode(134, "第4季 第1期还有加更", "2026-10-13"),
        ]
    )

    static let drama = metadata(episodes: (1...12).map { episode($0, nil, nil) })
}

struct EpisodeAIMatcherTests {
    @Test func parseFencedResponse() {
        let content = """
        ```json
        {"1": "E1", "2": "S0E131", "3": null, "9": "E2", "4": "第4集"}
        ```
        """
        let result = EpisodeAIMatcher.parseResponse(content, count: 4)
        #expect(result == [0: .episode(1), 1: .special(131)])
    }

    @Test func parseInvalidResponse() {
        #expect(EpisodeAIMatcher.parseResponse("对不上", count: 2) == nil)
    }

    @Test func promptListsEpisodesAndNames() {
        let prompt = EpisodeAIMatcher.userPrompt(title: "现在就出发第四季", names: ["a.mp4", "b.mp4"], metadata: EpisodeMatcherTests.variety)
        #expect(prompt.contains("E1 | 2026-10-10 | 第1期上：出发"))
        #expect(prompt.contains("S0E131 | 2026-10-01 | 第4季 先导片上"))
        #expect(prompt.contains("2. b.mp4"))
    }
}
