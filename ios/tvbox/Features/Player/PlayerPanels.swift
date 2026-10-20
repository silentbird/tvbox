import SwiftUI

/// 播放页右侧弹出的面板
enum PlayerPanel {
    case settings, speed, episodes, subtitleSearch
}

/// 右侧半透明面板，左边留出画面。遮罩由播放页单独淡入，不跟着面板滑动
struct PlayerSidePanel<Content: View>: View {
    let width: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            content
                .frame(width: width)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        }
        .ignoresSafeArea()
    }
}

/// 面板里可选的小块
private struct PanelChip: View {
    let title: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .lineLimit(1)
                .foregroundColor(isSelected ? .orange : .white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isSelected ? Color.orange.opacity(0.18) : Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isSelected ? Color.orange.opacity(0.6) : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct PanelSection<Content: View>: View {
    let title: String
    var note: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                if let note {
                    Text(note)
                }
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.5))
            content
        }
    }
}

private struct PanelHeader: View {
    let title: String
    var note: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}

// MARK: - 播放设置

struct PlayerSettingsPanel: View {
    @ObservedObject var viewModel: PlayerViewModel
    let onOpenSubtitleFile: () -> Void
    let onSearchSubtitle: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PanelHeader(title: "播放设置", note: "仅对本剧生效")

                PanelSection(title: "画面比例") {
                    FlowLayout(spacing: 6) {
                        ForEach(VideoScale.allCases) { scale in
                            PanelChip(title: scale.name, isSelected: viewModel.scale == scale) {
                                viewModel.setScale(scale)
                            }
                        }
                    }
                }

                PanelSection(title: "跳过片头片尾", note: "设置后自动跳过") {
                    VStack(alignment: .leading, spacing: 8) {
                        skipRow(
                            title: "片头",
                            time: viewModel.config.openingTime,
                            set: viewModel.setOpeningToCurrent,
                            clear: viewModel.clearOpening
                        )
                        skipRow(
                            title: "片尾",
                            time: viewModel.config.endingTime,
                            set: viewModel.setEndingToCurrent,
                            clear: viewModel.clearEnding
                        )
                    }
                }

                PanelSection(title: "字幕", note: "样式对所有视频生效") {
                    VStack(alignment: .leading, spacing: 10) {
                        FlowLayout(spacing: 6) {
                            PanelChip(title: "关", isSelected: viewModel.selectedSubtitleID == nil) {
                                viewModel.selectSubtitle(id: nil)
                            }
                            ForEach(viewModel.subtitleTracks) { track in
                                PanelChip(title: track.name, isSelected: viewModel.selectedSubtitleID == track.id) {
                                    viewModel.selectSubtitle(id: track.id)
                                }
                            }
                            PanelChip(title: "本地字幕…", action: onOpenSubtitleFile)
                            PanelChip(title: "在线字幕…", action: onSearchSubtitle)
                        }
                        stepperRow(
                            title: "字号",
                            value: "\(Int(viewModel.subtitleStyle.fontSize))",
                            minus: { viewModel.updateSubtitleStyle { $0.fontSize -= 2 } },
                            plus: { viewModel.updateSubtitleStyle { $0.fontSize += 2 } }
                        )
                        stepperRow(
                            title: "延时",
                            value: formatDelay(viewModel.subtitleStyle.delay),
                            minus: { viewModel.updateSubtitleStyle { $0.delay -= 0.5 } },
                            plus: { viewModel.updateSubtitleStyle { $0.delay += 0.5 } }
                        )
                        stepperRow(
                            title: "位置",
                            value: viewModel.subtitleStyle.position == 0 ? "默认" : String(format: "%+.0f%%", viewModel.subtitleStyle.position),
                            minus: { viewModel.updateSubtitleStyle { $0.position -= 2 } },
                            plus: { viewModel.updateSubtitleStyle { $0.position += 2 } }
                        )
                        HStack(spacing: 6) {
                            Text("颜色")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            PanelChip(title: "白色", isSelected: !viewModel.subtitleStyle.isPink) {
                                viewModel.updateSubtitleStyle { $0.isPink = false }
                            }
                            PanelChip(title: "粉色", isSelected: viewModel.subtitleStyle.isPink) {
                                viewModel.updateSubtitleStyle { $0.isPink = true }
                            }
                        }
                    }
                }

                if viewModel.audioTracks.count > 1 {
                    PanelSection(title: "音轨") {
                        FlowLayout(spacing: 6) {
                            ForEach(viewModel.audioTracks) { track in
                                PanelChip(title: track.name, isSelected: viewModel.selectedAudioTrackID == track.id) {
                                    viewModel.selectAudioTrack(id: track.id)
                                }
                            }
                        }
                    }
                }

                PanelSection(title: "其它") {
                    FlowLayout(spacing: 6) {
                        PanelChip(title: "重新加载", action: viewModel.reload)
                        PanelChip(title: "从头播放", action: viewModel.replay)
                    }
                }
            }
            .padding(20)
        }
    }

    /// 正数表示字幕推后
    private func formatDelay(_ delay: Double) -> String {
        delay == 0 ? "0 秒" : String(format: "%+.1f 秒", delay)
    }

    private func stepperRow(title: String, value: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            stepButton("minus", action: minus)
            Text(value)
                .foregroundColor(.white)
                .monospacedDigit()
                .frame(minWidth: 64)
            stepButton("plus", action: plus)
        }
        .font(.subheadline)
    }

    private func stepButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 32, height: 28)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }

    private func skipRow(title: String, time: Double, set: @escaping () -> Void, clear: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .foregroundColor(.white.opacity(0.7))
            Text(time > 0 ? PlayerViewModel.formatTime(time) : "—")
                .foregroundColor(.white)
                .monospacedDigit()
                .frame(width: 56, alignment: .leading)
            Button(action: set) {
                Text("设为当前 \(PlayerViewModel.formatTime(viewModel.currentTime))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.14)))
            }
            .buttonStyle(.plain)
            if time > 0 {
                Button("清除", action: clear)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .buttonStyle(.plain)
            }
        }
        .font(.subheadline)
    }
}

// MARK: - 在线字幕

/// 对应 Android 的 SearchSubtitleDialog，可以切换字幕网站。字幕包要先点开再选里面的文件
struct PlayerSubtitleSearchPanel: View {
    @ObservedObject var viewModel: PlayerViewModel
    /// 默认搜索词，用片名
    let keyword: String
    let onLoaded: () -> Void

    /// 记住上次用的字幕网站
    @AppStorage("subtitle_search_source") private var source: SubtitleSearch.Source = .xunlei
    @State private var query = ""
    @State private var results: [SubtitleSearch.Item] = []
    @State private var page = 0
    @State private var pageCount = 0
    /// 打开的字幕包和里面的文件，nil 时显示搜索结果
    @State private var opened: (item: SubtitleSearch.Item, files: [SubtitleSearch.Item])?
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(title: "在线字幕")

            HStack(spacing: 6) {
                ForEach(SubtitleSearch.Source.allCases) { item in
                    PanelChip(title: item.name, isSelected: source == item) {
                        guard source != item else { return }
                        source = item
                        search(page: 1)
                    }
                }
            }
            .disabled(isLoading)

            HStack(spacing: 8) {
                TextField("片名", text: $query)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.1)))
                    .onSubmit { search(page: 1) }
                PanelChip(title: "搜索") { search(page: 1) }
            }
            .disabled(isLoading)

            if let hint = source.hint {
                Text(hint)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if let opened {
                        row(title: "‹ 返回搜索结果", isSecondary: true) {
                            self.opened = nil
                            message = nil
                        }
                        Text(opened.item.name)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                        ForEach(opened.files) { file in
                            row(title: file.name) { load(file) }
                        }
                    } else {
                        ForEach(results) { item in
                            row(title: item.name, detail: item.detail) {
                                if item.isPackage {
                                    open(item)
                                } else {
                                    load(item)
                                }
                            }
                        }
                        if page < pageCount, !isLoading {
                            row(title: "加载更多", isSecondary: true) { search(page: page + 1) }
                        }
                    }

                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    } else if let message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
            }
            .disabled(isLoading)
        }
        .padding(20)
        .onAppear {
            guard query.isEmpty else { return }
            query = keyword
            search(page: 1)
        }
    }

    private func row(title: String, detail: String? = nil, isSecondary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(isSecondary ? .orange : .white.opacity(0.85))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(isSecondary ? 0 : 0.06)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func search(page: Int) {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        if page == 1 {
            results = []
            opened = nil
        }
        let source = source
        let duration = viewModel.duration
        run {
            let result = try await SubtitleSearch.search(keyword, page: page, source: source, duration: duration)
            results = page == 1 ? result.items : results + result.items
            self.page = page
            pageCount = result.pageCount
            opened = nil
            if results.isEmpty {
                message = "没有找到字幕"
            }
        }
    }

    private func open(_ item: SubtitleSearch.Item) {
        run {
            let files = try await SubtitleSearch.files(in: item)
            opened = (item, files)
            if files.isEmpty {
                message = "这个字幕包里没有支持的格式 (SRT、ASS、VTT)"
            }
        }
    }

    private func load(_ file: SubtitleSearch.Item) {
        run {
            try await viewModel.loadOnlineSubtitle(file)
            onLoaded()
        }
    }

    private func run(_ operation: @escaping () async throws -> Void) {
        isLoading = true
        message = nil
        Task {
            do {
                try await operation()
            } catch {
                message = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - 倍速

struct PlayerSpeedPanel: View {
    @ObservedObject var viewModel: PlayerViewModel
    let onSelect: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                PanelHeader(title: "倍速")
                    .padding(.bottom, 8)
                ForEach(PlayerViewModel.speedOptions.reversed(), id: \.self) { speed in
                    let isSelected = viewModel.config.speed == speed
                    Button {
                        viewModel.setSpeed(speed)
                        onSelect()
                    } label: {
                        HStack {
                            Text(formatSpeed(speed))
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                            }
                        }
                        .font(.body.weight(isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .orange : .white.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(isSelected ? Color.orange.opacity(0.12) : .clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
    }
}

func formatSpeed(_ speed: Float) -> String {
    let text = String(format: "%.2f", speed)
        .replacingOccurrences(of: #"0$"#, with: "", options: .regularExpression)
    return text + "x"
}

// MARK: - 选集

struct PlayerEpisodesPanel: View {
    @ObservedObject var viewModel: PlayerViewModel
    let onSelect: () -> Void
    /// 面板里正在看的线路，切换线路不会马上播放
    @State private var browsingSource: Int?

    private var sourceIndex: Int { browsingSource ?? viewModel.sourceIndex }

    var body: some View {
        if viewModel.sources.indices.contains(sourceIndex) {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(title: "选集", note: "共 \(viewModel.sources[sourceIndex].episodes.count) 集")
                .padding(.horizontal, 20)
                .padding(.top, 20)

            if viewModel.sources.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(viewModel.sources.indices, id: \.self) { index in
                            PanelChip(title: viewModel.sources[index].flag, isSelected: index == sourceIndex) {
                                browsingSource = index
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                        ForEach(viewModel.sources[sourceIndex].episodes.indices, id: \.self) { index in
                            episodeCell(index: index)
                                .id(index)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .onAppear {
                    proxy.scrollTo(viewModel.episodeIndex, anchor: .center)
                }
            }
        }
    }

    private func episodeCell(index: Int) -> some View {
        let isPlaying = sourceIndex == viewModel.sourceIndex && index == viewModel.episodeIndex
        return Button {
            viewModel.select(sourceIndex: sourceIndex, episodeIndex: index)
            onSelect()
        } label: {
            Text(viewModel.sources[sourceIndex].episodes[index].name)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundColor(isPlaying ? .orange : .white.opacity(0.8))
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isPlaying ? Color.orange.opacity(0.18) : Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isPlaying ? Color.orange.opacity(0.6) : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
