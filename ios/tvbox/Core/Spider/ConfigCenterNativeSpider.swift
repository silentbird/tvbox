import Foundation

final class ConfigCenterNativeSpider: WebsiteBundleNativeSpider {
    let siteKey: String

    private let site: SiteBean
    private var configCenterURL = ""

    init(site: SiteBean) {
        self.site = site
        self.siteKey = site.key
    }

    func initialize(ext: String?) async throws {
        guard let url = Self.resolveConfigCenterURL(site: site) else {
            throw SpiderError.invalidSite
        }

        configCenterURL = url
        AppLogger.debug("[ConfigCenterNativeSpider] 配置中心地址: \(url)")
    }

    func homeContent(filter: Bool) async throws -> HomeContent {
        HomeContent(
            categories: [
                MovieCategory(tid: "config_center", name: "配置中心")
            ],
            videos: [configCenterMovie()]
        )
    }

    func categoryContent(tid: String, page: Int, filter: Bool, extend: [String: String]) async throws -> CategoryContent {
        CategoryContent(videos: [configCenterMovie()], page: 1, pageCount: 1, total: 1)
    }

    func detailContent(ids: [String]) async throws -> [VodInfo] {
        var info = VodInfo(
            vodId: "config_center",
            vodName: "配置中心",
            vodPic: nil,
            vodContent: "配置网盘 Cookie/Token、账号、站源域名、网盘列表和 Emby 服务。当前地址: \(configCenterURL)",
            vodRemarks: "打开配置中心",
            typeName: "配置"
        )
        info.playFlags = ["配置中心"]
        info.playUrls = [[VodInfo.VodPlayItem(name: "打开", url: configCenterURL)]]
        return [info]
    }

    func searchContent(keyword: String, quick: Bool, page: Int) async throws -> [MovieItem] {
        let normalized = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.isEmpty || normalized.contains("配置") || normalized.contains("config") else {
            return []
        }
        return [configCenterMovie()]
    }

    func playerContent(flag: String, id: String, vipFlags: [String]) async throws -> PlayerContent {
        PlayerContent(url: id.isEmpty ? configCenterURL : id, parse: 0)
    }

    func destroy() {}

    private func configCenterMovie() -> MovieItem {
        MovieItem(
            vodId: "config_center",
            vodName: "配置中心",
            vodPic: nil,
            vodRemarks: "点击打开",
            vodContent: "打开本地配置中心，管理网盘 Cookie/Token、账号、站源域名、网盘列表和 Emby 服务。",
            vodPlayUrl: configCenterURL,
            vodTag: "config_center",
            typeName: "配置"
        )
    }

    private static func resolveConfigCenterURL(site: SiteBean) -> String? {
        let payload = site.websiteBundleExtPayload

        if let baseURL = payload?["configCenterUrl"] as? String, !baseURL.isEmpty {
            return appendWebsitePath(to: baseURL)
        }

        if let bundleURL = payload?["websiteBundleUrl"] as? String, !bundleURL.isEmpty {
            if bundleURL.contains("/website") {
                return bundleURL
            }
            if bundleURL.contains("/full-config") {
                return replacePath(in: bundleURL, with: "/website")
            }
            return bundleURL
        }

        if site.api.contains("/website") {
            return site.api
        }
        if site.api.contains("/full-config") {
            return replacePath(in: site.api, with: "/website")
        }

        return site.api.isEmpty ? nil : site.api
    }

    private static func appendWebsitePath(to value: String) -> String {
        let trimmed = value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(trimmed)/website"
    }

    private static func replacePath(in value: String, with path: String) -> String {
        guard var components = URLComponents(string: value) else {
            return value
        }
        components.path = path
        components.query = nil
        components.fragment = nil
        return components.string ?? value
    }
}
