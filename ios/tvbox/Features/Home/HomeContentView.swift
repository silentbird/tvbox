import SwiftUI

private class HomeContentViewCounter {
    static var count = 0
}

struct HomeContentView: View {
    @ObservedObject private var apiConfig = ApiConfig.shared
    @StateObject private var viewModel = HomeContentViewModel()
    @Environment(\.tvboxWideLayout) private var isWideLayout
    /// 宽布局下当前选中的分类，nil 表示「首页」推荐
    @State private var selectedCategory: MovieCategory?

    var body: some View {
        let _ = {
            HomeContentViewCounter.count += 1
            AppLogger.debug("[HomeContentView] body #\(HomeContentViewCounter.count)")
        }()

        Group {
            if isWideLayout {
                wideBody
            } else {
                narrowBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.tvboxSystemGroupedBackground.ignoresSafeArea())
        .tvboxHiddenNavigationBar()
        .refreshable {
            await viewModel.refresh()
        }
        .onAppear {
            AppLogger.debug("[HomeContentView] onAppear 被调用")
            viewModel.loadData()
        }
        .onChange(of: apiConfig.currentSite?.key) { _, newValue in
            AppLogger.debug("[HomeContentView] onChange currentSite: \(newValue ?? "nil")")
            selectedCategory = nil
            viewModel.loadData()
        }
    }

    private var narrowBody: some View {
        ZStack {
            ScrollView {
                homeSections
                    .padding(.top, 82)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            loadingState
        }
        .overlay(alignment: .top) {
            homeTopBar
        }
    }

    // 对应 Android HomeActivity: 顶部一行分类，下面原地显示选中分类的内容
    private var wideBody: some View {
        VStack(spacing: 0) {
            wideCategoryBar

            Divider()

            if let category = selectedCategory {
                CategoryDetailView(category: category)
                    .id(category.tid)
            } else {
                ZStack {
                    ScrollView {
                        homeSections
                            .padding(.vertical)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    loadingState
                }
            }
        }
    }

    private var homeSections: some View {
        VStack(spacing: 20) {
            if let error = viewModel.error {
                unsupportedState(error)
            }

            // 宽布局的分类在顶部标签栏里
            if !viewModel.categories.isEmpty && !isWideLayout {
                siteCategorySection
            }

            if !viewModel.recommendMovies.isEmpty {
                recommendSection
            }

            if viewModel.categories.isEmpty && viewModel.recommendMovies.isEmpty && viewModel.error == nil && !viewModel.isLoading {
                ForEach(viewModel.doubanCategories) { category in
                    DoubanCategoryRow(category: category)
                }
            }
        }
    }

    @ViewBuilder
    private var loadingState: some View {
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

    private var wideCategoryBar: some View {
        HStack(spacing: 12) {
            siteSelector

            Divider()
                .frame(height: 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    categoryTab(title: "首页", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }

                    ForEach(viewModel.categories) { category in
                        categoryTab(title: category.name, isSelected: selectedCategory == category) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func categoryTab(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.clear)
                .cornerRadius(8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var homeTopBar: some View {
        HStack(spacing: 12) {
            siteSelector

            Spacer(minLength: 12)

            NavigationLink(destination: SearchView()) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 38, height: 38)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("搜索")
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: 620)
        .background {
            topGlassBackground
        }
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 18, x: 0, y: 8)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var topGlassBackground: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Capsule()
                .fill(Color.white.opacity(0.10))
                .glassEffect(.regular.tint(Color.white.opacity(0.12)).interactive(), in: Capsule())
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .background {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                }
        }
    }

    private var siteSelector: some View {
        Menu {
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

            ForEach(apiConfig.homeSites) { (site: SiteBean) in
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
        // macOS 默认画成带边框和系统箭头的弹出按钮
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

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
                        .background(Color.tvboxSystemGray6)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

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
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private func unsupportedState(_ error: Error) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.orange)

            Text(apiConfig.currentSite?.name ?? "当前站点")
                .font(.headline)
                .foregroundColor(.primary)

            Text(AppErrorMessage.userMessage(for: error))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.tvboxSystemGray6)
        .cornerRadius(12)
        .padding(.horizontal)
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
