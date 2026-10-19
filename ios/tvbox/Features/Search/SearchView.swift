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
        .background(Color.tvboxSystemGroupedBackground)
        .navigationTitle("搜索")
        .tvboxInlineNavigationBarTitle()
        // 和详情页一样，用快速搜索搜所有站点
        .navigationDestination(item: $searchKeyword) { keyword in
            FastSearchView(keyword: keyword)
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
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索影视", text: $viewModel.searchText)
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
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.tvboxSystemGray6)
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
        .background(Color.tvboxSystemBackground)
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
                                Button(action: { search(keyword) }) {
                                    Text(keyword)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.tvboxSystemGray5)
                                        .cornerRadius(16)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                    .background(Color.tvboxSystemBackground)
                    .cornerRadius(12)
                }
                
                // 热门搜索
                if !viewModel.hotKeywords.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("热门搜索")
                            .font(.headline)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.hotKeywords, id: \.self) { keyword in
                                Button(action: { search(keyword) }) {
                                    Text(keyword)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.tvboxSystemGray5)
                                        .cornerRadius(16)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                    .background(Color.tvboxSystemBackground)
                    .cornerRadius(12)
                }
            }
            .padding()
        }
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
    
    private func loadHotKeywords() {
        // 默认热门关键词
        hotKeywords = ["庆余年", "三体", "狂飙", "漫长的季节", "繁花", "长相思"]
    }
}

#if !targetEnvironment(macCatalyst)
#Preview {
    NavigationView {
        SearchView()
    }
}
#endif
