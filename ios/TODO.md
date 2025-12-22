# TVBox iOS 移植进度

> 最后更新: 2025-12-22
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

#### 播放器增强
- [ ] 画中画 (PiP) 支持
- [ ] 后台音频播放
- [ ] 倍速播放 (0.5x - 3.0x)
- [ ] 画面比例调整 (默认/16:9/4:3/填充/原始)
- [ ] 手势控制 (音量/亮度/进度)
- [ ] 自动下一集
- [ ] 续播功能 (记住播放位置)
- [ ] 播放器类型切换

#### 字幕支持 (Android: SubtitleHelper, SubtitleLoader)
- [ ] SRT 字幕解析 (FormatSRT)
- [ ] ASS 字幕解析 (FormatASS)
- [ ] TTML 字幕解析 (FormatTTML)
- [ ] 在线字幕搜索
- [ ] 字幕样式设置 (字体、大小、颜色)
- [ ] 字幕时间轴调整

#### 解析接口
- [ ] VIP 视频解析支持
- [ ] 嗅探播放地址
- [ ] 多解析源切换
- [ ] WebView 嗅探

#### XML 类型站点支持
- [ ] XML 格式解析 (AbsXml, AbsSortXml)
- [ ] 资源站 API 适配

---

### 🟢 低优先级

#### 远程控制 (Android: WebController.kt, RemoteServer)
- [ ] 本地 HTTP 服务器
- [ ] Web 远程控制 API
- [ ] 接收推送播放
- [ ] 远程配置推送

#### 投屏功能
- [ ] AirPlay 支持
- [ ] DLNA 投屏

#### 二维码扫描
- [ ] 扫码输入配置地址
- [ ] 扫码添加网盘

#### 备份与同步 (Android: BackupDialog)
- [ ] iCloud 同步收藏/历史
- [ ] WebDAV 备份
- [ ] 配置导入/导出

#### 搜索增强 (Android: SearchHistory, FastSearchActivity)
- [ ] 搜索历史持久化 (Room -> Core Data)
- [ ] 快速搜索 (多站点并行)
- [ ] 搜索结果合并去重

#### 应用管理 (Android: AppsActivity)
- [ ] 第三方播放器调用
- [ ] 应用列表管理

#### UI/UX 优化
- [ ] 深色模式适配
- [ ] iPad 适配
- [ ] tvOS 适配
- [ ] 自定义主题色
- [ ] 骨架屏加载
- [ ] 下拉刷新动画

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
| `bean/DriveFolderFile.java` | `Models/DriveFolderFile.swift` | 🔲 待实现 |
| `bean/SearchResultWrapper.java` | - | 🔲 待实现 |
| `bean/SubtitleBean.java` | `Models/Subtitle.swift` | 🔲 待实现 |
| `bean/VodSeriesGroup.java` | - | 🔲 待实现 |
| `cache/SearchHistory.java` | `Core/Storage/SearchHistory.swift` | 🔲 待实现 |
| `cache/StorageDrive.java` | `Models/StorageDrive.swift` | 🔲 待实现 |
| `player/danmu/Parser.java` | `Features/Player/DanmuParser.swift` | 🔲 待实现 |
| `player/EXOmPlayer.java` | - | ❌ 不适用 |
| `player/IjkmPlayer.java` | - | ❌ 不适用 |
| `server/WebController.kt` | `Core/Server/WebController.swift` | 🔲 待实现 |
| `ui/activity/DriveActivity.java` | `Features/Drive/DriveView.swift` | 🔲 待实现 |
| `ui/activity/AppsActivity.java` | `Features/Apps/AppsView.swift` | 🔲 待实现 |
| `ui/dialog/DanmuSettingDialog.java` | `Features/Player/DanmuSettingView.swift` | 🔲 待实现 |
| `ui/dialog/ApiHistoryDialog.java` | `Features/Settings/ApiHistoryView.swift` | 🔲 待实现 |
| `ui/dialog/BackupDialog.java` | `Features/Settings/BackupView.swift` | 🔲 待实现 |
| `ui/dialog/WebdavDialog.java` | `Features/Drive/WebdavConfigView.swift` | 🔲 待实现 |
| `ui/dialog/AlistDriveDialog.java` | `Features/Drive/AlistConfigView.swift` | 🔲 待实现 |
| `util/StorageDriveType.java` | `Models/StorageDriveType.swift` | 🔲 待实现 |
| `viewmodel/drive/*` | `Features/Drive/DriveViewModel.swift` | 🔲 待实现 |

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
