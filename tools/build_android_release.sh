#!/bin/bash
# Android-only complete release build. Does not upload, sign manifests or publish.
# Tool paths are supplied by the caller; existing canonical outputs are refused.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tools/update_release.env"

GODOT_BIN="${GODOT_PATH:-${GODOT:-}}"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
JDK="${JAVA_HOME:-}"
TEMPLATE="${ANDROID_TEMPLATE:-}"
VERSION="$UPDATE_BASE_VERSION"
OUT=""
DELIVERY=""
EXPECTED_COMMIT=""

usage() {
	printf '%s\n' 'Usage: build_android_release.sh [VERSION] [--godot PATH] [--android-sdk PATH] [--java-home PATH] [--android-template PATH] [--out NEW_PATH] [--delivery-dir NEW_BUILD_PATH] [--expected-commit SHA]'
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--godot|--android-sdk|--java-home|--android-template|--out|--delivery-dir|--expected-commit)
			[ "$#" -ge 2 ] || { usage >&2; exit 2; }
			case "$1" in
				--godot) GODOT_BIN="$2" ;;
				--android-sdk) SDK="$2" ;;
				--java-home) JDK="$2" ;;
				--android-template) TEMPLATE="$2" ;;
				--out) OUT="$2" ;;
				--delivery-dir) DELIVERY="$2" ;;
				--expected-commit) EXPECTED_COMMIT="$2" ;;
			esac
			shift 2 ;;
		--help|-h) usage; exit 0 ;;
		--*) usage >&2; exit 2 ;;
		*) VERSION="$1"; shift ;;
	esac
done

[ -n "$GODOT_BIN" ] || { echo 'Set GODOT_PATH/GODOT or pass --godot.' >&2; exit 2; }
[ -n "$SDK" ] || { echo 'Set ANDROID_SDK_ROOT or pass --android-sdk.' >&2; exit 2; }
[ -n "$JDK" ] || { echo 'Set JAVA_HOME or pass --java-home.' >&2; exit 2; }
[ -n "$EXPECTED_COMMIT" ] || EXPECTED_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
if [ -z "$OUT" ]; then
	# mktemp owns the parent; the builder requires its child not to exist yet.
	PRIVATE_PARENT="$(mktemp -d "${TMPDIR:-/tmp}/lsh-android-release.XXXXXX")"
	OUT="$PRIVATE_PARENT/build"
fi
if [ -z "$DELIVERY" ]; then
	RUN_ID="$(python3 -c 'import uuid; print(uuid.uuid4().hex[:12])')"
	DELIVERY="$ROOT/build/android-release-$VERSION-$RUN_ID"
fi

ARGS=(--release --version "$VERSION" --godot "$GODOT_BIN" --android-sdk "$SDK"
	--java-home "$JDK" --out "$OUT" --delivery-dir "$DELIVERY" --expected-commit "$EXPECTED_COMMIT")
if [ -n "$TEMPLATE" ]; then ARGS+=(--android-template "$TEMPLATE"); fi
exec python3 -B "$ROOT/tools/build_android_test.py" "${ARGS[@]}"
