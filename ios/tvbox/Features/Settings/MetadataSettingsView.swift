import SwiftUI

/// 影视资料设置：从 TMDB 补全详情页的背景图、分集、演员等
struct MetadataSettingsView: View {
    @State private var isEnabled = TMDBSettings.isEnabled
    @State private var apiKey = TMDBSettings.apiKey
    @State private var proxy = TMDBSettings.proxy
    @State private var language = TMDBSettings.language
    @State private var testState: TestState = .idle
    @State private var cachedCount = 0
    @State private var showClearAlert = false
    @State private var aiEnabled = AIMatchSettings.isEnabled
    @State private var aiBaseURL = AIMatchSettings.baseURL
    @State private var aiApiKey = AIMatchSettings.apiKey
    @State private var aiModel = AIMatchSettings.model
    @State private var aiTestState: TestState = .idle

    private enum TestState: Equatable {
        case idle, testing, success
        case failure(String)
    }

    var body: some View {
        Form {
            Section {
                Toggle("从 TMDB 补全资料", isOn: $isEnabled)
                TextField("API Key", text: $apiKey)
                    .tvboxUrlTextInputStyle()
                TextField("代理地址（可选）", text: $proxy)
                    .tvboxUrlTextInputStyle()
                Picker("资料语言", selection: $language) {
                    ForEach(TMDBSettings.languages, id: \.code) { item in
                        Text(item.name).tag(item.code)
                    }
                }
            } header: {
                Text("TMDB")
            } footer: {
                Text("API Key 在 themoviedb.org → 设置 → API 免费申请，v3 Key 和 v4 读取令牌都可以。国内直连不稳定时填代理地址，代理需要把 /3/ 转发到 api.tmdb.org、/t/p/ 转发到 image.tmdb.org。")
            }

            Section {
                Button(action: testConnection) {
                    HStack {
                        Text("测试连接")
                        Spacer()
                        statusView(testState)
                    }
                }
                .tvboxFormRowButtonStyle()
                .disabled(apiKey.isEmpty || testState == .testing)

                Button(role: .destructive, action: { showClearAlert = true }) {
                    HStack {
                        Text("清除资料缓存")
                        Spacer()
                        Text("\(cachedCount) 部")
                            .foregroundColor(.secondary)
                    }
                }
                .tvboxFormRowButtonStyle()
            } footer: {
                Text("在详情页长按（Mac 上右键）顶部大图可以重新匹配，从搜索结果里手动选正确的作品；长按分集卡片可以手动对应 TMDB 的分集。")
            }

            Section {
                Toggle("AI 辅助匹配分集", isOn: $aiEnabled)
                TextField("接口地址", text: $aiBaseURL, prompt: Text("https://api.deepseek.com/v1"))
                    .tvboxUrlTextInputStyle()
                TextField("API Key", text: $aiApiKey)
                    .tvboxUrlTextInputStyle()
                TextField("模型", text: $aiModel, prompt: Text("deepseek-chat"))
                    .tvboxUrlTextInputStyle()
                Button(action: testAIConnection) {
                    HStack {
                        Text("测试连接")
                        Spacer()
                        statusView(aiTestState)
                    }
                }
                .tvboxFormRowButtonStyle()
                .disabled(aiBaseURL.isEmpty || aiApiKey.isEmpty || aiModel.isEmpty || aiTestState == .testing)
            } header: {
                Text("AI 辅助")
            } footer: {
                Text("规则对不上的分集，把集名和 TMDB 分集列表发给模型对应，结果会缓存，同一个集名只问一次。支持 OpenAI 兼容格式的接口，地址填到 /v1 为止。")
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .navigationTitle("影视资料")
        .tvboxInlineNavigationBarTitle()
        .onChange(of: isEnabled) { _, value in TMDBSettings.isEnabled = value }
        .onChange(of: apiKey) { _, value in
            TMDBSettings.apiKey = value
            testState = .idle
        }
        .onChange(of: proxy) { _, value in
            TMDBSettings.proxy = value
            testState = .idle
        }
        .onChange(of: language) { _, value in
            TMDBSettings.language = value
            // 换语言后旧缓存的标题简介都是原来的语言
            Task {
                await TMDBService.shared.clearCache()
                cachedCount = 0
            }
        }
        .onChange(of: aiEnabled) { _, value in AIMatchSettings.isEnabled = value }
        .onChange(of: aiBaseURL) { _, value in
            AIMatchSettings.baseURL = value
            aiTestState = .idle
        }
        .onChange(of: aiApiKey) { _, value in
            AIMatchSettings.apiKey = value
            aiTestState = .idle
        }
        .onChange(of: aiModel) { _, value in
            AIMatchSettings.model = value
            aiTestState = .idle
        }
        .task {
            cachedCount = await TMDBService.shared.cachedCount()
        }
        .alert("清除资料缓存", isPresented: $showClearAlert) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                Task {
                    await TMDBService.shared.clearCache()
                    await EpisodeAIMatcher.shared.clearCache()
                    cachedCount = 0
                }
            }
        } message: {
            Text("下次打开详情页时会重新从 TMDB 获取，AI 对应的分集也会重新匹配，手动匹配的结果会保留。")
        }
    }

    @ViewBuilder
    private func statusView(_ state: TestState) -> some View {
        switch state {
        case .idle:
            EmptyView()
        case .testing:
            ProgressView()
                .controlSize(.small)
        case .success:
            Label("连接正常", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failure(let message):
            Text(message)
                .foregroundColor(.red)
                .lineLimit(1)
        }
    }

    private func testConnection() {
        testState = .testing
        Task {
            do {
                try await TMDBService.shared.testConnection()
                testState = .success
            } catch {
                testState = .failure(AppErrorMessage.userMessage(for: error))
            }
        }
    }

    private func testAIConnection() {
        aiTestState = .testing
        Task {
            do {
                try await EpisodeAIMatcher.shared.testConnection()
                aiTestState = .success
            } catch {
                aiTestState = .failure(AppErrorMessage.userMessage(for: error))
            }
        }
    }
}
