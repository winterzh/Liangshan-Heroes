# classic record 死写入者恢复：只读计时诊断

本文件记录工具准备时状态：未编译、未运行；实际结果随后由根线程记入上层 VALIDATION。只绑定原 d7 `20261027_013339_8495b720` 和已终态失败批 `20261027_023731_c180a912`，不修改生产、任何冻结、Gao 或 classic_recovery 工具。默认 preflight 只读；只有 `--execute` 创建副本并启动一个受共享锁管理的原 Popen。

源码假设：SnapshotStore 的 inspect 先 `_chain`，再经 readback 第二次 `_chain`；recover 的 fresh inspect 后还有两次 readback，并在独立 claim 查询和 mkdir 前检查原 3000ms scope。约 4MB 的完整 Schema 校验可能消耗预算，但现有两份 PID_ABSENT 原始结果并不能证明 manager 采纳结果或确定超时发生点。本工具不调整预算、不实施优化。

从原 record/writer/prepared.json 字段读取原 profile/slot 路径，不打印整个 prepared 载荷。原 `continue/v1` 必须仍为完整 3 文件/8 目录且与原 producer 终态记录一致；在 `--execute` 中按字节/SHA 复制到全新短 profile。原 owner、已死亡 writer PID、LC、record 内容均不改变。正常 d7 autoload 完成后，确认副本业务目录仍与原件完全相同，再做以下真实原 API 调用：

1. 分别计时 `inventory`、`_chain`、`_verified(record_0000000001.json)`、`inspect_recovery`。
2. inspect 失败则原样记录并停止，不造 plan。成功才用原 `_enter_recovery_scope` 开新真实 scope，依原 preclaim 顺序调用嵌套 `inspect_recovery`、完整 plan 相等核对、readback、独立 claim `_confirmed_dead`、再次 readback、owner 原文比较、最终 `check_budget`。绝不调用 `recover` / `_recover_base`；停在原首次 mkdir 之前。
3. 分项模式在每次调用后核对副本完整业务 inventory/SHA，分别记录原调用、SHA guard、provider 采样、摘要及总观察开销。核对和采样也会消耗真实 scope，不能把分项诊断 deadline 等同原端到端延时。另开原始新 scope，执行一次相同完整只读准入序列，内部不插观察器或额外 guard；只在序列前后核全目录，原方法内部 CAS/readback 完整保留，仍停在 mkdir 前。先前读取可能预热文件缓存，报告明确此限制。无 clock 注入、方法替换、时限放宽或事件循环 pump。
4. 保留实际 Oracle 返回、原 provider JSON 字节/SHA、request nonce、target/provider PID、该进程自己的 helper 终态查询。查询错误/超时/活 PID 原样报告，不把 unknown 当 dead。宿主退出后再核对原件与副本业务文件、完整冻结身份及全部 pins；不能确认自有引擎/helper 终态则保留共享锁。

`complete=true` 只表示同字节隔离副本的诊断完整、原件和副本业务字节未变，不代表恢复、原路径现场、公开入口、游戏或发布验收。允许在 private profile 新建原生查询 IPC、日志和普通非业务设置；原 profile 全程只读。

```powershell
# 默认只读，不创建 profile，不启动引擎
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/continue_binding_candidate/tests/classic_recovery_timing/run_timing.py --base-run .godot/campaign_progress_recovery_20261026/20261027_013339_8495b720 --failure-run .godot/classic_recovery_branch_20261027/20261027_023731_c180a912
# 由根线程调度时才追加 --execute --timeout 120 --wait-lane 1800
```

后续优化边界：不能直接删去 readback 的 `_chain`。源码时序反例可能是 inventory 见 A,H（H.prev=hashB），初始 chain 临时见 B,H 合法，再恢复 A；inventory/head 虽相同，原 readback 仍会拒绝 CHAIN_BROKEN。该反例尚未原生复现。任何后继优化都须先把全部 record/pending 原始 SHA 与同一 inventory 逐项绑定，保留子类 `_chain` 跨代语义、owner 原文、完整 CAS、fresh inspect、独立 claim 查询、3 秒预算及 claim 后完整校验；本工具不修改这些合同。
