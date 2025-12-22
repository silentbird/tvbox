import SwiftUI

struct MainView: View {
    @StateObject private var apiConfig = ApiConfig.shared
    @State private var selectedTab = 0
    @State private var showConfigSheet = false
    
    var body: some View {
        Group {
            if apiConfig.configLoaded {
                mainTabView
            } else {
                welcomeView
            }
        }
        .sheet(isPresented: $showConfigSheet) {
            ConfigSetupView {
                Task {
                    try? await apiConfig.loadConfig()
                }
            }
        }
        .task {
            if !apiConfig.apiUrl.isEmpty {
                try? await apiConfig.loadConfig()
            } else {
                showConfigSheet = true
            }
        }
    }
    
    // MARK: - Main Tab View
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                HomeContentView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("首页", systemImage: "house.fill")
            }
            .tag(0)
            
            NavigationView {
                LiveView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("直播", systemImage: "play.tv.fill")
            }
            .tag(1)
            
            NavigationView {
                SearchView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("搜索", systemImage: "magnifyingglass")
            }
            .tag(2)
            
            NavigationView {
                MineView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("我的", systemImage: "person.fill")
            }
            .tag(3)
        }
    }
    
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

// MARK: - Config Setup View
struct ConfigSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiUrl: String = ""
    @State private var isLoading = false
    @State private var error: String?
    
    let onComplete: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 说明
                VStack(spacing: 8) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("配置数据源")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("请输入配置地址以开始使用")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // 输入框
                VStack(alignment: .leading, spacing: 8) {
                    Text("配置地址")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("http://example.com/config.json", text: $apiUrl)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal)
                
                // 错误提示
                if let error = error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                // 示例配置
                VStack(alignment: .leading, spacing: 8) {
                    Text("示例格式:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("http://example.com/config.json")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .onTapGesture {
                            // 可以添加复制功能
                        }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                Spacer()
                
                // 确认按钮
                Button(action: confirmConfig) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("确认")
                        }
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(apiUrl.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(apiUrl.isEmpty || isLoading)
                .padding()
            }
            .navigationTitle("初始配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func confirmConfig() {
        guard !apiUrl.isEmpty else { return }
        
        isLoading = true
        error = nil
        
        ApiConfig.shared.apiUrl = apiUrl
        
        Task {
            do {
                try await ApiConfig.shared.loadConfig(useCache: false)
                await MainActor.run {
                    isLoading = false
                    onComplete()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Home Content View
struct HomeContentView: View {
    @ObservedObject private var apiConfig = ApiConfig.shared
    @StateObject private var viewModel = HomeContentViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 站点选择器
                if apiConfig.filterableSites.count > 1 {
                    siteSelector
                }
                
                // 分类列表
                if !viewModel.categories.isEmpty {
                    categorySection
                }
                
                // 推荐内容
                if !viewModel.recommendMovies.isEmpty {
                    recommendSection
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(apiConfig.currentSite?.name ?? "首页")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: SearchView()) {
                    Image(systemName: "magnifyingglass")
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .onAppear {
            viewModel.loadData()
        }
        .onChange(of: apiConfig.currentSite?.key) { _ in
            viewModel.loadData()
        }
    }
    
    // MARK: - Site Selector
    private var siteSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(apiConfig.filterableSites) { site in
                    Button(action: { apiConfig.setCurrentSite(site) }) {
                        Text(site.name)
                            .font(.subheadline)
                            .fontWeight(apiConfig.currentSite?.key == site.key ? .semibold : .regular)
                            .foregroundColor(apiConfig.currentSite?.key == site.key ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(apiConfig.currentSite?.key == site.key ? Color.blue : Color(.systemGray5))
                            .cornerRadius(18)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Category Section
    private var categorySection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.categories) { category in
                    NavigationLink(destination: CategoryDetailView(category: category)) {
                        VStack(spacing: 6) {
                            Image(systemName: categoryIcon(for: category.name))
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            Text(category.name)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .frame(width: 70, height: 70)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Recommend Section
    private var recommendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("推荐")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(viewModel.recommendMovies) { movie in
                    NavigationLink(destination: DetailView(movie: movie)) {
                        MovieCard(movie: movie)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func categoryIcon(for name: String) -> String {
        switch name {
        case let n where n.contains("电影"): return "film"
        case let n where n.contains("电视") || n.contains("连续剧"): return "tv"
        case let n where n.contains("动漫") || n.contains("动画"): return "sparkles.tv"
        case let n where n.contains("综艺"): return "music.mic"
        case let n where n.contains("纪录"): return "doc.text.image"
        default: return "play.rectangle"
        }
    }
}

// MARK: - Movie Card
struct MovieCard: View {
    let movie: MovieItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 封面
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: movie.vodPic ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .frame(height: 180)
                .clipped()
                
                // 备注标签
                if let remarks = movie.vodRemarks, !remarks.isEmpty {
                    Text(remarks)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.9))
                        .cornerRadius(4)
                        .padding(6)
                }
            }
            
            // 标题
            Text(movie.vodName)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Category Detail View
struct CategoryDetailView: View {
    let category: MovieCategory
    @StateObject private var viewModel = CategoryDetailViewModel()
    
    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 12)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.movies) { movie in
                    NavigationLink(destination: DetailView(movie: movie)) {
                        MovieCard(movie: movie)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(category.name)
        .onAppear {
            viewModel.loadMovies(categoryId: category.tid)
        }
    }
}

class CategoryDetailViewModel: ObservableObject {
    @Published var movies: [MovieItem] = []
    @Published var isLoading = false
    
    func loadMovies(categoryId: String) {
        // TODO: 从 Spider 加载分类数据
    }
}

// MARK: - Home Content ViewModel
class HomeContentViewModel: ObservableObject {
    @Published var categories: [MovieCategory] = []
    @Published var recommendMovies: [MovieItem] = []
    @Published var isLoading = false
    
    func loadData() {
        // TODO: 从 Spider 加载首页数据
    }
    
    func refresh() async {
        // TODO: 刷新数据
    }
}

// MARK: - Mine View
struct MineView: View {
    @ObservedObject private var apiConfig = ApiConfig.shared
    private let storageManager = StorageManager.shared
    
    var body: some View {
        List {
            // 用户区域
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TVBox 用户")
                            .font(.headline)
                        
                        Text(apiConfig.currentSite?.name ?? "未配置数据源")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            // 功能入口
            Section {
                NavigationLink(destination: HistoryView()) {
                    Label("观看历史", systemImage: "clock.arrow.circlepath")
                }
                
                NavigationLink(destination: CollectView()) {
                    Label("我的收藏", systemImage: "heart")
                }
            }
            
            // 设置
            Section {
                NavigationLink(destination: SettingsView()) {
                    Label("设置", systemImage: "gear")
                }
            }
        }
        .navigationTitle("我的")
    }
}

#Preview {
    MainView()
}
