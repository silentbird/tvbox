import SwiftUI

struct DetailView: View {
    let movie: MovieItem
    @StateObject private var viewModel = DetailViewModel()
    @State private var selectedSourceIndex = 0
    @State private var showPlayer = false
    @State private var selectedEpisodeIndex: Int?
    @Environment(\.tvboxWideLayout) private var isWideLayout

    var body: some View {
        Group {
            if movie.vodId.hasPrefix("msearch:") {
                // 豆瓣等推荐站点的卡片没有详情，和 Android 一样按片名跳转快速搜索
                FastSearchView(keyword: movie.vodName)
            } else if isCatNodeConfigCenterMovie {
                CatNodeConfigCenterView()
                    .tvboxInlineNavigationBarTitle()
            } else if let configCenterURL {
                ConfigCenterWebView(urlString: configCenterURL)
                    .tvboxInlineNavigationBarTitle()
            } else {
                detailContent
            }
        }
    }

    private var configCenterURL: String? {
        guard isConfigCenterMovie else {
            return nil
        }

        if let url = movie.vodPlayUrl, !url.isEmpty {
            return url
        }

        let siteAPI = ApiConfig.shared.currentSite?.api.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return siteAPI.isEmpty ? nil : siteAPI
    }

    /// Node 运行的配置包「配置|中心」站点首页卡片，直接打开配置包自带的 `/website`。
    private var isCatNodeConfigCenterMovie: Bool {
        movie.vodId == "config-center" && ApiConfig.shared.currentSite?.catNodeApi != nil
    }

    /// 详情所属站点：搜索结果带来源站点，否则为当前站点
    private var site: SiteBean? {
        let apiConfig = ApiConfig.shared
        if let sourceKey = movie.sourceKey, let site = apiConfig.sites.first(where: { $0.key == sourceKey }) {
            return site
        }
        return apiConfig.currentSite
    }

    private var isConfigCenterMovie: Bool {
        movie.vodTag == "config_center" ||
            movie.vodId == "config_center" ||
            (movie.typeName == "配置" && movie.vodName.contains("配置"))
    }

    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if isWideLayout {
                    wideHeaderSection
                } else {
                    // 顶部封面区域
                    headerSection

                    // 信息区域
                    infoSection
                }

                // 播放源和剧集
                if let vodInfo = viewModel.vodInfo {
                    playSourceSection(vodInfo: vodInfo)
                }
            }
        }
        .background(Color.tvboxSystemGroupedBackground)
        .tvboxInlineNavigationBarTitle()
        .toolbar {
            // 宽布局的收藏按钮在信息区的按钮行里
            if !isWideLayout {
                ToolbarItem(placement: .tvboxNavigationBarTrailing) {
                    Button(action: { viewModel.toggleCollect() }) {
                        Image(systemName: viewModel.isCollected ? "heart.fill" : "heart")
                            .foregroundColor(viewModel.isCollected ? .red : .primary)
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        .tvboxFullScreenCover(isPresented: $showPlayer) {
            if let episodeIndex = selectedEpisodeIndex, let vodInfo = viewModel.vodInfo {
                let sourceIndex = selectedSourceIndex
                let flag = vodInfo.playFlags.indices.contains(sourceIndex) ? vodInfo.playFlags[sourceIndex] : ""
                PlayerView(
                    vodInfo: vodInfo,
                    sourceIndex: sourceIndex,
                    episodeIndex: episodeIndex,
                    startPosition: viewModel.resumePosition(sourceIndex: sourceIndex, episodeIndex: episodeIndex),
                    resolvePlayUrl: { episode in try await viewModel.getPlayUrlAsync(flag: flag, episode: episode) },
                    onProgress: { episodeIndex, position, duration in
                        viewModel.addToHistory(sourceIndex: sourceIndex, episodeIndex: episodeIndex, progress: position, duration: duration)
                    }
                )
            }
        }
        .onAppear {
            viewModel.loadDetail(vodId: movie.vodId, site: site)
        }
        .onChange(of: viewModel.vodInfo?.vodId) { _, _ in
            // 和 Android 一样恢复上次播放的线路
            if let history = viewModel.history, let vodInfo = viewModel.vodInfo,
               history.playIndex < vodInfo.playUrls.count {
                selectedSourceIndex = history.playIndex
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            // 背景图片
            AsyncImage(url: URL(string: movie.vodPic ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .frame(height: 300)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // 标题和备注
            VStack(alignment: .leading, spacing: 8) {
                Text(movie.vodName)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if let remarks = movie.vodRemarks, !remarks.isEmpty {
                    Text(remarks)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(4)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Wide Header Section
    // 对应 Android activity_detail: 左边海报，右边信息和按钮行
    private var wideHeaderSection: some View {
        HStack(alignment: .top, spacing: 20) {
            CachedAsyncImage(urlString: posterURL)
                .id(posterURL)
                .frame(width: 200, height: 280)
                .clipped()
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text(movie.vodName)
                        .font(.title)
                        .fontWeight(.bold)
                        .lineLimit(2)

                    if let remarks = movie.vodRemarks, !remarks.isEmpty {
                        tagView(text: remarks, color: .blue)
                    }
                }

                infoRows

                Spacer(minLength: 0)

                wideActionRow
            }
            .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
        }
        .padding()
        .background(Color.tvboxSystemBackground)
    }

    private var posterURL: String? {
        [viewModel.vodInfo?.vodPic, movie.vodPic].compactMap { $0 }.first { !$0.isEmpty }
    }

    private var wideActionRow: some View {
        HStack(spacing: 12) {
            if let vodInfo = viewModel.vodInfo,
               selectedSourceIndex < vodInfo.playUrls.count,
               !vodInfo.playUrls[selectedSourceIndex].isEmpty {
                Button(action: {
                    selectedEpisodeIndex = viewModel.playIndex(sourceIndex: selectedSourceIndex)
                    showPlayer = true
                }) {
                    Label("播放", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            NavigationLink(destination: FastSearchView(keyword: movie.vodName)) {
                Label("快搜", systemImage: "magnifyingglass")
            }
            .buttonStyle(.bordered)

            Button(action: { viewModel.toggleCollect() }) {
                Label(viewModel.isCollected ? "已收藏" : "收藏", systemImage: viewModel.isCollected ? "heart.fill" : "heart")
            }
            .buttonStyle(.bordered)
            .tint(viewModel.isCollected ? .red : nil)
        }
        .controlSize(.large)
    }

    // MARK: - Info Section
    private var infoSection: some View {
        infoRows
            .padding()
            .background(Color.tvboxSystemBackground)
    }

    private var infoRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标签行
            HStack(spacing: 12) {
                if let year = movie.vodYear, !year.isEmpty {
                    tagView(text: year, color: .blue)
                }
                if let area = movie.vodArea, !area.isEmpty {
                    tagView(text: area, color: .green)
                }
                if let typeName = movie.typeName, !typeName.isEmpty {
                    tagView(text: typeName, color: .orange)
                }
            }
            
            // 演员
            if let vodInfo = viewModel.vodInfo, let actor = vodInfo.vodActor, !actor.isEmpty {
                HStack(alignment: .top) {
                    Text("演员:")
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .leading)
                    Text(actor)
                        .lineLimit(2)
                }
                .font(.subheadline)
            }
            
            // 导演
            if let vodInfo = viewModel.vodInfo, let director = vodInfo.vodDirector, !director.isEmpty {
                HStack(alignment: .top) {
                    Text("导演:")
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .leading)
                    Text(director)
                }
                .font(.subheadline)
            }
            
            // 简介
            if let vodInfo = viewModel.vodInfo, let content = vodInfo.vodContent, !content.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("简介")
                        .font(.headline)
                    Text(content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Play Source Section
    private func playSourceSection(vodInfo: VodInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 播放源选择
            if vodInfo.playFlags.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(vodInfo.playFlags.enumerated()), id: \.offset) { index, flag in
                            Button(action: { selectedSourceIndex = index }) {
                                Text(flag)
                                    .font(.subheadline)
                                    .fontWeight(selectedSourceIndex == index ? .semibold : .regular)
                                    .foregroundColor(selectedSourceIndex == index ? .white : .primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedSourceIndex == index ? Color.blue : Color.tvboxSystemGray5)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // 剧集列表
            if selectedSourceIndex < vodInfo.playUrls.count {
                let episodes = vodInfo.playUrls[selectedSourceIndex]
                let playIndex = viewModel.playIndex(sourceIndex: selectedSourceIndex)
                
                HStack {
                    Text("选集 (\(episodes.count))")
                        .font(.headline)
                    
                    Spacer()
                    
                    if !episodes.isEmpty {
                        Button(action: {
                            selectedEpisodeIndex = playIndex
                            showPlayer = true
                        }) {
                            Label("立即播放", systemImage: "play.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: isWideLayout ? 120 : 70), spacing: 8)], spacing: 8) {
                    ForEach(Array(episodes.enumerated()), id: \.element.id) { index, episode in
                        let isPlayIndex = index == playIndex
                        Button(action: {
                            selectedEpisodeIndex = index
                            showPlayer = true
                        }) {
                            Text(episode.name)
                                .font(.caption)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(isPlayIndex ? Color.blue : Color.tvboxSystemGray5)
                                .foregroundColor(isPlayIndex ? .white : .primary)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color.tvboxSystemBackground)
    }
    
    // MARK: - Helper Views
    private func tagView(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.8))
            .cornerRadius(4)
    }
}

// MARK: - Detail ViewModel
@MainActor
class DetailViewModel: ObservableObject {
    @Published var vodInfo: VodInfo?
    @Published var isLoading = false
    @Published var isCollected = false
    /// 该视频的播放记录
    @Published private(set) var history: StorageManager.VodHistoryItem?
    @Published var error: Error?
    @Published var playerContent: PlayerContent?
    @Published var isLoadingPlayer = false
    @Published var parsedUrl: URL?
    @Published var parsedHeaders: [String: String]?
    @Published var parseStatus: String = ""
    
    private var site: SiteBean?
    private let apiConfig = ApiConfig.shared
    private let storageManager = StorageManager.shared
    private let spiderManager = SpiderManager.shared
    private let parserManager = ParserManager.shared
    
    /// 加载视频详情
    /// - Parameters:
    ///   - vodId: 视频ID
    ///   - site: 视频所属站点
    func loadDetail(vodId: String, site: SiteBean?) {
        guard let site else { return }
        
        self.site = site
        isLoading = true
        error = nil
        
        Task {
            do {
                let details = try await spiderManager.detailContent(site: site, ids: [vodId])
                await MainActor.run {
                    self.vodInfo = details.first
                    self.isLoading = false
                    self.checkCollected(vodId: vodId)
                    self.history = self.storageManager.getVodHistory().first { $0.vodId == vodId && $0.siteKey == site.key }
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    /// 加载视频详情 (使用 MovieItem)
    /// - Parameters:
    ///   - movie: 视频项
    ///   - site: 视频所属站点
    func loadDetail(movie: MovieItem, site: SiteBean?) {
        loadDetail(vodId: movie.vodId, site: site)
    }
    
    /// 获取播放地址
    /// - Parameters:
    ///   - flag: 播放源标识
    ///   - episode: 剧集信息
    func loadPlayerContent(flag: String, episode: VodInfo.VodPlayItem) {
        guard let site else { return }
        
        isLoadingPlayer = true
        playerContent = nil
        parsedUrl = nil
        parsedHeaders = nil
        parseStatus = "正在获取播放信息..."
        
        Task {
            do {
                // 1. 获取播放内容
                var content = try await spiderManager.playerContent(site: site, flag: flag, id: episode.url)
                let initialContent = content
                
                await MainActor.run {
                    self.playerContent = initialContent
                }
                
                // 2. 检查是否需要解析
                if content.needParse {
                    await MainActor.run {
                        self.parseStatus = "正在解析播放地址..."
                    }
                    
                    // 调用解析接口
                    content = try await parserManager.parse(content: content)
                    let parsedContent = content
                    
                    await MainActor.run {
                        self.playerContent = parsedContent
                    }
                }
                
                // 3. 设置最终的播放 URL
                let finalContent = content
                await MainActor.run {
                    if let url = URL(string: finalContent.url) {
                        self.parsedUrl = url
                        self.parsedHeaders = finalContent.header
                        self.parseStatus = ""
                    } else {
                        self.parseStatus = "无效的播放地址"
                    }
                    self.isLoadingPlayer = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.parseStatus = "解析失败: \(AppErrorMessage.userMessage(for: error))"
                    self.isLoadingPlayer = false
                }
            }
        }
    }
    
    /// 获取实际播放地址
    /// - Returns: 可播放的 URL 和 headers
    func getPlayUrl() -> (url: URL?, headers: [String: String]?) {
        // 优先返回已解析的 URL
        if let parsedUrl = parsedUrl {
            return (parsedUrl, parsedHeaders)
        }
        
        // 否则返回原始 URL
        guard let content = playerContent else { return (nil, nil) }
        return (URL(string: content.url), content.header)
    }
    
    /// 异步获取播放地址 (带解析)
    /// - Parameters:
    ///   - flag: 播放源标识
    ///   - episode: 剧集信息
    /// - Returns: 可播放的 URL、headers 和站点给出的媒体格式
    func getPlayUrlAsync(flag: String, episode: VodInfo.VodPlayItem) async throws -> (url: URL, headers: [String: String]?, format: String?) {
        guard let site else { throw SpiderError.invalidSite }
        
        // 1. 获取播放内容
        var content = try await spiderManager.playerContent(site: site, flag: flag, id: episode.url)
        
        // jx=1 时和 Android 一样改用默认解析
        if content.jxFrom == "1" {
            content.parse = 1
            content.playUrl = nil
        }
        
        // 2. 如果需要解析
        if content.needParse {
            content = try await parserManager.parse(content: content)
        }
        
        // 3. 返回 URL
        guard let url = URL(string: content.url) else {
            throw ParserError.invalidUrl
        }
        
        return (url, content.header, content.format)
    }
    
    /// 切换收藏状态
    func toggleCollect() {
        guard let vodInfo = vodInfo, let site else { return }
        
        if isCollected {
            storageManager.removeCollect(vodId: vodInfo.vodId, siteKey: site.key)
        } else {
            storageManager.addCollect(vodInfo: vodInfo, site: site)
        }
        isCollected.toggle()
    }
    
    /// 添加到历史记录
    /// - Parameters:
    ///   - sourceIndex: 播放源索引
    ///   - episodeIndex: 剧集索引
    ///   - progress: 播放进度 (秒)
    ///   - duration: 总时长 (秒)
    func addToHistory(sourceIndex: Int, episodeIndex: Int, progress: Double, duration: Double) {
        guard let vodInfo = vodInfo, let site,
              sourceIndex < vodInfo.playFlags.count, sourceIndex < vodInfo.playUrls.count,
              episodeIndex < vodInfo.playUrls[sourceIndex].count else { return }
        let episodeName = vodInfo.playUrls[sourceIndex][episodeIndex].name
        history = storageManager.addHistory(
            vodInfo: vodInfo,
            site: site,
            sourceIndex: sourceIndex,
            episodeIndex: episodeIndex,
            episodeName: episodeName,
            progress: progress,
            duration: duration
        )
        storageManager.savePlayProgress(StorageManager.PlayProgressItem(
            vodId: vodInfo.vodId,
            siteKey: site.key,
            flag: vodInfo.playFlags[sourceIndex],
            episodeIndex: episodeIndex,
            episodeName: episodeName,
            progress: progress,
            duration: duration
        ))
    }
    
    /// 该剧集上次的播放位置 (秒)，没有记录时从头播放
    func resumePosition(sourceIndex: Int, episodeIndex: Int) -> Double {
        guard let vodInfo = vodInfo, let site,
              sourceIndex < vodInfo.playFlags.count, sourceIndex < vodInfo.playUrls.count,
              episodeIndex < vodInfo.playUrls[sourceIndex].count else { return 0 }
        return storageManager.getPlayProgress(
            vodId: vodInfo.vodId,
            siteKey: site.key,
            flag: vodInfo.playFlags[sourceIndex],
            episodeIndex: episodeIndex,
            episodeName: vodInfo.playUrls[sourceIndex][episodeIndex].name
        )?.progress ?? 0
    }
    
    /// 当前播放源下选中的剧集，对应 Android 的 vodInfo.playIndex：
    /// 有播放记录时选中上次看的那一集，切换播放源后按集名找到对应剧集，否则选中第一集
    func playIndex(sourceIndex: Int) -> Int {
        guard let vodInfo, sourceIndex < vodInfo.playUrls.count else { return 0 }
        let episodes = vodInfo.playUrls[sourceIndex]
        guard let history else { return 0 }
        if history.playIndex == sourceIndex {
            return history.episodeIndex < episodes.count ? history.episodeIndex : 0
        }
        return episodes.firstIndex { $0.name == history.episodeName } ?? 0
    }
    
    private func checkCollected(vodId: String) {
        guard let site else { return }
        isCollected = storageManager.isCollected(vodId: vodId, siteKey: site.key)
    }
}

#if !targetEnvironment(macCatalyst)
#Preview {
    NavigationView {
        DetailView(movie: try! JSONDecoder().decode(
            MovieItem.self,
            from: """
            {"vod_id": "1", "vod_name": "测试电影", "vod_pic": "", "vod_remarks": "更新至10集"}
            """.data(using: .utf8)!
        ))
    }
}
#endif
