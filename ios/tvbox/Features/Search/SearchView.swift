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
    @Published var searchHistory: [String] = []
    @Published var hotKeywords: [String] = []
    @Published var error: Error?
    
    private let apiConfig = ApiConfig.shared
    private let storageManager = StorageManager.shared
    
    init() {
        loadSearchHistory()
        loadHotKeywords()
    }
    
    func search() {
        guard !searchText.isEmpty else { return }
        
        // 保存搜索历史
        saveSearchHistory(searchText)
        
        isLoading = true
        results.removeAll()
        
        Task {
            do {
                let searchResults = try await performSearch(keyword: searchText)
                await MainActor.run {
                    self.results = searchResults
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
    
    private func performSearch(keyword: String) async throws -> [MovieItem] {
        // 在所有可搜索的站点中搜索
        var allResults: [MovieItem] = []
        
        for site in apiConfig.searchableSites {
            // TODO: 实现从 Spider 搜索的逻辑
            // 根据站点类型调用不同的搜索接口
        }
        
        return allResults
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

