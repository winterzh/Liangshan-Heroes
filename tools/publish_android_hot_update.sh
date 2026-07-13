#!/bin/bash
# 从 Android 1.4.0 基准生成“基准→最新版”的累计 PCK，签名后原子发布到更新服务器。
set -euo pipefail

if [ "$#" -lt 1 ]; then
	echo "用法：bash tools/publish_android_hot_update.sh <内容版本，例如 1.5 或 1.5.1> [更新说明]" >&2
	exit 2
fi

VERSION="$1"
NOTES="${2:-安卓内容更新}"
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
	echo "内容版本必须是纯数字两段或三段式，例如 1.5 或 1.5.1" >&2
	exit 2
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
BASE_VERSION="1.4.0"
BASE_SHA_EXPECTED="d2198b09743d692041c6a5b976a6c3f58943f1955086f5332f9395e6e1a144de"
if ! python3 - "$VERSION" "$BASE_VERSION" <<'PY'
import sys
def parts(v):
    return tuple(int(x) for x in v.split(".")) + (0,) * (3 - len(v.split(".")))
sys.exit(0 if parts(sys.argv[1]) > parts(sys.argv[2]) else 1)
PY
then
	echo "热更新版本必须高于基线 ${BASE_VERSION}：${VERSION}" >&2
	exit 2
fi
OUT="$ROOT/build/android-update"
BASE="$OUT/base-$BASE_VERSION.pck"
PATCH_NAME="patch-$BASE_VERSION-to-$VERSION.pck"
PATCH="$OUT/$PATCH_NAME"
WORK="$OUT/publish-$VERSION"
PRIVATE_KEY="${LIANGSHAN_UPDATE_SIGNING_KEY:-$HOME/.config/liangshan-update/manifest-signing-private.pem}"
PUBLIC_KEY="${LIANGSHAN_UPDATE_PUBLIC_KEY:-$HOME/.config/liangshan-update/manifest-signing-public.pem}"
SSH_KEY="${LIANGSHAN_UPDATE_SSH_KEY:-$HOME/.ssh/liangshan_update_ed25519}"
REMOTE="${LIANGSHAN_UPDATE_REMOTE:-root@120.26.237.195}"
REMOTE_STABLE="/var/www/pAI/liangshan/android/stable"
REMOTE_RELEASES="/var/www/pAI/liangshan/android/releases"
PATCH_URL="http://120.26.237.195:1234/liangshan/android/releases/$PATCH_NAME"
RELEASE_MANIFEST_URL="http://120.26.237.195:1234/liangshan/android/releases/manifest-$VERSION.json"
RELEASE_SIGNATURE_URL="http://120.26.237.195:1234/liangshan/android/releases/manifest-$VERSION.sig"
STABLE_MANIFEST_URL="http://120.26.237.195:1234/liangshan/android/stable/manifest.json"
FULL_URL="https://github.com/winterzh/Liangshan-Heroes/releases/download/v1.5/LiangshanHeroes-v1.5.apk"

mkdir -p "$OUT" "$WORK"
[ -f "$PRIVATE_KEY" ] || { echo "缺少清单签名私钥：$PRIVATE_KEY" >&2; exit 1; }
[ -f "$PUBLIC_KEY" ] || { echo "缺少客户端清单公钥副本：$PUBLIC_KEY" >&2; exit 1; }
[ -f "$SSH_KEY" ] || { echo "缺少服务器 SSH 密钥：$SSH_KEY" >&2; exit 1; }
# stable 清单会把需要完整包的用户引到该 URL；文件尚未发布时禁止提前切流量。
if ! curl --fail --silent --show-error --location --head "$FULL_URL" >/dev/null; then
	echo "GitHub 完整 APK 尚不可下载，拒绝发布热更新：$FULL_URL" >&2
	exit 1
fi
# 内容版本只升不降，也不能覆盖 stable 的同版本；已经装过旧同名补丁的客户端不会重新下载。
curl --noproxy '*' --fail --silent --show-error "$STABLE_MANIFEST_URL" -o "$WORK/current-stable.json"
CURRENT_STABLE="$(python3 - "$WORK/current-stable.json" <<'PY'
import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8")).get("content_version", ""))
PY
)"
if ! python3 - "$VERSION" "$CURRENT_STABLE" <<'PY'
import sys
def parts(v):
    xs = v.split(".") if v else ["0"]
    return tuple(int(x) for x in xs) + (0,) * (3 - len(xs))
sys.exit(0 if parts(sys.argv[1]) > parts(sys.argv[2]) else 1)
PY
then
	echo "内容版本必须高于当前 stable ${CURRENT_STABLE}：${VERSION}" >&2
	exit 2
fi
if [ ! -f "$BASE" ]; then
	echo "本地无基准 PCK，从服务器私有备份取回……"
	scp -i "$SSH_KEY" "$REMOTE:/root/liangshan-update-bases/base-$BASE_VERSION.pck" "$BASE"
fi
BASE_SHA_ACTUAL="$(shasum -a 256 "$BASE" | awk '{print $1}')"
if [ "$BASE_SHA_ACTUAL" != "$BASE_SHA_EXPECTED" ]; then
	echo "基准 PCK 校验失败，已拒绝生成补丁：$BASE" >&2
	echo "期望 SHA-256：$BASE_SHA_EXPECTED" >&2
	echo "实际 SHA-256：$BASE_SHA_ACTUAL" >&2
	exit 1
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
    "full_apk": {"version_name": "1.5", "version_code": 11, "url": full_url},
    "notes": notes,
}
with open(path, "w", encoding="utf-8", newline="\n") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

openssl dgst -sha256 -sign "$PRIVATE_KEY" -out "$WORK/manifest.sig.bin" "$WORK/manifest.json"
openssl base64 -A -in "$WORK/manifest.sig.bin" -out "$WORK/manifest.sig"
openssl dgst -sha256 -verify "$PUBLIC_KEY" \
	-signature "$WORK/manifest.sig.bin" "$WORK/manifest.json"

# 版本化文件不可覆盖；若预发布阶段失败，修正后使用更高内容版本，避免客户端缓存歧义。
ssh -i "$SSH_KEY" "$REMOTE" "set -e; \
test ! -e '$REMOTE_RELEASES/$PATCH_NAME'; \
test ! -e '$REMOTE_RELEASES/manifest-$VERSION.json'; \
test ! -e '$REMOTE_RELEASES/manifest-$VERSION.sig'"
scp -i "$SSH_KEY" "$PATCH" "$REMOTE:$REMOTE_RELEASES/$PATCH_NAME.tmp"
scp -i "$SSH_KEY" "$WORK/manifest.json" "$WORK/manifest.sig" "$REMOTE:/tmp/"
ssh -i "$SSH_KEY" "$REMOTE" "set -e; \
mv '$REMOTE_RELEASES/$PATCH_NAME.tmp' '$REMOTE_RELEASES/$PATCH_NAME'; \
chmod 644 '$REMOTE_RELEASES/$PATCH_NAME'; \
install -m 644 /tmp/manifest.json '$REMOTE_RELEASES/manifest-$VERSION.json'; \
install -m 644 /tmp/manifest.sig '$REMOTE_RELEASES/manifest-$VERSION.sig'; \
rm -f /tmp/manifest.json /tmp/manifest.sig"

# 先从公开服务回读版本化文件并验签/验哈希，全部一致后才提升 stable。
curl --noproxy '*' --fail --silent --show-error "$PATCH_URL" -o "$WORK/public.patch.pck"
curl --noproxy '*' --fail --silent --show-error "$RELEASE_MANIFEST_URL" -o "$WORK/public-manifest.json"
curl --noproxy '*' --fail --silent --show-error "$RELEASE_SIGNATURE_URL" -o "$WORK/public-manifest.sig"
[ "$(stat -f '%z' "$WORK/public.patch.pck")" = "$PATCH_SIZE" ] || { echo "公网补丁大小不一致，stable 未切换" >&2; exit 1; }
[ "$(shasum -a 256 "$WORK/public.patch.pck" | awk '{print $1}')" = "$PATCH_SHA" ] || { echo "公网补丁哈希不一致，stable 未切换" >&2; exit 1; }
cmp -s "$WORK/manifest.json" "$WORK/public-manifest.json" || { echo "公网版本清单不一致，stable 未切换" >&2; exit 1; }
openssl base64 -d -A -in "$WORK/public-manifest.sig" -out "$WORK/public-manifest.sig.bin"
openssl dgst -sha256 -verify "$PUBLIC_KEY" -signature "$WORK/public-manifest.sig.bin" "$WORK/public-manifest.json"

ssh -i "$SSH_KEY" "$REMOTE" "set -e; \
install -m 644 '$REMOTE_RELEASES/manifest-$VERSION.sig' '$REMOTE_STABLE/manifest.sig'; \
install -m 644 '$REMOTE_RELEASES/manifest-$VERSION.json' '$REMOTE_STABLE/manifest.json'"

echo "累计补丁发布完成：$PATCH_NAME"
echo "大小：$PATCH_SIZE bytes"
echo "SHA-256：$PATCH_SHA"
curl --noproxy '*' --fail --silent --show-error \
	"$STABLE_MANIFEST_URL"
