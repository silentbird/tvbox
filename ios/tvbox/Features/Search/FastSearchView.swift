import SwiftUI

/// 快速搜索 - 对应 Android 的 FastSearchActivity。
/// 按片名并发搜索所有可搜索站点，"全部" 展示精确匹配的结果，也可以按站点查看。
struct FastSearchView: View {
    let keyword: String
    @StateObject private var viewModel = FastSearchViewModel()
    /// 选中的站点 key，nil 表示 "全部"
    @State private var selectedSiteKey: String?
    @Environment(\.tvboxWideLayout) private var isWideLayout

    private var results: [MovieItem] {
        viewModel.results(forSite: selectedSiteKey)
    }

    var body: some View {
        Group {
            if isWideLayout {
                // 对应 Android activity_fast_search: 左栏站点列表，右边结果
                HStack(spacing: 0) {
                    siteList
                        .frame(width: 220)

                    Divider()

                    resultsGrid
                }
            } else {
                VStack(spacing: 0) {
                    siteBar

                    resultsGrid
                }
            }
        }
        .background(Color.tvboxSystemGroupedBackground)
        .navigationTitle(keyword)
        .tvboxInlineNavigationBarTitle()
        .onAppear {
            viewModel.searchIfNeeded(keyword: keyword)
        }
    }

    private var resultsGrid: some View {
        ScrollView {
            if results.isEmpty {
                // 原生 macOS 的 ScrollView 会按内容收窄，空状态要撑满宽度
                emptyState
                    .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    ForEach(results) { movie in
                        NavigationLink(destination: DetailView(movie: movie)) {
                            MovieCard(movie: movie, subtitle: selectedSiteKey == nil ? viewModel.siteName(for: movie) : nil)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Site List
    private var siteList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)

                siteChip(title: "全部", siteKey: nil)
                ForEach(viewModel.resultSites) { site in
                    siteChip(title: site.name, siteKey: site.key)
                }
            }
            .padding(10)
        }
        .background(Color.tvboxSystemBackground)
    }

    // MARK: - Site Bar
    private var siteBar: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    siteChip(title: "全部", siteKey: nil)
                    ForEach(viewModel.resultSites) { site in
                        siteChip(title: site.name, siteKey: site.key)
                    }
                }
            }

            Text(viewModel.statusText)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.tvboxSystemBackground)
    }

    private func siteChip(title: String, siteKey: String?) -> some View {
        let isSelected = selectedSiteKey == siteKey
        return Button(action: { selectedSiteKey = siteKey }) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)
                // 宽布局在左栏里竖排，占满整行
                .frame(maxWidth: isWideLayout ? .infinity : nil, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : (isWideLayout ? Color.clear : Color.tvboxSystemGray5))
                .cornerRadius(8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.isSearching {
            ProgressView("搜索中...")
                .padding(.top, 80)
        } else if selectedSiteKey == nil && !viewModel.resultSites.isEmpty {
            ContentUnavailableView(
                "没有完全匹配的结果",
                systemImage: "magnifyingglass",
                description: Text("可以切换到上方站点查看相关结果")
            )
        } else {
            ContentUnavailableView(
                "未找到结果",
                systemImage: "magnifyingglass",
                description: Text("没有站点搜到「\(keyword)」")
            )
        }
    }
}

// MARK: - Fast Search ViewModel
@MainActor
final class FastSearchViewModel: ObservableObject {
    /// 有结果的站点，按返回先后排列
    @Published private(set) var resultSites: [SiteBean] = []
    /// "全部" 展示的结果
    @Published private(set) var mainResults: [MovieItem] = []
    @Published private(set) var finishedCount = 0
    @Published private(set) var totalCount = 0

    private var keyword = ""
    private var resultsBySite: [String: [MovieItem]] = [:]
    private var highMatchResults: [MovieItem] = []
    /// 一直没有精确匹配时，改为展示以片名开头的结果
    private var showsHighMatch = false
    private var searchTask: Task<Void, Never>?

    var isSearching: Bool { finishedCount < totalCount }

    var statusText: String {
        isSearching ? "搜索中 \(finishedCount)/\(totalCount)" : "\(resultSites.count) 个站点有结果"
    }

    deinit {
        searchTask?.cancel()
    }

    func results(forSite siteKey: String?) -> [MovieItem] {
        guard let siteKey else { return mainResults }
        return resultsBySite[siteKey] ?? []
    }

    func siteName(for movie: MovieItem) -> String? {
        resultSites.first { $0.key == movie.sourceKey }?.name
    }

    /// 从详情页返回时 onAppear 会再次触发，只搜索一次
    func searchIfNeeded(keyword: String) {
        guard searchTask == nil else { return }
        self.keyword = keyword
        let sites = SiteSearcher.sites
        totalCount = sites.count

        searchTask = Task { [weak self] in
            for await (site, items) in SiteSearcher.searchAll(keyword: keyword, sites: sites) {
                guard let self else { return }
                self.receive(items, from: site)
            }
        }
    }

    // MARK: - Private Methods

    private func receive(_ items: [MovieItem], from site: SiteBean) {
        finishedCount += 1

        // SiteSearcher 已经带上了来源站点
        let matched = items.filter { matches($0.vodName) }
        guard !matched.isEmpty else {
            showHighMatchIfNeeded()
            return
        }

        resultsBySite[site.key] = matched
        resultSites.append(site)

        let highMatched = matched.filter { isHighMatch($0.vodName) }
        highMatchResults.append(contentsOf: highMatched)

        if showsHighMatch {
            mainResults.append(contentsOf: highMatched)
        } else {
            let exactMatched = matched.filter { $0.vodName.trimmingCharacters(in: .whitespaces) == keyword.trimmingCharacters(in: .whitespaces) }
            if exactMatched.isEmpty {
                showHighMatchIfNeeded()
            } else {
                mainResults.append(contentsOf: exactMatched)
            }
        }
    }

    /// 前一批站点都没搜到精确匹配时，"全部" 改为展示以片名开头的结果
    private func showHighMatchIfNeeded() {
        guard !showsHighMatch, mainResults.isEmpty,
              finishedCount >= min(SiteSearcher.concurrentSiteCount, totalCount) else { return }
        showsHighMatch = true
        mainResults = highMatchResults
    }

    /// 片名需包含关键词按空格拆开后的每一段
    private func matches(_ name: String) -> Bool {
        let words = keyword.split(whereSeparator: \.isWhitespace)
        return !words.isEmpty && words.allSatisfy { name.contains($0) }
    }

    private func isHighMatch(_ name: String) -> Bool {
        let compactName = name.filter { !$0.isWhitespace }
        let compactKeyword = keyword.filter { !$0.isWhitespace }
        return !compactKeyword.isEmpty && compactName.hasPrefix(compactKeyword)
    }
}
