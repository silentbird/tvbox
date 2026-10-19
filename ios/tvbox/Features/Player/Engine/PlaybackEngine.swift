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

/// 音轨、字幕轨
struct PlaybackTrack: Identifiable, Equatable {
    let id: String
    let name: String
}

/// 画面比例，取值和 Android 的 VideoView.SCREEN_SCALE_* 一致 (不含「原始」)
enum VideoScale: Int, CaseIterable, Identifiable {
    case `default` = 0
    case ratio16x9 = 1
    case ratio4x3 = 2
    case fill = 3
    case crop = 5

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .default: return "默认"
        case .ratio16x9: return "16:9"
        case .ratio4x3: return "4:3"
        case .fill: return "填充"
        case .crop: return "裁剪"
        }
    }

    /// 画面拉伸到的固定宽高比，nil 表示用整个播放区域
    var aspectRatio: CGFloat? {
        switch self {
        case .ratio16x9: return 16.0 / 9.0
        case .ratio4x3: return 4.0 / 3.0
        default: return nil
        }
    }
}

/// 播放内核。播放页只通过它控制播放，新增播放器时实现这个协议并加到 PlayerKind。
@MainActor
protocol PlaybackEngine: AnyObject {
    var onEvent: ((PlaybackEvent) -> Void)? { get set }
    /// 显示画面和字幕的视图，不带控制条
    var videoView: AnyView { get }
    var currentTime: Double { get }
    /// 视频分辨率，未知时为 .zero
    var naturalSize: CGSize { get }
    /// 已下载的字节数，用来算网速；内核不支持时为 nil
    var bytesRead: Int64? { get }
    /// 播放器音量 0...1，不是系统音量
    var volume: Float { get set }

    var audioTracks: [PlaybackTrack] { get }
    var selectedAudioTrackID: String? { get }
    var subtitleTracks: [PlaybackTrack] { get }
    /// nil 表示不显示字幕
    var selectedSubtitleID: String? { get }

    func load(url: URL, headers: [String: String], format: String?)
    func play()
    func pause()
    func seek(to seconds: Double)
    func setRate(_ rate: Float)
    /// 画面填充方式，固定宽高比由播放页的布局负责
    func setScale(_ scale: VideoScale)
    func selectAudioTrack(id: String)
    func selectSubtitle(id: String?)
    func stop()
}

/// 设置里可选的播放器，对应 Android 的 PLAY_TYPE
enum PlayerKind: Int, CaseIterable, Identifiable {
    // 0 以前是系统播放器 (AVPlayer)，1 是和它重复的 "AVPlayer" 选项，都已去掉
    case ksPlayer = 2

    private static let storageKey = "player_type"

    /// 设置里选中的播放器，旧值或无效值按 KSPlayer 处理
    static var selected: PlayerKind {
        get { PlayerKind(rawValue: UserDefaults.standard.integer(forKey: storageKey)) ?? .ksPlayer }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: storageKey) }
    }

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .ksPlayer: return "KSPlayer"
        }
    }

    @MainActor
    func makeEngine() -> PlaybackEngine {
        switch self {
        case .ksPlayer: return KSPlaybackEngine()
        }
    }
}
