# Feature Inventory

用于盘点现有 Android/iOS 功能，迁移前每个功能至少补齐入口、数据来源、平台依赖和验收标准。

| 功能 | Android 入口 | iOS 入口 | 数据来源 | 平台依赖 | MVP | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 启动初始化 | `App.java`, `ApiConfig.java` | `tvboxApp.swift`, `ConfigSetupView.swift`, `ApiConfig.swift` | 配置地址、默认源、本地缓存 | 网络、本地存储 | 是 | Flutter 已有启动占位，待迁移真实配置解析 |
| 首页 | `HomeActivity.java`, `GridFragment.java` | `HomeView.swift`, `HomeContentView.swift`, `HomeViewModel.swift` | `SourceViewModel`, spider/category 数据 | 网络、图片缓存、焦点/遥控器 | 是 | Flutter 已有首页样例列表 |
| 分类/列表 | `GridFragment.java`, adapters | `CategoryDetailView.swift`, `DoubanViews.swift` | 分类、筛选、分页接口 | 网络、焦点/滚动 | 是 | Flutter 已有分类筛选占位 |
| 详情 | `DetailActivity.java` | `DetailView.swift` | 详情接口、播放线路、选集 | 网络、解析器 | 是 | Flutter 已有详情占位 |
| 搜索 | `SearchActivity.java`, `FastSearchActivity.java`, `SearchPresenter.java` | `SearchView.swift` | 搜索接口、搜索历史 | 网络、本地存储、输入法 | 是 | Flutter 已有搜索占位 |
| 播放 | `PlayActivity.java`, `PlayFragment.java`, `EXOmPlayer.java`, `IjkmPlayer.java` | `PlayerView.swift` | 播放地址、解析结果、字幕 | 播放器、字幕、屏幕方向、硬解 | 是 | Flutter 已有播放页占位，真实播放器待定 |
| 直播 | `LivePlayActivity.java`, `LiveController.java`, live adapters | `LiveView.swift`, `LiveParser.swift`, `EpgManager.swift` | M3U/TXT/JSON 直播源、EPG | 播放器、遥控器、频道焦点 | 待定 | 建议 Phase 3 后进入 |
| 收藏 | `CollectActivity.java`, `VodCollectDao.java` | `CollectView.swift` | Room/本地存储 | 本地存储 | 是 | Flutter 已有内存状态占位 |
| 历史 | `HistoryActivity.java`, `VodRecordDao.java`, `HistoryHelper.java` | `HistoryView.swift` | Room/本地存储 | 本地存储 | 是 | Flutter 已有内存状态占位 |
| 设置 | `SettingActivity.java`, `ModelSettingFragment.java`, `SettingsUtil.java` | `SettingsView.swift`, `MineView.swift` | 本地配置、播放设置、接口历史 | 本地存储、权限 | 是 | Flutter 已有设置页占位 |
| 网盘/文件 | `DriveActivity.java`, drive viewmodels | TBD | Alist/WebDAV/本地文件 | 文件权限、网络、WebDAV | 否 | MVP 后迁移 |
| 推送/外部打开 | `PushActivity.java`, `SearchReceiver.java` | TBD | Intent/URL/剪贴板 | 平台分享、URL scheme | 否 | 需单独平台适配 |
