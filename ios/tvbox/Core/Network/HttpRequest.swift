import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

class HttpRequest {
    private let method: HTTPMethod
    private let url: URL
    private let parameters: [String: String]?
    private let headers: [String: String]?
    private let jsonBody: String?
    private let tag: String?
    
    init(method: HTTPMethod,
         url: URL,
         parameters: [String: String]? = nil,
         headers: [String: String]? = nil,
         jsonBody: String? = nil,
         tag: String? = nil) {
        self.method = method
        self.url = url
        self.parameters = parameters
        self.headers = headers
        self.jsonBody = jsonBody
        self.tag = tag
    }
    
    func buildRequest() -> URLRequest {
        var request: URLRequest
        
        if method == .get {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
            if let parameters = parameters {
                components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
            }
            request = URLRequest(url: components.url!)
        } else {
            request = URLRequest(url: url)
            if let jsonBody = jsonBody {
                request.httpBody = jsonBody.data(using: .utf8)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } else if let parameters = parameters {
                let formData = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
                request.httpBody = formData.data(using: .utf8)
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            }
        }
        
        request.httpMethod = method.rawValue
        
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        return request
    }
} 
