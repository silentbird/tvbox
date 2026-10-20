import Foundation

/// 迅雷影音的字幕接口，没有公开文档。中英文片名都能搜，结果直接是字幕文件，带对应视频的时长
extension SubtitleSearch {
    /// duration 是正在播放的视频时长 (秒)，结果按时长接近程度排序，时间轴更可能对得上
    static func searchXunlei(_ keyword: String, duration: Double) async throws -> [Item] {
        var components = URLComponents(string: "https://api-shoulei-ssl.xunlei.com/oracle/subtitle")!
        components.queryItems = [URLQueryItem(name: "name", value: keyword)]

        struct Response: Decodable {
            struct Subtitle: Decodable {
                let url: String
                let ext: String?
                let name: String
                let languages: [String]?
                /// 毫秒
                let duration: Double?
            }
            let data: [Subtitle]?
        }
        let response = try JSONDecoder().decode(Response.self, from: try await fetch(URLRequest(url: components.url!)))

        var seen = Set<String>()
        let subtitles = (response.data ?? []).enumerated().filter { _, subtitle in
            supportedExtensions.contains((subtitle.ext ?? "").lowercased()) && seen.insert(subtitle.url).inserted
        }
        let sorted = duration > 0
            ? subtitles.sorted { left, right in
                let leftGap = abs((left.element.duration ?? 0) / 1000 - duration)
                let rightGap = abs((right.element.duration ?? 0) / 1000 - duration)
                return leftGap == rightGap ? left.offset < right.offset : leftGap < rightGap
            }
            : subtitles
        return sorted.compactMap { _, subtitle in
            guard let url = URL(string: subtitle.url) else { return nil }
            let length = (subtitle.duration ?? 0) > 0 ? "时长 \(PlayerViewModel.formatTime(subtitle.duration! / 1000))" : nil
            let detail = [subtitle.languages?.joined(separator: "/"), length]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            return Item(source: .xunlei, name: subtitle.name, detail: detail, url: url)
        }
    }
}
