# 2026-10-26 旧测试工程去重归档

54 个 10 月 15—17 日旧人物测试工程的非 `.godot` 文件已完整保存到内容去重 ZIP，再逐文件移除展开副本。共 **312,191 个文件 / 88,791,429,129 字节（82.69 GiB）**；其中不同字节内容仅 6,486 份。

归档 **1,751,101,502 字节（1.63 GiB）**，两者相减 **87,040,327,627 字节（81.06 GiB）**；另有少量本批审计清单/文档开销，不把并行任务的磁盘变化算作本次成果。实际系统空闲以收据中的 before/after 为准。

## 保存在哪里

- 本机归档：`D:\AI项目\水浒\归档\水浒_旧测试工程去重归档_20261026.zip`。
- ZIP SHA-256：`23afd4b2a6b7065b02f41e220255b8e7c68ff398058bac294b1468b832b36ac8`。
- ZIP 中 `manifest.json` 逐路径保存大小、SHA-256、时间与目录；`blobs/<SHA-256>` 保存完整原字节，同内容只存一次。不是普通原路径展开 ZIP，使用所附恢复工具还原。
- 仓库保留独立 `manifest.json.gz`、54 根索引、恢复工具、验证摘要和执行脚本；大归档只保留本机，不上传 Git。

## 保护边界与验证

- 当前源码/正式资源、全部未提交黄泥冈工作、`.godot/huangnigang_production_20261020`、全部 Steam 批、性能批、10 月 18 日特制工程、含 junction 的 recovered 工程均未列入目标。
- 每个旧工程自身的 `.godot` 完整原位保留；批次外的日志、截图、PCK、收据、私有存档和候选来源也保留。10 月 20 日缓存清理的 retained_copy 恢复链未变。
- 当前脚本/场景/资源中未发现这些旧 `project` 的运行引用。人物 runner 从当前根新建快照；旧 receipt/显式重放如需读历史工程，必须先恢复。参考 `tools/run_liu_tang_pudao_20261016.py:23`、`run_shi_en_packed_hud_20261015.py:28`、`run_shi_en_recovering_20261015.py:22`、`run_ruan_xiaoqi_merchant_nw_20261016.py:27`；当前黄泥冈 `run_batch.py:65,107-109` 仅用根源码和主导入缓存。
- 全部 6,486 个唯一内容解压读回 SHA/大小通过，manifest 读回一致；实际向新目录恢复一个完整旧工程 **5,181 文件**，每个文件 SHA 通过。恢复器另有 29 项边界检查通过。
- 删除清单从 ZIP manifest 生成，绑定 ZIP/manifest/计划 SHA；校验绝对路径、无 reparse、单硬链接、大小/mtime、独占打开与 SHA 后逐文件删除，不递归删除目录。串行PowerShell速度偏慢，核实并停止本次自建worker后保留原流水，改为同一PowerShell内.NET六路处理；串行已缺失 56,701、后续新删除 255,490，合计 312,191，跳过 0。只控制本次worker，没有结束其他应用。
- **267,159 个非目标文件**前后 SHA/大小一致，目标路径全部确认移除。文档写入前，原 Git HEAD、索引、19 个已跟踪修改及既有未跟踪清单和内容均未改变。
- 本轮没有启动游戏或进行玩法/原生SDK验收；哈希保护不等于功能测试。没有新 Steam 发布。

## 恢复一个旧工程

先恢复到新的检查目录，例如在开发工程根目录用 PowerShell 执行：

```powershell
python qa/storage_cleanup_20261026/restore_archive.py 'D:\AI项目\水浒\归档\水浒_旧测试工程去重归档_20261026.zip' 'D:/CodexTemp/shuihu-restore-check' --prefix '.godot/packed_world_art_20261015/20261015_045536_c1fcc980/project/'
```

工具先验证该批全部内容，再安全建立文件和目录，最后逐文件核 SHA。已有相同文件跳过，已有不同文件拒绝覆盖。其他批次从 `snapshot_index.json` 选择 prefix；省略 prefix 会恢复全部 54 个工程，需要约 82.7 GiB 可用空间。

需要按历史原路径运行时，把目的地换为本机开发工程根目录。先确认对应批次没有进行中的改动，工具只补缺失文件，不覆盖冲突。原位保留的缓存继续使用；历史上已清掉的导入缓存仍按原记录重新导入或恢复。

仅检查归档内容可加 `--verify-only`；它不会写入。旧批次的来源/身份/测试收据继续按当时语境阅读，恢复快照不授予新版本验收资格。

## 审计收据

本目录保存 `archive_verification.json`、`restore_actual_verification.json`、`removal_summary.json`、`verification_before_docs.json` 与 `remove_plan_binding.json`。逐文件保护前验及删除流水位于 `external_audit_evidence.json` 指向的本机审计目录，大小/SHA已登记；完整恢复只需 ZIP 与恢复工具。
