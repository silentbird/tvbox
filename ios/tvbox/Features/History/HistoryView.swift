import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var showClearAlert = false
    /// 直接播放的历史记录，详情页不带动画推进来垫在播放器下面
    @State private var openedItem: StorageManager.VodHistoryItem?
    @Environment(\.tvboxWideLayout) private var isWideLayout

    var body: some View {
        Group {
            if viewModel.historyItems.isEmpty {
                ContentUnavailableView(
                    "暂无观看记录",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("您观看的影视将会显示在这里")
                )
            } else if isWideLayout {
                historyGrid
            } else {
                historyList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.tvboxBackground)
        .navigationTitle("观看历史")
        .tvboxInlineNavigationBarTitle()
        .toolbar {
            ToolbarItem(placement: .tvboxNavigationBarTrailing) {
                if !viewModel.historyItems.isEmpty {
                    Button("清空") {
                        showClearAlert = true
                    }
                }
            }
        }
        .alert("清空历史记录", isPresented: $showClearAlert) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                viewModel.clearHistory()
            }
        } message: {
            Text("确定要清空所有观看记录吗？")
        }
        .onAppear {
            viewModel.loadHistory()
            viewModel.matchTMDB()
        }
        .navigationDestination(isPresented: Binding(
            get: { openedItem != nil },
            set: { if !$0 { openedItem = nil } }
        )) {
            if let openedItem {
                destination(for: openedItem)
            }
        }
    }
    
    private var historyList: some View {
        List {
            ForEach(groupedHistory, id: \.key) { dateString, items in
                Section {
                    ForEach(items) { item in
                        historyEntry(for: item) {
                            HistoryRow(item: item)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 18))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.tvboxBackground)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.removeHistory(item)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(dateString)
                        .font(.footnote.weight(.bold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.tvboxBackground)
    }

    // 宽布局对应 Android activity_history 的多列网格；鼠标没法左滑，删除放右键菜单
    private var historyGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], alignment: .leading, spacing: 12) {
                ForEach(groupedHistory, id: \.key) { dateString, items in
                    Section {
                        ForEach(items) { item in
                            historyEntry(for: item) {
                                HistoryRow(item: item)
                                    .padding(10)
                                    .tvboxCard(cornerRadius: 14)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.removeHistory(item)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Text(dateString)
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                }
            }
            .padding()
        }
        .background(Color.tvboxBackground)
    }

    /// 存了剧集的记录点击直接播放，详情页同时不带动画推进来，关掉播放器回到详情页；
    /// 旧记录没有剧集，进详情页等加载完再接着播
    @ViewBuilder
    private func historyEntry<RowContent: View>(
        for item: StorageManager.VodHistoryItem,
        @ViewBuilder row: () -> RowContent
    ) -> some View {
        if item.playableSite != nil {
            Button(action: {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { openedItem = item }
            }) {
                row()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(destination: destination(for: item)) {
                row()
            }
        }
    }

    private func destination(for item: StorageManager.VodHistoryItem) -> some View {
        HistoryDestination(item: item)
    }

    private var groupedHistory: [(key: String, value: [StorageManager.VodHistoryItem])] {
        let grouped = Dictionary(grouping: viewModel.historyItems) { item -> String in
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let itemDate = calendar.startOfDay(for: item.updateTime)
            
            if itemDate == today {
                return "今天"
            } else if itemDate == calendar.date(byAdding: .day, value: -1, to: today) {
                return "昨天"
            } else if itemDate >= calendar.date(byAdding: .day, value: -7, to: today)! {
                return "本周"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy年MM月"
                return formatter.string(from: item.updateTime)
            }
        }
        
        let order = ["今天", "昨天", "本周"]
        return grouped.sorted { first, second in
            let firstIndex = order.firstIndex(of: first.key) ?? Int.max
            let secondIndex = order.firstIndex(of: second.key) ?? Int.max
            if firstIndex != Int.max || secondIndex != Int.max {
                return firstIndex < secondIndex
            }
            return first.key > second.key
        }
    }
}

// MARK: - History Destination
/// 详情页带上这条记录接着播，关掉播放器回到详情页。
/// 在 TMDB 详情页看的回到 TMDB 详情页；其它和 Android 一样：站点还在就进详情并接着播放，否则按片名搜索（开启 TMDB 时先搜 TMDB）
struct HistoryDestination: View {
    let item: StorageManager.VodHistoryItem

    var body: some View {
        if let tmdb = item.tmdb, TMDBSettings.isConfigured {
            DetailView(tmdb: tmdb, title: item.vodName, posterURL: item.vodPic, resume: item)
        } else if ApiConfig.shared.sites.contains(where: { $0.key == item.siteKey }) {
            DetailView(movie: MovieItem(vodId: item.vodId, vodName: item.vodName, vodPic: item.vodPic, sourceKey: item.siteKey), resume: item)
        } else if TMDBSettings.isConfigured {
            TMDBSearchView(keyword: item.vodName)
        } else {
            FastSearchView(keyword: item.vodName)
        }
    }
}

// MARK: - History Thumbnail
/// 观看记录的横版封面，底部压进度条
struct HistoryThumbnail: View {
    let item: StorageManager.VodHistoryItem

    var body: some View {
        Color.clear
            .overlay {
                CachedAsyncImage(urlString: item.vodPic) { Color.tvboxSurfaceSecondary }
            }
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(alignment: .bottom) {
                if item.duration > 0 {
                    PlaybackProgressBar(fraction: item.progress / item.duration)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 7)
                }
            }
    }
}

// MARK: - History Row
struct HistoryRow: View {
    let item: StorageManager.VodHistoryItem

    var body: some View {
        HStack(spacing: 12) {
            HistoryThumbnail(item: item)
                .frame(width: 132, height: 74)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.vodName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(progressText)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)

                Text(formatDate(item.updateTime))
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    /// 第12集 · 24:31 / 44:10，没有时长的旧记录只写看到哪一集
    private var progressText: String {
        let episode = item.episodeName ?? "第\(item.episodeIndex + 1)集"
        guard item.duration > 0 else { return "看到\(episode)" }
        return "\(episode) · \(PlayerViewModel.formatTime(item.progress)) / \(PlayerViewModel.formatTime(item.duration))"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

extension StorageManager.VodHistoryItem {
    /// 存了剧集且站点还在时可以直接播放，返回所属站点
    var playableSite: SiteBean? {
        guard playFlag != nil, episodes?.isEmpty == false else { return nil }
        return ApiConfig.shared.sites.first { $0.key == siteKey }
    }
}

// MARK: - History ViewModel
class HistoryViewModel: ObservableObject {
    @Published var historyItems: [StorageManager.VodHistoryItem] = []
    
    private let storageManager = StorageManager.shared
    
    func loadHistory() {
        historyItems = storageManager.getVodHistory()
    }

    private var matchTask: Task<Void, Never>?

    /// 站点详情页播放的没有 TMDB 作品，按片名匹配后补上，之后点开直接进 TMDB 详情页接着播。
    /// 和站点详情页补全资料用同一套匹配和缓存，手动改过的匹配也算
    func matchTMDB() {
        guard TMDBSettings.isConfigured, matchTask == nil else { return }
        let items = historyItems.filter { $0.tmdb == nil }
        guard !items.isEmpty else { return }
        matchTask = Task { @MainActor [weak self] in
            for item in items {
                guard var ref = await TMDBService.shared.ref(siteKey: item.siteKey, vodName: item.vodName, episodeCount: item.episodes?.count ?? 0) else { continue }
                // 片名没写季数的剧集算第一季，TMDB 详情页要季对得上才把上次的站点当作来源
                if ref.mediaType == .tv, ref.season == nil {
                    ref.season = 1
                }
                StorageManager.shared.setHistoryTMDB(ref, for: item.id)
            }
            self?.loadHistory()
            self?.matchTask = nil
        }
    }
    
    func removeHistory(_ item: StorageManager.VodHistoryItem) {
        storageManager.removeVodHistory(vodId: item.vodId, siteKey: item.siteKey)
        loadHistory()
    }
    
    func clearHistory() {
        storageManager.clearVodHistory()
        historyItems.removeAll()
    }
}

#if !targetEnvironment(macCatalyst)
#Preview {
    NavigationView {
        HistoryView()
    }
}
#endif
