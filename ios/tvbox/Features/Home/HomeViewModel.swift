import Foundation
import Combine

class HomeViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    @Published var categories: [MovieCategory] = []
    @Published var videos: [MovieItem] = []
    @Published var categoryVideos: [MovieItem] = []
    @Published var searchText: String = ""
    @Published var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiConfig = ApiConfig.shared
    private let httpUtil = HttpUtil.shared
    
    init() {}
    
    func loadCategories() {
        guard let currentSite = apiConfig.currentSite else {
            showToast(message: "请先选择站点")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let result = try await fetchHomeData(site: currentSite)
                await MainActor.run {
                    self.categories = result.categories
                    self.videos = result.videos
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                    self.showToast(message: error.localizedDescription)
                }
            }
        }
    }
    
    func loadVideos(for category: MovieCategory) {
        guard let currentSite = apiConfig.currentSite else { return }
        
        isLoading = true
        categoryVideos.removeAll()
        
        Task {
            do {
                let movies = try await fetchCategoryVideos(site: currentSite, category: category)
                await MainActor.run {
                    self.categoryVideos = movies
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    func search() {
        guard !searchText.isEmpty else { return }
        guard let currentSite = apiConfig.currentSite else {
            showToast(message: "请先选择站点")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let results = try await searchVideos(site: currentSite, keyword: searchText)
                await MainActor.run {
                    self.videos = results
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.showToast(message: error.localizedDescription)
                    self.isLoading = false
                }
            }
        }
    }
    
    private func showToast(message: String) {
        toastMessage = message
        showToast = true
    }
    
    // MARK: - API Calls
    
    private func fetchHomeData(site: SiteBean) async throws -> (categories: [MovieCategory], videos: [MovieItem]) {
        // 根据站点类型调用不同的接口
        // type: 0 = xml, 1 = json, 3 = jar, 4 = remote
        
        guard let url = URL(string: site.api) else {
            throw ConfigError.invalidUrl
        }
        
        // 对于 JSON 类型的站点
        if site.type == 1 {
            let jsonString = try await httpUtil.string(url: url)
            
            guard let data = jsonString.data(using: .utf8) else {
                throw ConfigError.invalidData
            }
            
            let response = try JSONDecoder().decode(MovieCategoryResponse.self, from: data)
            
            return (
                categories: response.classData ?? [],
                videos: response.list ?? []
            )
        }
        
        // 对于 XML 类型，需要解析 XML
        if site.type == 0 {
            // TODO: 实现 XML 解析
        }
        
        // 对于 JAR 类型，需要调用 Spider
        if site.type == 3 {
            // TODO: 实现 Spider 调用
        }
        
        return (categories: [], videos: [])
    }
    
    private func fetchCategoryVideos(site: SiteBean, category: MovieCategory) async throws -> [MovieItem] {
        guard let baseUrl = URL(string: site.api) else {
            throw ConfigError.invalidUrl
        }
        
        // 添加分类参数
        let url = baseUrl.appendingQueryParameters(["t": category.tid, "ac": "videolist"])
        
        if site.type == 1 {
            let jsonString = try await httpUtil.string(url: url)
            
            guard let data = jsonString.data(using: .utf8) else {
                throw ConfigError.invalidData
            }
            
            let response = try JSONDecoder().decode(MovieListResponse.self, from: data)
            return response.list ?? []
        }
        
        return []
    }
    
    private func searchVideos(site: SiteBean, keyword: String) async throws -> [MovieItem] {
        guard let baseUrl = URL(string: site.api) else {
            throw ConfigError.invalidUrl
        }
        
        let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let url = baseUrl.appendingQueryParameters(["wd": encodedKeyword, "ac": "videolist"])
        
        if site.type == 1 {
            let jsonString = try await httpUtil.string(url: url)
            
            guard let data = jsonString.data(using: .utf8) else {
                throw ConfigError.invalidData
            }
            
            let response = try JSONDecoder().decode(MovieListResponse.self, from: data)
            return response.list ?? []
        }
        
        return []
    }
}
