# 2026-10-27 收尾：重复缓存清理与文档归并

按用户“收个尾，清除冗余，同步github”处理。删除12个旧战役快照中 **52176 个重复导入文件 / 14949340024 字节（约13.92 GiB）**，无跳过；数字为移除文件逻辑大小，少量审计文档和Git新增空间另计。没有启动游戏、完整52／61测试或平台发布。

## 清理与保留

范围限于 `.godot/campaign_progress_recovery_20261026/` 下12个旧快照的 `project/.godot/imported`，逐文件位置见 `plan.json.gz`。每个目标均与最新b22中同名保留文件大小/SHA-256相同；只删单硬链接、未变化且可独占读取的文件，发生变化或占用就跳过。不递归删除整个快照。

恢复保留副本为 `.godot/campaign_progress_recovery_20261026/20261027_075456_3e4a48ab/project/.godot/imported`，4538个保留文件已再次核对SHA。它不在删除范围，后续清理前须维护此恢复链。12个旧快照中168个独有/差异缓存文件原位保留。

主缓存、最新b22完整工程、各旧快照源码和其余缓存、原图/来源、原始QA报告/日志/每行证据、私有存档、发行包及Git对象均保留。本轮不删除原始验证记录或复制玩家数据进Git。

## 文件保护核对

- 47391个已跟踪保护文件前后逐文件大小/SHA一致；这是写入本轮收尾文档之前的比较，文档后续修改另有记录。
- 旧战役快照中97543个非目标文件的路径/大小/mtime一致；这是元数据检查，不声称这些文件全部重算SHA。
- 所有实际删除项均缺失，流水与计划计数/字节一致；保留缓存SHA一致。12个旧快照各恢复一个真实二进制样本、读回SHA通过，样本副本核对后移除。
- 引擎空闲检查、路径/reparse检查、计划/keeper绑定、删除前大小/mtime/SHA和单硬链接检查均执行。未运行玩法或全量测试。

完整保护清单及执行中间件在本机 `.godot/closeout_cleanup_20261027/`，仓库保存恢复映射、实际删除流水、绑定及验证摘要；中间件路径/哈希见 `verification.json`。清理脚本原字节副本位于 `execution_sources/`，用于审计，不作为新的自动清理入口。

## 恢复缺失缓存

复验所列旧快照前先补齐本轮删除的缓存。默认命令只验证保留副本；加 `--restore` 才写入缺失文件。例如先恢复到新目录：

```powershell
C:\Python314\python.exe qa/storage_cleanup_20261027/restore_imports.py qa/storage_cleanup_20261027/plan.json.gz . D:/CodexTemp/shuihu-import-restore --prefix .godot/campaign_progress_recovery_20261026/20261027_063133_392242bc/project/.godot/imported/ --restore
```

省略 `--prefix` 可选择本批全部映射；把目标目录换为当前工程根目录可原位恢复。恢复器拒绝越界/reparse路径、变化的保留副本和已有不同文件，逐文件核最终SHA并恢复mtime。映射本身不含缓存载荷；必须保留上述b22缓存，或按绑定的Godot版本重新导入，不能把清单当作备份。

## 文档与开发交接

PROJECT_STATUS、DEVELOPMENT_PLAN、SOURCE_SETUP和DIRECTORY_INDEX归并重复、过期的“正在执行”记录，完整开发/验收表继续保留；详细阶段历史集中到WORKLOG和对应QA。整理前全文保留在Git提交 `5837d1bdc769f2847888a074f41b5c3d629c5529`，`document_cleanup.json`记录旧Git内容及工作区行尾/前后哈希，可按原行尾恢复。

大名府全量测试仍按用户要求停止：27个进程39383项通过、1个取消、24个未执行；52／61整组未授予。后续按实际修改做必要的针对性测试。原版键鼠验收暂不恢复，当前候选未采用生产，公开战役继续未开放。

源码和本轮收据按白名单同步 `codex/sync-20260905-stable`；不合并main、不创建Release、不发布Steam。
