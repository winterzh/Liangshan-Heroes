# 经典续玩恢复观察器失败原始证据（2026-10-27 02:15:55 批次）

原批次：.godot/classic_recovery_branch_20261027/20261027_021555_ab13c0d1。此批 expected=baseline，实际使用原 e97a 源码候选，并非后继 d7 修复工程。

宿主终态 complete=false，错误为 RuntimeError('Actual HELD observer failed')。仅启动原 writer PID 5256，宿主收尾终止其自有子进程，实际 exit 1、process_terminal=true。attempted_processes=terminal_processes=1；cases 为空，恢复 reader 和第二个 record 用例均未启动。最终源码身份检查、自有共享锁确认及释放均为 true，这些收尾项不授予恢复通过资格。

prepared.json 共 22 项检查：21 通过、1 失败。唯一失败为 one read-only observer precedes original Flow capture：

- calls=1，held=true、outside_physics=true、flow_session_absent=true、observer_disconnected=true。
- flow_callback_connected=false，原工具错误地把它当成回调顺序失败。
- 正常命令产生的在途观察与完整类型快照检查均通过，原观察报告完整保留。

原冻结 driver.gd:142 和 run_recovery.py:158 要求上述一次性连接仍可见；宿主先在 run_recovery.py:154–155 因 prepared.passed=false 抛错。生产 continue_flow.gd:222 使用 CONNECT_ONE_SHOT。原 receipt 中保留的后续本地生命周期断点栈实际包含 ContinueFlow._capture_ready → Session.save_held，证明正式回调并未缺席。该批记录支持 QA 观察条件误判的诊断，不支持游戏恢复失败或修复成功。

宿主抛错早于槽 envelope、owner、受控中断前后字节等断言完成；实际槽断点栈也尚未写入最终 row。不要把 ACK、预设断点或 finally 中的终止当作本次预期故障注入已经验收。原 writer.log 仅记录该 QA CHECK_FAILED，没有据此认定原生游戏崩溃。

raw 目录完整保存原收据、writer receipt/log、prepared/request/ack、实际 workers/bindings 与运行时 runner_inputs 全部纯文本原件。原运行目录 104 文件中 102 份文本保留，2 个冻结 EXE 排除。source_map.json 为全部 191 个 pins 提供解析后的原来源及 SHA；优先使用运行时冻结副本，作者后续修订不冒充旧运行来源。manifest.json 覆盖除自身外的全部归档文件，长路径均通过 Windows 扩展绝对路径读写并回读哈希。

未复制独立存档、profile、account、缓存、assets 或 EXE。prepared 原报告中的 QA 类型观察保持原字节。此档案只授予失败证据完整保存资格；恢复分支缺陷复现、修复通过、公开入口、发行版、SDK、人工键鼠及发布均未达。归档没有运行引擎、修改源码或操作 Git。
