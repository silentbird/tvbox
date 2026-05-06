import Foundation

/// 星芽短剧（dongli）— 独立 API，初始化时登录换 Bearer token。
final class DongliNativeSpider: WebsiteBundleNativeSpider {
    let siteKey: String
    private let site: SiteBean
    private let baseURL = "https://app.whjzjx.cn"
    private let loginURL = "https://u.shytkjgs.com/user/v3/account/login"
    private let aesKey = "B@ecf920Od8A4df7"
    private var authorization = ""
    private var isInitialized = false

    init(site: SiteBean) {
        self.site = site
        self.siteKey = site.key
    }

    func initialize(ext: String?) async throws {
        try await login()
        isInitialized = true
    }

    private func login() async throws {
        let now = Int(Date().timeIntervalSince1970 * 1000)
        let payload: [String: Any] = [
            "first_install_time": now,
            "last_update_time": now,
            "install_first_open": true,
            "package_name": "com.jz.xydj",
            "device": WebsiteBundleCrypto.md5Hex("\(now)"),
            "timestamp": now
        ]
        guard let payloadData = try? JSONSerialization.data(withJSONObject: payload),
              let keyData = aesKey.data(using: .utf8),
              let encrypted = WebsiteBundleCrypto.aesEcbEncrypt(payloadData, key: keyData) else {
            throw SpiderError.scriptError("dongli: 构造初始化请求失败")
        }
        let body = encrypted.base64EncodedString()
        let headers: [String: String] = [
            "User-Agent": "okhttp/4.10.0",
            "platform": "1",
            "version_name": "3.9.2",
            "Content-Type": "application/json; charset=utf-8"
        ]

        guard let url = WebsiteBundleHttp.makeURL(loginURL) else {
            throw SpiderError.scriptError("dongli: 登录 URL 无效")
        }
        // /login 的 transformRequest 是 identity — 直接把 base64 串作为裸 body 发过去。
        let data = try await HttpUtil.shared.postJson(url: url, json: body, headers: headers)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataField = json["data"] as? [String: Any],
              let token = dataField["token"] as? String else {
            throw SpiderError.scriptError("dongli: 登录响应缺少 token")
        }
        authorization = token
    }

    private func authHeaders() -> [String: String] {
        [
            "User-Agent": "okhttp/4.10.0",
            "platform": "1",
            "version_name": "3.9.2",
            "Authorization": authorization
        ]
    }

    func homeContent(filter: Bool) async throws -> HomeContent {
        let json = try await WebsiteBundleHttp.getJSON("\(baseURL)/cloud/v2/theater/classes", headers: authHeaders())
        let list = (json["data"] as? [String: Any])?["list"] as? [[String: Any]] ?? []

        var categories: [MovieCategory] = []
        var filters: [String: [MovieFilter]] = [:]

        for cls in list {
            let showType = cls.wbString("show_type")
            if showType.contains("Bookstore") { continue }
            let id = cls.wbString("id").wbNilIfEmpty ?? "\(cls.wbInt("id"))"
            let name = cls.wbString("type_name").wbNilIfEmpty ?? cls.wbString("class_name")
            if name.isEmpty { continue }
            categories.append(MovieCategory(tid: id, name: name))

            var classFilters: [MovieFilter] = []
            if let algList = (cls["alg_class"] as? [[String: Any]]) {
                let values = algList.map { item in
                    MovieFilterValue(
                        n: item.wbString("class_name").wbNilIfEmpty ?? item.wbString("name"),
                        v: item.wbString("id")
                    )
                }
                if !values.isEmpty {
                    classFilters.append(MovieFilter(key: "class", name: "分类", values: values))
                }
            }
            if let rankList = (cls["first_level_ranking"] as? [[String: Any]]) {
                let values = rankList.map { item in
                    MovieFilterValue(
                        n: item.wbString("class_name").wbNilIfEmpty ?? item.wbString("name"),
                        v: item.wbString("id")
                    )
                }
                if !values.isEmpty {
                    classFilters.append(MovieFilter(key: "rank", name: "排行", values: values))
                }
            }
            if !classFilters.isEmpty {
                filters[id] = classFilters
            }
        }

        return HomeContent(categories: categories, videos: [], filters: filter ? filters : [:])
    }

    func categoryContent(tid: String, page: Int, filter: Bool, extend: [String: String]) async throws -> CategoryContent {
        let classId = extend["class"]?.wbNilIfEmpty ?? "0"
        let rank = extend["rank"]?.wbNilIfEmpty ?? "1"
        let items: [[String: Any]]
        if tid == "9" {
            if page > 1 {
                return CategoryContent(videos: [], page: page, pageCount: page, total: 0)
            }
            let json = try await WebsiteBundleHttp.getJSON(
                "\(baseURL)/cloud/v1/first_level_ranking/detail?id=\(rank)",
                headers: authHeaders()
            )
            items = (json["data"] as? [[String: Any]]) ?? []
        } else {
            let url = "\(baseURL)/cloud/v2/theater/home_page?theater_class_id=\(tid)&class2_ids=\(classId)&type=1&page_num=\(page)&page_size=24"
            let json = try await WebsiteBundleHttp.getJSON(url, headers: authHeaders())
            items = (json["data"] as? [[String: Any]]) ?? []
        }

        let videos: [MovieItem] = items.compactMap { wrapper in
            let theater = (wrapper["theater"] as? [String: Any]) ?? wrapper
            let id = theater.wbString("id")
            let name = theater.wbString("title")
            guard !id.isEmpty, !name.isEmpty else { return nil }
            let total = theater.wbInt("total")
            let remarks = total > 0 ? "\(total)集" : nil
            return MovieItem(
                vodId: id,
                vodName: name,
                vodPic: theater.wbStringOrNil("cover_url"),
                vodRemarks: remarks
            )
        }

        let pageCount = videos.count < 24 ? page : page + 1
        return CategoryContent(videos: videos, page: page, pageCount: pageCount, total: pageCount * 24)
    }

    func detailContent(ids: [String]) async throws -> [VodInfo] {
        guard let id = ids.first, !id.isEmpty else { return [] }
        let url = "\(baseURL)/v2/theater_parent/detail?theater_parent_id=\(id.wbUrlEncoded)"
        let json = try await WebsiteBundleHttp.getJSON(url, headers: authHeaders())
        let data = (json["data"] as? [String: Any]) ?? [:]

        let title = data.wbString("title")
        let cover = data.wbString("cover_url")
        let typeName = (data["desc_tags"] as? [String])?.joined(separator: ",").replacingOccurrences(of: "\"", with: "") ?? ""
        let intro = data.wbString("introduction")

        let theaters = (data["theaters"] as? [[String: Any]]) ?? []
        let episodes = theaters.compactMap { t -> String? in
            let num = t.wbInt("num")
            let url = t.wbString("son_video_url")
            guard !url.isEmpty else { return nil }
            return "\(num)$\(url)"
        }

        var payload: [String: Any] = [
            "vod_id": id,
            "vod_name": title,
            "vod_pic": cover,
            "type_name": typeName,
            "vod_content": intro
        ]
        if !episodes.isEmpty {
            payload["vod_play_from"] = "在线播放"
            payload["vod_play_url"] = episodes.joined(separator: "#")
        }

        return [WebsiteBundleVod.makeVodInfo(payload: payload, fallbackId: id, fallbackName: title)]
    }

    func searchContent(keyword: String, quick: Bool, page: Int) async throws -> [MovieItem] {
        guard !keyword.isEmpty else { return [] }
        let json = try await WebsiteBundleHttp.postJSONObject(
            "\(baseURL)/v3/search",
            body: ["text": keyword],
            headers: authHeaders()
        )
        let theaterData = (((json["data"] as? [String: Any])?["theater"] as? [String: Any])?["search_data"]) as? [[String: Any]] ?? []
        return theaterData.compactMap { item in
            let id = item.wbString("id")
            let name = item.wbString("title")
            guard !id.isEmpty, !name.isEmpty else { return nil }
            return MovieItem(
                vodId: id,
                vodName: name,
                vodPic: item.wbStringOrNil("cover_url"),
                vodRemarks: item.wbStringOrNil("score_str")
            )
        }
    }

    func playerContent(flag: String, id: String, vipFlags: [String]) async throws -> PlayerContent {
        // id 本身就是 son_video_url，直接播。
        PlayerContent(url: id, header: nil, parse: 0)
    }

    var supportsQuickSearch: Bool { site.isQuickSearchable }

    func destroy() {
        isInitialized = false
    }
}
