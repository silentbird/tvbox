# 0002 State Management

## Status

Accepted.

## Decision

使用 Riverpod 作为 Flutter 改写的状态管理方案。

## Rationale

- 不依赖 `BuildContext` 读取业务状态，适合把页面、业务逻辑和平台能力拆开。
- Provider 可以覆盖，方便区分 dev/staging/prod 环境和后续测试。
- 可以从轻量 `Provider` / `StateProvider` 起步，复杂功能再升级为 `Notifier`。

## Current Usage

- `appConfigProvider`: 应用环境配置。
- `appLoggerProvider`: 日志抽象。
- `keyValueStoreProvider`: 本地存储抽象。
- `startupProvider`: 启动初始化状态。
- `mediaItemsProvider`: 首页、分类、搜索共用的媒体数据。
- `favoriteIdsProvider`: 收藏状态。
- `historyIdsProvider`: 播放历史状态。

## Follow-up

- 把收藏和历史从内存状态迁移到 `KeyValueStore`。
- 为真实接口接入 repository/provider。
- 为核心状态流补单元测试。
