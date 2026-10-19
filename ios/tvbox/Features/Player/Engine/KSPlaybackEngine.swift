import SwiftUI
import KSPlayer

// KSPlayer 在 macOS 上把 UIView、UIColor 等定义成 AppKit 的别名，只在这个文件里 import，避免影响其他代码。

/// KSPlayer (FFmpeg)，支持 MKV、FLV 等系统播放器不支持的格式
@MainActor
final class KSPlaybackEngine: PlaybackEngine {
    var onEvent: ((PlaybackEvent) -> Void)?

    private var playerLayer: KSPlayerLayer?

    init() {
        // 用到 KSPlayer 时一般是系统播放器播不了，直接用 FFmpeg 内核，不再先试 AVPlayer
        KSOptions.firstPlayerType = KSMEPlayer.self
        KSOptions.secondPlayerType = nil
    }

    var videoView: AnyView {
        guard let playerLayer else { return AnyView(Color.black) }
        return AnyView(KSPlayerContainer(playerLayer: playerLayer))
    }

    var currentTime: Double {
        playerLayer?.player.currentPlaybackTime ?? 0
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

    func stop() {
        playerLayer?.delegate = nil
        playerLayer?.stop()
        playerLayer = nil
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
