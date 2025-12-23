import Foundation

/// OkHttp 辅助类 - 对应 Android 的 OkGoHelper
class OkHttpHelper {
    static let shared = OkHttpHelper()
    
    /// 默认超时时间（秒）
    static let defaultTimeout: TimeInterval = 10
    
    /// HTTP 状态码描述
    static let httpStatusMap: [Int: String] = [
        200: "OK",
        301: "Moved Permanently",
        302: "Found",
        400: "Bad Request",
        401: "Unauthorized",
        403: "Forbidden",
        404: "Not Found",
        429: "Too Many Requests",
        500: "Internal Server Error",
        502: "Bad Gateway",
        503: "Service Unavailable",
        504: "Gateway Timeout"
    ]
    
    /// DNS over HTTPS 配置列表
    static let dohList: [(name: String, url: String)] = [
        ("关闭", ""),
        ("腾讯", "https://doh.pub/dns-query"),
        ("阿里", "https://dns.alidns.com/dns-query"),
        ("360", "https://doh.360.cn/dns-query"),
        ("Google", "https://dns.google/dns-query"),
        ("AdGuard", "https://dns.adguard.com/dns-query"),
        ("Quad9", "https://dns.quad9.net/dns-query")
    ]
    
    /// 默认请求头
    static let defaultHeaders: [String: String] = [
        "User-Agent": UA.okhttp,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9"
    ]
    
    /// 默认 URLSession 配置
    private(set) var defaultSession: URLSession
    
    /// 不跟随重定向的 URLSession
    private(set) var noRedirectSession: URLSession
    
    private init() {
        // 默认配置
        let defaultConfig = URLSessionConfiguration.default
        defaultConfig.timeoutIntervalForRequest = OkHttpHelper.defaultTimeout
        defaultConfig.timeoutIntervalForResource = 300
        defaultConfig.httpAdditionalHeaders = OkHttpHelper.defaultHeaders
        defaultConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        // 允许任意 HTTP 连接（对应 Android 的 SSL 配置）
        defaultConfig.urlCache = nil
        
        defaultSession = URLSession(configuration: defaultConfig)
        
        // 不跟随重定向的配置
        let noRedirectConfig = URLSessionConfiguration.default
        noRedirectConfig.timeoutIntervalForRequest = OkHttpHelper.defaultTimeout
        noRedirectConfig.timeoutIntervalForResource = 300
        noRedirectConfig.httpAdditionalHeaders = OkHttpHelper.defaultHeaders
        noRedirectConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        noRedirectSession = URLSession(
            configuration: noRedirectConfig,
            delegate: NoRedirectDelegate(),
            delegateQueue: nil
        )
    }
    
    /// 创建带自定义配置的 URLSession
    func createSession(
        timeout: TimeInterval = defaultTimeout,
        headers: [String: String]? = nil,
        followRedirects: Bool = true,
        trustAllCerts: Bool = true
    ) -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 30
        config.httpAdditionalHeaders = headers ?? OkHttpHelper.defaultHeaders
        
        if followRedirects {
            if trustAllCerts {
                return URLSession(
                    configuration: config,
                    delegate: TrustAllCertsDelegate(),
                    delegateQueue: nil
                )
            }
            return URLSession(configuration: config)
        } else {
            if trustAllCerts {
                return URLSession(
                    configuration: config,
                    delegate: NoRedirectTrustAllDelegate(),
                    delegateQueue: nil
                )
            }
            return URLSession(
                configuration: config,
                delegate: NoRedirectDelegate(),
                delegateQueue: nil
            )
        }
    }
    
    // MARK: - 便捷请求方法
    
    /// GET 请求
    func get(
        url: URL,
        headers: [String: String]? = nil,
        timeout: TimeInterval = defaultTimeout
    ) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        
        let allHeaders = mergeHeaders(custom: headers)
        for (key, value) in allHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        print("[OkHttpHelper] GET 请求: \(url.absoluteString)")
        print("[OkHttpHelper] 请求头: \(allHeaders)")
        
        do {
            let (data, response) = try await defaultSession.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("[OkHttpHelper] 响应状态码: \(httpResponse.statusCode)")
                print("[OkHttpHelper] 响应头: \(httpResponse.allHeaderFields)")
            }
            print("[OkHttpHelper] 响应数据长度: \(data.count)")
            
            // 如果数据为空但状态码是成功的，打印响应内容
            if data.isEmpty {
                print("[OkHttpHelper] 警告: 响应数据为空")
            } else if data.count < 500 {
                print("[OkHttpHelper] 响应内容: \(String(data: data, encoding: .utf8) ?? "无法解码")")
            }
            
            return (data, response)
        } catch {
            print("[OkHttpHelper] 请求失败: \(error)")
            print("[OkHttpHelper] 错误详情: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                print("[OkHttpHelper] URLError 代码: \(urlError.code.rawValue)")
                print("[OkHttpHelper] URLError 描述: \(urlError.localizedDescription)")
            }
            throw error
        }
    }
    
    /// GET 请求返回字符串
    func getString(
        url: URL,
        headers: [String: String]? = nil,
        encoding: String.Encoding = .utf8,
        timeout: TimeInterval = defaultTimeout
    ) async throws -> String {
        let (data, response) = try await get(url: url, headers: headers, timeout: timeout)
        
        // 检查 HTTP 状态码，参照 Android 的处理方式
        if let httpResponse = response as? HTTPURLResponse {
            let statusCode = httpResponse.statusCode
            if statusCode < 200 || statusCode >= 300 {
                let statusDesc = OkHttpHelper.httpStatusMap[statusCode] ?? "Unknown Error"
                throw NetworkError.httpError(statusCode: statusCode, message: statusDesc)
            }
        }
        
        return String(data: data, encoding: encoding) ?? ""
    }
    
    /// POST 请求
    func post(
        url: URL,
        body: Data?,
        headers: [String: String]? = nil,
        timeout: TimeInterval = defaultTimeout
    ) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.httpBody = body
        
        let allHeaders = mergeHeaders(custom: headers)
        for (key, value) in allHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        return try await defaultSession.data(for: request)
    }
    
    /// POST JSON 请求
    func postJson(
        url: URL,
        json: String,
        headers: [String: String]? = nil,
        timeout: TimeInterval = defaultTimeout
    ) async throws -> (Data, URLResponse) {
        var customHeaders = headers ?? [:]
        customHeaders["Content-Type"] = "application/json"
        
        return try await post(
            url: url,
            body: json.data(using: .utf8),
            headers: customHeaders,
            timeout: timeout
        )
    }
    
    /// 合并请求头
    private func mergeHeaders(custom: [String: String]?) -> [String: String] {
        var headers = OkHttpHelper.defaultHeaders
        if let custom = custom {
            for (key, value) in custom {
                headers[key] = value
            }
        }
        return headers
    }
    
    /// 获取 DOH URL
    static func getDohUrl(type: Int) -> String {
        guard type > 0 && type < dohList.count else { return "" }
        return dohList[type].url
    }
}

// MARK: - URLSession Delegates

/// 不跟随重定向的代理
class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        // 返回 nil 表示不跟随重定向
        completionHandler(nil)
    }
}

/// 信任所有证书的代理
class TrustAllCertsDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // 信任所有服务器证书（对应 Android 的 SSLCompat）
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

/// 不跟随重定向且信任所有证书的代理
class NoRedirectTrustAllDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

