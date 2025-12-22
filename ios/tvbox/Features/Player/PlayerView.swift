import SwiftUI
import AVKit

struct PlayerView: View {
    let vodInfo: VodInfo
    let sourceIndex: Int
    let episode: VodInfo.VodPlayItem
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PlayerViewModel()
    @State private var showControls = true
    @State private var hideControlsTask: Task<Void, Never>?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 视频播放器
                Color.black
                    .ignoresSafeArea()
                
                if let player = viewModel.player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showControls.toggle()
                            }
                            scheduleHideControls()
                        }
                } else {
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
            }
        }
        .statusBar(hidden: true)
        .onAppear {
            viewModel.loadVideo(url: episode.url)
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
                Text(vodInfo.vodName)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(episode.name)
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
                Button(action: { /* TODO */ }) {
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
                Button(action: { /* TODO */ }) {
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
class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var isBuffering = false
    @Published var progress: Double = 0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var error: Error?
    
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    
    var currentTimeString: String {
        formatTime(currentTime)
    }
    
    var durationString: String {
        formatTime(duration)
    }
    
    func loadVideo(url: String) {
        // 处理 URL
        var videoUrl = url
        
        // 如果是相对路径或需要解析的 URL，这里需要处理
        guard let url = URL(string: videoUrl) else {
            self.error = NSError(domain: "PlayerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的视频地址"])
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // 监听播放状态
        statusObserver = playerItem.observe(\.status) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self?.duration = item.duration.seconds
                    self?.player?.play()
                    self?.isPlaying = true
                case .failed:
                    self?.error = item.error
                default:
                    break
                }
            }
        }
        
        // 监听播放进度
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self = self, let duration = self.player?.currentItem?.duration.seconds,
                  duration.isFinite && duration > 0 else { return }
            
            self.currentTime = time.seconds
            self.progress = time.seconds / duration
        }
        
        // 监听缓冲状态
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.isBuffering = true
        }
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    func seek(to progress: Double) {
        guard let player = player, duration > 0 else { return }
        let targetTime = CMTime(seconds: progress * duration, preferredTimescale: 600)
        player.seek(to: targetTime)
    }
    
    func seekForward() {
        guard let player = player else { return }
        let targetTime = CMTimeAdd(player.currentTime(), CMTime(seconds: 10, preferredTimescale: 600))
        player.seek(to: targetTime)
    }
    
    func seekBackward() {
        guard let player = player else { return }
        let targetTime = CMTimeSubtract(player.currentTime(), CMTime(seconds: 10, preferredTimescale: 600))
        player.seek(to: targetTime)
    }
    
    func cleanup() {
        player?.pause()
        
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        
        statusObserver?.invalidate()
        player = nil
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

