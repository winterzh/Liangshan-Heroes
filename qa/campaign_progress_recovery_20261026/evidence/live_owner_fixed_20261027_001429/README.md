# 活写者保护 fixed 切片通过

新完整候选 `20261027_000821_ba1f231b`（内容身份 `source-v1:e97a07b9…d1eea`）在真实双 Godot 进程中完成同一活写者负例。A 24 项、B 21 项，共 **45 项断言通过**；两个原生进程均退出 0，`complete=true`、`slice_passed=true`。此资格仅属于本切片。

A（PID 49012）在真实 `steam_receipt_store.gd:187` acquire 断点持有完整 writing owner。宿主保留 Win32 句柄和 creation FILETIME，569 个样本均为 Wait258 / exit259 / PopenNone；B 打开前后以及 A 放行前均确认 A 存活。B（PID 50780）经真实 native helper（PID 59752）得到 HANDLE_NONSIGNALED，返回明确 WRITER_ALIVE；原业务目录、writing owner 和全部 record 的清单、字节及 SHA 完全不变。helper 的私有 IPC 位于业务目录之外，不将“业务零变化”扩大为整个 profile 没有写入。

A 随后以同 Store 完成原 handoff，持久记录与 prepared 中 Codec 编码的原 proposal 精确相等：generation 2→3，kills 5→8，wins 0→1，pending 清空。精确九字段 proof 的 token、context、descriptor SHA、generation 和文件 SHA 均核对一致。B 在同 Ledger / Store 上 retry_open 后独立读到同一 durable/proof；A、B 重复同 handoff 均不增加奖励或改变文件，最终目录只剩 canonical records。

证据入口：

- [总收据](receipt.json)、[汇总核验](summary.json)、[逐文件 SHA](manifest.json)。
- [活性与前后业务目录](live_owner/live_owner_intervention.json)、[完整时序](live_owner/case_receipt.json)。
- [A 报告](live_owner/A/report.json)、[B 报告](live_owner/B/report.json)，及各自 controller/native.log。
- 运行时两个 worker、[宿主原文](runner_inputs/run_live_owner.py) 与 [运行时 README 原文](runner_inputs/README.md)。

43 项运行时 pin 独立重算一致，报告、日志、prepared 与 observed SHA 绑定一致；最终身份、双进程终态和共享锁归属／释放均通过。25 份原字节文件逐一复制复核，另有 summary、manifest、本说明，共 28 文件。仅从独立helper IPC目录另存[原始provider报告](provider_result.json)，已与B观测的11字段逐一相等；未复制6份账号目录载荷、其余profile、二进制或缓存；报告中的 owner/token/终局描述明确属于合成 fixture。未改外部工具 README 或任何源文件，未为归档启动引擎。

本结果不授一般双 Ledger 并发、死写者／cleanup／marker 恢复、quarantine 超时与 PID 复用、完整游戏回归、真实账号或 Steam SDK、原版 GUI、人工体验、性能或发布资格。后继恢复测试仍需各自独立结果。
