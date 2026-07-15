#!/bin/bash
# 从各平台固定基线生成“基线 -> 当前源码”的累计差异包，并同步提升三端 stable。
# Android 固定从 1.4.0 生成以兼容旧 APK；Windows/macOS 从当前两段式完整版本生成。
set -euo pipefail

if [ "$#" -lt 1 ]; then
	echo "用法：bash tools/publish_hot_update.sh <内容版本，例如 1.6.1> [更新说明]" >&2
	exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tools/update_release.env"
source "$ROOT/tools/lib_update_release.sh"

VERSION="$1"
NOTES="${2:-三端内容更新}"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
BUILD="$ROOT/build"
UPDATE_OUT="$BUILD/updates"
WORK="$BUILD/update-publish/hot-$VERSION"
UPDATE_PRIVATE_KEY="${LIANGSHAN_UPDATE_SIGNING_KEY:-$HOME/.config/liangshan-update/manifest-signing-private.pem}"
UPDATE_PUBLIC_KEY="${LIANGSHAN_UPDATE_PUBLIC_KEY:-$HOME/.config/liangshan-update/manifest-signing-public.pem}"
SSH_KEY="${LIANGSHAN_UPDATE_SSH_KEY:-$HOME/.ssh/liangshan_update_ed25519}"
REMOTE="${LIANGSHAN_UPDATE_REMOTE:-root@120.26.237.195}"
PLATFORMS="android windows macos"

update_require_patch_version "$VERSION"
update_same_release_line "$VERSION" "$UPDATE_BASE_VERSION" || \
	update_die "补丁 $VERSION 不属于当前完整版本 v$UPDATE_BASE_VERSION"
update_version_gt "$VERSION" "$UPDATE_BASE_VERSION" || update_die "补丁版本必须高于 v$UPDATE_BASE_VERSION"
update_require_executable "$GODOT"
update_require_file "$UPDATE_PRIVATE_KEY"
update_require_file "$UPDATE_PUBLIC_KEY"
update_require_file "$SSH_KEY"
update_verify_git_release_point "$VERSION"
update_require_hot_update_safe "$UPDATE_BASE_VERSION"
mkdir -p "$WORK"

echo "== 读取并验证三端 v$UPDATE_BASE_VERSION 基线清单 =="
for platform in $PLATFORMS; do
	dir="$WORK/base-manifest-$platform"
	mkdir -p "$dir"
	base_url="$UPDATE_PUBLIC_ROOT/$platform/releases"
	curl --noproxy '*' --fail --silent --show-error \
		"$base_url/manifest-$UPDATE_BASE_VERSION.json" -o "$dir/manifest.json"
	curl --noproxy '*' --fail --silent --show-error \
		"$base_url/manifest-$UPDATE_BASE_VERSION.sig" -o "$dir/manifest.sig"
	update_verify_manifest "$dir/manifest.json" "$dir/manifest.sig"
	[ "$(update_manifest_value "$dir/manifest.json" content_version)" = "$UPDATE_BASE_VERSION" ] || \
		update_die "$platform 基线清单版本错误"
	[ "$(update_manifest_value "$dir/manifest.json" platform)" = "$platform" ] || \
		update_die "$platform 基线清单平台错误"
	full_url="$(update_manifest_value "$dir/manifest.json" full_package.url)"
	curl --fail --silent --show-error --location --head "$full_url" >/dev/null
done

echo "== 检查 stable，只允许当前发布线同步升版 =="
for platform in $PLATFORMS; do
	dir="$WORK/current-$platform"
	update_fetch_stable "$platform" "$dir" || update_die "$platform stable 不存在；必须先发布 v$UPDATE_BASE_VERSION 基线"
	current="$(update_manifest_value "$dir/manifest.json" content_version)"
	update_same_release_line "$current" "$UPDATE_BASE_VERSION" || \
		update_die "$platform stable $current 不属于 v$UPDATE_BASE_VERSION 发布线"
	update_version_gt "$VERSION" "$current" || update_die "$platform stable 已是 $current，禁止覆盖为 $VERSION"
done

echo "== 取回、校验固定 PCK 基线并生成累计补丁 =="
for platform in $PLATFORMS; do
	manifest="$WORK/base-manifest-$platform/manifest.json"
	base_version="$(update_manifest_value "$manifest" patch_base.version)"
	base_size="$(update_manifest_value "$manifest" patch_base.size)"
	base_sha="$(update_manifest_value "$manifest" patch_base.sha256)"
	base_dir="$UPDATE_OUT/$platform"
	base="$base_dir/base-$base_version.pck"
	mkdir -p "$base_dir" "$WORK/$platform"
	if [ ! -f "$base" ]; then
		if [ "$platform" = "android" ] && [ "$base_version" = "$UPDATE_ANDROID_PATCH_BASE_VERSION" ]; then
			legacy="$BUILD/android-update/base-$base_version.pck"
			if [ -f "$legacy" ]; then
				cp "$legacy" "$base"
			else
				scp -i "$SSH_KEY" "$REMOTE:$UPDATE_REMOTE_BASE_ROOT/base-$base_version.pck" "$base"
			fi
		else
			scp -i "$SSH_KEY" "$REMOTE:$UPDATE_REMOTE_BASE_ROOT/$platform/base-$base_version.pck" "$base"
		fi
	fi
	[ "$(update_size "$base")" = "$base_size" ] || update_die "$platform 基线大小不匹配：$base"
	[ "$(update_sha256 "$base")" = "$base_sha" ] || update_die "$platform 基线 SHA-256 不匹配：$base"
	patch_name="patch-$base_version-to-$VERSION.pck"
	patch="$base_dir/$patch_name"
	preset="$(update_platform_preset "$platform")"
	cd "$ROOT"
	"$GODOT" --headless --path . --export-patch "$preset" "$patch" --patches "$base"
	patch_size="$(update_size "$patch")"
	patch_sha="$(update_sha256 "$patch")"
	patch_url="$UPDATE_PUBLIC_ROOT/$platform/releases/$patch_name"
	architecture="$(update_platform_architecture "$platform")"
	python3 - "$manifest" "$WORK/$platform/manifest.json" "$VERSION" \
		"$platform" "$architecture" "$patch_url" "$patch_size" "$patch_sha" "$NOTES" <<'PY'
import datetime, json, sys
source, target, version, platform, architecture, patch_url, patch_size, patch_sha, notes = sys.argv[1:]
with open(source, encoding="utf-8") as stream:
    data = json.load(stream)
data["published_at"] = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat()
data["content_version"] = version
data["platform"] = platform
data["architecture"] = architecture
data["patch"] = {
    "platform": platform,
    "architecture": architecture,
    "url": patch_url,
    "size": int(patch_size),
    "sha256": patch_sha,
}
data["notes"] = notes
with open(target, "w", encoding="utf-8", newline="\n") as stream:
    json.dump(data, stream, ensure_ascii=False, indent=2)
    stream.write("\n")
PY
	update_sign_manifest "$WORK/$platform/manifest.json" "$WORK/$platform/manifest.sig"
	printf '%-8s %-34s %12s %s\n' "$platform" "$patch_name" "$patch_size" "$patch_sha"
done

echo "== 服务器不可变路径预检 =="
for platform in $PLATFORMS; do
	manifest="$WORK/base-manifest-$platform/manifest.json"
	base_version="$(update_manifest_value "$manifest" patch_base.version)"
	patch_name="patch-$base_version-to-$VERSION.pck"
	ssh -i "$SSH_KEY" "$REMOTE" "set -e; \
test ! -e '$UPDATE_REMOTE_WEB_ROOT/$platform/releases/$patch_name'; \
test ! -e '$UPDATE_REMOTE_WEB_ROOT/$platform/releases/manifest-$VERSION.json'; \
test ! -e '$UPDATE_REMOTE_WEB_ROOT/$platform/releases/manifest-$VERSION.sig'"
done

REMOTE_TMP="/tmp/liangshan-hot-$VERSION-$$"
ssh -i "$SSH_KEY" "$REMOTE" "install -d -m 700 '$REMOTE_TMP'"
for platform in $PLATFORMS; do
	manifest="$WORK/base-manifest-$platform/manifest.json"
	base_version="$(update_manifest_value "$manifest" patch_base.version)"
	patch_name="patch-$base_version-to-$VERSION.pck"
	patch="$UPDATE_OUT/$platform/$patch_name"
	scp -i "$SSH_KEY" "$patch" "$REMOTE:$REMOTE_TMP/$patch_name"
	scp -i "$SSH_KEY" "$WORK/$platform/manifest.json" "$REMOTE:$REMOTE_TMP/manifest-$platform.json"
	scp -i "$SSH_KEY" "$WORK/$platform/manifest.sig" "$REMOTE:$REMOTE_TMP/manifest-$platform.sig"
	patch_sha="$(update_sha256 "$patch")"
	manifest_sha="$(update_sha256 "$WORK/$platform/manifest.json")"
	signature_sha="$(update_sha256 "$WORK/$platform/manifest.sig")"
	ssh -i "$SSH_KEY" "$REMOTE" "set -e; \
echo '$patch_sha  $REMOTE_TMP/$patch_name' | sha256sum -c -; \
echo '$manifest_sha  $REMOTE_TMP/manifest-$platform.json' | sha256sum -c -; \
echo '$signature_sha  $REMOTE_TMP/manifest-$platform.sig' | sha256sum -c -"
done
ssh -i "$SSH_KEY" "$REMOTE" "set -e; \
for platform in $PLATFORMS; do \
  base_version=\$(python3 -c \"import json; print(json.load(open('$REMOTE_TMP/manifest-'\"\$platform\"'.json'))['patch_base']['version'])\"); \
  patch_name='patch-'\"\$base_version\"'-to-$VERSION.pck'; \
  install -m 644 '$REMOTE_TMP/'\"\$patch_name\" '$UPDATE_REMOTE_WEB_ROOT/'\"\$platform\"'/releases/'\"\$patch_name\"; \
  install -m 644 '$REMOTE_TMP/manifest-'\"\$platform\"'.json' '$UPDATE_REMOTE_WEB_ROOT/'\"\$platform\"'/releases/manifest-$VERSION.json'; \
  install -m 644 '$REMOTE_TMP/manifest-'\"\$platform\"'.sig' '$UPDATE_REMOTE_WEB_ROOT/'\"\$platform\"'/releases/manifest-$VERSION.sig'; \
done; \
rm -rf '$REMOTE_TMP'"

echo "== 公网回读三端版本化文件，验签、验大小、验 SHA-256 =="
for platform in $PLATFORMS; do
	manifest="$WORK/base-manifest-$platform/manifest.json"
	base_version="$(update_manifest_value "$manifest" patch_base.version)"
	patch_name="patch-$base_version-to-$VERSION.pck"
	patch="$UPDATE_OUT/$platform/$patch_name"
	url="$UPDATE_PUBLIC_ROOT/$platform/releases"
	update_download_and_verify "$url/$patch_name" "$WORK/$platform/public-$patch_name" \
		"$(update_size "$patch")" "$(update_sha256 "$patch")"
	curl --noproxy '*' --fail --silent --show-error "$url/manifest-$VERSION.json" -o "$WORK/$platform/public-manifest.json"
	curl --noproxy '*' --fail --silent --show-error "$url/manifest-$VERSION.sig" -o "$WORK/$platform/public-manifest.sig"
	cmp -s "$WORK/$platform/manifest.json" "$WORK/$platform/public-manifest.json" || \
		update_die "$platform 公网清单内容不一致"
	update_verify_manifest "$WORK/$platform/public-manifest.json" "$WORK/$platform/public-manifest.sig"
done

echo "== 三端一起提升 stable =="
update_promote_all_stable "$VERSION"

for platform in $PLATFORMS; do
	dir="$WORK/promoted-$platform"
	update_fetch_stable "$platform" "$dir" || update_die "$platform stable 公网回读失败"
	cmp -s "$WORK/$platform/manifest.json" "$dir/manifest.json" || update_die "$platform stable 未指向 v$VERSION"
done

echo "三端累计内容补丁 v$VERSION 已发布。"
echo "版本化文件不可覆盖；若发布后发现问题，请修复后使用更高三段版本。"
