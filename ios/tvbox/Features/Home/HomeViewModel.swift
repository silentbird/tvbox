import Foundation
import Combine

class HomeViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    @Published var categories: [MovieCategory] = []
    @Published var videos: [MovieItem] = []
    @Published var categoryVideos: [MovieItem] = []
    @Published var searchText: String = ""
    @Published var searchResults: [MovieItem] = []
    @Published var error: Error?
    @Published var filters: [String: [MovieFilter]] = [:]
    @Published var selectedFilters: [String: String] = [:]
    
    // 分页状态
    @Published var currentPage: Int = 1
    @Published var hasMorePages: Bool = true
    @Published var currentCategory: MovieCategory?
    
    // 搜索分页
    @Published var searchPage: Int = 1
    @Published var hasMoreSearchResults: Bool = true
    
    private var cancellables = Set<AnyCancellable>()
    private let apiConfig = ApiConfig.shared
    private let spiderManager = SpiderManager.shared
    
    init() {}
    
    // MARK: - 首页加载
    
    /// 加载首页分类和推荐视频
    func loadCategories() {
        guard apiConfig.currentSite != nil else {
            showToast(message: "请先选择站点")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let content = try await spiderManager.homeContent(filter: true)
                await MainActor.run {
                    self.categories = content.categories
                    self.videos = content.videos
                    self.filters = content.filters
                    self.isLoading = false
                    self.error = nil
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
    
    // MARK: - 分类视频加载
    
    /// 加载指定分类的视频列表
    /// - Parameters:
    ///   - category: 分类
    ///   - refresh: 是否刷新 (从第一页开始)
    func loadVideos(for category: MovieCategory, refresh: Bool = true) {
        guard apiConfig.currentSite != nil else { return }
        
        if refresh {
            isLoading = true
            categoryVideos.removeAll()
            currentPage = 1
            hasMorePages = true
            currentCategory = category
            selectedFilters.removeAll()
        } else {
            guard hasMorePages, !isLoadingMore else { return }
            isLoadingMore = true
        }
        
        Task {
            do {
                let content = try await spiderManager.categoryContent(
                    tid: category.tid,
                    page: currentPage,
                    filter: !selectedFilters.isEmpty,
                    extend: selectedFilters
                )
                
                await MainActor.run {
                    if refresh {
                        self.categoryVideos = content.videos
                    } else {
                        self.categoryVideos.append(contentsOf: content.videos)
                    }
                    
                    self.currentPage = content.page
                    self.hasMorePages = content.hasMore
                    self.isLoading = false
                    self.isLoadingMore = false
                    self.error = nil
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                    self.isLoadingMore = false
                }
            }
        }
    }
    
    /// 加载下一页
    func loadMoreVideos() {
        guard let category = currentCategory, hasMorePages, !isLoadingMore else { return }
        
        currentPage += 1
        loadVideos(for: category, refresh: false)
    }
    
    /// 应用筛选条件
    /// - Parameter filters: 筛选条件字典
    func applyFilters(_ filters: [String: String]) {
        guard let category = currentCategory else { return }
        
        selectedFilters = filters
        loadVideos(for: category, refresh: true)
    }
    
    /// 获取当前分类的筛选项
    func getFiltersForCurrentCategory() -> [MovieFilter] {
        guard let category = currentCategory else { return [] }
        return filters[category.tid] ?? category.filters ?? []
    }
    
    // MARK: - 搜索功能
    
    /// 执行搜索
    /// - Parameter refresh: 是否刷新搜索 (从第一页开始)
    func search(refresh: Bool = true) {
        guard !searchText.isEmpty else { return }
        guard apiConfig.currentSite != nil else {
            showToast(message: "请先选择站点")
            return
        }
        
        if refresh {
            isLoading = true
            searchResults.removeAll()
            searchPage = 1
            hasMoreSearchResults = true
        } else {
            guard hasMoreSearchResults, !isLoadingMore else { return }
            isLoadingMore = true
        }
        
        Task {
            do {
                let results = try await spiderManager.searchContent(
                    keyword: searchText,
                    quick: false,
                    page: searchPage
                )
                
                await MainActor.run {
                    if refresh {
                        self.searchResults = results
                    } else {
                        self.searchResults.append(contentsOf: results)
                    }
                    
                    // 如果返回结果为空或少于预期，认为没有更多页面
                    self.hasMoreSearchResults = results.count >= 20
                    self.isLoading = false
                    self.isLoadingMore = false
                    self.error = nil
                }
            } catch {
                await MainActor.run {
                    self.showToast(message: error.localizedDescription)
                    self.isLoading = false
                    self.isLoadingMore = false
                }
            }
        }
    }
    
    /// 加载更多搜索结果
    func loadMoreSearchResults() {
        guard hasMoreSearchResults, !isLoadingMore else { return }
        
        searchPage += 1
        search(refresh: false)
    }
    
    /// 快速搜索 (多站点并行搜索)
    /// - Parameter keyword: 搜索关键字
    /// - Returns: 搜索结果
    func quickSearch(keyword: String) async -> [MovieItem] {
        let searchableSites = apiConfig.searchableSites
        
        var allResults: [MovieItem] = []
        
        await withTaskGroup(of: [MovieItem].self) { group in
            for site in searchableSites.prefix(5) { // 限制并行数量
                group.addTask {
                    do {
                        let spider = try await self.spiderManager.getSpider(for: site)
                        return try await spider.searchContent(keyword: keyword, quick: true, page: 1)
                    } catch {
                        print("Quick search error for \(site.name): \(error)")
                        return []
                    }
                }
            }
            
            for await results in group {
                allResults.append(contentsOf: results)
            }
        }
        
        return allResults
    }
    
    // MARK: - 辅助方法
    
    /// 刷新当前内容
    func refresh() {
        if let category = currentCategory {
            loadVideos(for: category, refresh: true)
        } else {
            loadCategories()
        }
    }
    
    /// 清除搜索
    func clearSearch() {
        searchText = ""
        searchResults.removeAll()
        searchPage = 1
        hasMoreSearchResults = true
    }
    
    /// 站点变更时重置状态
    func onSiteChanged() {
        categories.removeAll()
        videos.removeAll()
        categoryVideos.removeAll()
        searchResults.removeAll()
        filters.removeAll()
        selectedFilters.removeAll()
        currentPage = 1
        hasMorePages = true
        currentCategory = nil
        searchPage = 1
        hasMoreSearchResults = true
        
        // 清除旧站点的 Spider
        spiderManager.clearAll()
        
        // 加载新站点的内容
        loadCategories()
    }
    
    private func showToast(message: String) {
        toastMessage = message
        showToast = true
    }
}

// MARK: - 兼容旧 API (保留以避免破坏现有代码)

extension HomeViewModel {
    @available(*, deprecated, message: "Use loadVideos(for:refresh:) instead")
    func loadVideos(for category: MovieCategory) {
        loadVideos(for: category, refresh: true)
    }
    
    @available(*, deprecated, message: "Use search(refresh:) instead")
    func search() {
        search(refresh: true)
    }
    
    /// 获取搜索结果 (兼容旧代码)
    var videos_searchCompat: [MovieItem] {
        return searchResults.isEmpty ? videos : searchResults
    }
}
