import Foundation

/// 射手网(伪) assrt.net，和 Android 的 SubtitleViewModel 一样抓网页:
/// 搜索页列出字幕包，详情页列出包里的字幕文件，下载地址会 302 跳到真正的文件
extension SubtitleSearch {
    static func searchAssrt(_ keyword: String, page: Int) async throws -> (items: [Item], pageCount: Int) {
        var components = URLComponents(string: "https://secure.assrt.net/sub/")!
        components.queryItems = [
            URLQueryItem(name: "searchword", value: keyword),
            URLQueryItem(name: "sort", value: "rank"),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "no_redir", value: "1"),
        ]
        let html = String(decoding: try await fetch(URLRequest(url: components.url!)), as: UTF8.self)
        let items = matches(of: #"<a class="introtitle"[^>]*>"#, in: html).compactMap { groups -> Item? in
            let tag = groups[0]
            guard let title = matches(of: #"title="([^"]*)""#, in: tag).first?[1],
                  let href = matches(of: #"href="([^"]*)""#, in: tag).first?[1],
                  let url = URL(string: "https://assrt.net" + href) else { return nil }
            let name = decodeEntities(title)
            // 网站会混进不相关的结果，和 Android 一样只留标题里有关键词的
            guard name.range(of: keyword, options: .caseInsensitive) != nil else { return nil }
            return Item(source: .assrt, name: name, url: url, isPackage: true)
        }
        // 分页最后是 "<a>当前页/总页数</a>"
        let pageCount = matches(of: #"<a>\d+/(\d+)</a>"#, in: html).last.flatMap { Int($0[1]) } ?? page
        return (items, pageCount)
    }

    static func assrtFiles(in item: Item) async throws -> [Item] {
        let html = String(decoding: try await fetch(URLRequest(url: item.url)), as: UTF8.self)
        let files = matches(of: #"onthefly\("(\d+)","(\d+)","([^"]+)"\)"#, in: html).compactMap { groups -> Item? in
            let name = decodeEntities(groups[3])
            guard isSupported(name),
                  let path = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "https://secure.assrt.net/download/\(groups[1])/-/\(groups[2])/\(path)") else { return nil }
            return Item(source: .assrt, name: name, url: url)
        }
        if !files.isEmpty {
            return files
        }
        // 不是压缩包时只有一个下载按钮
        guard let href = matches(of: #"id="btn_download"[^>]*href="([^"]+)""#, in: html).first?[1],
              let url = URL(string: "https://assrt.net" + href),
              isSupported(url.lastPathComponent) else { return [] }
        return [Item(source: .assrt, name: url.lastPathComponent, url: url)]
    }
}
