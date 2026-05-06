import Foundation

/// 小薇短剧（duanjuweiguan）— 纯 REST + base64 承载的多分辨率地址。
final class DuanjuweiguanNativeSpider: WebsiteBundleNativeSpider {
    let siteKey: String
    private let site: SiteBean
    private let baseURL = "https://api.drama.9ddm.com/drama/home"
    private var clientInfo = ""
    private var isInitialized = false

    init(site: SiteBean) {
        self.site = site
        self.siteKey = site.key
    }

    func initialize(ext: String?) async throws {
        // clientInfo = MD5(十位随机字母数字)，每次进程启动生成一次。
        let seed = Self.randomAlnum(length: 10)
        clientInfo = WebsiteBundleCrypto.md5Hex(seed)
        isInitialized = true
    }

    func homeContent(filter: Bool) async throws -> HomeContent {
        let url = "\(baseURL)/shortVideoTags?\(commonQuery())"
        let json = try await WebsiteBundleHttp.getJSON(url, headers: Self.headers())
        let tags = (json["tags"] as? [String]) ?? []
        let categories = tags.map { MovieCategory(tid: $0, name: $0) }
        return HomeContent(categories: categories, videos: [], filters: [:])
    }

    func categoryContent(tid: String, page: Int, filter: Bool, extend: [String: String]) async throws -> CategoryContent {
        let url = "\(baseURL)/search?\(commonQuery())"
        let body: [String: Any] = [
            "audience": "全部",
            "order": "最新",
            "page": page,
            "pageSize": 30,
            "searchWord": "",
            "subject": tid
        ]
        let json = try await WebsiteBundleHttp.postJSONObject(url, body: body, headers: Self.headers())
        let list = Self.parseList(json["data"] as? [[String: Any]] ?? [])
        let pageCount = list.count < 30 ? page : page + 1
        return CategoryContent(videos: list, page: page, pageCount: pageCount, total: pageCount * 30)
    }

    func detailContent(ids: [String]) async throws -> [VodInfo] {
        guard let id = ids.first, !id.isEmpty else { return [] }
        let url = "\(baseURL)/shortVideoDetail?\(commonQuery())&oneId=\(id.wbUrlEncoded)&page=1&pageSize=10&userId=0&queryAll=true"
        let json = try await WebsiteBundleHttp.getJSON(url, headers: Self.headers())

        let items = json.wbArray("data").compactMap { $0 as? [String: Any] }
        let episodes = items.compactMap { item -> String? in
            let order = item.wbInt("playOrder")
            let clarity = item.wbArray("videoClarityList")
            guard JSONSerialization.isValidJSONObject(clarity),
                  let data = try? JSONSerialization.data(withJSONObject: clarity) else {
                return nil
            }
            let encoded = data.base64EncodedString()
            return "\(order)$\(encoded)"
        }

        var payload: [String: Any] = [
            "vod_id": id,
            "vod_name": json.wbString("title"),
            "vod_pic": json.wbString("vertPoster"),
            "vod_content": json.wbString("description")
        ]
        if !episodes.isEmpty {
            payload["vod_play_from"] = "在线播放"
            payload["vod_play_url"] = episodes.joined(separator: "#")
        }
        return [WebsiteBundleVod.makeVodInfo(payload: payload, fallbackId: id, fallbackName: json.wbString("title"))]
    }

    func searchContent(keyword: String, quick: Bool, page: Int) async throws -> [MovieItem] {
        guard !keyword.isEmpty else { return [] }
        let url = "\(baseURL)/search?\(commonQuery())"
        let body: [String: Any] = [
            "audience": "",
            "order": "",
            "page": page,
            "pageSize": 30,
            "searchWord": keyword,
            "subject": ""
        ]
        let json = try await WebsiteBundleHttp.postJSONObject(url, body: body, headers: Self.headers())
        return Self.parseList(json["data"] as? [[String: Any]] ?? [])
    }

    func playerContent(flag: String, id: String, vipFlags: [String]) async throws -> PlayerContent {
        guard let data = Data(base64Encoded: id),
              let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return PlayerContent(url: id, header: Self.headers(), parse: 0)
        }

        // 多清晰度时返回 AVPlayer 可识别的 name/url 交替数组（转 JSON 字符串）。
        var pairs: [String] = []
        for item in list {
            let name = item.wbString("name")
            let url = item.wbString("videoUrl").wbNilIfEmpty ?? item.wbString("url")
            guard !url.isEmpty else { continue }
            pairs.append(name.isEmpty ? "默认" : name)
            pairs.append(url)
        }

        if pairs.count >= 2 {
            if pairs.count == 2 {
                return PlayerContent(url: pairs[1], header: Self.headers(), parse: 0)
            }
            let jsonData = (try? JSONSerialization.data(withJSONObject: pairs)) ?? Data()
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
            return PlayerContent(url: pairs[1], header: Self.headers(), parse: 0, playUrl: jsonString)
        }

        return PlayerContent(url: id, header: Self.headers(), parse: 0)
    }

    var supportsQuickSearch: Bool { site.isQuickSearchable }

    func destroy() {
        isInitialized = false
    }

    // MARK: - helpers

    private func commonQuery() -> String {
        let device = "Pixel 8 Pro".wbUrlEncoded
        let firm = "Google".wbUrlEncoded
        return [
            "version_code=1500",
            "version_name=1.5.0",
            "device_name=\(device)",
            "device_type=phone",
            "is_first_day=true",
            "is_first_24h=true",
            "app_launch_way=icon",
            "default_homepage=homepage_interaction",
            "device_owning_firm=\(firm)",
            "font_scale=default",
            "os_type=1",
            "clientInfo=\(clientInfo)"
        ].joined(separator: "&")
    }

    private static func parseList(_ list: [[String: Any]]) -> [MovieItem] {
        list.compactMap { item in
            let name = item.wbString("title")
            let id = item.wbString("oneId")
            guard !name.isEmpty, !id.isEmpty else { return nil }
            let episodeCount = item.wbInt("episodeCount")
            let remarks = episodeCount > 0 ? "\(episodeCount)集" : nil
            return MovieItem(
                vodId: id,
                vodName: name,
                vodPic: item.wbStringOrNil("horzPoster") ?? item.wbStringOrNil("vertPoster"),
                vodRemarks: remarks
            )
        }
    }

    private static func randomAlnum(length: Int) -> String {
        let alphabet = Array("0123456789abcdefghijklmnopqrstuvwxyz")
        return String((0..<length).map { _ in alphabet.randomElement()! })
    }

    private static func headers() -> [String: String] {
        [
            "User-Agent": "okhttp/5.1.0",
            "Content-Type": "application/json; charset=utf-8"
        ]
    }
}
