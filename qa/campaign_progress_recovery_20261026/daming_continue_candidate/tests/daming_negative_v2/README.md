# 大名府 52 进程负例迁移工具（v2）

本文记录工具准备时状态：已实现外部执行入口，尚未编译、未运行 52 进程。后续实测以本目录原始运行收据和 [候选验证记录](../../VALIDATION.md) 为准。此前 `static_audit.json` 是旧“准入与表目录”草稿的历史静态记录，不能给本轮新字节授予资格。

本工具只消费新 projectile 组合冻结（26 个脚本与原生 helper）自己的首次 cold import，以及**同一冻结完整八阶段大名府 Flow 成功收据**。两个角色均必须已有 A 实际 SaveAndExit、B 独立 Continue 后再次 SaveAndExit、C 自然终局、D 独立菜单拒旧槽。缺失、失败、部分批次、旧 3365 收据一律在创建测试 profile 或启动引擎前拒绝。默认只核命名小文件，不创建冻结、不复制业务档案、不取得引擎锁。

## 范围与来源

- 每角色 1 个 world 进程：原 132 项各走 source / actual JSON envelope，共 264 行。
- 每角色 1 个 component 进程：原 181 项各走 source / component JSON，共 362 行；真实 UnitState、Contract 和纯 Core 配对 API，不能替代为整世界 prepare。
- 每角色 24 个 capture 进程：每项独立 profile / PID，原生离屏 GL、真实 Session 安装、真实 Barrier HELD、实际 Core.capture；保留临时单字段负例、拒绝码、typed/IEEE 回滚和完整 identity/节点/时钟不变断言。
- 合计 52 个真实进程。声明表来自 `case_plan.json` 固定的旧 r4 / r6 全文件；`case_catalog.gd` 原字节保留。`migration_audit.json` 记录函数逐字保留与允许替换的准入/报告入口。旧测试通过不转授本轮。

新 fixture 只从八 Flow 宿主在 A 终态保存的 `closed_a/<role>/slot_scope` 两文件六目录取原始字节。每个新 profile 都复制完全相同的两份 gen1 record，原 PID/token/typed payload/LC3 字节不改；不读取正在推进的原玩家 profile，不伪造旧 `handoff/packet/world` 五件套。原生 `Slot._decode` 与 LC `_decode` 是权威。原同 token C 文档再按当前 LC3 / Intent2 / ACK2 校验；全过程原件与每个 private copy 完整目录/SHA 不变。

world/component 原始负例主体和正例、直接组件调用、完整输入不变/无节点分配检查保留。capture 将原继承闭包显式移到 `capture_base.gd`，不继承旧 `res://tools`。异常 fixture 不转为新局、不清 journal、不解锁 gate、不改生产或 gameplay 数值；负例中的临时篡改只作用于本进程的测试对象并按原断言恢复，绝不授自然玩法资格。

## 入口

```powershell
# 仅命名源、精确旧表/迁移记录、52 阶段计划；不 full hash、不引擎。
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/daming_continue_candidate/tests/daming_negative_v2/run_negative.py

# 只读核完整八 Flow 的实际收据/冻结来源/closed-A；不引擎。
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/daming_continue_candidate/tests/daming_negative_v2/run_negative.py --flow-receipt <完整新八Flow批次/receipt.json>

# 必须由共享引擎通道所有者显式调度。完整准入只在这次执行中做。
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/daming_continue_candidate/tests/daming_negative_v2/run_negative.py --run --base-run <同源新冻结> --flow-receipt <完整新八Flow批次/receipt.json> --timeout 900 --wait-lane 60
```

`--base-run` 无 `--run` 可做完整只读准入，须同时有完整八 Flow 收据；不能把默认轻量检查当执行准入。每个进程超时由 `--timeout` 限定，发生脚本错误、拒绝码不符或超时即留原批失败，不跳过项目。宿主只在原 Popen 已终态、所有 attempt 有实际 PID/exit 记录、引擎通道确实空闲且锁归自己时释放锁；失败原件/traceback/报告不覆盖。

原生解析预检可在完整工程正常 autoload 后，仅 `load` / `can_instantiate` 下列 **8 GD**，不 `new`、不 add_child、不给 DN 环境，不调用准入或负例逻辑：bootstrap、fixture_reader、case_catalog、worker_support、world_worker、component_worker、capture_base、capture_worker。`load_inputs.json` 给精确字节。纯加载不需要伪造八 Flow 成功，不授任何负例执行资格。原 `admission_worker.gd` 留作历史草稿，不属于新 52 进程入口。

## 报告与边界

统一 `daming_negative_stage_report_v2` 记录实际 PID/nonce/profile、完整 request SHA、命名脚本、原 fixture 取证和具体 rows。宿主逐项检查实际进程 exit/log、矩阵计数、原 expected/actual code 和 capture 调用证据；`complete` 取决于实际全部 52 行进程完成以及前后源码/原件/私有业务树/锁后验。`source_flow_chain_passed` 不由负例 worker 新授予；只有既有八 Flow 原收据作为准入来源。

本片不包含原 19 个故障流程，不授全 61 阶段、公开菜单、原版 EXE、OS 键鼠、人工体验、真实 SDK/账号/奖励或发布资格。capture 虽有真实 GL 和 Session，也只是原生组件负例，不等于自然通关。首次编译及性能时限均待 root 独占引擎运行。

## 2026-10-27 首次实际执行与耗时观测

162116_c86e8835 已通过完整八 Flow／原 closed-A／b22 自身 cold 准入；首 Lu world 原生 PID65816 在900.655秒触发宿主超时，exit1、errors空、无最终报告。来源／子进程／通道／锁后验全部通过；失败原件保留，52与61均未授予。日志含原A/C报告非有限观察值的解析警告，不能据此推断Slot解码失败。

后继仅增加 DN_TIMING 标准输出：记录原生准入、runtime、原正例和每个负例开始／完成的单调毫秒时间。仍执行原132×2、181×2和两角色各24独立capture；不减少用例、不改任何原断言函数、输入、时钟或900秒期限。正例循环顺序及失败短路保持source后json。新字节须重新原生加载并完整执行；耗时日志本身不授资格。
