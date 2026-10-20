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

/// 字幕的字号、颜色、延时，所有视频共用，对应 Android 的 SubtitleHelper
struct SubtitleStyle: Codable, Equatable {
    /// 和 Android 一样 12...60，每次加减 2
    var fontSize: CGFloat
    /// 对应 Android 的「字幕样式二」(粉色)，默认白色
    var isPink = false
    /// 延时 (秒)，正数表示字幕推后显示，每次加减 0.5
    var delay: Double = 0
    /// 上移的距离，占画面高度的百分比，负数是下移，对应 Android 的「字幕上移/下移」
    var position: Double = 0

    static let fontSizeRange: ClosedRange<CGFloat> = 12...60
    /// 下移到贴底为止
    static let positionRange: ClosedRange<Double> = -defaultBottomPercent...80
    /// 字幕默认离底部的距离占画面高度的百分比，和 Android 的 Exo 字幕一样
    private static let defaultBottomPercent: Double = 8
    private static let storageKey = "subtitle_style"

    /// 默认字号和 Android 一样按屏幕大小来
    @MainActor
    static var defaultFontSize: CGFloat {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        return UIDevice.current.userInterfaceIdiom == .phone ? 18 : 24
        #else
        return 24
        #endif
    }

    /// 字幕底部离画面底部的距离占画面高度的比例
    var bottomFraction: CGFloat {
        CGFloat(Self.defaultBottomPercent + position) / 100
    }

    @MainActor
    static func load() -> SubtitleStyle {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let style = try? JSONDecoder().decode(SubtitleStyle.self, from: data) {
            return style
        }
        return SubtitleStyle(fontSize: defaultFontSize)
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
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
    /// 下载并解析外挂字幕 (SRT/ASS/VTT)，加到字幕列表里但不选中，返回字幕 id
    func loadSubtitle(url: URL, name: String) async throws -> String
    func setSubtitleStyle(_ style: SubtitleStyle)
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
