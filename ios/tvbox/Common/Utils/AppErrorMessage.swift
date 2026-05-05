import AVFoundation
import Foundation

enum AppErrorMessage {
    static func userMessage(for error: Error, fallback: String = "操作失败，请稍后重试") -> String {
        if let configError = error as? ConfigError {
            return configMessage(configError)
        }
        if let networkError = error as? NetworkError {
            return networkMessage(networkError)
        }
        if let spiderError = error as? SpiderError {
            return spiderMessage(spiderError)
        }
        if let parserError = error as? ParserError {
            return parserMessage(parserError)
        }
        if let liveParserError = error as? LiveParserError {
            return liveParserMessage(liveParserError)
        }
        if let epgError = error as? EpgError {
            return epgMessage(epgError)
        }
        if let urlError = error as? URLError {
            return urlMessage(urlError)
        }
        
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return urlMessage(URLError(URLError.Code(rawValue: nsError.code)))
        }
        if nsError.domain == AVFoundationErrorDomain {
            return "播放失败，请尝试切换播放源或稍后重试"
        }
        
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? fallback : message
    }
    
    private static func configMessage(_ error: ConfigError) -> String {
        switch error {
        case .noApiUrl:
            return "请先填写配置源地址"
        case .invalidUrl:
            return "配置源地址无效，请检查后重试"
        case .invalidData:
            return "配置内容格式无效"
        case .networkError(let error):
            return "配置加载失败：\(userMessage(for: error))"
        case .parseError:
            return "配置解析失败，请确认配置源是否可用"
        }
    }
    
    private static func networkMessage(_ error: NetworkError) -> String {
        switch error {
        case .invalidURL:
            return "网络地址无效"
        case .invalidResponse:
            return "服务器响应异常"
        case .decodingError:
            return "数据解析失败"
        case .serverError(let message):
            return "服务器错误：\(message)"
        case .httpError(let statusCode, _):
            return "请求失败，HTTP 状态码 \(statusCode)"
        }
    }
    
    private static func spiderMessage(_ error: SpiderError) -> String {
        switch error {
        case .notInitialized:
            return "站点尚未初始化，请刷新后重试"
        case .invalidSite:
            return "当前站点配置无效，请切换站点"
        case .networkError(let error):
            return "站点请求失败：\(userMessage(for: error))"
        case .parseError:
            return "站点数据解析失败，请尝试其他站点"
        case .scriptError:
            return "站点脚本执行失败，请尝试其他站点"
        case .unsupported(let feature):
            return "当前站点暂不支持：\(feature)"
        }
    }
    
    private static func parserMessage(_ error: ParserError) -> String {
        switch error {
        case .noParser:
            return "没有可用解析器"
        case .invalidUrl:
            return "播放地址无效"
        case .invalidResponse:
            return "解析器响应格式错误"
        case .noUrl:
            return "解析器未返回播放地址"
        case .parseFailed:
            return "播放地址解析失败，请尝试切换解析源"
        case .timeout:
            return "播放地址解析超时"
        }
    }
    
    private static func liveParserMessage(_ error: LiveParserError) -> String {
        switch error {
        case .invalidUrl:
            return "直播源地址无效"
        case .noUrl:
            return "未配置直播源地址"
        case .unknownFormat:
            return "直播源内容格式无效"
        case .parseError:
            return "直播源解析失败"
        case .networkError(let error):
            return "直播源加载失败：\(userMessage(for: error))"
        }
    }
    
    private static func epgMessage(_ error: EpgError) -> String {
        switch error {
        case .invalidUrl:
            return "EPG 地址无效"
        case .parseError:
            return "EPG 内容格式无效"
        case .networkError(let error):
            return "EPG 加载失败：\(userMessage(for: error))"
        }
    }
    
    private static func urlMessage(_ error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet:
            return "网络不可用，请检查连接"
        case .timedOut:
            return "请求超时，请稍后重试"
        case .cannotFindHost, .cannotConnectToHost:
            return "无法连接服务器，请检查地址"
        case .badURL, .unsupportedURL:
            return "地址格式无效"
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot:
            return "安全连接失败，请检查服务器证书"
        case .cancelled:
            return "请求已取消"
        default:
            return "网络请求失败：\(error.localizedDescription)"
        }
    }
}
