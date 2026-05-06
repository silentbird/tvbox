import Foundation

/// 悦悦秒播（wexYueYue）— 所有响应经 AES-CBC 加密；播放接口本需要本地代理重写
/// m3u8 segment，本实现跳过代理，直接返回签名后的直链（配合 AVPlayer 加上 Badci header）。
final class WexYueYueNativeSpider: WebsiteBundleNativeSpider {
    let siteKey: String
    private let site: SiteBean
    private let baseURL = "https://u.msfom.com/api"

    // CryptoJS AES-CBC, key / iv 为明文字符串的 UTF-8 字节
    private static let aesKey = "aZ9$kU5%qI7=yC2=zH2#gM0@pX7^wF3a"
    private static let aesIV = "hY2&tN3]kF7,dL7="
    private static let signSeed = "zD9[bM4~sF4~uY2)"
    private static let proxyKeySeed = "GNCdDRjBTddOQtNZDCx3g4eQwC01JjwQ"

    private var deviceId = ""        // oMe — 16 char 随机串
    private var token = ""           // iMe — /public/init 返回的 token
    private var appId = "shandianshipin"
    private var isInitialized = false

    init(site: SiteBean) {
        self.site = site
        self.siteKey = site.key
    }

    func initialize(ext: String?) async throws {
        deviceId = Self.randomDeviceId()
        try await bootstrapToken()
        isInitialized = true
    }

    private func bootstrapToken() async throws {
        let body: [String: String] = [
            "invited_by": "",
            "ua": "Mozilla/5.0 (Linux; Android 10; Generic) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Mobile",
            "is_install": "1"
        ]
        let json = try await WebsiteBundleHttp.postFormJSON(
            "\(baseURL)/public/init",
            parameters: body,
            headers: signedHeaders()
        )
        guard let decoded = decryptResponse(json),
              let result = decoded["result"] as? [String: Any],
              let userInfo = result["user_info"] as? [String: Any] else {
            // 即使 init 失败也允许继续跑其它接口（token 为空时服务端通常会默认匿名）。
            return
        }
        token = userInfo.wbString("token")
        if let id = userInfo["app_id"] as? String, !id.isEmpty {
            appId = id
        }
    }

    // MARK: - Spider

    func homeContent(filter: Bool) async throws -> HomeContent {
        let json = try await postEncrypted("/type/get_list", payload: [:])
        guard let data = json?["result"] as? [[String: Any]] else {
            return HomeContent(categories: [], videos: [], filters: [:])
        }

        var categories: [MovieCategory] = []
        var filters: [String: [MovieFilter]] = [:]

        for cls in data {
            let id = cls.wbString("id").wbNilIfEmpty ?? "\(cls.wbInt("id"))"
            let name = cls.wbString("name")
            guard !id.isEmpty, !name.isEmpty else { continue }
            categories.append(MovieCategory(tid: id, name: name))

            var classFilters: [MovieFilter] = []
            let msg = (cls["msg"] as? [[String: Any]]) ?? []
            for group in msg {
                let rawName = group.wbString("name")
                let key = Self.filterKey(forName: rawName)
                guard !key.isEmpty else { continue }
                let dropPrefix: Set<String> = ["全部", "排序"]
                let values: [MovieFilterValue] = group.wbArray("data").compactMap { raw in
                    guard let item = raw as? [String: Any] else { return nil }
                    let valueName = item.wbString("name").wbNilIfEmpty ?? item.wbString("value")
                    if dropPrefix.contains(where: { valueName.hasPrefix($0) }) { return nil }
                    let value = item.wbStringOrNil("value") ?? valueName
                    return MovieFilterValue(n: valueName, v: value)
                }
                if !values.isEmpty {
                    classFilters.append(MovieFilter(key: key, name: rawName, values: values))
                }
            }

            if !classFilters.isEmpty {
                filters[id] = classFilters
            }
        }

        return HomeContent(categories: categories, videos: [], filters: filter ? filters : [:])
    }

    func categoryContent(tid: String, page: Int, filter: Bool, extend: [String: String]) async throws -> CategoryContent {
        let payload: [String: Any] = [
            "type_id": tid,
            "type": extend["type"] ?? "",
            "area": extend["area"] ?? "",
            "year": extend["year"] ?? "",
            "sort": extend["sort"] ?? "",
            "pn": page
        ]
        let json = try await postEncrypted("/search/screen", payload: payload)
        let list = (json?["result"] as? [[String: Any]]) ?? (json?["list"] as? [[String: Any]]) ?? []
        let videos = Self.parseList(list)
        return CategoryContent(videos: videos, page: page, pageCount: 9999, total: 9999 * 20)
    }

    func detailContent(ids: [String]) async throws -> [VodInfo] {
        guard let id = ids.first, !id.isEmpty else { return [] }
        let payload: [String: Any] = [
            "sig": "", "nc_token": "", "code": "", "phone": "", "session_id": "",
            "vod_id": id
        ]
        let json = try await postEncrypted("/video/result", payload: payload)
        guard let result = json?["result"] as? [String: Any] else { return [] }

        let collection = (result["vod_collection"] as? [[String: Any]]) ?? []
        let curTime = Int(Date().timeIntervalSince1970 * 1000)
        let episodes = collection.compactMap { item -> String? in
            let title = item.wbString("title").wbNilIfEmpty ?? "\(item.wbInt("num"))"
            let epId = item.wbString("id")
            let vodToken = item.wbString("vod_token")
            let vodId = item.wbString("vod_id").wbNilIfEmpty ?? id
            guard !epId.isEmpty else { return nil }
            return "\(title)$\(epId)|||\(vodToken)|||\(curTime)|||\(vodId)"
        }

        var payload2: [String: Any] = [
            "vod_id": id,
            "vod_name": result.wbString("vod_name"),
            "vod_pic": result.wbString("vod_pic"),
            "vod_year": result.wbString("vod_year"),
            "vod_area": result.wbString("vod_area"),
            "vod_actor": result.wbString("vod_actor"),
            "vod_director": result.wbString("vod_director"),
            "vod_tag": result.wbString("vod_tag"),
            "vod_content": result.wbString("vod_blurb").wbStripHTML
        ]
        if !episodes.isEmpty {
            payload2["vod_play_from"] = "在线播放"
            payload2["vod_play_url"] = episodes.joined(separator: "#")
        }
        return [WebsiteBundleVod.makeVodInfo(payload: payload2, fallbackId: id, fallbackName: result.wbString("vod_name"))]
    }

    func searchContent(keyword: String, quick: Bool, page: Int) async throws -> [MovieItem] {
        guard !keyword.isEmpty else { return [] }
        let json = try await postEncrypted("/search/result", payload: ["kw": keyword, "pn": page])
        let list = (json?["result"] as? [[String: Any]]) ?? (json?["list"] as? [[String: Any]]) ?? []
        return Self.parseList(list)
    }

    func playerContent(flag: String, id: String, vipFlags: [String]) async throws -> PlayerContent {
        // id 形如 `<collection_id>|||<vod_token>|||<cur_time>|||<vod_id>`
        let parts = id.components(separatedBy: "|||")
        guard parts.count >= 4 else { return PlayerContent(url: id, header: Self.m3u8Headers(), parse: 0) }
        let payload: [String: Any] = [
            "collection_id": parts[0],
            "sig": "", "nc_token": "", "code": "", "phone": "", "session_id": "",
            "vod_token": parts[1],
            "cur_time": parts[2],
            "vod_id": parts[3]
        ]
        let json = try await postEncrypted("/video/collection", payload: payload)
        guard let result = json?["result"] as? [String: Any] else {
            return PlayerContent(url: "", header: Self.m3u8Headers(), parse: 0)
        }
        let rawUrl = result.wbString("vod_url")
        let ck = result.wbString("ck")
        let signedUrl = signM3U8URL(rawUrl, ck: ck)
        return PlayerContent(url: signedUrl, header: Self.m3u8Headers(), parse: 0)
    }

    var supportsQuickSearch: Bool { site.isQuickSearchable }

    func destroy() {
        isInitialized = false
    }

    // MARK: - Crypto & request

    private func postEncrypted(_ path: String, payload: [String: Any]) async throws -> [String: Any]? {
        var params: [String: String] = [:]
        for (key, value) in payload {
            params[key] = "\(value)"
        }
        let json = try await WebsiteBundleHttp.postFormJSON(
            "\(baseURL)\(path)",
            parameters: params,
            headers: signedHeaders()
        )
        return decryptResponse(json)
    }

    private func signedHeaders() -> [String: String] {
        let curTime = String(Int(Date().timeIntervalSince1970 * 1000))
        let sign = WebsiteBundleCrypto.md5HexUpper(Self.signSeed + deviceId + curTime)
        return [
            "User-Agent": "okhttp/4.9.0",
            "sys_platform": "2",
            "device_id": deviceId,
            "sysrelease": "11",
            "sign": sign,
            "cur_time": curTime,
            "channel_code": "sdsp_sp01",
            "mobmodel": "iPhone",
            "version": "42000",
            "token": token,
            "log-header": "I am the log request header.",
            "mob_mfr": "Apple",
            "package_name": "com.ycwlhz.yysp",
            "app_id": appId,
            "Content-Type": "application/x-www-form-urlencoded"
        ]
    }

    private func decryptResponse(_ json: [String: Any]) -> [String: Any]? {
        guard let encoded = json["data"] as? String, !encoded.isEmpty else {
            return json
        }
        guard let cipher = Data(base64Encoded: encoded),
              let keyData = Self.aesKey.data(using: .utf8),
              let ivData = Self.aesIV.data(using: .utf8),
              let plain = WebsiteBundleCrypto.aesCbcDecrypt(cipher, key: keyData, iv: ivData),
              let string = String(data: plain, encoding: .utf8),
              let object = try? JSONSerialization.jsonObject(with: Data(string.utf8)) as? [String: Any] else {
            return nil
        }
        return object
    }

    /// 给 m3u8 地址加上 wsSecret / wsTime 查询参数。不走本地代理。
    private func signM3U8URL(_ rawUrl: String, ck: String) -> String {
        guard let url = URL(string: rawUrl) else { return rawUrl }
        let path = url.path
        let wsTimeSec = Int(Date().timeIntervalSince1970)
        let wsTime = String(wsTimeSec, radix: 16, uppercase: false)
        let wsSecret = WebsiteBundleCrypto.md5Hex(Self.proxyKeySeed + path + wsTime)

        var query = url.query ?? ""
        if !ck.isEmpty {
            let ckPart = ck.hasPrefix("&") ? String(ck.dropFirst()) : ck
            query = query.isEmpty ? ckPart : "\(query)&\(ckPart)"
        }
        let suffix = "wsSecret=\(wsSecret)&wsTime=\(wsTime)"
        query = query.isEmpty ? suffix : "\(query)&\(suffix)"

        if let host = url.host {
            let scheme = url.scheme ?? "https"
            return "\(scheme)://\(host)\(path)?\(query)"
        }
        return rawUrl
    }

    // MARK: - helpers

    private static func parseList(_ list: [[String: Any]]) -> [MovieItem] {
        list.compactMap { item in
            let id = item.wbString("id")
            let name = item.wbString("vod_name").wbNilIfEmpty ?? item.wbString("name")
            guard !id.isEmpty, !name.isEmpty else { return nil }
            return MovieItem(
                vodId: id,
                vodName: name,
                vodPic: item.wbStringOrNil("vod_pic") ?? item.wbStringOrNil("pic"),
                vodRemarks: item.wbStringOrNil("remarks")
            )
        }
    }

    private static func randomDeviceId() -> String {
        let alphabet = Array("0123456789abcdef")
        return String((0..<16).map { _ in alphabet.randomElement()! })
    }

    private static func filterKey(forName name: String) -> String {
        if name.contains("剧情") || name.contains("类型") { return "type" }
        if name.contains("地区") { return "area" }
        if name.contains("时间") || name.contains("年份") { return "year" }
        if name.contains("排序") { return "sort" }
        return ""
    }

    private static func m3u8Headers() -> [String: String] {
        ["User-Agent": "Mozi", "Accept": "*/*"]
    }
}
