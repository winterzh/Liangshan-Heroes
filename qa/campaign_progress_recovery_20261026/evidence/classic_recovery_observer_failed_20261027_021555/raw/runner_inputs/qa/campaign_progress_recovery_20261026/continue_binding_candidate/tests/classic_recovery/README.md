# classic30 死写入者源码分支诊断

本文件记录工具准备时状态：**当时未编译、未运行**；后续实测与资格以 [VALIDATION.md](../../VALIDATION.md) 为准。工具不修改已冻结 3GD、父候选 manifest 支持列表、e97a、现有 classic/IO 工具或生产。`sources.json` 单独记录复用来源；默认 preflight 不启动引擎。

资格边界必须保留：`initial_private_gate_used=true`、`source_restore_branch_only=true`、`public_entry_qualified=false`、`original_release_qualified=false`、`sdk_qualified=false`。源码 editor/`--script`/`STEAM_DISABLED` 被生产 `SteamRunPolicy.test_environment()` 视为测试，无法直接授公开入口资格。本诊断经可见 Continue 按钮用私有 gate 接受请求，然后在同一同步调用栈、无 await/pump 的情况下清掉 **仅 `LSH_CONTINUE_FLOW_QA`**。原 `request_continue` 连接的下一 `process_frame` 自行进入 `_restore`；清标志前后必须确认 callback 尚未执行、phase/source/session/frame 正确，否则立即失败。`STEAM_DISABLED=1` 始终保留。

每种断点两个独立进程；pending 与 record 两案共四进程，各案使用新 profile，同案 A/B 共用真实原目录：

1. A 复用旧 classic 的可见驻守战菜单、原 intro、正常 `Policy.initial_orders`（付费工地及训练），核对真实费用；Viewport Esc 打开暂停后点原 `SaveAndExit`。只读一次性 `capture_ready` observer 早于 Flow 注册，实际 HELD 后记录完整 typed snapshot/clock/费用动作，移除自身连接，确认原 Flow callback 仍连接、其 Session 尚未创建。不给生产方法增加替身、不修改战斗值。
2. 宿主使用原 `godot_debug_wire.DebugConnection`，只发送 breakpoint/get_stack_dump/continue。pending 案在 `run_snapshot_store.gd` 的唯一 `_checkpoint("pending_verified")`，必须带 `Slot.write_slot → Session.save_held → Flow._capture_ready` 实际调用栈；先发生的 classic LC gen1 提交只记录并继续。record 案在 `run_slot_store.gd` 的唯一 `var released := release()`，完整 record 已提交而 writing 尚未释放。
3. 读取原完整 envelope、字节 SHA、revision/previous、实际 writing owner PID；确认 HELD observer 原报告成功，停止的是原 Popen PID，然后仅 `kill/wait` 该进程。保留终止前后完整 `continue/v1` inventory 和逐字副本。pending 使用**原完整 pending 的 SHA**作为新 head 预期；record 使用停点原 record SHA。均为首次真实保存，revision=1、previous=ZERO；不创建或修复半写文件。
4. B 使用同一源/原 profile，生产 Slot validator 只读验证完整候选及原 active LC，再点真实 Continue 并按前述时序清 QA gate。baseline 仅接受原 e97a，须复现 `RECOVERY_REQUIRED`、保留 Menu、无世界安装、全部 slot/LC 原字节未变；fixed 仅接受新的精确 23 文件候选，须安装原暂停 classic 世界、原槽 SHA/token/binding、完整 typed 世界/费用/队列观察一致，LC 仍 active gen1 且字节不变。

复用原文件而不改动：

- `handoff_candidate/tests/classic/driver.gd`：以原字节复制为外部 `classic_base.gd`，只继承按钮查找、原 snapshot/typed 观察、等待等方法；新 driver 自己拥有启动/阶段/报告，旧六阶段 runner 不调用。
- 同目录 `policy.gd`、`inflight.gd` 原字节复制，分别负责普通付费操作及完整暂停观察。
- `store_protocol_candidate/tests/io/run_io.py`：只调用现成 Windows 路径、目录证据、原调试 wire、实际引擎 PID 查询函数；不调用其 20 文件 preflight，也不改变其全局接口。
- 父 `tests/run_disk.py.preflight`：精确验证 CLI 指定 baseline/fixed 工程、23 脚本、native helper 来源/构建/EXE、成功导入、生成身份及 pins；使用返回的 **run_base/project/generation** 执行，不误用原 e97a 的 base。

```powershell
# 只读；原 e97a 的预期是复现分支失败，不能计作修复通过
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/continue_binding_candidate/tests/classic_recovery/run_recovery.py --base-run .godot/campaign_progress_recovery_20261026/20261027_000821_ba1f231b --expect baseline
# <NEW_RUN> 必须已单独导入；源码准备资格不代替导入
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/continue_binding_candidate/tests/classic_recovery/run_recovery.py --base-run <NEW_RUN> --expect fixed
# 只有根线程实际调度时，才在相应命令后追加 --execute --timeout 180 --wait-lane 1800
```

宿主只释放自己持有且所有已尝试子进程均终态、无活引擎的共享锁；异常收据与原失败文件保留。实际阶段/进程/检查数来自终态收据，不把计划四进程写成已通过。

本片不验证真实公开启用、OS 人工键鼠、release EXE、SDK、自然 30 波终局，也不包含半 pending、owner/content/context 拒绝、rev0 空首次锁或 scope/CAS 竞争矩阵；这些分别保留后续。
