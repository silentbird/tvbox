import SwiftUI

/// 剧集的真实播放地址
typealias PlayAddress = (url: URL, headers: [String: String]?, format: String?)

/// 向站点获取剧集的真实播放地址，需要解析时一并解析。详情页和观看历史共用
@MainActor
func resolvePlayAddress(site: SiteBean, flag: String, episode: VodInfo.VodPlayItem) async throws -> PlayAddress {
    // 1. 获取播放内容
    var content = try await SpiderManager.shared.playerContent(site: site, flag: flag, id: episode.url)

    // jx=1 时和 Android 一样改用默认解析
    if content.jxFrom == "1" {
        content.parse = 1
        content.playUrl = nil
    }

    // 2. 如果需要解析
    if content.needParse {
        content = try await ParserManager.shared.parse(content: content)
    }

    // 3. 返回 URL
    guard let url = URL(string: content.url) else {
        throw ParserError.invalidUrl
    }

    return (url, content.header, content.format)
}

struct PlayerView: View {
    let title: String
    /// 当前播放源的剧集
    let episodes: [VodInfo.VodPlayItem]
    /// 开始播放的剧集
    let episodeIndex: Int
    /// 开始播放的位置 (秒)，用于续播
    let startPosition: Double
    /// 向站点获取剧集的真实播放地址（需要解析时一并解析）
    let resolvePlayUrl: (VodInfo.VodPlayItem) async throws -> PlayAddress
    /// 播放进度回调 (剧集索引, 位置, 总时长)，用于记录播放历史
    let onProgress: @MainActor (Int, Double, Double) -> Void
    
    @Environment(\.tvboxDismissCover) private var dismiss
    @StateObject private var viewModel = PlayerViewModel()
    @State private var showControls = true
    @State private var hideControlsTask: Task<Void, Never>?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 视频播放器
                Color.black
                    .ignoresSafeArea()
                
                if let engine = viewModel.engine {
                    engine.videoView
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showControls.toggle()
                            }
                            scheduleHideControls()
                        }
                } else if viewModel.error == nil {
                    ProgressView()
                        .scaleEffect(2)
                        .tint(.white)
                }
                
                // 控制层
                if showControls {
                    controlsOverlay(geometry: geometry)
                }
                
                // 加载指示器
                if viewModel.isBuffering {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
                
                if let error = viewModel.error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                        Text("播放失败")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(AppErrorMessage.userMessage(for: error))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.black.opacity(0.55))
                    .cornerRadius(8)
                    .padding()
                }
            }
        }
        .tvboxStatusBar(hidden: true)
        .toast(message: viewModel.toastMessage, isShowing: $viewModel.showToast)
        .onAppear {
            viewModel.start(
                episodes: episodes,
                episodeIndex: episodeIndex,
                startPosition: startPosition,
                resolve: resolvePlayUrl,
                onProgress: onProgress
            )
            scheduleHideControls()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
    
    // MARK: - Controls Overlay
    private func controlsOverlay(geometry: GeometryProxy) -> some View {
        ZStack {
            // 背景渐变
            VStack {
                LinearGradient(
                    colors: [.black.opacity(0.7), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)
                
                Spacer()
                
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
            }
            .ignoresSafeArea()
            
            VStack {
                // 顶部栏
                topBar
                
                Spacer()
                
                // 底部控制栏
                bottomBar
            }
            .padding()
        }
        .transition(.opacity)
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.2)))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(viewModel.currentEpisode?.name ?? "")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            // 更多选项
            Menu {
                Button(action: {}) {
                    Label("画质", systemImage: "slider.horizontal.3")
                }
                Button(action: {}) {
                    Label("倍速", systemImage: "speedometer")
                }
                Button(action: {}) {
                    Label("字幕", systemImage: "captions.bubble")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.2)))
            }
        }
    }
    
    // MARK: - Bottom Bar
    private var bottomBar: some View {
        VStack(spacing: 12) {
            // 进度条
            HStack(spacing: 12) {
                Text(viewModel.currentTimeString)
                    .font(.caption)
                    .foregroundColor(.white)
                    .monospacedDigit()
                
                Slider(
                    value: Binding(
                        get: { viewModel.progress },
                        set: { viewModel.seek(to: $0) }
                    ),
                    in: 0...1
                )
                .tint(.white)
                
                Text(viewModel.durationString)
                    .font(.caption)
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            
            // 控制按钮
            HStack(spacing: 40) {
                // 上一集
                Button(action: { viewModel.playPrevious() }) {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                // 快退
                Button(action: { viewModel.seekBackward() }) {
                    Image(systemName: "gobackward.10")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                // 播放/暂停
                Button(action: { viewModel.togglePlayPause() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Color.white.opacity(0.2)))
                }
                
                // 快进
                Button(action: { viewModel.seekForward() }) {
                    Image(systemName: "goforward.10")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                // 下一集
                Button(action: { viewModel.playNext() }) {
                    Image(systemName: "forward.end.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showControls = false
                    }
                }
            }
        }
    }
}

// MARK: - Player ViewModel
@MainActor
class PlayerViewModel: ObservableObject {
    /// 当前使用的播放内核
    @Published private(set) var engine: PlaybackEngine?
    @Published var isPlaying = false
    @Published var isBuffering = false
    @Published var progress: Double = 0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var error: Error?
    
    @Published private(set) var episodeIndex = 0
    @Published var showToast = false
    @Published private(set) var toastMessage = ""
    
    private var resolveTask: Task<Void, Never>?
    
    private var episodes: [VodInfo.VodPlayItem] = []
    private var resolve: ((VodInfo.VodPlayItem) async throws -> PlayAddress)?
    private var onProgress: (@MainActor (Int, Double, Double) -> Void)?
    /// 当前剧集的播放地址，切换播放器时重新加载
    private var address: PlayAddress?
    /// 当前剧集使用的播放器，播放失败时可能自动切换
    private var playerKind = PlayerKind.selected
    /// 播放内核已就绪，可以上报进度
    private var isReady = false
    /// 准备好后需要跳转到的位置 (续播)
    private var pendingSeekPosition: Double = 0
    private var lastReportedTime: TimeInterval = 0
    /// 当前剧集已播完，进度按 0 记录 (和 Android 一样播完清除进度)
    private var didPlayToEnd = false
    /// 播放进度上报间隔 (秒)
    private static let progressReportInterval: TimeInterval = 5
    
    var currentTimeString: String {
        formatTime(currentTime)
    }
    
    var durationString: String {
        formatTime(duration)
    }
    
    var currentEpisode: VodInfo.VodPlayItem? {
        episodes.indices.contains(episodeIndex) ? episodes[episodeIndex] : nil
    }
    
    private var hasPrevious: Bool { episodeIndex > 0 }
    private var hasNext: Bool { episodeIndex + 1 < episodes.count }
    
    func start(
        episodes: [VodInfo.VodPlayItem],
        episodeIndex: Int,
        startPosition: Double,
        resolve: @escaping (VodInfo.VodPlayItem) async throws -> PlayAddress,
        onProgress: @escaping @MainActor (Int, Double, Double) -> Void
    ) {
        self.episodes = episodes
        self.resolve = resolve
        self.onProgress = onProgress
        play(episodeIndex: episodeIndex, startPosition: startPosition)
    }
    
    func playPrevious() {
        guard hasPrevious else {
            showToast(message: "已经是第一集了!")
            return
        }
        play(episodeIndex: episodeIndex - 1)
    }
    
    func playNext() {
        guard hasNext else {
            showToast(message: "已经是最后一集了!")
            return
        }
        play(episodeIndex: episodeIndex + 1)
    }
    
    private func showToast(message: String) {
        toastMessage = message
        showToast = true
    }
    
    /// 先取得真实播放地址再开始播放
    private func play(episodeIndex: Int, startPosition: Double = 0) {
        reportProgress()
        resolveTask?.cancel()
        tearDownEngine()
        
        self.episodeIndex = episodeIndex
        didPlayToEnd = false
        pendingSeekPosition = startPosition
        playerKind = PlayerKind.selected
        address = nil
        error = nil
        currentTime = 0
        duration = 0
        progress = 0
        
        guard let episode = currentEpisode, let resolve else { return }
        resolveTask = Task {
            do {
                let address = try await resolve(episode)
                // 取地址期间已关闭播放器或切换了剧集
                guard !Task.isCancelled else { return }
                self.address = address
                loadEngine()
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error
            }
        }
    }
    
    /// 用当前选择的播放器加载当前剧集
    private func loadEngine() {
        guard let address else { return }
        tearDownEngine()
        error = nil
        
        let engine = playerKind.makeEngine()
        engine.onEvent = { [weak self] event in
            self?.handle(event)
        }
        engine.load(url: address.url, headers: address.headers ?? [:], format: address.format)
        self.engine = engine
    }
    
    private func handle(_ event: PlaybackEvent) {
        switch event {
        case .ready(let duration):
            isReady = true
            self.duration = duration
            if pendingSeekPosition > 0 {
                let position = pendingSeekPosition
                pendingSeekPosition = 0
                currentTime = position
                engine?.seek(to: position)
            }
            engine?.play()
            isPlaying = true
            // 开始播放就记一条历史
            reportProgress()
        case .progress(let current, let duration):
            currentTime = current
            self.duration = duration
            progress = current / duration
            if abs(current - lastReportedTime) >= Self.progressReportInterval {
                reportProgress()
            }
        case .buffering(let buffering):
            isBuffering = buffering
        case .playedToEnd:
            // 播完清除该集进度并自动播下一集
            didPlayToEnd = true
            reportProgress()
            playNext()
        case .failed(let error):
            // 还没开始播放就失败，多半是格式不支持，换备用播放器再试一次
            if !isReady, let fallback = playerKind.fallback {
                AppLogger.debug("[Player] \(playerKind.name) 播放失败，改用 \(fallback.name): \(error)")
                playerKind = fallback
                showToast(message: "已切换到 \(fallback.name) 播放")
                loadEngine()
            } else {
                self.error = error
            }
        }
    }
    
    /// 上报当前剧集的播放进度，用于记录播放历史
    private func reportProgress() {
        // 还没开始播放时不上报，避免续播位置被 0 覆盖
        guard isReady, currentEpisode != nil else { return }
        lastReportedTime = currentTime
        onProgress?(episodeIndex, didPlayToEnd ? 0 : currentTime, duration.isFinite ? duration : 0)
    }
    
    private func tearDownEngine() {
        engine?.stop()
        engine = nil
        isReady = false
        isPlaying = false
        isBuffering = false
    }
    
    func togglePlayPause() {
        guard let engine else { return }
        
        if isPlaying {
            engine.pause()
        } else {
            engine.play()
        }
        isPlaying.toggle()
    }
    
    func seek(to progress: Double) {
        guard let engine, duration > 0 else { return }
        engine.seek(to: progress * duration)
    }
    
    func seekForward() {
        guard let engine else { return }
        engine.seek(to: engine.currentTime + 10)
    }
    
    func seekBackward() {
        guard let engine else { return }
        engine.seek(to: engine.currentTime - 10)
    }
    
    func cleanup() {
        reportProgress()
        resolveTask?.cancel()
        tearDownEngine()
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && time >= 0 else { return "00:00" }
        
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
