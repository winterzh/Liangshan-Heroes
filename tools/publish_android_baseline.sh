#!/bin/bash
# 发布 Android 1.4.0 完整基线：GitHub 只放 APK，更新服务器只放签名清单；基准 PCK 私下备份。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="1.4.0"
TAG="v$VERSION"
APK="$ROOT/build/LiangshanHeroes.apk"
BASE="$ROOT/build/android-update/base-$VERSION.pck"
WORK="$ROOT/build/android-update/publish-$VERSION"
PRIVATE_KEY="${LIANGSHAN_UPDATE_SIGNING_KEY:-$HOME/.config/liangshan-update/manifest-signing-private.pem}"
SSH_KEY="${LIANGSHAN_UPDATE_SSH_KEY:-$HOME/.ssh/liangshan_update_ed25519}"
REMOTE="${LIANGSHAN_UPDATE_REMOTE:-root@120.26.237.195}"
REMOTE_STABLE="/var/www/pAI/liangshan/android/stable"
REMOTE_RELEASES="/var/www/pAI/liangshan/android/releases"
FULL_URL="https://github.com/winterzh/Liangshan-Heroes/releases/download/$TAG/LiangshanHeroes.apk"

for f in "$APK" "$BASE" "$PRIVATE_KEY" "$SSH_KEY"; do
	[ -f "$f" ] || { echo "缺少文件：$f" >&2; exit 1; }
done
mkdir -p "$WORK"

python3 - "$WORK/manifest.json" "$FULL_URL" <<'PY'
import datetime, json, sys
path, full_url = sys.argv[1:]
data = {
    "schema": 1,
    "channel": "stable",
    "published_at": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
    "content_version": "1.4.0",
    "min_bootstrap": 1,
    "patch": None,
    "full_apk": {"version_name": "1.4.0", "version_code": 10, "url": full_url},
    "notes": "Android 热更新基线版本",
}
with open(path, "w", encoding="utf-8", newline="\n") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

openssl dgst -sha256 -sign "$PRIVATE_KEY" -out "$WORK/manifest.sig.bin" "$WORK/manifest.json"
openssl base64 -A -in "$WORK/manifest.sig.bin" -out "$WORK/manifest.sig"
openssl dgst -sha256 -verify <(openssl pkey -in "$PRIVATE_KEY" -pubout) \
	-signature "$WORK/manifest.sig.bin" "$WORK/manifest.json"

if gh release view "$TAG" >/dev/null 2>&1; then
	gh release upload "$TAG" "$APK" --clobber
else
	gh release create "$TAG" "$APK" --target main --title "水浒英雄传 Android v$VERSION" \
		--notes "Android 热更新基线完整包。以后常规内容更新只下载更新服务器上的差异 PCK。"
fi

ssh -i "$SSH_KEY" "$REMOTE" "install -d -m 755 '$REMOTE_STABLE' '$REMOTE_RELEASES'; install -d -m 700 /root/liangshan-update-bases"
scp -i "$SSH_KEY" "$BASE" "$REMOTE:/root/liangshan-update-bases/base-$VERSION.pck"
scp -i "$SSH_KEY" "$WORK/manifest.json" "$WORK/manifest.sig" "$REMOTE:/tmp/"
ssh -i "$SSH_KEY" "$REMOTE" "\
install -m 644 /tmp/manifest.json '$REMOTE_RELEASES/manifest-$VERSION.json'; \
install -m 644 /tmp/manifest.sig '$REMOTE_RELEASES/manifest-$VERSION.sig'; \
install -m 644 /tmp/manifest.sig '$REMOTE_STABLE/manifest.sig'; \
install -m 644 /tmp/manifest.json '$REMOTE_STABLE/manifest.json'; \
rm -f /tmp/manifest.json /tmp/manifest.sig"

echo "发布完成：$FULL_URL"
echo "更新清单：http://120.26.237.195:1234/liangshan/android/stable/manifest.json"
