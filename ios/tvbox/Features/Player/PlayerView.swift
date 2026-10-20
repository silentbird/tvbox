import SwiftUI
import UniformTypeIdentifiers

/// 剧集的真实播放地址
typealias PlayAddress = (url: URL, headers: [String: String]?, format: String?, subtitles: [SubtitleInfo])

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

    // 2. 如果需要解析。解析结果里没有字幕，用站点给的
    let subtitles = content.subs ?? []
    if content.needParse {
        content = try await ParserManager.shared.parse(content: content)
    }

    // 3. 返回 URL
    guard let url = URL(string: content.url) else {
        throw ParserError.invalidUrl
    }

    return (url, content.header, content.format, subtitles)
}

struct PlayerView: View {
    let title: String
    /// 可切换的线路
    let sources: [PlaySource]
    /// 开始播放的线路
    let sourceIndex: Int
    /// 开始播放的剧集
    let episodeIndex: Int
    /// 开始播放的位置 (秒)，用于续播
    let startPosition: Double
    /// 按剧保存播放设置用的 key，由站点和视频组成
    let configKey: String
    /// 向站点获取剧集的真实播放地址（需要解析时一并解析），参数是线路名和剧集
    let resolvePlayUrl: (String, VodInfo.VodPlayItem) async throws -> PlayAddress
    /// 播放进度回调 (线路索引, 剧集索引, 位置, 总时长)，用于记录播放历史
    let onProgress: @MainActor (Int, Int, Double, Double) -> Void

    @Environment(\.tvboxDismissCover) private var dismiss
    @StateObject private var viewModel = PlayerViewModel()
    @State private var showControls = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var panel: PlayerPanel?
    @State private var isLocked = false
    /// 拖动进度条或横滑时要跳到的位置 (秒)
    @State private var seekPreview: Double?
    @State private var panStartTime: Double = 0
    /// 竖滑时显示的亮度或音量
    @State private var level: (isVolume: Bool, value: Double)?
    /// 双击快退快进的提示
    @State private var skipFeedback: PlayerTapZone?
    @State private var isImportingSubtitle = false
    @FocusState private var isFocused: Bool
    #if os(macOS)
    /// 控制条上弹出的倍速、字幕音轨菜单
    @State private var macMenu: MacPlayerMenu?
    /// 鼠标停在控制条上时不自动隐藏
    @State private var isHoveringControls = false
    /// 鼠标悬停在进度条上的位置 (0...1)
    @State private var hoverFraction: Double?
    /// 单击画面播放/暂停后中间闪一下的图标，true 表示开始播放
    @State private var playFeedback: Bool?
    @State private var isFullScreen = false
    #endif

    /// 横滑一个屏幕宽度调整的时长 (秒)，和 Android 一样
    private static let panSeekRange: Double = 120
    private static let skipSeconds: Double = 10
    /// 本地字幕能选的文件，KSPlayer 能解析这几种
    private static let subtitleFileTypes: [UTType] = ["srt", "ass", "ssa", "vtt"].compactMap { UTType(filenameExtension: $0) } + [.plainText]
    #if os(macOS)
    private static let hideControlsDelay: UInt64 = 3_000_000_000
    #else
    private static let hideControlsDelay: UInt64 = 5_000_000_000
    #endif

    /// 锁屏只在触屏设备上有意义
    private static let supportsLock: Bool = {
        #if os(iOS)
        return !ProcessInfo.processInfo.isMacCatalystApp && !ProcessInfo.processInfo.isiOSAppOnMac
        #else
        return false
        #endif
    }()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                videoLayer
                    .ignoresSafeArea()

                PlayerGestureLayer(
                    isLocked: isLocked,
                    onTap: handleTap,
                    onDoubleTap: handleDoubleTap,
                    onLongPress: { viewModel.setBoosting($0) },
                    onPan: handlePan
                )
                .ignoresSafeArea()

                if viewModel.error == nil, viewModel.engine == nil || viewModel.isBuffering {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                        .allowsHitTesting(false)
                }

                feedbackLayer

                if showControls, !isLocked, panel == nil {
                    controlsOverlay
                }

                if Self.supportsLock, showControls, panel == nil, viewModel.error == nil {
                    lockButton
                }

                if let countdown = viewModel.upNextCountdown, panel == nil {
                    upNextCard(countdown: countdown)
                }

                if let error = viewModel.error, panel == nil {
                    errorOverlay(error)
                }

                if let panel {
                    // 遮罩原地淡入，只有面板从右侧滑入
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture(perform: closePanel)
                        .transition(.opacity)
                    panelView(panel, width: min(360, geometry.size.width * 0.85))
                        .transition(.move(edge: .trailing))
                }
            }
        }
        #if os(macOS)
        // 鼠标移动时显示控制层，静止一会儿后隐藏
        .onContinuousHover { phase in
            guard case .active = phase, panel == nil else { return }
            if !showControls {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showControls = true
                }
            }
            scheduleHideControls()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            isFullScreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            isFullScreen = false
        }
        #endif
        .tvboxStatusBar(hidden: true)
        .toast(message: viewModel.toastMessage, isShowing: $viewModel.showToast)
        .fileImporter(isPresented: $isImportingSubtitle, allowedContentTypes: Self.subtitleFileTypes) { result in
            if case .success(let url) = result {
                viewModel.openSubtitleFile(url)
            }
        }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(action: handleKeyPress)
        .onAppear {
            viewModel.start(
                sources: sources,
                sourceIndex: sourceIndex,
                episodeIndex: episodeIndex,
                startPosition: startPosition,
                configKey: configKey,
                resolve: resolvePlayUrl,
                onProgress: onProgress
            )
            isFocused = true
            #if os(macOS)
            isFullScreen = NSApp.keyWindow?.styleMask.contains(.fullScreen) ?? false
            #endif
            scheduleHideControls()
        }
        .onDisappear {
            hideControlsTask?.cancel()
            viewModel.cleanup()
        }
    }

    // MARK: - 画面

    @ViewBuilder
    private var videoLayer: some View {
        if let engine = viewModel.engine {
            if let ratio = viewModel.scale.aspectRatio {
                engine.videoView
                    .aspectRatio(ratio, contentMode: .fit)
            } else {
                engine.videoView
            }
        }
    }

    // MARK: - 控制层

    private var controlsOverlay: some View {
        ZStack {
            VStack {
                LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 110)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 140)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                Spacer()
                #if os(macOS)
                macBottomBar
                #else
                bottomBar
                #endif
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Mac 上单击画面就是播放/暂停，不需要中间的大按钮
            #if !os(macOS)
            centerControls
            #endif
        }
        .transition(.opacity)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            iconButton("chevron.left", size: 20) { dismiss() }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Text([viewModel.currentEpisode?.name, viewModel.currentFlag].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .foregroundColor(.white)

            Spacer(minLength: 8)

            statusInfo

            // Mac 的播放设置在底部控制条的齿轮里
            #if !os(macOS)
            iconButton("ellipsis", size: 20) { openPanel(.settings) }
            #endif
        }
        #if os(macOS)
        // 窗口左上角的红绿灯盖在画面上，全屏时才没有
        .padding(.leading, isFullScreen ? 0 : 64)
        .onHover { isHoveringControls = $0 }
        #endif
    }

    /// 分辨率、网速、时间，对应 Android 右上角的屏显
    private var statusInfo: some View {
        HStack(spacing: 10) {
            if let resolution = resolutionLabel {
                Text(resolution)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.4)))
            }
            if let speed = viewModel.networkSpeed {
                Text(speedLabel(speed))
            }
            TimelineView(.everyMinute) { context in
                Text(context.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
            }
        }
        .font(.caption)
        .monospacedDigit()
        .foregroundColor(.white.opacity(0.75))
    }

    private var centerControls: some View {
        HStack(spacing: 56) {
            iconButton("gobackward.10", size: 28) { viewModel.skip(by: -Self.skipSeconds) }
            Button(action: viewModel.togglePlayPause) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .frame(width: 68, height: 68)
                    .background(Circle().fill(Color.black.opacity(0.35)))
            }
            .buttonStyle(.plain)
            iconButton("goforward.10", size: 28) { viewModel.skip(by: Self.skipSeconds) }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 2) {
            progressBar

            HStack(spacing: 6) {
                iconButton(viewModel.isPlaying ? "pause.fill" : "play.fill", size: 20, action: viewModel.togglePlayPause)
                iconButton("forward.end.fill", size: 18, action: viewModel.playNext)

                HStack(spacing: 0) {
                    Text(PlayerViewModel.formatTime(seekPreview ?? viewModel.currentTime))
                        .foregroundColor(.white)
                    Text(" / " + PlayerViewModel.formatTime(viewModel.duration))
                        .foregroundColor(.white.opacity(0.7))
                }
                .font(.footnote)
                .monospacedDigit()
                .padding(.leading, 4)

                Spacer()

                let speedChanged = viewModel.config.speed != 1
                textButton(speedChanged ? formatSpeed(viewModel.config.speed) : "倍速", highlighted: speedChanged) {
                    openPanel(.speed)
                }
                if !viewModel.episodes.isEmpty {
                    textButton("选集") { openPanel(.episodes) }
                }
            }
        }
    }

    /// 进度条，标出片头片尾的位置
    private var progressBar: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let duration = viewModel.duration
            let fraction = duration > 0 ? min(max((seekPreview ?? viewModel.currentTime) / duration, 0), 1) : 0
            #if os(macOS)
            // 鼠标悬停时进度条变粗、显示圆点
            let isActive = hoverFraction != nil || seekPreview != nil
            let trackHeight: CGFloat = isActive ? 6 : 4
            #else
            let isActive = true
            let trackHeight: CGFloat = 4
            #endif

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: trackHeight)
                Capsule()
                    .fill(Color.orange)
                    .frame(width: width * fraction, height: trackHeight)
                ForEach(skipMarkers, id: \.self) { marker in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.yellow)
                        .frame(width: 2, height: 10)
                        .offset(x: width * marker - 1)
                }
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .shadow(color: .black.opacity(0.4), radius: 2)
                    .scaleEffect(isActive ? 1 : 0.01)
                    .offset(x: width * fraction - 7)
            }
            .frame(maxHeight: .infinity)
            .animation(.easeOut(duration: 0.12), value: isActive)
            #if os(macOS)
            .overlay(alignment: .topLeading) {
                if let hoverFraction, duration > 0, seekPreview == nil {
                    hoverTimeTip(fraction: hoverFraction, duration: duration)
                        .position(x: min(max(width * hoverFraction, 36), width - 36), y: -10)
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoverFraction = width > 0 ? min(max(location.x / width, 0), 1) : nil
                case .ended:
                    hoverFraction = nil
                }
            }
            #endif
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard duration > 0, width > 0 else { return }
                        hideControlsTask?.cancel()
                        seekPreview = min(max(value.location.x / width, 0), 1) * duration
                    }
                    .onEnded { _ in
                        if let seekPreview {
                            viewModel.seek(to: seekPreview)
                        }
                        seekPreview = nil
                        scheduleHideControls()
                    }
            )
        }
        .frame(height: 26)
    }

    private var skipMarkers: [Double] {
        let duration = viewModel.duration
        guard duration > 0 else { return [] }
        var markers: [Double] = []
        if viewModel.config.openingTime > 0, viewModel.config.openingTime < duration {
            markers.append(viewModel.config.openingTime / duration)
        }
        if viewModel.config.endingTime > 0, viewModel.config.endingTime < duration {
            markers.append(1 - viewModel.config.endingTime / duration)
        }
        return markers
    }

    private var lockButton: some View {
        HStack {
            Button {
                isLocked.toggle()
                scheduleHideControls()
            } label: {
                Image(systemName: isLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(isLocked ? Color.orange.opacity(0.85) : Color.black.opacity(0.4)))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.leading, 16)
        .transition(.opacity)
    }

    // MARK: - 提示

    /// 拖动进度、亮度音量、长按倍速、双击快进快退的提示
    private var feedbackLayer: some View {
        ZStack {
            if let seekPreview {
                seekHUD(target: seekPreview)
            }

            #if os(macOS)
            if let playFeedback {
                Image(systemName: playFeedback ? "play.fill" : "pause.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(Color.black.opacity(0.45)))
                    .transition(.opacity.combined(with: .scale(scale: 1.25)))
            }
            #endif

            if let level {
                HStack {
                    if level.isVolume { Spacer() }
                    levelIndicator(isVolume: level.isVolume, value: level.value)
                    if !level.isVolume { Spacer() }
                }
                .padding(.horizontal, 40)
            }

            if viewModel.isBoosting {
                VStack {
                    Label("\(formatSpeed(PlayerViewModel.boostRate)) 快进中", systemImage: "forward.fill")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                    Spacer()
                }
                .padding(.top, 20)
            }

            if let skipFeedback, skipFeedback != .center {
                HStack {
                    if skipFeedback == .right { Spacer() }
                    Label(
                        skipFeedback == .left ? "-\(Int(Self.skipSeconds)) 秒" : "+\(Int(Self.skipSeconds)) 秒",
                        systemImage: skipFeedback == .left ? "backward.fill" : "forward.fill"
                    )
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.5)))
                    if skipFeedback == .left { Spacer() }
                }
                .padding(.horizontal, 80)
                .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
    }

    private func seekHUD(target: Double) -> some View {
        let delta = target - viewModel.currentTime
        let duration = viewModel.duration
        return VStack(spacing: 4) {
            HStack(spacing: 0) {
                Text(PlayerViewModel.formatTime(target))
                    .foregroundColor(.white)
                Text(" / " + PlayerViewModel.formatTime(duration))
                    .foregroundColor(.white.opacity(0.5))
            }
            .font(.title2.weight(.semibold))
            .monospacedDigit()
            Text((delta >= 0 ? "+ " : "- ") + PlayerViewModel.formatTime(abs(delta)))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundColor(.orange)
            ProgressView(value: duration > 0 ? min(max(target / duration, 0), 1) : 0)
                .tint(.orange)
                .frame(width: 180)
                .padding(.top, 6)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.65)))
    }

    private func levelIndicator(isVolume: Bool, value: Double) -> some View {
        VStack(spacing: 10) {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    Capsule().fill(Color.white.opacity(0.2))
                    Capsule().fill(Color.white)
                        .frame(height: geometry.size.height * value)
                }
            }
            .frame(width: 6)
            Image(systemName: isVolume ? "speaker.wave.2.fill" : "sun.max.fill")
                .font(.system(size: 16))
                .foregroundColor(.white)
        }
        .frame(width: 44, height: 168)
        .padding(.vertical, 12)
        .background(Capsule().fill(Color.black.opacity(0.55)))
    }

    private func upNextCard(countdown: Int) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                HStack(spacing: 12) {
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.2), lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: CGFloat(countdown) / CGFloat(PlayerViewModel.upNextSeconds))
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: countdown)
                        Text("\(countdown)")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("即将播放")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        if viewModel.episodes.indices.contains(viewModel.episodeIndex + 1) {
                            Text(viewModel.episodes[viewModel.episodeIndex + 1].name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        HStack(spacing: 8) {
                            cardButton("立即播放", primary: true, action: viewModel.playUpNext)
                            cardButton("取消", action: viewModel.dismissUpNext)
                        }
                    }
                }
                .padding(14)
                .frame(width: 280, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .environment(\.colorScheme, .dark)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 72)
    }

    private func errorOverlay(_ error: Error) -> some View {
        ZStack {
            VStack {
                HStack {
                    iconButton("chevron.left", size: 20) { dismiss() }
                    Spacer()
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.yellow)
                Text("播放失败")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(AppErrorMessage.userMessage(for: error))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    cardButton("重试", primary: true, action: viewModel.reload)
                    if sources.count > 1 {
                        cardButton("换线路") { openPanel(.episodes) }
                    }
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: 360)
            .padding()
        }
    }

    // MARK: - 面板

    @ViewBuilder
    private func panelView(_ panel: PlayerPanel, width: CGFloat) -> some View {
        PlayerSidePanel(width: width) {
            switch panel {
            case .settings:
                PlayerSettingsPanel(
                    viewModel: viewModel,
                    onOpenSubtitleFile: openSubtitleFile,
                    onSearchSubtitle: { openPanel(.subtitleSearch) }
                )
            case .speed:
                PlayerSpeedPanel(viewModel: viewModel, onSelect: closePanel)
            case .episodes:
                PlayerEpisodesPanel(viewModel: viewModel, onSelect: closePanel)
            case .subtitleSearch:
                PlayerSubtitleSearchPanel(viewModel: viewModel, keyword: title, onLoaded: closePanel)
            }
        }
    }

    private func openPanel(_ panel: PlayerPanel) {
        hideControlsTask?.cancel()
        #if os(macOS)
        macMenu = nil
        // 控制条随面板消失，收不到鼠标移出
        isHoveringControls = false
        #endif
        withAnimation(.easeOut(duration: 0.2)) {
            self.panel = panel
        }
    }

    private func closePanel() {
        withAnimation(.easeOut(duration: 0.2)) {
            panel = nil
        }
        scheduleHideControls()
    }

    private func openSubtitleFile() {
        #if os(macOS)
        macMenu = nil
        #endif
        closePanel()
        isImportingSubtitle = true
    }

    // MARK: - 按钮

    private func iconButton(_ systemName: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func textButton(_ title: String, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(highlighted ? .orange : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func cardButton(_ title: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 7).fill(primary ? Color.orange : Color.white.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 手势和键盘

    private func handleTap() {
        #if os(macOS)
        // Mac 单击画面播放/暂停，控制层跟着鼠标显示隐藏；菜单打开时先关菜单
        if macMenu != nil {
            macMenu = nil
            return
        }
        viewModel.togglePlayPause()
        showPlayFeedback()
        #else
        withAnimation(.easeInOut(duration: 0.2)) {
            showControls.toggle()
        }
        scheduleHideControls()
        #endif
    }

    private func handleDoubleTap(_ zone: PlayerTapZone) {
        #if os(macOS)
        // Mac 双击画面切换全屏，和系统播放器一样
        toggleFullScreen()
        #else
        switch zone {
        case .left: viewModel.skip(by: -Self.skipSeconds)
        case .right: viewModel.skip(by: Self.skipSeconds)
        case .center: viewModel.togglePlayPause()
        }
        guard zone != .center else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            skipFeedback = zone
        }
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            if skipFeedback == zone {
                withAnimation(.easeOut(duration: 0.2)) {
                    skipFeedback = nil
                }
            }
        }
        #endif
    }

    private func handlePan(_ pan: PlayerPan) {
        switch pan {
        case .seek(let fraction):
            guard viewModel.duration > 0 else { return }
            if seekPreview == nil {
                panStartTime = viewModel.currentTime
            }
            seekPreview = min(max(panStartTime + fraction * Self.panSeekRange, 0), viewModel.duration)
        case .brightness(let value):
            level = (false, Double(value))
        case .volume(let value):
            level = (true, Double(value))
        case .ended:
            if let seekPreview {
                viewModel.seek(to: seekPreview)
            }
            seekPreview = nil
            level = nil
        }
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        #if os(macOS)
        if press.key == .escape {
            handleEscape()
            return .handled
        }
        #endif
        guard panel == nil else { return .ignored }
        switch press.key {
        case .space:
            viewModel.togglePlayPause()
        case .leftArrow:
            viewModel.skip(by: -Self.skipSeconds)
        case .rightArrow:
            viewModel.skip(by: Self.skipSeconds)
        case .upArrow:
            viewModel.adjustVolume(by: 0.1)
        case .downArrow:
            viewModel.adjustVolume(by: -0.1)
        default:
            #if os(macOS)
            switch press.characters.lowercased() {
            case "f": toggleFullScreen()
            case "m": viewModel.toggleMute()
            case "n": viewModel.playNext()
            case "[": viewModel.stepSpeed(by: -1)
            case "]": viewModel.stepSpeed(by: 1)
            default: return .ignored
            }
            #else
            return .ignored
            #endif
        }
        return .handled
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: Self.hideControlsDelay)
            if !Task.isCancelled {
                await MainActor.run {
                    #if os(macOS)
                    // 鼠标停在控制条上、菜单或面板打开时不隐藏
                    guard !isHoveringControls, macMenu == nil, panel == nil else { return }
                    NSCursor.setHiddenUntilMouseMoves(true)
                    #endif
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showControls = false
                    }
                }
            }
        }
    }

    // MARK: - 文字

    private var resolutionLabel: String? {
        guard let size = viewModel.engine?.naturalSize, size.height > 0 else { return nil }
        let height = min(size.width, size.height)
        switch height {
        case 2000...: return "4K"
        case 1400...: return "2K"
        case 1000...: return "1080P"
        case 700...: return "720P"
        default: return "\(Int(height))P"
        }
    }

    private func speedLabel(_ bytesPerSecond: Int64) -> String {
        if bytesPerSecond >= 1024 * 1024 {
            return String(format: "%.1f MB/s", Double(bytesPerSecond) / 1024 / 1024)
        }
        return "\(bytesPerSecond / 1024) KB/s"
    }
}

// MARK: - macOS 控制条

#if os(macOS)
/// 控制条上弹出的菜单
private enum MacPlayerMenu {
    case speed, tracks
}

extension PlayerView {
    /// Mac 的底部控制条：所有按钮放在一行，倍速和字幕音轨用就近弹出的菜单
    private var macBottomBar: some View {
        VStack(spacing: 2) {
            progressBar

            HStack(spacing: 2) {
                macIconButton(viewModel.isPlaying ? "pause.fill" : "play.fill", size: 17, help: viewModel.isPlaying ? "暂停 (空格)" : "播放 (空格)") {
                    viewModel.togglePlayPause()
                }
                macIconButton("forward.end.fill", help: "下一集 (N)", action: viewModel.playNext)
                macIconButton(volumeIcon, help: viewModel.isMuted ? "取消静音 (M)" : "静音 (M)", action: viewModel.toggleMute)
                Slider(
                    value: Binding(
                        get: { Double(viewModel.isMuted ? 0 : viewModel.volume) },
                        set: { viewModel.setVolume(Float($0)) }
                    ),
                    in: 0...1
                )
                .controlSize(.mini)
                .tint(.white)
                .frame(width: 72)

                HStack(spacing: 0) {
                    Text(PlayerViewModel.formatTime(seekPreview ?? viewModel.currentTime))
                        .foregroundColor(.white)
                    Text(" / " + PlayerViewModel.formatTime(viewModel.duration))
                        .foregroundColor(.white.opacity(0.6))
                }
                .font(.footnote)
                .monospacedDigit()
                .padding(.leading, 10)

                Spacer()

                let speedChanged = viewModel.config.speed != 1
                macTextButton(speedChanged ? formatSpeed(viewModel.config.speed) : "倍速", highlighted: speedChanged, help: "倍速 ([ ])") {
                    toggleMacMenu(.speed)
                }
                .overlay(alignment: .bottom) {
                    if macMenu == .speed {
                        speedMenu.offset(y: -44)
                    }
                }
                if !viewModel.episodes.isEmpty {
                    macTextButton("选集", help: "选集") { openPanel(.episodes) }
                }
                macIconButton("captions.bubble", help: "字幕与音轨") { toggleMacMenu(.tracks) }
                    .overlay(alignment: .bottomTrailing) {
                        if macMenu == .tracks {
                            tracksMenu.offset(y: -44)
                        }
                    }
                macIconButton("gearshape", help: "播放设置") { openPanel(.settings) }
                macIconButton(
                    isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                    help: isFullScreen ? "退出全屏 (F)" : "全屏 (F)",
                    action: toggleFullScreen
                )
            }
        }
        .onHover { isHoveringControls = $0 }
    }

    private var volumeIcon: String {
        let volume = viewModel.isMuted ? 0 : viewModel.volume
        switch volume {
        case 0: return "speaker.slash.fill"
        case ..<0.34: return "speaker.wave.1.fill"
        case ..<0.67: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }

    private var speedMenu: some View {
        macMenuPanel(width: 150) {
            macMenuHeader("倍速")
            ForEach(PlayerViewModel.speedOptions.reversed(), id: \.self) { speed in
                macMenuRow(formatSpeed(speed), isSelected: viewModel.config.speed == speed) {
                    viewModel.setSpeed(speed)
                    closeMacMenu()
                }
            }
        }
    }

    private var tracksMenu: some View {
        macMenuPanel(width: 220) {
            macMenuHeader("字幕")
            macMenuRow("关", isSelected: viewModel.selectedSubtitleID == nil) {
                viewModel.selectSubtitle(id: nil)
                closeMacMenu()
            }
            ForEach(viewModel.subtitleTracks) { track in
                macMenuRow(track.name, isSelected: viewModel.selectedSubtitleID == track.id) {
                    viewModel.selectSubtitle(id: track.id)
                    closeMacMenu()
                }
            }
            macMenuRow("本地字幕…", isSelected: false, action: openSubtitleFile)
            macMenuRow("在线字幕…", isSelected: false) { openPanel(.subtitleSearch) }
            if viewModel.audioTracks.count > 1 {
                Divider()
                    .overlay(Color.white.opacity(0.1))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                macMenuHeader("音轨")
                ForEach(viewModel.audioTracks) { track in
                    macMenuRow(track.name, isSelected: viewModel.selectedAudioTrackID == track.id) {
                        viewModel.selectAudioTrack(id: track.id)
                        closeMacMenu()
                    }
                }
            }
        }
    }

    /// 进度条悬停时显示的时间，靠近片头片尾标记时一并提示
    private func hoverTimeTip(fraction: Double, duration: Double) -> some View {
        let opening = viewModel.config.openingTime
        let ending = viewModel.config.endingTime
        let marker: String?
        if opening > 0, abs(fraction - opening / duration) < 0.01 {
            marker = "片头"
        } else if ending > 0, abs(fraction - (1 - ending / duration)) < 0.01 {
            marker = "片尾"
        } else {
            marker = nil
        }
        return HStack(spacing: 4) {
            Text(PlayerViewModel.formatTime(fraction * duration))
                .foregroundColor(.white)
            if let marker {
                Text(marker)
                    .foregroundColor(.yellow)
            }
        }
        .font(.caption)
        .monospacedDigit()
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.75)))
        .fixedSize()
        .allowsHitTesting(false)
    }

    // MARK: 菜单

    private func toggleMacMenu(_ menu: MacPlayerMenu) {
        hideControlsTask?.cancel()
        withAnimation(.easeOut(duration: 0.15)) {
            macMenu = macMenu == menu ? nil : menu
        }
        if macMenu == nil {
            scheduleHideControls()
        }
    }

    private func closeMacMenu() {
        withAnimation(.easeOut(duration: 0.15)) {
            macMenu = nil
        }
        scheduleHideControls()
    }

    private func macMenuPanel<Content: View>(width: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(6)
        .frame(width: width)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        .environment(\.colorScheme, .dark)
        .fixedSize(horizontal: false, vertical: true)
        .transition(.opacity)
    }

    private func macMenuHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundColor(.white.opacity(0.5))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }

    private func macMenuRow(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            .foregroundColor(isSelected ? .orange : .white.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlayerHoverButtonStyle())
    }

    // MARK: 按钮

    private func macIconButton(_ systemName: String, size: CGFloat = 15, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlayerHoverButtonStyle())
        .help(help)
    }

    private func macTextButton(_ title: String, highlighted: Bool = false, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundColor(highlighted ? .orange : .white)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlayerHoverButtonStyle())
        .help(help)
    }

    // MARK: 操作

    private func showPlayFeedback() {
        let playing = viewModel.isPlaying
        withAnimation(.easeOut(duration: 0.15)) {
            playFeedback = playing
        }
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if playFeedback == playing {
                withAnimation(.easeOut(duration: 0.25)) {
                    playFeedback = nil
                }
            }
        }
    }

    private func toggleFullScreen() {
        NSApp.keyWindow?.toggleFullScreen(nil)
    }

    /// Esc 依次关闭菜单、面板，退出全屏，最后返回
    private func handleEscape() {
        if macMenu != nil {
            closeMacMenu()
        } else if panel != nil {
            closePanel()
        } else if isFullScreen {
            toggleFullScreen()
        } else {
            dismiss()
        }
    }
}

/// 鼠标悬停时显示浅色底，按下时更深
private struct PlayerHoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverLabel(configuration: configuration)
    }

    private struct HoverLabel: View {
        let configuration: ButtonStyleConfiguration
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white.opacity(configuration.isPressed ? 0.22 : isHovering ? 0.14 : 0))
                )
                .onHover { isHovering = $0 }
        }
    }
}
#endif
