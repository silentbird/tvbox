import Foundation

/// Cat 配置包站点 - 通过 CatNodeRuntime 调用配置包的 `/spider/{key}/{type}/*` 接口。
final class CatNodeSpider: Spider {
    let siteKey: String

    private let site: SiteBean
    private let apiPath: String
    private let runtime = CatNodeRuntime.shared

    /// 配置包返回给播放器的本地代理占位前缀，需要换成服务实际地址。
    private static let dynamicHostPrefix = "js2p://_WEB_"

    init(site: SiteBean, apiPath: String) {
        self.site = site
        self.siteKey = site.key
        self.apiPath = apiPath
    }

    func initialize(ext: String?) async throws {
        _ = try await call("init", body: [:])
    }

    func homeContent(filter: Bool) async throws -> HomeContent {
        let response = try decode(MovieCategoryResponse.self, from: try await call("home", body: ["filter": filter]), method: "home")
        return HomeContent(
            categories: response.classData ?? [],
            videos: response.list ?? [],
            filters: response.filters ?? [:]
        )
    }

    func categoryContent(tid: String, page: Int, filter: Bool, extend: [String: String]) async throws -> CategoryContent {
        let body: [String: Any] = ["id": tid, "page": page, "filter": filter, "filters": extend]
        let response = try decode(MovieListResponse.self, from: try await call("category", body: body), method: "category")
        return CategoryContent(
            videos: response.list ?? [],
            page: response.page ?? page,
            pageCount: response.pagecount ?? 1,
            total: response.total ?? 0
        )
    }

    func detailContent(ids: [String]) async throws -> [VodInfo] {
        let response = try decode(MovieDetailResponse.self, from: try await call("detail", body: ["id": ids.first ?? ""]), method: "detail")
        return response.list ?? []
    }

    func searchContent(keyword: String, quick: Bool, page: Int) async throws -> [MovieItem] {
        let body: [String: Any] = ["wd": keyword, "quick": quick, "page": page]
        let response = try decode(MovieListResponse.self, from: try await call("search", body: body), method: "search")
        return response.list ?? []
    }

    func playerContent(flag: String, id: String, vipFlags: [String]) async throws -> PlayerContent {
        let data = try await call("play", body: ["flag": flag, "id": id])
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SpiderError.parseError("play 返回数据不是对象")
        }

        let baseURL = await runtime.baseURL?.absoluteString ?? ""
        var header: [String: String]?
        if let rawHeader = object["header"] as? [String: Any] {
            header = rawHeader.mapValues { "\($0)" }
        }

        // 和 Android 一样，字幕可能在 subt (单个地址) 或 subs (列表) 里
        var subs: [SubtitleInfo] = []
        if let subt = object["subt"] as? String, !subt.isEmpty {
            subs.append(SubtitleInfo(name: "", url: subt.replacingOccurrences(of: Self.dynamicHostPrefix, with: baseURL)))
        }
        for item in object["subs"] as? [[String: Any]] ?? [] {
            guard let url = item["url"] as? String, !url.isEmpty else { continue }
            subs.append(SubtitleInfo(
                name: item["name"] as? String ?? "",
                url: url.replacingOccurrences(of: Self.dynamicHostPrefix, with: baseURL),
                lang: item["lang"] as? String,
                format: item["format"] as? String
            ))
        }

        return PlayerContent(
            url: Self.playURL(from: object["url"]).replacingOccurrences(of: Self.dynamicHostPrefix, with: baseURL),
            header: header,
            parse: Self.intValue(object["parse"]) ?? 0,
            jxFrom: object["jx"].map { "\($0)" },
            flag: flag,
            danmaku: object["danmaku"] as? String,
            format: object["format"] as? String,
            subs: subs
        )
    }

    var supportsQuickSearch: Bool {
        site.isQuickSearchable
    }

    func destroy() {}

    // MARK: - Private Methods

    private func call(_ method: String, body: [String: Any]) async throws -> Data {
        do {
            return try await runtime.request(path: "\(apiPath)/\(method)", json: body)
        } catch let error as CatNodeError {
            if case .httpStatus(_, _, let body) = error, let message = Self.bundleMessage(from: body) {
                throw SpiderError.message(message)
            }
            throw SpiderError.scriptError(error.localizedDescription)
        } catch {
            throw SpiderError.networkError(error)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data, method: String) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            AppLogger.debug("[CatNodeSpider] \(siteKey) \(method) JSON 解码失败: \(String(decoding: data.prefix(500), as: UTF8.self))")
            throw SpiderError.parseError("\(method) 返回数据无法解析")
        }
    }

    /// `url` 可能是字符串，也可能是 `[名称, 地址, 名称, 地址...]` 形式的多清晰度数组，取第一个地址。
    private static func playURL(from value: Any?) -> String {
        if let url = value as? String {
            return url
        }
        guard let values = value as? [Any] else {
            return ""
        }
        let strings = values.map { "\($0)" }
        return strings.count >= 2 ? strings[1] : strings.first ?? ""
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    /// 配置包主动给出的提示（如 "还没有配置夸克 Cookie"）只有 message；
    /// 带 code 的是请求站点出错（如 ENOTFOUND），仍按脚本错误处理。
    private static func bundleMessage(from body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["code"] == nil,
              let message = object["message"] as? String,
              !message.isEmpty else {
            return nil
        }
        return message
    }
}
