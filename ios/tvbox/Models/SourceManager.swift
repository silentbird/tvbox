import Foundation
import Combine

class SourceManager {
    static let shared = SourceManager()
    
    private let httpUtil = HttpUtil.shared
    private let appConfig = AppConfig.shared
    
    private init() {}
    
    func fetchSources(completion: @escaping (Result<[Source], Error>) -> Void) {
        guard let apiHost = appConfig.getCurrentSource()?.api else {
            completion(.failure(NSError(domain: "SourceManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "API未配置"])))
            return
        }
        
        let url = URL(string: apiHost + "/sources")!
        let callback = DataCallback<[Source]>(completion: completion)
        httpUtil.get(url: url, callback: callback)
    }
    
    func fetchHomeData(completion: @escaping (Result<[SourceCategory], Error>) -> Void) {
        guard let source = appConfig.getCurrentSource() else {
            completion(.failure(NSError(domain: "SourceManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未选择数据源"])))
            return
        }
        
        let url = URL(string: source.api + "/home")!
        let callback = DataCallback<[SourceCategory]>(completion: completion)
        httpUtil.get(url: url, callback: callback)
    }
    
    func fetchVideos(category: SourceCategory, completion: @escaping (Result<[VideoItem], Error>) -> Void) {
        guard let source = appConfig.getCurrentSource() else {
            completion(.failure(NSError(domain: "SourceManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未选择数据源"])))
            return
        }
        
        let url = URL(string: source.api + "/category/\(category.id)")!
        let callback = DataCallback<[VideoItem]>(completion: completion)
        httpUtil.get(url: url, callback: callback)
    }
    
    func searchVideos(query: String, completion: @escaping (Result<[VideoItem], Error>) -> Void) {
        guard let source = appConfig.getCurrentSource() else {
            completion(.failure(NSError(domain: "SourceManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未选择数据源"])))
            return
        }
        
        let url = URL(string: source.api + "/search")!
        let parameters = ["keyword": query]
        let callback = DataCallback<[VideoItem]>(completion: completion)
        httpUtil.get(url: url, parameters: parameters, callback: callback)
    }
} 
