# 局部恢复原始证据

`archive_manifest.json` 按实际原始字节列出日志、报告、冻结输入和来源位置；`summary.json` 将源码摘要断言与其他断言分开。`production_promotion.json` 单独记录 ROOT 接入后的实际文件摘要。历史失败从未改写。

`packages/*/overlay_sources/` 保留 manifest 引用的实际候选字节，manifest 原始绝对/相对位置是历史身份信息；复现需要在新 scratchpad 中按新当前基线重新审核 before，并显式冻结新运行。不得直接覆盖共享生产或复用旧私有玩家目录。

`outbox_draft` 和 `clock_order` 是草稿；无磁盘 SDK 原子性或完整 Battle 屏障结论。本目录 `.gdignore` 防止开发工程自动导入证据脚本。缓存、完整工程副本和玩家数据不在同步范围。
