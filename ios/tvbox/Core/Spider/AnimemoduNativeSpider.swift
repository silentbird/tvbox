import Foundation

/// 魔都动漫（animemodu）— 基于 MacCMS 通用接口的简单适配。
/// 所有请求只携带 PC 端浏览器 UA，无鉴权。
final class AnimemoduNativeSpider: WebsiteBundleNativeSpider {
    let siteKey: String
    private let site: SiteBean
    private let baseURL = "https://www.mdzyapi.com/api.php/provide/vod"
    private var isInitialized = false

    init(site: SiteBean) {
        self.site = site
        self.siteKey = site.key
    }

    func initialize(ext: String?) async throws {
        isInitialized = true
    }

    func homeContent(filter: Bool) async throws -> HomeContent {
        precondition(isInitialized, "Animemodu spider not initialized")
        let categories = [
            MovieCategory(tid: "1", name: "国产动漫"),
            MovieCategory(tid: "2", name: "日韩动漫"),
            MovieCategory(tid: "3", name: "欧美动漫"),
            MovieCategory(tid: "4", name: "港台动漫"),
            MovieCategory(tid: "5", name: "动漫电影")
        ]
        return HomeContent(categories: categories, videos: [], filters: [:])
    }

    func categoryContent(tid: String, page: Int, filter: Bool, extend: [String: String]) async throws -> CategoryContent {
        let url = "\(baseURL)?ac=detail&t=\(tid)&pg=\(page)"
        let json = try await WebsiteBundleHttp.getJSON(url, headers: Self.headers())
        let videos = Self.parseList(json["list"] as? [[String: Any]] ?? [])
        let pagecount = json.wbInt("pagecount") == 0 ? 1 : json.wbInt("pagecount")
        let limit = json.wbInt("limit") == 0 ? 20 : json.wbInt("limit")
        return CategoryContent(
            videos: videos,
            page: page,
            pageCount: pagecount,
            total: json.wbInt("total") == 0 ? pagecount * limit : json.wbInt("total")
        )
    }

    func detailContent(ids: [String]) async throws -> [VodInfo] {
        guard let id = ids.first, !id.isEmpty else { return [] }
        let url = "\(baseURL)?ac=detail&ids=\(id.wbUrlEncoded)"
        let json = try await WebsiteBundleHttp.getJSON(url, headers: Self.headers())
        guard let first = (json["list"] as? [[String: Any]])?.first else { return [] }

        var payload: [String: Any] = [
            "vod_id": id,
            "vod_name": first.wbString("vod_name"),
            "vod_pic": first.wbString("vod_pic"),
            "vod_year": first.wbString("vod_year"),
            "vod_content": first.wbString("vod_content"),
            "vod_director": first.wbString("vod_director"),
            "vod_actor": first.wbString("vod_actor"),
            "vod_area": first.wbString("vod_area"),
            "vod_remarks": first.wbString("vod_remarks"),
            "type_name": first.wbString("type_name")
        ]

        let rawPlayFrom = first.wbString("vod_play_from")
        let rawPlayUrl = first.wbString("vod_play_url")
        if !rawPlayUrl.isEmpty {
            payload["vod_play_from"] = rawPlayFrom.isEmpty ? "在线播放" : rawPlayFrom
            payload["vod_play_url"] = rawPlayUrl
        }

        return [WebsiteBundleVod.makeVodInfo(payload: payload, fallbackId: id, fallbackName: first.wbString("vod_name"))]
    }

    func searchContent(keyword: String, quick: Bool, page: Int) async throws -> [MovieItem] {
        guard !keyword.isEmpty else { return [] }
        let url = "\(baseURL)/?ac=detail&pg=\(page)&wd=\(keyword.wbUrlEncoded)"
        let json = try await WebsiteBundleHttp.getJSON(url, headers: Self.headers())
        return Self.parseList(json["list"] as? [[String: Any]] ?? [])
    }

    func playerContent(flag: String, id: String, vipFlags: [String]) async throws -> PlayerContent {
        PlayerContent(url: id, header: Self.headers(), parse: 0)
    }

    var supportsQuickSearch: Bool { site.isQuickSearchable }

    func destroy() {
        isInitialized = false
    }

    private static func parseList(_ list: [[String: Any]]) -> [MovieItem] {
        list.compactMap { item in
            let name = item.wbString("vod_name")
            let id = item.wbString("vod_id")
            guard !name.isEmpty, !id.isEmpty else { return nil }
            return MovieItem(
                vodId: id,
                vodName: name,
                vodPic: item.wbStringOrNil("vod_pic"),
                vodRemarks: item.wbStringOrNil("vod_remarks")
            )
        }
    }

    private static func headers() -> [String: String] {
        [
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36"
        ]
    }
}
