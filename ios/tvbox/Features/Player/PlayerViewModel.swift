import SwiftUI

/// 播放页可切换的一条线路
struct PlaySource {
    let flag: String
    let episodes: [VodInfo.VodPlayItem]
}

@MainActor
final class PlayerViewModel: ObservableObject {
    /// 当前使用的播放内核
    @Published private(set) var engine: PlaybackEngine?
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var error: Error?

    @Published private(set) var sourceIndex = 0
    @Published private(set) var episodeIndex = 0
    /// 本剧的播放设置 (比例、倍速、片头片尾)
    @Published private(set) var config = StorageManager.VodPlayerConfig()
    /// 长按临时 3 倍速中
    @Published private(set) var isBoosting = false
    /// 自动播放下一集的倒计时 (秒)，nil 表示没有在倒计时
    @Published private(set) var upNextCountdown: Int?
    /// 每秒下载的字节数，内核测不到时为 nil (如 HLS 的分片不经过顶层 IO)
    @Published private(set) var networkSpeed: Int64?
    /// 播放器音量 0...1，换集后沿用
    @Published private(set) var volume: Float = 1
    @Published private(set) var isMuted = false
    /// 字幕字号、颜色、延时，所有视频共用
    @Published private(set) var subtitleStyle = SubtitleStyle.load()

    @Published var showToast = false
    @Published private(set) var toastMessage = ""

    /// 可切换的线路
    private(set) var sources: [PlaySource] = []
    private var configKey = ""
    private var resolve: ((String, VodInfo.VodPlayItem) async throws -> PlayAddress)?
    private var onProgress: (@MainActor (Int, Int, Double, Double) -> Void)?

    private var resolveTask: Task<Void, Never>?
    private var upNextTask: Task<Void, Never>?
    private var speedTask: Task<Void, Never>?
    private var subtitleTask: Task<Void, Never>?

    /// 当前剧集的播放地址，重新加载时复用
    private var address: PlayAddress?
    /// 播放内核已就绪，可以上报进度
    private var isReady = false
    /// 准备好后需要跳转到的位置 (续播)
    private var pendingSeekPosition: Double = 0
    private var lastReportedTime: TimeInterval = 0
    /// 当前剧集已看完，进度按 0 记录 (和 Android 一样播完清除进度)
    private var didPlayToEnd = false
    /// 本集已取消过自动播放下一集，不再弹出
    private var didCancelUpNext = false

    /// 播放进度上报间隔 (秒)
    private static let progressReportInterval: TimeInterval = 5
    /// 自动播放下一集前的倒计时 (秒)
    static let upNextSeconds = 5
    /// 长按时的倍速，和 Android 一样
    static let boostRate: Float = 3
    /// 倍速选项，和 Android 一样
    static let speedOptions: [Float] = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 3.0]

    var progress: Double {
        duration > 0 ? min(currentTime / duration, 1) : 0
    }

    var episodes: [VodInfo.VodPlayItem] {
        sources.indices.contains(sourceIndex) ? sources[sourceIndex].episodes : []
    }

    var currentEpisode: VodInfo.VodPlayItem? {
        episodes.indices.contains(episodeIndex) ? episodes[episodeIndex] : nil
    }

    var currentFlag: String {
        sources.indices.contains(sourceIndex) ? sources[sourceIndex].flag : ""
    }

    var hasNext: Bool { episodeIndex + 1 < episodes.count }

    var scale: VideoScale {
        VideoScale(rawValue: config.scale) ?? .default
    }

    /// 按集记住手动选的字幕，和 Android 的 subtitleCacheKey 一样区分线路
    private var subtitleKey: String {
        "\(configKey)_\(currentFlag)_\(currentEpisode?.name ?? "")"
    }

    func start(
        sources: [PlaySource],
        sourceIndex: Int,
        episodeIndex: Int,
        startPosition: Double,
        configKey: String,
        resolve: @escaping (String, VodInfo.VodPlayItem) async throws -> PlayAddress,
        onProgress: @escaping @MainActor (Int, Int, Double, Double) -> Void
    ) {
        self.sources = sources
        self.configKey = configKey
        self.resolve = resolve
        self.onProgress = onProgress
        config = StorageManager.shared.getPlayerConfig(key: configKey)
        startSpeedMonitor()
        play(sourceIndex: sourceIndex, episodeIndex: episodeIndex, startPosition: startPosition)
    }

    // MARK: - 选集

    /// 从选集面板选择剧集。换线路后选到同名的集，从当前位置接着播
    func select(sourceIndex: Int, episodeIndex: Int) {
        guard sourceIndex != self.sourceIndex || episodeIndex != self.episodeIndex else { return }
        let name = sources[sourceIndex].episodes[episodeIndex].name
        let position = name == currentEpisode?.name ? currentTime : 0
        play(sourceIndex: sourceIndex, episodeIndex: episodeIndex, startPosition: position)
    }

    func playNext() {
        guard hasNext else {
            showToast(message: "已经是最后一集了!")
            return
        }
        play(sourceIndex: sourceIndex, episodeIndex: episodeIndex + 1)
    }

    /// 重新获取播放地址并从当前位置播放，对应 Android 的「刷新」
    func reload() {
        play(sourceIndex: sourceIndex, episodeIndex: episodeIndex, startPosition: isReady ? currentTime : pendingSeekPosition)
    }

    /// 从头播放，对应 Android 的「重播」。和 Android 一样清掉这一集记住的字幕，下次打开不再自动加载
    func replay() {
        guard let engine else { return }
        StorageManager.shared.saveSubtitleFile(nil, key: subtitleKey)
        didPlayToEnd = false
        didCancelUpNext = false
        cancelUpNext()
        engine.seek(to: 0)
        engine.play()
        isPlaying = true
    }

    /// 先取得真实播放地址再开始播放
    private func play(sourceIndex: Int, episodeIndex: Int, startPosition: Double = 0) {
        reportProgress()
        resolveTask?.cancel()
        cancelUpNext()
        tearDownEngine()

        self.sourceIndex = sourceIndex
        self.episodeIndex = episodeIndex
        didPlayToEnd = false
        didCancelUpNext = false
        pendingSeekPosition = startPosition
        address = nil
        error = nil
        currentTime = 0
        duration = 0

        guard let episode = currentEpisode, let resolve else { return }
        let flag = currentFlag
        resolveTask = Task {
            do {
                let address = try await resolve(flag, episode)
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

    private func loadEngine() {
        guard let address else { return }
        tearDownEngine()
        error = nil

        let engine = PlayerKind.selected.makeEngine()
        engine.onEvent = { [weak self] event in
            self?.handle(event)
        }
        engine.load(url: address.url, headers: address.headers ?? [:], format: address.format)
        engine.setSubtitleStyle(subtitleStyle)
        self.engine = engine
        loadSubtitles(address.subtitles, into: engine)
    }

    private func handle(_ event: PlaybackEvent) {
        switch event {
        case .ready(let duration):
            isReady = true
            self.duration = duration
            engine?.setRate(config.speed)
            engine?.setScale(scale)
            engine?.volume = isMuted ? 0 : volume
            // 和 Android 一样，续播位置还在片头里时直接跳过片头
            var position = pendingSeekPosition
            pendingSeekPosition = 0
            if config.openingTime > 0, position < config.openingTime {
                position = config.openingTime
                showToast(message: "已跳过片头 \(Self.formatTime(config.openingTime))")
            }
            if position > 0 {
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
            if abs(current - lastReportedTime) >= Self.progressReportInterval {
                reportProgress()
            }
            // 到了片尾，倒计时后播下一集
            if config.endingTime > 0, current > 0, current + config.endingTime >= duration {
                startUpNext()
            }
        case .buffering(let buffering):
            isBuffering = buffering
        case .playedToEnd:
            // 播完清除该集进度，倒计时后播下一集
            didPlayToEnd = true
            isPlaying = false
            reportProgress()
            if hasNext {
                startUpNext()
            } else {
                showToast(message: "已经是最后一集了!")
            }
        case .failed(let error):
            self.error = error
        }
    }

    // MARK: - 自动播放下一集

    private func startUpNext() {
        guard PlaybackSettings.autoPlayNext, hasNext, upNextCountdown == nil, !didCancelUpNext else { return }
        upNextCountdown = Self.upNextSeconds
        upNextTask = Task {
            while let countdown = upNextCountdown, countdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                upNextCountdown = countdown - 1
            }
            playUpNext()
        }
    }

    func playUpNext() {
        // 片尾跳过的这一集也算看完了
        didPlayToEnd = true
        playNext()
    }

    /// 取消这一集的自动下一集
    func dismissUpNext() {
        didCancelUpNext = true
        cancelUpNext()
    }

    private func cancelUpNext() {
        upNextTask?.cancel()
        upNextTask = nil
        upNextCountdown = nil
    }

    // MARK: - 播放控制

    func togglePlayPause() {
        guard let engine else { return }
        if isPlaying {
            engine.pause()
        } else {
            engine.play()
        }
        isPlaying.toggle()
    }

    func seek(to seconds: Double) {
        guard let engine, duration > 0 else { return }
        let position = min(max(seconds, 0), duration)
        currentTime = position
        engine.seek(to: position)
    }

    func skip(by seconds: Double) {
        seek(to: currentTime + seconds)
    }

    /// 长按时临时 3 倍速，松手后恢复本剧的倍速
    func setBoosting(_ boosting: Bool) {
        guard boosting != isBoosting, let engine else { return }
        if boosting {
            guard isPlaying else { return }
            engine.setRate(Self.boostRate)
        } else {
            engine.setRate(config.speed)
        }
        isBoosting = boosting
    }

    /// 播放器音量，macOS 用方向键调
    func adjustVolume(by delta: Float) {
        guard engine != nil else { return }
        setVolume((isMuted ? 0 : volume) + delta)
        showToast(message: "音量 \(Int((volume * 100).rounded()))%")
    }

    /// 改音量会取消静音
    func setVolume(_ value: Float) {
        volume = min(max(value, 0), 1)
        isMuted = false
        engine?.volume = volume
    }

    func toggleMute() {
        isMuted.toggle()
        engine?.volume = isMuted ? 0 : volume
    }

    // MARK: - 播放设置

    func setSpeed(_ speed: Float) {
        config.speed = speed
        saveConfig()
        if !isBoosting {
            engine?.setRate(speed)
        }
    }

    /// 切到倍速选项里的上一档或下一档，macOS 用 [ ] 键
    func stepSpeed(by step: Int) {
        let current = Self.speedOptions.firstIndex(of: config.speed) ?? Self.speedOptions.firstIndex(of: 1) ?? 0
        let index = min(max(current + step, 0), Self.speedOptions.count - 1)
        setSpeed(Self.speedOptions[index])
        showToast(message: "倍速 \(formatSpeed(Self.speedOptions[index]))")
    }

    func setScale(_ scale: VideoScale) {
        config.scale = scale.rawValue
        saveConfig()
        engine?.setScale(scale)
    }

    /// 把当前位置设为片头，对应 Android 的「片头」按钮
    func setOpeningToCurrent() {
        guard isReady else { return }
        config.openingTime = currentTime.rounded(.down)
        saveConfig()
    }

    /// 把当前位置到结尾设为片尾，对应 Android 的「片尾」按钮
    func setEndingToCurrent() {
        guard isReady, duration > 0 else { return }
        config.endingTime = (duration - currentTime).rounded(.down)
        saveConfig()
    }

    func clearOpening() {
        config.openingTime = 0
        saveConfig()
    }

    func clearEnding() {
        config.endingTime = 0
        saveConfig()
    }

    private func saveConfig() {
        StorageManager.shared.savePlayerConfig(config, key: configKey)
    }

    // MARK: - 音轨、字幕

    var audioTracks: [PlaybackTrack] { engine?.audioTracks ?? [] }
    var selectedAudioTrackID: String? { engine?.selectedAudioTrackID }
    var subtitleTracks: [PlaybackTrack] { engine?.subtitleTracks ?? [] }
    var selectedSubtitleID: String? { engine?.selectedSubtitleID }

    func selectAudioTrack(id: String) {
        engine?.selectAudioTrack(id: id)
        objectWillChange.send()
    }

    func selectSubtitle(id: String?) {
        engine?.selectSubtitle(id: id)
        objectWillChange.send()
    }

    /// 和 Android 一样，这一集上次手动选的字幕优先，其次是站点给的第一条
    private func loadSubtitles(_ subtitles: [SubtitleInfo], into engine: PlaybackEngine) {
        var candidates: [(url: URL, name: String)] = []
        if let file = StorageManager.shared.getSubtitleFile(key: subtitleKey) {
            candidates.append((StorageManager.shared.subtitleDirectory.appendingPathComponent(file), file))
        }
        for (index, subtitle) in subtitles.enumerated() {
            guard let url = URL(string: subtitle.url) else { continue }
            candidates.append((url, subtitle.name.isEmpty ? "外挂字幕 \(index + 1)" : subtitle.name))
        }
        guard !candidates.isEmpty else { return }

        subtitleTask = Task {
            var didSelect = false
            for candidate in candidates {
                do {
                    let id = try await engine.loadSubtitle(url: candidate.url, name: candidate.name)
                    guard !Task.isCancelled else { return }
                    if !didSelect {
                        engine.selectSubtitle(id: id)
                        didSelect = true
                    }
                    objectWillChange.send()
                } catch {
                    AppLogger.debug("[Player] 字幕加载失败 \(candidate.url): \(error)")
                }
            }
        }
    }

    /// 加载本地字幕文件，对应 Android 的「本地字幕」
    func openSubtitleFile(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        guard let data = try? Data(contentsOf: url) else {
            showToast(message: "读取字幕文件失败")
            return
        }
        Task {
            do {
                try await addSubtitleFile(data: data, name: url.lastPathComponent)
            } catch {
                showToast(message: "字幕解析失败，支持 SRT、ASS、VTT")
            }
        }
    }

    /// 下载并加载在线搜到的字幕，对应 Android 的「在线搜索字幕」
    func loadOnlineSubtitle(_ file: SubtitleSearch.Item) async throws {
        let data = try await SubtitleSearch.download(file)
        try await addSubtitleFile(data: data, name: file.name)
    }

    /// 字幕文件存到缓存目录，加载并选中，记给这一集。存一份是为了下次打开这一集时不用再授权或下载
    private func addSubtitleFile(data: Data, name: String) async throws {
        guard let engine else { return }
        let key = subtitleKey
        let name = (name as NSString).lastPathComponent
        let directory = StorageManager.shared.subtitleDirectory
        let destination = directory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: destination)

        let id = try await engine.loadSubtitle(url: destination, name: name)
        guard self.engine === engine else { return }
        engine.selectSubtitle(id: id)
        StorageManager.shared.saveSubtitleFile(name, key: key)
        objectWillChange.send()
    }

    /// 改字号、颜色、延时，马上生效并保存
    func updateSubtitleStyle(_ update: (inout SubtitleStyle) -> Void) {
        update(&subtitleStyle)
        subtitleStyle.fontSize = min(max(subtitleStyle.fontSize, SubtitleStyle.fontSizeRange.lowerBound), SubtitleStyle.fontSizeRange.upperBound)
        subtitleStyle.position = min(max(subtitleStyle.position, SubtitleStyle.positionRange.lowerBound), SubtitleStyle.positionRange.upperBound)
        subtitleStyle.save()
        engine?.setSubtitleStyle(subtitleStyle)
    }

    // MARK: - 其它

    private func showToast(message: String) {
        toastMessage = message
        showToast = true
    }

    /// 每秒根据内核已下载的字节数算网速
    private func startSpeedMonitor() {
        speedTask?.cancel()
        speedTask = Task {
            var lastEngine: ObjectIdentifier?
            var lastBytes: Int64?
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                let currentEngine = engine.map(ObjectIdentifier.init)
                if currentEngine != lastEngine {
                    // 换了内核从头测，见到流量之前不显示
                    lastEngine = currentEngine
                    lastBytes = nil
                    networkSpeed = nil
                }
                let bytes = engine?.bytesRead
                if let bytes, let lastBytes, bytes > lastBytes || networkSpeed != nil {
                    networkSpeed = max(bytes - lastBytes, 0)
                }
                lastBytes = bytes
            }
        }
    }

    /// 上报当前剧集的播放进度，用于记录播放历史
    private func reportProgress() {
        // 还没开始播放时不上报，避免续播位置被 0 覆盖
        guard isReady, currentEpisode != nil else { return }
        lastReportedTime = currentTime
        onProgress?(sourceIndex, episodeIndex, didPlayToEnd ? 0 : currentTime, duration.isFinite ? duration : 0)
    }

    private func tearDownEngine() {
        subtitleTask?.cancel()
        engine?.stop()
        engine = nil
        isReady = false
        isPlaying = false
        isBuffering = false
        isBoosting = false
    }

    func cleanup() {
        reportProgress()
        resolveTask?.cancel()
        speedTask?.cancel()
        cancelUpNext()
        tearDownEngine()
    }

    nonisolated static func formatTime(_ time: TimeInterval) -> String {
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
