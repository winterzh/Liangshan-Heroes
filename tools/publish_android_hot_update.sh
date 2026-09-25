#!/bin/bash
# 兼容旧命令名；仅发布 Android 补丁，Windows/macOS 历史文件不动。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/tools/publish_hot_update.sh" "$@"
