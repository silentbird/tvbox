import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            searchBar
            
            // 内容区域
            if viewModel.isLoading {
                Spacer()
                ProgressView("搜索中...")
                Spacer()
            } else if viewModel.searchText.isEmpty {
                historySection
            } else if viewModel.results.isEmpty && !viewModel.searchText.isEmpty {
                ContentUnavailableView(
                    "未找到结果",
                    systemImage: "magnifyingglass",
                    description: Text("尝试使用其他关键词搜索")
                )
            } else {
                resultsList
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索影视", text: $viewModel.searchText)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        viewModel.search()
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if isSearchFocused {
                Button("取消") {
                    isSearchFocused = false
                    viewModel.searchText = ""
                }
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - History Section
    private var historySection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 搜索历史
                if !viewModel.searchHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("搜索历史")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("清空") {
                                viewModel.clearHistory()
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                        
                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.searchHistory, id: \.self) { keyword in
                                Button(action: {
                                    viewModel.searchText = keyword
                                    viewModel.search()
                                }) {
                                    Text(keyword)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(16)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                
                // 热门搜索
                if !viewModel.hotKeywords.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("热门搜索")
                            .font(.headline)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.hotKeywords, id: \.self) { keyword in
                                Button(action: {
                                    viewModel.searchText = keyword
                                    viewModel.search()
                                }) {
                                    Text(keyword)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(16)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Results List
    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.results) { movie in
                    NavigationLink(destination: DetailView(movie: movie)) {
                        SearchResultRow(movie: movie)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let movie: MovieItem
    
    var body: some View {
        HStack(spacing: 12) {
            // 封面图
            AsyncImage(url: URL(string: movie.vodPic ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 80, height: 110)
            .cornerRadius(8)
            .clipped()
            
            // 信息
            VStack(alignment: .leading, spacing: 6) {
                Text(movie.vodName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                if let remarks = movie.vodRemarks, !remarks.isEmpty {
                    Text(remarks)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(4)
                }
                
                HStack(spacing: 8) {
                    if let year = movie.vodYear, !year.isEmpty {
                        Text(year)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let area = movie.vodArea, !area.isEmpty {
                        Text(area)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let typeName = movie.typeName, !typeName.isEmpty {
                        Text(typeName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.origin.x, y: bounds.minY + frame.origin.y), proposal: .unspecified)
        }
    }
    
    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        
        let height = y + rowHeight
        return (CGSize(width: maxWidth, height: height), frames)
    }
}

// MARK: - Search ViewModel
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var results: [MovieItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var searchHistory: [String] = []
    @Published var hotKeywords: [String] = []
    @Published var error: Error?
    @Published var searchMode: SearchMode = .current // 搜索模式
    
    // 分页状态
    @Published var currentPage: Int = 1
    @Published var hasMorePages: Bool = true
    
    private let apiConfig = ApiConfig.shared
    private let storageManager = StorageManager.shared
    private let spiderManager = SpiderManager.shared
    
    /// 搜索模式
    enum SearchMode {
        case current    // 当前站点搜索
        case quick      // 快速搜索 (多站点并行)
        case aggregate  // 聚合搜索 (所有站点)
    }
    
    init() {
        loadSearchHistory()
        loadHotKeywords()
    }
    
    /// 执行搜索
    /// - Parameter refresh: 是否刷新 (从第一页开始)
    func search(refresh: Bool = true) {
        guard !searchText.isEmpty else { return }
        
        // 保存搜索历史
        saveSearchHistory(searchText)
        
        if refresh {
            isLoading = true
            results.removeAll()
            currentPage = 1
            hasMorePages = true
        } else {
            guard hasMorePages, !isLoadingMore else { return }
            isLoadingMore = true
        }
        
        Task {
            do {
                let searchResults: [MovieItem]
                
                switch searchMode {
                case .current:
                    searchResults = try await searchCurrentSite(keyword: searchText, page: currentPage)
                case .quick:
                    searchResults = try await quickSearch(keyword: searchText)
                case .aggregate:
                    searchResults = try await aggregateSearch(keyword: searchText)
                }
                
                await MainActor.run {
                    if refresh {
                        self.results = searchResults
                    } else {
                        self.results.append(contentsOf: searchResults)
                    }
                    
                    // 判断是否有更多页面
                    self.hasMorePages = searchResults.count >= 20
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
    
    /// 加载更多搜索结果
    func loadMore() {
        guard hasMorePages, !isLoadingMore, searchMode == .current else { return }
        
        currentPage += 1
        search(refresh: false)
    }
    
    /// 在当前站点搜索
    private func searchCurrentSite(keyword: String, page: Int) async throws -> [MovieItem] {
        return try await spiderManager.searchContent(keyword: keyword, quick: false, page: page)
    }
    
    /// 快速搜索 (多站点并行)
    private func quickSearch(keyword: String) async throws -> [MovieItem] {
        let searchableSites = apiConfig.searchableSites.prefix(5) // 限制并行数量
        
        var allResults: [MovieItem] = []
        
        await withTaskGroup(of: [MovieItem].self) { group in
            for site in searchableSites {
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
        
        // 去重
        return deduplicateResults(allResults)
    }
    
    /// 聚合搜索 (所有可搜索站点)
    private func aggregateSearch(keyword: String) async throws -> [MovieItem] {
        let searchableSites = apiConfig.searchableSites
        
        var allResults: [MovieItem] = []
        
        // 分批搜索，避免太多并行请求
        let batchSize = 5
        for batch in stride(from: 0, to: searchableSites.count, by: batchSize) {
            let endIndex = min(batch + batchSize, searchableSites.count)
            let batchSites = Array(searchableSites[batch..<endIndex])
            
            await withTaskGroup(of: [MovieItem].self) { group in
                for site in batchSites {
                    group.addTask {
                        do {
                            let spider = try await self.spiderManager.getSpider(for: site)
                            return try await spider.searchContent(keyword: keyword, quick: false, page: 1)
                        } catch {
                            print("Aggregate search error for \(site.name): \(error)")
                            return []
                        }
                    }
                }
                
                for await results in group {
                    allResults.append(contentsOf: results)
                }
            }
        }
        
        return deduplicateResults(allResults)
    }
    
    /// 去重搜索结果
    private func deduplicateResults(_ results: [MovieItem]) -> [MovieItem] {
        var seen = Set<String>()
        return results.filter { movie in
            let key = movie.vodName.lowercased()
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }
    
    /// 清除搜索
    func clear() {
        searchText = ""
        results.removeAll()
        currentPage = 1
        hasMorePages = true
        error = nil
    }
    
    func clearHistory() {
        searchHistory.removeAll()
        storageManager.clearSearchHistory()
    }
    
    private func loadSearchHistory() {
        searchHistory = storageManager.getSearchHistory()
    }
    
    private func saveSearchHistory(_ keyword: String) {
        if !searchHistory.contains(keyword) {
            searchHistory.insert(keyword, at: 0)
            if searchHistory.count > 20 {
                searchHistory.removeLast()
            }
            storageManager.saveSearchHistory(searchHistory)
        }
    }
    
    private func loadHotKeywords() {
        // 默认热门关键词
        hotKeywords = ["庆余年", "三体", "狂飙", "漫长的季节", "繁花", "长相思"]
    }
}

#Preview {
    NavigationView {
        SearchView()
    }
}

