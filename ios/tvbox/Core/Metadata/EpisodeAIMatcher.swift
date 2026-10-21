import Foundation

/// AI 辅助匹配分集的设置，接口用 OpenAI 兼容格式
enum AIMatchSettings {
    private enum Keys {
        static let enabled = "ai_match_enabled"
        static let baseURL = "ai_match_base_url"
        static let apiKey = "ai_match_api_key"
        static let model = "ai_match_model"
    }

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.enabled) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.enabled) }
    }

    /// 填到 /v1 为止，例如 https://api.deepseek.com/v1
    static var baseURL: String {
        get { UserDefaults.standard.string(forKey: Keys.baseURL) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.baseURL) }
    }

    static var apiKey: String {
        get { UserDefaults.standard.string(forKey: Keys.apiKey) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.apiKey) }
    }

    static var model: String {
        get { UserDefaults.standard.string(forKey: Keys.model) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.model) }
    }

    static var isConfigured: Bool { isEnabled && !baseURL.isEmpty && !apiKey.isEmpty && !model.isEmpty }

    /// 用户填了完整的 /chat/completions 地址时直接用
    static var completionsURL: URL? {
        var base = baseURL
        while base.hasSuffix("/") { base.removeLast() }
        guard !base.isEmpty else { return nil }
        if !base.hasSuffix("/chat/completions") { base += "/chat/completions" }
        return URL(string: base)
    }
}

enum AIMatchError: LocalizedError {
    case notConfigured
    case unauthorized
    case http(Int, String?)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "未填写接口地址、API Key 或模型"
        case .unauthorized: return "API Key 无效"
        case .http(let code, let message): return message.map { "接口返回错误 \(code)：\($0)" } ?? "接口返回错误 \(code)"
        case .badResponse: return "模型返回的内容无法解析"
        }
    }
}

/// 规则对不上的集名，连同 TMDB 分集列表一起发给模型对应。结果按剧缓存在磁盘，
/// 同一个集名只问一次，对不上的过一天再问（TMDB 可能还没录入新的一集）
actor EpisodeAIMatcher {
    static let shared = EpisodeAIMatcher()

    private static let unmatchedRetry: TimeInterval = 24 * 3600

    private struct CacheEntry: Codable {
        /// 集名 → EpisodeRef.rawValue
        var results: [String: String]
        var date: Date
    }

    private var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tmdb-episodes", isDirectory: true)
    }

    /// - Parameters:
    ///   - key: 剧的标识，换了 TMDB 作品要换 key
    ///   - title: 剧名，给模型参考
    ///   - names: 规则没对上的集名
    /// - Returns: 集名到分集的对应，只含 names 里有结果的
    func matches(key: String, title: String, names: [String], metadata: VodMetadata) async -> [String: EpisodeRef] {
        guard AIMatchSettings.isConfigured, !names.isEmpty, !metadata.episodes.isEmpty || !metadata.specials.isEmpty else { return [:] }
        var entry = readCache(key: key) ?? CacheEntry(results: [:], date: .distantPast)
        let retryUnmatched = Date().timeIntervalSince(entry.date) > Self.unmatchedRetry
        let pending = names.filter { name in
            guard let value = entry.results[name] else { return true }
            return value == EpisodeRef.none.rawValue && retryUnmatched
        }

        if !pending.isEmpty {
            do {
                let fetched = try await request(title: title, names: pending, metadata: metadata)
                for name in pending {
                    entry.results[name] = (fetched[name] ?? EpisodeRef.none).rawValue
                }
                entry.date = Date()
                writeCache(entry, key: key)
            } catch {
                AppLogger.debug("[AIMatch] \(title) 匹配失败: \(error)")
            }
        }

        var result: [String: EpisodeRef] = [:]
        for name in names {
            if let ref = entry.results[name].flatMap(EpisodeRef.init(rawValue:)) { result[name] = ref }
        }
        return result
    }

    func testConnection() async throws {
        _ = try await complete(system: "只回复 OK", user: "ping")
    }

    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }

    // MARK: - 请求

    private func request(title: String, names: [String], metadata: VodMetadata) async throws -> [String: EpisodeRef] {
        let content = try await complete(system: Self.systemPrompt, user: Self.userPrompt(title: title, names: names, metadata: metadata))
        guard let mapping = Self.parseResponse(content, count: names.count) else { throw AIMatchError.badResponse }
        var result: [String: EpisodeRef] = [:]
        for (index, ref) in mapping where metadata.episode(ref) != nil {
            result[names[index]] = ref
        }
        return result
    }

    static let systemPrompt = "你负责把视频网站或网盘里的分集文件名，对应到 TMDB 上这一季的分集。文件名里常有文件大小、画质、发布组等无关信息，综艺常按播出日期命名并分上中下、加更、先导片。只输出 JSON，不要解释。"

    static func userPrompt(title: String, names: [String], metadata: VodMetadata) -> String {
        func line(_ ref: EpisodeRef, _ episode: VodMetadata.Episode) -> String {
            [ref.rawValue, episode.airDate ?? "-", episode.name ?? "-"].joined(separator: " | ")
        }
        var lines = ["剧名：\(title)", "", "TMDB 分集（编号 | 播出日期 | 标题）："]
        lines += metadata.episodes.map { line(.episode($0.number), $0) }
        lines += metadata.specials.map { line(.special($0.number), $0) }
        lines += ["", "待对应的文件名："]
        lines += names.enumerated().map { "\($0.offset + 1). \($0.element)" }
        lines += ["", "按文件名序号返回 JSON 对象，值为 TMDB 编号，对不上的填 null，例如 {\"1\": \"E1\", \"2\": \"S0E131\", \"3\": null}"]
        return lines.joined(separator: "\n")
    }

    /// 从模型回复里取出 {"序号": "E1"}，返回 下标 → 分集。回复可能包着 ```json 代码块
    static func parseResponse(_ content: String, count: Int) -> [Int: EpisodeRef]? {
        guard let start = content.firstIndex(of: "{"), let end = content.lastIndex(of: "}"), start < end,
              let object = try? JSONSerialization.jsonObject(with: Data(content[start...end].utf8)) as? [String: Any] else { return nil }
        var result: [Int: EpisodeRef] = [:]
        for (key, value) in object {
            guard let number = Int(key), (1...count).contains(number),
                  let ref = (value as? String).flatMap(EpisodeRef.init(rawValue:)) else { continue }
            result[number - 1] = ref
        }
        return result
    }

    private func complete(system: String, user: String) async throws -> String {
        guard let url = AIMatchSettings.completionsURL, !AIMatchSettings.apiKey.isEmpty, !AIMatchSettings.model.isEmpty else {
            throw AIMatchError.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(AIMatchSettings.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": AIMatchSettings.model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        if status == 401 { throw AIMatchError.unauthorized }
        let body = try? JSONDecoder().decode(CompletionResponse.self, from: data)
        guard status == 200 else { throw AIMatchError.http(status, body?.error?.message) }
        guard let content = body?.choices?.first?.message.content else { throw AIMatchError.badResponse }
        return content
    }

    private struct CompletionResponse: Decodable {
        let choices: [Choice]?
        let error: ErrorBody?

        struct Choice: Decodable {
            let message: Message
        }

        struct Message: Decodable {
            let content: String?
        }

        struct ErrorBody: Decodable {
            let message: String?
        }
    }

    // MARK: - 缓存

    private func cacheFile(key: String) -> URL {
        let name = Data(key.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
        return cacheDirectory.appendingPathComponent(name + ".json")
    }

    private func readCache(key: String) -> CacheEntry? {
        guard let data = try? Data(contentsOf: cacheFile(key: key)) else { return nil }
        return try? JSONDecoder().decode(CacheEntry.self, from: data)
    }

    private func writeCache(_ entry: CacheEntry, key: String) {
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(entry) {
            try? data.write(to: cacheFile(key: key))
        }
    }
}
