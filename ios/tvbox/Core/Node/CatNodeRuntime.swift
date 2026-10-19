import Foundation
#if canImport(NodeMobile)
import NodeMobile
#endif

/// Cat 配置包的 Node 宿主 - 对应 MiraPlay 的 NodeRunner。
///
/// 通过 nodejs-mobile 启动 `catnode-bootstrap.js`，再由它 `require` 配置包的
/// `index.js` / `index.config.js`。配置包自己在本机起 HTTP 服务，站点、网盘、
/// 配置中心都通过这个服务访问，iOS 侧不再逐个重写站点逻辑。
actor CatNodeRuntime {
    static let shared = CatNodeRuntime()

    /// 当前平台是否带有 Node 运行时。NodeMobile 只提供 iOS 设备和模拟器切片，Mac Catalyst 没有。
    static var isSupported: Bool {
        #if canImport(NodeMobile)
        return true
        #else
        return false
        #endif
    }

    private var engineStarted = false
    private var controlPort = 0
    private var serverPort = 0

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        configuration.connectionProxyDictionary = [:]
        return URLSession(configuration: configuration)
    }()

    private let dataDirectory: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("catnode", isDirectory: true)

    private init() {}

    /// 配置包 HTTP 服务地址，未运行时为 nil。
    var baseURL: URL? {
        serverPort > 0 ? URL(string: "http://127.0.0.1:\(serverPort)") : nil
    }

    /// 加载配置包并返回它的 `/config` 站点列表 JSON。
    /// - Parameters:
    ///   - scriptContent: 已下载的 `index.js` 内容
    ///   - scriptUrl: `index.js` 地址，用于定位同目录的 `index.config.js`
    func load(scriptContent: String, scriptUrl: String) async throws -> String {
        try await startEngineIfNeeded()
        let bundleDirectory = try await prepareBundle(scriptContent: scriptContent, scriptUrl: scriptUrl)
        serverPort = try await runBundle(at: bundleDirectory)
        AppLogger.debug("[CatNodeRuntime] 配置包已启动，端口: \(serverPort)")
        return try await string(path: "/config")
    }

    /// 请求配置包服务，返回响应体。
    func request(path: String, json: [String: Any]? = nil) async throws -> Data {
        guard let baseURL, let url = URL(string: path, relativeTo: baseURL) else {
            throw CatNodeError.notRunning
        }

        var request = URLRequest(url: url)
        if let json {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw CatNodeError.httpStatus(path: path, code: httpResponse.statusCode, message: String(message.prefix(300)))
        }
        return data
    }

    // MARK: - Private Methods

    private func string(path: String) async throws -> String {
        let data = try await request(path: path)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func startEngineIfNeeded() async throws {
        guard controlPort == 0 else { return }

        let portFile = dataDirectory.appendingPathComponent("control.port")
        if !engineStarted {
            #if canImport(NodeMobile)
            guard let bootstrapPath = Bundle.main.path(forResource: "catnode-bootstrap", ofType: "js") else {
                throw CatNodeError.bootstrapMissing
            }
            try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: portFile)

            // nodejs-mobile 每个进程只能启动一次，之后切换配置包都走控制服务。
            let arguments = ["node", bootstrapPath, dataDirectory.path]
            let thread = Thread {
                NodeEngine.start(arguments: arguments)
            }
            thread.name = "nodejs"
            thread.stackSize = 2 * 1024 * 1024
            thread.start()
            engineStarted = true
            #else
            throw CatNodeError.unsupported
            #endif
        }

        for _ in 0..<150 {
            if let text = try? String(contentsOf: portFile, encoding: .utf8),
               let port = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                controlPort = port
                AppLogger.debug("[CatNodeRuntime] Node 控制服务端口: \(port)")
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw CatNodeError.startTimeout
    }

    private func prepareBundle(scriptContent: String, scriptUrl: String) async throws -> URL {
        let directory = dataDirectory
            .appendingPathComponent("source", isDirectory: true)
            .appendingPathComponent(scriptUrl.md5, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try scriptContent.write(to: directory.appendingPathComponent("index.js"), atomically: true, encoding: .utf8)

        let configFile = directory.appendingPathComponent("index.config.js")
        if let configURL = Self.configURL(forScriptUrl: scriptUrl) {
            do {
                let (data, response) = try await session.data(from: configURL)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, !data.isEmpty {
                    try data.write(to: configFile, options: .atomic)
                    return directory
                }
            } catch {
                AppLogger.debug("[CatNodeRuntime] index.config.js 下载失败: \(error.localizedDescription)")
            }
        }

        // 没有可用的配置文件时沿用上次下载的，否则给一个空配置。
        if !FileManager.default.fileExists(atPath: configFile.path) {
            try "module.exports = {};".write(to: configFile, atomically: true, encoding: .utf8)
        }
        return directory
    }

    private func runBundle(at directory: URL) async throws -> Int {
        guard let url = URL(string: "http://127.0.0.1:\(controlPort)/run") else {
            throw CatNodeError.notRunning
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["path": directory.path])
        request.timeoutInterval = 45

        let (data, _) = try await session.data(for: request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let port = object?["port"] as? Int, port > 0 else {
            throw CatNodeError.bundleFailed(object?["error"] as? String ?? String(decoding: data, as: UTF8.self))
        }
        return port
    }

    /// `.../index.js` 对应的 `.../index.config.js`。
    private static func configURL(forScriptUrl scriptUrl: String) -> URL? {
        guard scriptUrl.lowercased().hasSuffix(".js") else { return nil }
        return URL(string: String(scriptUrl.dropLast(3)) + ".config.js")
    }
}

enum CatNodeError: LocalizedError {
    case unsupported
    case bootstrapMissing
    case startTimeout
    case notRunning
    case bundleFailed(String)
    case httpStatus(path: String, code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "当前平台没有 Node 运行时"
        case .bootstrapMissing:
            return "缺少 catnode-bootstrap.js"
        case .startTimeout:
            return "Node 运行时启动超时"
        case .notRunning:
            return "配置包服务未运行"
        case .bundleFailed(let message):
            return "配置包启动失败: \(message)"
        case .httpStatus(let path, let code, let message):
            return "配置包接口 \(path) 返回 \(code): \(message)"
        }
    }
}

#if canImport(NodeMobile)
private enum NodeEngine {
    /// 调用 `node_start`，不会返回（Node 事件循环常驻）。
    static func start(arguments: [String]) {
        // Node 要求 argv 位于一段连续内存中，且在进程生命周期内有效，所以这里不释放。
        let cStrings = arguments.map { Array($0.utf8CString) }
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: cStrings.reduce(0) { $0 + $1.count })
        var argv: [UnsafeMutablePointer<CChar>?] = []
        var offset = 0
        for cString in cStrings {
            (buffer + offset).initialize(from: cString, count: cString.count)
            argv.append(buffer + offset)
            offset += cString.count
        }
        let code = node_start(Int32(argv.count), &argv)
        AppLogger.debug("[CatNodeRuntime] Node 已退出，code: \(code)")
    }
}
#endif
