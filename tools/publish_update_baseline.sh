#!/bin/bash
# 发布两段式完整版本：三端完整包已在 GitHub 后，登记不可变基线并切换三端 stable。
# Android 为兼容 1.4/1.5 旧 APK，同时发布 1.4.0 -> 当前版累计补丁；桌面本版本 patch=null。
set -euo pipefail

if [ "$#" -lt 1 ]; then
	echo "用法：bash tools/publish_update_baseline.sh <完整版本，例如 1.6> [更新说明]" >&2
	exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tools/update_release.env"
source "$ROOT/tools/lib_update_release.sh"

VERSION="$1"
NOTES="${2:-三端内容更新基线}"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
BUILD="$ROOT/build"
UPDATE_OUT="$BUILD/updates"
WORK="$BUILD/update-publish/baseline-$VERSION"
UPDATE_PRIVATE_KEY="${LIANGSHAN_UPDATE_SIGNING_KEY:-$HOME/.config/liangshan-update/manifest-signing-private.pem}"
UPDATE_PUBLIC_KEY="${LIANGSHAN_UPDATE_PUBLIC_KEY:-$HOME/.config/liangshan-update/manifest-signing-public.pem}"
SSH_KEY="${LIANGSHAN_UPDATE_SSH_KEY:-$HOME/.ssh/liangshan_update_ed25519}"
REMOTE="${LIANGSHAN_UPDATE_REMOTE:-root@120.26.237.195}"
PLATFORMS="android windows macos"

update_require_full_version "$VERSION"
[ "$VERSION" = "$UPDATE_BASE_VERSION" ] || update_die "版本 $VERSION 与 update_release.env 基线 $UPDATE_BASE_VERSION 不一致"
update_require_executable "$GODOT"
update_require_file "$UPDATE_PRIVATE_KEY"
update_require_file "$UPDATE_PUBLIC_KEY"
update_require_file "$SSH_KEY"
update_verify_git_release_point "$VERSION"
mkdir -p "$WORK"

echo "== 检查完整包与新基线 =="
for platform in $PLATFORMS; do
	update_require_file "$BUILD/$(update_artifact_name "$platform" "$VERSION")"
	update_require_file "$UPDATE_OUT/$platform/base-$VERSION.pck"
done
update_verify_build_source "$UPDATE_OUT/build-source.json" "$ROOT" "$VERSION"

ANDROID_APK_NAME="$(update_artifact_name android "$VERSION")"
ANDROID_APK="$BUILD/$ANDROID_APK_NAME"
ANDROID_APK_URL="$UPDATE_PUBLIC_ROOT/android/releases/$ANDROID_APK_NAME"

echo "== 生成 Android 旧客户端累计补丁 =="
ANDROID_OLD_BASE="$UPDATE_OUT/android/base-$UPDATE_ANDROID_PATCH_BASE_VERSION.pck"
if [ ! -f "$ANDROID_OLD_BASE" ] && [ -f "$BUILD/android-update/base-$UPDATE_ANDROID_PATCH_BASE_VERSION.pck" ]; then
	cp "$BUILD/android-update/base-$UPDATE_ANDROID_PATCH_BASE_VERSION.pck" "$ANDROID_OLD_BASE"
fi
if [ ! -f "$ANDROID_OLD_BASE" ]; then
	scp -i "$SSH_KEY" "$REMOTE:$UPDATE_REMOTE_BASE_ROOT/base-$UPDATE_ANDROID_PATCH_BASE_VERSION.pck" "$ANDROID_OLD_BASE"
fi
[ "$(update_sha256 "$ANDROID_OLD_BASE")" = "$UPDATE_ANDROID_PATCH_BASE_SHA256" ] || \
	update_die "Android $UPDATE_ANDROID_PATCH_BASE_VERSION 历史基线 SHA-256 不匹配"
ANDROID_PATCH_NAME="patch-$UPDATE_ANDROID_PATCH_BASE_VERSION-to-$VERSION.pck"
ANDROID_PATCH="$UPDATE_OUT/android/$ANDROID_PATCH_NAME"
cd "$ROOT"
"$GODOT" --headless --path . --export-patch "Android" "$ANDROID_PATCH" --patches "$ANDROID_OLD_BASE"

echo "== 检查现有 stable，只允许升版 =="
for platform in $PLATFORMS; do
	stable_dir="$WORK/current-$platform"
	if update_fetch_stable "$platform" "$stable_dir"; then
		current="$(update_manifest_value "$stable_dir/manifest.json" content_version)"
		update_version_gt "$VERSION" "$current" || update_die "$platform stable 已是 $current，禁止覆盖为 $VERSION"
	fi
done

echo "== 检查 GitHub 三端完整包并回读哈希 =="
for platform in $PLATFORMS; do
	artifact="$BUILD/$(update_artifact_name "$platform" "$VERSION")"
	url="$(update_github_artifact_url "$platform" "$VERSION")"
	size="$(update_size "$artifact")"
	sha="$(update_sha256 "$artifact")"
	if [ "${LIANGSHAN_VERIFY_FULL_DOWNLOAD:-1}" = "1" ]; then
		update_download_and_verify "$url" "$WORK/public-$(basename "$artifact")" "$size" "$sha"
	else
		curl --fail --silent --show-error --location --head "$url" >/dev/null
	fi
done

echo "== 生成并签名三端 v$VERSION 清单 =="
for platform in $PLATFORMS; do
	dir="$WORK/$platform"
	mkdir -p "$dir"
	artifact="$BUILD/$(update_artifact_name "$platform" "$VERSION")"
	packaged_base="$UPDATE_OUT/$platform/base-$VERSION.pck"
	full_url="$(update_github_artifact_url "$platform" "$VERSION")"
	full_kind="$(update_platform_kind "$platform")"
	architecture="$(update_platform_architecture "$platform")"
	min_bootstrap="$UPDATE_BOOTSTRAP_VERSION"
	patch_json="null"
	patch_base="$packaged_base"
	patch_base_version="$VERSION"
	if [ "$platform" = "android" ]; then
		full_url="$ANDROID_APK_URL"
		min_bootstrap=1
		patch_base="$ANDROID_OLD_BASE"
		patch_base_version="$UPDATE_ANDROID_PATCH_BASE_VERSION"
		patch_size="$(update_size "$ANDROID_PATCH")"
		patch_sha="$(update_sha256 "$ANDROID_PATCH")"
		patch_url="$UPDATE_PUBLIC_ROOT/android/releases/$ANDROID_PATCH_NAME"
		patch_json="{\"platform\":\"$platform\",\"architecture\":\"$architecture\",\"url\":\"$patch_url\",\"size\":$patch_size,\"sha256\":\"$patch_sha\"}"
	fi
	python3 - "$dir/manifest.json" "$platform" "$architecture" "$VERSION" "$min_bootstrap" \
		"$packaged_base" "$patch_base_version" "$patch_base" "$patch_json" \
		"$full_kind" "$full_url" "$artifact" "$UPDATE_ANDROID_VERSION_CODE" "$NOTES" <<'PY'
import datetime, json, os, sys, hashlib

(path, platform, architecture, version, min_bootstrap, packaged_path, patch_base_version,
 patch_base_path, patch_raw, full_kind, full_url, artifact_path,
 android_code, notes) = sys.argv[1:]

def info(file_path):
    digest = hashlib.sha256()
    with open(file_path, "rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return {"size": os.path.getsize(file_path), "sha256": digest.hexdigest()}

full = {"version_name": version, "kind": full_kind, "url": full_url, **info(artifact_path)}
data = {
    "schema": 1,
    "channel": "stable",
    "platform": platform,
    "architecture": architecture,
    "published_at": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
    "content_version": version,
    "min_bootstrap": int(min_bootstrap),
    "packaged_base": {"version": version, **info(packaged_path)},
    "patch_base": {"version": patch_base_version, **info(patch_base_path)},
    "patch": json.loads(patch_raw),
    "full_package": full,
    "notes": notes,
}
if platform == "android":
    data["full_apk"] = {
        "version_name": version,
        "version_code": int(android_code),
        "url": full_url,
        "size": full["size"],
        "sha256": full["sha256"],
    }
with open(path, "w", encoding="utf-8", newline="\n") as stream:
    json.dump(data, stream, ensure_ascii=False, indent=2)
    stream.write("\n")
PY
	update_sign_manifest "$dir/manifest.json" "$dir/manifest.sig"
done

echo "== 服务器不可变路径预检 =="
ssh -i "$SSH_KEY" "$REMOTE" "set -e; \
for platform in $PLATFORMS; do \
  install -d -m 755 '$UPDATE_REMOTE_WEB_ROOT/'\"\$platform\"'/stable' '$UPDATE_REMOTE_WEB_ROOT/'\"\$platform\"'/releases'; \
  install -d -m 700 '$UPDATE_REMOTE_BASE_ROOT/'\"\$platform\"; \
  test ! -e '$UPDATE_REMOTE_WEB_ROOT/'\"\$platform\"'/releases/manifest-$VERSION.json'; \
  test ! -e '$UPDATE_REMOTE_WEB_ROOT/'\"\$platform\"'/releases/manifest-$VERSION.sig'; \
  test ! -e '$UPDATE_REMOTE_BASE_ROOT/'\"\$platform\"'/base-$VERSION.pck'; \
done; \
test ! -e '$UPDATE_REMOTE_WEB_ROOT/android/releases/$ANDROID_PATCH_NAME'; \
test ! -e '$UPDATE_REMOTE_WEB_ROOT/android/releases/$ANDROID_APK_NAME'"

REMOTE_TMP="/tmp/liangshan-baseline-$VERSION-$$"
ssh -i "$SSH_KEY" "$REMOTE" "install -d -m 700 '$REMOTE_TMP'"
for platform in $PLATFORMS; do
	scp -i "$SSH_KEY" "$UPDATE_OUT/$platform/base-$VERSION.pck" "$REMOTE:$REMOTE_TMP/base-$platform.pck"
	scp -i "$SSH_KEY" "$WORK/$platform/manifest.json" "$REMOTE:$REMOTE_TMP/manifest-$platform.json"
	scp -i "$SSH_KEY" "$WORK/$platform/manifest.sig" "$REMOTE:$REMOTE_TMP/manifest-$platform.sig"
	base_sha="$(update_sha256 "$UPDATE_OUT/$platform/base-$VERSION.pck")"
	manifest_sha="$(update_sha256 "$WORK/$platform/manifest.json")"
	signature_sha="$(update_sha256 "$WORK/$platform/manifest.sig")"
	ssh -i "$SSH_KEY" "$REMOTE" "set -e; \
echo '$base_sha  $REMOTE_TMP/base-$platform.pck' | sha256sum -c -; \
echo '$manifest_sha  $REMOTE_TMP/manifest-$platform.json' | sha256sum -c -; \
echo '$signature_sha  $REMOTE_TMP/manifest-$platform.sig' | sha256sum -c -"
done
scp -i "$SSH_KEY" "$ANDROID_PATCH" "$REMOTE:$REMOTE_TMP/$ANDROID_PATCH_NAME"
scp -i "$SSH_KEY" "$ANDROID_APK" "$REMOTE:$REMOTE_TMP/$ANDROID_APK_NAME"
android_patch_sha="$(update_sha256 "$ANDROID_PATCH")"
android_apk_sha="$(update_sha256 "$ANDROID_APK")"
ssh -i "$SSH_KEY" "$REMOTE" "set -e; \
echo '$android_patch_sha  $REMOTE_TMP/$ANDROID_PATCH_NAME' | sha256sum -c -; \
echo '$android_apk_sha  $REMOTE_TMP/$ANDROID_APK_NAME' | sha256sum -c -"
ssh -i "$SSH_KEY" "$REMOTE" "set -e; \
for platform in $PLATFORMS; do \
  install -m 600 '$REMOTE_TMP/base-'\"\$platform\"'.pck' '$UPDATE_REMOTE_BASE_ROOT/'\"\$platform\"'/base-$VERSION.pck'; \
  install -m 644 '$REMOTE_TMP/manifest-'\"\$platform\"'.json' '$UPDATE_REMOTE_WEB_ROOT/'\"\$platform\"'/releases/manifest-$VERSION.json'; \
  install -m 644 '$REMOTE_TMP/manifest-'\"\$platform\"'.sig' '$UPDATE_REMOTE_WEB_ROOT/'\"\$platform\"'/releases/manifest-$VERSION.sig'; \
done; \
install -m 644 '$REMOTE_TMP/$ANDROID_PATCH_NAME' '$UPDATE_REMOTE_WEB_ROOT/android/releases/$ANDROID_PATCH_NAME'; \
install -m 644 '$REMOTE_TMP/$ANDROID_APK_NAME' '$UPDATE_REMOTE_WEB_ROOT/android/releases/$ANDROID_APK_NAME'; \
rm -rf '$REMOTE_TMP'"

echo "== 公网回读版本化清单、签名和 Android 补丁 =="
for platform in $PLATFORMS; do
	url="$UPDATE_PUBLIC_ROOT/$platform/releases"
	curl --noproxy '*' --fail --silent --show-error "$url/manifest-$VERSION.json" -o "$WORK/$platform/public-manifest.json"
	curl --noproxy '*' --fail --silent --show-error "$url/manifest-$VERSION.sig" -o "$WORK/$platform/public-manifest.sig"
	cmp -s "$WORK/$platform/manifest.json" "$WORK/$platform/public-manifest.json" || update_die "$platform 公网清单内容不一致"
	update_verify_manifest "$WORK/$platform/public-manifest.json" "$WORK/$platform/public-manifest.sig"
done
update_download_and_verify "$UPDATE_PUBLIC_ROOT/android/releases/$ANDROID_PATCH_NAME" \
	"$WORK/android/public-$ANDROID_PATCH_NAME" "$(update_size "$ANDROID_PATCH")" "$(update_sha256 "$ANDROID_PATCH")"
update_download_and_verify "$ANDROID_APK_URL" "$WORK/android/public-$ANDROID_APK_NAME" \
	"$(update_size "$ANDROID_APK")" "$(update_sha256 "$ANDROID_APK")"

echo "== 三端一起提升 stable =="
update_promote_all_stable "$VERSION"

for platform in $PLATFORMS; do
	stable_dir="$WORK/promoted-$platform"
	update_fetch_stable "$platform" "$stable_dir" || update_die "$platform stable 公网回读失败"
	cmp -s "$WORK/$platform/manifest.json" "$stable_dir/manifest.json" || update_die "$platform stable 未指向 v$VERSION"
done

echo "三端 v$VERSION 更新基线发布完成。"
echo "Android：保留 $UPDATE_ANDROID_PATCH_BASE_VERSION 累计补丁链；Windows/macOS：v$VERSION 起建立新补丁链。"
