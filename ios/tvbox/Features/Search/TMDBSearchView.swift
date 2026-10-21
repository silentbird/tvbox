import SwiftUI

/// TMDB 搜索结果：先出 TMDB 作品，站点在后台用同一个关键词搜一次，结果按片名、年份分到各张卡片。
/// TMDB 没收录、站点能搜到的放在底部，点进去走站点详情页
struct TMDBSearchView: View {
    let keyword: String
    @StateObject private var viewModel = TMDBSearchViewModel()
    /// nil 表示「全部」
    @State private var filter: TMDBMediaType?
    @State private var showsOthers = false
    @Environment(\.tvboxWideLayout) private var isWideLayout

    private var items: [TMDBSearchItem] {
        viewModel.items.filter { filter == nil || $0.mediaType == filter }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                filterBar
                content
            }
            .padding(.vertical, 12)
            // 原生 macOS 的 ScrollView 会按内容收窄
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.tvboxSystemGroupedBackground)
        .navigationTitle(keyword)
        .tvboxInlineNavigationBarTitle()
        .onAppear {
            viewModel.searchIfNeeded(keyword: keyword)
        }
    }

    // MARK: - Filter Bar
    private var filterBar: some View {
        HStack(spacing: 8) {
            filterChip("全部", type: nil)
            filterChip("剧集", type: .tv)
            filterChip("电影", type: .movie)
            Spacer(minLength: 8)
            HStack(spacing: 5) {
                if viewModel.isSearchingSites {
                    ProgressView()
                        .controlSize(.mini)
                    Text("站点 \(viewModel.finishedCount)/\(viewModel.totalCount)")
                } else {
                    Text("\(viewModel.itemsWithSourcesCount) 部有资源")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .monospacedDigit()
            .fixedSize()
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func filterChip(_ title: String, type: TMDBMediaType?) -> some View {
        let isSelected = filter == type
        Button(action: { filter = type }) {
            let label = Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            if isSelected {
                label
                    .foregroundColor(.white)
                    .background(Color.blue, in: Capsule())
            } else {
                label
                    .foregroundColor(.primary)
                    .tvboxGlass(in: Capsule())
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoadingTMDB {
            ProgressView("搜索中...")
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 12) {
                ContentUnavailableView("TMDB 搜索失败", systemImage: "exclamationmark.triangle", description: Text(error))
                NavigationLink("改用站点搜索", destination: FastSearchView(keyword: keyword))
            }
            .frame(maxWidth: .infinity)
        } else {
            if items.isEmpty {
                ContentUnavailableView(
                    "TMDB 没有找到「\(keyword)」",
                    systemImage: "magnifyingglass",
                    description: Text(viewModel.others.isEmpty ? "站点也还没有搜到结果" : "下面是站点搜到的结果")
                )
                .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: isWideLayout ? 140 : 100), spacing: 12)], spacing: 16) {
                    ForEach(items) { item in
                        NavigationLink(destination: detail(for: item)) {
                            card(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            if !viewModel.others.isEmpty {
                othersSection
            }
        }
    }

    private func detail(for item: TMDBSearchItem) -> DetailView {
        DetailView(
            tmdb: viewModel.ref(for: item),
            title: item.title,
            posterURL: TMDBSettings.imageURL(item.posterPath, size: "w342"),
            candidates: viewModel.candidates(for: item)
        )
    }

    // MARK: - Card
    private func card(_ item: TMDBSearchItem) -> some View {
        let count = viewModel.sourceCount(for: item)
        let isEmpty = count == 0 && !viewModel.isSearchingSites
        return VStack(alignment: .leading, spacing: 4) {
            Color.clear
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay {
                    CachedAsyncImage(urlString: TMDBSettings.imageURL(item.posterPath, size: "w342"))
                        .id(item.posterPath)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .bottomLeading) {
                    sourceBadge(count: count)
                        .padding(6)
                }
                .saturation(isEmpty ? 0 : 1)
                .opacity(isEmpty ? 0.55 : 1)

            Text(item.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
            Text([item.mediaType == .tv ? "剧集" : "电影", item.year].compactMap { $0 }.joined(separator: " · "))
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
    }

    /// 查找中 → N 源（还在搜时带转圈）→ 无源
    private func sourceBadge(count: Int) -> some View {
        HStack(spacing: 4) {
            if count > 0 {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("\(count) 源")
            }
            if viewModel.isSearchingSites {
                ProgressView()
                    .controlSize(.mini)
                if count == 0 {
                    Text("查找中")
                }
            } else if count == 0 {
                Text("无源")
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundColor(.white)
        .monospacedDigit()
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .tvboxGlass(in: Capsule())
        // 海报上的角标固定用深色玻璃
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Others
    private var othersSection: some View {
        DisclosureGroup(isExpanded: Binding(get: { showsOthers || items.isEmpty }, set: { showsOthers = $0 })) {
            VStack(spacing: 0) {
                ForEach(viewModel.others) { movie in
                    NavigationLink(destination: DetailView(movie: movie)) {
                        HStack(spacing: 8) {
                            Text(movie.vodName)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Spacer()
                            Text([viewModel.siteName(for: movie), movie.vodRemarks].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .font(.subheadline)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        } label: {
            HStack {
                Text("站点结果（TMDB 未收录）")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.others.count)")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.tvboxSystemBackground, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - TMDB Search ViewModel
@MainActor
final class TMDBSearchViewModel: ObservableObject {
    @Published private(set) var items: [TMDBSearchItem] = []
    @Published private(set) var isLoadingTMDB = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var finishedCount = 0
    @Published private(set) var totalCount = 0
    /// TMDB 作品 → 片名对得上的站点影片（含可能相关的，进详情页再复查）
    @Published private(set) var matched: [String: [MovieItem]] = [:]
    /// TMDB 作品 → 片名、年份都对得上的站点
    @Published private(set) var sureSites: [String: Set<String>] = [:]
    /// 和哪部 TMDB 作品都对不上的站点影片
    @Published private(set) var others: [MovieItem] = []

    /// 关键词里带的季，如「庆余年 第二季」
    private var season: Int?
    private var query = ""
    private var siteItems: [MovieItem] = []
    private var tmdbTask: Task<Void, Never>?
    private var siteTask: Task<Void, Never>?

    var isSearchingSites: Bool { finishedCount < totalCount }

    var itemsWithSourcesCount: Int {
        sureSites.values.filter { !$0.isEmpty }.count
    }

    deinit {
        tmdbTask?.cancel()
        siteTask?.cancel()
    }

    func sourceCount(for item: TMDBSearchItem) -> Int {
        sureSites[item.id]?.count ?? 0
    }

    func candidates(for item: TMDBSearchItem) -> [MovieItem] {
        matched[item.id] ?? []
    }

    func ref(for item: TMDBSearchItem) -> TMDBRef {
        TMDBRef(mediaType: item.mediaType, id: item.tmdbID, season: item.mediaType == .tv ? season : nil)
    }

    func siteName(for movie: MovieItem) -> String? {
        ApiConfig.shared.sites.first { $0.key == movie.sourceKey }?.name
    }

    /// 从详情页返回时 onAppear 会再次触发，只搜索一次
    func searchIfNeeded(keyword: String) {
        guard siteTask == nil else { return }
        // TMDB 和站点都用去掉季数的片名搜，站点会把各季都搜出来
        let parsed = TMDBService.parseTitle(keyword)
        query = parsed.query.isEmpty ? keyword : parsed.query
        season = parsed.season

        isLoadingTMDB = true
        tmdbTask = Task { [weak self, query] in
            let result: Result<[TMDBSearchItem], Error>
            do {
                result = .success(try await TMDBService.shared.search(query: query))
            } catch {
                result = .failure(error)
            }
            guard let self else { return }
            switch result {
            case .success(let items):
                self.items = items
                rematchAll()
            case .failure(let error):
                errorMessage = AppErrorMessage.userMessage(for: error)
            }
            isLoadingTMDB = false
        }

        let sites = SiteSearcher.sites
        totalCount = sites.count
        siteTask = Task { [weak self, query] in
            for await (_, items) in SiteSearcher.searchAll(keyword: query, sites: sites) {
                guard let self else { return }
                finishedCount += 1
                let relevant = items.filter { self.containsKeyword($0.vodName) }
                siteItems.append(contentsOf: relevant)
                assign(relevant)
            }
        }
    }

    // MARK: - Private Methods

    /// TMDB 结果晚于部分站点结果返回时，把已有的站点影片重新分一遍
    private func rematchAll() {
        matched = [:]
        sureSites = [:]
        others = []
        assign(siteItems)
    }

    private func assign(_ movies: [MovieItem]) {
        for movie in movies {
            var hit = false
            for item in items {
                guard let match = SourceMatcher.match(name: movie.vodName, year: movie.vodYear, target: target(for: item)) else { continue }
                hit = true
                matched[item.id, default: []].append(movie)
                if match.confidence == .sure, let siteKey = movie.sourceKey {
                    sureSites[item.id, default: []].insert(siteKey)
                }
            }
            if !hit {
                others.append(movie)
            }
        }
    }

    /// 搜索页还不知道看哪一季，剧集不比季和年份
    private func target(for item: TMDBSearchItem) -> SourceMatcher.Target {
        SourceMatcher.Target(
            mediaType: item.mediaType,
            titles: [item.title, item.originalTitle].compactMap { $0 },
            season: nil,
            year: item.year.flatMap { Int($0) },
            episodeCount: nil
        )
    }

    /// 和快速搜索一样，片名需包含关键词按空格拆开后的每一段
    private func containsKeyword(_ name: String) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace)
        return !words.isEmpty && words.allSatisfy { name.contains($0) }
    }
}
