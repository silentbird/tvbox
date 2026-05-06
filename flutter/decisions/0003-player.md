# 0003 Player

## Status

Deferred.

## Decision

播放器暂不直接绑定具体插件，先保留 `PlayerScreen` 和播放历史闭环。

## Candidate Direction

- 移动端和桌面端优先评估 `media_kit`。
- 如果 Android TV 体验优先，需要单独验证遥控器焦点、硬解、字幕和直播协议。
- Web 端需要独立评估浏览器解码、CORS 和 MSE/HLS 能力。

## Minimum Capabilities

- 播放 HLS 或常见远程视频源。
- 保存和恢复播放进度。
- 支持暂停、快进、倍速和线路切换。
- 支持字幕能力评估。
- 支持键盘或遥控器方向键操作。

## Follow-up

- 建立播放源样例集合。
- 在 Android、iOS、Windows、Web 至少各跑一次插件验证。
- 确认插件后再把 `PlayerScreen` 中的占位 UI 替换为真实播放器。
