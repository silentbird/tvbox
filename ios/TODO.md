# TVBox iOS 移植进度

> 最后更新: 2025-12-22 (解析功能完善)
> 基于 Android 版本同步
>
> **新增文件:**
> - `Core/Spider/Spider.swift` - Spider 协议定义
> - `Core/Spider/SpiderManager.swift` - Spider 管理器
> - `Core/Spider/JsonSpider.swift` - JSON 类型站点实现
> - `Core/Spider/JsSpider.swift` - JavaScript 爬虫 (JavaScriptCore)
> - `Core/Live/LiveParser.swift` - 直播源解析器协议和管理器
> - `Core/Live/TxtLiveParser.swift` - TXT 格式直播源解析
> - `Core/Live/M3uLiveParser.swift` - M3U/M3U8 格式解析
> - `Core/Live/JsonLiveParser.swift` - TVBOX JSON 格式解析
> - `Core/Live/EpgManager.swift` - EPG 电子节目单管理
> - `Core/Parser/ParserManager.swift` - 解析管理器 (VIP视频解析, 递归解析)
> - `Core/Parser/JsonParser.swift` - JSON 解析接口并发调用
> - `Core/Parser/SnifferWebView.swift` - WebView 嗅探器 (WKWebView 拦截视频请求)
> - `Core/Parser/VideoSniffer.swift` - 视频格式检测工具
> - `Core/Parser/SuperParse.swift` - 超级解析 (iframe 并发嗅探)
> - `Core/Parser/VideoParseRuler.swift` - 嗅探规则管理

## ✅ 已完成功能

### 核心架构
- [x] ApiConfig - 远程 JSON 配置解析
- [x] 站点管理 (SiteBean)
- [x] 解析器管理 (ParseBean)
- [x] 直播配置 (LiveConfig)
- [x] 本地缓存机制
- [x] StorageManager - 本地数据存储

### 数据模型
- [x] SiteBean - 站点源配置
- [x] ParseBean - 解析配置
- [x] MovieItem - 影视列表项
- [x] VodInfo - 影视详情
- [x] MovieCategory - 分类
- [x] LiveChannelGroup/Item - 直播频道

### 功能页面
- [x] MainView - 主页面 TabView 导航 + 配置引导
- [x] HomeView - 首页 (站点切换、分类、推荐)
- [x] DetailView - 影视详情页 (播放源选择、剧集列表)
- [x] PlayerView - 视频播放器 (AVPlayer、进度控制)
- [x] LiveView - 直播 (频道列表、直播播放)
- [x] SearchView - 搜索 (搜索历史、热门搜索)
- [x] HistoryView - 观看历史
- [x] CollectView - 我的收藏
- [x] SettingsView - 设置页面

### 网络层
- [x] HttpUtil - HTTP 请求工具
- [x] NetworkManager - 网络管理
- [x] DataCallback - 数据回调

---

## 🔲 待完成功能

### 🔴 高优先级

#### Spider 爬虫替代方案
- [x] 研究 iOS 上执行 JavaScript 的方案 (JavaScriptCore)
- [x] 实现 JS 爬虫加载器 (JsSpider)
- [x] 支持远程 JS 脚本执行
- [x] 实现 Spider 基础接口 (Spider.swift)

#### JSON 类型站点完整支持
- [x] 完善 HomeViewModel 的 API 调用 (支持分页、筛选)
- [x] 实现分类视频列表加载 (带分页功能)
- [x] 实现搜索功能的 API 调用 (支持多站点搜索)
- [x] 实现详情页的 API 调用 (DetailViewModel)

#### 直播源解析
- [x] TXT 格式直播源解析 (TxtLiveParser)
- [x] M3U/M3U8 格式直播源解析 (M3uLiveParser)
- [x] TVBOX JSON 直播格式支持 (JsonLiveParser)
- [x] EPG 电子节目单支持 (EpgManager)

---

### 🟡 中优先级

#### 弹幕功能 (Android: Danmu.java, Parser.java)
- [ ] 弹幕数据模型 (Danmu)
- [ ] XML 弹幕解析器
- [ ] 弹幕渲染视图
- [ ] 弹幕设置 (颜色、大小、速度、透明度)
- [ ] 弹幕开关控制

#### 网盘/存储驱动 (Android: StorageDrive, DriveActivity)
- [ ] StorageDrive 数据模型
- [ ] DriveFolderFile 文件模型
- [ ] 本地目录浏览
- [ ] WebDAV 支持
  - [ ] WebDAV 连接配置
  - [ ] 文件浏览
  - [ ] 视频播放
- [ ] Alist 网页支持
  - [ ] Alist 连接配置
  - [ ] 文件列表获取
  - [ ] 视频播放
- [ ] DriveView - 网盘页面

#### 播放器增强 (Android: PlayerHelper.java, VodController.java)
- [ ] 画中画 (PiP) 支持 (PIC_IN_PIC)
- [ ] 后台音频播放 (BACKGROUND_PLAY_TYPE)
- [ ] 倍速播放 (0.5x - 3.0x)
- [ ] 画面比例调整 (默认/16:9/4:3/填充/原始/裁剪)
- [ ] 手势控制 (音量/亮度/进度)
- [ ] 自动下一集
- [ ] 续播功能 (记住播放位置)
- [ ] 播放器类型切换 (系统/IJK/EXO/阿里)
- [ ] 渲染模式切换 (TextureView/SurfaceView)
- [ ] 跳转时间步长设置 (PLAY_TIME_STEP)
- [ ] 视频预览 (SHOW_PREVIEW)
- [ ] 视频净化/去广告 (VIDEO_PURIFY)

#### 字幕支持 (Android: SubtitleHelper, SubtitleLoader)
- [ ] SRT 字幕解析 (FormatSRT)
- [ ] ASS 字幕解析 (FormatASS)
- [ ] TTML 字幕解析 (FormatTTML)
- [ ] 在线字幕搜索
- [ ] 字幕样式设置 (字体、大小、颜色)
- [ ] 字幕时间轴调整

#### 解析接口 (Core/Parser/)
- [x] VIP 视频解析支持 (ParserManager.swift)
- [x] JSON 解析接口并发调用 (JsonParser.swift)
- [x] 多解析源切换
- [x] WebView 嗅探 (SnifferWebView.swift)
- [x] 代理解析 (SuperParse.swift - iframe 并发嗅探)
- [x] 递归解析 (parse=1 时继续解析)
- [x] 嗅探规则管理 (VideoParseRuler.swift)

#### XML 类型站点支持
- [ ] XML 格式解析 (AbsXml, AbsSortXml)
- [ ] 资源站 API 适配

#### M3U8 广告过滤 (Android: M3U8.java)
- [ ] 自动检测广告片段
- [ ] 基于域名过滤广告
- [ ] 基于切片时长过滤广告
- [ ] 自定义广告规则 (VideoParseRuler)
- [ ] 解密KEY路径处理

#### 网络增强 (Android: Doh.java, OkGoHelper)
- [ ] DNS over HTTPS (DoH) 支持
- [ ] 多个 DoH 服务器配置
- [ ] 代理服务器支持
- [ ] 自定义 User-Agent
- [ ] TLS 优化 (TLSSocketFactory)

#### 分类筛选 (Android: GridFilterDialog.java)
- [ ] 视频分类筛选界面
- [ ] 多条件筛选
- [ ] 筛选结果缓存

#### 媒体设置 (Android: MediaSettingDialog.java)
- [ ] IJK 解码模式切换 (软解/硬解)
- [ ] IJK 缓存设置
- [ ] EXO 渲染器设置
- [ ] EXO 渲染模式设置
- [ ] 首选播放器设置

---

### 🟢 低优先级

#### 远程控制 (Android: WebController.kt, RemoteServer, ControlManager.java)
- [ ] 本地 HTTP 服务器
- [ ] Web 远程控制 API
- [ ] 接收推送播放
- [ ] 远程配置推送
- [ ] 远程推送直播地址
- [ ] 远程推送EPG地址

#### 推送功能 (Android: PushActivity.java, PushDialog.java)
- [ ] 显示二维码/地址供浏览器访问
- [ ] 剪贴板内容播放
- [ ] 接收远程推送的播放链接
- [ ] Push 代理播放源

#### 投屏功能
- [ ] AirPlay 支持
- [ ] DLNA 投屏

#### 二维码扫描
- [ ] 扫码输入配置地址
- [ ] 扫码添加网盘
- [ ] 二维码生成 (QRCodeGen)

#### 备份与同步 (Android: BackupDialog)
- [ ] iCloud 同步收藏/历史
- [ ] WebDAV 备份
- [ ] 配置导入/导出
- [ ] 本地文件备份/恢复
- [ ] 备份列表管理 (最多保留10个)

#### 搜索增强 (Android: SearchHistory, FastSearchActivity, SearchHelper.java)
- [ ] 搜索历史持久化 (Room -> Core Data)
- [ ] 快速搜索 (多站点并行)
- [ ] 搜索结果合并去重
- [ ] 分词搜索 (调用分词API拆分关键词)
- [ ] 搜索源筛选 (SearchCheckboxDialog - 选择用于搜索的站点)
- [ ] 按站点过滤搜索结果
- [ ] 搜索结果计数显示

#### 应用管理 (Android: AppsActivity)
- [ ] 第三方播放器调用 (MXPlayer, Kodi, ReexPlayer)
- [ ] 应用列表管理
- [ ] 外部播放器Intent调用

#### UI/UX 优化
- [ ] 深色模式适配
- [ ] iPad 适配
- [ ] tvOS 适配
- [ ] 自定义主题色 (THEME_SELECT)
- [ ] 骨架屏加载
- [ ] 下拉刷新动画
- [ ] 选中放大动画效果 (BounceInterpolator)

#### 性能优化
- [ ] 图片缓存 (SDWebImage/Kingfisher)
- [ ] 列表预加载
- [ ] 内存优化
- [ ] 网络请求缓存

---

## 📋 Android 新增文件对照表

| Android 文件 | iOS 对应 | 状态 |
|-------------|----------|------|
| `bean/Danmu.java` | `Models/Danmu.swift` | 🔲 待实现 |
| `bean/Doh.java` | `Models/Doh.swift` | 🔲 待实现 |
| `bean/DriveFolderFile.java` | `Models/DriveFolderFile.swift` | 🔲 待实现 |
| `bean/IJKCode.java` | `Models/IJKCode.swift` | 🔲 待实现 |
| `bean/SearchResultWrapper.java` | `Models/SearchResultWrapper.swift` | 🔲 待实现 |
| `bean/SubtitleBean.java` | `Models/Subtitle.swift` | 🔲 待实现 |
| `bean/VodSeriesGroup.java` | `Models/VodSeriesGroup.swift` | 🔲 待实现 |
| `cache/SearchHistory.java` | `Core/Storage/SearchHistory.swift` | 🔲 待实现 |
| `cache/StorageDrive.java` | `Models/StorageDrive.swift` | 🔲 待实现 |
| `player/danmu/Parser.java` | `Features/Player/DanmuParser.swift` | 🔲 待实现 |
| `player/controller/VodController.java` | `Features/Player/VodController.swift` | 🔲 待实现 |
| `player/controller/LiveController.java` | `Features/Player/LiveController.swift` | 🔲 待实现 |
| `player/thirdparty/MXPlayer.java` | - | ❌ iOS无对应 |
| `player/thirdparty/Kodi.java` | - | ❌ iOS无对应 |
| `player/EXOmPlayer.java` | - | ❌ 不适用 |
| `player/IjkmPlayer.java` | - | ❌ 不适用 |
| `server/ControlManager.java` | `Core/Server/ControlManager.swift` | 🔲 待实现 |
| `server/RemoteServer.java` | `Core/Server/RemoteServer.swift` | 🔲 待实现 |
| `server/WebController.kt` | `Core/Server/WebController.swift` | 🔲 待实现 |
| `server/DataReceiver.java` | `Core/Server/DataReceiver.swift` | 🔲 待实现 |
| `subtitle/SubtitleLoader.java` | `Features/Player/SubtitleLoader.swift` | 🔲 待实现 |
| `subtitle/SubtitleEngine.java` | `Features/Player/SubtitleEngine.swift` | 🔲 待实现 |
| `subtitle/format/FormatSRT.java` | `Features/Player/Format/FormatSRT.swift` | 🔲 待实现 |
| `subtitle/format/FormatASS.java` | `Features/Player/Format/FormatASS.swift` | 🔲 待实现 |
| `subtitle/format/FormatTTML.java` | `Features/Player/Format/FormatTTML.swift` | 🔲 待实现 |
| `ui/activity/DriveActivity.java` | `Features/Drive/DriveView.swift` | 🔲 待实现 |
| `ui/activity/AppsActivity.java` | `Features/Apps/AppsView.swift` | 🔲 待实现 |
| `ui/activity/PushActivity.java` | `Features/Push/PushView.swift` | 🔲 待实现 |
| `ui/activity/FastSearchActivity.java` | `Features/Search/FastSearchView.swift` | 🔲 待实现 |
| `ui/dialog/DanmuSettingDialog.java` | `Features/Player/DanmuSettingView.swift` | 🔲 待实现 |
| `ui/dialog/ApiHistoryDialog.java` | `Features/Settings/ApiHistoryView.swift` | 🔲 待实现 |
| `ui/dialog/BackupDialog.java` | `Features/Settings/BackupView.swift` | 🔲 待实现 |
| `ui/dialog/GridFilterDialog.java` | `Features/Home/GridFilterView.swift` | 🔲 待实现 |
| `ui/dialog/MediaSettingDialog.java` | `Features/Player/MediaSettingView.swift` | 🔲 待实现 |
| `ui/dialog/SearchCheckboxDialog.java` | `Features/Search/SearchSourceSelectView.swift` | 🔲 待实现 |
| `ui/dialog/RemoteDialog.java` | `Features/Settings/RemoteView.swift` | 🔲 待实现 |
| `ui/dialog/PushDialog.java` | `Features/Push/PushDialog.swift` | 🔲 待实现 |
| `ui/dialog/WebdavDialog.java` | `Features/Drive/WebdavConfigView.swift` | 🔲 待实现 |
| `ui/dialog/AlistDriveDialog.java` | `Features/Drive/AlistConfigView.swift` | 🔲 待实现 |
| `ui/tv/QRCodeGen.java` | `Common/Utils/QRCodeGen.swift` | 🔲 待实现 |
| `util/M3U8.java` | `Core/Player/M3U8AdFilter.swift` | 🔲 待实现 |
| `util/Proxy.java` | `Core/Network/Proxy.swift` | 🔲 待实现 |
| `util/PlayerHelper.java` | `Core/Player/PlayerHelper.swift` | 🔲 待实现 |
| `util/SearchHelper.java` | `Core/Search/SearchHelper.swift` | 🔲 待实现 |
| `util/HawkConfig.java` | `Core/Config/AppConfig.swift` | 🔲 待实现 |
| `util/HistoryHelper.java` | `Core/Storage/HistoryHelper.swift` | 🔲 待实现 |
| `util/VideoParseRuler.java` | `Core/Player/VideoParseRuler.swift` | 🔲 待实现 |
| `util/StorageDriveType.java` | `Models/StorageDriveType.swift` | 🔲 待实现 |
| `viewmodel/drive/*` | `Features/Drive/DriveViewModel.swift` | 🔲 待实现 |
| `viewmodel/SubtitleViewModel.java` | `Features/Player/SubtitleViewModel.swift` | 🔲 待实现 |

---

## 📋 直播相关配置待实现 (Android: HawkConfig.java)

| 配置项 | 说明 | 状态 |
|-------|------|------|
| `LIVE_CHANNEL` | 记住最后播放的频道名 | 🔲 待实现 |
| `LIVE_CHANNEL_GROUP` | 记住最后播放的频道分组 | 🔲 待实现 |
| `LIVE_CHANNEL_REVERSE` | 频道列表反转显示 | 🔲 待实现 |
| `LIVE_CROSS_GROUP` | 跨分组切换频道 | 🔲 待实现 |
| `LIVE_CONNECT_TIMEOUT` | 直播连接超时设置 | 🔲 待实现 |
| `LIVE_SHOW_NET_SPEED` | 显示网络速度 | 🔲 待实现 |
| `LIVE_SHOW_TIME` | 显示时间 | 🔲 待实现 |
| `LIVE_SKIP_PASSWORD` | 跳过频道密码 | 🔲 待实现 |
| `LIVE_PLAYER_TYPE` | 直播播放器类型 | 🔲 待实现 |

## 📋 首页/设置相关配置待实现

| 配置项 | 说明 | 状态 |
|-------|------|------|
| `HOME_REC` | 首页推荐类型 (豆瓣/推荐/历史) | 🔲 待实现 |
| `HOME_REC_STYLE` | 首页推荐样式 (Grid/Line) | 🔲 待实现 |
| `HOME_NUM` | 历史记录数量 (20/40/60/80/100) | 🔲 待实现 |
| `HOME_SHOW_SOURCE` | 首页显示源名称 | 🔲 待实现 |
| `HOME_LOCALE` | 语言设置 (中文/英文) | 🔲 待实现 |
| `HOME_SEARCH_POSITION` | 搜索栏位置 (上/下) | 🔲 待实现 |
| `HOME_MENU_POSITION` | 菜单位置 (上/下) | 🔲 待实现 |
| `HOME_DEFAULT_SHOW` | 启动时直接进直播 | 🔲 待实现 |
| `FAST_SEARCH_MODE` | 快速搜索模式 | 🔲 待实现 |
| `SEARCH_VIEW` | 搜索结果视图 (列表/缩略图) | 🔲 待实现 |

---

## 📝 开发笔记

### 与 Android 版差异

1. **JAR 爬虫不支持**: iOS 无法运行 Java 代码，需要使用 JavaScriptCore 执行 JS 爬虫
2. **Python 爬虫不支持**: 需要寻找替代方案或使用服务端代理
3. **播放器**: 使用 AVPlayer 替代 IJK/EXO 播放器
4. **本地存储**: 使用 UserDefaults/Core Data 替代 Room 数据库
5. **弹幕**: 需要自己实现弹幕渲染，或使用第三方库

### 技术方案参考

#### JavaScriptCore 执行 JS 爬虫
```swift
import JavaScriptCore

let context = JSContext()
context?.evaluateScript(jsCode)
let result = context?.evaluateScript("spider.homeContent()")
```

#### 弹幕实现方案
- 使用 CALayer 动画
- 或集成 DanmakuKit 等第三方库

#### WebDAV 实现
- 使用 FilesProvider 库
- 或自己实现 PROPFIND/GET 请求

### 参考资源

- Android 源码: `android/app/src/main/java/com/github/tvbox/osc/`
- 配置格式: 参见 `android/README.md`

---

## 📅 更新日志

### 2025-12-22 (解析接口实现)
- ✅ 新增 `Core/Parser/ParserManager.swift` - 解析管理器
- ✅ 新增 `Core/Parser/JsonParser.swift` - JSON 解析接口并发调用
- ✅ 更新 `DetailViewModel` 集成解析功能
- ✅ 支持 JSON 解析 (type=1)
- ✅ 支持 JSON 扩展解析 (type=2) - 并发多解析器
- ✅ 支持 JSON 聚合解析 (type=3)
- ✅ 支持超级解析 (type=4)
- ✅ WebView 嗅探 (type=0) - SnifferWebView.swift, VideoSniffer.swift
- ✅ 递归解析 - parse=1 时自动继续解析 (最大深度3)
- ✅ 代理解析 SuperParse - iframe 并发嗅探
- ✅ 嗅探规则管理 VideoParseRuler - 自定义规则/过滤/正则/脚本

### 2025-12-22 (Android 功能对比完善)
- ✅ 完善 TODO 列表，新增 Android 中有但 iOS 未实现的功能
- 🔲 新增: M3U8 广告过滤功能待实现
- 🔲 新增: DNS over HTTPS (DoH) 支持待实现
- 🔲 新增: 推送功能 (PushActivity) 待实现
- 🔲 新增: 分词搜索功能待实现
- 🔲 新增: 搜索源筛选功能 (SearchCheckboxDialog) 待实现
- 🔲 新增: 分类筛选 (GridFilterDialog) 待实现
- 🔲 新增: 媒体设置 (MediaSettingDialog) 待实现
- 🔲 新增: 播放器增强功能 (渲染模式/视频净化等) 待实现
- 🔲 新增: 直播设置项 (频道记忆/网速显示/超时设置等) 待实现
- 🔲 新增: 首页配置项 (推荐类型/样式/历史数量等) 待实现
- 📋 更新: Android 文件对照表，新增 30+ 文件映射

### 2025-12-22 (直播源解析 & EPG)
- ✅ 完成直播源解析架构
  - 新增 `LiveParser.swift` - 解析器协议和管理器
  - 新增 `TxtLiveParser.swift` - TXT 格式解析 (支持多源、分组密码)
  - 新增 `M3uLiveParser.swift` - M3U/M3U8 格式解析 (自动合并多源)
  - 新增 `JsonLiveParser.swift` - TVBOX JSON 格式解析
- ✅ 完成 EPG 电子节目单功能
  - 新增 `EpgManager.swift` - EPG 管理器
  - 支持 XMLTV 格式解析
  - 支持 JSON 格式解析
  - 支持简单文本格式解析
  - 自动缓存 (6小时有效期)
- ✅ 完善 LiveViewModel
  - 集成直播源解析器
  - 支持多直播源合并
  - 集成 EPG 显示
- ✅ 完善频道列表 UI
  - 显示当前节目
  - 显示播放进度条

### 2025-12-22 (Spider & API 实现)
- ✅ 完成 Spider 爬虫架构实现
  - 新增 `Spider.swift` - 爬虫协议定义
  - 新增 `SpiderManager.swift` - 爬虫管理器
  - 新增 `JsonSpider.swift` - JSON 类型站点爬虫
  - 新增 `JsSpider.swift` - JavaScript 爬虫 (JavaScriptCore)
- ✅ 完善 HomeViewModel
  - 支持分页加载视频列表
  - 支持筛选功能
  - 支持多站点快速搜索
- ✅ 完善 DetailViewModel
  - 实现详情页 API 调用
  - 支持获取播放地址
  - 支持历史记录
- ✅ 完善 SearchViewModel
  - 支持当前站点搜索
  - 支持快速搜索 (多站点并行)
  - 支持聚合搜索
  - 支持搜索分页

### 2025-12-22
- 同步 Android 端新增功能到 TODO
- 新增: 弹幕功能待实现
- 新增: 网盘/存储驱动待实现 (WebDAV, Alist)
- 新增: 远程控制待实现
- 新增: 搜索历史持久化待实现
- 新增: 备份功能待实现
- 更新: Android 文件对照表

### 2025-12-22 (初始)
- 完成基础架构搭建
- 完成所有主要页面 UI
- 完成本地存储功能
- 完成基础播放器功能
