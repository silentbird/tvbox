# 0004 Storage

## Status

Accepted as initial scaffold.

## Decision

先以 `KeyValueStore` 抽象统一本地存储，默认实现使用 `SharedPreferencesKeyValueStore`。

## Rationale

- 当前阶段需要先保存简单配置、收藏、历史和调试状态。
- `KeyValueStore` 可以先支撑字符串读写，后续再扩展 JSON、批量操作和迁移版本。
- 对业务层隐藏具体插件，后续可以替换为 SQLite、Drift、Isar 或安全存储。

## Follow-up

- 为收藏和历史增加序列化。
- 为配置源增加缓存和刷新时间。
- 如果需要兼容旧客户端数据，新增迁移器和回滚策略。
