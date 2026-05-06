import Foundation

/// 哔哩哔哩集合（bili）— 精简移植：只支持 `mp4` flag 的 durl 直链方案。
/// DASH/MPD 组装依赖本地 HTTP 代理，在 iOS 端暂时不实现。
final class BiliNativeSpider: WebsiteBundleNativeSpider {
    let siteKey: String
    private let site: SiteBean
    private let apiBase = "https://api.bilibili.com"
    private let webBase = "https://www.bilibili.com"

    private var cookie: String = ""
    private var isLoggedIn: Bool = false
    private var isVip: Bool = false
    private var isInitialized = false

    init(site: SiteBean) {
        self.site = site
        self.siteKey = site.key
    }

    func initialize(ext: String?) async throws {
        await bootstrapCookie()
        await bootstrapLoginStatus()
        isInitialized = true
    }

    private func bootstrapCookie() async {
        guard let url = URL(string: webBase) else { return }
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                let headers = http.allHeaderFields as? [String: String] ?? [:]
                if let rawCookie = headers["Set-Cookie"] ?? headers["set-cookie"] {
                    let parts = rawCookie.components(separatedBy: ",").compactMap { chunk -> String? in
                        let piece = chunk.split(separator: ";").first.map(String.init) ?? chunk
                        return piece.trimmingCharacters(in: .whitespaces)
                    }
                    cookie = parts.joined(separator: "; ")
                }
            }
        } catch {
            AppLogger.debug("[BiliNativeSpider] cookie bootstrap 失败: \(error.localizedDescription)")
        }
    }

    private func bootstrapLoginStatus() async {
        let json = (try? await WebsiteBundleHttp.getJSON(
            "\(apiBase)/x/web-interface/nav",
            headers: headers()
        )) ?? [:]
        let data = (json["data"] as? [String: Any]) ?? [:]
        isLoggedIn = data.wbInt("isLogin") != 0 || (data["isLogin"] as? Bool) == true
        isVip = data.wbInt("vipStatus") != 0
    }

    func homeContent(filter: Bool) async throws -> HomeContent {
        let tags = [
            "首页", "动画", "游戏", "音乐", "舞蹈", "知识", "科技", "运动",
            "生活", "美食", "影视", "娱乐", "时尚", "动物圈", "鬼畜"
        ]
        let categories = tags.map { MovieCategory(tid: $0, name: $0) }

        let filters: [String: [MovieFilter]] = {
            guard filter else { return [:] }
            let orderValues = [
                MovieFilterValue(n: "综合排序", v: "0"),
                MovieFilterValue(n: "最多点击", v: "click"),
                MovieFilterValue(n: "最新发布", v: "pubdate"),
                MovieFilterValue(n: "最多弹幕", v: "dm"),
                MovieFilterValue(n: "最多收藏", v: "stow")
            ]
            let durationValues = [
                MovieFilterValue(n: "全部时长", v: "0"),
                MovieFilterValue(n: "60分钟以上", v: "4"),
                MovieFilterValue(n: "30~60分钟", v: "3"),
                MovieFilterValue(n: "10~30分钟", v: "2"),
                MovieFilterValue(n: "10分钟以下", v: "1")
            ]
            let perTag = [
                MovieFilter(key: "order", name: "排序", values: orderValues),
                MovieFilter(key: "duration", name: "时长", values: durationValues)
            ]
            return Dictionary(uniqueKeysWithValues: tags.map { ($0, perTag) })
        }()

        return HomeContent(categories: categories, videos: [], filters: filters)
    }

    func categoryContent(tid: String, page: Int, filter: Bool, extend: [String: String]) async throws -> CategoryContent {
        let videos: [MovieItem]
        if tid == "首页" {
            let json = try await WebsiteBundleHttp.getJSON(
                "\(apiBase)/x/web-interface/index/top/rcmd?ps=14&fresh_idx=\(page)&fresh_idx_1h=\(page)",
                headers: headers()
            )
            let list = ((json["data"] as? [String: Any])?["item"] as? [[String: Any]]) ?? []
            videos = Self.parseList(list)
        } else {
            let order = extend["order"] ?? "0"
            let duration = extend["duration"] ?? "0"
            let url = "\(apiBase)/x/web-interface/search/type?search_type=video&keyword=\(tid.wbUrlEncoded)&order=\(order == "0" ? "" : order)&duration=\(duration)&page=\(page)"
            let json = try await WebsiteBundleHttp.getJSON(url, headers: headers())
            let list = ((json["data"] as? [String: Any])?["result"] as? [[String: Any]]) ?? []
            videos = Self.parseList(list)
        }
        return CategoryContent(videos: videos, page: page, pageCount: page + 1, total: (page + 1) * 14)
    }

    func detailContent(ids: [String]) async throws -> [VodInfo] {
        guard let bvid = ids.first, !bvid.isEmpty else { return [] }
        let view = try await WebsiteBundleHttp.getJSON(
            "\(apiBase)/x/web-interface/view?bvid=\(bvid)",
            headers: headers()
        )
        guard let data = view["data"] as? [String: Any] else { return [] }
        let aid = data.wbInt("aid")
        let title = data.wbString("title")
        let pic = data.wbString("pic")
        let desc = data.wbString("desc")
        let tname = data.wbString("tname")
        let duration = data.wbInt("duration")

        let pages = (data["pages"] as? [[String: Any]]) ?? []
        let episodes: [String] = pages.enumerated().compactMap { (idx, page) in
            let cid = page.wbInt("cid")
            guard cid != 0 else { return nil }
            return "\(idx + 1)$\(aid)+\(cid)"
        }

        var payload: [String: Any] = [
            "vod_id": bvid,
            "vod_name": title,
            "vod_pic": pic,
            "type_name": tname,
            "vod_remarks": Self.formatDuration(duration),
            "vod_content": desc
        ]
        if !episodes.isEmpty {
            payload["vod_play_from"] = "mp4"
            payload["vod_play_url"] = episodes.joined(separator: "#")
        }
        return [WebsiteBundleVod.makeVodInfo(payload: payload, fallbackId: bvid, fallbackName: title)]
    }

    func searchContent(keyword: String, quick: Bool, page: Int) async throws -> [MovieItem] {
        guard !keyword.isEmpty else { return [] }
        let url = "\(apiBase)/x/web-interface/search/type?search_type=video&keyword=\(keyword.wbUrlEncoded)&duration=0&page=\(page)"
        let json = try await WebsiteBundleHttp.getJSON(url, headers: headers())
        let list = ((json["data"] as? [String: Any])?["result"] as? [[String: Any]]) ?? []
        return Self.parseList(list)
    }

    func playerContent(flag: String, id: String, vipFlags: [String]) async throws -> PlayerContent {
        let parts = id.components(separatedBy: "+")
        guard parts.count >= 2,
              let aid = Int(parts[0]),
              let cid = Int(parts[1]) else {
            return PlayerContent()
        }
        // 采用 qn=32（480p）或 64（720p）挑最高可用：未登录限 <=32；登录非VIP <=80；VIP 可 120。
        let qn = isVip ? 112 : (isLoggedIn ? 80 : 32)
        let url = "\(apiBase)/x/player/playurl?avid=\(aid)&cid=\(cid)&qn=\(qn)&fnval=1&fourk=1"
        let json = try await WebsiteBundleHttp.getJSON(url, headers: headers())
        let data = (json["data"] as? [String: Any]) ?? [:]
        let durl = (data["durl"] as? [[String: Any]]) ?? []
        let playUrl = durl.first?.wbString("url") ?? ""
        return PlayerContent(
            url: playUrl,
            header: Self.playerHeaders(),
            parse: 0
        )
    }

    var supportsQuickSearch: Bool { site.isQuickSearchable }

    func destroy() {
        isInitialized = false
    }

    // MARK: - helpers

    private func headers() -> [String: String] {
        var headers: [String: String] = ["User-Agent": Self.userAgent]
        if !cookie.isEmpty {
            headers["cookie"] = cookie
        }
        return headers
    }

    private static func parseList(_ list: [[String: Any]]) -> [MovieItem] {
        list.compactMap { item in
            let bvid = item.wbString("bvid")
            let name = item.wbString("title").wbStripHTML
            guard !bvid.isEmpty, !name.isEmpty else { return nil }
            var pic = item.wbString("pic")
            if pic.hasPrefix("//") { pic = "https:\(pic)" }
            return MovieItem(
                vodId: bvid,
                vodName: name,
                vodPic: pic.isEmpty ? nil : pic,
                vodRemarks: formatDuration(item.wbInt("duration"))
            )
        }
    }

    private static func formatDuration(_ seconds: Int) -> String? {
        guard seconds > 0 else { return nil }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return "\(h)小时\(m)分钟" }
        if m > 0 { return "\(m)分钟\(s)秒" }
        return "\(s)秒"
    }

    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36"

    private static func playerHeaders() -> [String: String] {
        [
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36",
            "Referer": "https://www.bilibili.com"
        ]
    }
}
