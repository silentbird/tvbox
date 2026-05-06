# Flutter Cross-Platform Rewrite

这个目录用于沉淀 TVBox Flutter 跨平台改写的规划、任务拆分、技术决策和迁移记录。

当前已开始 Flutter 工程骨架，源码位于 `app/`。应用已包含 Android/iOS/Web/桌面平台模板和基础功能占位。

## 目标

- 使用 Flutter 改写现有 Android/iOS 客户端的主要功能。
- 尽量复用现有业务规则、接口协议、数据结构和资源命名。
- 建立 Android、iOS、Windows、macOS、Linux、Web 的可扩展跨平台基础。
- 把平台相关能力隔离到清晰的 adapter/plugin 层，避免业务代码被平台分支污染。

## 建议目录结构

```text
flutter/
  README.md
  TODO.md
  decisions/
    0001-architecture.md
  migration/
    feature-inventory.md
    api-inventory.md
    platform-capabilities.md
  app/
    pubspec.yaml
    analysis_options.yaml
    lib/
```

## 本地启动

先确认 Flutter SDK 已安装并加入 PATH：

```powershell
flutter --version
```

进入应用目录并启动开发环境：

```powershell
cd flutter/app
flutter pub get
flutter run -t lib/main_dev.dart
```

补齐平台模板：

```powershell
cd flutter/app
flutter create --project-name tvbox_flutter --platforms=android,ios,web,windows,macos,linux .
```

## 推荐技术路线

- Flutter stable channel，优先使用官方跨平台能力。
- 状态管理建议从 `Riverpod` 或 `Bloc` 二选一，按团队熟悉度决定。
- 状态管理当前采用 `Riverpod`。
- 路由当前采用 `go_router`，便于深链、桌面窗口和 Web URL 对齐。
- 网络层当前采用 `dio` 抽象，统一拦截器、超时、重试和日志。
- 本地存储分层处理：
  - 简单配置：`shared_preferences`
  - 结构化缓存：`drift` 或 `isar`
  - 敏感信息：`flutter_secure_storage`
- 媒体播放、文件访问、投屏、后台任务等能力先做平台能力调研，再确定插件或自研桥接。

## 迁移原则

- 先盘点再改写：每个功能都要有现有入口、数据来源、平台依赖和验收标准。
- 先核心链路再边缘能力：优先跑通启动、配置、列表、详情、播放等主流程。
- UI 与业务分离：页面只负责渲染和交互，业务状态沉到 provider/bloc/service。
- 平台能力可替换：所有 native channel/plugin 调用都通过接口封装。
- 每个阶段都有可运行版本，避免长期处于“大重写但跑不起来”的状态。

## 阶段规划

### Phase 0: 现状盘点

- 盘点 Android/iOS 当前功能列表。
- 梳理接口、配置源、缓存、播放、搜索、收藏、历史、设置等模块。
- 标记平台相关能力：权限、文件、网络、播放器、投屏、后台、通知、横竖屏。
- 输出功能优先级和不可缺失能力。

### Phase 1: Flutter 工程骨架

- 初始化 Flutter app。
- 配置 lint、format、环境变量和基础 CI。
- 建立 app/router/theme/network/storage/logging 基础模块。
- 建立 dev/staging/prod 配置切换。

### Phase 2: 核心业务闭环

- 已实现启动加载和基础配置解析占位。
- 已实现首页/分类/列表/详情占位。
- 已实现搜索、收藏、历史记录占位。
- 已实现基础播放页占位；真实播放器仍待插件验证。

### Phase 3: 平台能力补齐

- Android/iOS 权限和文件访问。
- 桌面端窗口、键盘、遥控器/方向键适配。
- Web 端路由、跨域、播放限制评估。
- 播放器能力增强：倍速、字幕、选集、清晰度、播放进度。

### Phase 4: 质量与发布

- 单元测试覆盖核心解析、网络、缓存、状态逻辑。
- Widget 测试覆盖关键页面状态。
- 真机/模拟器/桌面/Web 多端验收。
- 打包签名、版本号、渠道配置和发布文档。

## 已建文档

- `migration/feature-inventory.md`: 现有功能盘点。
- `migration/api-inventory.md`: 接口和数据模型盘点。
- `migration/platform-capabilities.md`: 平台能力和插件选型。
- `decisions/0001-architecture.md`: 架构决策记录。
- `decisions/0002-state-management.md`: 状态管理决策记录。
- `decisions/0003-player.md`: 播放器决策记录。
- `decisions/0004-storage.md`: 本地存储决策记录。
