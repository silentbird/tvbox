import SwiftUI

struct CollectView: View {
    @StateObject private var viewModel = CollectViewModel()
    @State private var showClearAlert = false
    @Environment(\.tvboxWideLayout) private var isWideLayout
    
    var body: some View {
        Group {
            if viewModel.collectItems.isEmpty {
                ContentUnavailableView(
                    "暂无收藏",
                    systemImage: "heart.slash",
                    description: Text("您收藏的影视将会显示在这里")
                )
            } else {
                collectGrid
            }
        }
        .navigationTitle("我的收藏")
        .tvboxInlineNavigationBarTitle()
        .toolbar {
            ToolbarItem(placement: .tvboxNavigationBarTrailing) {
                if !viewModel.collectItems.isEmpty {
                    Button("清空") {
                        showClearAlert = true
                    }
                }
            }
        }
        .alert("清空收藏", isPresented: $showClearAlert) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                viewModel.clearCollects()
            }
        } message: {
            Text("确定要清空所有收藏吗？")
        }
        .onAppear {
            viewModel.loadCollects()
            viewModel.matchTMDB()
        }
    }
    
    private var collectGrid: some View {
        ScrollView {
            // 和 TMDB 搜索结果一样的竖版海报网格
            LazyVGrid(columns: [GridItem(.adaptive(minimum: isWideLayout ? 140 : 100), spacing: 12)], spacing: 16) {
                ForEach(viewModel.collectItems) { item in
                    NavigationLink(destination: destination(for: item)) {
                        CollectItemCard(item: item, metadata: viewModel.metadata[item.id]) {
                            viewModel.removeCollect(item)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    /// 在 TMDB 详情页收藏的回到 TMDB 详情页；其它和 Android 一样：站点还在就进详情，否则按片名搜索（开启 TMDB 时先搜 TMDB）
    @ViewBuilder
    private func destination(for item: StorageManager.VodCollectItem) -> some View {
        if let tmdb = item.tmdb, TMDBSettings.isConfigured {
            DetailView(tmdb: tmdb, title: item.vodName, posterURL: item.vodPic, candidates: [MovieItem(vodId: item.vodId, vodName: item.vodName, sourceKey: item.siteKey)])
        } else if ApiConfig.shared.sites.contains(where: { $0.key == item.siteKey }) {
            DetailView(movie: MovieItem(vodId: item.vodId, vodName: item.vodName, vodPic: item.vodPic, sourceKey: item.siteKey))
        } else if TMDBSettings.isConfigured {
            TMDBSearchView(keyword: item.vodName)
        } else {
            FastSearchView(keyword: item.vodName)
        }
    }
}

// MARK: - Collect Item Card
/// 和 TMDB 搜索结果的卡片一样：海报、片名、类型和年份。匹配到 TMDB 作品时用 TMDB 的资料，否则用站点的
struct CollectItemCard: View {
    let item: StorageManager.VodCollectItem
    let metadata: VodMetadata?
    let onRemove: () -> Void
    
    @State private var showRemoveAlert = false

    private var posterURL: String? {
        TMDBSettings.imageURL(metadata?.posterPath, size: "w342") ?? item.vodPic
    }

    private var subtitle: String? {
        if let metadata {
            let year = metadata.releaseDate.map { String($0.prefix(4)) }
            return [metadata.mediaType == .tv ? "剧集" : "电影", year].compactMap { $0 }.joined(separator: " · ")
        }
        return item.vodRemarks.flatMap { $0.isEmpty ? nil : $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Color.clear
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay {
                    CachedAsyncImage(urlString: posterURL)
                        .id(posterURL)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(metadata?.title ?? item.vodName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) {
                showRemoveAlert = true
            } label: {
                Label("取消收藏", systemImage: "heart.slash")
            }
        }
        .alert("取消收藏", isPresented: $showRemoveAlert) {
            Button("取消", role: .cancel) {}
            Button("确定", role: .destructive) {
                onRemove()
            }
        } message: {
            Text("确定要取消收藏「\(metadata?.title ?? item.vodName)」吗？")
        }
    }
}

// MARK: - Collect ViewModel
class CollectViewModel: ObservableObject {
    @Published var collectItems: [StorageManager.VodCollectItem] = []
    /// 匹配到 TMDB 作品的收藏的资料，按收藏的 id
    @Published private(set) var metadata: [String: VodMetadata] = [:]
    
    private let storageManager = StorageManager.shared
    
    func loadCollects() {
        collectItems = storageManager.getCollects()
        loadMetadata()
    }

    private var metadataTask: Task<Void, Never>?

    /// 收藏按作品算，剧集取第一季的资料，年份是首播年份
    private func loadMetadata() {
        guard TMDBSettings.isConfigured else { return }
        let items = collectItems.filter { $0.tmdb != nil && metadata[$0.id] == nil }
        guard !items.isEmpty else { return }
        metadataTask?.cancel()
        metadataTask = Task { @MainActor [weak self] in
            for item in items {
                guard let ref = item.tmdb,
                      let value = await TMDBService.shared.metadata(type: ref.mediaType, id: ref.id, season: 1),
                      !Task.isCancelled else { continue }
                self?.metadata[item.id] = value
            }
        }
    }

    private var matchTask: Task<Void, Never>?

    /// 站点详情页收藏的没有 TMDB 作品，按片名匹配后补上，之后点开直接进 TMDB 详情页。
    /// 和站点详情页补全资料用同一套匹配和缓存，手动改过的匹配也算
    func matchTMDB() {
        guard TMDBSettings.isConfigured, matchTask == nil else { return }
        let items = collectItems.filter { $0.tmdb == nil }
        guard !items.isEmpty else { return }
        matchTask = Task { @MainActor [weak self] in
            for item in items {
                // 收藏没存集数，只能靠片名里的季数判断是不是剧集
                guard let ref = await TMDBService.shared.ref(siteKey: item.siteKey, vodName: item.vodName, episodeCount: 0) else { continue }
                StorageManager.shared.setCollectTMDB(ref, for: item.id)
            }
            self?.loadCollects()
            self?.matchTask = nil
        }
    }

    func removeCollect(_ item: StorageManager.VodCollectItem) {
        var collects = storageManager.getCollects()
        collects.removeAll { $0.id == item.id }
        
        // 直接更新 UserDefaults
        if let data = try? JSONEncoder().encode(collects) {
            UserDefaults.standard.setCodable(data, forKey: "vod_collect")
        }
        
        loadCollects()
    }
    
    func clearCollects() {
        storageManager.clearCollects()
        collectItems.removeAll()
    }
}

#if !targetEnvironment(macCatalyst)
#Preview {
    NavigationView {
        CollectView()
    }
}
#endif
