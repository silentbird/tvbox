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
    
    private let apiConfig = ApiConfig.shared
    private let storageManager = StorageManager.shared
    
    func loadDetail(vodId: String) {
        guard let currentSite = apiConfig.currentSite else { return }
        
        isLoading = true
        
        Task {
            do {
                let detail = try await fetchDetail(siteKey: currentSite.key, vodId: vodId)
                await MainActor.run {
                    self.vodInfo = detail
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
    
    private func fetchDetail(siteKey: String, vodId: String) async throws -> VodInfo? {
        // TODO: 实现从 Spider 获取详情的逻辑
        // 这里需要根据不同的站点类型调用不同的接口
        return nil
    }
    
    func toggleCollect() {
        guard let vodInfo = vodInfo else { return }
        
        if isCollected {
            storageManager.removeCollect(vodId: vodInfo.vodId)
        } else {
            storageManager.addCollect(vodInfo: vodInfo)
        }
        isCollected.toggle()
    }
    
    private func checkCollected(vodId: String) {
        isCollected = storageManager.isCollected(vodId: vodId)
    }
}

#Preview {
    NavigationView {
        DetailView(movie: MovieItem(from: try! JSONDecoder().decode(
            MovieItem.self,
            from: """
            {"vod_id": "1", "vod_name": "测试电影", "vod_pic": "", "vod_remarks": "更新至10集"}
            """.data(using: .utf8)!
        )))
    }
}

