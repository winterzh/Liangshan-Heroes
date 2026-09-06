# 独立私有项目磁盘 QA

root 已完成当前目录 49 个磁盘案例；当前被测 `run_save_store.gd` raw SHA 为 `86619f5cbf87e984ed253d66dddf2b852c8e11fe5e34d256c5a463bef16abca3`，runner raw SHA 为 `233dcd47bfe99af5419c38a2a135060860dbf46719683521c8e5610776b73fd2`。QA 不替换被测正文或添加生产接缝：`qa_faults.gd` 继承该原稿，正常分支调用 super；`qa_driver.gd` 调用真实 `read_slot/save_payload`，核对实际文件、内容和返回状态。这里的通过只代表磁盘夹具，不开放继续/保存按钮。

已核实旧稿 `a812ee51` 的 roundtrip [22 项通过](runs/20260906T105022891023Z/receipt.json)。首轮 corrupt 因 QA 对空文件计算摘要产生 ERROR 而未完成；修正 QA 后，单独 empty_payload 又复现原稿 `_digest(empty)` 的两条引擎 ERROR。root 已完成仅跳过零字节 `update` 的原稿修复和 runner PIN 更新，见 [修复收据](empty_digest_fix/receipt.json)；不将旧稿通过结果转记为修复版全绿。完整失败路径和五次当前来源运行见 [README 验证记录](README.md#验证记录与剩余-qa)。[当前汇总](current_qa_summary.json) 的 49 案例、54 次子进程和 1,233 次断言已经原始报告与实际文件复核：50 次正常退出报告贡献全部 1,233 次断言，4 次 checkpoint 终止不作为普通 exit=0 或普通报告通过；它们仅在终止证据与新 reader 验证共同成立时计为中断案例完成。断言含重复来源和准备检查，不是独立功能数量。

## root 的执行顺序

默认只检查原稿摘要与列出案例，不创建副本；`--prepare` 只创建很小的私有项目供审阅，也不启动 Godot。后续 `--run` 会另建一份来源相同的新运行目录，避免重用带残留的夹具。

**当前必须通过 `--godot` 显式传入真实引擎 `.exe`，不能传 `_console.exe` 包装器。** 本机已观察到 console 包装器另派生 Godot 进程，导致 `Popen.pid` 与报告中的 `OS.get_process_id()` 不同，也无法仅凭包装器退出确认实际引擎退出。以下 `$godot` 指已核实存在、版本相同的非 console 引擎程序；不要直接沿用指向 console 包装器的本机忽略配置。当前冻结 runner 不自动解析或替换该路径，执行者须先确认实际引擎参数；源码摘要与进程 PID 检查保持严格。

```powershell
python -X utf8 scratchpad/run_save_store/run_qa.py --suite all
python -X utf8 scratchpad/run_save_store/run_qa.py --prepare --case roundtrip

# 先取得 Godot 独占时段；$godot 必须指向已核实的真实引擎，见上方要求。
python -X utf8 scratchpad/run_save_store/run_qa.py --run --case roundtrip --godot $godot
python -X utf8 scratchpad/run_save_store/run_qa.py --run --case unknown_schema bad_sha truncated file_utf8 semantic_file --godot $godot
python -X utf8 scratchpad/run_save_store/run_qa.py --run --suite io --godot $godot
python -X utf8 scratchpad/run_save_store/run_qa.py --run --suite restart --godot $godot
python -X utf8 scratchpad/run_save_store/run_qa.py --run --suite interrupt --godot $godot
```

逐项可用 `--case <名称>`；分组为 `smoke/corrupt/input/io/restart/interrupt/all`。目前 49 案例：44 个单进程案例、1 个正常重启、4 个中断重启；全组 54 次子进程，其中 4 次只在确认正确检查点后由启动器主动终止。**不要把这 4 个非正常退出当作普通 exit=0；只有检查点证据、准确退出确认、后续新进程断言均通过，对应中断案例才通过。** 无须为了做一次入口验证先跑全组。

默认每个子进程超时 90 秒，可用 `--timeout 15..240`。检查点等待最多 45 秒；若 root 的 Python 没及时收到合法检查点并终止准确子进程，案例失败，不能冒充重启通过。旧稿已在 roundtrip 实际编译并执行；每次修复后仍须新建运行目录、核对当次源码，保留任何编译/运行失败日志。

## 副本、进程与输出范围

`runs/<UTC>/project/` 只含三份逐字节 GD、一个没有 Autoload 的 `project.godot` 及随后生成的极小夹具/引擎缓存。不会复制原工程、资源、Git、导出物或玩家内容。原稿要求的 `res://scratchpad/run_save_store/fixtures/<case>` 在私有项目内保持相同相对布局。私有项目不加载 Battle、Art、Music、Campaign、Settings，也不先启动原游戏再换路径。

每个子进程的 APPDATA/LOCALAPPDATA/TEMP/TMP 都指向本次 `private_profile/`；驱动核对实际 `user://` 路径与 manifest 相同，并断言场景树没有 Autoload/生产场景。没有读取、备份或恢复真实玩家目录的代码。私有目录只保留，不自动清空。

启动器共用根工程 `.godot/redraw_rejection_source.lock`，每次启动前后检查 Godot 独占。超时/KeyboardInterrupt 只 kill 自己持有的 Popen handle，并等待真实退出；无法确认退出、来源变化、锁所有者变化时保留锁和收据。没有按进程名字全杀或自动恢复源文件。只有显式 `--run` 才可能启动引擎，`--prepare` 不查杀进程。

运行前后检查作者源与私有源的精确 SHA。每阶段单独 manifest、原始日志和 process receipt；正常报告必须匹配 run/case/phase/PID/manifest SHA，非空全部断言通过、exit=0，日志无 SCRIPT ERROR/ERROR/WARNING/FAIL。Python 还独立读取磁盘字节，对照 GD 的文件摘要；预期 A/B 的文件另用 Python JSON/SHA 检查字节数、摘要及明确 payload 值。不会只读 `passed=true`。

主要产物：

- `preparation.json`：原稿和两个 QA、runner 的摘要、私有项目精确来源。
- `reports/<case>_<phase>.json/.log`、`*_process.json`、`*_manifest.json`：原始阶段证据。
- `reports/interrupt_<point>_checkpoint.json`：被中断进程的 PID、阶段、检查点、当前文件摘要与参照摘要。
- `receipt.json`：只有所有所选案例完成并释放共同锁，启动器才返回 0。失败尝试同样保留。

**不整包提交 runs**：这里含私有 fixture/profile/project/cache。若将来归档，只挑报告/日志/源码摘要，源码已在此草稿目录；残留文件的内容仅是明确小假 payload，但仍不是生产资源。

## 独立 oracle 与故障层次

A 输入包含中文、换行与最大有符号 64 位整数字符串；B 是另一份明确小 payload。夹具 validator 检查全部固定字段/类型/值和 revision-marker 关系，仅用于证明完整 Callable 确实被执行，不能宣称生产 Battle schema 已完整。

每个单进程案例先用**原稿本身**写入并回读精确 A；另在独立 oracle 目录写入并回读精确 B，取得期望封装原字节。不是在测试里复制封装实现生成“正确答案”。成功案例还明确比较原输入的完整 payload 字节，避免一个总写 A 的错误实现同时污染 B oracle。损坏案例只修改原稿已经产生的真实文件；以修改后的文件原字节作为拒读/拒写后的保留断言。

| 范围 | 案例 | 原生路径与预期 |
| --- | --- | --- |
| 正常写读 | roundtrip、restart | 原稿新写 A/覆写 B/完整回读；正常重启是 writer 退出后另一个 Popen 只读 A，不能用同对象当重启 |
| 不支持/损坏旧槽 | unknown_schema、unknown_format、bad_magic、bad_sha、bad_length、empty_file、empty_payload、truncated、file_utf8、envelope_shape/fields/types、semantic_file、slot_directory | 真实文件/目录输入，经原解析、摘要和 Callable；读返回明确错误，写返回 EXISTING_SLOT_REJECTED，同一原档/原目录完整保留。empty_payload 保持合法六字段封装、payload 为空字符串、bytes 为 "0"、SHA 为标准空字节摘要，预期 PAYLOAD_SIZE 且无引擎错误 |
| 无效新输入 | input_empty/oversize/utf8/semantic、validator_missing/contract | 原槽 A 完全不变，不产生 pending/previous/锁；无效 validator 不默认放行 |
| 锁与临时文件 | lock_race、pending_race | 子类只制造实际冲突，原来的 mkdir/open 前检查返回错误；不偷锁、不覆盖外部 pending |
| 临时 I/O 返回失败 | write_open、write_short、temp_read_open/incomplete、new_write_open | 窄接缝返回指定 I/O 错误，write_short 真实写出半份并关闭；检查原稿调用方保留旧档/残留。首次无旧档的布尔状态不得报成“旧档已恢复” |
| 临时回读失败 | temp_truncated/digest/semantic/whitespace | 实际关闭文件后改字节，执行原完整回读校验；分别得到 JSON/摘要/语义/精确封装字节错误；旧档 A 原位 |
| 旧槽/备份冲突 | slot_changed、backup_move、backup_read | 实际原槽变化不覆盖；备份 move/read 接缝拒绝时分别保留 A 在原位或 previous，不虚报已恢复 |
| 替换与回滚 | replace_rollback、replace_no_rollback、rollback_read、replace_external | 替换拒绝后原稿真实 previous→空槽回滚；再验证回滚移动/验证失败，以及实际外部目标挡住替换时不覆盖该文件 |
| 最终回读/清理 | final_read/corrupt、backup_changed、cleanup_previous、cleanup_lock | 最终回读失败状态 unknown；外部备份变化不删除；真实 Windows read-only 备份令原 delete 失败；真实非空锁令原 rmdir 失败，状态 new_verified 且不伪报完整事务成功 |
| 四个中断点 | interrupt_temp_closed/backup_moved/committed/backup_removed | 真实 I/O 已完成、准确子进程在检查点被外部终止；新进程见残留只返回 RECOVERY_REQUIRED，读取/重试后字节不变 |

`write_open/write_short/temp_read_open/temp_read_incomplete/backup_move/backup_read/replace_*/rollback_read/final_read` 中的指定返回错误属于**边界故障注入**，主要验证原事务对该类 I/O 失败的处理；不是证明 Godot 内部 `FileAccess.get_error` 在真实磁盘耗尽时怎样变化。未修改正常读写实现，也没有用整套文件系统 mock 替代磁盘。真实 FileAccess 截断、关闭后重开、摘要/语义拒绝、Windows 属性拒绝删除、目录非空删除失败与 actual rename/rollback 都另有实际文件证据。

这覆盖每个事务磁盘阶段的失败处理，但不声称枚举所有 OS 错误码或证明磁盘满、权限 ACL、网络断连、坏扇区、掉电、fsync、恶意进程竞争的全部平台行为。对照中 Windows read-only 设置若失败，会记录 injection_errors 并使案例失败，不能降级到假返回后仍称原生验证。`input_oversize` 分配约 16 MiB 内存，不填满磁盘。

## 恢复策略说明

**没有增加自动恢复策略。** 唯一会自行回滚的是旧稿 `a812ee51` 已有、当前 `86619f5c` 未改动的同次保存失败路径：目标为空、previous 完整且原摘要相同，才将 previous 移回空槽并再次验证。`replace_rollback` 已在 [当前 io 运行](runs/20260906T110042779296Z/receipt.json) 通过，原 A 确认回到正式路径；`replace_no_rollback` / `rollback_read` 则明确未确认回滚，实际 A 留在 previous。它们都不是新进程启动后的自动恢复。

重启后的残留一律只报告 RECOVERY_REQUIRED。四个中断点分别要求：

| 检查点 | slot | pending | previous | lock |
| --- | --- | --- | --- | --- |
| 临时关闭后 | A | B | 无 | 有 |
| 旧档移到备份后 | 无 | B | A | 有 |
| 新档已移入后 | B | 无 | A | 有 |
| 已验证新档并清掉旧备份后 | B | 无 | 无 | 有 |

保留至少一份完整 A 或 B，不要求最后一个阶段仍保留已正常清理的旧 A。新进程读/再保存不能删残留、猜最新文件或悄悄开放续玩。未来若要设计自动恢复，须另行列出每种中断状态、归属证明、业务完整验证及覆盖未知文件的边界，由 root 先评审。
