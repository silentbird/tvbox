# TVBox Flutter App

这是 Flutter 跨平台改写的应用骨架。

当前机器还没有可用的 `flutter` 命令，所以这里先提交源码目录、配置和架构占位。安装 Flutter SDK 后，在本目录执行：

```powershell
flutter pub get
flutter run -t lib/main_dev.dart
```

如果需要补齐 Android、iOS、Web、桌面平台模板，在本目录执行：

```powershell
flutter create --project-name tvbox_flutter --platforms=android,ios,web,windows,macos,linux .
```

执行后需要检查 `lib/` 和 `pubspec.yaml` 是否被模板覆盖。

## 入口

- `lib/main_dev.dart`: 开发环境
- `lib/main_staging.dart`: 预发环境
- `lib/main_prod.dart`: 生产环境
- `lib/main.dart`: 默认开发环境入口

## 目录

```text
lib/
  main.dart
  main_dev.dart
  main_staging.dart
  main_prod.dart
  src/
    app/
    core/
    features/
    platform/
    shared/
```
