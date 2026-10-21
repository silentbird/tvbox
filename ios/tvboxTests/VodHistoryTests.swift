import Foundation
import Testing
@testable import tvbox

struct VodHistoryTests {
    private func item(_ siteKey: String, _ vodId: String, tmdb: TMDBRef?) -> StorageManager.VodHistoryItem {
        StorageManager.VodHistoryItem(
            vodId: vodId, vodName: "现在就出发", vodPic: nil, siteKey: siteKey,
            playIndex: 0, episodeIndex: 0, episodeName: nil, progress: 0, duration: 0,
            updateTime: Date(), tmdb: tmdb
        )
    }

    /// 同一 TMDB 作品同一季，不同站点算一条；换了季另算一条
    @Test func sameEntryByTMDBSeason() {
        let season1 = TMDBRef(mediaType: .tv, id: 1, season: 1)
        let uc = item("uc", "a", tmdb: season1)

        #expect(uc.isSameEntry(as: item("quark", "b", tmdb: season1)))
        #expect(!uc.isSameEntry(as: item("quark", "b", tmdb: TMDBRef(mediaType: .tv, id: 1, season: 4))))
        #expect(!uc.isSameEntry(as: item("quark", "b", tmdb: nil)))
        #expect(uc.isSameEntry(as: item("uc", "a", tmdb: nil)))
    }
}

struct SameEpisodeTests {
    /// 换线路、站点时按集名对应上次看的那一集
    @Test func sameEpisode() {
        #expect(EpisodeMatcher.isSameEpisode("第01集", "01"))
        #expect(EpisodeMatcher.isSameEpisode("[1.3GB]E09.mkv", "第9集"))
        #expect(!EpisodeMatcher.isSameEpisode("第01集", "第02集"))
        #expect(EpisodeMatcher.isSameEpisode("[1.4GB]20230814.mp4", "20230814"))
        #expect(!EpisodeMatcher.isSameEpisode("[1.4GB]20230814.mp4", "[906.8MB]20230730.mp4"))
        #expect(!EpisodeMatcher.isSameEpisode("20261010 第1期上", "20261010 第1期下"))
        #expect(!EpisodeMatcher.isSameEpisode("第1期加更", "第1期"))
        // 一边只有日期时按日期对应，上下集分在两天
        #expect(EpisodeMatcher.isSameEpisode("20230813第1期上", "[1.8GB]20230813.mp4【第1季】"))
        #expect(!EpisodeMatcher.isSameEpisode("20230813第1期上", "[1.4GB]20230814.mp4【C现在就出发-第1季】"))
        #expect(!EpisodeMatcher.isSameEpisode("[5.5GB]20261001 先导片上.mp4【现在4】", "[4.1GB]20261001 先导片下.mp4【现在4】"))
        // 同一站点各线路的集名：有的带日期，有的不带，有的集数补 0
        #expect(EpisodeMatcher.isSameEpisode("20230813第1期上", "第1期上"))
        #expect(EpisodeMatcher.isSameEpisode("20230813第1期上", "第01期上"))
        #expect(EpisodeMatcher.isSameEpisode("20230813第1期上", "2023-08-13"))
        #expect(EpisodeMatcher.isSameEpisode("20230730森林体验篇", "森林体验篇"))
        #expect(!EpisodeMatcher.isSameEpisode("20230813第1期上", "第1期下"))
        #expect(!EpisodeMatcher.isSameEpisode("20230816第1期加更", "第1期上"))
    }
}
