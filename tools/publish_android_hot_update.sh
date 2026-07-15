#!/bin/bash
# 兼容旧命令名。自 v1.6 起内容版本必须保持三端同步，因此该入口会发布全部三端补丁。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/tools/publish_hot_update.sh" "$@"
