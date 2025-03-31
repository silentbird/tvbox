import Foundation
import Alamofire
import SwiftyJSON

class NetworkManager {
    static let shared = NetworkManager()
    
    private init() {}
    
    func request<T: Decodable>(_ url: String,
                              method: HTTPMethod = .get,
                              parameters: Parameters? = nil,
                              headers: HTTPHeaders? = nil,
                              completion: @escaping (Result<T, Error>) -> Void) {
        
        AF.request(url,
                  method: method,
                  parameters: parameters,
                  headers: headers)
            .validate()
            .responseDecodable(of: T.self) { response in
                switch response.result {
                case .success(let value):
                    completion(.success(value))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }
    
    func requestJSON(_ url: String,
                    method: HTTPMethod = .get,
                    parameters: Parameters? = nil,
                    headers: HTTPHeaders? = nil,
                    completion: @escaping (Result<JSON, Error>) -> Void) {
        
        AF.request(url,
                  method: method,
                  parameters: parameters,
                  headers: headers)
            .validate()
            .responseJSON { response in
                switch response.result {
                case .success(let value):
                    completion(.success(JSON(value)))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }
    
    func download(_ url: String,
                 destination: @escaping (URL, HTTPURLResponse) -> (URL, DownloadRequest.DownloadOptions),
                 progress: @escaping (Progress) -> Void,
                 completion: @escaping (Result<URL, Error>) -> Void) {
        
        AF.download(url, to: destination)
            .downloadProgress { progress in
                progress(progress)
            }
            .response { response in
                switch response.result {
                case .success(let url):
                    if let url = url {
                        completion(.success(url))
                    } else {
                        completion(.failure(NSError(domain: "DownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Download failed"])))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }
} 