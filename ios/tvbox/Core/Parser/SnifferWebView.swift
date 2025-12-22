import Foundation
import WebKit

/// WebView 嗅探器 - 对应 Android 的 WebView 嗅探功能
/// 使用 WKWebView 加载解析页面，拦截视频请求获取直链
class SnifferWebView: NSObject {
    
    // MARK: - Properties
    
    private var webView: WKWebView?
    private var videoSniffer = VideoSniffer.shared
    private var parseUrl: String = ""
    private var timeout: TimeInterval = 20.0
    private var foundUrls: [SniffedVideo] = []
    private var continuation: CheckedContinuation<SniffedVideo, Error>?
    private var timeoutTask: Task<Void, Never>?
    private var userAgent: String?
    private var headers: [String: String]?
    
    // MARK: - Public Methods
    
    /// 嗅探视频地址
    /// - Parameters:
    ///   - url: 解析页面 URL
    ///   - timeout: 超时时间 (秒)
    ///   - userAgent: 自定义 User-Agent
    ///   - headers: 自定义请求头
    /// - Returns: 嗅探到的视频信息
    func sniff(url: String, timeout: TimeInterval = 20.0, userAgent: String? = nil, headers: [String: String]? = nil) async throws -> SniffedVideo {
        self.parseUrl = url
        self.timeout = timeout
        self.userAgent = userAgent
        self.headers = headers
        self.foundUrls.removeAll()
        
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            // 在主线程创建和配置 WebView
            DispatchQueue.main.async { [weak self] in
                self?.setupWebView()
                self?.loadUrl(url)
                self?.startTimeoutTimer()
            }
        }
    }
    
    /// 停止嗅探
    func stop() {
        DispatchQueue.main.async { [weak self] in
            self?.cleanup()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupWebView() {
        // 创建配置
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // 设置 URL Scheme Handler 来拦截请求
        let schemeHandler = VideoSchemeHandler(delegate: self)
        // 注意: 无法拦截 http/https, 但可以通过其他方式
        
        // 创建 UserContentController 注入脚本
        let userContentController = WKUserContentController()
        
        // 注入脚本来拦截 XMLHttpRequest 和 fetch
        let interceptScript = WKUserScript(
            source: Self.interceptorScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(interceptScript)
        
        // 添加消息处理
        userContentController.add(self, name: "videoSniffer")
        
        configuration.userContentController = userContentController
        
        // 创建 WebView
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: configuration)
        webView?.navigationDelegate = self
        
        // 设置 User-Agent
        if let ua = userAgent {
            webView?.customUserAgent = ua
        } else {
            webView?.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        }
        
        // 允许任意加载
        webView?.configuration.preferences.javaScriptEnabled = true
    }
    
    private func loadUrl(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            failWithError(ParserError.invalidUrl)
            return
        }
        
        var request = URLRequest(url: url)
        
        // 添加自定义请求头
        if let headers = headers {
            for (key, value) in headers {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        
        webView?.load(request)
        print("[SnifferWebView] 开始加载: \(urlString)")
    }
    
    private func startTimeoutTimer() {
        timeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            
            await MainActor.run {
                if self.continuation != nil {
                    // 超时，如果有找到的 URL 就返回第一个
                    if let firstVideo = self.foundUrls.first {
                        self.succeedWithVideo(firstVideo)
                    } else {
                        self.failWithError(ParserError.timeout)
                    }
                }
            }
        }
    }
    
    private func checkUrl(_ urlString: String, headers: [String: String]? = nil) {
        // 检查是否是视频 URL
        guard videoSniffer.isVideoUrl(urlString, webUrl: parseUrl) else {
            return
        }
        
        // 检查是否应该过滤
        guard !videoSniffer.shouldFilter(urlString) else {
            return
        }
        
        print("[SnifferWebView] 发现视频: \(urlString)")
        
        let video = SniffedVideo(
            url: urlString,
            headers: headers,
            format: videoSniffer.getVideoFormat(urlString)
        )
        
        foundUrls.append(video)
        
        // 找到第一个视频就返回
        succeedWithVideo(video)
    }
    
    private func succeedWithVideo(_ video: SniffedVideo) {
        guard let continuation = self.continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        cleanup()
        continuation.resume(returning: video)
    }
    
    private func failWithError(_ error: Error) {
        guard let continuation = self.continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        cleanup()
        continuation.resume(throwing: error)
    }
    
    private func cleanup() {
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "videoSniffer")
        webView = nil
    }
    
    // MARK: - Interceptor Script
    
    /// 注入到网页的脚本，用于拦截 XMLHttpRequest 和 fetch 请求
    private static let interceptorScript = """
    (function() {
        // 拦截 XMLHttpRequest
        var originalOpen = XMLHttpRequest.prototype.open;
        var originalSend = XMLHttpRequest.prototype.send;
        
        XMLHttpRequest.prototype.open = function(method, url, async, user, password) {
            this._snifferUrl = url;
            return originalOpen.apply(this, arguments);
        };
        
        XMLHttpRequest.prototype.send = function(body) {
            var self = this;
            this.addEventListener('load', function() {
                try {
                    var url = self._snifferUrl;
                    if (url && typeof url === 'string') {
                        // 检查响应类型
                        var contentType = self.getResponseHeader('Content-Type') || '';
                        if (url.indexOf('.m3u8') !== -1 || 
                            url.indexOf('.mp4') !== -1 || 
                            url.indexOf('.flv') !== -1 ||
                            contentType.indexOf('video') !== -1 ||
                            contentType.indexOf('mpegurl') !== -1) {
                            window.webkit.messageHandlers.videoSniffer.postMessage({
                                type: 'xhr',
                                url: url
                            });
                        }
                    }
                } catch(e) {}
            });
            return originalSend.apply(this, arguments);
        };
        
        // 拦截 fetch
        var originalFetch = window.fetch;
        window.fetch = function(input, init) {
            var url = typeof input === 'string' ? input : input.url;
            
            return originalFetch.apply(this, arguments).then(function(response) {
                try {
                    if (url && typeof url === 'string') {
                        var contentType = response.headers.get('Content-Type') || '';
                        if (url.indexOf('.m3u8') !== -1 || 
                            url.indexOf('.mp4') !== -1 || 
                            url.indexOf('.flv') !== -1 ||
                            contentType.indexOf('video') !== -1 ||
                            contentType.indexOf('mpegurl') !== -1) {
                            window.webkit.messageHandlers.videoSniffer.postMessage({
                                type: 'fetch',
                                url: url
                            });
                        }
                    }
                } catch(e) {}
                return response;
            });
        };
        
        // 拦截 video 元素
        var observer = new MutationObserver(function(mutations) {
            mutations.forEach(function(mutation) {
                mutation.addedNodes.forEach(function(node) {
                    if (node.nodeName === 'VIDEO' || node.nodeName === 'SOURCE') {
                        var src = node.src || node.currentSrc;
                        if (src) {
                            window.webkit.messageHandlers.videoSniffer.postMessage({
                                type: 'video',
                                url: src
                            });
                        }
                    }
                    // 检查子元素
                    if (node.querySelectorAll) {
                        var videos = node.querySelectorAll('video, source');
                        videos.forEach(function(v) {
                            var src = v.src || v.currentSrc;
                            if (src) {
                                window.webkit.messageHandlers.videoSniffer.postMessage({
                                    type: 'video',
                                    url: src
                                });
                            }
                        });
                    }
                });
            });
        });
        
        observer.observe(document, { childList: true, subtree: true });
        
        // 监听已存在的 video 元素
        document.addEventListener('DOMContentLoaded', function() {
            var videos = document.querySelectorAll('video, source');
            videos.forEach(function(v) {
                var src = v.src || v.currentSrc;
                if (src) {
                    window.webkit.messageHandlers.videoSniffer.postMessage({
                        type: 'video',
                        url: src
                    });
                }
            });
        });
    })();
    """
}

// MARK: - WKNavigationDelegate

extension SnifferWebView: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url?.absoluteString {
            // 检查导航请求是否是视频
            checkUrl(url)
        }
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse,
           let url = response.url?.absoluteString {
            
            // 检查响应的 Content-Type
            let contentType = response.mimeType ?? ""
            if contentType.contains("video") || contentType.contains("mpegurl") || contentType.contains("mp2t") {
                checkUrl(url)
            } else {
                checkUrl(url)
            }
        }
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[SnifferWebView] 导航失败: \(error.localizedDescription)")
        // 不立即失败，等待超时
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[SnifferWebView] 加载失败: \(error.localizedDescription)")
        // 不立即失败，等待超时
    }
}

// MARK: - WKScriptMessageHandler

extension SnifferWebView: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "videoSniffer",
              let body = message.body as? [String: Any],
              let url = body["url"] as? String else {
            return
        }
        
        let type = body["type"] as? String ?? "unknown"
        print("[SnifferWebView] JS拦截 [\(type)]: \(url)")
        
        checkUrl(url)
    }
}

// MARK: - VideoSchemeHandler

private class VideoSchemeHandler: NSObject, WKURLSchemeHandler {
    weak var delegate: SnifferWebView?
    
    init(delegate: SnifferWebView) {
        self.delegate = delegate
    }
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        // 自定义 scheme 处理
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // 停止处理
    }
}

// MARK: - Sniffed Video

/// 嗅探到的视频信息
struct SniffedVideo {
    let url: String
    let headers: [String: String]?
    let format: String?
    
    init(url: String, headers: [String: String]? = nil, format: String? = nil) {
        self.url = url
        self.headers = headers
        self.format = format
    }
    
    /// 转换为 PlayerContent
    func toPlayerContent() -> PlayerContent {
        return PlayerContent(
            url: url,
            header: headers,
            parse: 0,
            format: format
        )
    }
}

