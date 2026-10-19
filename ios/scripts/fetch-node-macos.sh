#!/bin/sh
# 下载官方 Node.js macOS (arm64) 可执行文件到 ios/Vendor/node-macos/node。
# Mac Catalyst 版本把它打包进 App，以子进程运行 Cat 配置包（iOS 用 NodeMobile）。
# 约 100MB，不入库；首次构建 Mac Catalyst 前执行一次即可。
set -eu

VERSION="${NODE_MACOS_VERSION:-v22.23.3}"
IOS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="$IOS_DIR/Vendor/node-macos"
TARGET="$TARGET_DIR/node"
ARCHIVE="node-$VERSION-darwin-arm64.tar.gz"

if [ -f "$TARGET" ]; then
    echo "node already exists: $TARGET"
    exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

curl -fL -o "$TMP_DIR/$ARCHIVE" "https://nodejs.org/dist/$VERSION/$ARCHIVE"
curl -fL -o "$TMP_DIR/SHASUMS256.txt" "https://nodejs.org/dist/$VERSION/SHASUMS256.txt"
(cd "$TMP_DIR" && grep " $ARCHIVE\$" SHASUMS256.txt | shasum -a 256 -c -)

tar -xzf "$TMP_DIR/$ARCHIVE" -C "$TMP_DIR"
mkdir -p "$TARGET_DIR"
mv "$TMP_DIR/node-$VERSION-darwin-arm64/bin/node" "$TARGET"
echo "Installed node ($VERSION) to $TARGET"
