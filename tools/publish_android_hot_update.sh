#!/bin/bash
# 从 Android 1.4.0 基准生成“基准→最新版”的累计 PCK，签名后原子发布到更新服务器。
set -euo pipefail

if [ "$#" -lt 1 ]; then
	echo "用法：bash tools/publish_android_hot_update.sh <内容版本，例如 1.4.1> [更新说明]" >&2
	exit 2
fi

VERSION="$1"
NOTES="${2:-安卓内容更新}"
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "内容版本必须是纯数字三段式，例如 1.4.1" >&2
	exit 2
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
BASE_VERSION="1.4.0"
if [ "$VERSION" = "$BASE_VERSION" ]; then
	echo "热更新版本不能等于基线 $BASE_VERSION" >&2
	exit 2
fi
OUT="$ROOT/build/android-update"
BASE="$OUT/base-$BASE_VERSION.pck"
PATCH_NAME="patch-$BASE_VERSION-to-$VERSION.pck"
PATCH="$OUT/$PATCH_NAME"
WORK="$OUT/publish-$VERSION"
PRIVATE_KEY="${LIANGSHAN_UPDATE_SIGNING_KEY:-$HOME/.config/liangshan-update/manifest-signing-private.pem}"
SSH_KEY="${LIANGSHAN_UPDATE_SSH_KEY:-$HOME/.ssh/liangshan_update_ed25519}"
REMOTE="${LIANGSHAN_UPDATE_REMOTE:-root@120.26.237.195}"
REMOTE_STABLE="/var/www/pAI/liangshan/android/stable"
REMOTE_RELEASES="/var/www/pAI/liangshan/android/releases"
PATCH_URL="http://120.26.237.195:1234/liangshan/android/releases/$PATCH_NAME"
FULL_URL="https://github.com/winterzh/Liangshan-Heroes/releases/download/v1.4.0/LiangshanHeroes.apk"

mkdir -p "$OUT" "$WORK"
[ -f "$PRIVATE_KEY" ] || { echo "缺少清单签名私钥：$PRIVATE_KEY" >&2; exit 1; }
[ -f "$SSH_KEY" ] || { echo "缺少服务器 SSH 密钥：$SSH_KEY" >&2; exit 1; }
if [ ! -f "$BASE" ]; then
	echo "本地无基准 PCK，从服务器私有备份取回……"
	scp -i "$SSH_KEY" "$REMOTE:/root/liangshan-update-bases/base-$BASE_VERSION.pck" "$BASE"
fi

cd "$ROOT"
"$GODOT" --headless --path . --export-patch "Android" "$PATCH" --patches "$BASE"
PATCH_SIZE="$(stat -f '%z' "$PATCH")"
PATCH_SHA="$(shasum -a 256 "$PATCH" | awk '{print $1}')"

python3 - "$WORK/manifest.json" "$VERSION" "$PATCH_URL" "$PATCH_SIZE" "$PATCH_SHA" "$FULL_URL" "$NOTES" <<'PY'
import datetime, json, sys
path, version, patch_url, size, sha256, full_url, notes = sys.argv[1:]
data = {
    "schema": 1,
    "channel": "stable",
    "published_at": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
    "content_version": version,
    "min_bootstrap": 1,
    "patch": {"url": patch_url, "size": int(size), "sha256": sha256},
    "full_apk": {"version_name": "1.4.0", "version_code": 10, "url": full_url},
    "notes": notes,
}
with open(path, "w", encoding="utf-8", newline="\n") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

openssl dgst -sha256 -sign "$PRIVATE_KEY" -out "$WORK/manifest.sig.bin" "$WORK/manifest.json"
openssl base64 -A -in "$WORK/manifest.sig.bin" -out "$WORK/manifest.sig"
openssl dgst -sha256 -verify <(openssl pkey -in "$PRIVATE_KEY" -pubout) \
	-signature "$WORK/manifest.sig.bin" "$WORK/manifest.json"

scp -i "$SSH_KEY" "$PATCH" "$REMOTE:$REMOTE_RELEASES/$PATCH_NAME.tmp"
scp -i "$SSH_KEY" "$WORK/manifest.json" "$WORK/manifest.sig" "$REMOTE:/tmp/"
ssh -i "$SSH_KEY" "$REMOTE" "\
mv '$REMOTE_RELEASES/$PATCH_NAME.tmp' '$REMOTE_RELEASES/$PATCH_NAME'; \
chmod 644 '$REMOTE_RELEASES/$PATCH_NAME'; \
install -m 644 /tmp/manifest.json '$REMOTE_RELEASES/manifest-$VERSION.json'; \
install -m 644 /tmp/manifest.sig '$REMOTE_RELEASES/manifest-$VERSION.sig'; \
install -m 644 /tmp/manifest.sig '$REMOTE_STABLE/manifest.sig'; \
install -m 644 /tmp/manifest.json '$REMOTE_STABLE/manifest.json'; \
rm -f /tmp/manifest.json /tmp/manifest.sig"

echo "累计补丁发布完成：$PATCH_NAME"
echo "大小：$PATCH_SIZE bytes"
echo "SHA-256：$PATCH_SHA"
curl --noproxy '*' --fail --silent --show-error \
	"http://120.26.237.195:1234/liangshan/android/stable/manifest.json"
