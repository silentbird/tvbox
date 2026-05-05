import SwiftUI

struct MineView: View {
    @ObservedObject private var apiConfig = ApiConfig.shared

    var body: some View {
        List {
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

            Section {
                NavigationLink(destination: HistoryView()) {
                    Label("观看历史", systemImage: "clock.arrow.circlepath")
                }

                NavigationLink(destination: CollectView()) {
                    Label("我的收藏", systemImage: "heart")
                }
            }

            Section {
                NavigationLink(destination: SettingsView()) {
                    Label("设置", systemImage: "gear")
                }
            }
        }
        .navigationTitle("我的")
    }
}
