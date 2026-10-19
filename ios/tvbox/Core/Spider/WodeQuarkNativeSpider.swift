import Foundation

final class WodeQuarkNativeSpider: WebsiteBundleNativeSpider {
    let siteKey: String

    private let provider: QuarkNetDiskProvider
    private var isInitialized = false

    init(site: SiteBean, provider: QuarkNetDiskProvider = .shared) {
        self.siteKey = site.key
        self.provider = provider
    }

    func initialize(ext: String?) async throws {
        guard !ConfigCenterRuntime.cookie(for: "/quark/cookie").isEmpty else {
            throw SpiderError.unsupported("请先在配置中心填写夸克 Cookie")
        }
        isInitialized = true
    }

    func homeContent(filter: Bool) async throws -> HomeContent {
        try ensureInitialized()
        let root = QuarkNetDiskProvider.rootItem()
        let listed = try await provider.movieItems(folderId: root.fid, page: 1)
        return HomeContent(
            categories: [MovieCategory(tid: root.fid, name: "全部文件")],
            videos: listed.items,
            filters: [:]
        )
    }

    func categoryContent(
        tid: String,
        page: Int,
        filter: Bool,
        extend: [String: String]
    ) async throws -> CategoryContent {
        try ensureInitialized()
        let folderId = folderId(from: tid)
        let listed = try await provider.movieItems(folderId: folderId, page: page)
        return CategoryContent(
            videos: listed.items,
            page: page,
            pageCount: listed.hasMore ? page + 1 : page,
            total: listed.items.count
        )
    }

    func detailContent(ids: [String]) async throws -> [VodInfo] {
        try ensureInitialized()
        guard let id = ids.first,
              let decoded = QuarkNetDiskProvider.decodeID(id) else {
            return []
        }

        switch decoded.kind {
        case .file:
            let playItem = "\(decoded.item.name)$\(id)"
            return [provider.vodInfo(for: decoded.item, playItems: [playItem])]

        case .folder:
            let videos = try await provider.collectVideos(folderId: decoded.item.fid)
            let playItems = videos.map { video in
                "\(video.name)$\(QuarkNetDiskProvider.encodeID(kind: .file, item: video))"
            }
            return [provider.vodInfo(for: decoded.item, playItems: playItems)]
        }
    }

    func searchContent(keyword: String, quick: Bool, page: Int) async throws -> [MovieItem] {
        try ensureInitialized()
        guard !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let videos = try await provider.collectVideos(folderId: QuarkNetDiskProvider.rootItem().fid)
        let lowercasedKeyword = keyword.lowercased()
        return videos
            .filter { $0.name.lowercased().contains(lowercasedKeyword) }
            .map { item in
                MovieItem(
                    vodId: QuarkNetDiskProvider.encodeID(kind: .file, item: item),
                    vodName: item.name,
                    vodPic: item.thumbnail,
                    vodRemarks: item.size > 0 ? itemSize(item) : "",
                    vodTag: "quark_file",
                    typeName: "夸克网盘"
                )
            }
    }

    func playerContent(flag: String, id: String, vipFlags: [String]) async throws -> PlayerContent {
        try ensureInitialized()
        guard let decoded = QuarkNetDiskProvider.decodeID(id),
              decoded.kind == .file else {
            throw SpiderError.parseError("无效的夸克播放 ID")
        }

        let url = try await provider.downloadURL(fid: decoded.item.fid)
        return PlayerContent(url: url, header: provider.playerHeaders(), parse: 0)
    }

    var supportsQuickSearch: Bool {
        false
    }

    func destroy() {
        isInitialized = false
    }

    private func ensureInitialized() throws {
        guard isInitialized else {
            throw SpiderError.notInitialized
        }
    }

    private func folderId(from tid: String) -> String {
        if tid.isEmpty || tid == QuarkNetDiskProvider.rootItem().fid {
            return QuarkNetDiskProvider.rootItem().fid
        }
        guard let decoded = QuarkNetDiskProvider.decodeID(tid),
              decoded.kind == .folder else {
            return tid
        }
        return decoded.item.fid
    }

    private func itemSize(_ item: QuarkDriveItem) -> String {
        ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)
    }
}
