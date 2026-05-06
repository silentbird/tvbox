import Foundation

/// 韩剧秒播（hanxiaoquan）— 多层 AES-CBC + MD5 动态密钥 + 播放签名链。
/// 本实现省略本地 m3u8 代理：若 play 响应是单段 m3u8，则直接透传并带 UA。
final class HanxiaoquanNativeSpider: WebsiteBundleNativeSpider {
    let siteKey: String
    private let site: SiteBean
    private let baseURL = "https://hxqapi.hiyun.tv"

    private static let fixedKey = "f349wghhe784tqwhd3w8hf94fidk38lk"
    private static let responseSalt = "34F9Q53w/HJW8E6Q"
    private static let signSalt = "2E159Q/Z8979WckQ"
    private static let rewardPadding = "GIpxY0JPylRx"
    private static let ai = "dd2ebaf2b7b8083e"

    private var did = ""
    private var udid = ""
    private var uk = ""
    private var isInitialized = false

    init(site: SiteBean) {
        self.site = site
        self.siteKey = site.key
    }

    func initialize(ext: String?) async throws {
        did = Self.randomAlnum(length: 20)
        udid = WebsiteBundleCrypto.md5Hex(did)
        if let didData = did.data(using: .utf8),
           let keyData = Self.fixedKey.data(using: .utf8),
           let encrypted = WebsiteBundleCrypto.aesCbcEncrypt(
            didData,
            key: keyData.prefix(16),
            iv: keyData.suffix(16)
           ) {
            uk = encrypted.base64EncodedString()
        }
        isInitialized = true
    }

    func homeContent(filter: Bool) async throws -> HomeContent {
        let categories = [
            MovieCategory(tid: "1", name: "韩剧"),
            MovieCategory(tid: "2", name: "综艺"),
            MovieCategory(tid: "3", name: "电影")
        ]
        let filters: [String: [MovieFilter]] = {
            guard filter else { return [:] }
            let sortValues = [
                MovieFilterValue(n: "热度", v: "hot"),
                MovieFilterValue(n: "最新", v: "new"),
                MovieFilterValue(n: "评分", v: "score")
            ]
            let yearValues = ["2025", "2024", "2023", "2022", "2021", "2020", "1-2014"].map {
                MovieFilterValue(n: $0, v: $0)
            }
            let filters = [
                MovieFilter(key: "sorts", name: "排序", values: sortValues),
                MovieFilter(key: "years", name: "年份", values: yearValues)
            ]
            return Dictionary(uniqueKeysWithValues: ["1", "2", "3"].map { ($0, filters) })
        }()
        return HomeContent(categories: categories, videos: [], filters: filters)
    }

    func categoryContent(tid: String, page: Int, filter: Bool, extend: [String: String]) async throws -> CategoryContent {
        let sort = extend["sorts"]?.wbNilIfEmpty ?? "hot"
        let cid = extend["cates"]?.wbNilIfEmpty ?? "-1"
        let year = extend["years"]?.wbNilIfEmpty ?? "-1"
        let url = "\(baseURL)/api/series2/arrange/cate?stype=\(tid)&page=\(page)&sort=\(sort)&cid=\(cid)&year=\(year)"
        let json = try await requestDecrypted(url, method: "GET")
        let list = (json?["seriesList"] as? [[String: Any]]) ?? []
        let videos = Self.parseList(list)
        return CategoryContent(videos: videos, page: page, pageCount: page + 1, total: (page + 1) * 20)
    }

    func detailContent(ids: [String]) async throws -> [VodInfo] {
        guard let id = ids.first, !id.isEmpty else { return [] }
        let url = "\(baseURL)/api/series2/detail/normal?sid=\(id.wbUrlEncoded)"
        let json = try await requestDecrypted(url, method: "GET")
        guard let series = json?["series"] as? [String: Any] else { return [] }

        let name = series.wbString("name")
        let pic = (series["image"] as? [String: Any])?.wbString("thumb") ?? ""
        let actor = series.wbString("crew")
        let content = series.wbString("intro").wbStripHTML

        // 每个清晰度是一条 flag；每个 flag 拼接所有 playItems。
        let qualities = (series["scopeQualities"] as? [[String: Any]]) ?? []
        var flags: [String] = []
        var flagUrls: [String] = []
        for quality in qualities {
            let qualityName = quality.wbString("name")
            let resolution = quality.wbString("resolution")
            let flag = [qualityName, resolution].filter { !$0.isEmpty }.joined(separator: "|").wbNilIfEmpty ?? "默认"

            let playItems = (quality["playItems"] as? [[String: Any]]) ?? []
            let urls = playItems.compactMap { item -> String? in
                let serial = item.wbInt("serialNo")
                let title = item.wbString("title")
                let pid = item.wbString("pid")
                let value = item.wbString("value")
                let vtype = item.wbString("vtype")
                guard !pid.isEmpty else { return nil }
                let label = "【\(serial)】\(title)".trimmingCharacters(in: .whitespaces)
                return "\(label)$\(pid)+++\(value)+++\(vtype)"
            }
            if urls.isEmpty { continue }
            flags.append(flag)
            flagUrls.append(urls.joined(separator: "#"))
        }

        var payload: [String: Any] = [
            "vod_id": id,
            "vod_name": name,
            "vod_pic": pic,
            "vod_actor": actor,
            "vod_content": content
        ]
        if !flags.isEmpty {
            payload["vod_play_from"] = flags.joined(separator: "$$$")
            payload["vod_play_url"] = flagUrls.joined(separator: "$$$")
        }
        return [WebsiteBundleVod.makeVodInfo(payload: payload, fallbackId: id, fallbackName: name)]
    }

    func searchContent(keyword: String, quick: Bool, page: Int) async throws -> [MovieItem] {
        guard !keyword.isEmpty else { return [] }
        let url = "\(baseURL)/api/search/s5?k=\(keyword.wbUrlEncoded)&srefer=search_hot&type=0&page=\(page)"
        let json = try await requestDecrypted(url, method: "GET")
        let list = (json?["seriesList"] as? [[String: Any]]) ?? []
        return Self.parseList(list)
    }

    func playerContent(flag: String, id: String, vipFlags: [String]) async throws -> PlayerContent {
        let parts = id.components(separatedBy: "+++")
        guard parts.count >= 3 else { return PlayerContent() }
        let pid = parts[0]
        let sq = parts[1]
        let re = parts[2]

        // Step 2: /episode/detail → scid
        let episode = try await requestDecrypted("\(baseURL)/api/series2/episode/detail?pid=\(pid)", method: "GET")
        let playItem = (episode?["playItem"] as? [String: Any]) ?? [:]
        let sources = (playItem["sources"] as? [[String: Any]]) ?? []
        let scid = sources.first?.wbString("scid") ?? ""
        let resolvedPid = playItem.wbString("pid").wbNilIfEmpty ?? pid

        // Step 3: ad_series_play → traceId
        let reward = try? await requestDecrypted("\(baseURL)/api/carp/reward/v2?scene=ad_series_play", method: "GET")
        let traceId = reward?.wbString("traceId") ?? ""

        // Step 4: /carp/reward/rp/v2 → rewardTokenInfo.token
        let ttk = await rewardToken(pid: resolvedPid, traceId: traceId)

        // Step 5: sign
        let uuid = Self.randomAlnum(length: 32).uppercased()
        let t = String(Int(Date().timeIntervalSince1970))
        let signInput = "&version=6.8&uuid=\(uuid)&udid=\(udid)&ttk=\(ttk)&t=\(t)&sq=\(sq)&scid=\(scid)&re=\(re)&pid=\(resolvedPid)&dt=android&\(Self.signSalt)"
        let sign = WebsiteBundleCrypto.md5Hex(signInput)
        let playURL = "\(baseURL)/api/series/rslvV4?version=6.8&uuid=\(uuid)&t=\(t)&sq=\(sq)&scid=\(scid)&re=\(re)&pid=\(resolvedPid)&dt=android&ttk=\(ttk)&sign=\(sign)"

        let json = try await requestDecrypted(playURL, method: "GET")
        let datas = (json?["datas"] as? [[String: Any]]) ?? []
        guard let first = datas.first else {
            return PlayerContent(url: "", header: Self.playerHeaders(), parse: 0)
        }
        let dataEnc = first.wbString("data")
        let playUrl: String = {
            guard let cipher = Data(base64Encoded: dataEnc),
                  let keyData = dynamicKey(ts: "")
                  else { return "" }
            if let plain = WebsiteBundleCrypto.aesCbcDecrypt(
                cipher,
                key: keyData.prefix(16),
                iv: keyData.suffix(16)
            ),
               let string = String(data: plain, encoding: .utf8),
               let object = try? JSONSerialization.jsonObject(with: Data(string.utf8)) as? [String: Any] {
                return object.wbString("playUrl")
            }
            return ""
        }()

        return PlayerContent(url: playUrl, header: Self.playerHeaders(), parse: 0)
    }

    var supportsQuickSearch: Bool { site.isQuickSearchable }

    func destroy() {
        isInitialized = false
    }

    // MARK: - Crypto pipeline

    private func requestDecrypted(_ urlString: String, method: String) async throws -> [String: Any]? {
        let headers = requestHeaders()
        let json: [String: Any]
        if method == "POST" {
            json = try await WebsiteBundleHttp.postJSONObject(urlString, body: [:], headers: headers)
        } else {
            json = try await WebsiteBundleHttp.getJSON(urlString, headers: headers)
        }
        return decryptWrapper(json)
    }

    private func requestHeaders() -> [String: String] {
        let ts = String(Int(Date().timeIntervalSince1970 * 1000))
        let deviceFingerprint = signPayload(ts: ts)
        return [
            "User-Agent": "HanjuTV/6.8 (HUAWEI; Android 12; Scale/2.00)",
            "ch": "huawei",
            "uk": uk,
            "vn": "6.8",
            "vc": "a_8260",
            "said": Self.ai,
            "app": "hj",
            "sign": deviceFingerprint,
            "Content-Type": "application/json; charset=utf-8"
        ]
    }

    private func signPayload(ts: String) -> String {
        let payload: [String: Any] = [
            "emu": 0, "ou": 0, "it": Int(ts) ?? 0, "iit": Int(ts) ?? 0,
            "bs": 0, "uid": did, "pc": 0, "tm": 0,
            "d8m": "0,0,0,0,0,0,0,0", "md": "", "maker": "HUAWEI",
            "osv": "12", "br": 82, "rpc": 0, "scc": 0, "plc": 0,
            "toc": 1, "tsc": 0, "ts": Int(ts) ?? 0, "pa": 1, "crec": 0,
            "nw": 2, "px": "0", "isp": "", "ai": Self.ai, "oa": "",
            "dpc": 0, "dsc": 0, "qpc": 0, "apad": 1, "pk": "com.babycloud.hanju"
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let keyData = udid.data(using: .utf8),
              keyData.count >= 32,
              let encrypted = WebsiteBundleCrypto.aesCbcEncrypt(
                data,
                key: keyData.prefix(16),
                iv: keyData.suffix(16)
              ) else {
            return ""
        }
        return encrypted.base64EncodedString()
    }

    private func decryptWrapper(_ json: [String: Any]) -> [String: Any]? {
        let ts = json.wbString("ts")
        let dataField = json["data"] as? String ?? ""
        guard let cipher = Data(base64Encoded: dataField),
              let keyData = dynamicKey(ts: ts) else {
            return json["data"] as? [String: Any]
        }
        guard let plain = WebsiteBundleCrypto.aesCbcDecrypt(
            cipher,
            key: keyData.prefix(16),
            iv: keyData.suffix(16)
        ),
              let string = String(data: plain, encoding: .utf8),
              let object = try? JSONSerialization.jsonObject(with: Data(string.utf8)) as? [String: Any] else {
            return nil
        }
        return object
    }

    /// Ane(ts) = MD5(MD5(did+ts) + responseSalt)
    private func dynamicKey(ts: String) -> Data? {
        let inner = WebsiteBundleCrypto.md5Hex(did + ts)
        let outer = WebsiteBundleCrypto.md5Hex(inner + Self.responseSalt)
        return outer.data(using: .utf8)
    }

    private func rewardToken(pid: String, traceId: String) async -> String {
        let payload: [String: Any] = [
            "pid": pid,
            "scene": "ad_series_play",
            "traceId": traceId
        ]
        guard let payloadData = try? JSONSerialization.data(withJSONObject: payload),
              let udidData = udid.data(using: .utf8),
              udidData.count >= 32,
              let encrypted = WebsiteBundleCrypto.aesCbcEncrypt(
                payloadData,
                key: udidData.prefix(16),
                iv: udidData.suffix(16)
              ) else {
            return Self.randomAlnum(length: 32)
        }
        let bodyB64 = encrypted.base64EncodedString()
        let aps = WebsiteBundleCrypto.md5Hex(bodyB64 + Self.rewardPadding)
        var headers = requestHeaders()
        headers["aps"] = aps
        headers["Content-Type"] = "application/json; charset=utf-8"

        // body 传进去的是裸 JSON {data: "..."}
        let wrapper: [String: Any] = ["data": bodyB64]
        guard let json = try? await WebsiteBundleHttp.postJSONObject(
            "\(baseURL)/api/carp/reward/rp/v2",
            body: wrapper,
            headers: headers
        ) else {
            return Self.randomAlnum(length: 32)
        }
        guard let result = decryptWrapper(json),
              let tokenInfo = result["rewardTokenInfo"] as? [String: Any] else {
            return Self.randomAlnum(length: 32)
        }
        let token = tokenInfo.wbString("token")
        return token.isEmpty ? Self.randomAlnum(length: 32) : token
    }

    // MARK: - helpers

    private static func parseList(_ list: [[String: Any]]) -> [MovieItem] {
        list.compactMap { item in
            let sid = item.wbString("sid").wbNilIfEmpty ?? item.wbString("id")
            let name = item.wbString("name")
            guard !sid.isEmpty, !name.isEmpty else { return nil }
            let pic = (item["image"] as? [String: Any])?.wbString("thumb") ?? item.wbString("thumb")
            return MovieItem(
                vodId: sid,
                vodName: name,
                vodPic: pic.isEmpty ? nil : pic,
                vodRemarks: item.wbStringOrNil("detailMemo")
            )
        }
    }

    private static func randomAlnum(length: Int) -> String {
        let alphabet = Array("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return String((0..<length).map { _ in alphabet.randomElement()! })
    }

    private static func playerHeaders() -> [String: String] {
        ["User-Agent": "HanjuTV/6.8 (HUAWEI; Android 12; Scale/2.00)"]
    }
}
