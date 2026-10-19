import SwiftUI

/// 播放页右侧弹出的面板
enum PlayerPanel {
    case settings, speed, episodes
}

/// 右侧半透明面板，左边留出画面，点空白处关闭
struct PlayerSidePanel<Content: View>: View {
    let width: CGFloat
    let onClose: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) {
            Color.black.opacity(0.25)
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)
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

                if !viewModel.subtitleTracks.isEmpty {
                    PanelSection(title: "字幕") {
                        FlowLayout(spacing: 6) {
                            PanelChip(title: "关", isSelected: viewModel.selectedSubtitleID == nil) {
                                viewModel.selectSubtitle(id: nil)
                            }
                            ForEach(viewModel.subtitleTracks) { track in
                                PanelChip(title: track.name, isSelected: viewModel.selectedSubtitleID == track.id) {
                                    viewModel.selectSubtitle(id: track.id)
                                }
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
