# Platform Capabilities

用于评估各平台能力差异、插件选择和降级策略。

| 能力 | Android | iOS | Web | Windows | macOS | Linux | 插件/方案 | 风险 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 视频播放 | Exo/IJK/第三方播放器 | SwiftUI PlayerView | 浏览器限制明显 | 待验证 | 待验证 | 待验证 | 候选 `media_kit` | 高 |
| HLS/直播 | 已有 LivePlay/LiveController | LiveView + parsers | 受 CORS/MSE 影响 | 待验证 | 待验证 | 待验证 | 播放器插件 + 直播 parser | 高 |
| 字幕 | `SubtitleViewModel`, subtitle dialog | Parser/Player 后续确认 | 浏览器能力差异 | 待验证 | 待验证 | 待验证 | 播放器插件能力优先 | 中 |
| 文件访问 | Drive/LocalDrive/WebDAV | 待盘点 | 受浏览器沙箱限制 | 文件选择器 | 文件选择器 | 文件选择器 | `file_picker` / 平台桥接 | 中 |
| 本地存储 | Room DAOs | `StorageManager` | IndexedDB/localStorage 抽象 | SharedPreferences 后端 | SharedPreferences 后端 | SharedPreferences 后端 | 当前 `KeyValueStore` + shared_preferences | 中 |
| 安全存储 | 待盘点 | Keychain 可用 | 受浏览器限制 | 待验证 | Keychain 可用 | Secret Service 待验证 | 后续评估 `flutter_secure_storage` | 中 |
| 遥控器/键盘 | TV 焦点重要 | 键盘/遥控待验证 | 键盘事件 | 键盘事件 | 键盘事件 | 键盘事件 | Flutter Focus/Shortcuts | 高 |
| 剪贴板 | Android clipboard | iOS pasteboard | Browser clipboard API | 可用 | 可用 | 可用 | Flutter Clipboard | 低 |
| 后台任务 | Android 后台限制 | iOS 后台限制 | 基本不可用 | 待验证 | 待验证 | 待验证 | 先不进入 MVP | 高 |
