import Foundation

class HttpUtil {
    static let shared = HttpUtil()
    private let session: URLSession
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        session = URLSession(configuration: configuration)
    }
    
    func string(url: URL,
                tag: String? = nil,
                parameters: [String: String]? = nil,
                headers: [String: String]? = nil) async throws -> String {
        let request = HttpRequest(method: .get,
                            url: url,
                            parameters: parameters,
                            headers: headers,
                            tag: tag)
            .buildRequest()
        
        let (data, response) = try await session.data(for: request)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    func get<T, C: HttpCallBack<T>>(url: URL,
                parameters: [String: String]? = nil,
                headers: [String: String]? = nil,
                callback: C) {
        let request = HttpRequest(method: .get,
                            url: url,
                            parameters: parameters,
                            headers: headers)
            .buildRequest()
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                callback.onFailure(error: error)
                return
            }
            
            guard let data = data, let response = response else {
                callback.onFailure(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }
            
            do {
                let result = try callback.onParseResponse(data: data, response: response)
                callback.onResponse(response: result)
            } catch {
                callback.onFailure(error: error)
            }
        }
        
        task.resume()
    }
    
    func post<T, C: HttpCallBack<T>>(url: URL,
                parameters: [String: String]? = nil,
                headers: [String: String]? = nil,
                callback: C) {
        let request = HttpRequest(method: .post,
                            url: url,
                            parameters: parameters,
                            headers: headers)
            .buildRequest()
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                callback.onFailure(error: error)
                return
            }
            
            guard let data = data, let response = response else {
                callback.onFailure(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }
            
            do {
                let result = try callback.onParseResponse(data: data, response: response)
                callback.onResponse(response: result)
            } catch {
                callback.onFailure(error: error)
            }
        }
        
        task.resume()
    }
    
    func postJson<T, C: HttpCallBack<T>>(url: URL,
                    json: String,
                    headers: [String: String]? = nil,
                    callback: C) {
        let request = HttpRequest(method: .post,
                            url: url,
                            headers: headers,
                            jsonBody: json)
            .buildRequest()
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                callback.onFailure(error: error)
                return
            }
            
            guard let data = data, let response = response else {
                callback.onFailure(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }
            
            do {
                let result = try callback.onParseResponse(data: data, response: response)
                callback.onResponse(response: result)
            } catch {
                callback.onFailure(error: error)
            }
        }
        
        task.resume()
    }
    
    func cancel(tag: String) {
        session.getAllTasks { tasks in
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
        session.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
    }
} 
