# TVBox iOS/macOS 移植路线图

> 最后更新: 2026-05-04
> 当前判断: Android 是主线成熟版；iOS 是 SwiftUI 移植版；macOS 建议优先走 Mac Catalyst，等核心链路稳定后再评估原生 macOS/AppKit 适配。

## 现在最先做什么

先做 **可构建、可运行、可验证**，不要先补弹幕、网盘、远控这些大功能。

1. **把 iOS 工程跑通**
   - [x] 安装/切换完整 Xcode，确保 `xcodebuild -list -project ios/tvbox.xcodeproj` 可执行。
   - [ ] 用 Xcode 打开 `ios/tvbox.xcodeproj`，先跑 iPhone Simulator。
   - [x] 修复阻塞 iOS/macOS Catalyst 编译的错误。
   - [x] 把 `IPHONEOS_DEPLOYMENT_TARGET = 18.2` 降到合理版本，例如 iOS 16 或 iOS 17。
   - [x] 记录最小可运行环境: Xcode 26.4.1 (17E202)、iOS deployment target 17.0、Swift 5.0。

2. **跑通最小用户链路**
   - [ ] 首次启动输入配置源。
   - [ ] 成功解析远程配置。
   - [ ] 首页能展示站点/分类/推荐。
   - [ ] 搜索能返回结果。
   - [ ] 详情页能加载剧集。
   - [ ] 点击剧集能播放。
   - [ ] 直播列表能加载并播放至少一个频道。

3. **建立回归样例**
   - [ ] 准备 2-3 个公开可用配置源，仅用于本地验证。
   - [ ] 每个配置源记录支持的能力: JSON 源、JS 源、直播、解析、图片防盗链。
   - [x] 建一个 `ios/SMOKE_TEST.md`，写清楚每次发版前手动验证步骤。

4. **再打开 macOS**
   - [x] 先启用 Mac Catalyst，而不是立即写原生 macOS 版本。
   - [x] 确认 Mac Catalyst target 可以编译通过。
   - [ ] 确认 `AVPlayer`、`WKWebView` 嗅探、`UserDefaults`、文件缓存、网络请求在 Catalyst 运行时可用。
   - [ ] 修复 Mac 上的键盘、窗口尺寸、列表滚动、播放器全屏体验。
   - [ ] 只有当 Catalyst 限制明显影响体验时，再考虑拆出原生 macOS target。

## P0 - 工程健康

- [x] 补充 `ios/README.md`，说明如何构建 iOS/macOS。
- [x] 补充 `ios/SMOKE_TEST.md`，记录核心链路验证清单。
- [x] 让 iOS generic build 通过。
- [x] 让 Mac Catalyst build 通过。
- [ ] 梳理 Debug 日志，避免大量 `print` 长期留在生产路径。
- [x] 处理 iOS 17 `onChange`、废弃 API 调用、`DetailView` Swift 6 捕获警告。
- [ ] 处理 `JsSpider`/`QuickJSSpider` 中 JavaScriptCore `Sendable` 相关 warning。
- [ ] 给网络、配置、Spider、播放器错误加统一用户提示。
- [ ] 检查 SwiftUI 文件是否职责过重，优先拆分 `MainView.swift` 中的首页/豆瓣/图片缓存/设置子视图。
- [ ] 明确 iOS 和 Mac 共用代码目录，例如 `Core/`、`Models/`、`Features/`，平台差异放到 `Platform/`。
- [ ] 给关键 ViewModel 标注 `@MainActor` 或统一主线程更新策略。

## P1 - 数据源兼容性

### 配置解析
- [x] ApiConfig - 远程 JSON 配置解析
- [x] 站点管理 `SiteBean`
- [x] 解析器管理 `ParseBean`
- [x] 直播配置 `LiveConfig`
- [x] 本地缓存机制
- [ ] 对齐 Android 的配置解密逻辑，包括 `;pk;`、Base64/AES、`clan://`、`file://`。
- [ ] 增加配置解析失败时的可读错误: URL 无效、网络失败、JSON 无效、字段缺失、加密失败。

### Spider
- [x] Spider 协议定义
- [x] JsonSpider
- [x] JsSpider - JavaScriptCore
- [x] QuickJSSpider fallback
- [ ] 对齐 Android `JarLoader`/`JsLoader` 行为，列出 iOS 无法支持的字节码/二进制格式。
- [ ] 支持 XML 类型站点 `type = 0`。
- [ ] 支持远程类型站点 `type = 4`。
- [ ] 给每类站点加真实源测试记录。

### 搜索与分类
- [x] 首页分类和推荐
- [x] 分类视频列表
- [x] 搜索
- [x] 多站点快速搜索基础能力
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
- [ ] API 历史记录。
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
