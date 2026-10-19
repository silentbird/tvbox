import SwiftUI

// 用于调试视图重绘次数
private class MainViewCounter {
    static var count = 0
}

struct MainView: View {
    @ObservedObject private var apiConfig = ApiConfig.shared
    @State private var selectedTab = 0
    @State private var sidebarSelection: SidebarItem? = .home
    @State private var isWideLayout = false
    @State private var showConfigSheet = false

    var body: some View {
        let _ = {
            MainViewCounter.count += 1
            AppLogger.debug("[MainView] body #\(MainViewCounter.count)")
        }()

        Group {
            if apiConfig.configLoaded {
                if isWideLayout {
                    mainSidebarView
                } else {
                    mainTabView
                }
            } else {
                welcomeView
            }
        }
        .onGeometryChange(for: Bool.self) { proxy in
            TVBoxLayout.isWide(width: proxy.size.width)
        } action: { isWide in
            isWideLayout = isWide
        }
        .environment(\.tvboxWideLayout, isWideLayout)
        .tvboxWindowCoverHost()
        .sheet(isPresented: $showConfigSheet) {
            ConfigSetupView {
                AppLogger.debug("[MainView] ConfigSetupView onComplete 被调用，开始加载配置")
                Task {
                    try? await apiConfig.loadConfig(useCache: false)
                    AppLogger.debug("[MainView] 配置加载完成")
                }
            }
            .tvboxConfigSheetSize()
        }
        .task {
            AppLogger.debug("[MainView] .task 开始执行")
            if !apiConfig.apiUrl.isEmpty {
                AppLogger.debug("[MainView] apiUrl 不为空，开始加载配置")
                try? await apiConfig.loadConfig()
                AppLogger.debug("[MainView] 配置加载完成")
            } else {
                AppLogger.debug("[MainView] apiUrl 为空，显示配置 sheet")
                showConfigSheet = true
            }
        }
    }
    
    // MARK: - Main Tab View
    private var mainTabView: some View {
        ZStack(alignment: .bottom) {
            selectedTabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.tvboxSystemGroupedBackground.ignoresSafeArea())
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 86)
                }
            
            FloatingTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case 0:
            NavigationStack {
                HomeContentView()
            }
        case 1:
            NavigationStack {
                LiveView()
            }
        case 2:
            NavigationStack {
                SearchView()
            }
        default:
            NavigationStack {
                MineView()
            }
        }
    }

    // MARK: - Sidebar View
    // 宽窗口下对应 Android 首页「我的」那排入口，用侧边栏代替底部 Tab
    private var mainSidebarView: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, id: \.self, selection: $sidebarSelection) { item in
                Label(item.title, systemImage: item.systemImage)
            }
            .navigationTitle("TVBox")
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            sidebarContent
        }
    }

    @ViewBuilder
    private var sidebarContent: some View {
        switch sidebarSelection ?? .home {
        case .home:
            NavigationStack {
                HomeContentView()
            }
        case .live:
            NavigationStack {
                LiveView()
            }
        case .search:
            NavigationStack {
                SearchView()
            }
        case .history:
            NavigationStack {
                HistoryView()
            }
        case .collect:
            NavigationStack {
                CollectView()
            }
        case .settings:
            NavigationStack {
                SettingsView()
            }
        }
    }
}

private enum SidebarItem: Hashable, CaseIterable {
    case home, live, search, history, collect, settings

    var title: String {
        switch self {
        case .home: return "首页"
        case .live: return "直播"
        case .search: return "搜索"
        case .history: return "观看历史"
        case .collect: return "我的收藏"
        case .settings: return "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .live: return "play.tv"
        case .search: return "magnifyingglass"
        case .history: return "clock.arrow.circlepath"
        case .collect: return "heart"
        case .settings: return "gear"
        }
    }
}

extension MainView {
    // MARK: - Welcome View
    private var welcomeView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "tv")
                .font(.system(size: 100))
                .foregroundColor(.blue)
            
            Text("TVBox")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("开源影视聚合播放器")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if apiConfig.isLoading {
                ProgressView("加载配置中...")
            } else {
                if let error = apiConfig.error {
                    VStack(spacing: 12) {
                        Text("配置加载失败：\(AppErrorMessage.userMessage(for: error))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button("重试") {
                            Task {
                                try? await apiConfig.loadConfig()
                            }
                        }
                    }
                }

                Button(action: { showConfigSheet = true }) {
                    Text(apiConfig.error == nil ? "配置数据源" : "更换配置")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }
            
            Spacer()
                .frame(height: 50)
        }
    }
}

#if !targetEnvironment(macCatalyst)
#Preview {
    MainView()
}
#endif
