#!/bin/sh
# 下载 KSPlayer 及其依赖 FFmpegKit 到 ios/Vendor，项目以本地 Swift 包引用。
# KSPlayer 之后的版本核心改为闭源二进制，开源版不支持 iOS 真机，所以固定在 2.3.4 (GPL-3.0)。
# 用版本源码快照而不是 SPM 远程依赖：两个仓库的 git 历史有好几 GB，克隆非常慢。
# KSPlayer 会优先使用同级目录的 ../FFmpegKit。首次构建前执行一次即可。
set -eu

KSPLAYER_VERSION="${KSPLAYER_VERSION:-2.3.4}"
FFMPEGKIT_VERSION="${FFMPEGKIT_VERSION:-6.1.4}"
IOS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$IOS_DIR/Vendor"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fetch() {
    name="$1"
    version="$2"
    target="$VENDOR_DIR/$name"

    if [ -f "$target/Package.swift" ]; then
        echo "$name already exists: $target"
        return
    fi

    curl -fL -o "$TMP_DIR/$name.tar.gz" "https://codeload.github.com/kingslay/$name/tar.gz/refs/tags/$version"
    mkdir -p "$TMP_DIR/$name"
    tar -xzf "$TMP_DIR/$name.tar.gz" -C "$TMP_DIR/$name" --strip-components 1

    rm -rf "$target"
    mkdir -p "$VENDOR_DIR"
    mv "$TMP_DIR/$name" "$target"
    echo "Installed $name ($version) to $target"
}

# FFmpegKit 的 macOS / Mac Catalyst 框架是 iOS 式的浅层结构，Xcode 把它们拷进 App 时会报
# "expected Versions/Current/Resources/Info.plist"，改成 macOS 要求的 Versions/A 结构。
deepen_mac_frameworks() {
    for framework in "$VENDOR_DIR"/FFmpegKit/Sources/*.xcframework/macos-*/*.framework \
                     "$VENDOR_DIR"/FFmpegKit/Sources/*.xcframework/*-maccatalyst/*.framework; do
        [ -f "$framework/Info.plist" ] || continue
        name="$(basename "$framework" .framework)"
        version_dir="$framework/Versions/A"

        mkdir -p "$version_dir/Resources"
        mv "$framework/Info.plist" "$version_dir/Resources/Info.plist"
        for item in "$name" Headers Modules; do
            if [ -e "$framework/$item" ]; then
                mv "$framework/$item" "$version_dir/$item"
            fi
        done

        ln -s A "$framework/Versions/Current"
        for item in "$name" Headers Modules Resources; do
            if [ -e "$version_dir/$item" ]; then
                ln -s "Versions/Current/$item" "$framework/$item"
            fi
        done
    done
}

# 新 SDK 里 Mac Catalyst 也能 import AppKit，KSPlayer 唯一一处用 canImport(AppKit) 判断 macOS 的代码在 Catalyst 下编译失败
patch_ksplayer() {
    sed -i '' 's/^    #if canImport(AppKit)$/    #if canImport(AppKit) \&\& !targetEnvironment(macCatalyst)/' \
        "$VENDOR_DIR/KSPlayer/Sources/KSPlayer/Video/SeekView.swift"

    # FFmpegKit 要求 Mac Catalyst 14.0，KSPlayer 原清单仍声明 13.1。
    sed -i '' 's/\.macCatalyst(\.v13)/.macCatalyst(.v14)/' "$VENDOR_DIR/KSPlayer/Package.swift"

    # 原清单用 FileManager 判断 ../FFmpegKit 是否存在，Xcode 解析清单时有沙盒，判断失败就去 GitHub 克隆 FFmpegKit。
    # 把这段判断换成固定的本地依赖。
    manifest="$VENDOR_DIR/KSPlayer/Package.swift"
    if grep -q '^var ffmpegKitPath' "$manifest"; then
        sed -i '' '/^var ffmpegKitPath/,$d' "$manifest"
        printf 'package.dependencies += [\n    .package(path: "../FFmpegKit"),\n]\n' >> "$manifest"
    fi
}

fetch KSPlayer "$KSPLAYER_VERSION"
fetch FFmpegKit "$FFMPEGKIT_VERSION"
deepen_mac_frameworks
patch_ksplayer
