import SwiftUI
import AVFoundation

/// 系统播放器 (AVPlayer)，支持 MP4、HLS 等系统格式
@MainActor
final class AVPlaybackEngine: PlaybackEngine {
    var onEvent: ((PlaybackEvent) -> Void)?

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var notificationObservers: [NSObjectProtocol] = []

    var videoView: AnyView {
        AnyView(PlayerLayerView(player: player))
    }

    var currentTime: Double {
        player.currentTime().seconds
    }

    func load(url: URL, headers: [String: String], format: String?) {
        var options: [String: Any] = [:]
        if !headers.isEmpty {
            options["AVURLAssetHTTPHeaderFieldsKey"] = headers
        }
        // 部分站点的 m3u8 地址没有扩展名，按站点给出的 format 指定类型
        if let format, !format.isEmpty {
            options[AVURLAssetOverrideMIMETypeKey] = format
        }

        let playerItem = AVPlayerItem(asset: AVURLAsset(url: url, options: options))
        player.replaceCurrentItem(with: playerItem)

        // 监听播放状态
        statusObserver = playerItem.observe(\.status) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self?.onEvent?(.ready(duration: item.duration.seconds))
                case .failed:
                    if let error = item.error {
                        self?.onEvent?(.failed(error))
                    }
                default:
                    break
                }
            }
        }

        // 监听播放进度
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let duration = self?.player.currentItem?.duration.seconds,
                      duration.isFinite,
                      duration > 0 else { return }
                self?.onEvent?(.progress(current: time.seconds, duration: duration))
            }
        }

        // 监听缓冲状态
        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onEvent?(.buffering(true))
            }
        })

        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onEvent?(.playedToEnd)
            }
        })
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: max(seconds, 0), preferredTimescale: 600))
    }

    func stop() {
        player.pause()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
        notificationObservers.removeAll()
        statusObserver?.invalidate()
        statusObserver = nil
        player.replaceCurrentItem(with: nil)
        onEvent = nil
    }
}
