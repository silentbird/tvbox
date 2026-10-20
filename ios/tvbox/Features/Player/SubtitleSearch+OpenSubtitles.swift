import Foundation

/// OpenSubtitles 的旧版 REST 接口 (rest.opensubtitles.org)，不用注册 API Key，下载不用登录。
/// 只能用英文片名搜，一次只能查一种语言
extension SubtitleSearch {
    /// 依次显示简体、繁体、英文
    private static let openSubtitlesLanguages = [("chi", "简体"), ("zht", "繁体"), ("eng", "英文")]

    static func searchOpenSubtitles(_ keyword: String) async throws -> [Item] {
        let (lists, error) = await withTaskGroup(of: (Int, Result<[Item], Error>).self) { group in
            for (index, language) in openSubtitlesLanguages.enumerated() {
                group.addTask {
                    do {
                        return (index, .success(try await searchOpenSubtitles(keyword, language: language)))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            var lists = Array(repeating: [Item](), count: openSubtitlesLanguages.count)
            var firstError: Error?
            for await (index, result) in group {
                switch result {
                case .success(let items): lists[index] = items
                case .failure(let error): firstError = firstError ?? error
                }
            }
            return (lists, firstError)
        }
        let items = lists.flatMap { $0 }
        // 都失败了才报错
        if items.isEmpty, let error {
            throw error
        }
        return items
    }

    private static func searchOpenSubtitles(_ keyword: String, language: (code: String, name: String)) async throws -> [Item] {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove("/")
        guard let query = keyword.lowercased().addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: "https://rest.opensubtitles.org/search/query-\(query)/sublanguageid-\(language.code)") else { return [] }
        var request = URLRequest(url: url)
        // 旧接口要求带这个头
        request.setValue("TemporaryUserAgent", forHTTPHeaderField: "X-User-Agent")

        struct Subtitle: Decodable {
            let SubFileName: String
            let SubFormat: String
            let SubDownloadLink: String
            let SubDownloadsCnt: String?
            let MovieName: String?
            let MovieYear: String?
        }
        let subtitles = try JSONDecoder().decode([Subtitle].self, from: try await fetch(request))
        return subtitles
            .filter { supportedExtensions.contains($0.SubFormat.lowercased()) }
            .sorted { Int($0.SubDownloadsCnt ?? "") ?? 0 > Int($1.SubDownloadsCnt ?? "") ?? 0 }
            .compactMap { subtitle in
                guard let url = URL(string: subtitle.SubDownloadLink) else { return nil }
                let movie = [subtitle.MovieName, subtitle.MovieYear.map { "(\($0))" }].compactMap { $0 }.joined(separator: " ")
                let detail = [language.name, movie, subtitle.SubDownloadsCnt.map { "下载 \($0)" }]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                return Item(source: .openSubtitles, name: subtitle.SubFileName, detail: detail, url: url)
            }
    }
}
