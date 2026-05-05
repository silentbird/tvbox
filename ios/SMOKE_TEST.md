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
- [ ] Config input accepts a JS checksum source such as `https://9280.kstore.vip/cat/index.js.md5`, loads the sibling `.js` script, identifies it as a Cat WebsiteBundle source, and shows the iOS runtime unsupported state clearly.
- [ ] Invalid config URL shows a readable error.
- [ ] Valid config loads and is cached.
- [ ] Relaunch uses cached config or reloads gracefully.

## Home

- [ ] Home tab loads.
- [ ] Site selector shows configured sites.
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
- [ ] Play, pause, seek forward, and seek backward work.
- [ ] Leaving the player stops playback cleanly.
- [ ] Playback error shows a useful message.

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
| 2026-05-05 | iOS/Catalyst build | `https://9280.kstore.vip/cat/index.js.md5` | Pending runtime smoke | `.js.md5` returns a checksum; app should normalize to sibling `.js`, identify `globalThis.websiteBundle`, and avoid treating it as a traditional Spider. |
|      |          |               |        |       |
