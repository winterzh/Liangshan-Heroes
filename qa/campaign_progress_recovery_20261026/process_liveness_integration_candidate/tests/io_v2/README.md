# 23 脚本候选的 Store I/O 适配入口

此目录只新增外部 QA，不修改旧 I/O 宿主、故障脚本、20/23 文件候选或冻结工程。2026-10-27：同一 e97a 冻结已完成 23 进程／370 项真实文件故障专项，以及两种延迟写入交错共 4 进程／129 项检查。所有实际 PID、前后源码与引擎、原始 helper 结果、共享锁释放均通过独立回读。半 pending 的 ENVELOPE_JSON 仍是保留原件的安全拒绝；B 使用 Store+Receipt，不能据此声称双 Ledger 全并发或自动修复所有坏档。

[23 进程原始收据](../../../evidence/liveness_io_v2_20261027_003556/README.md)、[4 进程交错收据](../../../evidence/liveness_delayed_v2_20261027_010849/README.md)。provenance 保留创建时的 engine_started=false；执行结果以这两批终态原件为准。运行时 README 与全部输入原字节已保留，不改写历史资格。

`run_io_v2.py` 默认仅预检，不申请共享锁、不启动引擎。执行必须显式 `--execute`；`--suite io` 为原 23 个独立进程，`--suite delayed` 为两种 A/B 时序共 4 个进程，`--suite all` 顺序运行 27 个进程。每种时序使用新隔离 profile，后继恢复沿用其原 profile。账号、token、击杀数为明确的模型夹具，不是 SDK 资格。

```powershell
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/process_liveness_integration_candidate/tests/io_v2/run_io_v2.py --base-run .godot/campaign_progress_recovery_20261026/20261027_000821_ba1f231b --suite all

# 由主线程持有调度权后，先执行原 23 阶段，再执行 4 进程延迟写入：
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/process_liveness_integration_candidate/tests/io_v2/run_io_v2.py --base-run .godot/campaign_progress_recovery_20261026/20261027_000821_ba1f231b --suite io --execute --timeout 180 --wait-lane 1800
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/process_liveness_integration_candidate/tests/io_v2/run_io_v2.py --base-run .godot/campaign_progress_recovery_20261026/20261027_000821_ba1f231b --suite delayed --execute --timeout 180 --wait-lane 1800
```

适配范围：

- `binding.py` 直接调用当前 `prepare_liveness.preflight()` 重建严格 20+4 合并后的 23 路径清单，逐项核对完整冻结 manifest、生产基线、overlay、native source/build receipt/exe SHA、成功 import 收据、实际工程内容和生成常量。执行前后与等待共享锁后再次核验，不能用旧 20 文件清单冒充新候选。
- 故障执行直接导入旧 `run_io.run_stage` 与 `run_delayed_acquire.execute_case`。真实 Windows 共享拒绝、原 Popen 的终止/等待、断点栈、nonce/PID、原提案、原库存和报告判定保持原流程。只将唯一恢复断点的栈函数由 `recover` 显式改为 `_recover_unique`；语句与唯一性仍严格校验。
- 两份 worker 为明示的外部派生文件，来源 SHA 和逐行差异见 `provenance.json`、`worker_changes.diff`。原 Store/Ledger/提案/账本断言均保留。对外部 PID 的无效 `OS.is_process_running` 检查改为同冻结候选 Manager 的有界真实 helper 查询。延迟 B 在开始及独立最终核验时都必须获得 `WRITER_ALIVE`；A 当时仍受旧宿主 Popen/gate 持有。死亡恢复也须取得 `PROCESS_CONFIRMED_DEAD`，unknown/timeout 均失败，不放宽成死亡。
- 原 bootstrap 字节复用并 pin，仍以 `can_instantiate()` 快速拒绝编译失败。原生 helper 返回文件与 worker 中观察的 PID、nonce、状态、来源 SHA 对照并 pin；运行保留 profile、失败状态、原始 controller、所有引用源与终态收据。
- 新宿主自身的复制、递归取证、SHA 和终态 pin 校验复用旧 `io.fs_path` 扩展路径处理；收据仍记录正常绝对路径。完成计数取实际已验证的独立 PID/收据，不能只靠计划阶段数。

原 23 阶段依序覆盖：正常 handoff/精确 proof/重复、v2 显式升级、write 与四处 release 失败的同对象重试；pending/record/半 pending 进程中断；cleanup/marker 中断及恢复者再次中断；cleanup 删除后、marker 删除后重启。半 pending 的 `ENVELOPE_JSON` 是预期拒绝，不是恢复成功。延迟片覆盖 `first_after_clear` 与 `retry_under_barrier`，保留旧 CAS 不重算提案、活 A、B 原字节和独立回读断言。

边界：延迟 B 使用真实 Store+Receipt，仍不是双 Ledger 并发资格。未覆盖旧无 owner/recovering 死亡窗口、完整篡改拒绝矩阵、断电持久性、游戏流程、导出携带、真实 SDK 或发布。manager 的 3 秒预算和未知状态拒绝保持生产候选原样。上述两批已分别串行执行；其余未覆盖边界保持待办，任何失败保留原始证据。
