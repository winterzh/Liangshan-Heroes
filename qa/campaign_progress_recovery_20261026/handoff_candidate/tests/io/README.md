# Steam handoff 本地文件事务专项

新23c源的实际专项已完成：`20261026_200759_741207e6`共9案例/13进程阶段、178项已完成worker断言符合预期，前后身份/源文件pin通过、共享锁释放。[汇总及边界](../../../evidence/handoff_io_20261026_200759/summary.json)。其中7类正常/重试/恢复成功，两类损坏或缺失归属残留按预期拒绝；不是完整自动恢复通过。使用冻结工程真实 `steam_run_ledger.gd`、`steam_receipt_store.gd`、`run_snapshot_store.gd`；没有方法返回值 mock、源码补丁、替换 Store 或真实 SDK 资格。

所有案例使用独立短路径 profile 下的固定 `user://steam_receipts/v1/5088120/76561198000000001`。账号字符串是显式合成夹具；正常案例的 token 由真实 `Ledger.begin_run()` 随机生成，作为合成测试 token 写入 `prepared.json`，不能据此声称获得真实账号资格。结局、击杀与 intent 哈希也是组件夹具，不是自然战斗验收。

## 复用与入口

- 复用 `tools/godot_debug_wire.py` 的有界 loopback 调试协议、实际 PID/stack/source/line 校验；模式参考既有 `tools/run_campaign_persistence_fault_matrix.py`，未改旧工具。
- 复用 `qa/huangnigang_production_20261020/run_batch.py` 的冻结身份、来源哈希、共享 lane、进程扫描和隔离环境 helper。
- 生产已有 `_checkpoint("pending_half"/"pending_verified"/"record_renamed")` 仅作为实际源码断点位置；未覆盖 `_checkpoint`。Windows 原生共享句柄在实际 API 前阻止写入/删除，真实方法负责返回错误。

先对根线程已成功导入的 20 文件 handoff 冻结执行只读 preflight；`--execute` 才启动引擎。失败冻结不能作为入口。

```powershell
python -X utf8 qa/campaign_progress_recovery_20261026/handoff_candidate/tests/io/run_io.py --base-run <已成功导入的冻结目录>
python -X utf8 qa/campaign_progress_recovery_20261026/handoff_candidate/tests/io/run_io.py --base-run <同一冻结目录> --execute --timeout 180 --wait-lane 1800
```

runner 只复制外部 worker 到新的 `.godot/campaign_handoff_io_20261026/<批次>/workers`，不改冻结工程。每个案例使用新的 `D:/CodexQA/campio/<nonce>`；崩溃案例恢复进程复用原 profile、nonce、descriptor 与固定 root。原进程真实终态后才能启动下一进程。共享锁只在所有引擎终态且仍属于本 runner 时释放；失败文件与原日志全部保留。

## 13 个进程阶段

| 案例 | 真实调用及证据 | 预期 |
|---|---|---|
| normal | Ledger open/begin/progress → handoff；独立 Store 重新读取原链 | 仅一个新 generation，8 kills/1 win；固定 9 字段 proof 与独立头 SHA 完全一致；重复调用不改任何账本文件；另一个 intent 被拒绝 |
| legacy_upgrade | 通过真实 Store 写严格 v2 合成 genesis；Ledger 读/写/upgrade | 初读不改原文件，普通写要求显式 upgrade；v3 新记录 previous 指向原 v2 SHA，原字节保留；重复升级不写 |
| write_retry | 在 `_write_new` 真正 pending 写入前设置不共享 WRITE 的原生文件句柄 | 原 API 返回 WRITE_OPEN；记录原 proposal/owned pending；移除仅由控制器创建且仍为空的占位后，同一 Ledger/同一 proposal 重试 |
| release_owner_retry | 在删除真实 writing/owner.json 前持有不共享 DELETE 的句柄 | LOCK_RELEASE；文件原字节不变，同对象继续释放并给出精确 proof |
| release_directory_retry | owner.json 已删除、空 writing 目录删除前持有不共享 DELETE 的目录句柄 | LOCK_RELEASE；同对象 retained OwnedRelease 接着完成，不重建 proposal |
| crash_pending + recover | closed pending 已验证时外部终止原 PID；全目录副本保留；新 PID 用原 Ledger.open | inspect_recovery 明确 forward_pending；只读回既有 handoff，重复 no-op |
| crash_record + recover | 原子 rename 后终止原 PID；同 profile 新 PID | release_committed_lock；同一终局只记一次 |
| crash_half + recover | 已 flush 半份 pending 后终止原 PID | ENVELOPE_JSON，保留全部残留且不给 proof；这是预期拒绝，不是可恢复证明 |
| crash_owner_removed + recover | owner.json 已删、writing 目录仍在时终止原 PID | UNKNOWN_OR_MISSING_LOCK，保留目录且不给 proof；明确暴露现有缺口，不宣称跨进程自动恢复完成 |

`write_retry` 必须由 stack 确认 `_write_new` 来自 `commit_locked`，会跳过 `acquire` 写 owner.json 的同一行。控制器必须记录实际断点、真实错误、原生拒绝句柄和解除证据；只有 script 错误或超时不能充当 I/O 通过。

## 外部环境契约

`bootstrap.gd` 继承 SceneTree，加载绝对路径 `IO_WORKERS/worker.gd`，核对 `IO_WORKER_SHA256`。worker 使用以下环境变量：

| 变量 | 内容 |
|---|---|
| IO_PROJECT | 冻结 project 的绝对路径，必须等于实际 res:// |
| IO_PROFILE | 本案例隔离 profile；APPDATA/LOCALAPPDATA/TEMP/TMP 分别绑定其同名小写子目录 |
| IO_WORKERS / IO_WORKER_SHA256 | 本批外部脚本目录及 worker 字节哈希 |
| IO_MODE | 上表单个模式；恢复进程为 recover |
| IO_OUTPUT | 当前进程证据目录 |
| IO_NONCE | 同案例共享 32 位随机 nonce |
| IO_PREVIOUS / IO_PREVIOUS_SHA256 | 仅恢复：原进程 prepared.json 及其哈希 |
| STEAM_DISABLED / CAMPAIGN_QA | 固定 1 / 空字符串；不引入 SDK、账号或 CFG 抑制资格 |

故障握手为 `request_NN.json` → 控制器设置真实断点 → `ack_NN.json`。错误后第二个 `release_fault` 请求才关闭本控制器的原生句柄。所有握手均绑定 nonce、原 PID、index、模式和固定私有账号目录。不得手工补 ACK 跳过故障。

## 收据与尚未覆盖

每进程保留 `controller.json`、native.log、worker `report.json`；崩溃 writer 没有正常完成 report，必须具备实际断点、被终止 PID、非成功进程退出、terminated_account_copy 与后继恢复 report。正常/故障 writer 在变更前写 `prepared.json`，包含合成 token、descriptor、basis、实际源码/引擎身份。runner 总 receipt 的 complete 仅表示这 13 阶段符合预期，包括两项预期拒绝诊断。

本专项不覆盖实际断电持久性、磁盘耗尽、ACL 目录权限、任意外部篡改、SDK callback/result8/真实账号切换或上层 CFG/生命周期跨文件协调。尤其 owner 删除后的进程死亡仍无法自动补发；通过该拒绝诊断不能改称完整终局恢复。本次已用Windows原生共享句柄实际触发WRITE_OPEN、owner删除及目录删除的LOCK_RELEASE，同对象原proposal重试成功；闭合pending和已rename记录的原PID终止后独立恢复也通过。首次执行器类型错误、初始physics frame诊断、旧JSON读取失败及中间收据重名失败均另存原证据，后继仅修正测试执行与已记录候选缺陷。
