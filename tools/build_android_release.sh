#!/bin/bash
# 仅构建当前两段式完整版本的 Android APK 与完整内容留档 PCK。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tools/update_release.env"
source "$ROOT/tools/lib_update_release.sh"

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
VERSION="${1:-$UPDATE_BASE_VERSION}"
BUILD="$ROOT/build"
OUT="$BUILD/updates/android"
APK="$BUILD/LiangshanHeroes-v$VERSION.apk"
BASE="$OUT/base-$VERSION.pck"

update_require_full_version "$VERSION"
[ "$VERSION" = "$UPDATE_BASE_VERSION" ] || update_die "Android 版本 $VERSION 与当前更新基线 $UPDATE_BASE_VERSION 不一致"
update_require_executable "$GODOT"
update_verify_git_release_point "$VERSION"
mkdir -p "$OUT"
cd "$ROOT"

python3 - "$ROOT/export_presets.cfg" "$VERSION" "$UPDATE_ANDROID_VERSION_CODE" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
version, code = sys.argv[2:]
if f'version/name="{version}"' not in text or f'version/code={code}' not in text:
    raise SystemExit("export_presets.cfg 的 Android versionName/versionCode 尚未同步")
PY

"$GODOT" --headless --path . --export-debug "Android" "$BUILD/LiangshanHeroes.apk" \
	> /tmp/liangshan_android_apk.log 2>&1
cp "$BUILD/LiangshanHeroes.apk" "$APK"
"$GODOT" --headless --path . --export-pack "Android" "$BASE" \
	> /tmp/liangshan_android_base.log 2>&1

AAPT="${AAPT:-$(find "$HOME/Library/Android/sdk/build-tools" -type f -name aapt 2>/dev/null | sort | tail -n 1)}"
APKSIGNER="${APKSIGNER:-$(find "$HOME/Library/Android/sdk/build-tools" -type f -name apksigner 2>/dev/null | sort | tail -n 1)}"
update_require_executable "$AAPT"
update_require_executable "$APKSIGNER"
APK_LINE="$("$AAPT" dump badging "$APK" | head -n 1)"
if [[ "$APK_LINE" != *"versionCode='$UPDATE_ANDROID_VERSION_CODE'"* || "$APK_LINE" != *"versionName='$VERSION'"* ]]; then
	update_die "APK 版本不匹配：$APK_LINE"
fi
if [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]; then
	export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
fi
"$APKSIGNER" verify --verbose "$APK" >/dev/null
SIGNER_SHA256="$("$APKSIGNER" verify --print-certs "$APK" | awk -F': ' '/Signer #1 certificate SHA-256 digest:/ {print tolower($2); exit}')"
[ "$SIGNER_SHA256" = "$UPDATE_ANDROID_SIGNER_SHA256" ] || update_die "APK 签名证书不匹配"

shasum -a 256 "$APK" "$BASE"
ls -lh "$APK" "$BASE"
echo "Android v$VERSION 完整包构建完成；该 PCK 是留档基线，不替换旧客户端使用的 1.4.0 补丁基线。"
