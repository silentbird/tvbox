import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showApiInput = false
    @State private var showLiveApiInput = false
    @State private var showSiteSelector = false
    @State private var showParseSelector = false
    @State private var showAbout = false
    @State private var showClearCacheAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // 配置管理
                configSection
                
                // 播放设置
                playbackSection
                
                // 数据管理
                dataSection
                
                // 关于
                aboutSection
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showApiInput) {
                ApiInputView(
                    title: "配置地址",
                    placeholder: "请输入配置地址",
                    currentValue: viewModel.apiUrl
                ) { url in
                    viewModel.updateApiUrl(url)
                }
            }
            .sheet(isPresented: $showLiveApiInput) {
                ApiInputView(
                    title: "直播地址",
                    placeholder: "请输入直播配置地址",
                    currentValue: viewModel.liveApiUrl
                ) { url in
                    viewModel.updateLiveApiUrl(url)
                }
            }
            .sheet(isPresented: $showSiteSelector) {
                SiteSelectorView()
            }
            .sheet(isPresented: $showParseSelector) {
                ParseSelectorView()
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .alert("清除缓存", isPresented: $showClearCacheAlert) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) {
                    viewModel.clearCache()
                }
            } message: {
                Text("确定要清除所有缓存数据吗？")
            }
        }
    }
    
    // MARK: - Config Section
    private var configSection: some View {
        Section {
            // 配置地址
            Button(action: { showApiInput = true }) {
                HStack {
                    Label("配置地址", systemImage: "link")
                    Spacer()
                    Text(viewModel.apiUrl.isEmpty ? "未配置" : "已配置")
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            
            // 直播地址
            Button(action: { showLiveApiInput = true }) {
                HStack {
                    Label("直播地址", systemImage: "play.tv")
                    Spacer()
                    Text(viewModel.liveApiUrl.isEmpty ? "未配置" : "已配置")
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            
            // 当前站点
            Button(action: { showSiteSelector = true }) {
                HStack {
                    Label("当前站点", systemImage: "globe")
                    Spacer()
                    Text(viewModel.currentSiteName)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            
            // 默认解析
            Button(action: { showParseSelector = true }) {
                HStack {
                    Label("默认解析", systemImage: "wand.and.rays")
                    Spacer()
                    Text(viewModel.defaultParseName)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            
            // 刷新配置
            Button(action: { viewModel.refreshConfig() }) {
                HStack {
                    Label("刷新配置", systemImage: "arrow.clockwise")
                    Spacer()
                    if viewModel.isRefreshing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .foregroundColor(.primary)
            .disabled(viewModel.isRefreshing)
        } header: {
            Text("配置管理")
        }
    }
    
    // MARK: - Playback Section
    private var playbackSection: some View {
        Section {
            // 播放器类型
            Picker(selection: $viewModel.playerType) {
                Text("系统播放器").tag(0)
                Text("AVPlayer").tag(1)
            } label: {
                Label("播放器", systemImage: "play.rectangle")
            }
            
            // 默认画质
            Picker(selection: $viewModel.defaultQuality) {
                Text("自动").tag(0)
                Text("1080P").tag(1)
                Text("720P").tag(2)
                Text("480P").tag(3)
            } label: {
                Label("默认画质", systemImage: "slider.horizontal.3")
            }
            
            // 后台播放
            Toggle(isOn: $viewModel.backgroundPlay) {
                Label("后台播放", systemImage: "speaker.wave.2")
            }
            
            // 自动下一集
            Toggle(isOn: $viewModel.autoPlayNext) {
                Label("自动下一集", systemImage: "forward.end")
            }
        } header: {
            Text("播放设置")
        }
    }
    
    // MARK: - Data Section
    private var dataSection: some View {
        Section {
            // 观看历史
            NavigationLink(destination: HistoryView()) {
                HStack {
                    Label("观看历史", systemImage: "clock.arrow.circlepath")
                    Spacer()
                    Text("\(viewModel.historyCount)条")
                        .foregroundColor(.secondary)
                }
            }
            
            // 我的收藏
            NavigationLink(destination: CollectView()) {
                HStack {
                    Label("我的收藏", systemImage: "heart")
                    Spacer()
                    Text("\(viewModel.collectCount)个")
                        .foregroundColor(.secondary)
                }
            }
            
            // 清除缓存
            Button(action: { showClearCacheAlert = true }) {
                HStack {
                    Label("清除缓存", systemImage: "trash")
                    Spacer()
                    Text(viewModel.cacheSize)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
        } header: {
            Text("数据管理")
        }
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
        Section {
            Button(action: { showAbout = true }) {
                HStack {
                    Label("关于", systemImage: "info.circle")
                    Spacer()
                    Text("v\(viewModel.appVersion)")
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
        }
    }
}

// MARK: - API Input View
struct ApiInputView: View {
    let title: String
    let placeholder: String
    let currentValue: String
    let onSave: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var inputText: String = ""
    @State private var showScanner = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 输入框
                VStack(alignment: .leading, spacing: 8) {
                    Text("请输入配置地址")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField(placeholder, text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                .padding()
                
                // 扫码按钮
                Button(action: { showScanner = true }) {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                        Text("扫码输入")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // 确认按钮
                Button(action: {
                    onSave(inputText)
                    dismiss()
                }) {
                    Text("确认")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
                .disabled(inputText.isEmpty)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                inputText = currentValue
            }
        }
    }
}

// MARK: - Site Selector View
struct SiteSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var apiConfig = ApiConfig.shared
    
    var body: some View {
        NavigationView {
            List {
                ForEach(apiConfig.filterableSites) { site in
                    Button(action: {
                        apiConfig.setCurrentSite(site)
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(site.name)
                                    .foregroundColor(.primary)
                                
                                Text(site.api)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            if apiConfig.currentSite?.key == site.key {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择站点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Parse Selector View
struct ParseSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var apiConfig = ApiConfig.shared
    
    var body: some View {
        NavigationView {
            List {
                ForEach(apiConfig.parses) { parse in
                    Button(action: {
                        apiConfig.setDefaultParse(parse)
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(parse.name)
                                    .foregroundColor(.primary)
                                
                                Text(parse.url)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            if apiConfig.defaultParse?.name == parse.name {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择解析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // Logo
                Image(systemName: "tv")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                // App Name
                Text("TVBox")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Version
                Text("版本 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Description
                Text("一个开源的影视聚合播放器")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                // Links
                VStack(spacing: 12) {
                    Link(destination: URL(string: "https://github.com")!) {
                        HStack {
                            Image(systemName: "link")
                            Text("GitHub 仓库")
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Settings ViewModel
class SettingsViewModel: ObservableObject {
    @Published var apiUrl: String = ""
    @Published var liveApiUrl: String = ""
    @Published var currentSiteName: String = "未选择"
    @Published var defaultParseName: String = "未选择"
    @Published var isRefreshing = false
    
    @Published var playerType: Int = 0
    @Published var defaultQuality: Int = 0
    @Published var backgroundPlay: Bool = false
    @Published var autoPlayNext: Bool = true
    
    @Published var historyCount: Int = 0
    @Published var collectCount: Int = 0
    @Published var cacheSize: String = "0 MB"
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private let apiConfig = ApiConfig.shared
    private let storageManager = StorageManager.shared
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadSettings()
    }
    
    func loadSettings() {
        apiUrl = apiConfig.apiUrl
        liveApiUrl = apiConfig.liveApiUrl
        currentSiteName = apiConfig.currentSite?.name ?? "未选择"
        defaultParseName = apiConfig.defaultParse?.name ?? "未选择"
        
        historyCount = storageManager.getVodHistory().count
        collectCount = storageManager.getCollects().count
        calculateCacheSize()
        
        // 播放设置
        playerType = userDefaults.integer(forKey: "player_type")
        defaultQuality = userDefaults.integer(forKey: "default_quality")
        backgroundPlay = userDefaults.bool(forKey: "background_play")
        autoPlayNext = userDefaults.object(forKey: "auto_play_next") as? Bool ?? true
    }
    
    func updateApiUrl(_ url: String) {
        apiConfig.apiUrl = url
        apiUrl = url
        refreshConfig()
    }
    
    func updateLiveApiUrl(_ url: String) {
        apiConfig.liveApiUrl = url
        liveApiUrl = url
    }
    
    func refreshConfig() {
        isRefreshing = true
        
        Task {
            do {
                try await apiConfig.loadConfig(useCache: false)
                await MainActor.run {
                    self.currentSiteName = apiConfig.currentSite?.name ?? "未选择"
                    self.defaultParseName = apiConfig.defaultParse?.name ?? "未选择"
                    self.isRefreshing = false
                }
            } catch {
                await MainActor.run {
                    self.isRefreshing = false
                }
            }
        }
    }
    
    func clearCache() {
        // 清除 URLCache
        URLCache.shared.removeAllCachedResponses()
        
        // 清除临时文件
        let tempDirectory = FileManager.default.temporaryDirectory
        try? FileManager.default.removeItem(at: tempDirectory)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        calculateCacheSize()
    }
    
    private func calculateCacheSize() {
        let urlCacheSize = URLCache.shared.currentDiskUsage + URLCache.shared.currentMemoryUsage
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        cacheSize = formatter.string(fromByteCount: Int64(urlCacheSize))
    }
}

#Preview {
    SettingsView()
}
