import Foundation

struct QuarkDriveItem: Codable, Equatable {
    let fid: String
    let name: String
    let isFolder: Bool
    let size: Int64
    let thumbnail: String?
    let updatedAt: String?

    var isVideo: Bool {
        guard !isFolder else { return false }
        return Self.videoExtensions.contains(name.pathExtensionLowercased)
    }

    private static let videoExtensions: Set<String> = [
        "mp4", "mkv", "m3u8", "ts", "avi", "mov", "flv", "wmv", "webm", "m4v", "rmvb"
    ]
}

final class QuarkNetDiskProvider {
    static let shared = QuarkNetDiskProvider()

    private let apiBase = "https://drive-pc.quark.cn/1/clouddrive"
    private let pageSize = 100
    private let maxCollectedVideoCount = 200

    private init() {}

    func list(folderId: String, page: Int) async throws -> (items: [QuarkDriveItem], hasMore: Bool) {
        let cookie = try requireCookie()
        let normalizedPage = max(page, 1)
        let encodedFolderId = folderId.wbUrlEncoded
        let url = "\(apiBase)/file/sort?pr=ucpro&fr=pc&pdir_fid=\(encodedFolderId)&_page=\(normalizedPage)&_size=\(pageSize)&_sort=file_type:asc,updated_at:desc"
        let json = try await WebsiteBundleHttp.getJSON(url, headers: requestHeaders(cookie: cookie))
        try validateResponse(json, context: "读取夸克网盘目录失败")

        let data = json.wbDict("data")
        let rawItems = data["list"] as? [[String: Any]] ?? json["list"] as? [[String: Any]] ?? []
        let items = rawItems.compactMap(Self.parseItem)
            .filter { $0.isFolder || $0.isVideo }
        return (items, hasMore(json: json, rawCount: rawItems.count, page: normalizedPage))
    }

    func collectVideos(folderId: String, maxDepth: Int = 2) async throws -> [QuarkDriveItem] {
        var collected: [QuarkDriveItem] = []
        try await collectVideos(
            folderId: folderId,
            remainingDepth: maxDepth,
            collected: &collected
        )
        return collected
    }

    func downloadURL(fid: String) async throws -> String {
        let cookie = try requireCookie()
        let url = "\(apiBase)/file/download?pr=ucpro&fr=pc"
        let json = try await WebsiteBundleHttp.postJSONObject(
            url,
            body: ["fids": [fid]],
            headers: requestHeaders(cookie: cookie)
        )
        try validateResponse(json, context: "获取夸克播放直链失败")

        if let url = Self.findDownloadURL(in: json["data"]) {
            return url
        }
        if let url = Self.findDownloadURL(in: json) {
            return url
        }
        throw SpiderError.parseError("夸克接口没有返回 download_url")
    }

    func movieItems(folderId: String, page: Int) async throws -> (items: [MovieItem], hasMore: Bool) {
        let listed = try await list(folderId: folderId, page: page)
        return (listed.items.map(Self.makeMovieItem), listed.hasMore)
    }

    func vodInfo(for item: QuarkDriveItem, playItems: [String]) -> VodInfo {
        var payload: [String: Any] = [
            "vod_id": Self.encodeID(kind: item.isFolder ? .folder : .file, item: item),
            "vod_name": item.name,
            "vod_pic": item.thumbnail ?? "",
            "vod_remarks": item.isFolder ? "文件夹" : Self.formatSize(item.size),
            "type_name": "夸克网盘",
            "vod_content": item.isFolder ? "来自夸克网盘文件夹，已聚合可播放视频。" : "来自夸克网盘个人文件。"
        ]

        if !playItems.isEmpty {
            payload["vod_play_from"] = "夸克"
            payload["vod_play_url"] = playItems.joined(separator: "#")
        }

        return WebsiteBundleVod.makeVodInfo(
            payload: payload,
            fallbackId: Self.encodeID(kind: item.isFolder ? .folder : .file, item: item),
            fallbackName: item.name
        )
    }

    func playerHeaders() -> [String: String] {
        var headers = Self.baseHeaders
        if let cookie = try? requireCookie() {
            headers["Cookie"] = cookie
        }
        return headers
    }

    static func encodeID(kind: QuarkDriveItemKind, item: QuarkDriveItem) -> String {
        guard let data = try? JSONEncoder().encode(item) else {
            return "quark:\(kind.rawValue):"
        }
        return "quark:\(kind.rawValue):\(base64URLEncode(data))"
    }

    static func decodeID(_ id: String) -> (kind: QuarkDriveItemKind, item: QuarkDriveItem)? {
        let parts = id.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0] == "quark",
              let kind = QuarkDriveItemKind(rawValue: String(parts[1])),
              let data = base64URLDecode(String(parts[2])),
              let item = try? JSONDecoder().decode(QuarkDriveItem.self, from: data) else {
            return nil
        }
        return (kind, item)
    }

    static func rootItem() -> QuarkDriveItem {
        QuarkDriveItem(
            fid: "0",
            name: "全部文件",
            isFolder: true,
            size: 0,
            thumbnail: nil,
            updatedAt: nil
        )
    }

    private func collectVideos(
        folderId: String,
        remainingDepth: Int,
        collected: inout [QuarkDriveItem]
    ) async throws {
        guard collected.count < maxCollectedVideoCount else {
            return
        }

        let listed = try await list(folderId: folderId, page: 1)
        for item in listed.items where item.isVideo {
            collected.append(item)
            if collected.count >= maxCollectedVideoCount {
                return
            }
        }

        guard remainingDepth > 0 else {
            return
        }

        for folder in listed.items where folder.isFolder {
            try await collectVideos(
                folderId: folder.fid,
                remainingDepth: remainingDepth - 1,
                collected: &collected
            )
            if collected.count >= maxCollectedVideoCount {
                return
            }
        }
    }

    private func requireCookie() throws -> String {
        let cookie = ConfigCenterRuntime.cookie(for: "/quark/cookie")
        guard !cookie.isEmpty else {
            throw SpiderError.unsupported("请先在配置中心填写夸克 Cookie")
        }
        return cookie
    }

    private func requestHeaders(cookie: String) -> [String: String] {
        var headers = Self.baseHeaders
        headers["Cookie"] = cookie
        return headers
    }

    private func validateResponse(_ json: [String: Any], context: String) throws {
        let status = json.wbInt("status")
        let code = json.wbInt("code")
        guard code == 0 || status == 200 || (!json.isEmpty && json["code"] == nil && json["status"] == nil) else {
            let message = json.wbString("message").wbNilIfEmpty
                ?? json.wbString("msg").wbNilIfEmpty
                ?? json.wbString("error").wbNilIfEmpty
                ?? "接口返回 code=\(code), status=\(status)"
            throw SpiderError.parseError("\(context): \(message)")
        }
    }

    private func hasMore(json: [String: Any], rawCount: Int, page: Int) -> Bool {
        let data = json.wbDict("data")
        let metadata = data.wbDict("metadata")
        let total = metadata.wbInt("_total")
            .nonZero ?? data.wbInt("total").nonZero ?? json.wbInt("total").nonZero
        if let total {
            return page * pageSize < total
        }
        return rawCount >= pageSize
    }

    private static func parseItem(_ raw: [String: Any]) -> QuarkDriveItem? {
        let fid = raw.wbString("fid").wbNilIfEmpty
            ?? raw.wbString("file_id").wbNilIfEmpty
            ?? raw.wbString("id").wbNilIfEmpty
        let name = raw.wbString("file_name").wbNilIfEmpty
            ?? raw.wbString("name").wbNilIfEmpty
            ?? raw.wbString("title").wbNilIfEmpty
        guard let fid, let name, !fid.isEmpty, !name.isEmpty else {
            return nil
        }

        return QuarkDriveItem(
            fid: fid,
            name: name,
            isFolder: isFolder(raw),
            size: int64(raw, keys: ["size", "file_size"]),
            thumbnail: raw.wbString("thumbnail").wbNilIfEmpty
                ?? raw.wbString("cover").wbNilIfEmpty
                ?? raw.wbString("preview_url").wbNilIfEmpty,
            updatedAt: raw.wbString("updated_at").wbNilIfEmpty
                ?? raw.wbString("update_time").wbNilIfEmpty
        )
    }

    private static func isFolder(_ raw: [String: Any]) -> Bool {
        if raw.wbInt("dir") == 1 || raw.wbInt("is_dir") == 1 {
            return true
        }
        if let dir = raw["dir"] as? Bool, dir {
            return true
        }
        if let isDir = raw["is_dir"] as? Bool, isDir {
            return true
        }
        if raw.keys.contains("file_type"), raw.wbInt("file_type") == 0 {
            return true
        }
        let category = raw.wbString("category").lowercased()
        let objectCategory = raw.wbString("obj_category").lowercased()
        return category == "folder" || objectCategory == "folder"
    }

    private static func makeMovieItem(_ item: QuarkDriveItem) -> MovieItem {
        MovieItem(
            vodId: encodeID(kind: item.isFolder ? .folder : .file, item: item),
            vodName: item.name,
            vodPic: item.thumbnail,
            vodRemarks: item.isFolder ? "文件夹" : formatSize(item.size),
            vodTag: item.isFolder ? "quark_folder" : "quark_file",
            typeName: "夸克网盘"
        )
    }

    private static func findDownloadURL(in value: Any?) -> String? {
        if let dict = value as? [String: Any] {
            if let url = dict.wbString("download_url").wbNilIfEmpty
                ?? dict.wbString("downloadUrl").wbNilIfEmpty
                ?? dict.wbString("url").wbNilIfEmpty {
                return url
            }
            for nested in dict.values {
                if let url = findDownloadURL(in: nested) {
                    return url
                }
            }
        }
        if let array = value as? [Any] {
            for item in array {
                if let url = findDownloadURL(in: item) {
                    return url
                }
            }
        }
        return nil
    }

    private static func int64(_ raw: [String: Any], keys: [String]) -> Int64 {
        for key in keys {
            if let value = raw[key] as? Int64 {
                return value
            }
            if let value = raw[key] as? Int {
                return Int64(value)
            }
            if let value = raw[key] as? NSNumber {
                return value.int64Value
            }
            if let value = raw[key] as? String, let parsed = Int64(value) {
                return parsed
            }
        }
        return 0
    }

    private static func formatSize(_ size: Int64) -> String {
        guard size > 0 else {
            return ""
        }
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(size)
        var unitIndex = 0
        while value >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        return String(format: "%.1f %@", value, units[unitIndex])
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = base64.count % 4
        if padding > 0 {
            base64.append(String(repeating: "=", count: 4 - padding))
        }
        return Data(base64Encoded: base64)
    }

    private static let baseHeaders: [String: String] = [
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Accept": "application/json, text/plain, */*",
        "Origin": "https://pan.quark.cn",
        "Referer": "https://pan.quark.cn/"
    ]
}

enum QuarkDriveItemKind: String {
    case folder
    case file
}

private extension String {
    var pathExtensionLowercased: String {
        (self as NSString).pathExtension.lowercased()
    }
}

private extension Int {
    var nonZero: Int? {
        self == 0 ? nil : self
    }
}
