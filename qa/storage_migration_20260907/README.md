# 2026-09-07 本机存储迁移

用户要求为水浒项目在 D 盘建立位置，减少 C 盘占用。本轮把当前 Git 工程与历史资料集中到 `D:\AI项目\水浒`，不修改游戏源码和生产素材。

| 用途 | 实际位置 |
| --- | --- |
| 当前开发工程 | `D:\AI项目\水浒\开发工程`，根部 `project.godot` / `Play.cmd` |
| 历史资料 | `D:\AI项目\水浒\历史资料`，完整保留原 C 外层内容 |
| 用户入口 | `D:\AI项目\水浒\README.md` / `开始游戏.cmd` |
| 旧 D 临时路径 | `D:\CodexTemp\liangshan-github-sync-20260905-5f8a7c2e`，junction 到当前开发工程 |
| 旧 C 根 | 保留普通目录和少量交接文件；8 个子目录各为指向历史资料同名目录的 junction |

## 文件与空间验证

- 历史资料：17,241 文件、1,265 子目录（含空目录）、6,158,831,649 字节，Robocopy 完整复制；逐文件 SHA-256 零差异。切换前再次核对两边文件数量、大小和修改时间，确认校验后没有新变更。
- 当前工程：同一 NTFS 卷内移动 29,115 文件、6,468,859,714 字节，逐文件路径/大小/修改时间一致；移动前后 Git 均干净，HEAD 为 `100822d4d818bc739736d131270fe246c4f17b5f`，分支为 `codex/sync-20260905-stable`。
- 核验旧路径可读取后，仅删除 C 中已验证的目录副本：17,232 文件、6,158,623,779 字节，约 **5.74 GiB**。C 根最初保留 9 文件、207,870 字节，追加交接说明后为 213,073 字节；素材和旧工程均实际位于 D。
- 磁盘快照 C 可用空间从 47,704,662,016 字节变为 53,972,746,240 字节。整盘空间也受其他运行程序影响，释放项目数据量以上一条的精确字节数为准。

完整 SHA-256 文件清单保存在本机 `D:\CodexTemp\watermargin-migration-20260907-fd8d\history_file_manifest.json`，清单自身 SHA-256 见 [closeout_evidence.json](closeout_evidence.json)。本 QA 保存摘要、路径映射和运行收据，不上传整份历史内容或缓存。

## 兼容处理与实际失败

当前 Codex 会话占用 C 根，整目录改名报 sharing violation。曾尝试保留根目录、清空后原地创建 junction，仍被工作目录句柄阻止；原内容已恢复。最终保留 C 根，仅为其 8 个子目录建立 junction，全部回读正确，再删除受约束备份路径中的已验证副本。没有关闭 Codex 或其他项目进程。

历史来源 JSON 的旧绝对路径未批量改写。现有任务仍可从旧路径读取资料；后续开发、导入、构建直接使用新 D 实路径。隔离构建 profile 必须是实际目录，不能把旧 junction 当 profile 根。Godot 引擎、真实玩家目录、Steam 安装与凭据均不在本轮迁移范围。

## 运行验证与边界

Godot `4.6.3.stable.official.7d41c59c4`，隔离 profile 为 `D:\WMQA\migrate_fd8d`，设置 `STEAM_DISABLED=1` 与 `CAMPAIGN_QA=1`：

- 新实际路径运行资源导入：退出 0。
- 新实际路径运行默认入口 `--headless --quit-after 180`：退出 0，日志 ERROR / SCRIPT ERROR / Parse Error 为 0。
- 顶层 `开始游戏.cmd -Mode import`：退出 0。启动器首版 UTF-8/LF 在 cmd 下解析失败，改为 CRLF 后重验通过；该修改只涉及新建的本机入口。

本次验证证明迁移后的路径、导入和默认无头启动可用，不包含画面验收、真人通关、长局稳定性或 Steam 发布。

## 收据和同步范围

- [copy_verified.json](copy_verified.json)：删除 C 副本之前的全量复制校验快照，其中 `SourceRemoved=false` 为当时状态。
- [history_move_verified.json](history_move_verified.json)：最终 8 个 junction 与已删除 C 副本的收据。
- [active_move_verified.json](active_move_verified.json)：当前 Git 工程同卷迁移及旧 D 入口验证。
- [smoke_verified.json](smoke_verified.json)、[import.log](import.log)、[startup.log](startup.log)：隔离启动证据。
- `outer_handoff/`：本轮更新的 C 根 AGENTS、WORKLOG、SOURCE_SETUP、DIRECTORY_INDEX、README 精确副本；前四份与 D 历史资料根同步一致。
- `desktop_entrypoints/`：新 D 顶层 README 和启动器的交接副本，原文件位于仓库上层。

提交范围仅为本 QA、当前工程 README 与三份 docs 交接文件；Git 分支保持 stable，不合并 main，不操作 Steam 发布。
