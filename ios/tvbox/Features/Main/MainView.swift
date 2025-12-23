import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// 用于调试视图重绘次数
private class MainViewCounter {
    static var count = 0
}

private class HomeContentViewCounter {
    static var count = 0
}

struct MainView: View {
    @ObservedObject private var apiConfig = ApiConfig.shared
    @State private var selectedTab = 0
    @State private var showConfigSheet = false
    
    var body: some View {
        let _ = {
            MainViewCounter.count += 1
            print("[MainView] body #\(MainViewCounter.count)")
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
                print("[MainView] ConfigSetupView onComplete 被调用，开始加载配置")
                Task {
                    try? await apiConfig.loadConfig(useCache: false)
                    print("[MainView] 配置加载完成")
                }
            }
        }
        .task {
            print("[MainView] .task 开始执行")
            if !apiConfig.apiUrl.isEmpty {
                print("[MainView] apiUrl 不为空，开始加载配置")
                try? await apiConfig.loadConfig()
                print("[MainView] 配置加载完成")
            } else {
                print("[MainView] apiUrl 为空，显示配置 sheet")
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
        print("[ConfigSetupView] confirmConfig 开始")
        
        guard !apiUrl.isEmpty else {
            print("[ConfigSetupView] apiUrl 为空，返回")
            return
        }
        
        // 保存到本地变量
        let urlToSave = apiUrl
        let completion = onComplete
        
        // 设置加载状态
        isLoading = true
        
        // 使用 Task.detached 完全分离执行
        Task.detached(priority: .userInitiated) {
            print("[ConfigSetupView] 1. detached task 开始")
            
            // 在主线程上保存，通过 ApiConfig 的 setter 保存
            await MainActor.run {
                ApiConfig.shared.apiUrl = urlToSave
            }
            print("[ConfigSetupView] 2. URL 已保存: \(urlToSave)")
            
            // 回到主线程
            await MainActor.run {
                print("[ConfigSetupView] 3. 回到主线程，准备 dismiss")
                self.isLoading = false
                self.dismiss()
                print("[ConfigSetupView] 4. dismiss 已调用")
            }
            
            // 延迟执行加载配置
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                print("[ConfigSetupView] 5. 开始加载配置")
                completion()
            }
        }
    }
}

// MARK: - Home Content View
struct HomeContentView: View {
    @ObservedObject private var apiConfig = ApiConfig.shared
    @StateObject private var viewModel = HomeContentViewModel()
    
    var body: some View {
        let _ = {
            HomeContentViewCounter.count += 1
            print("[HomeContentView] body #\(HomeContentViewCounter.count)")
        }()
        
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 站点分类列表（如果有）
                    if !viewModel.categories.isEmpty {
                        siteCategorySection
                    }
                    
                    // 站点推荐内容（如果有）
                    if !viewModel.recommendMovies.isEmpty {
                        recommendSection
                    }
                    
                    // 豆瓣分类（当没有站点数据时显示）
                    if viewModel.categories.isEmpty && viewModel.recommendMovies.isEmpty && !viewModel.isLoading {
                        ForEach(viewModel.doubanCategories) { category in
                            DoubanCategoryRow(category: category)
                        }
                    }
                }
                .padding(.vertical)
            }
            
            // 加载状态指示器
            if viewModel.isLoading && viewModel.categories.isEmpty && viewModel.recommendMovies.isEmpty && viewModel.doubanCategories.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("加载中...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                siteSelector
            }
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
            print("[HomeContentView] onAppear 被调用")
            viewModel.loadData()
        }
        .onChange(of: apiConfig.currentSite?.key) { newValue in
            print("[HomeContentView] onChange currentSite: \(newValue ?? "nil")")
            viewModel.loadData()
        }
    }
    
    // MARK: - Site Selector
    private var siteSelector: some View {
        Menu {
            // 豆瓣热门选项
            Button {
                apiConfig.setDoubanHome()
            } label: {
                HStack {
                    Text("豆瓣热门")
                    if apiConfig.currentSite == nil {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()
            
            // 站点列表
            ForEach(apiConfig.filterableSites) { (site: SiteBean) in
                Button {
                    apiConfig.setCurrentSite(site)
                } label: {
                    HStack {
                        Text(site.name)
                        if apiConfig.currentSite?.key == site.key {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(apiConfig.currentSite?.name ?? "豆瓣热门")
                    .font(.headline)
                    .fontWeight(.semibold)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.primary)
        }
    }
    
    // MARK: - Site Category Section
    private var siteCategorySection: some View {
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

// MARK: - 豆瓣分类行（水平滚动卡片）
struct DoubanCategoryRow: View {
    let category: DoubanCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 分类标题
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundColor(.orange)
                
                Text(category.name)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                if category.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)
            
            // 水平滚动卡片列表
            if category.movies.isEmpty && !category.isLoading {
                // 空状态
                HStack {
                    Spacer()
                    Text("暂无数据")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Spacer()
                }
                .frame(height: 100)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(category.movies) { movie in
                            NavigationLink(destination: DetailView(movie: movie)) {
                                DoubanMovieCard(movie: movie)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - 豆瓣电影卡片（小尺寸，适合水平滚动）
struct DoubanMovieCard: View {
    let movie: MovieItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 封面
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(urlString: movie.vodPic)
                    .frame(width: 120, height: 160)
                    .clipped()
                
                // 评分标签
                if let remarks = movie.vodRemarks, !remarks.isEmpty {
                    Text(remarks)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(4)
                        .padding(6)
                }
            }
            
            // 标题
            Text(movie.vodName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 120, height: 36, alignment: .topLeading)
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Movie Card
struct MovieCard: View {
    let movie: MovieItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 封面
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(urlString: movie.vodPic)
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

// MARK: - Cached Async Image (支持自定义请求头)
struct CachedAsyncImage: View {
    let urlString: String?
    @State private var image: UIImage?
    @State private var isLoading = false
    
    // 内存缓存
    private static var imageCache = NSCache<NSString, UIImage>()
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderView
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private var placeholderView: some View {
        LinearGradient(
            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func loadImage() {
        guard let urlString = urlString, !urlString.isEmpty else { return }
        guard !isLoading else { return }
        
        // 检查缓存
        if let cached = Self.imageCache.object(forKey: urlString as NSString) {
            self.image = cached
            return
        }
        
        guard let url = URL(string: urlString) else { return }
        
        isLoading = true
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        
        // 添加豆瓣图片所需的请求头
        if urlString.contains("douban") {
            request.setValue(UA.shared.random(), forHTTPHeaderField: "User-Agent")
            request.setValue("https://www.douban.com/", forHTTPHeaderField: "Referer")
        } else {
            request.setValue(UA.shared.random(), forHTTPHeaderField: "User-Agent")
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let uiImage = UIImage(data: data) {
                    // 存入缓存
                    Self.imageCache.setObject(uiImage, forKey: urlString as NSString)
                    await MainActor.run {
                        self.image = uiImage
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            } catch {
                print("[CachedAsyncImage] 加载失败: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
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

// MARK: - 豆瓣分类数据
struct DoubanCategory: Identifiable {
    let id: String
    let name: String
    let icon: String
    let apiUrl: String  // 完整的 API URL
    var movies: [MovieItem] = []
    var isLoading: Bool = false
    
    static var allCategories: [DoubanCategory] {
        let year = Calendar.current.component(.year, from: Date())
        return [
            // 热门推荐 - 使用当年数据
            DoubanCategory(
                id: "hot",
                name: "热门推荐",
                icon: "flame.fill",
                apiUrl: "https://movie.douban.com/j/new_search_subjects?sort=U&range=0,10&tags=&playable=1&start=0&year_range=\(year),\(year)"
            ),
            // 热门电影 - 不限年份
            DoubanCategory(
                id: "movie",
                name: "热门电影",
                icon: "film.fill",
                apiUrl: "https://movie.douban.com/j/search_subjects?type=movie&tag=热门&page_limit=20&page_start=0"
            ),
            // 热门电视剧 - 不限年份
            DoubanCategory(
                id: "tv",
                name: "热门剧集",
                icon: "tv.fill",
                apiUrl: "https://movie.douban.com/j/search_subjects?type=tv&tag=热门&page_limit=20&page_start=0"
            ),
            // 高分电影
            DoubanCategory(
                id: "top_movie",
                name: "高分电影",
                icon: "star.fill",
                apiUrl: "https://movie.douban.com/j/search_subjects?type=movie&tag=豆瓣高分&page_limit=20&page_start=0"
            ),
            // 国产剧
            DoubanCategory(
                id: "cn_tv",
                name: "国产剧",
                icon: "play.tv.fill",
                apiUrl: "https://movie.douban.com/j/search_subjects?type=tv&tag=国产剧&page_limit=20&page_start=0"
            ),
            // 综艺
            DoubanCategory(
                id: "variety",
                name: "综艺节目",
                icon: "music.mic",
                apiUrl: "https://movie.douban.com/j/search_subjects?type=tv&tag=综艺&page_limit=20&page_start=0"
            ),
        ]
    }
}

// MARK: - Home Content ViewModel
class HomeContentViewModel: ObservableObject {
    @Published var categories: [MovieCategory] = []
    @Published var recommendMovies: [MovieItem] = []
    @Published var doubanCategories: [DoubanCategory] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let spiderManager = SpiderManager.shared
    private let apiConfig = ApiConfig.shared
    
    // 豆瓣缓存
    private static var doubanCache: [String: [MovieItem]] = [:]
    private static var doubanCacheDate: String = ""
    
    func loadData() {
        print("[HomeContentViewModel] loadData 被调用, currentSite: \(apiConfig.currentSite?.name ?? "nil")")
        
        // 切换站点时清除旧数据
        categories = []
        recommendMovies = []
        doubanCategories = []
        error = nil
        
        guard apiConfig.currentSite != nil else {
            print("[HomeContentViewModel] 没有当前站点，加载豆瓣分类")
            loadDoubanCategories()
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let content = try await spiderManager.homeContent(filter: true)
                await MainActor.run {
                    self.categories = content.categories
                    self.recommendMovies = content.videos
                    self.isLoading = false
                    self.error = nil
                    print("[HomeContentViewModel] 加载成功: \(content.categories.count) 分类, \(content.videos.count) 视频")
                    
                    // 如果没有推荐视频，尝试加载豆瓣分类
                    if content.videos.isEmpty && self.categories.isEmpty {
                        self.loadDoubanCategories()
                    }
                }
            } catch {
                print("[HomeContentViewModel] 加载失败: \(error)")
                await MainActor.run {
                    self.categories = []
                    self.recommendMovies = []
                    self.error = error
                    self.isLoading = false
                    // 加载失败时显示豆瓣分类
                    self.loadDoubanCategories()
                }
            }
        }
    }
    
    func refresh() async {
        print("[HomeContentViewModel] refresh 被调用")
        await MainActor.run {
            self.categories = []
            self.recommendMovies = []
            self.doubanCategories = []
        }
        // 清除缓存
        Self.doubanCache.removeAll()
        Self.doubanCacheDate = ""
        loadData()
    }
    
    // MARK: - 豆瓣分类
    
    /// 加载所有豆瓣分类
    private func loadDoubanCategories() {
        print("[HomeContentViewModel] 开始加载豆瓣分类")
        
        // 初始化分类
        doubanCategories = DoubanCategory.allCategories
        
        // 检查缓存
        let today = todayString()
        if Self.doubanCacheDate == today && !Self.doubanCache.isEmpty {
            print("[HomeContentViewModel] 使用豆瓣缓存")
            for i in 0..<doubanCategories.count {
                if let cached = Self.doubanCache[doubanCategories[i].id] {
                    doubanCategories[i].movies = cached
                }
            }
            return
        }
        
        // 并行加载所有分类
        for i in 0..<doubanCategories.count {
            loadDoubanCategory(index: i)
        }
    }
    
    /// 加载单个豆瓣分类
    private func loadDoubanCategory(index: Int) {
        guard index < doubanCategories.count else { return }
        
        let category = doubanCategories[index]
        
        // 手动编码中文字符，保留 URL 结构字符
        let urlString = category.apiUrl
            .replacingOccurrences(of: "热门", with: "%E7%83%AD%E9%97%A8")
            .replacingOccurrences(of: "豆瓣高分", with: "%E8%B1%86%E7%93%A3%E9%AB%98%E5%88%86")
            .replacingOccurrences(of: "国产剧", with: "%E5%9B%BD%E4%BA%A7%E5%89%A7")
            .replacingOccurrences(of: "综艺", with: "%E7%BB%BC%E8%89%BA")
        
        guard let url = URL(string: urlString) else {
            print("[HomeContentViewModel] 豆瓣分类[\(category.name)] URL无效: \(urlString)")
            return
        }
        
        // 设置加载状态
        DispatchQueue.main.async {
            self.doubanCategories[index].isLoading = true
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(UA.shared.random(), forHTTPHeaderField: "User-Agent")
        request.setValue("https://movie.douban.com/", forHTTPHeaderField: "Referer")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        
        Task {
            do {
                print("[HomeContentViewModel] 请求豆瓣分类[\(category.name)]: \(url.absoluteString)")
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("[HomeContentViewModel] 豆瓣分类[\(category.name)] 响应状态: \(httpResponse.statusCode)")
                }
                
                let movies = parseDoubanResponse(data: data)
                
                await MainActor.run {
                    guard index < self.doubanCategories.count else { return }
                    self.doubanCategories[index].movies = movies
                    self.doubanCategories[index].isLoading = false
                    
                    // 缓存
                    Self.doubanCache[category.id] = movies
                    Self.doubanCacheDate = self.todayString()
                    
                    print("[HomeContentViewModel] 豆瓣分类[\(category.name)]加载成功: \(movies.count) 条")
                }
            } catch {
                print("[HomeContentViewModel] 豆瓣分类[\(category.name)]加载失败: \(error)")
                await MainActor.run {
                    guard index < self.doubanCategories.count else { return }
                    self.doubanCategories[index].isLoading = false
                }
            }
        }
    }
    
    /// 解析豆瓣返回数据 - 支持两种 API 格式
    private func parseDoubanResponse(data: Data) -> [MovieItem] {
        var movies: [MovieItem] = []
        
        // 打印原始数据用于调试
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[HomeContentViewModel] 豆瓣响应数据: \(jsonString.prefix(500))...")
        }
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("[HomeContentViewModel] 解析JSON失败")
                return movies
            }
            
            // 尝试两种 API 格式
            // 格式1: new_search_subjects 返回 { "data": [...] }
            // 格式2: search_subjects 返回 { "subjects": [...] }
            var dataArray: [[String: Any]] = []
            
            if let data = json["data"] as? [[String: Any]] {
                dataArray = data
            } else if let subjects = json["subjects"] as? [[String: Any]] {
                dataArray = subjects
            }
            
            for item in dataArray {
                // 标题字段可能是 "title" 或在不同位置
                let title = item["title"] as? String ?? ""
                guard !title.isEmpty else { continue }
                
                // 评分字段可能是 "rate" 或 "rating" 对象
                var rate = ""
                if let rateStr = item["rate"] as? String {
                    rate = rateStr
                } else if let ratingDict = item["rating"] as? [String: Any],
                          let average = ratingDict["average"] as? Double {
                    rate = String(format: "%.1f", average)
                }
                
                // 图片字段可能是 "cover" 或 "cover_url"
                let cover = item["cover"] as? String ?? item["cover_url"] as? String ?? ""
                
                let movie = MovieItem(
                    vodId: "douban_\(title.hashValue)",
                    vodName: title,
                    vodPic: cover,
                    vodRemarks: rate.isEmpty || rate == "0" || rate == "0.0" ? nil : "⭐ \(rate)"
                )
                movies.append(movie)
            }
        } catch {
            print("[HomeContentViewModel] 解析豆瓣数据异常: \(error)")
        }
        
        return movies
    }
    
    /// 获取今天日期字符串
    private func todayString() -> String {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let month = cal.component(.month, from: Date())
        let day = cal.component(.day, from: Date())
        return "\(year)\(month)\(day)"
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
