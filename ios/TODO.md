# TVBox iOS/macOS 移植进度

> 更新: 2026-10-19
> 对照基准: Android `android/`（提交 `97d9851`，261 个类）↔ iOS `ios/tvbox/`（提交 `3780077`）
> 状态以实际代码为准，不以文件是否存在为准。每一步都写了「验收」，做完按验收标准自测后再勾选。

状态: ✅ 已完成 · 🟡 部分完成 · ❌ 未开始 · ⛔ 不移植（iOS 没有对等能力）

## 总览

| # | 类别 | 状态 | 一句话现状 |
|---|------|------|-----------|
| 1 | 配置解析 | 🟡 | 只支持 Cat 配置包和配置中心 full-config；**标准 TVBox JSON 配置已不支持** |
| 2 | 站点/爬虫 | 🟡 | Cat 配置包走 Node 可用；JSON(type 1)、JS(type 3) Spider 在但缺配置入口；XML、jar、py 不支持 |
| 3 | 首页与分类 | 🟡 | 首页、豆瓣推荐、分类分页可用；缺筛选 |
| 4 | 搜索 | 🟡 | 当前站/聚合/快速搜索、历史可用；缺指定搜索源，热词是写死的 |
| 5 | 详情 | 🟡 | 线路、剧集、收藏、续播可用；缺倒序、切源（换站点） |
| 6 | 点播播放器 | 🟡 | AVPlayer 播放、上下集、续播、请求头可用；倍速/画质/字幕菜单是空按钮 |
| 7 | 解析与嗅探 | 🟡 | 解析器代码齐全，但 `parses` 永远为空，需要解析的视频都会失败 |
| 8 | 直播 | 🟡 | 解析器和界面都有，但**没有数据来源**，直播页永远为空 |
| 9 | 历史与收藏 | ✅ | 历史（含每集进度）、收藏、搜索历史、配置历史可用 |
| 10 | 设置 | 🟡 | 配置/站点/解析/配置中心可用；播放设置不保存也不生效 |
| 11 | 网盘与配置中心 | 🟡 | Node 配置包自带网盘和配置中心，已接入；扫码登录后的网盘播放未实测 |
| 12 | 字幕 | ❌ | |
| 13 | 弹幕 | ❌ | |
| 14 | 网络增强与去广告 | ❌ | `ads`/`hosts` 字段解析了但没人用 |
| 15 | 远程控制、推送、投屏 | ❌ | |
| 16 | 本地文件与备份 | ❌ | |
| 17 | 平台适配（iPad/Mac） | 🟡 | Catalyst 与原生 macOS 都能构建运行并跑 Node；缺键盘、菜单、全屏 |
| 18 | 工程与稳定性 | 🟡 | 无单元测试；有两套首页/搜索实现；`SMOKE_TEST.md` 过时 |

## 建议移植顺序

先打通「配置 → 站点 → 播放」这条主链路，再补体验，最后做大功能。

1. **恢复标准 JSON 配置解析**（第 1 类）。这是 Android 最主要的配置格式，不恢复的话解析、直播都没有数据。
2. **接通直播数据**（第 8 类）。
3. **用真实解析接口验证解析链路**（第 7 类）。
4. **播放器补齐 + 播放设置生效**（第 6、10 类）。
5. **分类筛选、详情倒序/切源、指定搜索源**（第 3、4、5 类）。
6. **网盘扫码登录后播放实测，Node 宿主稳定性**（第 11、2 类）。
7. **字幕**（第 12 类）→ **弹幕**（第 13 类）。
8. **M3U8 去广告、hosts**（第 14 类）。
9. **AirPlay、推送、扫码输入**（第 15 类）。
10. **备份恢复、本地文件**（第 16 类）。
11. **iPad/Mac 体验**（第 17 类）。

---

## 1. 配置解析 🟡

- Android: `api/ApiConfig.java`（`FindResult` 解密、`parseJson`、`urls` 多仓）、`util/DefaultConfig.java`、`util/AES.java`
- iOS: `Core/Config/ApiConfig.swift`

已完成:
- ✅ Cat 配置包（`.js.md5` → `.js`）交给 Node 运行，站点列表读配置包 `/config`。
- ✅ 旧格式 `globalThis.websiteBundle` 原生静态解析（Node 不可用时的兜底），站点列表按内容 md5 缓存。
- ✅ 配置中心 `/full-config` 格式。
- ✅ 配置缓存、配置历史。

待办:
- [ ] **恢复标准 TVBox JSON 配置解析**: `sites`、`parses`、`lives`、`spider`、`wallpaper`、`flags`、`rules`、`hosts`、`ads`、`doh`。
  - 这段代码在 `9253199` 被删掉，可从 `git show 4fbb229:ios/tvbox/Core/Config/ApiConfig.swift` 里的 `RemoteConfig` 解码逻辑找回再对齐。
  - 验收: 用一个公开 JSON 配置，站点列表、解析列表、直播源都能加载，首页能出内容。
- [ ] 加密配置: Base64、`$#key#$` AES-CBC、带配置密钥的 AES-ECB、图片里藏配置（对照 `ApiConfig.FindResult`）。
  - 验收: 各准备一个加密样例，解密后能正常加载。
- [ ] 多仓配置 `urls`（Android 设置里的「线路选择」）。
  - 验收: 多仓配置能列出线路，切换后重新加载。
- [ ] 配置加载失败的可读提示: URL 无效、网络失败、JSON 无效、解密失败分别提示。
- [ ] 给配置解析加单元测试，样例放在测试目录（目前工程没有测试 target）。

## 2. 站点/爬虫 🟡

- Android: `catvod/crawler/JarLoader.java`、`JsLoader.java`、`js/*`、`python/IPyLoader.java`、`bean/AbsXml.java`、`AbsJson.java`
- iOS: `Core/Spider/*`、`Core/Node/CatNodeRuntime.swift`、`Resources/catnode-bootstrap.js`

已完成:
- ✅ Cat 配置包: iOS 用 nodejs-mobile，Mac 用打包的官方 node 子进程，`CatNodeSpider` 调用 `/spider/{key}/{type}/*`。真实配置包 96 个站点验证过首页/分类/搜索/详情/播放。
- ✅ `JsonSpider`（type 1）、`JsSpider`（JavaScriptCore）、`QuickJSSpider`（type 3 的 JS 站点）。
- ✅ 原生适配（Node 不可用时兜底）: `wexDuBoKu`、`wexYueYue`、`animemodu`、`dongli`、`duanjuweiguan`、`hanxiaoquan`、`bookWuWei`、`bili`、`wodequark`。

待办:
- [ ] 第 1 类恢复后，用真实 JSON 配置分别验证 type 1 和 type 3（JS）站点。
  - 验收: 每种至少一个站点能走通首页 → 详情 → 播放。
- [ ] Node 宿主: App 回到前台时检查配置包服务是否还活着，必要时重新加载；Mac 上 node 子进程意外退出后重新拉起。
  - 验收: iOS 切后台 10 分钟后回来还能请求；Mac 上手动 kill node 后能自动恢复。
- [ ] XML 站点（type 0，对照 `AbsXml`）。
- [ ] 远程站点（type 4）。
- [ ] 列出 iOS 无法运行的站点格式，在站点列表里标明原因: jar（`csp_` 类，DexClassLoader）、py（Chaquopy）。
- [ ] 决定原生适配（`WebsiteBundleNativeSpider` 等）是否保留: Node 已覆盖时可以只留兜底或删除。

不移植:
- ⛔ jar 爬虫（需要 JVM/DEX）。
- ⛔ Python 爬虫（`pyramid` 模块，Chaquopy）。

## 3. 首页与分类 🟡

- Android: `ui/activity/HomeActivity.java`、`ui/fragment/GridFragment.java`、`ui/dialog/GridFilterDialog.java`
- iOS: `Features/Home/HomeContentView.swift`、`HomeContentViewModel.swift`、`CategoryDetailView.swift`

已完成:
- ✅ 首页分类与推荐、下拉刷新、站点切换。
- ✅ 站点首页为空时显示豆瓣推荐，豆瓣卡片跳快速搜索。
- ✅ 分类页加载与滚动分页。

待办:
- [ ] 分类筛选: 读取首页返回的 `filters`，在分类页提供筛选面板，筛选条件传给 `categoryContent(extend:)`。
  - 验收: 豆瓣「电影筛选」能按类型/地区/年份筛选，翻页保留筛选。
- [ ] 切换分类再回来时保留该分类的筛选条件（Android 存在 `MovieSort.filterSelect` 里，只在内存中，不持久化）。
- [ ] 首页设置项（对照 Android「首页推荐」「首页多行」）: 推荐来源（豆瓣/站点/无）。

## 4. 搜索 🟡

- Android: `ui/activity/SearchActivity.java`、`FastSearchActivity.java`、`ui/dialog/SearchCheckboxDialog.java`、`QuickSearchDialog.java`、`util/SearchHelper.java`
- iOS: `Features/Search/SearchView.swift`、`FastSearchView.swift`

已完成:
- ✅ 当前站搜索、聚合搜索（并发、去重）、搜索历史。
- 🟡 热词: 目前是写死在 `SearchView.loadHotKeywords` 里的 6 个片名。
- ✅ 快速搜索（按片名搜索所有站点，Android `FastSearchActivity` 同规则），结果记录来源站点。

待办:
- [ ] 指定搜索源: 选择参与聚合搜索的站点并保存（对照 `SearchCheckboxDialog`、`SearchHelper`）。
  - 验收: 只勾 2 个站点时只搜这 2 个，重启后保留。
- [ ] 单个站点搜索失败或超时不影响其他结果，失败站点可见。
- [ ] 热词改为在线获取（豆瓣/站点热搜）。
- [ ] 合并 `SearchView` 与 `FastSearchView` 的多站点搜索逻辑，避免两套实现。

## 5. 详情 🟡

- Android: `ui/activity/DetailActivity.java`、`ui/dialog/DescDialog.java`、`EpisodeDialog.java`
- iOS: `Features/Detail/DetailView.swift`

已完成:
- ✅ 线路切换、剧集列表、立即播放、恢复上次线路、收藏、按来源站点取详情。
- ✅ 配置中心卡片直接打开配置中心。

待办:
- [ ] 剧集正序/倒序切换。
- [ ] 切源: 用片名在其他 `changeable` 站点找同名影片并切换，保留当前集数；详情加载失败时自动触发（对照 `DetailActivity.startDetailFallback`）。
  - 验收: 当前站点详情失败时自动换到另一站点的同名影片，停在原来的集数。
- [ ] 简介展开/收起（对照 `DescDialog`）。

## 6. 点播播放器 🟡

- Android: `player/MyVideoView.java`、`player/controller/VodController.java`、`ui/fragment/PlayFragment.java`、`util/PlayerHelper.java`、`util/AudioTrackMemory.java`、`player/MusicPlaybackService.java`
- iOS: `Features/Player/PlayerView.swift`

已完成:
- ✅ AVPlayer 播放、暂停、拖动、快进快退。
- ✅ 上一集/下一集、播完自动下一集、每集续播。
- ✅ 站点请求头（UA/Referer/Cookie）注入、按 `format` 指定 MIME。

待办:
- [ ] 倍速（菜单里「倍速」目前是空按钮）。验收: 0.5x–3x 可切换，切集后保持。
- [ ] 画面比例/缩放（Android「画面缩放」、播放器里的 16:9）。
- [ ] 音轨、内嵌字幕轨选择（AVPlayer `AVMediaSelectionGroup`，对照「音轨/视轨」）。
- [ ] 跳过片头片尾（Android「片头尾」，按影片记忆时间点）。
- [ ] 重播、刷新（重新取播放地址）。
- [ ] 播放失败自动换线路/换解析（Android「自动换线」）。
- [ ] 画中画（iOS）。
- [ ] 后台播放与锁屏控制: `AVAudioSession`、`MPNowPlayingInfoCenter`、`MPRemoteCommandCenter`（对照 `MusicPlaybackService`）。
- [ ] 播放时禁止自动锁屏。
- [ ] 外部播放器（可选）: 通过 URL scheme 交给 VLC/Infuse，对照 `player/thirdparty`。

不移植:
- ⛔ IJK、Exo、阿里播放器及其解码/缓存设置（iOS 统一用 AVPlayer）。

## 7. 解析与嗅探 🟡

- Android: `util/parser/SuperParse.java`、`JsonParallel.java`、`util/VideoParseRuler.java`、`bean/ParseBean.java`、`ui/activity/...`（WebView 嗅探）
- iOS: `Core/Parser/ParserManager.swift`、`JsonParser.swift`、`SuperParse.swift`、`SnifferWebView.swift`、`VideoSniffer.swift`、`VideoParseRuler.swift`

已完成（代码层面）:
- ✅ JSON 解析接口并发、多解析源切换、WebView 嗅探、SuperParse iframe 并发嗅探、递归解析、嗅探规则。

待办:
- [ ] 依赖第 1 类: 配置里的 `parses`、`flags`、`rules` 要能加载进来，现在 `parses` 永远为空，`parse=1` 的视频都会失败。
  - 验收: 一个需要 VIP 解析的站点，点剧集能解析出地址并播放。
- [ ] 播放器里切换解析接口（Android 播放器「解析」按钮）。
- [ ] 与 Android `SuperParse`、`JsonParallel` 的超时、优先级逐项对齐。
- [ ] Mac（Catalyst/原生）上验证 WKWebView 嗅探。

## 8. 直播 🟡

- Android: `ui/activity/LivePlayActivity.java`、`player/controller/LiveController.java`、`util/live/TxtSubscribe.java`、`util/EpgUtil.java`、`util/EpgNameFuzzyMatch.java`、`bean/Live*.java`、`ui/dialog/LivePasswordDialog.java`
- iOS: `Features/Live/LiveView.swift`、`Core/Live/*`

已完成（代码层面）:
- ✅ TXT、M3U、TVBox JSON 直播源解析，EPG 加载，频道分组界面，直播播放请求头，多源切换。

待办:
- [ ] **接通数据来源**: `LiveView` 只读 `ApiConfig.liveConfigs`，而它在所有配置路径里都被清空；设置里的「直播地址」保存了但没有使用。
  - 做法: 第 1 类恢复 `lives` 解析，同时让「直播地址」生效（有直播地址时优先用它）。
  - 验收: 填一个公开 M3U 地址，直播页出现分组和频道，至少一个频道能播。
- [ ] EPG 频道名模糊匹配（对照 `EpgNameFuzzyMatch`）、EPG 缓存与按天刷新。
- [ ] 回看（catchup/时移）。
- [ ] 加密分组（输入密码才显示，对照 `LivePasswordDialog`）。
- [ ] 直播设置: 画面比例、超时自动换源、显示时间/网速（对照 `LiveSettingGroup`）。
- [ ] 换台交互: 上下切台、数字选台（Mac 键盘）。

## 9. 历史与收藏 ✅

- Android: `cache/VodRecord*.java`、`VodCollect*.java`、`util/HistoryHelper.java`、`ui/activity/HistoryActivity.java`、`CollectActivity.java`
- iOS: `Core/Storage/StorageManager.swift`、`Features/History/HistoryView.swift`、`Features/Collect/CollectView.swift`

已完成:
- ✅ 观看历史（记录来源站点，每集进度，站点不在时转快速搜索）、收藏、搜索历史、配置历史。

待办:
- [ ] 历史条数上限设置（Android「历史记录」）。
- [ ] 历史合并（同名影片不同站点合为一条，Android「历史合并」）。
- [ ] iCloud 同步（可选，后置）。

## 10. 设置 🟡

- Android: `ui/fragment/ModelSettingFragment.java`、`util/HawkConfig.java`、`ui/dialog/*`
- iOS: `Features/Settings/SettingsView.swift`

已完成:
- ✅ 配置地址与历史、当前站点、默认解析、刷新配置、配置中心入口、清除缓存、关于。
- ✅ Mac 上设置页与弹窗不再分栏显示。

待办:
- [ ] **播放设置生效**: 「播放器」「默认画质」「后台播放」「自动下一集」只在启动时读一次，改了不保存，也没有任何地方使用。
  - 验收: 关闭「自动下一集」后播完不再自动跳集，重启 App 后设置保留。
- [ ] 「扫码输入」按钮只改了状态，没有扫码界面（iOS 用 `DataScannerViewController` 或 `AVCaptureSession`，Mac 隐藏该按钮）。
- [ ] 清除缓存只清了 `URLCache` 和临时目录，补上图片缓存、配置缓存、Node 配置包缓存。
- [ ] Android 其他设置按需移植: 下次进入（点播/直播）、搜索展示样式、聚合搜索开关、壁纸、调试模式。

## 11. 网盘与配置中心 🟡

- Android: 由配置包/jar 实现，App 侧无对应代码
- iOS: `Features/ConfigCenter/*`、`Core/Spider/QuarkNetDiskProvider.swift`、`ConfigCenterNativeSpider.swift`、`WodeQuarkNativeSpider.swift`，详见 `ios/CONFIG_CENTER_NETDISK.md`

已完成:
- ✅ Node 配置包自带配置中心（`/website`）: 设置 → 配置中心、「配置|中心」站点卡片都能直接打开。
- ✅ 网盘线路（夸克/UC/百度/115）随配置包一起工作，未登录时提示去配置中心登录。
- ✅ 原生配置中心与夸克 provider（Node 不可用时兜底）。

待办:
- [ ] 在配置中心扫码登录夸克，再播放一个夸克线路。验收: 能播放，重启后不用重新登录。
- [ ] 真机上再验证一遍（iOS 真机后台限制和模拟器不同）。
- [ ] Node 方案覆盖后，决定原生网盘兜底代码是否保留（原 TODO 里的 UC/阿里/天翼/123 provider 搬运可以不做）。

## 12. 字幕 ❌

- Android: `subtitle/*`（`SubtitleEngine`、`SubtitleLoader`、`SubtitleFinder`、`format/*`）、`ui/dialog/SubtitleDialog.java`、`SearchSubtitleDialog.java`、`util/SubtitleHelper.java`
- iOS: 无

待办:
- [ ] 内嵌字幕轨选择（与第 6 类音轨一起做，AVPlayer 原生支持）。
- [ ] 外挂字幕: SRT、ASS（先纯文本）、VTT 解析，叠加渲染到播放器。
- [ ] 站点 `playerContent` 返回的字幕地址自动加载。
- [ ] 字幕样式（字号、颜色、位置）和时间轴偏移。
- [ ] 在线字幕搜索（对照 `SearchSubtitleDialog`）。

## 13. 弹幕 ❌

- Android: `api/DanmakuApi.java`、`player/danmu/*`、`bean/Danmu*.java`、`ui/dialog/DanmuSettingDialog.java`、`SearchDanmuDialog.java`、`DanmuApiDialog.java`、`util/DanmuHelper.java`、`player/src/.../tv/danmaku`
- iOS: 无

待办:
- [ ] 弹幕数据模型与 XML（B 站格式）解析。
- [ ] 弹幕渲染层（滚动/顶部/底部，叠加在播放器上）。
- [ ] 站点 `playerContent` 返回的 `danmaku` 地址自动加载（`PlayerContent.danmaku` 已解析但未使用）。
- [ ] 弹幕设置: 开关、透明度、字号、速度、显示区域。
- [ ] 弹幕搜索接口（配置里的 `danmuSearchUrl`，对照 `DanmakuApi`）。

## 14. 网络增强与去广告 ❌

- Android: `util/M3u8.java`、`util/AdBlocker.java`、`catvod/net/OkDns.java`、`okhttp3/dnsoverhttps/*`、`util/net/OkProxySelector.java`、`util/TLSSocketFactory.java`
- iOS: `ApiConfig` 里解析了 `adHosts`、`hosts`，但没有任何地方使用

待办:
- [ ] M3U8 去广告: 按域名、按切片时长/不连续标记识别广告片段，生成干净的 m3u8 给 AVPlayer（需要本地代理或 `AVAssetResourceLoaderDelegate`）。
  - 验收: 一个带插播广告的 m3u8，播放时跳过广告。
- [ ] WebView 嗅探时屏蔽 `ads` 域名（对照 `AdBlocker`）。
- [ ] `hosts` 域名映射。
- [ ] 安全 DNS（DoH）。iOS 17 可用 `NWParameters.PrivacyContext` 加密 DNS，优先级低。

## 15. 远程控制、推送、投屏 ❌

- Android: `server/*`（`RemoteServer` 本地 HTTP 服务 9978 端口: `/action`、`/push`、`/proxy`、`/file`、`/upload` 等）、`ui/activity/PushActivity.java`、`ui/dialog/RemoteDialog.java`、`SearchRemoteTvDialog.java`、`util/IpScanning.java`、`dlna/*`、`ui/dialog/CastDeviceDialog.java`、`receiver/*`
- iOS: 无（配置中心里已有二维码生成）

待办:
- [ ] AirPlay 投屏: 播放器加 `AVRoutePickerView`，开启 `allowsExternalPlayback`。验收: 能投到 Apple TV 或支持 AirPlay 的电视。
- [ ] 推送给局域网里的 Android TVBox: 扫描 9978 端口设备，把当前视频或配置推过去（对照 `IpScanning`、`SearchRemoteTvDialog`）。
- [ ] 接收推送: App 内起 HTTP 服务（iOS 只能前台运行），手机网页提交地址后直接播放（对照 `RemoteServer`、`RemoteDialog` 二维码）。
- [ ] URL scheme 接收外部推送（对照 `receiver/PushReceiver`）。
- [ ] DLNA 投屏（可选，需要第三方库，对照 `dlna/*`）。

## 16. 本地文件与备份 ❌

- Android: `ui/activity/LocalFileActivity.java`、`ui/dialog/BackupDialog.java`
- iOS: 无

待办:
- [ ] 本地文件播放: iOS 用文件选择器，Mac 用打开面板，支持本地视频和本地配置文件。
- [ ] 备份与恢复: 导出/导入历史、收藏、配置地址、设置（JSON 文件）。

## 17. 平台适配（iPad/Mac） 🟡

- iOS: `Platform/*`

已完成:
- ✅ Mac Catalyst 与原生 macOS 都能构建运行；Mac 上 Node 以子进程运行。
- ✅ Mac 启动时配置解析不阻塞主线程。
- ✅ 设置页、弹窗在 Mac/iPad 上不再分栏显示；原生 macOS 播放器窗口尺寸修复。

待办:
- [ ] 决定 Mac 主线: Catalyst 还是原生 macOS（现在两者都在构建，Xcode 默认「My Mac」是原生版）。
- [ ] Mac 键盘: 空格播放/暂停、左右快退快进、上下切台、ESC 退出全屏。
- [ ] Mac 菜单栏: 打开配置、刷新、播放控制、全屏。
- [ ] 播放器全屏与窗口尺寸适配。
- [ ] iPad 分栏布局。
- [ ] Mac 上架前: 开启 App Sandbox 后验证 node 子进程；需要支持 Intel 时打包 x86_64 版 node。
- [ ] 深色模式完整检查。

## 18. 工程与稳定性 🟡

- [ ] 加单元测试 target，先覆盖配置解析、直播源解析、Spider 返回值解码。
- [ ] 更新 `ios/SMOKE_TEST.md`（里面还是早期 `wexDuBoKu` 原生适配的验证步骤）。
- [ ] 清理未使用的旧首页 `Features/Home/HomeView.swift`、`HomeViewModel.swift`（`MainView` 实际用的是 `HomeContentView`）。

## 不移植清单

| Android | 原因 | iOS 替代 |
|---------|------|----------|
| `catvod/crawler/JarLoader.java`（jar 爬虫） | iOS 不能加载 DEX/JVM | Cat 配置包（Node）或 JS 站点 |
| `pyramid` 模块、`IPyLoader`（Python 爬虫） | 依赖 Chaquopy | 无 |
| `player/IjkMediaPlayer.java`、`ExoPlayer.java` 等 | Android 播放内核 | AVPlayer |
| `player/thirdparty/*`（Kodi、MX、Reex、VLC） | Android Intent | 可选: URL scheme 调用 iOS 版 VLC/Infuse |
| `util/thunder/*`、`com/p2p/P2PClass.java`（迅雷、磁力、荐片） | 依赖 Android 原生库 | 无 |
| `util/XWalkUtils.java`、`XWalkInitDialog.java` | Crosswalk WebView | WKWebView |
| `ui/tv/widget/*`、`ui/adapter/*` | Android TV 焦点控件和列表适配器 | SwiftUI |
| `quickjs` 模块 | Android 版 QuickJS 绑定 | JavaScriptCore / `QuickJSSpider` |
