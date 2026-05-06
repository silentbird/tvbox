import SwiftUI

struct ConfigSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiUrl: String = ""
    @State private var recentApiUrls: [String] = []
    @State private var isLoading = false
    @State private var error: String?

    let onComplete: () -> Void

    var body: some View {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        NavigationView {
            configContent
                .navigationTitle("初始配置")
                .tvboxInlineNavigationBarTitle()
                .toolbar {
                    ToolbarItem(placement: .tvboxNavigationBarLeading) {
                        Button("取消") {
                            dismiss()
                        }
                    }
                }
        }
        #else
        VStack(spacing: 0) {
            HStack {
                Text("初始配置")
                    .font(.headline)
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 8)

            configContent
        }
        #endif
    }

    private var configContent: some View {
        VStack(spacing: 24) {
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

            VStack(alignment: .leading, spacing: 8) {
                Text("配置地址")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("http://example.com/config.json", text: $apiUrl)
                    .textFieldStyle(.roundedBorder)
                    .tvboxUrlTextInputStyle()
            }
            .padding(.horizontal)

            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

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

            if !recentApiUrls.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近使用")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(recentApiUrls.prefix(3), id: \.self) { url in
                        Button {
                            apiUrl = url
                        } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.secondary)
                                Text(url)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(Color.tvboxSystemGray6)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }

            Spacer(minLength: 16)

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
                .background(trimmedApiUrl.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(trimmedApiUrl.isEmpty || isLoading)
            .padding()
        }
        .onAppear {
            recentApiUrls = StorageManager.shared.getApiHistory()
        }
    }

    private var trimmedApiUrl: String {
        apiUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func confirmConfig() {
        AppLogger.debug("[ConfigSetupView] confirmConfig 开始")

        guard !trimmedApiUrl.isEmpty else {
            AppLogger.debug("[ConfigSetupView] apiUrl 为空，返回")
            return
        }

        let urlToSave = trimmedApiUrl
        let completion = onComplete
        isLoading = true

        Task.detached(priority: .userInitiated) {
            AppLogger.debug("[ConfigSetupView] 1. detached task 开始")

            await MainActor.run {
                ApiConfig.shared.apiUrl = urlToSave
                StorageManager.shared.addApiHistory(urlToSave)
            }
            AppLogger.debug("[ConfigSetupView] 2. URL 已保存: \(urlToSave)")

            await MainActor.run {
                AppLogger.debug("[ConfigSetupView] 3. 回到主线程，准备 dismiss")
                self.isLoading = false
                self.dismiss()
                AppLogger.debug("[ConfigSetupView] 4. dismiss 已调用")
            }

            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                AppLogger.debug("[ConfigSetupView] 5. 开始加载配置")
                completion()
            }
        }
    }
}
