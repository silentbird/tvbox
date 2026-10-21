import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @FocusState private var isSearchFocused: Bool
    /// 要打开快速搜索的片名
    @State private var searchKeyword: String?
    @Environment(\.tvboxWideLayout) private var isWideLayout

    var body: some View {
        Group {
            if isWideLayout {
                // 对应 Android activity_search: 左栏搜索框和热词，右边结果
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        searchBar
                        historySection
                    }
                    .frame(width: 320)

                    Divider()

                    VStack(spacing: 0) {
                        searchContent
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    // 搜索栏
                    searchBar

                    // 内容区域
                    searchContent
                }
            }
        }
        .background(Color.tvboxBackground)
        .navigationTitle("搜索")
        // 开启 TMDB 时先搜 TMDB，站点资源在后台查找；否则用快速搜索搜所有站点
        .navigationDestination(item: $searchKeyword) { keyword in
            if TMDBSettings.isConfigured {
                TMDBSearchView(keyword: keyword)
            } else {
                FastSearchView(keyword: keyword)
            }
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        if isWideLayout {
            // 宽布局的历史和热词已经在左栏
            ContentUnavailableView(
                "搜索影视",
                systemImage: "magnifyingglass",
                description: Text("在左侧输入片名，或点击历史和热门搜索")
            )
        } else {
            historySection
        }
    }

    private func search(_ keyword: String) {
        guard !keyword.isEmpty else { return }
        viewModel.searchText = keyword
        viewModel.saveSearchHistory(keyword)
        searchKeyword = keyword
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索片名", text: $viewModel.searchText)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        search(viewModel.searchText)
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.system(size: 15))
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Color.tvboxSurface, in: RoundedRectangle(cornerRadius: 14))
            // 聚焦时描边换成强调色
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSearchFocused ? Color.accentColor : Color.tvboxHairline, lineWidth: isSearchFocused ? 1.5 : 1)
            }
            
            if isSearchFocused {
                Button("取消") {
                    isSearchFocused = false
                    viewModel.searchText = ""
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.accentColor)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }
    
    // MARK: - History Section
    private var historySection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 搜索历史
                if !viewModel.searchHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            sectionTitle("搜索历史")
                            
                            Spacer()
                            
                            Button("清空") {
                                viewModel.clearHistory()
                            }
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .buttonStyle(.plain)
                        }
                        
                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.searchHistory, id: \.self) { keyword in
                                Button(action: { search(keyword) }) {
                                    Text(keyword)
                                        .font(.system(size: 13.5))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 13)
                                        .padding(.vertical, 7)
                                        .background(Color.tvboxSurface, in: Capsule())
                                        .overlay(Capsule().strokeBorder(Color.tvboxHairline, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                // 热门搜索，按顺序编号，前三名用强调色
                if !viewModel.hotKeywords.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        sectionTitle("热门搜索")
                        
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 0) {
                            ForEach(Array(viewModel.hotKeywords.enumerated()), id: \.offset) { index, keyword in
                                Button(action: { search(keyword) }) {
                                    HStack(spacing: 10) {
                                        Text("\(index + 1)")
                                            .font(.system(size: 15, weight: .heavy))
                                            .monospacedDigit()
                                            .foregroundColor(index < 3 ? .accentColor : .secondary)
                                            .lineLimit(1)
                                            .fixedSize()
                                            .frame(width: 24, alignment: .leading)
                                        
                                        Text(keyword)
                                            .font(.system(size: 14.5))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 11)
                                    .overlay(alignment: .bottom) {
                                        Rectangle()
                                            .fill(Color.tvboxHairline)
                                            .frame(height: 1)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .bold))
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
@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchHistory: [String] = []
    @Published var hotKeywords: [String] = []
    
    private let storageManager = StorageManager.shared
    
    init() {
        loadSearchHistory()
        loadHotKeywords()
    }
    
    func clearHistory() {
        searchHistory.removeAll()
        storageManager.clearSearchHistory()
    }
    
    private func loadSearchHistory() {
        searchHistory = storageManager.getSearchHistory()
    }
    
    func saveSearchHistory(_ keyword: String) {
        if !searchHistory.contains(keyword) {
            searchHistory.insert(keyword, at: 0)
            if searchHistory.count > 20 {
                searchHistory.removeLast()
            }
            storageManager.saveSearchHistory(searchHistory)
        }
    }
    
    // MARK: - Hot Keywords
    // 对应 Android SearchActivity: 热词取豆瓣热门剧集，失败时用默认热词

    private nonisolated static let hotSearchURL = URL(string: "https://movie.douban.com/j/search_subjects?type=tv&tag=%E7%83%AD%E9%97%A8&sort=recommend&page_limit=20&page_start=0")!
    private nonisolated static let defaultHotKeywords = ["家业", "主角", "低智商犯罪", "苏超", "书卷一梦", "美人余", "藏海传", "长安的荔枝", "庆余年", "凡人修仙传"]
    /// 热词只请求一次，App 运行期间复用
    private static var hotKeywordsTask: Task<[String], Never>?

    private func loadHotKeywords() {
        let task = Self.hotKeywordsTask ?? Task { await Self.fetchHotKeywords() }
        Self.hotKeywordsTask = task
        Task {
            hotKeywords = await task.value
        }
    }

    private nonisolated static func fetchHotKeywords() async -> [String] {
        var request = URLRequest(url: hotSearchURL)
        request.timeoutInterval = 15
        request.setValue(UA.shared.random(), forHTTPHeaderField: "User-Agent")
        request.setValue("https://movie.douban.com/", forHTTPHeaderField: "Referer")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let subjects = json?["subjects"] as? [[String: Any]] ?? []
            var keywords: [String] = []
            for subject in subjects {
                guard let title = subject["title"] as? String else { continue }
                let keyword = cleanHotKeyword(title)
                if !keyword.isEmpty && !keywords.contains(keyword) {
                    keywords.append(keyword)
                }
            }
            if !keywords.isEmpty {
                return keywords
            }
        } catch {
            AppLogger.debug("[SearchViewModel] 豆瓣热词加载失败: \(error)")
        }
        return defaultHotKeywords
    }

    /// 去掉书名号等符号，只取空格前的片名，如 "某剧 第二季" 取 "某剧"
    private nonisolated static func cleanHotKeyword(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "<|>|《|》|-", with: "", options: .regularExpression)
            .components(separatedBy: " ")
            .first ?? ""
    }
}

#if !targetEnvironment(macCatalyst)
#Preview {
    NavigationView {
        SearchView()
    }
}
#endif
