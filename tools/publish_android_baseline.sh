#!/bin/bash
# 兼容 Android 命令名；转入有版本/来源/不可变路径门禁的完整基线发布器。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/tools/publish_update_baseline.sh" "$@"
