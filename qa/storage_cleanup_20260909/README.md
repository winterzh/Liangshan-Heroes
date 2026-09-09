# 2026-09-09 冗余缓存清理与旧助手归档

用户授权清理和归档冗余文件。基线为 `cf746f1`，当前开发仍使用 `D:\AI项目\水浒\开发工程`。本轮保留所有 Git 跟踪文件、当前主导入缓存、全部 Steam 候选及关联 QA、各类最新成功测试批、旧批源码/资源/日志/测档、原始美术与验证证据、历史归档和 `.git`。

## 实际完成

| 范围 | 删除的缓存目录 | 文件 | 字节 |
| --- | ---: | ---: | ---: |
| 工程内旧隔离测试 `.godot/imported` | 110 | 332334 | 46385682145 |
| D盘旧测试批 `project/.godot/imported` | 51 | 122212 | 13404457715 |
| 合计 | **161** | **454546** | **59790139860（55.68 GiB）** |

每个待删缓存的文件名、大小和 SHA-256 都与保留主缓存匹配；规划时全量比对，删除前再次比对并检查完整文件集合、绝对路径范围、reparse、原始工程仍在、主缓存保护清单和共享引擎锁。只删除精确 `imported` 根，未删除旧 `project` 或整个 `.godot`。原 `.godot` 元数据和源码仍可直接读取；需要复查旧工程时先重新导入资源，或按对应 QA 驱动重新生成隔离工程。12类最新成功批次均保留完整。

前50根由原PowerShell逐文件校验器完成；随后主动在已有的删除前锁检查处停止（`in_progress_target=null`），改为等价的只读 C# 校验循环接续。全部路径、集合、大小、SHA校验及原生PowerShell `Remove-Item -LiteralPath` 保留，最终计数与计划完全一致。原阶段收据和主动切换记录保留；这次切换不是审批拒绝或放宽校验。编译校验器7个合成正反例通过，不计为游戏QA。

## 归档

`D:/AI项目/水浒/归档/水浒_旧准备与收尾助手_20260909.7z`：111724 字节，SHA-256 `a1a1ed8b7c5acb2b490924599a6747b727376a93aa6cf68c210ae741d713caca`。52个原始文件共545395字节，另附清单和说明；7-Zip完整性测试、完整解压和全部载荷SHA通过，原件稳定性复核后才移除。

- 31个旧祝家庄景物候选文件在正式 `qa/level3_scenery_prepare_20260909` 中仍有逐路径、逐字节相同副本。原临时目录留有 `已归档.md`。
- 21个未被当前源码、工具、文档或QA名称引用扫描命中的历史收尾助手已归档；其余被引用的55个助手保留。工程 `.godot` 根留有归档说明。

查看[归档说明副本](archive_guide/README.md)和[文件清单](archive_verified.json)。恢复时先解压到新目录，按 `archive_path` 和SHA核对，再按 `source` 放回所需原路径；不要覆盖后续修改，也不要把旧候选当当前正式实现。压缩包留本机，GitHub保存清单、恢复说明和验证收据。

## 保护与启动验证

清理和隔离启动后，**28040个受保护文件、4663619590字节**逐文件大小/SHA一致，缺失或变化0。范围包括全部16580个原Git文件、主imported、最新Steam25185242候选完整目录、本机Godot路径和总启动器。完整前清单为[protected_before.json.gz](protected_before.json.gz)，[后验结果](protected_after.json)记录其SHA；清理新增文档在后验完成后更新，不冒充原文件零修改。

Godot4.6.3在新D盘隔离profile中禁用Steam，使用保留主导入缓存运行当前默认菜单180帧无头启动，退出0，ERROR/SCRIPT ERROR/Parse Error 0。见[startup.log](startup.log)、[启动收据](smoke_receipt.json)。本轮没有强制重导入、视觉/真人/性能或完整战役验收。

自动审批仅拦截了删除本次 `archive_stage` 和 `archive_verify` 两份归档验证临时副本的命令，返回 `blocked by policy`，没有更具体原因；命令未执行，未换工具重试。这两份小型副本保留，不计入释放量，见[保留记录](retained_temporary_copies.json)。上表是实际移除的缓存逻辑字节，不是磁盘空闲增量；本轮审计元数据、少量标记和隔离启动文件另有占用。

## 收据与接续

- [清理计划](cache_plan.json)、[最终删除收据](cache_deletion_receipt.json)：161根精确路径与计数。
- [工程盘点](repo_audit.json)、[临时批盘点](temp_audit.json)：保留类别、快照与最新批匹配。
- [归档验证](archive_verified.json)、[原副本移除收据](archive_cleanup_receipt.json)：52个文件、归档SHA及实际操作。
- 完整每目录成员清单留在 `D:/CodexTemp/watermargin-cleanup-20260909/cache_manifests`，其各自SHA由本计划固定。
- `execution_sources/*.txt` 为一次性固定清理脚本的证据副本，不能直接用本轮旧白名单重复清理后续批次。

项目启动仍用 `Play.cmd`；功能源码和Steam线上包不变。本轮只同步清理说明与QA，开发继续从[当前续玩计划](../../docs/CONTINUE_DELIVERY_20260908.md)接续。
