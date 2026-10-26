# Steam 纠正与 Session 尾账：独立回归

这里只新增外部 QA worker，不改正在冻结的 20 个候选脚本、manifest、receipt_model 或黄泥冈驱动。当前已完成实际引擎运行：旧811源`194925_27b674d4`成功复现两类缺陷；新23c源`195508_84cf1da4`通过8项宿主、14项Receipt和27项Session检查。首轮初始physics frame拒绝被保留；后继等待普通process frame后调用同一真实Session API。它仍仅资格为纯/合成逻辑回归，不是文件故障或SDK验收。

## 运行契约

使用已完成导入的 20 文件 handoff freeze。宿主先验证 base-run 位于本工程 `.godot/campaign_progress_recovery_20261026/`，再核对 preparation、根工程来源、生成清单、20 文件候选清单与实际工程、实际引擎及外部 worker SHA。与已有训练／黄泥冈执行器共用引擎锁，结束后复核身份并只释放自己的锁。

```powershell
python qa/campaign_progress_recovery_20261026/handoff_candidate/tests/regressions/run_regressions.py --base-run <已导入冻结目录> --expect defects --timeout 360 --wait-lane 1800
```

基线 `--expect defects` 成功表示两个缺陷被确实复现；`candidate_regressions_passed` 必须为 false。统一修复并新建 freeze 后，将参数改成 `--expect fixed`：只在两个场景的修复后条件全部成立时通过。两种模式都不授予完整候选运行、真实 Steam、文件事务、原版 EXE、键鼠、人工、性能或发布资格。实际执行结果以新 output 的 receipt/report 为准。

若当前候选源码已开始修复，复跑旧 811 冻结时必须显式增加 `--historical-freeze`。此模式报告 `current_candidate_matches_freeze=false`，仍要求旧冻结的 20 个实际脚本逐一等于原冻结 manifest，并继续 pin 当前候选文件与清单的运行前后 SHA；不会修改旧冻结或把旧结果授予新候选。

宿主复制并冻结 bootstrap.gd、worker.gd、receipt_case.gd、session_case.gd，采用四目录隔离的私有 profile。启动参数为实际候选引擎 `--headless --script <bootstrap.gd>`；这里只运行纯逻辑，不加载战场或纹理。`STEAM_DISABLED=1`，`CAMPAIGN_QA` 为空。不会复制存档或真实 SDK 数据。

独立 ENV 为 `RG_PROFILE`（原 Windows 字符串）、`RG_PROJECT`、`RG_WORKERS`、`RG_NONCE`、`RG_REPORT`、`RG_EXPECT`，以及 `RG_WORKER_SHA256`、`RG_RECEIPT_SHA256`、`RG_SESSION_SHA256`。bootstrap 自身由宿主运行前后 pin。报告包含实际 PID、nonce、profile、Provider 的完整 `trusted_identity`、逐项断言与每例前后状态，宿主验证实际子进程 PID / exit code 与报告绑定。

## 覆盖

1. `receipt_case.gd` 直接调用真实 Receipt reducer：以 TOTAL_WINS=10、ACH_WINS_10=true 为历史状态，持久模型提交 invalidate(epoch 1)→权威 correction(仍十胜、成就 false)→adoption merge→completion merge→严格 reopen→restart merge。修复后 false 必须保持；epoch 0 同样 merge 的正向控制仍应推导成就。这里的 commit 是模型提交，**没有磁盘持久化或 SDK 回调**。
2. `session_case.gd` 调用真实 LocalRunSession，显式注入只在内存中工作的 FakeLedger；FakeLedger 内部使用真实 Receipt 提案和 commit。先在 progress10 提交前合成一次瞬时失败，再 observe11 + queue_terminal(victory)。分别检查一次 checkpoint 的返回语义、begin 不丢旧尾账、第二批 settle 失败后的 exact proposal 重试与胜利只计一次。所有失败前后 Session、Receipt、pending 与调用记录保留在 report。

FakeLedger 不模拟 Windows 文件系统、Store 锁/rename/recover、不模拟真正 SteamService 或 SDK 账号，不把合成失败当真实 I/O 证据。这些路径仍需独立实际 I/O 与服务接线验证。报告中的 `passed` 只表示指定 `expected` 模式断言成立。

## 已确认最小修复方向（本目录不实施）

- Receipt `prepare_remote_floor()` 仅在 correction_epoch == 0 时调用 `_evaluate(next)`；纠正后的普通远端合并不把权威撤销的成就重新推导为 true。保留 epoch 0 的既有行为。
- Session `checkpoint()` 拆出一次批次处理，单次同步调用最多收敛“已有冻结批次 + 当前最新尾账”两批；第二批失败返回失败并保留原提案。不能在 `_dirty` 仍 true 时返回可让 begin 清空旧 token 的成功。begin 必须在旧尾账完全收敛后才建立新 token。此契约也覆盖只调用一次 checkpoint 的退出路径。

原始问题位置为当前冻结候选 `scripts/steam_run_receipt.gd:247` 与 `scripts/steam_local_run_session.gd:82–90,108–124`。后续修复行号可变化，实际候选身份以宿主收据为准。
