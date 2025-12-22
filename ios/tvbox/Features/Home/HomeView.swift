import SwiftUI

struct HomeView: View {
    @ObservedObject private var apiConfig = ApiConfig.shared
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedCategory: MovieCategory?
    
    var body: some View {
        NavigationView {
            Group {
                if apiConfig.configLoaded {
                    contentView
                } else if apiConfig.isLoading {
                    loadingView
                } else {
                    emptyView
                }
            }
            .navigationTitle(apiConfig.currentSite?.name ?? "首页")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SearchView()) {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .toast(message: viewModel.toastMessage, isShowing: $viewModel.showToast)
        .onAppear {
            if apiConfig.configLoaded {
                viewModel.loadCategories()
            }
        }
        .onChange(of: apiConfig.currentSite?.key) { _ in
            viewModel.loadCategories()
        }
    }
    
    // MARK: - Content View
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 站点选择器
                if apiConfig.filterableSites.count > 1 {
                    siteSelector
                }
                
                // 分类列表
                if !viewModel.categories.isEmpty {
                    categoryGrid
                }
                
                // 推荐内容
                if !viewModel.videos.isEmpty {
                    recommendSection
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            viewModel.loadCategories()
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
    
    // MARK: - Category Grid
    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分类")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.categories) { category in
                        NavigationLink(destination: CategoryListView(category: category, viewModel: viewModel)) {
                            VStack(spacing: 6) {
                                Image(systemName: categoryIcon(for: category.name))
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                
                                Text(category.name)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
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
    }
    
    // MARK: - Recommend Section
    private var recommendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("推荐")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(viewModel.videos) { movie in
                    NavigationLink(destination: DetailView(movie: movie)) {
                        MovieItemCard(movie: movie)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("加载中...")
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        ContentUnavailableView(
            "未配置数据源",
            systemImage: "exclamationmark.triangle",
            description: Text("请在设置中配置API地址")
        )
    }
    
    // MARK: - Helper
    private func categoryIcon(for name: String) -> String {
        switch name {
        case let n where n.contains("电影"): return "film"
        case let n where n.contains("电视") || n.contains("连续剧") || n.contains("剧集"): return "tv"
        case let n where n.contains("动漫") || n.contains("动画"): return "sparkles.tv"
        case let n where n.contains("综艺"): return "music.mic"
        case let n where n.contains("纪录"): return "doc.text.image"
        case let n where n.contains("体育"): return "sportscourt"
        case let n where n.contains("音乐"): return "music.note"
        default: return "play.rectangle"
        }
    }
}

// MARK: - Movie Item Card
struct MovieItemCard: View {
    let movie: MovieItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 封面
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: movie.vodPic ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholderImage
                    case .empty:
                        placeholderImage
                    @unknown default:
                        placeholderImage
                    }
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
    
    private var placeholderImage: some View {
        LinearGradient(
            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Category List View
struct CategoryListView: View {
    let category: MovieCategory
    @ObservedObject var viewModel: HomeViewModel
    
    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 12)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.categoryVideos) { movie in
                    NavigationLink(destination: DetailView(movie: movie)) {
                        MovieItemCard(movie: movie)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(category.name)
        .onAppear {
            viewModel.loadVideos(for: category)
        }
    }
}

#Preview {
    HomeView()
}
