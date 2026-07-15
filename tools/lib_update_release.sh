#!/bin/bash
# 三端内容更新发布脚本的公共函数。只供 tools/ 下脚本 source。

update_die() {
	echo "错误：$*" >&2
	exit 1
}

update_require_file() {
	[ -f "$1" ] || update_die "缺少文件：$1"
}

update_require_executable() {
	[ -x "$1" ] || update_die "缺少可执行文件：$1"
}

update_sha256() {
	shasum -a 256 "$1" | awk '{print $1}'
}

update_size() {
	if stat -f '%z' "$1" >/dev/null 2>&1; then
		stat -f '%z' "$1"
	else
		stat -c '%s' "$1"
	fi
}

update_require_full_version() {
	[[ "$1" =~ ^[0-9]+\.[0-9]+$ ]] || update_die "完整包版本必须是两段式（例如 1.6）：$1"
}

update_require_patch_version() {
	[[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || update_die "内容补丁版本必须是三段式（例如 1.6.1）：$1"
}

update_version_gt() {
	python3 - "$1" "$2" <<'PY'
import sys

def parts(value):
    values = [int(item) for item in value.split(".")] if value else [0]
    return tuple(values + [0] * (3 - len(values)))

raise SystemExit(0 if parts(sys.argv[1]) > parts(sys.argv[2]) else 1)
PY
}

update_same_release_line() {
	python3 - "$1" "$2" <<'PY'
import sys
a = [int(item) for item in sys.argv[1].split(".")]
b = [int(item) for item in sys.argv[2].split(".")]
raise SystemExit(0 if a[:2] == b[:2] else 1)
PY
}

update_platform_preset() {
	case "$1" in
		android) echo "Android" ;;
		windows) echo "Windows Desktop" ;;
		macos) echo "macOS" ;;
		*) update_die "未知平台：$1" ;;
	esac
}

update_platform_extension() {
	case "$1" in
		android) echo "apk" ;;
		windows) echo "exe" ;;
		macos) echo "dmg" ;;
		*) update_die "未知平台：$1" ;;
	esac
}

update_platform_kind() {
	case "$1" in
		android) echo "apk" ;;
		windows) echo "windows_exe" ;;
		macos) echo "macos_dmg" ;;
		*) update_die "未知平台：$1" ;;
	esac
}

update_platform_architecture() {
	case "$1" in
		android) echo "arm64" ;;
		windows) echo "x86_64" ;;
		macos) echo "arm64" ;;
		*) update_die "未知平台：$1" ;;
	esac
}

update_artifact_name() {
	local extension
	extension="$(update_platform_extension "$1")"
	echo "LiangshanHeroes-v$2.$extension"
}

update_github_artifact_url() {
	local name
	name="$(update_artifact_name "$1" "$2")"
	echo "https://github.com/${UPDATE_GITHUB_REPO}/releases/download/v$2/$name"
}

update_sign_manifest() {
	local manifest="$1"
	local signature="$2"
	local binary="${signature}.bin"
	openssl dgst -sha256 -sign "$UPDATE_PRIVATE_KEY" -out "$binary" "$manifest"
	openssl base64 -A -in "$binary" -out "$signature"
	openssl dgst -sha256 -verify "$UPDATE_PUBLIC_KEY" -signature "$binary" "$manifest" >/dev/null
}

update_verify_manifest() {
	local manifest="$1"
	local signature="$2"
	local binary="${signature}.verified.bin"
	openssl base64 -d -A -in "$signature" -out "$binary"
	openssl dgst -sha256 -verify "$UPDATE_PUBLIC_KEY" -signature "$binary" "$manifest" >/dev/null
}

update_manifest_value() {
	local path="$1"
	local dotted="$2"
	python3 - "$path" "$dotted" <<'PY'
import json, sys
value = json.load(open(sys.argv[1], encoding="utf-8"))
for key in sys.argv[2].split("."):
    value = value.get(key) if isinstance(value, dict) else None
if value is None:
    print("")
elif isinstance(value, (dict, list)):
    print(json.dumps(value, ensure_ascii=False, separators=(",", ":")))
else:
    print(value)
PY
}

update_download_and_verify() {
	local url="$1"
	local output="$2"
	local expected_size="$3"
	local expected_sha="$4"
	curl --noproxy '*' --fail --silent --show-error --location "$url" -o "$output"
	[ "$(update_size "$output")" = "$expected_size" ] || update_die "公网文件大小不一致：$url"
	[ "$(update_sha256 "$output")" = "$expected_sha" ] || update_die "公网文件 SHA-256 不一致：$url"
}

update_verify_git_release_point() {
	local version="$1"
	if [ "${LIANGSHAN_SKIP_GIT_GUARD:-0}" = "1" ]; then
		return
	fi
	local dirty
	dirty="$(git status --porcelain --untracked-files=all)"
	[ -z "$dirty" ] || {
		echo "$dirty" >&2
		update_die "工作区包含未提交或未跟踪文件；export_filter=all_resources，拒绝从非确定源码发布"
	}
	local head tag_head
	head="$(git rev-parse HEAD)"
	tag_head="$(git rev-parse "v${version}^{commit}" 2>/dev/null || true)"
	[ -n "$tag_head" ] || update_die "缺少标签 v$version"
	[ "$head" = "$tag_head" ] || update_die "HEAD 不是标签 v$version 指向的提交"
}

update_verify_build_source() {
	local proof="$1"
	local root="$2"
	local version="$3"
	update_require_file "$proof"
	python3 - "$proof" "$root" "$version" "$(git rev-parse HEAD)" <<'PY'
import hashlib, json, os, sys

proof_path, root, version, commit = sys.argv[1:]
with open(proof_path, encoding="utf-8") as stream:
    proof = json.load(stream)
if proof.get("schema") != 1 or proof.get("version") != version or proof.get("git_commit") != commit:
    raise SystemExit("构建来源证明的版本或提交与当前 tag 不一致")
expected = {"android": "apk", "windows": "exe", "macos": "dmg"}
for platform, extension in expected.items():
    entries = proof.get("platforms", {}).get(platform, {})
    for kind, relative in (
        ("package", f"build/LiangshanHeroes-v{version}.{extension}"),
        ("base", f"build/updates/{platform}/base-{version}.pck"),
    ):
        recorded = entries.get(kind, {})
        if recorded.get("path") != relative:
            raise SystemExit(f"{platform} {kind} 构建路径证明不一致")
        path = os.path.join(root, relative)
        if not os.path.isfile(path):
            raise SystemExit(f"缺少构建产物：{path}")
        digest = hashlib.sha256()
        with open(path, "rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        if recorded.get("size") != os.path.getsize(path) or recorded.get("sha256") != digest.hexdigest():
            raise SystemExit(f"{platform} {kind} 与构建来源证明的大小或 SHA-256 不一致")
print("构建来源证明验证通过")
PY
}

update_require_hot_update_safe() {
	local base_version="$1"
	local changed protected=""
	changed="$(git diff --name-only --diff-filter=ACMRTUXB "v${base_version}..HEAD")"
	while IFS= read -r path; do
		[ -n "$path" ] || continue
		case "$path" in
			project.godot|export_presets.cfg|scripts/android_updater.gd|scripts/campaign.gd|\
			android/*|ios/*|macos/*|windows/*|*.gdextension|*.dll|*.dylib|*.so|*.framework/*)
				protected+="$path"$'\n'
				;;
		esac
	done <<< "$changed"
	if [ -n "$protected" ]; then
		echo "$protected" >&2
		update_die "小版本包含必须随完整包发布的引导/工程/原生文件；请改发下一个两段式版本"
	fi
}

update_promote_all_stable() {
	local version="$1"
	# 一个远端进程先读取全部三端源文件并备份旧 stable，再替换；任何异常都会恢复三端旧值。
	ssh -i "$SSH_KEY" "$REMOTE" python3 - "$UPDATE_REMOTE_WEB_ROOT" "$version" android windows macos <<'PY'
import os, pathlib, sys

root = pathlib.Path(sys.argv[1])
version = sys.argv[2]
platforms = sys.argv[3:]
names = ("manifest.sig", "manifest.json")  # 先签名、后 JSON，兼容旧 Android 客户端。
sources = {}
backups = {}
staged = []

for platform in platforms:
    release = root / platform / "releases"
    stable = root / platform / "stable"
    stable.mkdir(parents=True, exist_ok=True)
    for name in names:
        suffix = ".sig" if name.endswith(".sig") else ".json"
        source = release / f"manifest-{version}{suffix}"
        if not source.is_file():
            raise SystemExit(f"missing immutable release file: {source}")
        sources[(platform, name)] = source.read_bytes()
        target = stable / name
        backups[(platform, name)] = target.read_bytes() if target.is_file() else None

try:
    for platform in platforms:
        stable = root / platform / "stable"
        for name in names:
            temp = stable / f".{name}.next-{version}"
            with temp.open("wb") as stream:
                stream.write(sources[(platform, name)])
                stream.flush()
                os.fsync(stream.fileno())
            os.chmod(temp, 0o644)
            staged.append(temp)
    for platform in platforms:
        stable = root / platform / "stable"
        for name in names:
            os.replace(stable / f".{name}.next-{version}", stable / name)
except BaseException:
    for platform in platforms:
        stable = root / platform / "stable"
        for name in names:
            target = stable / name
            old = backups[(platform, name)]
            if old is None:
                target.unlink(missing_ok=True)
            else:
                temp = stable / f".{name}.rollback-{version}"
                temp.write_bytes(old)
                os.chmod(temp, 0o644)
                os.replace(temp, target)
    raise
finally:
    for path in staged:
        path.unlink(missing_ok=True)
PY
}

update_fetch_stable() {
	local platform="$1"
	local output_dir="$2"
	local manifest_url="${UPDATE_PUBLIC_ROOT}/${platform}/stable/manifest.json"
	local signature_url="${UPDATE_PUBLIC_ROOT}/${platform}/stable/manifest.sig"
	local status
	mkdir -p "$output_dir"
	if ! status="$(curl --noproxy '*' --silent --show-error --output "$output_dir/manifest.json" \
		--write-out '%{http_code}' "$manifest_url")"; then
		update_die "无法读取 $platform stable 清单：$manifest_url"
	fi
	if [ "$status" = "404" ]; then
		rm -f "$output_dir/manifest.json" "$output_dir/manifest.sig"
		return 1
	fi
	[[ "$status" =~ ^2[0-9][0-9]$ ]] || update_die "$platform stable 清单返回 HTTP $status"
	curl --noproxy '*' --fail --silent --show-error "$signature_url" -o "$output_dir/manifest.sig"
	update_verify_manifest "$output_dir/manifest.json" "$output_dir/manifest.sig" || \
		update_die "$platform stable 清单签名无效"
}
