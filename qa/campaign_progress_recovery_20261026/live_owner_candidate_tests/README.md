# 活写者不能被另一进程恢复

本目录是独立 QA 工具，包含 `run_live_owner.py`、`bootstrap.gd`、`worker.gd` 和本说明。未改现有候选、生产、冻结或 I/O 工具。f6ef原生双进程已复现活锁误清理，37项诊断断言符合预期；后继e97a新源的fixed专项45项通过，范围及独立收据见下文。

初交付时仅Python AST与帮助入口通过；后继主线程已执行preflight和显式`--execute --expect defects`，实际结果见下方基线记录。运行时README原字节已单独保留。

默认只读 preflight，不占共享引擎锁、不创建 profile、不启动引擎。只有显式 `--execute` 才取共享锁，默认不等待占用者。执行由主线程单独安排；开发本工具不代表已经排队执行。

```powershell
# 默认检查：已导入 f6ef 冻结、完整生成身份、候选清单、实际引擎与唯一源码断点。
python qa/campaign_progress_recovery_20261026/live_owner_candidate_tests/run_live_owner.py --base-run .godot/campaign_progress_recovery_20261026/20261026_211212_dd3104df

# 需另行明确执行：复现原缺陷，成功只表示 defect_reproduced。
python qa/campaign_progress_recovery_20261026/live_owner_candidate_tests/run_live_owner.py --base-run .godot/campaign_progress_recovery_20261026/20261026_211212_dd3104df --execute --expect defects

# 后继修复冻结：明确活写者拒绝，UNKNOWN 不计成功。
python qa/campaign_progress_recovery_20261026/live_owner_candidate_tests/run_live_owner.py --base-run <已导入后继冻结> --expect fixed --execute
```

`defects` 只接受源码 `f6ef8398f297af3a9be64ca376b9f2a940951d9b93b0512808e3f4275afc32e4`、Steam Store `11bf6cae…`、公共 SnapshotStore `581e638b…` 的原字节。`fixed` 验证调用方明确选定的新冻结，不继承旧版本通过资格；清单中的每个脚本与完整 generation 都核验。源码路径、引擎、宿主、两个 worker 和共享依赖在运行前后 pin。

## 真实时序与判定

1. A 使用真实 Ledger 新建私有合成账号账本，正常 `begin_run` 及 `progress(...,5)`；只读 Receipt observer 计算预期 handoff proposal。`prepared.json` 保留原 CAS、proposal、handoff 与 before；跨进程结构用生产 Codec 编码，identity 只含字符串及布尔值。
2. A 发出 `a_apply` gate。宿主只在实际 `steam_receipt_store.gd::acquire` 的唯一 `_checkpoint("lock_acquired")` 语句设置外部 debugger 断点；核对 PID、thread、source/line/function 与实际栈。此时原 `writing/owner.json` 完整，尚无 `receipt.pending`、cleanup 或 marker。记录 owner 原字节/SHA、目录完整 inventory，并复制账号目录。
3. B 为同一 profile/owner，先到 `b_open` gate，再普通 `Ledger.open(require_existing=true)`，由原打开链自动 inspect/recover；不直接调用 recovery、不替换返回值、不改写任何生产方法。若后继返回 `LIVENESS_PENDING`，最多 15 秒以同 Ledger/Store 调用真实 `retry_open()`；最终仍必须明确 `WRITER_ALIVE`。UNKNOWN、超时、持续 PENDING、进程崩溃均不算 fixed 成功。
4. B 到 `b_observed`，A 仍停在同一断点。`defects` 必须 B 真正返回成功、实际删除 A 的 owner/writing，而且账号其余文件字节完全不变。`fixed` 必须返回 `WRITER_ALIVE`，整个 inventory 与 A 断点快照完全一致。宿主保存 `live_owner_intervention.json`、before/after 目录副本和 Win32 活性证据，随后才放行 A。
5. `defects` 中 A 必须得到 `LOCK_CHANGED`、unsafe/restart，保留同 Store、原未提交 proposal/CAS，model 尚未 commit；原 head/SHA、5 kills/0 wins 不变，同 scope 重试仍不变。`fixed` 中 A 原 handoff 正常完成：原 generation +1、8 kills/1 win、精确九字段 proof、释放干净、重复 handoff 不再累计。
6. A 到 `a_verified` gate 后继续存活。B 用自己保留的 Ledger 独立核对最终结果；fixed 中以同 Store `retry_open()` 打开，再验证同 proof。宿主确认 B 验证没有改变文件，B 实际退出后才 ACK A 退出。两个 report 全部断言、stage_completed、身份和实际退出码 0 都成立才能通过；stdout 的 PASS 文字不能单独作为成功。

## 活性证明与安全边界

Godot 4.6.3 Windows 的 `OS.is_process_running` 仅查询查询方内部 `process_map`；不能把兄弟进程的 false 当死亡。本 worker 完全不使用该 API 证明 A 的活性。

宿主只对自己 `Popen` 创建的 A 打开 `SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION` 句柄，绑定真实 image、PID 与 creation FILETIME，并持续要求 `Popen.poll() is None`、同一保留句柄 `WaitForSingleObject(...,0)==WAIT_TIMEOUT`、`GetExitCodeProcess()==STILL_ACTIVE`。保留句柄标识同一进程实例，进程退出后不能恢复为未终止；B 启动、B open 前后、A 恢复前后及 B 完成时均有样本，等待循环也取样。调用失败或无法证明存活直接使测试失败，不猜测死亡，不通过 Godot 查询回填结果。creation FILETIME 用十进制字符串保存，避免跨 JSON 丢精度。

新 gate schema 为 `live_owner_gate_v1`，绑定 nonce/PID/index/mode/case/kind/owner/directory；report 为 `live_owner_worker_v1`，总收据为 `live_owner_runner_v1`。环境使用 `LO_PROFILE/PROJECT/WORKERS/WORKER_SHA256/NONCE/MODE/EXPECT/OUTPUT`，B 另有 `LO_PREVIOUS/LO_PREVIOUS_SHA256`。Steam 禁用、CAMPAIGN_QA 为空、四个系统 profile 根隔离、固定 `user://steam_receipts/v1`，保留非 physics 启动守卫。

复用既有 `run_delayed_acquire.Pair` 的 debugger framing、断点状态机、原子 ACK 和自有子进程清理，以及 `run_io` 的 Win32 扩展路径、no-links/scope、snapshot/copy、post_step/persist_result；只导入，未修改它们。所有进程由本宿主保存 Popen 对象，只能终止自有子进程；不按名称杀进程、不操作 OS 键鼠。任何主错误保留 traceback，后置清理错误另存且撤销通过资格；不覆盖旧证据。共享锁只有确认仍属自己且无引擎运行时释放。

产物位于 `.godot/campaign_live_owner_io_20261026/<batch>`，每批创建 `D:/CodexQA/liveowner/<nonce>` 短私有 profile。`complete=true` 在 defects 中仅表示真实缺陷复现，`slice_passed` 仅属于 fixed 的这一个活锁负例；`production_qualified`、SDK 和一般双 Ledger 并发资格始终为 false。未覆盖活 claimant/unique marker 抢占、死亡收尾、PID 复用、权限 UNKNOWN、CFG/LC/slot、真实账号、断电、自然玩法或发布。


## 2026-10-26 活写者基线实测（诊断成功，修复未通过）

主线程运行 `20261026_234140_40126e64`，对已导入 f6ef 冻结执行 `--expect defects`：A 21 项、B 16 项，共 37 项诊断断言通过，两原生进程退出 0；`complete=true`、`defect_reproduced=true`、`slice_passed=false`。

A（PID 12164）在真实 acquire 的 lock_acquired 断点持有完整 owner；宿主保留 Win32 句柄的 555 个样本均证明 A 活着且尚未放行。B（PID 35608）普通 Ledger.open 返回 OPENED，实际删除 A 的 writing owner / writing 目录，另外两条 record 字节未变。A 放行后 LOCK_CHANGED / unsafe，原 scope、proposal、CAS 未丢，账本仍 generation 2、5 kills、0 wins。pending.owned_lock=true 为失效内存标志，不代表磁盘锁仍在。

终态报告、controller、日志和 41 个运行时 pin 已独立复核；共享锁归属与释放记录通过。原字节证据见 [活锁基线归档](../evidence/live_owner_baseline_20261026_234140/README.md)，包含运行前 README 快照，未复制私有账号目录载荷。此结果确认旧源码缺陷；后继 fixed 活锁保护、一般并发、真实账号 / SDK、GUI、性能和发布资格均未授予。

## 2026-10-27 后继 fixed 专项通过

23脚本及固定helper新冻结`20261027_000821_ba1f231b`（实际source-v1:e97a07b9…d1eea）运行`20261027_001429_a52fb5dc`，45项通过（A24/B21）、双exit0、完整身份后验通过、锁释放。B实际返回WRITER_ALIVE，A仍存活，业务目录和全部原字节不变；A按原proposal正常提交，B保留同Ledger/Store重开并获得同一九字段proof，重复handoff没有重复奖励或文件写入。

原始provider报告、宿主活性证据、运行时README及所有结果见[fixed专项归档](../evidence/live_owner_fixed_20261027_001429/README.md)。只有此活写者时序通过，不授一般并发、死者恢复、v2超时隔离、游戏、SDK或生产资格；上一节未授fixed的结论保留基线当时语境。
