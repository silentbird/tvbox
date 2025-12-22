# TVBox iOS 移植进度

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

### 高优先级

- [ ] **Spider 爬虫替代方案**
  - [ ] 研究 iOS 上执行 JavaScript 的方案 (JavaScriptCore)
  - [ ] 实现 JS 爬虫加载器 (JsLoader)
  - [ ] 支持远程 JS 脚本执行

- [ ] **JSON 类型站点完整支持**
  - [ ] 完善 HomeViewModel 的 API 调用
  - [ ] 实现分类视频列表加载
  - [ ] 实现搜索功能的 API 调用
  - [ ] 实现详情页的 API 调用

- [ ] **直播源解析**
  - [ ] TXT 格式直播源解析
  - [ ] M3U/M3U8 格式直播源解析
  - [ ] TVBOX JSON 直播格式支持
  - [ ] EPG 电子节目单支持

### 中优先级

- [ ] **播放器增强**
  - [ ] 画中画 (PiP) 支持
  - [ ] 后台音频播放
  - [ ] 倍速播放
  - [ ] 画面比例调整
  - [ ] 手势控制 (音量/亮度/进度)
  - [ ] 自动下一集
  - [ ] 续播功能 (记住播放位置)

- [ ] **字幕支持**
  - [ ] SRT 字幕解析
  - [ ] ASS 字幕解析
  - [ ] 在线字幕搜索
  - [ ] 字幕样式设置

- [ ] **解析接口**
  - [ ] VIP 视频解析支持
  - [ ] 嗅探播放地址
  - [ ] 多解析源切换
  - [ ] WebView 嗅探

- [ ] **XML 类型站点支持**
  - [ ] XML 格式解析
  - [ ] 资源站 API 适配

### 低优先级

- [ ] **投屏功能**
  - [ ] AirPlay 支持
  - [ ] DLNA 投屏

- [ ] **二维码扫描**
  - [ ] 扫码输入配置地址

- [ ] **远程推送**
  - [ ] 本地 HTTP 服务器
  - [ ] 接收推送播放

- [ ] **数据同步**
  - [ ] iCloud 同步收藏/历史
  - [ ] WebDAV 备份

- [ ] **UI/UX 优化**
  - [ ] 深色模式适配
  - [ ] iPad 适配
  - [ ] tvOS 适配
  - [ ] 自定义主题色
  - [ ] 骨架屏加载

- [ ] **性能优化**
  - [ ] 图片缓存 (SDWebImage/Kingfisher)
  - [ ] 列表预加载
  - [ ] 内存优化

---

## 📝 开发笔记

### 与 Android 版差异

1. **JAR 爬虫不支持**: iOS 无法运行 Java 代码，需要使用 JavaScriptCore 执行 JS 爬虫
2. **Python 爬虫不支持**: 需要寻找替代方案或使用服务端代理
3. **播放器**: 使用 AVPlayer 替代 IJK/EXO 播放器
4. **本地存储**: 使用 UserDefaults 替代 Room 数据库

### 参考资源

- Android 源码: `android/app/src/main/java/com/github/tvbox/osc/`
- 配置格式: 参见 `android/README.md`

---

## 📅 更新日志

### 2025-12-22
- 完成基础架构搭建
- 完成所有主要页面 UI
- 完成本地存储功能
- 完成基础播放器功能

