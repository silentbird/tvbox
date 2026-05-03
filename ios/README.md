# TVBox iOS/macOS

This directory contains the SwiftUI port of the Android TVBox app.

## Current Direction

- iOS is the primary target.
- macOS should be validated first through Mac Catalyst.
- Native macOS/AppKit should wait until the iOS core flow is stable.
- Playback should use AVPlayer first. Android-only players such as IJK, Exo, AliyunPlayer, MXPlayer, and Kodi are not direct migration targets.

## Requirements

- Full Xcode installation, not only Command Line Tools.
- Verified locally with Xcode 26.4.1 (17E202).
- iOS deployment target: 17.0.
- Swift version: 5.0, as configured in the Xcode project.

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

- Keep shared logic in `Core/`, `Models/`, and `Features/`.
- Put platform-specific behavior behind small platform helpers instead of branching throughout feature views.
- Avoid porting Android implementation details mechanically. Prefer native Apple APIs where they map cleanly.
- Keep `ios/TODO.md` updated as work moves between priorities.
