import SwiftUI
import WebKit
import CoreImage.CIFilterBuiltins

#if os(macOS) && !targetEnvironment(macCatalyst)
import AppKit
#else
import UIKit
#endif

struct ConfigCenterWebView: View {
    let urlString: String

    @Environment(\.openURL) private var openURL
    @ObservedObject private var apiConfig = ApiConfig.shared
    @StateObject private var store = ConfigCenterStore()
    @State private var showBrowser = false

    private var url: URL? {
        URL(string: urlString)
    }

    private var configCenterServiceURL: URL? {
        guard let url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme != nil,
              components.host != nil else {
            return nil
        }

        // Config center cards can arrive as /website, /full-config, /spider/...,
        // or the original script URL. In this view the origin is already known
        // to be the config-center service, so normalize all valid origins to
        // MiraPlay's local backend path.
        components.path = "/website"
        components.query = nil
        components.fragment = nil
        return components.url
    }

    private var canOpenWebPage: Bool {
        configCenterServiceURL != nil
    }

    private var containsCredentials: Bool {
        guard let url else {
            return false
        }
        return url.user != nil || url.password != nil
    }

    var body: some View {
        List {
            Section {
                headerView
            }

            Section("登录信息") {
                ForEach(ConfigCenterDefinitions.cookieItems) { item in
                    NavigationLink {
                        ConfigCenterCookieEditorView(
                            item: item,
                            store: store,
                            qrURL: absoluteURL(for: item.qrPath),
                            remoteFetchURL: absoluteConfigCenterEndpointURL(for: item.endpoint)
                        )
                    } label: {
                        ConfigCenterRow(
                            iconName: canUseQRCode(item) ? "qrcode" : "key.horizontal",
                            title: item.title,
                            subtitle: item.endpoint,
                            status: isConfigured(store.cookie(for: item.endpoint)) ? "已配置" : "未配置",
                            statusColor: isConfigured(store.cookie(for: item.endpoint)) ? .green : .secondary
                        )
                    }
                }

                ForEach(ConfigCenterDefinitions.accountItems) { item in
                    NavigationLink {
                        ConfigCenterAccountEditorView(
                            item: item,
                            store: store,
                            qrURL: absoluteURL(for: item.qrPath),
                            remoteFetchURL: absoluteConfigCenterEndpointURL(for: item.endpoint)
                        )
                    } label: {
                        ConfigCenterRow(
                            iconName: canUseRemoteQRCode(item.qrPath) ? "qrcode" : "person.crop.circle",
                            title: item.title,
                            subtitle: item.endpoint,
                            status: isAccountConfigured(item.endpoint) ? "已配置" : "未配置",
                            statusColor: isAccountConfigured(item.endpoint) ? .green : .secondary
                        )
                    }
                }
            }

            Section("站源设置") {
                ForEach(ConfigCenterDefinitions.domainItems) { item in
                    NavigationLink {
                        ConfigCenterDomainEditorView(item: item, store: store)
                    } label: {
                        ConfigCenterRow(
                            iconName: "link",
                            title: item.title,
                            subtitle: item.endpoint,
                            status: isConfigured(store.domain(for: item.endpoint)) ? "已设置" : "未设置",
                            statusColor: isConfigured(store.domain(for: item.endpoint)) ? .green : .secondary
                        )
                    }
                }
            }

            Section("网盘与 Emby") {
                NavigationLink {
                    ConfigCenterPanListView(store: store)
                } label: {
                    ConfigCenterRow(
                        iconName: "externaldrive.connected.to.line.below",
                        title: "网盘列表",
                        subtitle: "/pans/list",
                        status: "\(store.enabledPanCount)/\(store.settings.pans.count)",
                        statusColor: .blue
                    )
                }

                NavigationLink {
                    ConfigCenterEmbyListView(store: store)
                } label: {
                    ConfigCenterRow(
                        iconName: "server.rack",
                        title: "Emby 服务",
                        subtitle: "/emby/config",
                        status: "\(store.settings.embyServers.count)",
                        statusColor: .blue
                    )
                }
            }

            Section("来源") {
                addressRow(title: canOpenWebPage ? "网页地址" : "脚本地址", value: urlString)
                if !apiConfig.apiUrl.isEmpty, apiConfig.apiUrl != urlString {
                    addressRow(title: "原始输入", value: apiConfig.apiUrl)
                }

                HStack {
                    Label("已解析站点", systemImage: "list.bullet.rectangle")
                    Spacer()
                    Text("\(apiConfig.sites.count)")
                        .foregroundColor(.secondary)
                }

                if canOpenWebPage {
                    Button {
                        showBrowser = true
                    } label: {
                        Label("网页模式", systemImage: "globe")
                    }
                }
            }
        }
        .tvboxInsetGroupedListStyle()
        .navigationTitle("配置中心")
        .sheet(isPresented: $showBrowser) {
            NavigationStack {
                ConfigCenterBrowserView(urlString: configCenterServiceURL?.absoluteString ?? urlString)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") {
                                showBrowser = false
                            }
                        }
                    }
            }
        }
        .toolbar {
            if let configCenterServiceURL, canOpenWebPage {
                ToolbarItem(placement: .tvboxNavigationBarTrailing) {
                    Button {
                        openURL(configCenterServiceURL)
                    } label: {
                        Image(systemName: "safari")
                    }
                    .accessibilityLabel("在浏览器打开")
                }
            }

            if canOpenWebPage {
                ToolbarItem(placement: .tvboxNavigationBarTrailing) {
                    Button {
                        showBrowser = true
                    } label: {
                        Image(systemName: "globe")
                    }
                    .accessibilityLabel("网页模式")
                }
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 48, height: 48)
                    .background(Color.blue.opacity(0.12))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text("配置中心")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("登录 \(store.configuredLoginCount) 项 · 网盘 \(store.enabledPanCount) 个")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if let displayURL = configCenterServiceURL ?? url {
                HStack(alignment: .top, spacing: 16) {
                    if containsCredentials {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(width: 104, height: 104)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    } else {
                        QRCodeView(text: displayURL.absoluteString)
                            .frame(width: 104, height: 104)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(displayURL.host ?? displayURL.absoluteString)
                            .font(.headline)
                            .lineLimit(2)
                        Text(canOpenWebPage ? "可打开 WebsiteBundle 网页配置页。" : "当前使用 iOS 原生配置；网页登录扫码由本机自动保存。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func absoluteURL(for path: String?) -> URL? {
        guard let path,
              let configCenterServiceURL,
              var components = URLComponents(url: configCenterServiceURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = path
        components.query = nil
        components.fragment = nil
        return components.url
    }

    private func absoluteConfigCenterEndpointURL(for endpoint: String) -> URL? {
        guard let configCenterServiceURL,
              var components = URLComponents(url: configCenterServiceURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let normalizedEndpoint = endpoint.hasPrefix("/") ? endpoint : "/\(endpoint)"
        components.path = normalizedEndpoint.hasPrefix("/website/")
            ? normalizedEndpoint
            : "/website\(normalizedEndpoint)"
        components.query = nil
        components.fragment = nil
        return components.url
    }

    private func canUseRemoteQRCode(_ path: String?) -> Bool {
        path != nil && configCenterServiceURL != nil
    }

    private func canUseQRCode(_ item: ConfigCenterCookieItem) -> Bool {
        canUseRemoteQRCode(item.qrPath)
    }

    private func isConfigured(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isAccountConfigured(_ endpoint: String) -> Bool {
        let account = store.account(for: endpoint)
        return isConfigured(account.username) || isConfigured(account.password)
    }

    private func addressRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(displayAddress(value))
                .font(.caption)
                .textSelection(.enabled)
                .lineLimit(3)
        }
        .contextMenu {
            Button("复制") {
                Clipboard.copy(value)
            }
        }
    }

    private func displayAddress(_ value: String) -> String {
        guard var components = URLComponents(string: value) else {
            return value
        }
        if components.user != nil {
            components.user = "****"
        }
        if components.password != nil {
            components.password = "****"
        }
        return components.string ?? value
    }
}

private struct ConfigCenterRow: View {
    let iconName: String
    let title: String
    let subtitle: String
    let status: String
    let statusColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Text(status)
                .font(.caption)
                .foregroundColor(statusColor)
        }
        .padding(.vertical, 4)
    }
}

private struct ConfigCenterCookieEditorView: View {
    let item: ConfigCenterCookieItem
    @ObservedObject var store: ConfigCenterStore
    let qrURL: URL?
    let remoteFetchURL: URL?

    private var cookieBinding: Binding<String> {
        Binding(
            get: { store.cookie(for: item.endpoint) },
            set: { store.setCookie($0, for: item.endpoint) }
        )
    }

    var body: some View {
        List {
            if let qrURL {
                ConfigCenterQRCodeLoginView(
                    qrURL: qrURL,
                    fetchURL: remoteFetchURL,
                    valueName: item.title
                ) { value in
                    store.setCookie(value, for: item.endpoint)
                }
            }

            if qrURL == nil, item.supportsWebLogin, let loginURL = item.webLoginPageURL {
                Section("网页登录兜底") {
                    NavigationLink {
                        ConfigCenterCookieWebLoginView(
                            item: item,
                            loginURL: loginURL
                        ) { value in
                            store.setCookie(value, for: item.endpoint)
                        }
                    } label: {
                        Label("扫码登录并自动保存", systemImage: "qrcode.viewfinder")
                    }

                    Text("打开 \(item.title) 登录页后完成扫码，iOS 会从网页 Cookie 中自动提取并保存。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Section(item.title) {
                ZStack(alignment: .topLeading) {
                    if store.cookie(for: item.endpoint).isEmpty {
                        Text(item.placeholder)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }
                    TextEditor(text: cookieBinding)
                        .frame(minHeight: 160)
                }

                Button("清除", role: .destructive) {
                    store.setCookie("", for: item.endpoint)
                }
            }

            endpointSection(item.endpoint)
        }
        .tvboxInsetGroupedListStyle()
        .navigationTitle(item.title)
    }

}

private struct ConfigCenterAccountEditorView: View {
    let item: ConfigCenterAccountItem
    @ObservedObject var store: ConfigCenterStore
    let qrURL: URL?
    let remoteFetchURL: URL?

    private var usernameBinding: Binding<String> {
        Binding(
            get: { store.account(for: item.endpoint).username },
            set: { value in
                var account = store.account(for: item.endpoint)
                account.username = value
                store.setAccount(account, for: item.endpoint)
            }
        )
    }

    private var passwordBinding: Binding<String> {
        Binding(
            get: { store.account(for: item.endpoint).password },
            set: { value in
                var account = store.account(for: item.endpoint)
                account.password = value
                store.setAccount(account, for: item.endpoint)
            }
        )
    }

    var body: some View {
        List {
            if let qrURL {
                ConfigCenterQRCodeLoginView(
                    qrURL: qrURL,
                    fetchURL: remoteFetchURL,
                    valueName: item.title
                ) { value in
                    applyFetchedAccount(value)
                }
            }

            Section(item.title) {
                TextField(item.usernamePlaceholder, text: usernameBinding)
                    .textContentType(.username)
                    .tvboxUrlTextInputStyle()

                SecureField(item.passwordPlaceholder, text: passwordBinding)
                    .textContentType(.password)
                    .tvboxUrlTextInputStyle()

                Button("清除", role: .destructive) {
                    store.setAccount(ConfigCenterAccount(), for: item.endpoint)
                }
            }

            endpointSection(item.endpoint)
        }
        .tvboxInsetGroupedListStyle()
        .navigationTitle(item.title)
    }

    private func applyFetchedAccount(_ value: String) {
        var account = ConfigCenterAccount(username: value, password: "")
        if let data = value.data(using: .utf8),
           let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            account.username = payload.ccString("token").ccNilIfEmpty
                ?? payload.ccString("refresh_token").ccNilIfEmpty
                ?? payload.ccString("refreshToken").ccNilIfEmpty
                ?? payload.ccString("username").ccNilIfEmpty
                ?? value
            account.password = payload.ccString("open_token").ccNilIfEmpty
                ?? payload.ccString("openToken").ccNilIfEmpty
                ?? payload.ccString("password").ccNilIfEmpty
                ?? ""
        }
        store.setAccount(account, for: item.endpoint)
    }
}

private struct ConfigCenterQRCodeLoginView: View {
    let qrURL: URL
    let fetchURL: URL?
    let valueName: String
    let onFetched: (String) -> Void

    @State private var isFetching = false
    @State private var qrPayload: ConfigCenterQRCodePayload = .loading
    @State private var qrLoadTask: Task<Void, Never>?
    @State private var statusText = "请用对应 App 扫码登录。"
    @State private var autoFetchTask: Task<Void, Never>?

    private var canFetchValue: Bool {
        fetchURL != nil && qrPayload.isReady
    }

    var body: some View {
        Section("扫码登录") {
            HStack {
                Spacer()
                qrPayloadView
                .frame(width: 180, height: 180)
                Spacer()
            }

            HStack {
                Button {
                    Task {
                        await fetchAndStore(showErrors: true)
                    }
                } label: {
                    HStack {
                        if isFetching {
                            ProgressView()
                        }
                        Text("扫码后获取并保存")
                    }
                }
                .disabled(!canFetchValue || isFetching)

                Button {
                    reloadQRCode()
                } label: {
                    Label("刷新二维码", systemImage: "arrow.clockwise")
                }
                .disabled(qrLoadTask != nil)
            }

            Text(fetchURL == nil ? "当前地址无法调用配置中心登录接口。" : statusText)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .onAppear {
            loadQRCode()
        }
        .onDisappear {
            qrLoadTask?.cancel()
            qrLoadTask = nil
            stopAutoFetch()
        }
    }

    private func reloadQRCode() {
        qrLoadTask?.cancel()
        qrLoadTask = nil
        stopAutoFetch()
        qrPayload = .loading
        statusText = "正在刷新二维码..."
        loadQRCode()
    }

    @ViewBuilder
    private var qrPayloadView: some View {
        switch qrPayload {
        case .loading:
            VStack(spacing: 10) {
                ProgressView()
                Text("正在加载二维码")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        case .image(let image):
            PlatformImageView(image: image)
                .padding(8)
                .background(Color.white)
                .cornerRadius(8)
        case .text(let text):
            QRCodeView(text: text)
        case .failed(let message):
            VStack(spacing: 8) {
                Image(systemName: "qrcode")
                    .font(.system(size: 56))
                    .foregroundColor(.secondary)
                Text(message)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
            .padding(8)
        }
    }

    @MainActor
    private func loadQRCode() {
        guard qrLoadTask == nil else {
            return
        }

        statusText = "正在加载二维码..."
        qrLoadTask = Task {
            do {
                let payload = try await ConfigCenterRemoteQRCode.fetchPayload(from: qrURL)
                await MainActor.run {
                    qrPayload = payload
                    qrLoadTask = nil
                    statusText = fetchURL == nil
                        ? "二维码已加载，但当前地址无法调用扫码结果接口。"
                        : "二维码已加载，请扫码；扫码完成后会自动获取并保存。"
                    startAutoFetch()
                }
            } catch {
                await MainActor.run {
                    let message = AppErrorMessage.userMessage(for: error)
                    qrPayload = .failed(message)
                    statusText = "二维码加载失败：\(message)"
                    qrLoadTask = nil
                }
            }
        }
    }

    @MainActor
    private func startAutoFetch() {
        guard canFetchValue, autoFetchTask == nil else {
            return
        }

        autoFetchTask = Task {
            for _ in 0..<40 {
                if Task.isCancelled {
                    return
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if Task.isCancelled {
                    return
                }
                await fetchAndStore(showErrors: false)
                if Task.isCancelled {
                    return
                }
            }

            await MainActor.run {
                if autoFetchTask != nil {
                    statusText = "自动检测超时，可扫码后手动点击获取。"
                    autoFetchTask = nil
                }
            }
        }
    }

    @MainActor
    private func stopAutoFetch() {
        autoFetchTask?.cancel()
        autoFetchTask = nil
    }

    @MainActor
    private func fetchAndStore(showErrors: Bool) async {
        guard let fetchURL else {
            statusText = "当前地址无法调用配置中心登录接口。"
            return
        }
        guard qrPayload.isReady else {
            statusText = "二维码还没有加载完成，请稍后再试。"
            return
        }
        guard !isFetching else {
            return
        }

        isFetching = true
        defer { isFetching = false }

        do {
            let value = try await ConfigCenterRemoteLogin.fetchValue(from: fetchURL)
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                if showErrors {
                    statusText = "暂未获取到 \(valueName)，请确认扫码已完成。"
                }
                return
            }

            onFetched(trimmed)
            statusText = "已获取并保存 \(valueName)。"
            stopAutoFetch()
        } catch {
            if showErrors {
                statusText = AppErrorMessage.userMessage(for: error)
            }
        }
    }
}

private struct ConfigCenterCookieWebLoginView: View {
    let item: ConfigCenterCookieItem
    let loginURL: URL
    let onFetched: (String) -> Void

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var hasSaved = false
    @State private var statusText = "请在网页中完成扫码或登录。"
    @State private var autoCollectTask: Task<Void, Never>?

    private var requiredCookieDescription: String {
        item.requiredCookieNames.isEmpty ? "登录 Cookie" : item.requiredCookieNames.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 0) {
            statusBar

            ZStack {
                ConfigCenterWebContainer(
                    url: loginURL,
                    isLoading: $isLoading,
                    errorMessage: $errorMessage
                )
                .ignoresSafeArea(.container, edges: .bottom)

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding(18)
                        .background(.regularMaterial)
                        .cornerRadius(8)
                }

                if let errorMessage {
                    webErrorView(errorMessage)
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button {
                    Task {
                        await saveCurrentCookie(manual: true)
                    }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                        }
                        Text("保存当前 Cookie")
                    }
                }
                .disabled(isSaving)

                if hasSaved {
                    Label("已保存", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }

                Spacer()
            }
            .padding(12)
        }
        .navigationTitle(item.title)
        .onAppear {
            startAutoCollect()
        }
        .onDisappear {
            stopAutoCollect()
        }
    }

    private var statusBar: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: hasSaved ? "checkmark.circle.fill" : "qrcode.viewfinder")
                .foregroundColor(hasSaved ? .green : .blue)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(statusText)
                    .font(.footnote)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(loginURL.host ?? loginURL.absoluteString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func webErrorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(.orange)
            Text("网页登录页加载失败")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(8)
        .padding()
    }

    @MainActor
    private func startAutoCollect() {
        guard autoCollectTask == nil else {
            return
        }

        statusText = "请在网页中扫码登录，正在等待 \(requiredCookieDescription)。"
        autoCollectTask = Task {
            for _ in 0..<90 {
                if Task.isCancelled {
                    return
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if Task.isCancelled {
                    return
                }

                let collected = await ConfigCenterCookieCollector.collect(
                    domains: item.cookieDomains,
                    requiredCookieNames: item.requiredCookieNames
                )
                await MainActor.run {
                    applyCollectedCookie(collected, manual: false)
                }

                if collected.hasRequiredCookies {
                    return
                }
            }

            await MainActor.run {
                if autoCollectTask != nil {
                    statusText = "自动检测超时，可登录后手动保存当前 Cookie。"
                    autoCollectTask = nil
                }
            }
        }
    }

    @MainActor
    private func stopAutoCollect() {
        autoCollectTask?.cancel()
        autoCollectTask = nil
    }

    @MainActor
    private func saveCurrentCookie(manual: Bool) async {
        guard !isSaving else {
            return
        }

        isSaving = true
        defer { isSaving = false }

        let collected = await ConfigCenterCookieCollector.collect(
            domains: item.cookieDomains,
            requiredCookieNames: item.requiredCookieNames
        )
        applyCollectedCookie(collected, manual: manual)
    }

    @MainActor
    private func applyCollectedCookie(_ collected: ConfigCenterCollectedCookie, manual: Bool) {
        guard !collected.cookieHeader.isEmpty else {
            if manual {
                statusText = "当前网页还没有可保存的 \(item.title) Cookie。"
            }
            return
        }

        guard manual || collected.hasRequiredCookies || item.requiredCookieNames.isEmpty else {
            statusText = "已读取到 \(collected.cookieCount) 个 Cookie，继续等待 \(requiredCookieDescription)。"
            return
        }

        onFetched(collected.cookieHeader)
        hasSaved = true
        if collected.hasRequiredCookies {
            statusText = "已获取并保存 \(item.title)。"
        } else {
            statusText = "已保存当前网页 Cookie；如果播放仍失败，请重新扫码后再保存。"
        }
        stopAutoCollect()
    }
}

private struct ConfigCenterCollectedCookie {
    let cookieHeader: String
    let hasRequiredCookies: Bool
    let cookieCount: Int
}

private enum ConfigCenterCookieCollector {
    static func collect(domains: [String], requiredCookieNames: [String]) async -> ConfigCenterCollectedCookie {
        let now = Date()
        let normalizedDomains = domains.map(normalizedDomain).filter { !$0.isEmpty }
        let cookies = await allCookies()
        let matchedCookies = cookies.filter { cookie in
            if let expiresDate = cookie.expiresDate, expiresDate <= now {
                return false
            }
            return normalizedDomains.contains { domainMatches(cookieDomain: cookie.domain, targetDomain: $0) }
        }
        let uniqueCookies = deduplicatedCookies(matchedCookies)
        let cookieHeader = uniqueCookies
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "; ")
        let lowerNames = Set(uniqueCookies.map { $0.name.lowercased() })
        let requiredNames = requiredCookieNames.map { $0.lowercased() }
        let hasRequiredCookies = requiredNames.isEmpty
            ? !uniqueCookies.isEmpty
            : requiredNames.allSatisfy { lowerNames.contains($0) }

        return ConfigCenterCollectedCookie(
            cookieHeader: cookieHeader,
            hasRequiredCookies: hasRequiredCookies,
            cookieCount: uniqueCookies.count
        )
    }

    @MainActor
    private static func allCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }

    private static func deduplicatedCookies(_ cookies: [HTTPCookie]) -> [HTTPCookie] {
        let sortedCookies = cookies.sorted { lhs, rhs in
            let lhsScore = specificityScore(lhs)
            let rhsScore = specificityScore(rhs)
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            return lhs.name < rhs.name
        }

        var seenNames = Set<String>()
        return sortedCookies.filter { cookie in
            seenNames.insert(cookie.name).inserted
        }
        .sorted { $0.name < $1.name }
    }

    private static func specificityScore(_ cookie: HTTPCookie) -> Int {
        normalizedDomain(cookie.domain).count * 1_000 + cookie.path.count
    }

    private static func domainMatches(cookieDomain: String, targetDomain: String) -> Bool {
        let normalizedCookieDomain = normalizedDomain(cookieDomain)
        guard !normalizedCookieDomain.isEmpty, !targetDomain.isEmpty else {
            return false
        }

        return normalizedCookieDomain == targetDomain ||
            normalizedCookieDomain.hasSuffix(".\(targetDomain)") ||
            targetDomain.hasSuffix(".\(normalizedCookieDomain)")
    }

    private static func normalizedDomain(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
    }
}

private enum ConfigCenterQRCodePayload {
    case loading
    case image(TVBoxQRCodeImage)
    case text(String)
    case failed(String)

    var isReady: Bool {
        switch self {
        case .image, .text:
            return true
        case .loading, .failed:
            return false
        }
    }
}

private enum ConfigCenterRemoteQRCode {
    static func fetchPayload(from url: URL) async throws -> ConfigCenterQRCodePayload {
        var request = ConfigCenterAuthenticatedRequest.make(url: url, method: "GET")
        request.setValue("image/*, application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ConfigCenterRemoteLoginError.httpStatus(statusCode)
        }

        if let image = TVBoxQRCodeImage(data: data) {
            return .image(image)
        }

        if let object = try? JSONSerialization.jsonObject(with: data),
           let value = extractQRCodeValue(from: object).ccNilIfEmpty {
            return payload(from: value)
        }

        if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return payload(from: text)
        }

        throw ConfigCenterRemoteLoginError.remoteMessage("二维码接口没有返回可显示内容")
    }

    private static func payload(from value: String) -> ConfigCenterQRCodePayload {
        if let image = imageFromDataURL(value) {
            return .image(image)
        }
        return .text(value)
    }

    private static func extractQRCodeValue(from object: Any) -> String {
        if let string = object as? String {
            return string
        }
        if let number = object as? NSNumber {
            return number.stringValue
        }
        if let dict = object as? [String: Any] {
            for key in [
                "qrcode", "qrCode", "qr_code", "qr",
                "url", "loginUrl", "login_url", "qrUrl", "qr_url",
                "content", "value", "image", "data"
            ] {
                guard let value = dict[key] else {
                    continue
                }
                let extracted = extractQRCodeValue(from: value)
                if !extracted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return extracted
                }
            }
        }
        if let array = object as? [Any] {
            for value in array {
                let extracted = extractQRCodeValue(from: value)
                if !extracted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return extracted
                }
            }
        }
        return ""
    }

    private static func imageFromDataURL(_ value: String) -> TVBoxQRCodeImage? {
        guard let commaIndex = value.firstIndex(of: ","),
              value[..<commaIndex].lowercased().contains("base64") else {
            return nil
        }

        let base64 = String(value[value.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: base64) else {
            return nil
        }
        return TVBoxQRCodeImage(data: data)
    }
}

private enum ConfigCenterRemoteLogin {
    static func fetchValue(from url: URL) async throws -> String {
        var request = ConfigCenterAuthenticatedRequest.make(url: url, method: "POST")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ConfigCenterRemoteLoginError.httpStatus(statusCode)
        }

        if let object = try? JSONSerialization.jsonObject(with: data) {
            return try extractValue(from: object)
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func extractValue(from object: Any) throws -> String {
        if let string = object as? String {
            return string
        }
        if let number = object as? NSNumber {
            return number.stringValue
        }
        if let dict = object as? [String: Any] {
            if let code = dict.ccInt("code"), code != 0 {
                throw ConfigCenterRemoteLoginError.remoteMessage(
                    dict.ccString("message").ccNilIfEmpty
                        ?? dict.ccString("msg").ccNilIfEmpty
                        ?? "扫码登录接口返回 code=\(code)"
                )
            }
            if let data = dict["data"] {
                return try extractValue(from: data)
            }
            for key in ["cookie", "token", "refresh_token", "refreshToken", "open_token", "openToken", "value"] {
                if let value = dict.ccString(key).ccNilIfEmpty {
                    return value
                }
            }
            return jsonString(dict)
        }
        if let array = object as? [Any] {
            return jsonString(array)
        }
        return ""
    }

    private static func jsonString(_ object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }
}

private enum ConfigCenterAuthenticatedRequest {
    static func make(url: URL, method: String) -> URLRequest {
        var requestURL = url
        if var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           components.user != nil {
            components.user = nil
            components.password = nil
            requestURL = components.url ?? url
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method

        if let authorization = basicAuthorizationHeader(for: url) {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private static func basicAuthorizationHeader(for url: URL) -> String? {
        guard let user = url.user, !user.isEmpty else {
            return nil
        }

        let password = url.password ?? ""
        let credentials = "\(user):\(password)"
        guard let data = credentials.data(using: .utf8) else {
            return nil
        }
        return "Basic \(data.base64EncodedString())"
    }
}

private enum ConfigCenterRemoteLoginError: LocalizedError {
    case httpStatus(Int)
    case remoteMessage(String)

    var errorDescription: String? {
        switch self {
        case .httpStatus(let status):
            return "扫码登录接口请求失败: HTTP \(status)"
        case .remoteMessage(let message):
            return message
        }
    }
}

private extension Dictionary where Key == String, Value == Any {
    func ccString(_ key: String) -> String {
        if let value = self[key] as? String {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.stringValue
        }
        return ""
    }

    func ccInt(_ key: String) -> Int? {
        if let value = self[key] as? Int {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.intValue
        }
        if let value = self[key] as? String {
            return Int(value)
        }
        return nil
    }
}

private extension String {
    var ccNilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private struct ConfigCenterDomainEditorView: View {
    let item: ConfigCenterDomainItem
    @ObservedObject var store: ConfigCenterStore

    private var domainBinding: Binding<String> {
        Binding(
            get: { store.domain(for: item.endpoint) },
            set: { store.setDomain($0, for: item.endpoint) }
        )
    }

    var body: some View {
        List {
            Section(item.title) {
                TextField(item.placeholder, text: domainBinding)
                    .textContentType(.URL)
                    .tvboxUrlTextInputStyle()

                Button("清除", role: .destructive) {
                    store.setDomain("", for: item.endpoint)
                }
            }

            endpointSection(item.endpoint)
        }
        .tvboxInsetGroupedListStyle()
        .navigationTitle(item.title)
    }
}

private struct ConfigCenterPanListView: View {
    @ObservedObject var store: ConfigCenterStore

    var body: some View {
        List {
            Section {
                ForEach(store.settings.pans) { pan in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("名称", text: panNameBinding(for: pan.key))
                            Text(pan.key)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Toggle("", isOn: panEnabledBinding(for: pan.key))
                            .labelsHidden()
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Button("恢复默认") {
                    store.resetPans()
                }
            }
        }
        .tvboxInsetGroupedListStyle()
        .navigationTitle("网盘列表")
    }

    private func panNameBinding(for key: String) -> Binding<String> {
        Binding(
            get: { store.settings.pans.first { $0.key == key }?.name ?? "" },
            set: { store.setPanName($0, for: key) }
        )
    }

    private func panEnabledBinding(for key: String) -> Binding<Bool> {
        Binding(
            get: { store.settings.pans.first { $0.key == key }?.isEnabled ?? false },
            set: { store.setPanEnabled($0, for: key) }
        )
    }
}

private struct ConfigCenterEmbyListView: View {
    @ObservedObject var store: ConfigCenterStore

    var body: some View {
        List {
            Section {
                if store.settings.embyServers.isEmpty {
                    Text("暂无 Emby 服务")
                        .foregroundColor(.secondary)
                }

                ForEach(store.settings.embyServers) { server in
                    NavigationLink {
                        ConfigCenterEmbyEditorView(server: serverBinding(for: server.id))
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(server.servername.isEmpty ? "未命名服务" : server.servername)
                                Text(server.serverurl.isEmpty ? "未设置地址" : server.serverurl)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if server.isChosen {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteServers)
            }

            Section {
                Button {
                    addServer()
                } label: {
                    Label("添加服务", systemImage: "plus")
                }
            }
        }
        .tvboxInsetGroupedListStyle()
        .navigationTitle("Emby 服务")
    }

    private func serverBinding(for id: String) -> Binding<ConfigCenterEmbyServer> {
        Binding(
            get: {
                store.settings.embyServers.first { $0.id == id } ?? ConfigCenterEmbyServer()
            },
            set: { updated in
                var servers = store.settings.embyServers
                guard let index = servers.firstIndex(where: { $0.id == id }) else {
                    return
                }
                servers[index] = updated
                if updated.isChosen {
                    for serverIndex in servers.indices where serverIndex != index {
                        servers[serverIndex].isChosen = false
                    }
                }
                store.setEmbyServers(servers)
            }
        )
    }

    private func addServer() {
        var servers = store.settings.embyServers
        var server = ConfigCenterEmbyServer()
        server.servername = "Emby"
        server.isChosen = servers.isEmpty
        servers.append(server)
        store.setEmbyServers(servers)
    }

    private func deleteServers(_ offsets: IndexSet) {
        var servers = store.settings.embyServers
        servers.remove(atOffsets: offsets)
        store.setEmbyServers(servers)
    }
}

private struct ConfigCenterEmbyEditorView: View {
    @Binding var server: ConfigCenterEmbyServer

    var body: some View {
        List {
            Section("服务") {
                TextField("名称", text: $server.servername)
                    .tvboxUrlTextInputStyle()
                TextField("地址", text: $server.serverurl)
                    .textContentType(.URL)
                    .tvboxUrlTextInputStyle()
            }

            Section("登录") {
                TextField("账号", text: $server.username)
                    .textContentType(.username)
                    .tvboxUrlTextInputStyle()
                SecureField("密码", text: $server.password)
                    .textContentType(.password)
                    .tvboxUrlTextInputStyle()
            }

            Section {
                Toggle("默认服务", isOn: $server.isChosen)
            }
        }
        .tvboxInsetGroupedListStyle()
        .navigationTitle(server.servername.isEmpty ? "Emby 服务" : server.servername)
    }
}

private func endpointSection(_ endpoint: String) -> some View {
    Section("接口") {
        Text(endpoint)
            .font(.caption)
            .foregroundColor(.secondary)
            .textSelection(.enabled)
            .contextMenu {
                Button("复制") {
                    Clipboard.copy(endpoint)
                }
            }
    }
}

struct ConfigCenterBrowserView: View {
    let urlString: String

    @State private var isLoading = true
    @State private var errorMessage: String?

    private var url: URL? {
        URL(string: urlString)
    }

    var body: some View {
        ZStack {
            if let url {
                ConfigCenterWebContainer(
                    url: url,
                    isLoading: $isLoading,
                    errorMessage: $errorMessage
                )
                .ignoresSafeArea(.container, edges: .bottom)
            } else {
                invalidURLView
            }

            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(18)
                    .background(.regularMaterial)
                    .cornerRadius(8)
            }

            if let errorMessage {
                errorView(errorMessage)
            }
        }
        .navigationTitle("网页模式")
    }

    private var invalidURLView: some View {
        VStack(spacing: 12) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(.orange)
            Text("配置中心地址无效")
                .font(.headline)
            Text(urlString)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(.orange)
            Text("配置中心加载失败")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(8)
        .padding()
    }
}

private struct QRCodeView: View {
    let text: String

    var body: some View {
        Group {
            if let image = QRCodeGenerator.image(from: text) {
                PlatformImageView(image: image)
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.white)
        .cornerRadius(8)
    }
}

#if os(macOS) && !targetEnvironment(macCatalyst)
private typealias TVBoxQRCodeImage = NSImage

private struct PlatformImageView: View {
    let image: TVBoxQRCodeImage

    var body: some View {
        Image(nsImage: image)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
    }
}
#else
private typealias TVBoxQRCodeImage = UIImage

private struct PlatformImageView: View {
    let image: TVBoxQRCodeImage

    var body: some View {
        Image(uiImage: image)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
    }
}
#endif

private enum QRCodeGenerator {
    private static let context = CIContext()

    static func image(from text: String) -> TVBoxQRCodeImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        #if os(macOS) && !targetEnvironment(macCatalyst)
        return NSImage(cgImage: cgImage, size: NSSize(width: scaledImage.extent.width, height: scaledImage.extent.height))
        #else
        return UIImage(cgImage: cgImage)
        #endif
    }
}

private enum Clipboard {
    static func copy(_ value: String) {
        #if os(macOS) && !targetEnvironment(macCatalyst)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        #else
        UIPasteboard.general.string = value
        #endif
    }
}

#if os(macOS) && !targetEnvironment(macCatalyst)
private struct ConfigCenterWebContainer: NSViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, errorMessage: $errorMessage)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedURL != url else {
            return
        }

        context.coordinator.loadedURL = url
        errorMessage = nil
        isLoading = true
        webView.load(URLRequest(url: url))
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedURL: URL?

        @Binding private var isLoading: Bool
        @Binding private var errorMessage: String?

        init(isLoading: Binding<Bool>, errorMessage: Binding<String?>) {
            _isLoading = isLoading
            _errorMessage = errorMessage
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
            errorMessage = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            errorMessage = error.localizedDescription
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}
#else
private struct ConfigCenterWebContainer: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, errorMessage: $errorMessage)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedURL != url else {
            return
        }

        context.coordinator.loadedURL = url
        errorMessage = nil
        isLoading = true
        webView.load(URLRequest(url: url))
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedURL: URL?

        @Binding private var isLoading: Bool
        @Binding private var errorMessage: String?

        init(isLoading: Binding<Bool>, errorMessage: Binding<String?>) {
            _isLoading = isLoading
            _errorMessage = errorMessage
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
            errorMessage = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            errorMessage = error.localizedDescription
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}
#endif
