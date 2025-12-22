import SwiftUI
import AVKit

struct LiveView: View {
    @StateObject private var viewModel = LiveViewModel()
    @State private var selectedGroupIndex = 0
    @State private var selectedChannel: LiveChannelItem?
    @State private var showPlayer = false
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // 左侧分组列表
                groupList
                    .frame(width: geometry.size.width * 0.25)
                
                Divider()
                
                // 右侧频道列表
                channelList
                    .frame(width: geometry.size.width * 0.75)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("直播")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { viewModel.refreshChannels() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            if let channel = selectedChannel {
                LivePlayerView(channel: channel)
            }
        }
        .onAppear {
            viewModel.loadChannels()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("加载中...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 10)
            }
        }
    }
    
    // MARK: - Group List
    private var groupList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.channelGroups.enumerated()), id: \.element.id) { index, group in
                    Button(action: { selectedGroupIndex = index }) {
                        HStack {
                            Text(group.groupName)
                                .font(.subheadline)
                                .fontWeight(selectedGroupIndex == index ? .semibold : .regular)
                                .foregroundColor(selectedGroupIndex == index ? .white : .primary)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .background(selectedGroupIndex == index ? Color.blue : Color.clear)
                    }
                    
                    if index < viewModel.channelGroups.count - 1 {
                        Divider().padding(.leading, 12)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Channel List
    private var channelList: some View {
        ScrollView {
            if selectedGroupIndex < viewModel.channelGroups.count {
                let channels = viewModel.channelGroups[selectedGroupIndex].channels
                
                LazyVStack(spacing: 1) {
                    ForEach(channels) { channel in
                        ChannelRow(
                            channel: channel,
                            isSelected: selectedChannel?.id == channel.id,
                            currentProgram: viewModel.getCurrentProgram(for: channel)
                        )
                        .onTapGesture {
                            selectedChannel = channel
                            showPlayer = true
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "暂无频道",
                    systemImage: "tv.slash",
                    description: Text("请先配置直播源")
                )
            }
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Channel Row
struct ChannelRow: View {
    let channel: LiveChannelItem
    let isSelected: Bool
    var currentProgram: EpgProgram?
    
    var body: some View {
        HStack(spacing: 12) {
            // 频道号
            Text(String(format: "%03d", channel.channelNum))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 36)
            
            // 频道信息
            VStack(alignment: .leading, spacing: 4) {
                // 频道名
                Text(channel.channelName)
                    .font(.body)
                    .foregroundColor(isSelected ? .blue : .primary)
                    .lineLimit(1)
                
                // 当前节目 (EPG)
                if let program = currentProgram {
                    HStack(spacing: 4) {
                        // 直播标记
                        if program.isLive {
                            Text("直播")
                                .font(.system(size: 9))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.red)
                                .cornerRadius(2)
                        }
                        
                        Text(program.title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // 进度条
                    if program.isLive {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .frame(height: 2)
                                
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: geo.size.width * program.progress, height: 2)
                            }
                        }
                        .frame(height: 2)
                    }
                }
            }
            
            Spacer()
            
            // 源数量
            if channel.channelUrls.count > 1 {
                Text("\(channel.channelUrls.count)源")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
    }
}

// MARK: - Live Player View
struct LivePlayerView: View {
    let channel: LiveChannelItem
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LivePlayerViewModel()
    @State private var showControls = true
    @State private var currentSourceIndex = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 视频播放器
            if let player = viewModel.player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showControls.toggle()
                        }
                    }
            } else if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
            
            // 控制层
            if showControls {
                VStack {
                    // 顶部栏
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                        }
                        
                        Text(channel.channelName)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // 切换源
                        if channel.channelUrls.count > 1 {
                            Menu {
                                ForEach(Array(channel.channelSourceNames.enumerated()), id: \.offset) { index, name in
                                    Button(action: {
                                        currentSourceIndex = index
                                        viewModel.loadChannel(url: channel.channelUrls[index])
                                    }) {
                                        HStack {
                                            Text(name)
                                            if index == currentSourceIndex {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Text(channel.channelSourceNames[currentSourceIndex])
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(6)
                            }
                            .padding(.trailing)
                        }
                    }
                    .padding(.top, 44)
                    .background(
                        LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom)
                    )
                    
                    Spacer()
                }
                .transition(.opacity)
            }
            
            // 错误提示
            if let error = viewModel.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                    
                    Text("播放失败")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    if channel.channelUrls.count > 1 && currentSourceIndex < channel.channelUrls.count - 1 {
                        Button("切换下一个源") {
                            currentSourceIndex += 1
                            viewModel.loadChannel(url: channel.channelUrls[currentSourceIndex])
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding()
            }
        }
        .statusBar(hidden: true)
        .onAppear {
            if !channel.channelUrls.isEmpty {
                viewModel.loadChannel(url: channel.channelUrls[currentSourceIndex])
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}

// MARK: - Live ViewModel
class LiveViewModel: ObservableObject {
    @Published var channelGroups: [LiveChannelGroup] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var currentPrograms: [String: EpgProgram] = [:] // 频道名 -> 当前节目
    
    private let apiConfig = ApiConfig.shared
    private let parserManager = LiveParserManager.shared
    private let epgManager = EpgManager.shared
    
    func loadChannels() {
        isLoading = true
        error = nil
        
        Task {
            do {
                let groups = try await fetchChannelGroups()
                await MainActor.run {
                    self.channelGroups = groups
                    self.isLoading = false
                }
                
                // 加载 EPG
                await loadEpg()
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    func refreshChannels() {
        channelGroups.removeAll()
        currentPrograms.removeAll()
        epgManager.clearCache()
        loadChannels()
    }
    
    /// 获取频道当前节目
    func getCurrentProgram(for channel: LiveChannelItem) -> EpgProgram? {
        return currentPrograms[channel.channelName] ?? epgManager.getCurrentProgram(for: channel.channelName)
    }
    
    /// 获取频道节目列表
    func getPrograms(for channel: LiveChannelItem) -> [EpgProgram] {
        return epgManager.getPrograms(for: channel.channelName)
    }
    
    private func fetchChannelGroups() async throws -> [LiveChannelGroup] {
        // 从直播配置加载频道列表
        let liveConfigs = apiConfig.liveConfigs
        
        guard !liveConfigs.isEmpty else {
            // 如果没有配置，返回空列表
            return []
        }
        
        var allGroups: [LiveChannelGroup] = []
        
        // 遍历所有直播源配置
        for config in liveConfigs {
            do {
                let groups = try await parserManager.loadFromConfig(config)
                allGroups.append(contentsOf: groups)
            } catch {
                print("加载直播源失败: \(config.name ?? "未知"): \(error)")
                // 继续加载其他源
            }
        }
        
        // 合并同名分组
        return mergeGroups(allGroups)
    }
    
    /// 加载 EPG 数据
    private func loadEpg() async {
        // 从直播配置获取 EPG URL
        for config in apiConfig.liveConfigs {
            if let epgUrl = config.epg, !epgUrl.isEmpty {
                do {
                    try await epgManager.loadEpg(from: epgUrl)
                    
                    // 更新当前节目
                    await updateCurrentPrograms()
                    
                    break // 只加载第一个有效的 EPG
                } catch {
                    print("加载 EPG 失败: \(error)")
                }
            }
        }
    }
    
    /// 更新所有频道的当前节目
    @MainActor
    private func updateCurrentPrograms() {
        var programs: [String: EpgProgram] = [:]
        
        for group in channelGroups {
            for channel in group.channels {
                if let program = epgManager.getCurrentProgram(for: channel.channelName) {
                    programs[channel.channelName] = program
                }
            }
        }
        
        currentPrograms = programs
    }
    
    /// 合并同名分组
    private func mergeGroups(_ groups: [LiveChannelGroup]) -> [LiveChannelGroup] {
        var mergedDict: [String: LiveChannelGroup] = [:]
        var order: [String] = []
        
        for group in groups {
            if mergedDict[group.groupName] != nil {
                // 合并频道
                mergedDict[group.groupName]?.channels.append(contentsOf: group.channels)
            } else {
                mergedDict[group.groupName] = group
                order.append(group.groupName)
            }
        }
        
        // 重新索引
        return order.enumerated().compactMap { index, name in
            guard var group = mergedDict[name] else { return nil }
            group.groupIndex = index
            group.channels = group.channels.enumerated().map { channelIndex, channel in
                var mutableChannel = channel
                mutableChannel.channelIndex = channelIndex
                mutableChannel.channelNum = channelIndex + 1
                return mutableChannel
            }
            return group
        }
    }
}

// MARK: - Live Player ViewModel
class LivePlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isLoading = false
    @Published var error: Error?
    
    func loadChannel(url: String) {
        isLoading = true
        error = nil
        
        guard let videoUrl = URL(string: url) else {
            error = NSError(domain: "LivePlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的播放地址"])
            isLoading = false
            return
        }
        
        cleanup()
        
        let playerItem = AVPlayerItem(url: videoUrl)
        player = AVPlayer(playerItem: playerItem)
        
        // 监听状态
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                self?.error = error
            }
        }
        
        player?.play()
        isLoading = false
    }
    
    func cleanup() {
        player?.pause()
        player = nil
    }
}

#Preview {
    NavigationView {
        LiveView()
    }
}

