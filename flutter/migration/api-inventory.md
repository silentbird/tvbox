# API Inventory

用于记录接口、配置源、数据模型和错误码。

| 模块 | 接口/配置 | 方法 | 请求参数 | 响应模型 | 错误处理 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 启动配置 | `ApiConfig` / 配置地址 | GET/本地 | 配置 URL、历史配置 | `SourceBean`, parser/live/site 配置 | 配置为空、格式错误、网络失败 | Android/iOS 都有配置管理，需要统一模型 |
| 首页列表 | spider home/category | GET/自定义 spider | source key、分类、页码 | `Movie`, `MovieSort` | source 不可用、解析失败 | 先从 Android `SourceViewModel` 和 iOS `HomeViewModel` 反查 |
| 分类列表 | category/filter/page | GET/自定义 spider | type id、filter、page | movie list、分页信息 | 空列表、分页到底、解析失败 | Flutter 已有 UI 占位 |
| 详情 | detail | GET/自定义 spider | vod id/source key | detail、play flags、episodes | 详情缺失、线路为空 | 关系到播放页选集 |
| 搜索 | search/quick search | GET/自定义 spider | keyword、quick flag、page | search result list | 搜索源失败、结果为空 | 需保留搜索历史 |
| 播放地址 | player/parse | GET/POST/解析器 | play flag、url、parse api | final url、headers、subtitles | 解析失败、嗅探失败、跨域限制 | 播放器选型前重点验证 |
| 直播源 | live parser | GET/本地 | M3U/TXT/JSON URL | group/channel/epg | 格式错误、频道失效 | Phase 3 后迁移 |
| 本地收藏/历史 | Room/StorageManager | local | vod id、source key、progress | favorite/history records | 迁移冲突、旧数据缺字段 | 需要设计旧数据迁移 |
