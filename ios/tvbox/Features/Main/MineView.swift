import SwiftUI

struct MineView: View {
    @ObservedObject private var apiConfig = ApiConfig.shared
    @State private var historyItems: [StorageManager.VodHistoryItem] = []
    @State private var collectItems: [StorageManager.VodCollectItem] = []
    @State private var showConfigSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                configCard

                HStack(spacing: 12) {
                    NavigationLink(destination: HistoryView()) {
                        entryTile(title: "观看历史", systemImage: "clock", count: historyItems.count, posters: historyItems.map(\.vodPic))
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: CollectView()) {
                        entryTile(title: "我的收藏", systemImage: "heart", count: collectItems.count, posters: collectItems.map(\.vodPic))
                    }
                    .buttonStyle(.plain)
                }

                settingsGroup
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .background(Color.tvboxBackground.ignoresSafeArea())
        .navigationTitle("我的")
        .onAppear {
            historyItems = StorageManager.shared.getVodHistory()
            collectItems = StorageManager.shared.getCollects()
        }
        .sheet(isPresented: $showConfigSheet) {
            ConfigSetupView {
                Task {
                    try? await apiConfig.loadConfig(useCache: false)
                }
            }
            .tvboxConfigSheetSize()
        }
    }

    // MARK: - Config Card

    /// 当前配置地址和站点、解析、直播的数量
    private var configCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "server.rack")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.accentColor)
                    .frame(width: 48, height: 48)
                    .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 3) {
                    Text("当前配置")
                        .font(.system(size: 16, weight: .bold))
                    HStack(spacing: 6) {
                        Circle()
                            .fill(apiConfig.configLoaded ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(configAddress)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer(minLength: 8)

                Button("更换") {
                    showConfigSheet = true
                }
                .font(.footnote.weight(.semibold))
                .foregroundColor(.accentColor)
                .buttonStyle(.plain)
            }

            Divider()

            HStack(spacing: 0) {
                statItem(count: apiConfig.sites.count, title: "站点")
                statItem(count: apiConfig.parses.count, title: "解析")
                statItem(count: apiConfig.liveConfigs.count, title: "直播")
            }
        }
        .padding(16)
        .tvboxCard(cornerRadius: 20)
    }

    /// 去掉 http(s):// 前缀，只留地址本身
    private var configAddress: String {
        let url = apiConfig.apiUrl
        guard !url.isEmpty else { return "未配置" }
        return url.replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)
    }

    private func statItem(count: Int, title: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(count)")
                .font(.system(size: 18, weight: .heavy))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Entry Tiles

    /// 数量下面叠最近三张海报当预览
    private func entryTile(title: String, systemImage: String, count: Int, posters: [String?]) -> some View {
        VStack(alignment: .leading) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(.secondary)

            Spacer(minLength: 12)

            HStack(alignment: .bottom) {
                Text("\(count)")
                    .font(.system(size: 28, weight: .heavy))
                    .monospacedDigit()
                    .foregroundColor(.primary)

                Spacer(minLength: 4)

                HStack(spacing: -12) {
                    ForEach(Array(posters.prefix(3).enumerated()), id: \.offset) { _, poster in
                        Color.clear
                            .frame(width: 30, height: 44)
                            .overlay {
                                CachedAsyncImage(urlString: poster) { Color.tvboxSurfaceSecondary }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.tvboxSurface, lineWidth: 1.5))
                            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .tvboxCard()
        .contentShape(Rectangle())
    }

    // MARK: - Settings

    private var settingsGroup: some View {
        VStack(spacing: 0) {
            // 配置中心（Node 运行的配置包自带网页）
            if apiConfig.sites.contains(where: { $0.catNodeApi != nil }) {
                NavigationLink(destination: CatNodeConfigCenterView()) {
                    settingsRow(title: "配置中心", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 56)
            }

            NavigationLink(destination: MetadataSettingsView()) {
                settingsRow(title: "影视资料", systemImage: "film.stack", value: TMDBSettings.isConfigured ? "已开启" : "未开启")
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 56)

            NavigationLink(destination: SettingsView()) {
                settingsRow(title: "设置", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
        }
        .tvboxCard()
    }

    private func settingsRow(title: String, systemImage: String, value: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .frame(width: 30, height: 30)
                .background(Color.tvboxSurfaceSecondary, in: RoundedRectangle(cornerRadius: 9))

            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.primary)

            Spacer()

            if let value {
                Text(value)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .contentShape(Rectangle())
    }
}
