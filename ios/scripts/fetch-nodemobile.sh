#!/bin/sh
# 下载 nodejs-mobile 预编译 iOS 框架到 ios/Vendor/NodeMobile.xcframework。
# 框架约 160MB，不入库；首次构建前执行一次即可。
set -eu

VERSION="${NODEJS_MOBILE_VERSION:-v18.20.4}"
IOS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$IOS_DIR/Vendor"
TARGET="$VENDOR_DIR/NodeMobile.xcframework"

if [ -d "$TARGET" ]; then
    echo "NodeMobile.xcframework already exists: $TARGET"
    exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

curl -fL -o "$TMP_DIR/nodejs-mobile.zip" \
    "https://github.com/nodejs-mobile/nodejs-mobile/releases/download/$VERSION/nodejs-mobile-$VERSION-ios.zip"
unzip -q "$TMP_DIR/nodejs-mobile.zip" -d "$TMP_DIR"

mkdir -p "$VENDOR_DIR"
mv "$TMP_DIR/NodeMobile.xcframework" "$TARGET"
echo "Installed NodeMobile.xcframework ($VERSION) to $TARGET"
