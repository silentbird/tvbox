import SwiftUI
import KSPlayer

// KSPlayer 在 macOS 上把 UIView、UIColor 等定义成 AppKit 的别名，只在这个文件里 import，避免影响其他代码。

/// KSPlayer (FFmpeg)，支持 MKV、FLV 等格式，可以选音轨和内嵌字幕
@MainActor
final class KSPlaybackEngine: PlaybackEngine {
    var onEvent: ((PlaybackEvent) -> Void)?

    private var playerLayer: KSPlayerLayer?
    private let subtitle = SubtitleState()
    private var externalSubtitles: [URLSubtitleInfo] = []
    /// 已经选过字幕 (默认的内嵌字幕、外挂字幕或用户手选)，不再自动选内嵌字幕
    private var didSelectSubtitle = false

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
            + externalSubtitles.map { PlaybackTrack(id: $0.subtitleID, name: $0.name) }
    }

    /// KSPlayer 默认启用内嵌字幕里标了默认的那一条，和它保持一致。
    /// 内嵌字幕可能在选了外挂字幕之后才启用，这时以外挂字幕为准
    private var enabledSubtitle: (any KSPlayer.SubtitleInfo)? {
        externalSubtitles.first { $0.isEnabled } ?? subtitleInfos.first { $0.isEnabled }
    }

    var selectedSubtitleID: String? {
        enabledSubtitle?.subtitleID
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
        didSelectSubtitle = true
        for info in subtitleInfos {
            info.isEnabled = info.subtitleID == id
        }
        for info in externalSubtitles {
            info.isEnabled = info.subtitleID == id
        }
        subtitle.parts = []
        refreshSubtitle(at: currentTime)
    }

    func loadSubtitle(url: URL, name: String) async throws -> String {
        let data = url.isFileURL ? try Data(contentsOf: url) : try await URLSession.shared.data(from: url).0
        // 名字为空时 URLSubtitleInfo 会自己再下载一遍
        let info = URLSubtitleInfo(subtitleID: url.absoluteString, name: name.isEmpty ? url.lastPathComponent : name, url: url)
        try info.parse(data: data)
        externalSubtitles.removeAll { $0.subtitleID == info.subtitleID }
        externalSubtitles.append(info)
        return info.subtitleID
    }

    func setSubtitleStyle(_ style: SubtitleStyle) {
        subtitle.style = style
        refreshSubtitle(at: currentTime)
    }

    /// KSPlayer 默认把所有文字字幕轨都启用。和 Android 一样只选一条：优先中文，没有就选第一条
    private func selectDefaultSubtitleIfNeeded() {
        guard !didSelectSubtitle else { return }
        let infos = subtitleInfos
        guard !infos.isEmpty else { return }
        selectSubtitle(id: (infos.first(where: Self.isChinese) ?? infos[0]).subtitleID)
    }

    private static func isChinese(_ info: any KSPlayer.SubtitleInfo) -> Bool {
        let code = ((info as? MediaPlayerTrack)?.languageCode ?? "").lowercased()
        if ["chi", "zho", "chs", "cht"].contains(code) || code.hasPrefix("zh") {
            return true
        }
        let name = info.name.lowercased()
        return ["中", "简", "繁", "國", "国", "chinese", "chs", "cht"].contains { name.contains($0) }
    }

    private func refreshSubtitle(at time: TimeInterval) {
        var parts: [SubtitlePart] = []
        if let info = enabledSubtitle {
            let time = time - subtitle.style.delay
            parts = info.search(for: time)
            // 内嵌字幕查到一次就从队列里取走了，之后查不到时保留还没到结束时间的，和 KSPlayer 的 SubtitleModel 一样
            if parts.isEmpty {
                parts = subtitle.parts.filter { $0 == time }
            }
        }
        if parts != subtitle.parts {
            subtitle.parts = parts
        }
    }

    func stop() {
        playerLayer?.delegate = nil
        playerLayer?.stop()
        playerLayer = nil
        externalSubtitles = []
        subtitle.parts = []
        onEvent = nil
    }
}

extension KSPlaybackEngine: KSPlayerLayerDelegate {
    func player(layer: KSPlayerLayer, state: KSPlayerState) {
        switch state {
        case .readyToPlay:
            subtitle.videoSize = layer.player.naturalSize
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
        // 内嵌字幕轨在 readyToPlay 之后才陆续出来
        selectDefaultSubtitleIfNeeded()
        refreshSubtitle(at: currentTime)
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
    @Published var style = SubtitleStyle(fontSize: 18)
    /// 视频分辨率，用来按画面缩放图形字幕
    @Published var videoSize: CGSize = .zero
}

private struct SubtitleOverlay: View {
    @ObservedObject var state: SubtitleState

    private static let horizontalPadding: CGFloat = 40

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 4) {
                Spacer(minLength: 0)
                ForEach(state.parts) { part in
                    if let image = part.image {
                        let size = imageSize(image.size, in: geometry.size)
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: size.width, height: size.height)
                    } else if let text = part.text?.string {
                        OutlinedText(
                            text: text,
                            fontSize: state.style.fontSize,
                            // 粉色和 Android 的 color_FFB6C1 一样
                            color: state.style.isPink ? Color(red: 1, green: 0.714, blue: 0.757) : .white
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.bottom, geometry.size.height * state.style.bottomFraction)
        }
        .allowsHitTesting(false)
    }

    /// 图形字幕是按视频像素画的，跟着画面缩放，再乘上字号相对默认字号的比例
    private func imageSize(_ size: CGSize, in container: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return .zero }
        let video = state.videoSize
        var zoom: CGFloat = video.width > 0 && video.height > 0 ? min(container.width / video.width, container.height / video.height) : 1
        zoom *= state.style.fontSize / SubtitleStyle.defaultFontSize
        zoom = min(zoom, max(container.width - Self.horizontalPadding * 2, 0) / size.width)
        return CGSize(width: size.width * zoom, height: size.height * zoom)
    }
}

/// 黑色描边的字幕，和 Android 的 SimpleSubtitleView 一样，亮的画面上也看得清
private struct OutlinedText: View {
    let text: String
    let fontSize: CGFloat
    let color: Color

    var body: some View {
        let label = Text(text)
            .font(.system(size: fontSize, weight: .medium))
            .multilineTextAlignment(.center)
        // 往 8 个方向各偏移一份黑字，叠出描边
        let width = max(1, fontSize / 12)
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) * .pi / 4
                label
                    .foregroundColor(.black)
                    .offset(x: cos(angle) * width, y: sin(angle) * width)
            }
            label.foregroundColor(color)
        }
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
