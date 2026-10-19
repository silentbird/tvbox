import SwiftUI

/// 播放内核发出的事件
enum PlaybackEvent {
    /// 可以播放了，带总时长 (秒)
    case ready(duration: Double)
    /// 播放进度 (秒)
    case progress(current: Double, duration: Double)
    case buffering(Bool)
    case playedToEnd
    case failed(Error)
}

/// 播放内核。播放页只通过它控制播放，新增播放器时实现这个协议并加到 PlayerKind。
@MainActor
protocol PlaybackEngine: AnyObject {
    var onEvent: ((PlaybackEvent) -> Void)? { get set }
    /// 显示画面的视图，不带控制条
    var videoView: AnyView { get }
    var currentTime: Double { get }

    func load(url: URL, headers: [String: String], format: String?)
    func play()
    func pause()
    func seek(to seconds: Double)
    func stop()
}

/// 设置里可选的播放器，对应 Android 的 PLAY_TYPE
enum PlayerKind: Int, CaseIterable, Identifiable {
    case system = 0
    // 1 以前是和系统播放器重复的 "AVPlayer" 选项，不再使用
    case ksPlayer = 2

    private static let storageKey = "player_type"

    /// 设置里选中的播放器，旧值或无效值按系统播放器处理
    static var selected: PlayerKind {
        get { PlayerKind(rawValue: UserDefaults.standard.integer(forKey: storageKey)) ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: storageKey) }
    }

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .system: return "系统播放器"
        case .ksPlayer: return "KSPlayer"
        }
    }

    /// 系统播放器播放失败时自动改用的播放器，对应 Android 的自动切换播放器
    var fallback: PlayerKind? {
        self == .system ? .ksPlayer : nil
    }

    @MainActor
    func makeEngine() -> PlaybackEngine {
        switch self {
        case .system: return AVPlaybackEngine()
        case .ksPlayer: return KSPlaybackEngine()
        }
    }
}
