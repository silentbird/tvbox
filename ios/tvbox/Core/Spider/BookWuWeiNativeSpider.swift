import Foundation

/// 无忧听书（bookWuWei）— HTML 抓取 + MD5 签名的听书站。
final class BookWuWeiNativeSpider: WebsiteBundleNativeSpider {
    let siteKey: String
    private let site: SiteBean
    private let pcBase = "http://www.5weiting.com"
    private let mBase = "http://m.5weiting.com"
    private var isInitialized = false

    init(site: SiteBean) {
        self.site = site
        self.siteKey = site.key
    }

    func initialize(ext: String?) async throws {
        isInitialized = true
    }

    func homeContent(filter: Bool) async throws -> HomeContent {
        let categories: [(String, String)] = [
            ("t0", "全部分类"), ("t1", "玄幻奇幻"), ("t2", "修真武侠"), ("t3", "恐怖灵异"),
            ("t4", "古今言情"), ("t5", "都市言情"), ("t6", "穿越重生"), ("t7", "粤语古仔"),
            ("t8", "网游小说"), ("t9", "通俗文学"), ("t10", "历史纪实"), ("t11", "军事"),
            ("t12", "悬疑推理"), ("t13", "ebc5系列"), ("t14", "官场商战"), ("t15", "儿童读物"),
            ("t16", "广播剧"), ("t17", "外文原版"), ("t18", "评书大全"), ("t19", "相声小品"),
            ("t20", "百家讲坛"), ("t21", "健康养生"), ("t22", "教材"), ("t23", "期刊头条"),
            ("t24", "戏曲"), ("t25", "脱口秀")
        ]
        return HomeContent(
            categories: categories.map { MovieCategory(tid: $0.0, name: $0.1) },
            videos: [],
            filters: [:]
        )
    }

    func categoryContent(tid: String, page: Int, filter: Bool, extend: [String: String]) async throws -> CategoryContent {
        let url = "\(pcBase)/ys/\(tid)/o1/p\(page)"
        let html = try await WebsiteBundleHttp.getString(url, headers: Self.pcHeaders())
        let items = Self.parseCategoryHTML(html)
        let pageCount = items.count < 10 ? page : page + 1
        return CategoryContent(videos: items, page: page, pageCount: pageCount, total: pageCount * 10)
    }

    func detailContent(ids: [String]) async throws -> [VodInfo] {
        guard let id = ids.first, !id.isEmpty else { return [] }
        let url = "\(mBase)\(id)"
        let html = try await WebsiteBundleHttp.getString(url, headers: Self.mobileHeaders())

        let name = Self.matchFirst(
            in: html,
            pattern: #"<h2[^>]*>\s*([^<]+?)\s*</h2>"#
        ) ?? ""
        let pic = Self.matchFirst(
            in: html,
            pattern: #"<div[^>]*class=\"[^\"]*detail-top[^\"]*\"[^>]*>[\s\S]*?<img[^>]*src=\"([^\"]+)\""#
        ) ?? ""
        let intro = (Self.matchFirst(
            in: html,
            pattern: #"<div[^>]*class=\"[^\"]*book-intro[^\"]*tab-cont[^\"]*\"[^>]*>([\s\S]*?)</div>"#
        ) ?? "").wbStripHTML

        let episodes = Self.parseEpisodeLinks(html)

        var payload: [String: Any] = [
            "vod_id": id,
            "vod_name": name,
            "vod_pic": pic,
            "vod_content": intro
        ]

        if !episodes.isEmpty {
            payload["vod_play_from"] = "在线播放"
            payload["vod_play_url"] = episodes.joined(separator: "#")
        }

        return [WebsiteBundleVod.makeVodInfo(payload: payload, fallbackId: id, fallbackName: name)]
    }

    func searchContent(keyword: String, quick: Bool, page: Int) async throws -> [MovieItem] {
        guard !keyword.isEmpty else { return [] }
        let url = "\(pcBase)/search/index/search?content=\(keyword.wbUrlEncoded)&type=1&pageNum=\(page)&pageSize=10"
        let json = try await WebsiteBundleHttp.getJSON(url, headers: Self.pcHeaders())
        let content = (json["data"] as? [String: Any])?["content"] as? [[String: Any]] ?? []
        return content.compactMap { item in
            let name = item.wbString("name").wbStripHTML
            let code = item.wbString("code")
            guard !name.isEmpty, !code.isEmpty else { return nil }
            let cover = item.wbString("coverUrlLocal")
            return MovieItem(
                vodId: "/list/\(code)",
                vodName: name,
                vodPic: cover.isEmpty ? nil : "http://img.5weiting.com:20001/\(cover)",
                vodRemarks: item.wbStringOrNil("broadcaster")
            )
        }
    }

    func playerContent(flag: String, id: String, vipFlags: [String]) async throws -> PlayerContent {
        // id 形如 `/list/<code>/<no>`
        let parts = id.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count >= 3 else { return PlayerContent() }
        let code = String(parts[1])
        let no = String(parts[2])
        let ts = String(Int(Date().timeIntervalSince1970 * 1000))
        let sign = WebsiteBundleCrypto.md5Hex(ts + code + no + "FRDSHFSKVKSKFKS")
        let url = "\(pcBase)/web/index/video_new?code=\(code)&no=\(no)&type=0&timestamp=\(ts)&sign=\(sign)"
        let json = try await WebsiteBundleHttp.getJSON(url, headers: Self.pcHeaders())
        let data = json["data"] as? [String: Any] ?? [:]
        return PlayerContent(url: data.wbString("videoUrl"), header: Self.pcHeaders(), parse: 0)
    }

    var supportsQuickSearch: Bool { site.isQuickSearchable }

    func destroy() {
        isInitialized = false
    }

    // MARK: - HTML parsing

    private static func parseCategoryHTML(_ html: String) -> [MovieItem] {
        // 用 `ul.album-list` 下的 `<li>` 块做分段
        let liPattern = #"<li[^>]*>([\s\S]*?)</li>"#
        let items = matchAll(in: html, pattern: liPattern)
        return items.compactMap { block -> MovieItem? in
            guard let href = matchFirst(in: block, pattern: #"class=\"book-item-img[^\"]*\"[\s\S]*?href=\"([^\"]+)\""#)
                  ?? matchFirst(in: block, pattern: #"href=\"(/list/[^\"]+)\""#),
                  let img = matchFirst(in: block, pattern: #"<img[^>]*src=\"([^\"]+)\""#),
                  let alt = matchFirst(in: block, pattern: #"<img[^>]*alt=\"([^\"]+)\""#) else {
                return nil
            }
            let status = matchFirst(in: block, pattern: #"book-item-status[^>]*>([^<]*)</div>"#) ?? ""
            let remarks = status.replacingOccurrences(of: "状态：", with: "").trimmingCharacters(in: .whitespaces)
            return MovieItem(
                vodId: href,
                vodName: alt.wbStripHTML,
                vodPic: img,
                vodRemarks: remarks.isEmpty ? nil : remarks
            )
        }
    }

    private static func parseEpisodeLinks(_ html: String) -> [String] {
        // 以 book-list-wrapper 容器内的 <a> 链接为剧集
        let wrapper = matchFirst(
            in: html,
            pattern: #"<div[^>]*class=\"[^\"]*book-list-wrapper[^\"]*\"[^>]*>([\s\S]*?)</div>\s*</div>"#
        ) ?? html
        let linkPattern = #"<a[^>]*href=\"([^\"]+)\"[^>]*>([\s\S]*?)</a>"#
        return matchAllGroups(in: wrapper, pattern: linkPattern).compactMap { groups in
            guard groups.count >= 3 else { return nil }
            let href = groups[1]
            let text = groups[2].wbStripHTML
            guard !href.isEmpty, !text.isEmpty else { return nil }
            return "\(text)$\(href)"
        }
    }

    private static func matchFirst(in source: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(source.startIndex..., in: source)
        guard let match = regex.firstMatch(in: source, options: [], range: range),
              match.numberOfRanges >= 2,
              let group = Range(match.range(at: 1), in: source) else {
            return nil
        }
        return String(source[group])
    }

    private static func matchAll(in source: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(source.startIndex..., in: source)
        return regex.matches(in: source, range: range).compactMap { match in
            guard match.numberOfRanges >= 2,
                  let group = Range(match.range(at: 1), in: source) else {
                return nil
            }
            return String(source[group])
        }
    }

    private static func matchAllGroups(in source: String, pattern: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(source.startIndex..., in: source)
        return regex.matches(in: source, range: range).map { match in
            (0..<match.numberOfRanges).map { idx -> String in
                guard let range = Range(match.range(at: idx), in: source) else { return "" }
                return String(source[range])
            }
        }
    }

    private static func pcHeaders() -> [String: String] {
        [
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Referer": "http://www.5weiting.com"
        ]
    }

    private static func mobileHeaders() -> [String: String] {
        [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 15_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.2 Mobile/15E148 Safari/604.1"
        ]
    }
}
