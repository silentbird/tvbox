import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var showClearAlert = false
    /// 正在直接播放的历史记录
    @State private var playingItem: StorageManager.VodHistoryItem?
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
        }
        .tvboxFullScreenCover(item: $playingItem) { item in
            player(for: item)
        }
    }
    
    private var historyList: some View {
        List {
            ForEach(groupedHistory, id: \.key) { dateString, items in
                Section(header: Text(dateString)) {
                    ForEach(items) { item in
                        historyEntry(for: item) {
                            HistoryRow(item: item)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.removeHistory(item)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .tvboxInsetGroupedListStyle()
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
                                    .background(Color.tvboxSystemBackground)
                                    .cornerRadius(10)
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
        .background(Color.tvboxSystemGroupedBackground)
    }

    /// 存了剧集的记录点击直接播放；旧记录没有剧集，进详情页接着播
    @ViewBuilder
    private func historyEntry<RowContent: View>(
        for item: StorageManager.VodHistoryItem,
        @ViewBuilder row: () -> RowContent
    ) -> some View {
        if viewModel.playableSite(for: item) != nil {
            Button(action: { playingItem = item }) {
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

    @ViewBuilder
    private func player(for item: StorageManager.VodHistoryItem) -> some View {
        if let site = viewModel.playableSite(for: item), let flag = item.playFlag, let episodes = item.episodes {
            // 历史只存了上次播放的线路
            PlayerView(
                title: item.vodName,
                sources: [PlaySource(flag: flag, episodes: episodes)],
                sourceIndex: 0,
                episodeIndex: episodes.indices.contains(item.episodeIndex) ? item.episodeIndex : 0,
                startPosition: item.progress,
                configKey: item.id,
                resolvePlayUrl: { flag, episode in try await resolvePlayAddress(site: site, flag: flag, episode: episode) },
                onProgress: { _, episodeIndex, position, duration in
                    viewModel.recordProgress(item, episodeIndex: episodeIndex, progress: position, duration: duration)
                }
            )
        }
    }

    /// 和 Android 一样：站点还在就进详情并接着播放，否则按片名快速搜索
    @ViewBuilder
    private func destination(for item: StorageManager.VodHistoryItem) -> some View {
        if ApiConfig.shared.sites.contains(where: { $0.key == item.siteKey }) {
            DetailView(movie: MovieItem(vodId: item.vodId, vodName: item.vodName, vodPic: item.vodPic, sourceKey: item.siteKey), autoPlay: true)
        } else {
            FastSearchView(keyword: item.vodName)
        }
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

// MARK: - History Row
struct HistoryRow: View {
    let item: StorageManager.VodHistoryItem
    
    var body: some View {
        HStack(spacing: 12) {
            // 封面
            AsyncImage(url: URL(string: item.vodPic ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 100, height: 60)
            .cornerRadius(6)
            .clipped()
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(item.vodName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                // 播放进度
                HStack(spacing: 4) {
                    Text("看到\(item.episodeName ?? "第\(item.episodeIndex + 1)集")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if item.duration > 0 {
                        Text("·")
                            .foregroundColor(.secondary)
                        
                        let progress = item.progress / item.duration
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                // 进度条
                if item.duration > 0 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.tvboxSystemGray5)
                                .frame(height: 3)
                            
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * CGFloat(item.progress / item.duration), height: 3)
                        }
                        .cornerRadius(1.5)
                    }
                    .frame(height: 3)
                }
            }
            
            Spacer()
            
            // 时间
            Text(formatDate(item.updateTime))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - History ViewModel
class HistoryViewModel: ObservableObject {
    @Published var historyItems: [StorageManager.VodHistoryItem] = []
    
    private let storageManager = StorageManager.shared
    
    func loadHistory() {
        historyItems = storageManager.getVodHistory()
    }
    
    /// 可以直接播放时返回所属站点；旧记录没存剧集或站点已不在时返回 nil
    func playableSite(for item: StorageManager.VodHistoryItem) -> SiteBean? {
        guard item.playFlag != nil, item.episodes?.isEmpty == false else { return nil }
        return ApiConfig.shared.sites.first { $0.key == item.siteKey }
    }

    /// 从历史直接播放时记录进度，和详情页一样同时更新历史和该集的进度
    func recordProgress(_ item: StorageManager.VodHistoryItem, episodeIndex: Int, progress: Double, duration: Double) {
        storageManager.updateHistory(item, episodeIndex: episodeIndex, progress: progress, duration: duration)
        if let flag = item.playFlag, let episodes = item.episodes, episodes.indices.contains(episodeIndex) {
            storageManager.savePlayProgress(StorageManager.PlayProgressItem(
                vodId: item.vodId,
                siteKey: item.siteKey,
                flag: flag,
                episodeIndex: episodeIndex,
                episodeName: episodes[episodeIndex].name,
                progress: progress,
                duration: duration
            ))
        }
        loadHistory()
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
