import Foundation

class DataCallback<T: Decodable>: HttpCallBack {
    typealias T = T
    
    private let completion: (Result<T, Error>) -> Void
    
    init(completion: @escaping (Result<T, Error>) -> Void) {
        self.completion = completion
    }
    
    func onParseResponse(data: Data, response: URLResponse) throws -> T {
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func onFailure(error: Error) {
        completion(.failure(error))
    }
    
    func onResponse(response: T) {
        completion(.success(response))
    }
} 