#!/bin/sh
# 打一个不签名的真机 IPA，放到 ios/build/，在手机上用自签工具签名安装。
# 版本号是工程里的 MARKETING_VERSION（三位），每打一次包最后一位加 1，打包成功后单独提交这次改动。
# 加 --release 时再推送版本号的提交，用 gh 传到 GitHub Release（预发布），tag 为 ios-<版本>。
set -eu

IOS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$IOS_DIR/build"
ARCHIVE="$BUILD_DIR/tvbox.xcarchive"
PBXPROJ="$IOS_DIR/tvbox.xcodeproj/project.pbxproj"
RELEASE="${1:-}"

# 版本号要单独提交，工程文件里有别的改动会混进去
if ! git -C "$IOS_DIR" diff --quiet HEAD -- "$PBXPROJ"; then
    echo "project.pbxproj 有没提交的改动，先提交再打包" >&2
    exit 1
fi

# tag 建在 GitHub 上的提交，本地还有没推送的提交时和 IPA 对不上
if [ "$RELEASE" = "--release" ] && [ "$(git -C "$IOS_DIR" rev-parse HEAD)" != "$(git -C "$IOS_DIR" rev-parse '@{u}')" ]; then
    echo "本地提交和 origin 不一致，先推送再发布" >&2
    exit 1
fi

CURRENT="$(sed -n 's/.*MARKETING_VERSION = \(.*\);/\1/p' "$PBXPROJ" | head -n 1)"
VERSION="$(echo "$CURRENT" | awk -F. '{ printf "%d.%d.%d", $1, $2, $3 + 1 }')"
sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $VERSION;/" "$PBXPROJ"
# 打包失败时还原版本号
trap 'git -C "$IOS_DIR" checkout -- "$PBXPROJ"' EXIT

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
IPA="$BUILD_DIR/tvbox-$VERSION.ipa"

rm -f "$IPA"
mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP" "$BUILD_DIR/Payload/"
(cd "$BUILD_DIR" && zip -qry "$IPA" Payload)
rm -rf "$BUILD_DIR/Payload"

git -C "$IOS_DIR" commit -q -m "chore:[iOS] 版本号升到 $VERSION" -- "$PBXPROJ"
trap - EXIT
echo "$IPA"

if [ "$RELEASE" = "--release" ]; then
    git -C "$IOS_DIR" push -q
    COMMIT="$(git -C "$IOS_DIR" rev-parse --short HEAD)"
    gh release create "ios-$VERSION" "$IPA" \
        --prerelease \
        --target "$(git -C "$IOS_DIR" rev-parse HEAD)" \
        --title "iOS $VERSION" \
        --notes "未签名的测试包，提交 ${COMMIT}。下载后用自签工具签名安装。"
fi
