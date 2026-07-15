#!/bin/bash
# 构建两段式完整版本的三端安装包，并分别导出内容更新基线 PCK。
# 用法：bash tools/build_packages.sh [版本，默认取 update_release.env]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tools/update_release.env"
source "$ROOT/tools/lib_update_release.sh"

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
VERSION="${1:-$UPDATE_BASE_VERSION}"
BUILD="$ROOT/build"
UPDATE_OUT="$BUILD/updates"

update_require_full_version "$VERSION"
[ "$VERSION" = "$UPDATE_BASE_VERSION" ] || update_die "构建版本 $VERSION 与当前更新基线 $UPDATE_BASE_VERSION 不一致"
update_require_executable "$GODOT"
update_verify_git_release_point "$VERSION"

# 在耗时导出前确认三个 preset 的版本元数据已经同步。
python3 - "$ROOT/export_presets.cfg" "$VERSION" "$UPDATE_ANDROID_VERSION_CODE" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
version, code = sys.argv[2:]
required = {
    f'application/file_version="{version}.0.0"': "Windows file_version",
    f'application/product_version="{version}.0.0"': "Windows product_version",
    f'application/short_version="{version}"': "macOS short_version",
    f'application/version="{version}"': "macOS bundle version",
    f'version/code={code}': "Android versionCode",
    f'version/name="{version}"': "Android versionName",
}
missing = [label for needle, label in required.items() if needle not in text]
if missing:
    raise SystemExit("export_presets.cfg 版本未同步：" + "、".join(missing))
PY

mkdir -p "$BUILD" "$UPDATE_OUT/android" "$UPDATE_OUT/windows" "$UPDATE_OUT/macos"
cd "$ROOT"

echo "== Windows x86_64 完整包 =="
"$GODOT" --headless --path . --export-release "Windows Desktop" "$BUILD/LiangshanHeroes.exe" \
	> /tmp/liangshan_win_export.log 2>&1
cp "$BUILD/LiangshanHeroes.exe" "$BUILD/LiangshanHeroes-v$VERSION.exe"

echo "== Windows $VERSION 更新基线 =="
"$GODOT" --headless --path . --export-pack "Windows Desktop" \
	"$UPDATE_OUT/windows/base-$VERSION.pck" > /tmp/liangshan_win_base.log 2>&1

echo "== Android arm64 完整包 =="
"$GODOT" --headless --path . --export-debug "Android" "$BUILD/LiangshanHeroes.apk" \
	> /tmp/liangshan_android_apk.log 2>&1
cp "$BUILD/LiangshanHeroes.apk" "$BUILD/LiangshanHeroes-v$VERSION.apk"

echo "== Android $VERSION 完整内容留档 =="
"$GODOT" --headless --path . --export-pack "Android" \
	"$UPDATE_OUT/android/base-$VERSION.pck" > /tmp/liangshan_android_base.log 2>&1

echo "== macOS universal 导出、arm64 瘦身与签名 =="
rm -rf "$BUILD/LiangshanHeroes.app"
"$GODOT" --headless --path . --export-release "macOS" "$BUILD/LiangshanHeroes.app" \
	> /tmp/liangshan_mac_export.log 2>&1
APP="$BUILD/LiangshanHeroes.app"
BIN="$(find "$APP/Contents/MacOS" -maxdepth 1 -type f -perm +111 | head -n 1)"
[ -n "$BIN" ] || update_die "macOS app 中未找到可执行文件"
/usr/bin/lipo "$BIN" -thin arm64 -output /tmp/liangshan_arm64_bin
mv /tmp/liangshan_arm64_bin "$BIN"
chmod +x "$BIN"
/usr/bin/codesign --force --deep --sign - --timestamp=none "$APP"

echo "== macOS DMG =="
STAGE="$(mktemp -d /tmp/liangshan_dmg.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/LiangshanHeroes.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$BUILD/LiangshanHeroes.dmg"
hdiutil create -volname "水浒英雄传" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov \
	"$BUILD/LiangshanHeroes.dmg" >/dev/null
cp "$BUILD/LiangshanHeroes.dmg" "$BUILD/LiangshanHeroes-v$VERSION.dmg"
rm -rf "$STAGE"
trap - EXIT

echo "== macOS $VERSION 更新基线 =="
"$GODOT" --headless --path . --export-pack "macOS" \
	"$UPDATE_OUT/macos/base-$VERSION.pck" > /tmp/liangshan_mac_base.log 2>&1

echo "== Android 版本与签名 =="
AAPT="${AAPT:-$(find "$HOME/Library/Android/sdk/build-tools" -type f -name aapt 2>/dev/null | sort | tail -n 1)}"
APKSIGNER="${APKSIGNER:-$(find "$HOME/Library/Android/sdk/build-tools" -type f -name apksigner 2>/dev/null | sort | tail -n 1)}"
update_require_executable "$AAPT"
update_require_executable "$APKSIGNER"
APK_LINE="$("$AAPT" dump badging "$BUILD/LiangshanHeroes-v$VERSION.apk" | head -n 1)"
if [[ "$APK_LINE" != *"versionCode='$UPDATE_ANDROID_VERSION_CODE'"* || "$APK_LINE" != *"versionName='$VERSION'"* ]]; then
	update_die "APK 版本不匹配：$APK_LINE"
fi
if [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]; then
	export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
fi
"$APKSIGNER" verify --verbose "$BUILD/LiangshanHeroes-v$VERSION.apk" >/dev/null
SIGNER_SHA256="$("$APKSIGNER" verify --print-certs "$BUILD/LiangshanHeroes-v$VERSION.apk" | awk -F': ' '/Signer #1 certificate SHA-256 digest:/ {print tolower($2); exit}')"
[ "$SIGNER_SHA256" = "$UPDATE_ANDROID_SIGNER_SHA256" ] || \
	update_die "APK 签名证书不匹配（实际 $SIGNER_SHA256）"

echo "== macOS 版本、架构与签名 =="
MAC_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
[ "$MAC_VERSION" = "$VERSION" ] || update_die "macOS 版本不匹配：$MAC_VERSION"
[ "$(/usr/bin/lipo -archs "$BIN")" = "arm64" ] || update_die "macOS app 不是纯 arm64"
/usr/bin/codesign --verify --deep --strict "$APP"

echo "== 产物 SHA-256 =="
for platform in android windows macos; do
	artifact="$BUILD/$(update_artifact_name "$platform" "$VERSION")"
	base="$UPDATE_OUT/$platform/base-$VERSION.pck"
	printf '%-8s package %12s  %s\n' "$platform" "$(update_size "$artifact")" "$(update_sha256 "$artifact")"
	printf '%-8s base    %12s  %s\n' "$platform" "$(update_size "$base")" "$(update_sha256 "$base")"
done

# 绑定“源码提交 -> 六个构建产物”。基线发布会重新计算并逐项比对，防止误发旧 build/。
update_verify_git_release_point "$VERSION"
COMMIT="$(git rev-parse HEAD)"
python3 - "$UPDATE_OUT/build-source.json" "$ROOT" "$VERSION" "$COMMIT" <<'PY'
import datetime, hashlib, json, os, sys
target, root, version, commit = sys.argv[1:]

def describe(relative):
    path = os.path.join(root, relative)
    digest = hashlib.sha256()
    with open(path, "rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return {"path": relative, "size": os.path.getsize(path), "sha256": digest.hexdigest()}

extensions = {"android": "apk", "windows": "exe", "macos": "dmg"}
data = {
    "schema": 1,
    "version": version,
    "git_commit": commit,
    "built_at": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
    "platforms": {},
}
for platform, extension in extensions.items():
    data["platforms"][platform] = {
        "package": describe(f"build/LiangshanHeroes-v{version}.{extension}"),
        "base": describe(f"build/updates/{platform}/base-{version}.pck"),
    }
with open(target, "w", encoding="utf-8", newline="\n") as stream:
    json.dump(data, stream, ensure_ascii=False, indent=2)
    stream.write("\n")
PY

echo "三端完整包与 v$VERSION 更新基线构建完成。"
echo "构建来源证明：$UPDATE_OUT/build-source.json"
