import SwiftUI
import KSPlayer

// KSPlayer 在 macOS 上把 UIView、UIColor 等定义成 AppKit 的别名，只在这个文件里 import，避免影响其他代码。

/// KSPlayer (FFmpeg)，支持 MKV、FLV 等格式，可以选音轨和内嵌字幕
@MainActor
final class KSPlaybackEngine: PlaybackEngine {
    var onEvent: ((PlaybackEvent) -> Void)?

    private var playerLayer: KSPlayerLayer?
    private let subtitle = SubtitleState()

    init() {
        // 直接用 FFmpeg 内核，不先试 AVPlayer
        KSOptions.firstPlayerType = KSMEPlayer.self
        KSOptions.secondPlayerType = nil
    }

    var videoView: AnyView {
        guard let playerLayer else { return AnyView(Color.black) }
        return AnyView(
            KSPlayerContainer(playerLayer: playerLayer)
                .overlay { SubtitleOverlay(state: subtitle) }
        )
    }

    var currentTime: Double {
        playerLayer?.player.currentPlaybackTime ?? 0
    }

    var naturalSize: CGSize {
        playerLayer?.player.naturalSize ?? .zero
    }

    var bytesRead: Int64? {
        playerLayer?.player.dynamicInfo?.bytesRead
    }

    var volume: Float {
        get { playerLayer?.player.playbackVolume ?? 1 }
        set { playerLayer?.player.playbackVolume = min(max(newValue, 0), 1) }
    }

    var audioTracks: [PlaybackTrack] {
        (playerLayer?.player.tracks(mediaType: .audio) ?? []).map(\.playbackTrack)
    }

    var selectedAudioTrackID: String? {
        playerLayer?.player.tracks(mediaType: .audio).first { $0.isEnabled }?.playbackTrack.id
    }

    /// 内嵌字幕在 readyToPlay 之后才陆续解析出来，每次都现取
    private var subtitleInfos: [any KSPlayer.SubtitleInfo] {
        playerLayer?.player.subtitleDataSouce?.infos ?? []
    }

    var subtitleTracks: [PlaybackTrack] {
        subtitleInfos.map { PlaybackTrack(id: $0.subtitleID, name: $0.name) }
    }

    /// KSPlayer 默认启用内嵌字幕里标了默认的那一条，和它保持一致
    var selectedSubtitleID: String? {
        subtitleInfos.first { $0.isEnabled }?.subtitleID
    }

    /// FFmpeg 会自己探测格式，不需要 format
    func load(url: URL, headers: [String: String], format _: String?) {
        let options = KSOptions()
        if !headers.isEmpty {
            options.appendHeader(headers)
        }
        // 不设置的话 FFmpeg 会用默认的 "KSPlayer" 作为 User-Agent
        if let userAgent = headers.first(where: { $0.key.caseInsensitiveCompare("User-Agent") == .orderedSame })?.value {
            options.userAgent = userAgent
        }
        playerLayer = KSPlayerLayer(url: url, options: options, delegate: self)
    }

    func play() {
        playerLayer?.play()
    }

    func pause() {
        playerLayer?.pause()
    }

    func seek(to seconds: Double) {
        guard let playerLayer else { return }
        playerLayer.seek(time: max(seconds, 0), autoPlay: playerLayer.state.isPlaying) { _ in }
    }

    func setRate(_ rate: Float) {
        playerLayer?.player.playbackRate = rate
    }

    func setScale(_ scale: VideoScale) {
        switch scale {
        case .default: playerLayer?.player.contentMode = .scaleAspectFit
        case .crop: playerLayer?.player.contentMode = .scaleAspectFill
        case .ratio16x9, .ratio4x3, .fill: playerLayer?.player.contentMode = .scaleToFill
        }
    }

    func selectAudioTrack(id: String) {
        guard let player = playerLayer?.player,
              let track = player.tracks(mediaType: .audio).first(where: { $0.playbackTrack.id == id }) else { return }
        player.select(track: track)
    }

    func selectSubtitle(id: String?) {
        for info in subtitleInfos {
            info.isEnabled = info.subtitleID == id
        }
        subtitle.parts = []
    }

    func stop() {
        playerLayer?.delegate = nil
        playerLayer?.stop()
        playerLayer = nil
        subtitle.parts = []
        onEvent = nil
    }
}

extension KSPlaybackEngine: KSPlayerLayerDelegate {
    func player(layer: KSPlayerLayer, state: KSPlayerState) {
        switch state {
        case .readyToPlay:
            onEvent?(.ready(duration: layer.player.duration))
        case .buffering:
            onEvent?(.buffering(true))
        case .bufferFinished:
            onEvent?(.buffering(false))
        default:
            break
        }
    }

    func player(layer _: KSPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        let parts = subtitleInfos.first { $0.isEnabled }?.search(for: currentTime) ?? []
        if parts != subtitle.parts {
            subtitle.parts = parts
        }
        guard totalTime > 0 else { return }
        onEvent?(.progress(current: currentTime, duration: totalTime))
    }

    func player(layer _: KSPlayerLayer, finish error: Error?) {
        if let error {
            onEvent?(.failed(error))
        } else {
            onEvent?(.playedToEnd)
        }
    }

    func player(layer _: KSPlayerLayer, bufferedCount _: Int, consumeTime _: TimeInterval) {}
}

private extension MediaPlayerTrack {
    var playbackTrack: PlaybackTrack {
        let language = languageCode.flatMap { Locale.current.localizedString(forLanguageCode: $0) }
        let title = [name, language].compactMap { $0 }.filter { !$0.isEmpty }
        return PlaybackTrack(id: String(trackID), name: title.isEmpty ? "音轨 \(trackID)" : title.joined(separator: " · "))
    }
}

/// 当前要显示的字幕
@MainActor
private final class SubtitleState: ObservableObject {
    @Published var parts: [SubtitlePart] = []
}

private struct SubtitleOverlay: View {
    @ObservedObject var state: SubtitleState

    var body: some View {
        VStack(spacing: 4) {
            Spacer()
            ForEach(state.parts) { part in
                if let image = part.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 160)
                } else if let text = part.text?.string {
                    Text(text)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.9), radius: 1, x: 1, y: 1)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 24)
        .allowsHitTesting(false)
    }
}

/// 承载 KSPlayer 画面的容器。KSPlayer 切换内核时会把新画面插到旧画面的父视图里，所以要有一层容器。
#if os(macOS) && !targetEnvironment(macCatalyst)
private struct KSPlayerContainer: NSViewRepresentable {
    let playerLayer: KSPlayerLayer

    func makeNSView(context _: Context) -> NSView {
        let container = NSView()
        if let playerView = playerLayer.player.view {
            container.addSubview(playerView)
            pin(playerView, to: container)
        }
        return container
    }

    func updateNSView(_: NSView, context _: Context) {}
}
#else
private struct KSPlayerContainer: UIViewRepresentable {
    let playerLayer: KSPlayerLayer

    func makeUIView(context _: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        if let playerView = playerLayer.player.view {
            container.addSubview(playerView)
            pin(playerView, to: container)
        }
        return container
    }

    func updateUIView(_: UIView, context _: Context) {}
}
#endif

private func pin(_ view: UIView, to container: UIView) {
    view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        view.topAnchor.constraint(equalTo: container.topAnchor),
        view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
    ])
}
