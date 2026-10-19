# 配置中心与网盘 Token 搬运记录

> 更新日期: 2026-06-16

## 结论

iOS 目前已经能打开 MiraPlay 风格的配置中心，并保存网盘 Cookie、Token、账号、网盘列表和 Emby 配置。保存位置是本地 Keychain，失败时回退到 UserDefaults。

配置中心本身已完成“可配置”。观看网盘视频要在具体 WebsiteBundle 原生 spider 的 `playerContent` 阶段读取这些配置，换取真实播放地址和 headers，再返回给播放器。目前 `bili` 和 `wodequark` 已开始走这条链路。

## Android 参考

Android 里有两条不同链路，不能混在一起搬。

### 独立网盘页

`DriveActivity` 使用 `StorageDrive` 保存 Local、WebDAV、Alist 的连接配置。点选文件后：

- Local 直接拼本地路径。
- WebDAV 拼服务器 URL 和路径，播放时可带 Basic Authorization。
- Alist 通过接口或 `/d/...` 路径拿文件 URL。

这条链路对应 Android 的“存储/网盘浏览器”，不是 MiraPlay 配置中心。

### 影视播放链路

普通影视播放走 spider：

1. `JsSpider.playerContent` 调用站点脚本的 `play(flag, id, vipFlags)`。
2. 站点脚本解析资源，返回播放 JSON。
3. `PlayActivity` 从 JSON 里取 `url` 和 `header`。
4. 播放器用返回的直链和 headers 播放。

MiraPlay 配置中心的网盘 token 应该应用在第 2 步：网盘 provider 读取配置中心保存的 Cookie/Token/账号，解析分享链接，返回真实播放 URL 和 headers。

## iOS 当前实现

已完成：

- 识别配置中心 HTML，并改读 `/full-config`。
- 展示配置中心入口 `baseset`。
- 本地实现配置中心页面。
- 保存以下 endpoint 的值：
  - `/baidu/cookie`
  - `/quark/cookie`
  - `/uc/cookie`
  - `/uc-tv/token`
  - `/115/cookie`
  - `/bili/cookie`
  - `/pan123ziyuan/cookie`
  - `/wuming/cookie`
  - `/tianyi/account`
  - `/pan123/account`
  - `/ali/token`
  - `/pans/list`
  - `/emby/config`
- 新增 `ConfigCenterRuntime`，让播放和 spider 侧能读取同一套配置。
- 当入口是真实配置中心服务地址（`/website` 或 `/full-config`）时，登录页优先复用 MiraPlay 后端直接扫码接口：先 `GET /website/<provider>/qrcode` 拿 300x300 PNG 二维码，二维码加载成功后再自动轮询 `POST /website/<provider>/<cookie|token>`，也可手动点击“扫码后获取并保存”，成功后直接写入本地 Keychain。
- 直接扫码接口目前按 MiraPlay 前端映射：百度 `/website/baidu/qrcode` + `/website/baidu/cookie`，夸克 `/website/quark/qrcode` + `/website/quark/cookie`，UC Cookie `/website/uc/qrcode` + `/website/uc/cookie`，UC token `/website/uc-tv/qrcode` + `/website/uc-tv/token`，115 `/website/115/qrcode` + `/website/115/cookie`，Bili `/website/bili/qrcode` + `/website/bili/cookie`。
- 当入口只是普通 WebsiteBundle 源地址时，iOS 使用本地原生配置页，不请求不存在的 `/website/*` 后端接口；百度、夸克、UC Cookie、115、Bili 暂以官方网页登录扫码兜底，并从 `WKWebsiteDataStore` 自动提取 Cookie 保存到 Keychain。
- `BiliNativeSpider` 已优先读取 `/bili/cookie`，这是第一处配置中心值进入播放解析链路。
- 新增 `QuarkNetDiskProvider`，读取 `/quark/cookie` 后调用夸克网盘目录和下载接口。
- 新增 `WodeQuarkNativeSpider`，`wodequark` 个人网盘站点可以列出根目录文件，文件夹详情会聚合可播放视频，播放时通过 provider 换取直链。

未完成：

- 夸克分享链接解析、转存/保存后取直链等资源搜索链路还没有搬完。
- 百度、UC、115、阿里、天翼、123 等网盘 provider 的原生解析逻辑还没有搬到 iOS。
- UC TV token、阿里 refresh token/open token 等需要 provider 专属扫码 API 的登录流程还没有搬到 iOS，当前网页登录扫码只负责 Cookie 型凭据。
- `wodebaidu`、`wode189`、`wode115`、`wode123` 等个人网盘站点还没有原生 adapter。
- 网盘资源搜索站点返回分享链接后的统一解析器还没有实现。

## 搬运顺序

1. 先补运行时读取层。
   - 已完成 `ConfigCenterRuntime`。
   - provider 不直接碰 UI store，只通过运行时 API 读取配置。

2. 先搬最容易闭环的 provider。
   - 优先级建议：Quark、UC、115、Ali、Baidu、Tianyi、123。
   - Quark 个人网盘目录/播放直链已接入初版。
   - 每搬一个 provider，都要能做到：读取配置、解析分享、返回 `PlayerContent(url/header)`。

3. 再适配个人网盘站点。
   - `wodequark` 已接入初版。
   - `wodebaidu`
   - `wode189`
   - `wode115`
   - `wode123`

4. 最后做资源搜索站点的统一分流。
   - 识别播放 id 里的分享链接类型。
   - 按启用的 `/pans/list` 顺序选择 provider。
   - provider 失败时切换下一个可用网盘。

## 验证要求

每次改完代码都要跑：

```sh
xcodebuild -project ios/tvbox.xcodeproj -scheme tvbox -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath ios/DerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ios/tvbox.xcodeproj -scheme tvbox -configuration Debug -destination generic/platform=iOS -derivedDataPath ios/DerivedData CODE_SIGNING_ALLOWED=NO build
```

如果 iOS generic build 在 sandbox 下遇到 Swift preview plugin 问题，需要用非 sandbox 环境重跑确认。
