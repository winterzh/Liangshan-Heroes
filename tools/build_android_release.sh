#!/bin/bash
# 只构建 Android 完整 APK 与热更新基准 PCK；不会导出或改动 Windows/macOS 包。
set -euo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/android-update"
APK="$ROOT/build/LiangshanHeroes.apk"
VERSION="1.5"
BASE="$OUT/base-$VERSION.pck"
EXPECTED_SIGNER_SHA256="5d1a80e66ce545a69acb6e2ffc7c22d61d0c62961ac44a9b0b9619888196ac54"

cd "$ROOT"
mkdir -p "$OUT"

echo "== Android $VERSION APK (arm64，保持现有 debug 签名以兼容覆盖安装) =="
"$GODOT" --headless --path . --export-debug "Android" "$APK" > /tmp/liangshan_android_apk.log 2>&1

echo "== Android $VERSION 完整包 PCK 留档（不覆盖 1.4.0 累计补丁基准） =="
"$GODOT" --headless --path . --export-pack "Android" "$BASE" > /tmp/liangshan_android_base_pck.log 2>&1

echo "== 完整性 =="
shasum -a 256 "$APK" "$BASE"
ls -lh "$APK" "$BASE"

AAPT="$HOME/Library/Android/sdk/build-tools/36.1.0/aapt"
[ -x "$AAPT" ] || { echo "缺少 aapt，无法验证 APK 版本" >&2; exit 1; }
APK_BADGING="$("$AAPT" dump badging "$APK")"
APK_PACKAGE_LINE="${APK_BADGING%%$'\n'*}"
echo "$APK_PACKAGE_LINE"
if [[ "$APK_PACKAGE_LINE" != *"versionCode='11'"* || "$APK_PACKAGE_LINE" != *"versionName='$VERSION'"* ]]; then
	echo "APK 版本不匹配，拒绝发包（期望 $VERSION/code 11）" >&2
	exit 1
fi

APKSIGNER="$HOME/Library/Android/sdk/build-tools/36.1.0/apksigner"
[ -x "$APKSIGNER" ] || { echo "缺少 apksigner，无法验证 APK 签名" >&2; exit 1; }
[ -x "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java" ] || { echo "缺少 Android Studio JBR" >&2; exit 1; }
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
"$APKSIGNER" verify --verbose "$APK"
SIGNER_SHA256="$("$APKSIGNER" verify --print-certs "$APK" | awk -F': ' '/Signer #1 certificate SHA-256 digest:/ {print tolower($2); exit}')"
if [ "$SIGNER_SHA256" != "$EXPECTED_SIGNER_SHA256" ]; then
	echo "APK 签名证书不匹配，拒绝发包" >&2
	echo "期望：$EXPECTED_SIGNER_SHA256" >&2
	echo "实际：$SIGNER_SHA256" >&2
	exit 1
fi
echo "APK signer SHA-256：$SIGNER_SHA256"
