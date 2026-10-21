import SwiftUI

struct DetailView: View {
    let movie: MovieItem
    /// 详情加载完直接播放上次看的那一集，用于从观看历史进入
    var autoPlay = false
    @StateObject private var viewModel = DetailViewModel()
    @State private var selectedSourceIndex = 0
    @State private var playRequest: PlayRequest?
    /// 只自动播放一次，退出播放器回到详情页不再触发
    @State private var didAutoPlay = false
    @State private var showAllEpisodes = false
    /// 在选集面板里点的集，面板关闭后再播放
    @State private var pendingEpisodeIndex: Int?
    @State private var showMatch = false
    /// 正在手动对应分集的那一集
    @State private var episodeMatchTarget: EpisodeMatchTarget?
    /// 剧集、演职人员两排横向列表最左边显示的那一项
    @State private var episodePosition: Int?
    @State private var castPosition: Int?
    @Environment(\.tvboxWideLayout) private var isWideLayout

    var body: some View {
        Group {
            if movie.vodId.hasPrefix("msearch:") {
                // 豆瓣等推荐站点的卡片没有详情，和 Android 一样按片名跳转快速搜索
                FastSearchView(keyword: movie.vodName)
            } else if isCatNodeConfigCenterMovie {
                CatNodeConfigCenterView()
                    .tvboxInlineNavigationBarTitle()
            } else if let configCenterURL {
                ConfigCenterWebView(urlString: configCenterURL)
                    .tvboxInlineNavigationBarTitle()
            } else {
                detailContent
            }
        }
    }

    private var configCenterURL: String? {
        guard isConfigCenterMovie else {
            return nil
        }

        if let url = movie.vodPlayUrl, !url.isEmpty {
            return url
        }

        let siteAPI = ApiConfig.shared.currentSite?.api.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return siteAPI.isEmpty ? nil : siteAPI
    }

    /// Node 运行的配置包「配置|中心」站点首页卡片，直接打开配置包自带的 `/website`。
    private var isCatNodeConfigCenterMovie: Bool {
        movie.vodId == "config-center" && ApiConfig.shared.currentSite?.catNodeApi != nil
    }

    /// 详情所属站点：搜索结果带来源站点，否则为当前站点
    private var site: SiteBean? {
        let apiConfig = ApiConfig.shared
        if let sourceKey = movie.sourceKey, let site = apiConfig.sites.first(where: { $0.key == sourceKey }) {
            return site
        }
        return apiConfig.currentSite
    }

    private var isConfigCenterMovie: Bool {
        movie.vodTag == "config_center" ||
            movie.vodId == "config_center" ||
            (movie.typeName == "配置" && movie.vodName.contains("配置"))
    }

    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroSection

                infoSection

                // 播放源和剧集
                if let vodInfo = viewModel.vodInfo {
                    playSourceSection(vodInfo: vodInfo)
                }

                castSection

                if viewModel.metadata != nil {
                    attribution
                }
            }
            .padding(.bottom, 24)
        }
        .background(backgroundView)
        .environment(\.colorScheme, .dark)
        .tvboxContentUnderNavigationBar()
        .tvboxInlineNavigationBarTitle()
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        .sheet(isPresented: $showAllEpisodes, onDismiss: {
            // 等选集面板关掉再弹播放器，否则两个弹出层会冲突
            if let index = pendingEpisodeIndex {
                pendingEpisodeIndex = nil
                play(episodeIndex: index)
            }
        }) {
            if let vodInfo = viewModel.vodInfo, vodInfo.playUrls.indices.contains(selectedSourceIndex) {
                EpisodeListSheet(
                    episodes: vodInfo.playUrls[selectedSourceIndex],
                    playIndex: viewModel.playIndex(sourceIndex: selectedSourceIndex)
                ) { index in
                    pendingEpisodeIndex = index
                }
            }
        }
        .sheet(isPresented: $showMatch) {
            TMDBMatchView(vodName: movie.vodName) { item in
                viewModel.rematch(item)
            }
        }
        .sheet(item: $episodeMatchTarget) { target in
            if let metadata = viewModel.metadata {
                EpisodeMatchSheet(
                    episodeName: target.name,
                    metadata: metadata,
                    current: target.ref,
                    isManual: viewModel.episodeOverrides[target.name] != nil
                ) { ref in
                    viewModel.setEpisodeOverride(name: target.name, ref: ref)
                }
            }
        }
        .tvboxFullScreenCover(item: $playRequest) { request in
            if let vodInfo = viewModel.vodInfo {
                let sourceIndex = request.sourceIndex
                let episodeIndex = request.episodeIndex
                PlayerView(
                    title: vodInfo.vodName,
                    sources: vodInfo.playFlags.indices.map { index in
                        PlaySource(
                            flag: vodInfo.playFlags[index],
                            episodes: vodInfo.playUrls.indices.contains(index) ? vodInfo.playUrls[index] : []
                        )
                    },
                    sourceIndex: sourceIndex,
                    episodeIndex: episodeIndex,
                    startPosition: viewModel.resumePosition(sourceIndex: sourceIndex, episodeIndex: episodeIndex),
                    configKey: "\(site?.key ?? "")_\(vodInfo.vodId)",
                    resolvePlayUrl: { flag, episode in try await viewModel.getPlayUrlAsync(flag: flag, episode: episode) },
                    onProgress: { sourceIndex, episodeIndex, position, duration in
                        viewModel.addToHistory(sourceIndex: sourceIndex, episodeIndex: episodeIndex, progress: position, duration: duration)
                    }
                )
            }
        }
        .onAppear {
            viewModel.loadDetail(vodId: movie.vodId, site: site)
        }
        .onChange(of: viewModel.vodInfo?.vodId) { _, _ in
            // 和 Android 一样恢复上次播放的线路
            if let history = viewModel.history, let vodInfo = viewModel.vodInfo,
               history.playIndex < vodInfo.playUrls.count {
                selectedSourceIndex = history.playIndex
            }
            if autoPlay, !didAutoPlay, let vodInfo = viewModel.vodInfo,
               vodInfo.playUrls.indices.contains(selectedSourceIndex),
               !vodInfo.playUrls[selectedSourceIndex].isEmpty {
                didAutoPlay = true
                play(episodeIndex: viewModel.playIndex(sourceIndex: selectedSourceIndex))
            }
        }
    }

    private var horizontalPadding: CGFloat { isWideLayout ? 24 : 16 }

    private var posterURL: String? {
        [viewModel.vodInfo?.vodPic, movie.vodPic].compactMap { $0 }.first { !$0.isEmpty }
    }

    /// 顶部大图：TMDB 横版背景图，其次站点的横版图，都没有时用竖版海报裁切
    private var heroImageURL: String? {
        TMDBSettings.imageURL(viewModel.metadata?.backdropPath, size: "w1280")
            ?? viewModel.vodInfo?.vodPicSlide
            ?? posterURL
    }

    // MARK: - Background
    /// 整页背景：大图放大模糊后压暗
    private var backgroundView: some View {
        ZStack {
            Color(white: 0.08)
            Color.clear
                .overlay {
                    CachedAsyncImage(urlString: heroImageURL) { Color.clear }
                        .id(heroImageURL)
                        .scaleEffect(1.3)
                        .blur(radius: 60)
                        .opacity(0.9)
                }
                .clipped()
            Color.black.opacity(0.5)
        }
        .ignoresSafeArea()
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        let height: CGFloat = isWideLayout ? 420 : 320
        return Color.clear
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .overlay {
                CachedAsyncImage(urlString: heroImageURL) { Color.clear }
                    .id(heroImageURL)
            }
            .clipped()
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.45),
                        .init(color: Color(white: 0.08).opacity(0.92), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .bottomLeading) {
                titleView
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 16)
            }
            .contentShape(Rectangle())
            .contextMenu {
                if TMDBSettings.isConfigured {
                    Button(action: { showMatch = true }) {
                        Label("重新匹配 TMDB", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
    }

    /// 有 TMDB 片名 Logo 时用 Logo，没有或加载不出来时用文字
    @ViewBuilder
    private var titleView: some View {
        let title = Text(movie.vodName)
            .font(isWideLayout ? .largeTitle : .title)
            .fontWeight(.heavy)
            .foregroundColor(.white)
            .lineLimit(2)
            .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
        if let logo = TMDBSettings.imageURL(viewModel.metadata?.logoPath, size: "w500") {
            CachedAsyncImage(urlString: logo, contentMode: .fit) { title }
                .id(logo)
                .frame(maxWidth: isWideLayout ? 360 : 240, maxHeight: isWideLayout ? 130 : 96, alignment: .bottomLeading)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
        } else {
            title
        }
    }

    // MARK: - Info Section
    // 宽屏左边按钮、右边信息；窄屏信息、按钮、简介依次排列
    @ViewBuilder
    private var infoSection: some View {
        if isWideLayout {
            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 10) {
                    secondaryButtons
                    playButton
                }
                .frame(width: 270)

                VStack(alignment: .leading, spacing: 6) {
                    metaRows
                    descriptionText
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 4)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                metaRows
                VStack(spacing: 10) {
                    playButton
                    secondaryButtons
                }
                descriptionText
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 4)
        }
    }

    private var secondaryButtons: some View {
        HStack(spacing: 10) {
            NavigationLink(destination: FastSearchView(keyword: movie.vodName)) {
                pillLabel("快搜", systemImage: "magnifyingglass")
            }
            .buttonStyle(.plain)

            Button(action: { viewModel.toggleCollect() }) {
                pillLabel(viewModel.isCollected ? "已收藏" : "收藏", systemImage: viewModel.isCollected ? "heart.fill" : "heart")
                    .foregroundColor(viewModel.isCollected ? .red : .white)
            }
            .buttonStyle(.plain)
        }
    }

    private func pillLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(Color.white.opacity(0.18), in: Capsule())
            .contentShape(Capsule())
    }

    /// 有播放记录时显示「继续播放」和上次看到的集数
    @ViewBuilder
    private var playButton: some View {
        if let vodInfo = viewModel.vodInfo,
           vodInfo.playUrls.indices.contains(selectedSourceIndex),
           !vodInfo.playUrls[selectedSourceIndex].isEmpty {
            let episodes = vodInfo.playUrls[selectedSourceIndex]
            let playIndex = viewModel.playIndex(sourceIndex: selectedSourceIndex)
            let position = viewModel.resumePosition(sourceIndex: selectedSourceIndex, episodeIndex: playIndex)
            Button(action: { play(episodeIndex: playIndex) }) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    Text(viewModel.history == nil ? "播放" : "继续播放")
                        .fontWeight(.semibold)
                    if viewModel.history != nil {
                        Text(position > 0
                             ? "\(episodes[playIndex].name) · \(PlayerViewModel.formatTime(position))"
                             : episodes[playIndex].name)
                            .foregroundColor(.black.opacity(0.55))
                            .lineLimit(1)
                    }
                }
                .font(.subheadline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color.white.opacity(0.92), in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var metaRows: some View {
        let metadata = viewModel.metadata
        let vodInfo = viewModel.vodInfo
        let genres = metadata?.genres.isEmpty == false ? metadata!.genres : [movie.typeName ?? vodInfo?.typeName].compactMap { $0 }
        let firstRow = (genres + [movie.vodYear ?? vodInfo?.vodYear, movie.vodArea ?? vodInfo?.vodArea].compactMap { $0 })
            .filter { !$0.isEmpty }
        let remarks = [movie.vodRemarks, vodInfo?.vodRemarks].compactMap { $0 }.first { !$0.isEmpty }
        let rating = metadata?.rating ?? vodInfo?.vodScore
        var details: [String] = []
        if let date = metadata?.releaseDate, !date.isEmpty {
            details.append(metadata?.mediaType == .tv ? "\(date) 首播" : "\(date) 上映")
        }
        if let runtime = metadata?.runtime {
            details.append(metadata?.mediaType == .tv ? "每集 \(runtime) 分钟" : "\(runtime) 分钟")
        }
        if let count = metadata?.episodeCount, count > 1 {
            details.append("共 \(count) 集")
        }

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let certification = metadata?.certification {
                    badge(certification, filled: false)
                }
                Text(firstRow.joined(separator: " · "))
                    .lineLimit(1)
            }
            HStack(spacing: 6) {
                if let remarks {
                    badge(remarks, filled: true)
                }
                if let rating {
                    Text("★ \(String(format: "%.1f", rating))")
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 1, green: 0.8, blue: 0.3))
                }
                Text(details.joined(separator: " · "))
                    .lineLimit(1)
            }
        }
        .font(.footnote)
        .foregroundColor(.white.opacity(0.88))
    }

    private func badge(_ text: String, filled: Bool) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(filled ? .semibold : .regular)
            .lineLimit(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .foregroundColor(filled ? Color(red: 0.1, green: 0.07, blue: 0) : .white)
            .background {
                if filled {
                    RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.91, green: 0.73, blue: 0.29))
                } else {
                    RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.55))
                }
            }
    }

    /// 站点简介优先，站点没有时用 TMDB 的
    @ViewBuilder
    private var descriptionText: some View {
        let siteContent = viewModel.vodInfo?.vodContent?
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let content = siteContent?.isEmpty == false ? siteContent : viewModel.metadata?.overview {
            Text(content)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.78))
                .lineSpacing(2)
                .lineLimit(isWideLayout ? 3 : 4)
        }
    }

    // MARK: - Play Source Section
    @ViewBuilder
    private func playSourceSection(vodInfo: VodInfo) -> some View {
        let episodes = vodInfo.playUrls.indices.contains(selectedSourceIndex) ? vodInfo.playUrls[selectedSourceIndex] : []
        let hasSources = vodInfo.playFlags.count > 1
        // 只有一集的电影不显示剧集，直接用播放按钮
        if hasSources || episodes.count > 1 {
            let playIndex = viewModel.playIndex(sourceIndex: selectedSourceIndex)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if isWideLayout && hasSources {
                        sourceMenu(vodInfo: vodInfo)
                    } else {
                        sectionTitle(episodes.count > 1 ? "选集" : "线路")
                    }
                    Spacer()
                    if episodes.count > 1 {
                        Button(action: { showAllEpisodes = true }) {
                            HStack(spacing: 2) {
                                Text("全部 \(episodes.count) 集")
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, horizontalPadding)

                if !isWideLayout && hasSources {
                    sourceChips(vodInfo: vodInfo)
                }

                if episodes.count > 1 {
                    let cardWidth = episodeCardWidth
                    let numberByOrder = EpisodeMatcher.numberByOrder(episodes.map(\.name))
                    ShelfScrollView(
                        count: episodes.count,
                        itemStride: cardWidth + 12,
                        buttonCenterY: cardWidth * 9 / 32,
                        leadingPadding: horizontalPadding,
                        position: $episodePosition
                    ) {
                        ForEach(Array(episodes.enumerated()), id: \.offset) { index, episode in
                            episodeCard(index: index, episode: episode, isPlayIndex: index == playIndex, numberByOrder: numberByOrder)
                        }
                    }
                    .onAppear {
                        episodePosition = playIndex
                    }
                    .onChange(of: selectedSourceIndex) { _, _ in
                        episodePosition = viewModel.playIndex(sourceIndex: selectedSourceIndex)
                    }
                    .task(id: "\(viewModel.metadata?.tmdbID ?? 0)-\(selectedSourceIndex)") {
                        await viewModel.matchEpisodesWithAI(sourceIndex: selectedSourceIndex)
                    }
                }
            }
            .padding(.top, 24)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.white)
    }

    private func sourceMenu(vodInfo: VodInfo) -> some View {
        Menu {
            ForEach(Array(vodInfo.playFlags.enumerated()), id: \.offset) { index, flag in
                Button(action: { selectedSourceIndex = index }) {
                    if index == selectedSourceIndex {
                        Label(flag, systemImage: "checkmark")
                    } else {
                        Text(flag)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text("线路 · \(vodInfo.playFlags.indices.contains(selectedSourceIndex) ? vodInfo.playFlags[selectedSourceIndex] : "")")
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .opacity(0.7)
            }
            .foregroundColor(.white)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .fixedSize()
    }

    private func sourceChips(vodInfo: VodInfo) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(vodInfo.playFlags.enumerated()), id: \.offset) { index, flag in
                    let isSelected = index == selectedSourceIndex
                    Button(action: { selectedSourceIndex = index }) {
                        Text(flag)
                            .font(.caption)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .foregroundColor(isSelected ? .black : .white.opacity(0.85))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(isSelected ? Color.white : Color.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
    }

    // MARK: - Episode Card
    private var episodeCardWidth: CGFloat { isWideLayout ? 210 : 160 }

    /// - Parameter numberByOrder: 集名里都没有数字，按顺序对应 TMDB 分集
    private func episodeCard(index: Int, episode: VodInfo.VodPlayItem, isPlayIndex: Bool, numberByOrder: Bool) -> some View {
        let width = episodeCardWidth
        let parsedNumber = EpisodeMatcher.episodeNumber(episode.name)
        let progress = viewModel.playProgress(sourceIndex: selectedSourceIndex, episodeIndex: index)
        let fraction = progress.map { $0.duration > 0 ? min($0.progress / $0.duration, 1) : 0 } ?? 0
        let ref = viewModel.episodeRef(name: episode.name, index: index, numberByOrder: numberByOrder)
        let info = ref.flatMap { viewModel.metadata?.episode($0) }
        var title = episode.name
        // 特别篇的名字带「第4季 」前缀
        if let info, let name = info.name?.replacingOccurrences(of: "^第\\s*\\d+\\s*季\\s*", with: "", options: .regularExpression) {
            // 集名本身是集数时显示 E01，综艺「第1期上」这类直接用 TMDB 的标题
            let variety = EpisodeMatcher.varietyKey(episode.name)
            if case .episode(let number) = ref, parsedNumber != nil, !variety.isPart, variety.airDate == nil {
                title = "E\(String(format: "%02d", number)) · \(name)"
            } else {
                title = name
            }
        }

        return Button(action: { play(episodeIndex: index) }) {
            VStack(alignment: .leading, spacing: 4) {
                Color.clear
                    .frame(width: width, height: width * 9 / 16)
                    .overlay {
                        if let still = TMDBSettings.imageURL(info?.stillPath, size: "w300") {
                            CachedAsyncImage(urlString: still) {
                                episodePlaceholder(number: parsedNumber, name: episode.name)
                            }
                            .id(still)
                        } else {
                            episodePlaceholder(number: parsedNumber, name: episode.name)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .topLeading) {
                        if isPlayIndex && viewModel.history != nil {
                            Text("上次看到")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 4))
                                .padding(8)
                        }
                    }
                    // 进度条缩进在截图里面，不会被当前集的白色描边盖住
                    .overlay(alignment: .bottom) {
                        if let progress, fraction > 0 {
                            VStack(alignment: .trailing, spacing: 5) {
                                let remaining = Int((progress.duration - progress.progress) / 60)
                                Text(fraction >= 0.95 ? "已看完" : "剩 \(max(remaining, 1)) 分钟")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 4))
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.white.opacity(0.3))
                                        Capsule().fill(Color(red: 0.91, green: 0.73, blue: 0.29))
                                            .frame(width: max(4, geometry.size.width * fraction))
                                    }
                                }
                                .frame(height: 4)
                                .shadow(color: .black.opacity(0.4), radius: 2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.bottom, 7)
                        }
                    }
                    .overlay {
                        if isPlayIndex {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.white, lineWidth: 2.5)
                        }
                    }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let overview = info?.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.62))
                        .lineLimit(isWideLayout ? 3 : 2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(width: width, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if viewModel.metadata?.mediaType == .tv {
                Button(action: { episodeMatchTarget = EpisodeMatchTarget(name: episode.name, ref: ref) }) {
                    Label("对应 TMDB 分集…", systemImage: "list.number")
                }
            }
        }
    }

    /// 没有分集截图时用海报模糊打底，中间放集数
    private func episodePlaceholder(number: Int?, name: String) -> some View {
        ZStack {
            CachedAsyncImage(urlString: posterURL) { Color.white.opacity(0.1) }
                .id(posterURL)
                .blur(radius: 8)
            Color.black.opacity(0.35)
            Text(number.map { String(format: "%02d", $0) } ?? name)
                .font(.system(size: number == nil ? 17 : (isWideLayout ? 34 : 26), weight: .heavy))
                .foregroundColor(.white.opacity(0.92))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Cast Section
    private struct CastMember: Identifiable {
        let id: Int
        let name: String
        let role: String
        let imageURL: String?
    }

    /// TMDB 有演职人员时用 TMDB 的，否则拆分站点的导演、演员文本
    private var castMembers: [CastMember] {
        if let cast = viewModel.metadata?.cast, !cast.isEmpty {
            return cast.enumerated().map { index, person in
                CastMember(
                    id: index,
                    name: person.name,
                    role: person.isDirector ? "导演" : (person.character.flatMap { $0.isEmpty ? nil : $0 } ?? "演员"),
                    imageURL: TMDBSettings.imageURL(person.profilePath, size: "w185")
                )
            }
        }
        let directors = Self.splitNames(viewModel.vodInfo?.vodDirector).map { ($0, "导演") }
        let actors = Self.splitNames(viewModel.vodInfo?.vodActor).map { ($0, "演员") }
        return (directors + actors).prefix(20).enumerated().map { index, item in
            CastMember(id: index, name: item.0, role: item.1, imageURL: nil)
        }
    }

    /// 站点的名字用逗号、顿号、斜杠分隔；只有一段又是中文名时按空格分
    static func splitNames(_ text: String?) -> [String] {
        guard let text else { return [] }
        var names = text.components(separatedBy: CharacterSet(charactersIn: ",，、/|;；"))
        if names.count == 1, text.contains(" "), text.unicodeScalars.contains(where: { (0x4E00...0x9FFF).contains($0.value) }) {
            names = text.components(separatedBy: " ")
        }
        return names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    @ViewBuilder
    private var castSection: some View {
        let members = castMembers
        if !members.isEmpty {
            let size: CGFloat = isWideLayout ? 82 : 68
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("演职人员")
                    .padding(.horizontal, horizontalPadding)

                ShelfScrollView(
                    count: members.count,
                    itemStride: size + 12,
                    buttonCenterY: size / 2,
                    leadingPadding: horizontalPadding,
                    position: $castPosition
                ) {
                    ForEach(members) { member in
                        VStack(alignment: .leading, spacing: 2) {
                            Color.clear
                                .frame(width: size, height: size)
                                .overlay {
                                    if let imageURL = member.imageURL {
                                        CachedAsyncImage(urlString: imageURL) { initialAvatar(member.name, size: size) }
                                            .id(imageURL)
                                    } else {
                                        initialAvatar(member.name, size: size)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .padding(.bottom, 4)
                            Text(member.name)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Text(member.role)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.55))
                        }
                        .lineLimit(1)
                        .frame(width: size, alignment: .leading)
                    }
                }
            }
            .padding(.top, 24)
        }
    }

    /// 没有头像时显示名字首字，颜色按名字固定
    private func initialAvatar(_ name: String, size: CGFloat) -> some View {
        let palette: [Color] = [
            Color(red: 0.36, green: 0.37, blue: 0.45),
            Color(red: 0.25, green: 0.42, blue: 0.56),
            Color(red: 0.56, green: 0.31, blue: 0.42),
            Color(red: 0.31, green: 0.56, blue: 0.45),
            Color(red: 0.56, green: 0.48, blue: 0.31),
            Color(red: 0.42, green: 0.31, blue: 0.56),
        ]
        // hashValue 每次启动都不同，用字符码相加
        let seed = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return ZStack {
            palette[seed % palette.count]
            Text(name.prefix(1))
                .font(.system(size: size * 0.32, weight: .bold))
                .foregroundColor(.white.opacity(0.95))
        }
    }

    /// TMDB 使用条款要求注明来源
    private var attribution: some View {
        HStack(spacing: 6) {
            Text("TMDB")
                .font(.caption2)
                .fontWeight(.heavy)
                .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.25))
                .padding(.horizontal, 5)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.56, green: 0.81, blue: 0.63), Color(red: 0, green: 0.71, blue: 0.89)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 3)
                )
            Text("部分资料来自 The Movie Database")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 24)
    }

    private func play(episodeIndex: Int) {
        playRequest = PlayRequest(sourceIndex: selectedSourceIndex, episodeIndex: episodeIndex)
    }
}

/// 横向列表。Mac 上鼠标滚轮带不动横向滚动，悬停时两侧显示翻页按钮。
/// 左边距放在列表外面，列表在边距处裁切，不会延伸到 macOS 26 浮动侧边栏的玻璃下面
private struct ShelfScrollView<Content: View>: View {
    let count: Int
    /// 每项宽度加间距，用来算一页放得下几项
    let itemStride: CGFloat
    /// 翻页按钮中心离列表顶部的距离，对齐到图片中间
    let buttonCenterY: CGFloat
    let leadingPadding: CGFloat
    @Binding var position: Int?
    @ViewBuilder let content: () -> Content

    @State private var width: CGFloat = 0
    @State private var isHovering = false

    private var pageSize: Int { max(1, Int(width / itemStride)) }
    private var current: Int { position ?? 0 }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                content()
            }
            .scrollTargetLayout()
            .padding(.trailing, leadingPadding)
            .padding(.vertical, 2)
            .tvboxMouseDragScroll()
        }
        .scrollPosition(id: $position, anchor: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .padding(.leading, leadingPadding)
        .overlay(alignment: .topLeading) {
            if isHovering && current > 0 {
                pageButton("chevron.left") { scroll(to: current - pageSize) }
                    .padding(.leading, leadingPadding + 8)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isHovering && current + pageSize < count {
                pageButton("chevron.right") { scroll(to: current + pageSize) }
                    .padding(.trailing, 12)
            }
        }
        .onHover { isHovering = $0 }
    }

    private func pageButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.top, max(0, buttonCenterY - 17))
    }

    private func scroll(to index: Int) {
        withAnimation(.easeInOut(duration: 0.35)) {
            position = min(max(0, index), max(0, count - pageSize))
        }
    }
}

extension View {
    /// Mac 上按住鼠标左右拖动横向列表，iOS 本来就能用手指滑
    @ViewBuilder
    fileprivate func tvboxMouseDragScroll() -> some View {
        #if os(macOS)
        modifier(MouseDragScroll())
        #else
        self
        #endif
    }
}

#if os(macOS)
/// macOS 的 ScrollView 不支持鼠标拖动，拖动时直接改底层 NSScrollView 的滚动位置。
/// 拖动超过几个像素才生效，单击卡片仍然是播放
private struct MouseDragScroll: ViewModifier {
    @State private var scrollView: NSScrollView?
    @State private var startX: CGFloat?

    func body(content: Content) -> some View {
        content
            .background(ScrollViewResolver { scrollView = $0 })
            // 列表内容会跟着拖动移动，用全局坐标算位移才不会抖
            .highPriorityGesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .global)
                    .onChanged { value in
                        guard let scrollView else { return }
                        let clipView = scrollView.contentView
                        let start = startX ?? clipView.bounds.origin.x
                        startX = start
                        let maxX = max(0, (scrollView.documentView?.frame.width ?? 0) - clipView.bounds.width)
                        let x = min(max(0, start - value.translation.width), maxX)
                        clipView.scroll(to: NSPoint(x: x, y: clipView.bounds.origin.y))
                        scrollView.reflectScrolledClipView(clipView)
                    }
                    .onEnded { _ in startX = nil }
            )
    }
}

/// 放在列表内容后面，找到包着它的 NSScrollView
private struct ScrollViewResolver: NSViewRepresentable {
    let onResolve: (NSScrollView) -> Void

    func makeNSView(context: Context) -> ResolverView {
        ResolverView(onResolve: onResolve)
    }

    func updateNSView(_ nsView: ResolverView, context: Context) {}

    final class ResolverView: NSView {
        let onResolve: (NSScrollView) -> Void

        init(onResolve: @escaping (NSScrollView) -> Void) {
            self.onResolve = onResolve
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let scrollView = enclosingScrollView else { return }
            // 不在视图更新过程中改 State
            DispatchQueue.main.async { self.onResolve(scrollView) }
        }
    }
}
#endif

/// 「全部 N 集」面板，集数多时横向列表滑不完
private struct EpisodeListSheet: View {
    let episodes: [VodInfo.VodPlayItem]
    let playIndex: Int
    let onSelect: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.tvboxWideLayout) private var isWideLayout

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: isWideLayout ? 120 : 70), spacing: 8)], spacing: 8) {
                        ForEach(Array(episodes.enumerated()), id: \.element.id) { index, episode in
                            let isPlayIndex = index == playIndex
                            Button(action: {
                                onSelect(index)
                                dismiss()
                            }) {
                                Text(episode.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(isPlayIndex ? Color.blue : Color.tvboxSystemGray5)
                                    .foregroundColor(isPlayIndex ? .white : .primary)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .id(index)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    proxy.scrollTo(playIndex, anchor: .center)
                }
            }
            .navigationTitle("选集 (\(episodes.count))")
            .tvboxInlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .tvboxNavigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .tvboxConfigSheetSize()
    }
}

private struct EpisodeMatchTarget: Identifiable {
    var id: String { name }
    let name: String
    let ref: EpisodeRef?
}

/// 点击播放时选中的线路和剧集
private struct PlayRequest: Identifiable {
    let id = UUID()
    let sourceIndex: Int
    let episodeIndex: Int
}

// MARK: - Detail ViewModel
@MainActor
class DetailViewModel: ObservableObject {
    @Published var vodInfo: VodInfo?
    @Published var isLoading = false
    @Published var isCollected = false
    /// 该视频的播放记录
    @Published private(set) var history: StorageManager.VodHistoryItem?
    @Published var error: Error?
    /// TMDB 补全的资料，没开启或没匹配上时为 nil
    @Published private(set) var metadata: VodMetadata? {
        didSet { loadEpisodeOverrides() }
    }
    /// 手动对应的分集，集名 → 分集
    @Published private(set) var episodeOverrides: [String: EpisodeRef] = [:]
    /// AI 对应的分集，只用在规则对不上的集
    @Published private(set) var aiEpisodeMatches: [String: EpisodeRef] = [:]
    @Published var playerContent: PlayerContent?
    @Published var isLoadingPlayer = false
    @Published var parsedUrl: URL?
    @Published var parsedHeaders: [String: String]?
    @Published var parseStatus: String = ""
    
    private var site: SiteBean?
    private let apiConfig = ApiConfig.shared
    private let storageManager = StorageManager.shared
    private let spiderManager = SpiderManager.shared
    private let parserManager = ParserManager.shared
    
    /// 加载视频详情
    /// - Parameters:
    ///   - vodId: 视频ID
    ///   - site: 视频所属站点
    func loadDetail(vodId: String, site: SiteBean?) {
        guard let site else { return }
        
        self.site = site
        isLoading = true
        error = nil
        
        Task {
            do {
                let details = try await spiderManager.detailContent(site: site, ids: [vodId])
                await MainActor.run {
                    self.vodInfo = details.first
                    self.isLoading = false
                    self.checkCollected(vodId: vodId)
                    self.history = self.storageManager.getVodHistory().first { $0.vodId == vodId && $0.siteKey == site.key }
                    self.loadMetadata()
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    private var metadataTask: Task<Void, Never>?

    private func loadMetadata() {
        guard let vodInfo, let site else { return }
        metadataTask?.cancel()
        let episodeCount = vodInfo.playUrls.map(\.count).max() ?? 0
        metadataTask = Task {
            let metadata = await TMDBService.shared.metadata(
                siteKey: site.key,
                vodName: vodInfo.vodName,
                year: vodInfo.vodYear,
                episodeCount: episodeCount
            )
            guard !Task.isCancelled else { return }
            self.metadata = metadata
        }
    }

    /// 手动选定 TMDB 作品后重新加载资料，nil 表示不使用
    func rematch(_ item: TMDBSearchItem?) {
        guard let vodInfo, let site else { return }
        metadata = nil
        Task {
            await TMDBService.shared.setOverride(siteKey: site.key, vodName: vodInfo.vodName, type: item?.mediaType, id: item?.tmdbID)
            loadMetadata()
        }
    }
    
    // MARK: - 分集对应

    /// 手动对应和 AI 结果的分组，换了 TMDB 作品就是另一组
    private var episodeMatchKey: String? {
        guard let vodInfo, let site, let metadata else { return nil }
        return "\(site.key)|\(vodInfo.vodName)|\(metadata.tmdbID)"
    }

    private func loadEpisodeOverrides() {
        aiEpisodeMatches = [:]
        let stored = episodeMatchKey.flatMap { TMDBSettings.episodeOverrides[$0] } ?? [:]
        episodeOverrides = stored.compactMapValues(EpisodeRef.init(rawValue:))
    }

    /// 手动对应优先，其次规则，最后 AI
    func episodeRef(name: String, index: Int, numberByOrder: Bool) -> EpisodeRef? {
        guard let metadata else { return nil }
        return episodeOverrides[name]
            ?? EpisodeMatcher.match(name: name, index: index, numberByOrder: numberByOrder, metadata: metadata)
            ?? aiEpisodeMatches[name]
    }

    /// 手动对应一集，nil 表示恢复自动匹配
    func setEpisodeOverride(name: String, ref: EpisodeRef?) {
        guard let key = episodeMatchKey else { return }
        episodeOverrides[name] = ref
        var all = TMDBSettings.episodeOverrides
        all[key] = episodeOverrides.mapValues(\.rawValue)
        if all[key]?.isEmpty == true { all[key] = nil }
        TMDBSettings.episodeOverrides = all
    }

    /// 线路里规则对不上的集交给 AI，没开启时什么都不做
    func matchEpisodesWithAI(sourceIndex: Int) async {
        guard AIMatchSettings.isConfigured, let vodInfo, let metadata, metadata.mediaType == .tv,
              let key = episodeMatchKey, vodInfo.playUrls.indices.contains(sourceIndex) else { return }
        let names = vodInfo.playUrls[sourceIndex].map(\.name)
        guard names.count > 1 else { return }
        let byOrder = EpisodeMatcher.numberByOrder(names)
        let pending = names.enumerated().filter { index, name in
            episodeOverrides[name] == nil && aiEpisodeMatches[name] == nil
                && EpisodeMatcher.match(name: name, index: index, numberByOrder: byOrder, metadata: metadata) == nil
        }.map(\.element)
        guard !pending.isEmpty else { return }
        let matches = await EpisodeAIMatcher.shared.matches(key: key, title: vodInfo.vodName, names: pending, metadata: metadata)
        // 等待期间换了作品
        guard key == episodeMatchKey else { return }
        aiEpisodeMatches.merge(matches) { _, new in new }
    }

    /// 加载视频详情 (使用 MovieItem)
    /// - Parameters:
    ///   - movie: 视频项
    ///   - site: 视频所属站点
    func loadDetail(movie: MovieItem, site: SiteBean?) {
        loadDetail(vodId: movie.vodId, site: site)
    }
    
    /// 获取播放地址
    /// - Parameters:
    ///   - flag: 播放源标识
    ///   - episode: 剧集信息
    func loadPlayerContent(flag: String, episode: VodInfo.VodPlayItem) {
        guard let site else { return }
        
        isLoadingPlayer = true
        playerContent = nil
        parsedUrl = nil
        parsedHeaders = nil
        parseStatus = "正在获取播放信息..."
        
        Task {
            do {
                // 1. 获取播放内容
                var content = try await spiderManager.playerContent(site: site, flag: flag, id: episode.url)
                let initialContent = content
                
                await MainActor.run {
                    self.playerContent = initialContent
                }
                
                // 2. 检查是否需要解析
                if content.needParse {
                    await MainActor.run {
                        self.parseStatus = "正在解析播放地址..."
                    }
                    
                    // 调用解析接口
                    content = try await parserManager.parse(content: content)
                    let parsedContent = content
                    
                    await MainActor.run {
                        self.playerContent = parsedContent
                    }
                }
                
                // 3. 设置最终的播放 URL
                let finalContent = content
                await MainActor.run {
                    if let url = URL(string: finalContent.url) {
                        self.parsedUrl = url
                        self.parsedHeaders = finalContent.header
                        self.parseStatus = ""
                    } else {
                        self.parseStatus = "无效的播放地址"
                    }
                    self.isLoadingPlayer = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.parseStatus = "解析失败: \(AppErrorMessage.userMessage(for: error))"
                    self.isLoadingPlayer = false
                }
            }
        }
    }
    
    /// 获取实际播放地址
    /// - Returns: 可播放的 URL 和 headers
    func getPlayUrl() -> (url: URL?, headers: [String: String]?) {
        // 优先返回已解析的 URL
        if let parsedUrl = parsedUrl {
            return (parsedUrl, parsedHeaders)
        }
        
        // 否则返回原始 URL
        guard let content = playerContent else { return (nil, nil) }
        return (URL(string: content.url), content.header)
    }
    
    /// 异步获取播放地址 (带解析)
    /// - Parameters:
    ///   - flag: 播放源标识
    ///   - episode: 剧集信息
    /// - Returns: 可播放的 URL、headers 和站点给出的媒体格式
    func getPlayUrlAsync(flag: String, episode: VodInfo.VodPlayItem) async throws -> PlayAddress {
        guard let site else { throw SpiderError.invalidSite }
        return try await resolvePlayAddress(site: site, flag: flag, episode: episode)
    }
    
    /// 切换收藏状态
    func toggleCollect() {
        guard let vodInfo = vodInfo, let site else { return }
        
        if isCollected {
            storageManager.removeCollect(vodId: vodInfo.vodId, siteKey: site.key)
        } else {
            storageManager.addCollect(vodInfo: vodInfo, site: site)
        }
        isCollected.toggle()
    }
    
    /// 添加到历史记录
    /// - Parameters:
    ///   - sourceIndex: 播放源索引
    ///   - episodeIndex: 剧集索引
    ///   - progress: 播放进度 (秒)
    ///   - duration: 总时长 (秒)
    func addToHistory(sourceIndex: Int, episodeIndex: Int, progress: Double, duration: Double) {
        guard let vodInfo = vodInfo, let site,
              sourceIndex < vodInfo.playFlags.count, sourceIndex < vodInfo.playUrls.count,
              episodeIndex < vodInfo.playUrls[sourceIndex].count else { return }
        let episodeName = vodInfo.playUrls[sourceIndex][episodeIndex].name
        history = storageManager.addHistory(
            vodInfo: vodInfo,
            site: site,
            sourceIndex: sourceIndex,
            episodeIndex: episodeIndex,
            episodeName: episodeName,
            progress: progress,
            duration: duration
        )
        storageManager.savePlayProgress(StorageManager.PlayProgressItem(
            vodId: vodInfo.vodId,
            siteKey: site.key,
            flag: vodInfo.playFlags[sourceIndex],
            episodeIndex: episodeIndex,
            episodeName: episodeName,
            progress: progress,
            duration: duration
        ))
    }
    
    /// 该剧集上次的播放位置 (秒)，没有记录时从头播放
    func resumePosition(sourceIndex: Int, episodeIndex: Int) -> Double {
        playProgress(sourceIndex: sourceIndex, episodeIndex: episodeIndex)?.progress ?? 0
    }

    /// 该剧集的播放进度记录
    func playProgress(sourceIndex: Int, episodeIndex: Int) -> StorageManager.PlayProgressItem? {
        guard let vodInfo = vodInfo, let site,
              sourceIndex < vodInfo.playFlags.count, sourceIndex < vodInfo.playUrls.count,
              episodeIndex < vodInfo.playUrls[sourceIndex].count else { return nil }
        return storageManager.getPlayProgress(
            vodId: vodInfo.vodId,
            siteKey: site.key,
            flag: vodInfo.playFlags[sourceIndex],
            episodeIndex: episodeIndex,
            episodeName: vodInfo.playUrls[sourceIndex][episodeIndex].name
        )
    }
    
    /// 当前播放源下选中的剧集，对应 Android 的 vodInfo.playIndex：
    /// 有播放记录时选中上次看的那一集，切换播放源后按集名找到对应剧集，否则选中第一集
    func playIndex(sourceIndex: Int) -> Int {
        guard let vodInfo, sourceIndex < vodInfo.playUrls.count else { return 0 }
        let episodes = vodInfo.playUrls[sourceIndex]
        guard let history else { return 0 }
        if history.playIndex == sourceIndex {
            return history.episodeIndex < episodes.count ? history.episodeIndex : 0
        }
        return episodes.firstIndex { $0.name == history.episodeName } ?? 0
    }
    
    private func checkCollected(vodId: String) {
        guard let site else { return }
        isCollected = storageManager.isCollected(vodId: vodId, siteKey: site.key)
    }
}

#if !targetEnvironment(macCatalyst)
#Preview {
    NavigationView {
        DetailView(movie: try! JSONDecoder().decode(
            MovieItem.self,
            from: """
            {"vod_id": "1", "vod_name": "测试电影", "vod_pic": "", "vod_remarks": "更新至10集"}
            """.data(using: .utf8)!
        ))
    }
}
#endif
