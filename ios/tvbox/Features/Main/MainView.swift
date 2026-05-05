import SwiftUI

// 用于调试视图重绘次数
private class MainViewCounter {
    static var count = 0
}

struct MainView: View {
    @ObservedObject private var apiConfig = ApiConfig.shared
    @State private var selectedTab = 0
    @State private var showConfigSheet = false
    
    var body: some View {
        let _ = {
            MainViewCounter.count += 1
            AppLogger.debug("[MainView] body #\(MainViewCounter.count)")
        }()
        
        Group {
            if apiConfig.configLoaded {
                mainTabView
            } else {
                welcomeView
            }
        }
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
                Button(action: { showConfigSheet = true }) {
                    Text("配置数据源")
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
