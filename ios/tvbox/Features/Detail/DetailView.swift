import SwiftUI

struct DetailView: View {
    let movie: MovieItem
    @StateObject private var viewModel = DetailViewModel()
    @State private var selectedSourceIndex = 0
    @State private var showPlayer = false
    @State private var selectedEpisode: VodInfo.VodPlayItem?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 顶部封面区域
                headerSection
                
                // 信息区域
                infoSection
                
                // 播放源和剧集
                if let vodInfo = viewModel.vodInfo {
                    playSourceSection(vodInfo: vodInfo)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { viewModel.toggleCollect() }) {
                    Image(systemName: viewModel.isCollected ? "heart.fill" : "heart")
                        .foregroundColor(viewModel.isCollected ? .red : .primary)
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
        .fullScreenCover(isPresented: $showPlayer) {
            if let episode = selectedEpisode, let vodInfo = viewModel.vodInfo {
                PlayerView(
                    vodInfo: vodInfo,
                    sourceIndex: selectedSourceIndex,
                    episode: episode
                )
            }
        }
        .onAppear {
            viewModel.loadDetail(vodId: movie.vodId)
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
    
    // MARK: - Info Section
    private var infoSection: some View {
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
        .padding()
        .background(Color(.systemBackground))
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
                                    .background(selectedSourceIndex == index ? Color.blue : Color(.systemGray5))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // 剧集列表
            if selectedSourceIndex < vodInfo.playUrls.count {
                let episodes = vodInfo.playUrls[selectedSourceIndex]
                
                Text("选集 (\(episodes.count))")
                    .font(.headline)
                    .padding(.horizontal)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                    ForEach(episodes) { episode in
                        Button(action: {
                            selectedEpisode = episode
                            showPlayer = true
                        }) {
                            Text(episode.name)
                                .font(.caption)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(6)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
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
class DetailViewModel: ObservableObject {
    @Published var vodInfo: VodInfo?
    @Published var isLoading = false
    @Published var isCollected = false
    @Published var error: Error?
    @Published var playerContent: PlayerContent?
    @Published var isLoadingPlayer = false
    @Published var parsedUrl: URL?
    @Published var parsedHeaders: [String: String]?
    @Published var parseStatus: String = ""
    
    private let apiConfig = ApiConfig.shared
    private let storageManager = StorageManager.shared
    private let spiderManager = SpiderManager.shared
    private let parserManager = ParserManager.shared
    
    /// 加载视频详情
    /// - Parameter vodId: 视频ID
    func loadDetail(vodId: String) {
        guard apiConfig.currentSite != nil else { return }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                let details = try await spiderManager.detailContent(ids: [vodId])
                await MainActor.run {
                    self.vodInfo = details.first
                    self.isLoading = false
                    self.checkCollected(vodId: vodId)
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
    /// - Parameter movie: 视频项
    func loadDetail(movie: MovieItem) {
        loadDetail(vodId: movie.vodId)
    }
    
    /// 获取播放地址
    /// - Parameters:
    ///   - flag: 播放源标识
    ///   - episode: 剧集信息
    func loadPlayerContent(flag: String, episode: VodInfo.VodPlayItem) {
        isLoadingPlayer = true
        playerContent = nil
        parsedUrl = nil
        parsedHeaders = nil
        parseStatus = "正在获取播放信息..."
        
        Task {
            do {
                // 1. 获取播放内容
                var content = try await spiderManager.playerContent(flag: flag, id: episode.url)
                
                await MainActor.run {
                    self.playerContent = content
                }
                
                // 2. 检查是否需要解析
                if content.needParse {
                    await MainActor.run {
                        self.parseStatus = "正在解析播放地址..."
                    }
                    
                    // 调用解析接口
                    content = try await parserManager.parse(content: content)
                    
                    await MainActor.run {
                        self.playerContent = content
                    }
                }
                
                // 3. 设置最终的播放 URL
                await MainActor.run {
                    if let url = URL(string: content.url) {
                        self.parsedUrl = url
                        self.parsedHeaders = content.header
                        self.parseStatus = ""
                    } else {
                        self.parseStatus = "无效的播放地址"
                    }
                    self.isLoadingPlayer = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.parseStatus = "解析失败: \(error.localizedDescription)"
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
    /// - Returns: 可播放的 URL 和 headers
    func getPlayUrlAsync(flag: String, episode: VodInfo.VodPlayItem) async throws -> (url: URL, headers: [String: String]?) {
        // 1. 获取播放内容
        var content = try await spiderManager.playerContent(flag: flag, id: episode.url)
        
        // 2. 如果需要解析
        if content.needParse {
            content = try await parserManager.parse(content: content)
        }
        
        // 3. 返回 URL
        guard let url = URL(string: content.url) else {
            throw ParserError.invalidUrl
        }
        
        return (url, content.header)
    }
    
    /// 切换收藏状态
    func toggleCollect() {
        guard let vodInfo = vodInfo else { return }
        
        if isCollected {
            storageManager.removeCollect(vodId: vodInfo.vodId)
        } else {
            storageManager.addCollect(vodInfo: vodInfo)
        }
        isCollected.toggle()
    }
    
    /// 添加到历史记录
    /// - Parameters:
    ///   - sourceIndex: 播放源索引
    ///   - episodeIndex: 剧集索引
    ///   - progress: 播放进度
    func addToHistory(sourceIndex: Int, episodeIndex: Int, progress: Double) {
        guard let vodInfo = vodInfo else { return }
        storageManager.addHistory(
            vodInfo: vodInfo,
            sourceIndex: sourceIndex,
            episodeIndex: episodeIndex,
            progress: progress
        )
    }
    
    private func checkCollected(vodId: String) {
        isCollected = storageManager.isCollected(vodId: vodId)
    }
}

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

