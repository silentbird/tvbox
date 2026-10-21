import SwiftUI

private class HomeContentViewCounter {
    static var count = 0
}

struct HomeContentView: View {
    @ObservedObject private var apiConfig = ApiConfig.shared
    @StateObject private var viewModel = HomeContentViewModel()
    @Environment(\.tvboxWideLayout) private var isWideLayout
    /// 当前选中的分类，nil 表示「推荐」
    @State private var selectedCategory: MovieCategory?
    /// 「继续观看」一排，每次回到首页重新读取
    @State private var historyItems: [StorageManager.VodHistoryItem] = []

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
        .background(Color.tvboxBackground.ignoresSafeArea())
        .tvboxHiddenNavigationBar()
        .refreshable {
            await viewModel.refresh()
        }
        .onAppear {
            AppLogger.debug("[HomeContentView] onAppear 被调用")
            viewModel.loadData()
            historyItems = Array(StorageManager.shared.getVodHistory().prefix(10))
        }
        .onChange(of: apiConfig.currentSite?.key) { _, newValue in
            AppLogger.debug("[HomeContentView] onChange currentSite: \(newValue ?? "nil")")
            selectedCategory = nil
            viewModel.loadData()
        }
    }

    // 站点名、搜索框、分类 Tab 跟着内容一起滚动，选中分类时下面原地换成分类的海报网格
    private var narrowBody: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    narrowHeader

                    if !viewModel.categories.isEmpty {
                        narrowCategoryTabs
                    }

                    if let category = selectedCategory {
                        CategoryGrid(category: category)
                            .id(category.tid)
                            .padding(.horizontal, 18)
                    } else {
                        homeSections
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            loadingState
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
        VStack(alignment: .leading, spacing: 24) {
            if let error = viewModel.error {
                unsupportedState(error)
            }

            // 窄屏推荐的第一部放大卡，其余进海报网格
            if !isWideLayout, let featured = viewModel.recommendMovies.first {
                featureCard(featured)
            }

            if !historyItems.isEmpty {
                continueWatchingSection
            }

            let gridMovies = isWideLayout ? viewModel.recommendMovies : Array(viewModel.recommendMovies.dropFirst())
            if !gridMovies.isEmpty {
                recommendSection(gridMovies)
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

    // MARK: - Header

    private var narrowHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                siteSelector(large: true)

                Spacer(minLength: 12)

                NavigationLink(destination: HistoryView()) {
                    Image(systemName: "clock")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.primary)
                        .frame(width: 38, height: 38)
                        .background(Color.tvboxSurface, in: Circle())
                        .overlay(Circle().strokeBorder(Color.tvboxHairline, lineWidth: 1))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("观看历史")
            }

            NavigationLink(destination: SearchView()) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                    Text("搜索片名")
                    Spacer(minLength: 0)
                }
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .frame(height: 42)
                .tvboxCard(cornerRadius: 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("搜索")
        }
        .padding(.horizontal, 18)
    }

    private var narrowCategoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 22) {
                underlineTab(title: "推荐", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }

                ForEach(viewModel.categories) { category in
                    underlineTab(title: category.name, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 18)
        }
        .background(alignment: .bottom) {
            Rectangle()
                .fill(Color.tvboxHairline)
                .frame(height: 1)
                .padding(.horizontal, 18)
        }
    }

    private func underlineTab(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
                .padding(.top, 4)
                .padding(.bottom, 10)
                .overlay(alignment: .bottom) {
                    if isSelected {
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(height: 2.5)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var wideCategoryBar: some View {
        HStack(spacing: 12) {
            siteSelector(large: false)

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
                .background(isSelected ? Color.accentColor : Color.clear)
                .cornerRadius(8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// - Parameter large: 窄屏首页的大标题样式，前面带强调色圆点
    private func siteSelector(large: Bool) -> some View {
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
            HStack(spacing: large ? 8 : 4) {
                if large {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                        .background(Circle().fill(Color.accentColor.opacity(0.18)).frame(width: 16, height: 16))
                }
                Text(apiConfig.currentSite?.name ?? "豆瓣热门")
                    .font(large ? .system(size: 22, weight: .heavy) : .headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(large ? .system(size: 13, weight: .bold) : .caption.weight(.semibold))
                    .foregroundColor(large ? .secondary : .primary)
            }
        }
        // macOS 默认画成带边框和系统箭头的弹出按钮
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // MARK: - Sections

    private func sectionHeader<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
            Spacer()
            trailing()
        }
        .padding(.horizontal, 18)
    }

    /// 推荐的第一部：海报模糊打底，左边海报，右边片名和播放按钮
    private func featureCard(_ movie: MovieItem) -> some View {
        let meta = [movie.vodYear, movie.typeName, movie.vodRemarks]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        return NavigationLink(destination: DetailView(movie: movie)) {
            HStack(alignment: .bottom, spacing: 14) {
                Color.clear
                    .frame(width: 92, height: 138)
                    .overlay {
                        CachedAsyncImage(urlString: movie.vodPic) { Color.white.opacity(0.1) }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(movie.vodName)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if !meta.isEmpty {
                        Text(meta)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                        Text("播放")
                    }
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Color.tvboxAccentOnDark, in: Capsule())
                    .padding(.top, 4)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    Color(white: 0.1)
                    CachedAsyncImage(urlString: movie.vodPic) { Color.clear }
                        .scaleEffect(1.4)
                        .blur(radius: 30)
                    LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
    }

    private var continueWatchingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("继续观看") {
                NavigationLink(destination: HistoryView()) {
                    HStack(spacing: 2) {
                        Text("全部")
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(historyItems) { item in
                        NavigationLink(destination: HistoryDestination(item: item)) {
                            continueWatchingCard(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }

    private func continueWatchingCard(_ item: StorageManager.VodHistoryItem) -> some View {
        let episode = item.episodeName ?? "第\(item.episodeIndex + 1)集"
        let subtitle = item.duration > 0
            ? "\(episode) · 已看 \(Int(min(item.progress / item.duration, 1) * 100))%"
            : episode
        return VStack(alignment: .leading, spacing: 6) {
            HistoryThumbnail(item: item)
                .frame(width: 150, height: 84)
                .overlay(alignment: .topLeading) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.black.opacity(0.5), in: Circle())
                        .padding(8)
                }

            Text(item.vodName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 150, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func recommendSection(_ movies: [MovieItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("热门推荐")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: isWideLayout ? 140 : 100), spacing: 12)], alignment: .leading, spacing: 16) {
                ForEach(movies) { movie in
                    NavigationLink(destination: DetailView(movie: movie)) {
                        MovieCard(movie: movie)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
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
        .tvboxCard()
        .padding(.horizontal, 18)
    }
}
