import Foundation
import Combine

class HomeViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    @Published var categories: [SourceCategory] = []
    @Published var videos: [VideoItem] = []
    @Published var searchText: String = ""
    @Published var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    private let sourceManager = SourceManager.shared
    private let httpUtil = HttpUtil.shared
    
    init() {
        loadCategories()
    }
    
    func loadCategories() {
        isLoading = true
        sourceManager.fetchHomeData { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let sourceCategories):
                    self?.categories = sourceCategories
                case .failure(let error):
                    self?.error = error
                }
            }
        }
    }
    
    func loadVideos(for category: SourceCategory) {
        isLoading = true
        error = nil
        
        sourceManager.fetchVideos(category: category) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let videos):
                    self?.videos = videos
                case .failure(let error):
                    self?.error = error
                }
            }
        }
    }
    
    func search() {
        guard !searchText.isEmpty else { return }
        isLoading = true
        sourceManager.searchVideos(query: searchText) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let videos):
                    self?.videos = videos
                case .failure(let error):
                    self?.showToast(message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showToast(message: String) {
        toastMessage = message
        showToast = true
    }
    
    func getCategories() -> AnyPublisher<[SourceCategory], Error> {
        return Future<[SourceCategory], Error> { promise in
            self.sourceManager.fetchHomeData { result in
                switch result {
                case .success(let sourceCategories):
                    promise(.success(sourceCategories))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func getVideos(category: SourceCategory.CategoryType) -> AnyPublisher<[VideoItem], Error> {
        return Future<[VideoItem], Error> { promise in
            let sourceCategory = SourceCategory(
                id: "",
                name: "",
                type: category,
                api: "",
                searchable: 1,
                quickSearch: 1,
                filterable: 1,
                playerUrl: "",
                ext: "",
                jar: "",
                playerType: 0,
                categories: [],
                clickSelector: ""
            )
            
            self.sourceManager.fetchVideos(category: sourceCategory) { result in
                switch result {
                case .success(let videos):
                    promise(.success(videos))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

// API服务类
class APIService {
    private let httpUtil = HttpUtil.shared
    
    func getCategories() -> AnyPublisher<[SourceCategory], Error> {
        return Future<[SourceCategory], Error> { promise in
            let url = URL(string: "/api/categories")!
            let callback = DataCallback<[SourceCategory]> { result in
                switch result {
                case .success(let categories):
                    promise(.success(categories))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
            self.httpUtil.get(url: url, callback: callback)
        }
        .eraseToAnyPublisher()
    }
    
    func getVideos(category: SourceCategory.CategoryType) -> AnyPublisher<[VideoItem], Error> {
        return Future<[VideoItem], Error> { promise in
            let url = URL(string: "/api/videos")!
            let parameters = ["category": String(category.rawValue)]
            let callback = DataCallback<[VideoItem]> { result in
                switch result {
                case .success(let videos):
                    promise(.success(videos))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
            self.httpUtil.get(url: url, parameters: parameters, callback: callback)
        }
        .eraseToAnyPublisher()
    }
    
    func searchVideos(query: String) -> AnyPublisher<[VideoItem], Error> {
        return Future<[VideoItem], Error> { promise in
            let url = URL(string: "/api/search")!
            let parameters = ["query": query]
            let callback = DataCallback<[VideoItem]> { result in
                switch result {
                case .success(let videos):
                    promise(.success(videos))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
            self.httpUtil.get(url: url, parameters: parameters, callback: callback)
        }
        .eraseToAnyPublisher()
    }
} 
