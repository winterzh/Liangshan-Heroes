#!/bin/bash
# 只构建 Android 完整 APK 与热更新基准 PCK；不会导出或改动 Windows/macOS 包。
set -euo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/android-update"
APK="$ROOT/build/LiangshanHeroes.apk"
BASE="$OUT/base-1.4.0.pck"

cd "$ROOT"
mkdir -p "$OUT"

echo "== Android 1.4.0 APK (arm64, 保持现有 debug 签名以兼容 1.3.5 覆盖安装) =="
"$GODOT" --headless --path . --export-debug "Android" "$APK" > /tmp/liangshan_android_apk.log 2>&1

echo "== Android 1.4.0 热更新基准 PCK =="
"$GODOT" --headless --path . --export-pack "Android" "$BASE" > /tmp/liangshan_android_base_pck.log 2>&1

echo "== 完整性 =="
shasum -a 256 "$APK" "$BASE"
ls -lh "$APK" "$BASE"

if command -v "$HOME/Library/Android/sdk/build-tools/36.1.0/aapt" >/dev/null 2>&1; then
	"$HOME/Library/Android/sdk/build-tools/36.1.0/aapt" dump badging "$APK" | head -1
fi

APKSIGNER="$HOME/Library/Android/sdk/build-tools/36.1.0/apksigner"
if [ -x "$APKSIGNER" ] && [ -x "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java" ]; then
	export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
	"$APKSIGNER" verify --verbose "$APK"
fi
