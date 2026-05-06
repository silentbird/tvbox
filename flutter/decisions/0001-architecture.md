# 0001 Architecture

## Status

Accepted as initial scaffold.

## Context

Flutter 改写需要同时覆盖移动端、桌面端、Web 和可能的大屏/遥控器场景。现阶段还没有完成原 Android/iOS 功能盘点，所以架构要先保持轻量，避免过早绑定具体插件或数据源。

## Decision

采用 feature-first 与 shared core 结合的目录结构：

```text
lib/src/
  app/        # 应用壳：路由、主题、根组件
  core/       # 配置、网络、存储、日志、状态等基础能力
  features/   # 按业务功能组织页面和逻辑
  platform/   # 平台能力抽象和桥接
  shared/     # 跨功能复用组件
```

核心原则：

- 页面层只处理 UI 和交互。
- 业务逻辑进入 feature 内部的 state/service/repository。
- 平台能力必须通过 `platform/` 或 `core/` 抽象访问。
- 第三方库选型在独立决策记录中确认。

## Consequences

- 初期代码会多一些接口和占位，但后续替换插件、拆平台能力会更稳。
- 在功能盘点完成前，不强绑定 Riverpod、Bloc、Dio、播放器等具体依赖。
- SDK 安装后可直接补齐 Flutter 平台模板。
