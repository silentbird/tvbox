#!/bin/sh
# 打一个不签名的真机 IPA，放到 ios/build/，在手机上用自签工具签名安装。
# 加 --release 时再用 gh 传到 GitHub Release（预发布），tag 为 ios-<版本>-<时间>，指向 origin 上当前的提交。
set -eu

IOS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$IOS_DIR/build"
ARCHIVE="$BUILD_DIR/tvbox.xcarchive"

rm -rf "$ARCHIVE" "$BUILD_DIR/Payload"
mkdir -p "$BUILD_DIR"

xcodebuild archive \
    -project "$IOS_DIR/tvbox.xcodeproj" \
    -scheme tvbox \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$IOS_DIR/DerivedData" \
    -archivePath "$ARCHIVE" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    -quiet

APP="$ARCHIVE/Products/Applications/tvbox.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist")"
STAMP="$(date +%Y%m%d-%H%M)"
IPA="$BUILD_DIR/tvbox-$VERSION-$STAMP.ipa"

mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP" "$BUILD_DIR/Payload/"
(cd "$BUILD_DIR" && zip -qry "$IPA" Payload)
rm -rf "$BUILD_DIR/Payload"
echo "$IPA"

if [ "${1:-}" = "--release" ]; then
    COMMIT="$(git -C "$IOS_DIR" rev-parse --short HEAD)"
    # tag 建在 GitHub 上的提交，本地还没推送的话和 IPA 对不上
    if [ "$(git -C "$IOS_DIR" rev-parse HEAD)" != "$(git -C "$IOS_DIR" rev-parse '@{u}')" ]; then
        echo "本地提交和 origin 不一致，先推送再发布" >&2
        exit 1
    fi
    gh release create "ios-$VERSION-$STAMP" "$IPA" \
        --prerelease \
        --target "$(git -C "$IOS_DIR" rev-parse HEAD)" \
        --title "iOS $VERSION ($STAMP)" \
        --notes "未签名的测试包，提交 $COMMIT。下载后用自签工具签名安装。"
fi
