import SwiftUI

/// Node 运行的配置包自带的配置中心网页（`/website`），网盘登录、Cookie、站点开关都在这里配置。
struct CatNodeConfigCenterView: View {
    @State private var websiteURL: URL?
    @State private var isResolved = false

    var body: some View {
        Group {
            if let websiteURL {
                ConfigCenterBrowserView(urlString: websiteURL.absoluteString)
            } else if isResolved {
                Text(CatNodeError.notRunning.localizedDescription)
                    .foregroundColor(.secondary)
            } else {
                ProgressView()
            }
        }
        .task {
            websiteURL = await CatNodeRuntime.shared.baseURL?.appendingPathComponent("website")
            isResolved = true
        }
    }
}
