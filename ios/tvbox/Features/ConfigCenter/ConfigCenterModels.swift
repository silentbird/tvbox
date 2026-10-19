import Combine
import Foundation
import Security

struct ConfigCenterCookieItem: Identifiable {
    let id: String
    let title: String
    let endpoint: String
    let qrPath: String?
    let placeholder: String
    let webLoginURL: String?
    let cookieDomains: [String]
    let requiredCookieNames: [String]

    init(
        id: String,
        title: String,
        endpoint: String,
        qrPath: String? = nil,
        placeholder: String,
        webLoginURL: String? = nil,
        cookieDomains: [String] = [],
        requiredCookieNames: [String] = []
    ) {
        self.id = id
        self.title = title
        self.endpoint = endpoint
        self.qrPath = qrPath
        self.placeholder = placeholder
        self.webLoginURL = webLoginURL
        self.cookieDomains = cookieDomains
        self.requiredCookieNames = requiredCookieNames
    }

    var webLoginPageURL: URL? {
        guard let webLoginURL else {
            return nil
        }
        return URL(string: webLoginURL)
    }

    var supportsWebLogin: Bool {
        webLoginPageURL != nil && !cookieDomains.isEmpty
    }
}

struct ConfigCenterAccountItem: Identifiable {
    let id: String
    let title: String
    let endpoint: String
    let qrPath: String?
    let usernameLabel: String
    let passwordLabel: String
    let usernamePlaceholder: String
    let passwordPlaceholder: String

    init(
        id: String,
        title: String,
        endpoint: String,
        qrPath: String? = nil,
        usernameLabel: String = "账号",
        passwordLabel: String = "密码",
        usernamePlaceholder: String = "请输入账号",
        passwordPlaceholder: String = "请输入密码"
    ) {
        self.id = id
        self.title = title
        self.endpoint = endpoint
        self.qrPath = qrPath
        self.usernameLabel = usernameLabel
        self.passwordLabel = passwordLabel
        self.usernamePlaceholder = usernamePlaceholder
        self.passwordPlaceholder = passwordPlaceholder
    }
}

struct ConfigCenterDomainItem: Identifiable {
    let id: String
    let title: String
    let endpoint: String
    let placeholder: String
}

struct ConfigCenterAccount: Codable, Equatable {
    var username: String = ""
    var password: String = ""
}

struct ConfigCenterPan: Codable, Equatable, Identifiable {
    var id: String { key }

    let key: String
    var name: String
    var isEnabled: Bool
}

struct ConfigCenterEmbyServer: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var servername: String = ""
    var serverurl: String = ""
    var username: String = ""
    var password: String = ""
    var isChosen: Bool = false
}

struct ConfigCenterSettings: Codable, Equatable {
    var cookies: [String: String] = [:]
    var accounts: [String: ConfigCenterAccount] = [:]
    var domains: [String: String] = [:]
    var pans: [ConfigCenterPan] = ConfigCenterDefinitions.defaultPans
    var embyServers: [ConfigCenterEmbyServer] = []
}

enum ConfigCenterDefinitions {
    static let cookieItems: [ConfigCenterCookieItem] = [
        ConfigCenterCookieItem(
            id: "baidu",
            title: "百度",
            endpoint: "/baidu/cookie",
            qrPath: "/website/baidu/qrcode",
            placeholder: "请粘贴百度 Cookie",
            webLoginURL: "https://pan.baidu.com",
            cookieDomains: ["baidu.com", "pan.baidu.com"],
            requiredCookieNames: ["BDUSS"]
        ),
        ConfigCenterCookieItem(
            id: "quark",
            title: "夸克",
            endpoint: "/quark/cookie",
            qrPath: "/website/quark/qrcode",
            placeholder: "请粘贴夸克 Cookie",
            webLoginURL: "https://pan.quark.cn",
            cookieDomains: ["quark.cn", "pan.quark.cn"],
            requiredCookieNames: ["__puus"]
        ),
        ConfigCenterCookieItem(
            id: "uc-cookie",
            title: "UC Cookie",
            endpoint: "/uc/cookie",
            qrPath: "/website/uc/qrcode",
            placeholder: "请粘贴 UC Cookie",
            webLoginURL: "https://drive.uc.cn",
            cookieDomains: ["uc.cn", "drive.uc.cn"],
            requiredCookieNames: ["__puus"]
        ),
        ConfigCenterCookieItem(id: "uc-token", title: "UC token", endpoint: "/uc-tv/token", qrPath: "/website/uc-tv/qrcode", placeholder: "请粘贴 UC token"),
        ConfigCenterCookieItem(
            id: "115",
            title: "115",
            endpoint: "/115/cookie",
            qrPath: "/website/115/qrcode",
            placeholder: "请粘贴 115 Cookie",
            webLoginURL: "https://115.com",
            cookieDomains: ["115.com"],
            requiredCookieNames: ["UID", "CID", "SEID"]
        ),
        ConfigCenterCookieItem(
            id: "bili",
            title: "Bili Cookie",
            endpoint: "/bili/cookie",
            qrPath: "/website/bili/qrcode",
            placeholder: "请粘贴 Bili Cookie",
            webLoginURL: "https://www.bilibili.com",
            cookieDomains: ["bilibili.com", "www.bilibili.com"],
            requiredCookieNames: ["SESSDATA"]
        ),
        ConfigCenterCookieItem(id: "pan123ziyuan", title: "123资源网 Cookie", endpoint: "/pan123ziyuan/cookie", qrPath: nil, placeholder: "请粘贴 123资源网 Cookie"),
        ConfigCenterCookieItem(id: "wuming", title: "无名 Cookie", endpoint: "/wuming/cookie", qrPath: nil, placeholder: "请粘贴无名 Cookie")
    ]

    static let accountItems: [ConfigCenterAccountItem] = [
        ConfigCenterAccountItem(id: "tianyi", title: "天翼", endpoint: "/tianyi/account"),
        ConfigCenterAccountItem(id: "pan123", title: "123", endpoint: "/pan123/account"),
        ConfigCenterAccountItem(id: "yunchao", title: "云巢", endpoint: "/yunchao/account"),
        ConfigCenterAccountItem(id: "leijing", title: "雷鲸账号", endpoint: "/leijinguser/account"),
        ConfigCenterAccountItem(
            id: "ali",
            title: "阿里 Token",
            endpoint: "/ali/token",
            qrPath: "/website/ali/qrcode",
            usernameLabel: "Token",
            passwordLabel: "OpenToken",
            usernamePlaceholder: "请粘贴阿里 refresh token",
            passwordPlaceholder: "请粘贴阿里 open token"
        )
    ]

    static let domainItems: [ConfigCenterDomainItem] = [
        ConfigCenterDomainItem(id: "muou", title: "木偶域名", endpoint: "/muou/url", placeholder: "请输入木偶域名"),
        ConfigCenterDomainItem(id: "wogg", title: "玩偶域名", endpoint: "/wogg/url", placeholder: "请输入玩偶域名"),
        ConfigCenterDomainItem(id: "leijing", title: "雷鲸域名", endpoint: "/leijing/url", placeholder: "请输入雷鲸域名"),
        ConfigCenterDomainItem(id: "livetovod", title: "直播地址", endpoint: "/livetovod/url", placeholder: "请输入直播地址")
    ]

    static let defaultPans: [ConfigCenterPan] = [
        ConfigCenterPan(key: "baidu", name: "百度", isEnabled: true),
        ConfigCenterPan(key: "quark", name: "夸父", isEnabled: true),
        ConfigCenterPan(key: "123miao", name: "123原画(秒传)", isEnabled: true),
        ConfigCenterPan(key: "uc", name: "优夕", isEnabled: true),
        ConfigCenterPan(key: "tianyi", name: "天意", isEnabled: true),
        ConfigCenterPan(key: "yidong", name: "逸动", isEnabled: true),
        ConfigCenterPan(key: "123", name: "Pan123", isEnabled: true),
        ConfigCenterPan(key: "115", name: "Pan115", isEnabled: true),
        ConfigCenterPan(key: "ali", name: "阿狸", isEnabled: true)
    ]
}

final class ConfigCenterStore: ObservableObject {
    @Published private(set) var settings: ConfigCenterSettings

    init() {
        settings = Self.savedSettings()
    }

    static func savedSettings() -> ConfigCenterSettings {
        var settings = ConfigCenterSecureStorage.load() ?? ConfigCenterSettings()
        settings.pans = normalizedPans(settings.pans)
        return settings
    }

    var configuredLoginCount: Int {
        let cookieCount = settings.cookies.values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        let accountCount = settings.accounts.values.filter {
            !$0.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !$0.password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        return cookieCount + accountCount
    }

    var enabledPanCount: Int {
        settings.pans.filter(\.isEnabled).count
    }

    func cookie(for endpoint: String) -> String {
        settings.cookies[endpoint] ?? ""
    }

    func setCookie(_ value: String, for endpoint: String) {
        update { $0.cookies[endpoint] = value }
    }

    func account(for endpoint: String) -> ConfigCenterAccount {
        settings.accounts[endpoint] ?? ConfigCenterAccount()
    }

    func setAccount(_ value: ConfigCenterAccount, for endpoint: String) {
        update { $0.accounts[endpoint] = value }
    }

    func domain(for endpoint: String) -> String {
        settings.domains[endpoint] ?? ""
    }

    func setDomain(_ value: String, for endpoint: String) {
        update { $0.domains[endpoint] = value }
    }

    func setPanName(_ name: String, for key: String) {
        update { settings in
            guard let index = settings.pans.firstIndex(where: { $0.key == key }) else { return }
            settings.pans[index].name = name
        }
    }

    func setPanEnabled(_ isEnabled: Bool, for key: String) {
        update { settings in
            guard let index = settings.pans.firstIndex(where: { $0.key == key }) else { return }
            settings.pans[index].isEnabled = isEnabled
        }
    }

    func resetPans() {
        update { $0.pans = ConfigCenterDefinitions.defaultPans }
    }

    func setEmbyServers(_ servers: [ConfigCenterEmbyServer]) {
        update { $0.embyServers = servers }
    }

    private static func normalizedPans(_ pans: [ConfigCenterPan]) -> [ConfigCenterPan] {
        let defaultPans = ConfigCenterDefinitions.defaultPans
        guard !pans.isEmpty else {
            return defaultPans
        }

        let defaultKeys = Set(defaultPans.map(\.key))
        let existingPans = pans.filter { defaultKeys.contains($0.key) }
        let missingPans = defaultPans.filter { defaultPan in
            !existingPans.contains { $0.key == defaultPan.key }
        }
        return existingPans + missingPans
    }

    private func update(_ mutation: (inout ConfigCenterSettings) -> Void) {
        objectWillChange.send()
        mutation(&settings)
        settings.pans = Self.normalizedPans(settings.pans)
        ConfigCenterSecureStorage.save(settings)
    }
}

struct ConfigCenterPanCredential: Equatable {
    let key: String
    let name: String
    let isEnabled: Bool
    var cookie: String = ""
    var token: String = ""
    var openToken: String = ""
    var username: String = ""
    var password: String = ""

    var hasCredential: Bool {
        !cookie.isEmpty ||
            !token.isEmpty ||
            !openToken.isEmpty ||
            !username.isEmpty ||
            !password.isEmpty
    }
}

enum ConfigCenterRuntime {
    static func settings() -> ConfigCenterSettings {
        ConfigCenterStore.savedSettings()
    }

    static func cookie(for endpoint: String) -> String {
        trimmed(settings().cookies[endpoint])
    }

    static func account(for endpoint: String) -> ConfigCenterAccount {
        let account = settings().accounts[endpoint] ?? ConfigCenterAccount()
        return ConfigCenterAccount(
            username: trimmed(account.username),
            password: trimmed(account.password)
        )
    }

    static func domain(for endpoint: String) -> String {
        trimmed(settings().domains[endpoint])
    }

    static func enabledPanKeys() -> [String] {
        settings().pans.filter(\.isEnabled).map(\.key)
    }

    static func panCredential(for key: String) -> ConfigCenterPanCredential? {
        let currentSettings = settings()
        guard let pan = currentSettings.pans.first(where: { $0.key == key }) else {
            return nil
        }

        var credential = ConfigCenterPanCredential(
            key: pan.key,
            name: pan.name,
            isEnabled: pan.isEnabled
        )

        switch key {
        case "baidu":
            credential.cookie = cookie("/baidu/cookie", in: currentSettings)
        case "quark":
            credential.cookie = cookie("/quark/cookie", in: currentSettings)
        case "uc":
            credential.cookie = cookie("/uc/cookie", in: currentSettings)
            credential.token = cookie("/uc-tv/token", in: currentSettings)
        case "115":
            credential.cookie = cookie("/115/cookie", in: currentSettings)
        case "tianyi":
            let account = account("/tianyi/account", in: currentSettings)
            credential.username = account.username
            credential.password = account.password
        case "123", "123miao":
            let account = account("/pan123/account", in: currentSettings)
            credential.username = account.username
            credential.password = account.password
        case "ali":
            let account = account("/ali/token", in: currentSettings)
            credential.token = account.username
            credential.openToken = account.password
        default:
            break
        }

        return credential
    }

    static func enabledPanCredentials() -> [ConfigCenterPanCredential] {
        settings().pans.compactMap { pan in
            pan.isEnabled ? panCredential(for: pan.key) : nil
        }
    }

    private static func cookie(_ endpoint: String, in settings: ConfigCenterSettings) -> String {
        trimmed(settings.cookies[endpoint])
    }

    private static func account(_ endpoint: String, in settings: ConfigCenterSettings) -> ConfigCenterAccount {
        let account = settings.accounts[endpoint] ?? ConfigCenterAccount()
        return ConfigCenterAccount(
            username: trimmed(account.username),
            password: trimmed(account.password)
        )
    }

    private static func trimmed(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

private enum ConfigCenterSecureStorage {
    private static let service = "com.fly.tvbox.config-center"
    private static let account = "settings"
    private static let fallbackKey = "config_center_settings_fallback"

    static func load() -> ConfigCenterSettings? {
        let data = keychainData() ?? UserDefaults.standard.data(forKey: fallbackKey)
        guard let data else {
            return nil
        }
        return try? JSONDecoder().decode(ConfigCenterSettings.self, from: data)
    }

    static func save(_ settings: ConfigCenterSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }
        if !saveToKeychain(data) {
            UserDefaults.standard.set(data, forKey: fallbackKey)
        }
    }

    private static func keychainData() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else {
            return nil
        }
        return item as? Data
    }

    private static func saveToKeychain(_ data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }
        guard updateStatus == errSecItemNotFound else {
            return false
        }

        var item = query
        item[kSecValueData as String] = data
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }
}
