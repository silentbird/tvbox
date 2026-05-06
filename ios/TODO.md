# TVBox iOS/macOS 移植路线图

> 最后更新: 2026-05-05
> 当前判断: Android 是主线成熟版；iOS 是 SwiftUI 移植版；macOS 建议优先走 Mac Catalyst，等核心链路稳定后再评估原生 macOS/AppKit 适配。

## 现在最先做什么

先做 **可构建、可运行、可验证**，不要先补弹幕、网盘、远控这些大功能。

### 当前最高优先级

1. [x] **P0-Blocker: 展开 Cat WebsiteBundle 完整 `/website` 子站点列表**，已补混淆 `meta` 静态还原，站点列表不再只依赖明文 `meta` 或单个 `wexDuBoKu`。
2. [x] **P0-Blocker: 给 WebsiteBundle 子站点加可用性分层**，已适配站点可直接进入，未适配站点显示“待适配/暂不可用”状态，避免再次触发 `WebsiteBundle 未暴露 home/category/detail/search/play`。

1. **把 iOS 工程跑通**
   - [x] 安装/切换完整 Xcode，确保 `xcodebuild -list -project ios/tvbox.xcodeproj` 可执行。
   - [ ] 用 Xcode 打开 `ios/tvbox.xcodeproj`，先跑 iPhone Simulator。
   - [x] 修复阻塞 iOS/macOS Catalyst 编译的错误。
   - [x] 把 `IPHONEOS_DEPLOYMENT_TARGET = 18.2` 降到合理版本，例如 iOS 16 或 iOS 17。
   - [x] 记录最小可运行环境: Xcode 26.4.1 (17E202)、iOS deployment target 17.0、Swift 5.0。

2. **跑通最小用户链路**
   - [x] 首次启动输入配置源。
   - [x] 成功识别 `.js.md5` 入口对应的 Cat WebsiteBundle 源。
   - [x] Cat WebsiteBundle 接入 SpiderManager，优先尝试直接暴露 Spider 方法的 bundle。
   - [x] P0: 支持 Node/Fastify 型 Cat WebsiteBundle 的原生路由替代层，当前先接入真实源里的 `nodejs_wexDuBoKu`。
   - [x] 解析 Cat WebsiteBundle 时只展示已适配子站点，避免继续选中旧占位站点 `ios_website_bundle_source`。
   - [x] 配置刷新、切换站点、Spider 创建时清理或迁移旧缓存，避免回到 JS fallback 的旧“不支持”报错。
   - [x] P0-Blocker: 解析并展示 Cat WebsiteBundle 完整 `/website` 子站点列表，支持明文 `meta` 和混淆 `meta` 静态还原。
   - [x] P0-Blocker: 未适配 WebsiteBundle 子站点进入前给出明确状态，不走 JS fallback 报错。
   - [x] 首页能展示已适配 WebsiteBundle 子站点分类。
   - [x] 搜索能通过已适配 WebsiteBundle 子站点返回结果。
   - [x] 详情页能通过已适配 WebsiteBundle 子站点加载剧集。
   - [x] 点击剧集能通过已适配 WebsiteBundle 子站点拿到直链播放地址。
   - [ ] 直播列表能加载并播放至少一个频道。

3. **建立回归样例**
   - [ ] 准备 2-3 个公开可用配置源，仅用于本地验证。
   - [ ] 每个配置源记录支持的能力: JSON 源、JS 源、直播、解析、图片防盗链。
   - [x] 建一个 `ios/SMOKE_TEST.md`，写清楚每次发版前手动验证步骤。
   - [x] 用真实 Cat WebsiteBundle 源验证 `wexDuBoKu` 分类、搜索、详情、播放接口。
   - [x] 把 `wexDuBoKu` 的真实接口样例整理进 `ios/SMOKE_TEST.md`。

4. **再打开 macOS**
   - [x] 先启用 Mac Catalyst，而不是立即写原生 macOS 版本。
   - [x] 确认 Mac Catalyst target 可以编译通过。
   - [ ] 确认 `AVPlayer`、`WKWebView` 嗅探、`UserDefaults`、文件缓存、网络请求在 Catalyst 运行时可用。
   - [ ] 修复 Mac 上的键盘、窗口尺寸、列表滚动、播放器全屏体验。
   - [ ] 只有当 Catalyst 限制明显影响体验时，再考虑拆出原生 macOS target。

## P0 - 工程健康

- [x] **P0-Blocker: 展开 Cat WebsiteBundle 完整子站点列表**，从 bundle 内的 `/website` 注册数据或等价元数据中提取所有入口；支持明文 `meta` 和混淆 `meta` 静态还原。
- [x] **P0-Blocker: WebsiteBundle 子站点可用性分层**，在 `SiteBean`/配置解析层记录 `nativeAdapter`、`isAdapted`、`unsupportedReason`，UI 允许展示未适配站点但不直接进入失败路径。
- [x] 补充 `ios/README.md`，说明如何构建 iOS/macOS。
- [x] 补充 `ios/SMOKE_TEST.md`，记录核心链路验证清单。
- [x] 让 iOS generic build 通过。
- [x] 让 Mac Catalyst build 通过。
- [x] 梳理 Debug 日志，避免大量 `print` 长期留在生产路径。
- [x] 处理 iOS 17 `onChange`、废弃 API 调用、`DetailView` Swift 6 捕获警告。
- [x] 处理 `JsSpider`/`QuickJSSpider` 中 JavaScriptCore `Sendable` 相关 warning。
- [x] 给网络、配置、Spider、播放器错误加统一用户提示。
- [x] 检查 SwiftUI 文件是否职责过重，优先拆分 `MainView.swift` 中的首页/豆瓣/图片缓存/设置子视图。
- [x] 明确 iOS 和 Mac 共用代码目录，例如 `Core/`、`Models/`、`Features/`，平台差异放到 `Platform/`。
- [x] 给关键 ViewModel 标注 `@MainActor` 或统一主线程更新策略。
- [x] Cat WebsiteBundle 不再在首页提前拦截，接入 iOS `WebsiteBundleSpider` 适配层。
- [x] P0: 为 Node/Fastify 型 WebsiteBundle 补原生路由替代层，先支持 `wexDuBoKu` 站点。
- [x] P0: WebsiteBundle 配置解析时优先抽取已适配子站点，旧占位站点仅作为无适配子站点时的 fallback。
- [x] P0: 配置重新解析和站点切换时清空 Spider 缓存，并在 SpiderManager 中兜底迁移旧 WebsiteBundle 占位站点。

## P1 - 数据源兼容性

### 配置解析
- [x] **P0-Blocker: Cat WebsiteBundle `/website` 完整列表解析**，从真实 bundle 里提取竞品可见的所有站点入口；明文/混淆 `meta` 均可解析，不再硬编码单个 `wexDuBoKu`。
- [x] **P0-Blocker: 未适配子站点状态建模**，让站点列表能区分“已适配可用”和“已识别待适配”。
- [x] ApiConfig - 远程 JSON 配置解析
- [x] 站点管理 `SiteBean`
- [x] 解析器管理 `ParseBean`
- [x] 直播配置 `LiveConfig`
- [x] 本地缓存机制
- [x] 支持 `.js.md5` JS 源入口，下载同路径 `.js` 并识别 `globalThis.websiteBundle`。
- [x] Cat WebsiteBundle 源在首页/设置站点列表可见，并显示明确的 iOS 运行层暂不支持提示。
- [x] 为 Cat WebsiteBundle 补基础 iOS 运行适配层，可执行直接暴露 Spider 方法的 bundle。
- [x] P0: 为 Node/Fastify 型 Cat WebsiteBundle 补原生替代解析层，先支持 `wexDuBoKu` 站点。
- [x] `wexDuBoKu` 支持分类、筛选、搜索、详情、剧集列表和播放地址获取。
- [x] `wexDuBoKu` 适配层支持从 `ext.nativeAdapter`、`site.key`、`site.api` 三种路径识别，降低旧缓存回退风险。
- [ ] 记录暂不支持的 Android 兼容源格式，例如加密 JSON、`clan://`、`file://`。
- [ ] 增加配置解析失败时的可读错误: URL 无效、网络失败、JSON 无效、字段缺失、加密失败。

### Spider
- [x] **P0-Blocker: WebsiteBundle 子站点路由分发框架**，按 key/type 将不同子站点分派到 native adapter；没有 adapter 时返回明确 unsupported，不执行泛化 JS fallback。
- [x] Spider 协议定义
- [x] JsonSpider
- [x] JsSpider - JavaScriptCore
- [x] QuickJSSpider fallback
- [x] WebsiteBundleSpider fallback
- [x] WebsiteBundleNativeSpider - `wexDuBoKu`
- [x] WebsiteBundleNativeSpider - `wexYueYue`、`animemodu`、`dongli`、`duanjuweiguan`、`hanxiaoquan`、`bookWuWei`、`bili`（mp4 flag）
- [ ] 对齐 Android `JarLoader`/`JsLoader` 行为，列出 iOS 无法支持的字节码/二进制格式。
- [ ] 支持 XML 类型站点 `type = 0`。
- [ ] 支持远程类型站点 `type = 4`。
- [ ] 给每类站点加真实源测试记录。

### 搜索与分类
- [x] 首页分类和推荐
- [x] 分类视频列表
- [x] 搜索
- [x] 多站点快速搜索基础能力
- [x] `wexDuBoKu` 分类筛选参数映射。
- [ ] 分类筛选 UI 和筛选参数持久化。
- [ ] 搜索源选择。
- [ ] 搜索结果合并去重和错误隔离。

## P2 - 播放核心

### 点播播放器
- [x] PlayerView - AVPlayer 基础播放
- [x] 播放/暂停、进度、快进快退
- [ ] 自动下一集。
- [ ] 续播，记住播放位置。
- [ ] 倍速播放。
- [ ] 画面比例调整。
- [ ] iOS 画中画。
- [ ] macOS/Catalyst 全屏和键盘快捷键。
- [ ] 播放失败重试和切换解析源。
- [ ] Header、User-Agent、Referer、Cookie 注入播放请求。

### 解析和嗅探
- [x] ParserManager - VIP 视频解析
- [x] JSON 解析接口并发调用
- [x] 多解析源切换
- [x] WebView 嗅探
- [x] SuperParse iframe 并发嗅探
- [x] 递归解析
- [x] VideoParseRuler 嗅探规则
- [ ] 与 Android `SuperParse`、`JsonParallel` 行为逐项对齐。
- [ ] 增加解析链路日志开关，方便定位具体解析器失败。
- [ ] macOS/Catalyst 下验证 WKWebView 嗅探可用性。

### 直播
- [x] TXT 格式直播源解析
- [x] M3U/M3U8 格式解析
- [x] TVBOX JSON 直播格式支持
- [x] EPG 管理
- [ ] 直播频道收藏。
- [ ] 直播分组搜索。
- [ ] 直播播放 Header 支持。
- [ ] EPG 缓存和刷新策略。

## P3 - iOS/mac 体验补齐

### 平台适配
- [ ] iPad 分栏布局。
- [ ] Mac Catalyst 窗口尺寸适配。
- [ ] Mac 键盘方向键/回车/空格/ESC 操作。
- [ ] Mac 菜单栏基础命令: 打开配置、刷新、播放/暂停、全屏。
- [ ] 深色模式完整检查。
- [ ] 图片缓存替换为更稳定的实现，或增强当前 `CachedAsyncImage` 的磁盘缓存。

### 设置与数据
- [x] HistoryView
- [x] CollectView
- [x] SettingsView
- [x] StorageManager 基础本地存储
- [x] API 历史记录。
- [ ] 配置导入/导出。
- [ ] iCloud 同步收藏/历史，可后置。
- [ ] 清理缓存。
- [ ] 播放器设置页。

## P4 - Android 功能移植清单

### 字幕
- [ ] SRT 字幕解析。
- [ ] ASS 字幕解析。
- [ ] TTML 字幕解析。
- [ ] 在线字幕搜索。
- [ ] 字幕样式设置。
- [ ] 字幕时间轴调整。

### 弹幕
- [ ] Danmu 数据模型。
- [ ] XML 弹幕解析器。
- [ ] 弹幕渲染视图。
- [ ] 弹幕设置。
- [ ] 弹幕开关控制。

### 网盘/存储驱动
- [ ] StorageDrive 数据模型。
- [ ] DriveFolderFile 文件模型。
- [ ] 本地目录浏览。
- [ ] WebDAV 连接、浏览、播放。
- [ ] Alist 连接、浏览、播放。
- [ ] DriveView。

### M3U8 处理
- [ ] 自动检测广告片段。
- [ ] 基于域名过滤广告。
- [ ] 基于切片时长过滤广告。
- [ ] 自定义广告规则。
- [ ] 解密 KEY 路径处理。

### 网络增强
- [ ] DNS over HTTPS。
- [ ] 代理服务器。
- [ ] 自定义 User-Agent。
- [ ] TLS 兼容优化。

### 远程控制和推送
- [ ] 本地 HTTP 服务器。
- [ ] Web 远程控制 API。
- [ ] 接收推送播放。
- [ ] 远程配置推送。
- [ ] 二维码生成。
- [ ] 扫码输入配置地址。

### 投屏
- [ ] AirPlay 能力整理。
- [ ] DLNA 可行性评估。

## Android 对照表

| Android 文件 | iOS/mac 对应 | 状态 |
|-------------|--------------|------|
| `bean/Danmu.java` | `Models/Danmu.swift` | 待实现 |
| `bean/Doh.java` | `Models/Doh.swift` | 待实现 |
| `bean/DriveFolderFile.java` | `Models/DriveFolderFile.swift` | 待实现 |
| `bean/IJKCode.java` | 不适用，AVPlayer 方案 | 后置评估 |
| `bean/SearchResultWrapper.java` | `Models/SearchResultWrapper.swift` | 待实现 |
| `bean/SubtitleBean.java` | `Models/Subtitle.swift` | 待实现 |
| `bean/VodSeriesGroup.java` | `Models/VodSeriesGroup.swift` | 待实现 |
| `cache/SearchHistory.java` | `Core/Storage/SearchHistory.swift` | 待实现 |
| `cache/StorageDrive.java` | `Models/StorageDrive.swift` | 待实现 |
| `player/danmu/Parser.java` | `Features/Player/DanmuParser.swift` | 待实现 |
| `player/controller/VodController.java` | `Features/Player/PlayerControls.swift` | 部分实现 |
| `player/controller/LiveController.java` | `Features/Live/LiveControls.swift` | 部分实现 |
| `player/thirdparty/MXPlayer.java` | 不适用 | 不移植 |
| `player/thirdparty/Kodi.java` | 不适用 | 不移植 |
| `player/EXOmPlayer.java` | 不适用，AVPlayer 方案 | 不移植 |
| `player/IjkmPlayer.java` | 不适用，AVPlayer 方案 | 不移植 |
| `server/ControlManager.java` | `Core/Server/ControlManager.swift` | 待实现 |
| `server/RemoteServer.java` | `Core/Server/RemoteServer.swift` | 待实现 |
| `server/WebController.kt` | `Core/Server/WebController.swift` | 待实现 |
| `server/DataReceiver.java` | `Core/Server/DataReceiver.swift` | 待实现 |
| `subtitle/SubtitleLoader.java` | `Features/Player/SubtitleLoader.swift` | 待实现 |
| `subtitle/SubtitleEngine.java` | `Features/Player/SubtitleEngine.swift` | 待实现 |
| `subtitle/format/FormatSRT.java` | `Features/Player/Format/FormatSRT.swift` | 待实现 |
| `subtitle/format/FormatASS.java` | `Features/Player/Format/FormatASS.swift` | 待实现 |
| `subtitle/format/FormatTTML.java` | `Features/Player/Format/FormatTTML.swift` | 待实现 |
| `ui/activity/DriveActivity.java` | `Features/Drive/DriveView.swift` | 待实现 |
| `ui/activity/AppsActivity.java` | 不适用 | 不移植 |
| `ui/activity/PushActivity.java` | `Features/Push/PushView.swift` | 待实现 |
| `ui/activity/FastSearchActivity.java` | `Features/Search/FastSearchView.swift` | 待实现 |
| `ui/dialog/DanmuSettingDialog.java` | `Features/Player/DanmuSettingView.swift` | 待实现 |
| `ui/dialog/ApiHistoryDialog.java` | `Features/Settings/ApiHistoryView.swift` | 待实现 |
| `ui/dialog/BackupDialog.java` | `Features/Settings/BackupView.swift` | 待实现 |
| `ui/dialog/GridFilterDialog.java` | `Features/Home/GridFilterView.swift` | 待实现 |
| `ui/dialog/MediaSettingDialog.java` | `Features/Player/MediaSettingView.swift` | 待实现 |
| `ui/dialog/SearchCheckboxDialog.java` | `Features/Search/SearchSourceSelectView.swift` | 待实现 |
| `ui/dialog/RemoteDialog.java` | `Features/Settings/RemoteView.swift` | 待实现 |
| `ui/dialog/PushDialog.java` | `Features/Push/PushDialog.swift` | 待实现 |
| `ui/dialog/WebdavDialog.java` | `Features/Drive/WebdavConfigView.swift` | 待实现 |
| `ui/dialog/AlistDriveDialog.java` | `Features/Drive/AlistConfigView.swift` | 待实现 |
| `ui/tv/QRCodeGen.java` | `Common/Utils/QRCodeGen.swift` | 待实现 |
| `util/M3U8.java` | `Core/Player/M3U8AdFilter.swift` | 待实现 |
| `util/Proxy.java` | `Core/Network/Proxy.swift` | 待实现 |
| `util/PlayerHelper.java` | `Core/Player/PlayerHelper.swift` | 部分实现 |
| `util/SearchHelper.java` | `Core/Search/SearchHelper.swift` | 待实现 |
| `util/HawkConfig.java` | `Core/Config/AppConfig.swift` | 待实现 |

## 暂缓事项

- 暂缓原生 macOS target，先用 Mac Catalyst 验证。
- 暂缓 IJK/Exo/阿里播放器等 Android 播放器移植，iOS/macOS 优先使用 AVPlayer。
- 暂缓第三方播放器调用，iOS/macOS 没有 Android Intent 对等机制。
- 暂缓大规模 UI 美化，先保证核心链路稳定。
