#!/bin/bash
# 兼容旧命令名；发布 Android/macOS 补丁，Windows 在线更新已停用。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/tools/publish_hot_update.sh" "$@"
