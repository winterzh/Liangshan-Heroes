# 活写者基线：缺陷已真实复现

2026-10-26，冻结 `20261026_211212_dd3104df`（内容身份 `source-v1:f6ef8398…`）完成一次真实双 Godot 进程诊断。A 21 项、B 16 项，共 37 项诊断断言通过；两个原生进程均退出 0。`complete=true`、`defect_reproduced=true`，但 **`slice_passed=false`、修复验收未通过**。

A（PID 12164）在 `steam_receipt_store.gd:187` 的真实 acquire 断点持有完整 writing owner，尚无 pending。B（PID 35608）普通 Ledger.open 自动恢复并返回 OPENED，实际删除 `writing/owner.json` 与 writing 目录，另外两条 record 的字节不变。此时 A 始终暂停且存活；宿主保留 Win32 句柄、creation FILETIME 与 Popen，555 个样本全部为 Wait258 / exit259 / PopenNone。

A 放行后得到 LOCK_CHANGED、unsafe / restart_required；原 scope、proposal、CAS 保留，model_committed=false。账本仍为 generation 2、5 kills、0 wins。pending 中 owned_lock=true 只是失效的内存标志，不能解释为磁盘锁仍存在。

证据入口：

- [总收据](receipt.json)、[简要核验](summary.json)、[逐文件 SHA-256](manifest.json)。
- [A 活性及前后目录清单](live_owner/live_owner_intervention.json)、[完整时序](live_owner/case_receipt.json)。
- [A 报告](live_owner/A/report.json)、[B 报告](live_owner/B/report.json)；各自 controller 与 native.log 记录断点、退出及日志 SHA。
- [运行时宿主原文](runner_inputs/run_live_owner.py)、[运行时 README 原文](runner_inputs/README.md)；两个 worker 原文保留于 workers。

归档前重算 41 项运行时 pin 全部一致，report / log / prepared 的 SHA 绑定一致，终态记录最终身份核验、共享锁归属及释放成功。24 份原字节文件逐一复制并复核；另有 summary、manifest、本说明，共 27 文件。未复制 5 份账号目录载荷、任何 profile、二进制或缓存；报告内的账号及 token 是明确标记的合成测试 fixture。旧 README 的“尚未执行”是运行前快照，当前实测结论以本说明与终态收据为准。

这证明旧 f6ef 的活写者保护存在缺陷，不证明后继修复、一般双 Ledger 并发、CFG/LC/slot、真实 Steam 账号或 SDK、原版 GUI、人工体验、性能或发布通过。
