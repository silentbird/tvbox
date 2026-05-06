# TVBox iOS/macOS Smoke Test

Use this checklist before larger feature work and before sharing a build.

## Environment

- [x] Full Xcode is selected.
- [ ] `ios/tvbox.xcodeproj` opens without project migration prompts.
- [x] The `tvbox` scheme is available.
- [x] Generic iOS build succeeds.
- [x] Mac Catalyst build succeeds.
- [ ] iPhone Simulator build and launch succeeds.

## First Launch

- [ ] App launches without crashing.
- [ ] Empty state asks for a config source.
- [ ] Config input accepts a JS checksum source such as `https://9280.kstore.vip/cat/index.js.md5`, loads the sibling `.js` script, identifies it as a Cat WebsiteBundle source, and selects the adapted `nodejs_wexDuBoKu` child site.
- [ ] Invalid config URL shows a readable error.
- [ ] Valid config loads and is cached.
- [ ] Relaunch uses cached config or reloads gracefully.

## Home

- [ ] Home tab loads.
- [ ] Site selector shows configured sites.
- [ ] Cat WebsiteBundle config shows `🌺独播|秒播🌺` instead of the legacy `Cat WebsiteBundle` placeholder when `wexDuBoKu` is available.
- [ ] Switching sites refreshes categories and recommendations.
- [ ] Poster images load, including sources that require User-Agent or Referer.
- [ ] Pull to refresh does not duplicate stale content.

## Search

- [ ] Search works on the current site.
- [ ] Empty search is ignored or explained.
- [ ] Failed source search does not break the whole page.
- [ ] Result item opens detail.

## Detail

- [ ] Detail page loads title, poster, metadata, play sources, and episodes.
- [ ] Source switching changes episode list.
- [ ] Collection toggle persists.
- [ ] History is written after playback starts.

## Playback

- [ ] Normal direct URL plays.
- [ ] Parsed/VIP URL resolves before playback.
- [ ] `wexDuBoKu` episode playback returns a direct URL from `HId` and injects the required User-Agent/Referer headers.
- [ ] Play, pause, seek forward, and seek backward work.
- [ ] Leaving the player stops playback cleanly.
- [ ] Playback error shows a useful message.

## Cat WebsiteBundle - 其它已适配子站点

运行时逐个切换到每个已适配子站点并验证核心链路（首页分类 → 搜索 → 详情 → 播放）。
下列任一出错都不应再抛 `WebsiteBundle 未暴露 home/category/detail/search/play`。

- [ ] `wexYueYue` (悦悦秒播)：分类/详情/搜索通过 AES-CBC 解密；播放返回 `wsSecret/wsTime` 签名后的直链。
- [ ] `animemodu` (魔都动漫)：MacCMS 接口直连，`vod_play_url` 直接透传。
- [ ] `dongli` (星芽短剧)：初始化登录 `u.shytkjgs.com` 拿 Bearer token，`son_video_url` 直接播放。
- [ ] `duanjuweiguan` (小薇短剧)：`clientInfo` 参数生成，多清晰度数组经 base64 编码。
- [ ] `hanxiaoquan` (韩剧秒播)：AES-CBC + 动态 MD5 密钥 + 播放签名链，返回 m3u8 带 `HanjuTV/6.8` UA。
- [ ] `bookWuWei` (无忧听书)：HTML 抓取 + `FRDSHFSKVKSKFKS` MD5 签名，听书音频直链播放。
- [ ] `bili` (哔哩集合)：`www.bilibili.com` 引导 cookie，`mp4` flag 返回 `durl` 直链。

## Cat WebsiteBundle - `wexDuBoKu`

Use `https://9280.kstore.vip/cat/index.js.md5` as the config source.

- [ ] Config parsing creates `nodejs_wexDuBoKu` and does not keep `ios_website_bundle_source` as the selected site when the adapted child site exists.
- [ ] Site selector shows the expanded WebsiteBundle child list from mixed literal/obfuscated `meta` entries, not only the 9 literal entries.
- [ ] Home categories include `电影`, `电视剧`, `综艺`, `动漫`, `短剧`, `港剧`, `陆剧`, `日韩剧`, `台泰剧`.
- [ ] Category smoke URL shape works: `https://api.dbokutv.com/vodshow/1--------1---?...`
- [ ] Search for `庆余年` returns `庆余年 第二季` and `庆余年`.
- [ ] Detail for `/voddetail/4570` shows metadata and 36 episodes.
- [ ] Play for `/vodplay/4570-1-1` returns an `HId` direct playback URL.
- [ ] Refresh config, switch away/back, and relaunch do not show `WebsiteBundle 未暴露 home/category/detail/search/play` again.

## Live

- [ ] Live tab loads configured live sources.
- [ ] Channel groups render.
- [ ] At least one channel plays.
- [ ] EPG data loads when available.
- [ ] Failed channels do not crash the app.

## macOS Catalyst

- [ ] App launches as a Catalyst app.
- [ ] Window resizing keeps layouts usable.
- [ ] Keyboard navigation works for primary lists.
- [ ] Player can enter and exit full screen.
- [ ] WKWebView-based sniffing still works.
- [ ] Config and image cache paths work on macOS.

## Regression Notes

Record the config sources used for each smoke test run:

| Date | Platform | Config Source | Result | Notes |
|------|----------|---------------|--------|-------|
| 2026-05-05 | iOS/Catalyst build | `https://9280.kstore.vip/cat/index.js.md5` | Build + API smoke passed | `.js.md5` normalizes to sibling `.js`; `wexDuBoKu` category/search/detail/play endpoints were verified with live API responses. Runtime UI smoke still needs Simulator/device confirmation. |
|      |          |               |        |       |
