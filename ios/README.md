# TVBox iOS/macOS

This directory contains the SwiftUI port of the Android TVBox app.

## Current Direction

- iOS is the primary mobile target.
- Native macOS is the primary Mac target; build and validate the native `My Mac` destination.
- Mac Catalyst remains available as a compatibility target, but is not the Mac development priority.
- Playback should use AVPlayer first. Android-only players such as IJK, Exo, AliyunPlayer, MXPlayer, and Kodi are not direct migration targets.

## Requirements

- Full Xcode installation, not only Command Line Tools.
- Verified locally with Xcode 26.4.1 (17E202).
- iOS deployment target: 17.0.
- Swift version: 5.0, as configured in the Xcode project.
- Metal Toolchain, needed to compile KSPlayer's Metal shaders. Since Xcode 26 it is a separate download:

  ```sh
  xcodebuild -downloadComponent MetalToolchain
  ```

- Vendored dependencies (not committed). Run once before the first build:

  ```sh
  ios/scripts/fetch-nodemobile.sh   # iOS: nodejs-mobile framework
  ios/scripts/fetch-node-macos.sh   # Mac (Catalyst / native): official Node.js (arm64)
  ios/scripts/fetch-ksplayer.sh     # KSPlayer 2.3.4 + FFmpegKit, local Swift packages
  ```

- KSPlayer is pinned to 2.3.4, the last fully open-source release (GPL-3.0). Later releases ship the core as a binary without iOS device support.
- If the FFmpegKit download is slow, download https://github.com/kingslay/FFmpegKit/archive/refs/tags/6.1.4.zip yourself, extract it to `ios/Vendor/FFmpegKit` (so `ios/Vendor/FFmpegKit/Package.swift` exists), then run `fetch-ksplayer.sh` again to apply its fixes.

## Cat Bundles Through Node

Cat config bundles (`index.js.md5` entries) run inside an embedded Node.js, the same way MiraPlay does:

- `CatNodeRuntime` starts Node once with `Resources/catnode-bootstrap.js`, downloads `index.js` + `index.config.js`, and loads them.
- iOS runs Node in-process through nodejs-mobile. Mac (Catalyst and the native macOS build) spawns the official `node` binary embedded at `Contents/MacOS/node` as a child process, which exits when the app quits. Node data lives in `Documents/catnode` on iOS and `~/Library/Application Support/<bundle id>/catnode` on Mac.
- The bundle serves its own HTTP API on `127.0.0.1:9988` (or the next free port). Site list comes from `/config`, sites go through `CatNodeSpider` (`/spider/{key}/{type}/*`), and the config center is the bundle's `/website` page (Settings → 配置中心).
- When Node fails to start or the bundle fails to load, the app falls back to the native `WebsiteBundleNativeSpider` adapters.

## Open The Project

Open:

```sh
ios/tvbox.xcodeproj
```

The target is named `tvbox`.

## First Build

1. Select an iPhone Simulator.
2. Run the `tvbox` scheme.
3. Fix compile errors before adding new feature work.
4. Enter a TVBox config URL on first launch.
5. Verify the minimum flow in `SMOKE_TEST.md`.

Command-line compile checks:

```sh
xcodebuild -project ios/tvbox.xcodeproj -scheme tvbox -configuration Debug -destination generic/platform=iOS -derivedDataPath ios/DerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ios/tvbox.xcodeproj -scheme tvbox -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath ios/DerivedData CODE_SIGNING_ALLOWED=NO build
```

Both commands are expected to finish with `BUILD SUCCEEDED`.

Known warnings after the first successful build:

- `JsSpider` has Swift concurrency `Sendable` warnings around `JavaScriptCore` types.
- Xcode may print `Supported platforms for the buildables in the current scheme is empty`, but generic iOS and Mac Catalyst builds still succeed.

## macOS Through Catalyst

Mac Catalyst is enabled in the Xcode project.

After iPhone Simulator works:

1. Select a Mac Catalyst destination in Xcode.
2. Build and run the same `tvbox` target.
3. Verify AVPlayer playback, WKWebView sniffing, config cache, keyboard navigation, and window resizing.

## Development Notes

- Keep source directories scoped by responsibility:
  - `App/`: app entry and scene setup.
  - `Core/`: config, networking, parser, spider, storage, and other shared runtime services.
  - `Models/`: Codable/domain value types shared by iOS and Mac Catalyst.
  - `Features/`: SwiftUI screens and feature-specific view models.
  - `Common/`: platform-neutral helpers, extensions, logging, toasts, and reusable utilities.
  - `Platform/`: iOS, Mac Catalyst, and future native macOS adaptation helpers.
- Put platform-specific behavior behind small `Platform/` helpers instead of branching throughout feature views.
- Avoid porting Android implementation details mechanically. Prefer native Apple APIs where they map cleanly.
- Keep `ios/TODO.md` updated as work moves between priorities.
