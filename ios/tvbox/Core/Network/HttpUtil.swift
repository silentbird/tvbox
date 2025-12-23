import Foundation

/// HTTP 工具类 - 对应 Android 的网络请求封装
class HttpUtil {
    static let shared = HttpUtil()
    
    private let okHttp = OkHttpHelper.shared
    
    private init() {}
    
    // MARK: - Async/Await 方法
    
    /// GET 请求返回字符串
    func string(
        url: URL,
        tag: String? = nil,
        parameters: [String: String]? = nil,
        headers: [String: String]? = nil
    ) async throws -> String {
        let finalUrl = appendParameters(to: url, parameters: parameters)
        return try await okHttp.getString(url: finalUrl, headers: headers)
    }
    
    /// GET 请求返回 Data
    func data(
        url: URL,
        parameters: [String: String]? = nil,
        headers: [String: String]? = nil
    ) async throws -> Data {
        let finalUrl = appendParameters(to: url, parameters: parameters)
        let (data, _) = try await okHttp.get(url: finalUrl, headers: headers)
        return data
    }
    
    /// POST 请求
    func post(
        url: URL,
        parameters: [String: String]? = nil,
        headers: [String: String]? = nil
    ) async throws -> Data {
        let body = parameters?.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        var allHeaders = headers ?? [:]
        if body != nil {
            allHeaders["Content-Type"] = "application/x-www-form-urlencoded"
        }
        let (data, _) = try await okHttp.post(url: url, body: body, headers: allHeaders)
        return data
    }
    
    /// POST JSON 请求
    func postJson(
        url: URL,
        json: String,
        headers: [String: String]? = nil
    ) async throws -> Data {
        let (data, _) = try await okHttp.postJson(url: url, json: json, headers: headers)
        return data
    }
    
    // MARK: - Callback 方法（兼容旧接口）
    
    func get<T, C: HttpCallBack<T>>(
        url: URL,
        parameters: [String: String]? = nil,
        headers: [String: String]? = nil,
        callback: C
    ) {
        Task {
            do {
                let finalUrl = appendParameters(to: url, parameters: parameters)
                let (data, response) = try await okHttp.get(url: finalUrl, headers: headers)
                let result = try callback.onParseResponse(data: data, response: response)
                await MainActor.run {
                    callback.onResponse(response: result)
                }
            } catch {
                await MainActor.run {
                    callback.onFailure(error: error)
                }
            }
        }
    }
    
    func post<T, C: HttpCallBack<T>>(
        url: URL,
        parameters: [String: String]? = nil,
        headers: [String: String]? = nil,
        callback: C
    ) {
        Task {
            do {
                let data = try await post(url: url, parameters: parameters, headers: headers)
                let result = try callback.onParseResponse(data: data, response: URLResponse())
                await MainActor.run {
                    callback.onResponse(response: result)
                }
            } catch {
                await MainActor.run {
                    callback.onFailure(error: error)
                }
            }
        }
    }
    
    func postJson<T, C: HttpCallBack<T>>(
        url: URL,
        json: String,
        headers: [String: String]? = nil,
        callback: C
    ) {
        Task {
            do {
                let data = try await postJson(url: url, json: json, headers: headers)
                let result = try callback.onParseResponse(data: data, response: URLResponse())
                await MainActor.run {
                    callback.onResponse(response: result)
                }
            } catch {
                await MainActor.run {
                    callback.onFailure(error: error)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// 拼接 URL 参数
    private func appendParameters(to url: URL, parameters: [String: String]?) -> URL {
        guard let parameters = parameters, !parameters.isEmpty else {
            return url
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        var queryItems = components?.queryItems ?? []
        queryItems.append(contentsOf: parameters.map { URLQueryItem(name: $0.key, value: $0.value) })
        components?.queryItems = queryItems
        
        return components?.url ?? url
    }
    
    func cancel(tag: String) {
        // 取消指定标签的请求
        okHttp.defaultSession.getAllTasks { tasks in
            tasks.forEach { task in
                if let request = task.originalRequest,
                   let requestTag = request.value(forHTTPHeaderField: "X-Request-Tag"),
                   requestTag == tag {
                    task.cancel()
                }
            }
        }
    }
    
    func cancelAll() {
        okHttp.defaultSession.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
    }
}
