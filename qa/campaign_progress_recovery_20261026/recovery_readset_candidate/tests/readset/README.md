# Exact Slot readset：隔离原生针对性工具

本目录是尚未运行的外部 QA 工具。只绑定 prepare_readset.prepared_state 接受的新候选、完整 23 脚本和原生 helper、同一固定引擎及该候选自己的成功 import。默认只读预检；未传 --execute 不建 profile、不启动引擎。生产、旧冻结和原失败 profile 不变。

本轮目标是验证 readset 证明和真实文件恢复，不包含完整 19 类/61 阶段、公开入口、完整游戏体验、SDK 或发布。exact 原 Slot 是实际 res://scripts/run_slot_store.gd 资源，攻击不继承或覆盖其方法。派生 Slot 和 CFG 只验证保留的原路径，不能给它们制造优化证书。

## 执行与来源

新宿主 run_readset.py 使用独立输出、共享引擎锁及三个自有进程：

1. producer：在全新 profile 中，由实际 Slot acquire/commit_locked/release 生成小型 B/H 记录并重新持锁；最后提交第三代，宿主在原 pending_verified 行验证来源、栈、PID、完整闭合 pending 和 owner 后停止这个自有 producer。保留原 Popen 的进程句柄直到 reader 结束，不改 owner PID。
2. attack_reader：同 profile、不同 process nonce，正常 autoload 完成后执行下表。真实 helper 判定原 producer 已退出。只有显式文件攻击和合成数据准备会修改测试目录；不伪造 liveness 返回、时钟或私有证明字段。
3. clone_record：第二个全新 profile，完整复制原 02:37:31 失败现场 continue/v1 的 3 文件/8 目录，逐字/SHA 相等。使用新候选的实际 Slot.inspect_recovery/recover；只允许删除原死 owner 和 writing 目录，原 3,961,694 字节槽与 LC 必须保持原字节。

原档来源固定为 .godot/classic_recovery_branch_20261027/20261027_023731_c180a912。原槽 SHA 为 2a4513329433fa76973cff28fd6d95044d3b9b8e7accb275969a7510580eb1f5；原 owner PID 为 12488。宿主复用原 timing 只读来源核验，但不会使用 timing 的旧 d7 状态替代新候选 prepared_state。宿主先将 seed 逐字复制到新 profile/inputs/seed.json 并核 SHA，只有此新副本路径传给 producer；reader 与 clone_record 不接收 seed 路径。原 profile 的路径不传给引擎、不修改、不清理。seed 副本属于业务载荷，归档时同样排除。

原档中的 content identity 仍是旧 d7，不改写成新身份。本片的 clone 成功最多授予 Store 文件协议资格，不能证明新版本可以通过 Flow 正常加载这个历史档；正常 Flow 必须由根线程用新冻结重新保存和恢复。

示例（第二行仅由根线程持有调度权时执行）：

    python -B run_readset.py --base-run D:\AI项目\水浒\开发工程\.godot\campaign_progress_recovery_20261026\20261027_034810_ed1bdef8
    python -B run_readset.py --base-run D:\AI项目\水浒\开发工程\.godot\campaign_progress_recovery_20261026\20261027_034810_ed1bdef8 --execute --timeout 300 --wait-lane 1800

导入尚未完成时，默认预检拒绝是预期行为。Python AST/--help 通过不等于 GDScript 已编译或原生片已运行。

## 有界案例

| case | 实际施加或调用 | 必须观察到 |
| --- | --- | --- |
| aba | inventory 见 A,H；原 _chain 前换成 B；_chain 返回、其错误判断前换回 A | RECOVERY_READSET_CHANGED，无 claim；证明实际 raw SHA 与起始库存冲突即拒绝。新代码可在首个 B 上提前失败，不宣称完整 B→H 链已走完 |
| file_content | seal 后真实 query 完成、readback 前换前代 record 原字节 | RECOVERY_CAS_CHANGED，不能用 timeout 代替 |
| pending_changed | 起始放入真实闭合 gen3 pending；readback 前替换其字节 | RECOVERY_CAS_CHANGED，不得前滚替换后的 pending |
| file_rename | readback 前改前代文件名 | 完整名字集合变化被拒绝 |
| directory_set | readback 前显式加入 recovering 目录 | 完整目录集合变化被拒绝；host 注入的目录不能算引擎成功创建 claim |
| owner_replace | readback 前只替换同长度 token 原文 | RECOVERY_CAS_CHANGED，原 owner 语义相似不等于原字节一致 |
| scope_expiry | 原 inspect query 前停在真实断点超过原 3 秒 | PROCESS_LIVENESS_TIMEOUT，无 claim，预算和时钟不变 |
| forged_plan | 修改 action/head/PID/inventory，传给实际 recover；另在原 live scope 中取得真实证明后传 changed plan 给原 readback | fresh plan 拒绝、证明 scope 拒绝、所有失败后字节不变并清证书；最终合法 copied plan 仍能恢复 |
| record | 真实已退出 producer 留下完整 B/H 与锁 | 原字节头恢复成功，只移除 writing/owner 和目录 |
| pending | 实际 commit_locked 原生断点留下完整 gen3 pending | 原字节前滚 gen3、按原规则 prune gen1、清理锁，gen2 保持 |
| derived_fallback | 无 override 的真实 Slot 派生类 | 原 readback 的 _chain 栈真实命中；原 scope 内无 exact-Slot 证明；只读结果不变 |
| cfg_fallback | 正常 reader startup 后才放入 individually valid、但 gen1 state=applied 的闭合 CFG 夹具 | 原 CFG._chain 拒绝 CFG_PREPARED_GENESIS_REQUIRED，不跳过跨代语义 |

forged_plan 同时包含原元数据的 0、负数、非规范整数、非数字、超出 INT_MAX 负例，以及真实当前 reader PID 的 alive owner。后者必须由原生 helper 返回 WRITER_ALIVE/HANDLE_NONSIGNALED；除了明确的 owner 测试写入外，整个目录保持，随后恢复原 owner 原文。它与修改 plan.dead_pid 导致 fresh 比较失败分开记录。

小夹具保留原档的真实 Codec root/options/session/binding、完整必需字段和一致的旧 content。为避免大档验证本身消耗 3 秒而掩盖 ABA，world 非 map 段是显式合成空值，map display 使用合法 none；A/B/H 逐个由实际 Slot._decode 验证。这些只是存储模型夹具，不能挂载 Battle、不能算自然游戏保存。唯一完整真实槽恢复是第三进程的原字节 clone。

## 收据与限制

断点均由当前 prepared 源的函数范围和唯一语句解析，保留脚本 SHA、行、函数、原 Popen、debugger stack、nonce、注入前后 SHA。观察到断点后先记录上下文，再做可能失败的文件 I/O。只有明确自有进程允许停止；外部引擎出现即拒绝。所有路径仍验证私有范围和 reparse，Win32 长路径使用既有 extended-path helper。

driver 的最终 report.checks 是唯一检查计数来源；case_XX 的 checks 是累积快照，禁止相加重复计数。原生 provider JSON 保留原字节，关联 nonce、target PID、provider PID 和 Godot 对自己 helper 的真实退出查询；不能凭 OS.is_process_running 对外部 PID 的 false 判死亡。

结束时检查原现场未变、clone/各 case 的允许变化、完整新旧来源、worker pins、原生进程与 helper 终态、自有锁释放。首次异常和清理/取证异常分别保存；失败不改写成 complete=true。原业务载荷、完整私有 profile、EXE、缓存不进入公开证据，只保留必要原件索引与 SHA。

尚未覆盖：LC/StartupReader 独立原生恢复、双 Ledger 并发、完整未知 PID/权限/平台矩阵、硬断电耐久性、完整 61 阶段、公开 GUI、发行 EXE、SDK、人工体验和发布。CFG/派生 Slot 的本片结果不得转授这些范围。
