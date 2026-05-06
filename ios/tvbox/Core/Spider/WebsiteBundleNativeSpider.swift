import Foundation

protocol WebsiteBundleNativeSpider: Spider {}

enum WebsiteBundleNativeSpiderFactory {
    static func make(site: SiteBean) -> WebsiteBundleNativeSpider? {
        guard let adapter = adapterKey(for: site) else {
            return nil
        }

        switch adapter {
        case "wexDuBoKu":
            return WexDuBoKuNativeSpider(site: site)
        case "wexYueYue":
            return WexYueYueNativeSpider(site: site)
        case "animemodu":
            return AnimemoduNativeSpider(site: site)
        case "dongli":
            return DongliNativeSpider(site: site)
        case "duanjuweiguan":
            return DuanjuweiguanNativeSpider(site: site)
        case "hanxiaoquan":
            return HanxiaoquanNativeSpider(site: site)
        case "bookWuWei":
            return BookWuWeiNativeSpider(site: site)
        case "bili":
            return BiliNativeSpider(site: site)
        default:
            return nil
        }
    }

    /// 给 `ApiConfig` 用于判断某个 WebsiteBundle 子站点是否已有原生适配。
    static func hasAdapter(forKey key: String) -> Bool {
        supportedKeys.contains(key)
    }

    static let supportedKeys: Set<String> = [
        "wexDuBoKu",
        "wexYueYue",
        "animemodu",
        "dongli",
        "duanjuweiguan",
        "hanxiaoquan",
        "bookWuWei",
        "bili"
    ]

    private static func adapterKey(for site: SiteBean) -> String? {
        if let ext = site.ext,
           let data = ext.data(using: .utf8),
           let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let adapter = payload["nativeAdapter"] as? String,
           !adapter.isEmpty {
            return supportedKeys.contains(adapter) ? adapter : nil
        }

        // 历史配置：旧的站点 key 直接命中 wexDuBoKu。
        if site.key == "nodejs_wexDuBoKu" ||
            site.api.contains("/spider/wexDuBoKu/") ||
            site.api.contains("#/spider/wexDuBoKu/") {
            return "wexDuBoKu"
        }

        // 其它适配器仅通过 ext.nativeAdapter 匹配，避免误识别。
        return nil
    }
}

// MARK: - Shared helpers

extension Dictionary where Key == String, Value == Any {
    func wbString(_ key: String) -> String {
        if let value = self[key] as? String {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.stringValue
        }
        return ""
    }

    func wbStringOrNil(_ key: String) -> String? {
        if let value = self[key] as? String, !value.isEmpty {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.stringValue
        }
        return nil
    }

    func wbInt(_ key: String) -> Int {
        if let value = self[key] as? Int {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.intValue
        }
        if let value = self[key] as? String, let parsed = Int(value) {
            return parsed
        }
        return 0
    }

    func wbArray(_ key: String) -> [Any] {
        self[key] as? [Any] ?? []
    }

    func wbDict(_ key: String) -> [String: Any] {
        self[key] as? [String: Any] ?? [:]
    }

    func wbStringArray(_ key: String) -> [String] {
        wbArray(key).compactMap { value in
            if let string = value as? String { return string }
            if let number = value as? NSNumber { return number.stringValue }
            return nil
        }
    }
}

extension String {
    var wbNilIfEmpty: String? {
        isEmpty ? nil : self
    }

    func wbCharacter(at offset: Int) -> Character {
        self[index(startIndex, offsetBy: offset)]
    }

    var wbStripHTML: String {
        replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var wbUrlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}

enum WebsiteBundleHttp {
    static func makeURL(_ value: String) -> URL? {
        if let url = URL(string: value) {
            return url
        }
        let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: "%3A", with: ":")
            .replacingOccurrences(of: "%2F", with: "/")
            .replacingOccurrences(of: "%3F", with: "?")
            .replacingOccurrences(of: "%3D", with: "=")
            .replacingOccurrences(of: "%26", with: "&")
        return encoded.flatMap(URL.init(string:))
    }

    static func getJSON(
        _ urlString: String,
        headers: [String: String] = [:],
        http: HttpUtil = .shared
    ) async throws -> [String: Any] {
        let data = try await getData(urlString, headers: headers, http: http)
        return (try JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    static func getJSONArray(
        _ urlString: String,
        headers: [String: String] = [:],
        http: HttpUtil = .shared
    ) async throws -> [[String: Any]] {
        let data = try await getData(urlString, headers: headers, http: http)
        return (try JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []
    }

    static func getData(
        _ urlString: String,
        headers: [String: String] = [:],
        http: HttpUtil = .shared
    ) async throws -> Data {
        guard let url = makeURL(urlString) else {
            throw SpiderError.scriptError("WebsiteBundle 适配层 URL 无效: \(urlString)")
        }
        return try await http.data(url: url, headers: headers)
    }

    static func getString(
        _ urlString: String,
        headers: [String: String] = [:],
        http: HttpUtil = .shared
    ) async throws -> String {
        guard let url = makeURL(urlString) else {
            throw SpiderError.scriptError("WebsiteBundle 适配层 URL 无效: \(urlString)")
        }
        return try await http.string(url: url, headers: headers)
    }

    static func postJSON(
        _ urlString: String,
        body: Any,
        headers: [String: String] = [:],
        http: HttpUtil = .shared
    ) async throws -> Data {
        guard let url = makeURL(urlString) else {
            throw SpiderError.scriptError("WebsiteBundle 适配层 URL 无效: \(urlString)")
        }
        let data = try JSONSerialization.data(withJSONObject: body)
        let jsonString = String(data: data, encoding: .utf8) ?? "{}"
        var merged = headers
        merged["Content-Type"] = merged["Content-Type"] ?? "application/json; charset=utf-8"
        return try await http.postJson(url: url, json: jsonString, headers: merged)
    }

    static func postJSONObject(
        _ urlString: String,
        body: Any,
        headers: [String: String] = [:]
    ) async throws -> [String: Any] {
        let data = try await postJSON(urlString, body: body, headers: headers)
        return (try JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    static func postForm(
        _ urlString: String,
        parameters: [String: String],
        headers: [String: String] = [:],
        http: HttpUtil = .shared
    ) async throws -> Data {
        guard let url = makeURL(urlString) else {
            throw SpiderError.scriptError("WebsiteBundle 适配层 URL 无效: \(urlString)")
        }
        return try await http.post(url: url, parameters: parameters, headers: headers)
    }

    static func postFormJSON(
        _ urlString: String,
        parameters: [String: String],
        headers: [String: String] = [:]
    ) async throws -> [String: Any] {
        let data = try await postForm(urlString, parameters: parameters, headers: headers)
        return (try JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }
}

enum WebsiteBundleVod {
    /// Build a VodInfo via JSON encode/decode with the app's existing decoder,
    /// so `vod_play_from` / `vod_play_url` correctly populate `playFlags` / `playUrls`.
    static func makeVodInfo(payload: [String: Any], fallbackId: String, fallbackName: String) -> VodInfo {
        if JSONSerialization.isValidJSONObject(payload),
           let data = try? JSONSerialization.data(withJSONObject: payload),
           let vod = try? JSONDecoder().decode(VodInfo.self, from: data) {
            return vod
        }

        return VodInfo(
            vodId: fallbackId,
            vodName: fallbackName,
            vodPic: payload.wbStringOrNil("vod_pic"),
            vodYear: payload.wbStringOrNil("vod_year"),
            vodArea: payload.wbStringOrNil("vod_area"),
            vodActor: payload.wbStringOrNil("vod_actor"),
            vodDirector: payload.wbStringOrNil("vod_director"),
            vodContent: payload.wbStringOrNil("vod_content"),
            vodRemarks: payload.wbStringOrNil("vod_remarks"),
            typeName: payload.wbStringOrNil("type_name")
        )
    }
}

// MARK: - wexDuBoKu

final class WexDuBoKuNativeSpider: WebsiteBundleNativeSpider {
    let siteKey: String

    private let site: SiteBean
    private let baseURL = "https://api.dbokutv.com"
    private var isInitialized = false

    init(site: SiteBean) {
        self.site = site
        self.siteKey = site.key
    }

    func initialize(ext: String?) async throws {
        isInitialized = true
    }

    func homeContent(filter: Bool) async throws -> HomeContent {
        ensureInitialized()

        let typeIds = ["1", "2", "3", "4", "21", "20", "13", "15", "14"]
        let typeNames = ["电影", "电视剧", "综艺", "动漫", "短剧", "港剧", "陆剧", "日韩剧", "台泰剧"]
        let categories = zip(typeIds, typeNames).map { MovieCategory(tid: $0.0, name: $0.1) }

        return HomeContent(
            categories: categories,
            videos: [],
            filters: filter ? buildFilters() : [:]
        )
    }

    func categoryContent(tid: String, page: Int, filter: Bool, extend: [String: String]) async throws -> CategoryContent {
        ensureInitialized()

        let categoryId = extend["cateId"]?.wbNilIfEmpty ?? tid
        let area = extend["area"] ?? ""
        let year = extend["year"] ?? ""
        let by = extend["by"] ?? ""
        let klass = extend["class"] ?? ""
        let lang = extend["lang"] ?? ""
        let urlString = "\(baseURL)/vodshow/\(categoryId)-\(area)-\(by)-\(klass)-\(lang)----\(page)---\(year)\(Self.signatureQuery())"

        let json = try await WebsiteBundleHttp.getJSON(urlString, headers: Self.requestHeaders())
        let videos = parseVodList(json["VodList"] as? [[String: Any]] ?? [])
        let limit = 48
        let pageCount = parsePageCount(json["PaginationList"] as? [[String: Any]] ?? [])
        let total = pageCount * limit
        return CategoryContent(videos: videos, page: page, pageCount: pageCount, total: total)
    }

    func detailContent(ids: [String]) async throws -> [VodInfo] {
        ensureInitialized()

        guard let id = ids.first, !id.isEmpty else {
            return []
        }

        let json = try await WebsiteBundleHttp.getJSON("\(baseURL)\(id)\(Self.signatureQuery())", headers: Self.requestHeaders())
        let playlist = json["Playlist"] as? [[String: Any]] ?? []
        let items = playlist.compactMap { item -> String? in
            let name = item.wbString("EpisodeName")
            guard let url = Self.decodeBundleBase64(item.wbString("VId")), !url.isEmpty else {
                return nil
            }
            return "\(name)$\(url)"
        }

        let vod = makeVodInfo(from: json, fallbackId: id, playItems: items)
        return [vod]
    }

    func searchContent(keyword: String, quick: Bool, page: Int) async throws -> [MovieItem] {
        ensureInitialized()

        guard !keyword.isEmpty else {
            return []
        }

        let encodedKeyword = keyword.wbUrlEncoded
        let json = try await WebsiteBundleHttp.getJSONArray(
            "\(baseURL)/vodsearch\(Self.signatureQuery())&wd=\(encodedKeyword)",
            headers: Self.requestHeaders()
        )
        return parseVodList(json)
    }

    func playerContent(flag: String, id: String, vipFlags: [String]) async throws -> PlayerContent {
        ensureInitialized()

        guard !id.isEmpty else {
            return PlayerContent()
        }

        let json = try await WebsiteBundleHttp.getJSON("\(baseURL)\(id)\(Self.signatureQuery())", headers: Self.requestHeaders())
        return PlayerContent(
            url: Self.decodeBundleBase64(json.wbString("HId")) ?? "",
            header: Self.playerHeaders(),
            parse: 0
        )
    }

    var supportsQuickSearch: Bool {
        site.isQuickSearchable
    }

    func destroy() {
        isInitialized = false
    }

    private func ensureInitialized() {
        precondition(isInitialized, "WebsiteBundle native spider not initialized")
    }

    private func parseVodList(_ list: [[String: Any]]) -> [MovieItem] {
        list.compactMap { item in
            let name = item.wbString("Name")
            guard !name.isEmpty,
                  let id = Self.decodeBundleBase64(item.wbString("DId")),
                  !id.isEmpty else {
                return nil
            }

            let remarks: String
            if !item.wbString("Tag").isEmpty {
                remarks = item.wbString("Tag")
            } else if !item.wbString("Rating").isEmpty {
                remarks = "\(item.wbString("Rating"))分"
            } else {
                remarks = ""
            }

            return MovieItem(
                vodId: id,
                vodName: name,
                vodPic: Self.decodeBundleBase64(item.wbString("TnId")),
                vodRemarks: remarks
            )
        }
    }

    private func makeVodInfo(from json: [String: Any], fallbackId: String, playItems: [String]) -> VodInfo {
        var payload: [String: Any] = [
            "vod_id": fallbackId,
            "vod_name": json.wbString("Name"),
            "vod_pic": Self.decodeBundleBase64(json.wbString("TnId")) ?? "",
            "vod_year": json.wbString("ReleaseYear"),
            "vod_area": json.wbString("Region"),
            "vod_actor": json.wbStringArray("Actor").joined(separator: "，"),
            "vod_director": json.wbString("Director"),
            "vod_content": json.wbString("Description"),
            "vod_remarks": json.wbString("Rating").isEmpty ? json.wbString("Tag") : "\(json.wbString("Rating"))分",
            "type_name": json.wbString("Genre")
        ]

        if !playItems.isEmpty {
            payload["vod_play_from"] = "独播"
            payload["vod_play_url"] = playItems.joined(separator: "#")
        }

        return WebsiteBundleVod.makeVodInfo(
            payload: payload,
            fallbackId: fallbackId,
            fallbackName: json.wbString("Name")
        )
    }

    private func parsePageCount(_ list: [[String: Any]]) -> Int {
        for item in list {
            let name = item.wbString("Name")
            let parts = name.split(separator: "/")
            if parts.count == 2, let count = Int(parts[1]) {
                return max(1, count)
            }
        }
        return 1
    }

    private func buildFilters() -> [String: [MovieFilter]] {
        let classValues = ["喜剧", "爱情", "恐怖", "动作", "科幻", "剧情", "警匪", "战争", "犯罪", "动画", "奇幻", "武侠", "冒险", "悬疑", "惊悚", "古装"].map {
            MovieFilterValue(n: $0, v: $0)
        }
        let areaValues = ["大陆", "香港", "台湾", "韩国", "英国", "法国", "加拿大", "澳大利亚"].map {
            MovieFilterValue(n: $0, v: $0)
        }
        let yearValues = ["2025", "2024", "2023", "2022", "2021", "2020", "2019"].map {
            MovieFilterValue(n: $0, v: $0)
        }
        let sortValues = [
            MovieFilterValue(n: "时间", v: ""),
            MovieFilterValue(n: "人气", v: "人气"),
            MovieFilterValue(n: "评分", v: "评分")
        ]

        let filters = [
            MovieFilter(key: "class", name: "类型", values: classValues),
            MovieFilter(key: "area", name: "地区", values: areaValues),
            MovieFilter(key: "year", name: "年份", values: yearValues),
            MovieFilter(key: "by", name: "排序", values: sortValues)
        ]

        return Dictionary(uniqueKeysWithValues: ["1", "2", "13", "14", "15", "20"].map { ($0, filters) })
    }

    private static func requestHeaders() -> [String: String] {
        [
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
            "Connection": "Keep-Alive",
            "Referer": "https://www.duboku.tv/"
        ]
    }

    private static func playerHeaders() -> [String: String] {
        [
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36",
            "origin": "https://w.duboku.io",
            "referer": "https://w.duboku.io/"
        ]
    }

    private static func signatureQuery() -> String {
        let seconds = Int(Date().timeIntervalSince1970)
        let random = Int.random(in: 0...800_000_000)
        let millis = String(Int(Date().timeIntervalSince1970 * 1000))
        let mixedSeed = String(100_000_000 + random) + String(900_000_000 - random)

        var ssidSeed = ""
        let maxCount = min(mixedSeed.count, millis.count)
        for index in 0..<maxCount {
            ssidSeed.append(mixedSeed.wbCharacter(at: index))
            ssidSeed.append(millis.wbCharacter(at: index))
        }
        if mixedSeed.count > maxCount {
            ssidSeed.append(String(mixedSeed.dropFirst(maxCount)))
        }
        if millis.count > maxCount {
            ssidSeed.append(String(millis.dropFirst(maxCount)))
        }

        let ssid = Data(ssidSeed.utf8).base64EncodedString().replacingOccurrences(of: "=", with: ".")
        let sign = seededRandomString(length: 60, alphabetKind: 33, seed: seconds + 60)
        let token = seededRandomString(length: 38, alphabetKind: 88, seed: seconds + 38)
        return "?sign=\(sign)&ssid=\(ssid)&token=\(token)"
    }

    private static func seededRandomString(length: Int, alphabetKind: Int, seed: Int) -> String {
        let alphabet: String
        switch alphabetKind {
        case 33:
            alphabet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        case 88:
            alphabet = "XYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVW"
        default:
            alphabet = String((alphabetKind..<(alphabetKind + 62)).compactMap { UnicodeScalar($0).map(Character.init) })
        }

        var state = Double(seed) + Date().timeIntervalSince1970 * 1000
        var value = ""
        for _ in 0..<length {
            let x = sin(state) * 10_000
            state += 1
            let fraction = x - floor(x)
            let index = max(0, min(alphabet.count - 1, Int(floor(fraction * Double(alphabet.count)))))
            value.append(alphabet.wbCharacter(at: index))
        }
        return value
    }

    private static func decodeBundleBase64(_ value: String) -> String? {
        guard !value.isEmpty else {
            return nil
        }

        var rebuilt = ""
        var start = value.startIndex
        while start < value.endIndex {
            let end = value.index(start, offsetBy: 10, limitedBy: value.endIndex) ?? value.endIndex
            rebuilt += String(value[start..<end].reversed())
            start = end
        }

        let normalized = rebuilt.replacingOccurrences(of: ".", with: "=")
        guard let data = Data(base64Encoded: normalized) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
