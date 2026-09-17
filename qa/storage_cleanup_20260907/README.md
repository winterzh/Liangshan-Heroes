# 2026-09-07 项目冗余清理与历史归档

用户授权清理冗余、过期无用数据，或集中保存。盘点、引用审计和文件校验后，本轮删除明确可重建的重复缓存，把不再被当前工具直接读取的旧批次收入一个 7z 文件。

## 实际处理结果

| 类别 | 处理 | 字节数 |
| --- | --- | ---: |
| 三份重复导入缓存 | 与保留的主工程缓存逐文件 SHA-256 相同，删除副本 | 1,271,805,222 |
| 旧历史工程标准 `.godot` | 仅含导入、编辑器、导出缓存和 UID/marker，删除后可重建 | 393,808,261 |
| 9 组历史批次 | 4,161 文件、164 目录完整归档，校验后撤去展开文件 | 原 1,819,449,034 |
| 单一历史归档 | `D:\AI项目\水浒\归档\水浒_过期资料_20260907.7z` | 1,455,622,866 |
| 合计净减少 | 缓存删除 + 归档差额，未扣少量清单、说明和 QA 文档 | **2,029,439,651（约 1.89 GiB）** |

归档 SHA-256：`8844D3535BA29CE7315EB8709BF8D091F7D05F9C69E91B32245B6D70C17ABAB1`。归档完整性测试、全量解压后的 4,161 文件 SHA-256 和原文件稳定性核对均通过。完成后移除原展开数据，原目录保留 `已归档.md`；详情见 [archive_cleanup_verified.json](archive_cleanup_verified.json)。

归档范围为 2026-09-01 发布候选、环境 v8、视觉 v1—v6、`implementation_20260904` 改前备份。可在本机[归档说明](D:/AI项目/水浒/归档/README.md)查看和恢复；远端保存其准确交接副本 [archive_guide/README.md](archive_guide/README.md) 与 [archive_file_manifest.json](archive_file_manifest.json)。压缩包保留在本机，不上传历史安装包或整份备份。

## 保留与验证

当前源码、素材、主导入缓存、最新已上传 ZIP、冻结工程源码、原始 QA 收据保持原位。旧来源目录 `implementation_20260902/03`、campaign_rework 基线、旧工程素材/QA、视觉 v7 和原始 ZIP 继续直接可读。

选择保护的 **16,420 个文件、5,027,944,167 字节** 清理前后逐文件大小及 SHA-256 一致，文件集合没有新增或缺失；所有读取/扫描错误为 0。详见 [protected_after_verification.json](protected_after_verification.json)。完整清理前清单保存在该收据指明的本机审计路径，并由清单自身 SHA-256 固定。

新实际路径运行 Godot `4.6.3.stable.official.7d41c59c4`，使用 `D:\WMQA\cleanup_fd8d` 隔离用户目录，禁用 Steam：资源导入和默认入口 180 帧无头启动均退出 0，ERROR / SCRIPT ERROR / Parse Error 为 0。当前游戏启动方式不变；以后复用旧工程或冻结工程时，先导入资源即可重建被删除的缓存。该检查不替代画面验收、真人通关或长期性能测试。

## 未执行的清理

Git 只读审计发现 50 个孤立 `tmp_pack_*`，共 **529,907,662 字节（505.36 MiB）**，`git count-objects` 报为 garbage。但删除命令被自动审批返回 `blocked by policy`，没有给出更具体原因，命令未执行；这 50 个文件仍在，不计入已释放空间，也未换工具重试删除。

后续只读 `git fsck --full --no-dangling`（禁止 lazy fetch）退出 0。仓库为 `promisor/blob:none` 部分克隆，531 个按需缺失对象是此前审计状态；不宣称所有历史对象都已离线齐备，不执行 gc/prune 或重写历史。见 [git_temp_candidates.json](git_temp_candidates.json)、[git_temp_retained.json](git_temp_retained.json)。

## 收据与同步

- [cache_cleanup_verified.json](cache_cleanup_verified.json)：4 个精确删除根、11,626 个缓存文件、保留缓存与上传 ZIP。
- [archive_cleanup_verified.json](archive_cleanup_verified.json)、[archive_file_manifest.json](archive_file_manifest.json)：归档、文件清单与净减少量。
- [protected_after_verification.json](protected_after_verification.json)：保护文件逐字节复核摘要。
- [smoke_verified.json](smoke_verified.json)、[import.log](import.log)、[startup.log](startup.log)：本轮实际启动日志。
- `outer_handoff/`：本轮外层 AGENTS、WORKLOG、SOURCE_SETUP、DIRECTORY_INDEX、README 的精确交接副本。
- `archive_guide/`、`desktop_entrypoints/`：归档说明和新总入口文档的交接副本；运行文件位于当前仓库外层。

本轮仅提交这些 QA/说明、README、三份 docs 和 QA 字节保留属性；游戏代码、素材、Steam 发布状态不变。旧轮迁移文档和 QA 保留其当时的完整展开语境，当前存储状态以本轮记录为准。
