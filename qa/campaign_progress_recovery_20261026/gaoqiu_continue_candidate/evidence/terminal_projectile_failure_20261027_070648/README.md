# 高俅 SaveAndExit projectile 拒绝原件 — 2026-10-27 07:06:48

原批次：`D:\AI项目\水浒\开发工程\.godot\gaoqiu_terminal_20261027\20261027_070648_7b48f352`。只归档已结束的实际执行，不启动引擎或修改候选。

PID 38288 退出 1，宿主耗时 301.030 秒，engine errors 为 0。报告与日志一致：112 项检查，110 通过、2 失败（`actual SaveAndExit operation succeeds` / `save did not reach production-owned exit`）。

本次已通过正常 140 秒首波存活派发：observed_elapsed=140.01666666667，陆军 4、水军 3。随后首波在第二波派发前清场检查也通过；保存前最终原组观察仅剩未派发第二波陆6/水5及第三波陆8/水6，首波陆水均0。这与上一轮纯 H 未清场不同。原时钟 1x/60Hz，报告声明未注入玩法状态。

普通 Escape、可见 SaveAndExit 按钮及首次保存流程已进入实际 ContinueFlow。实际返回 `code=TIMED_RENDER_OVERRIDE`、`section=visual`、`cause.field=projectile`，`complete_world=false`。这是保存捕获的实际拒绝；本包保留事实，不凭失败码单独给出完整根因。

只执行 `save_after_wave1` 一进程：`save_exit_observed=false`、`exit_reason` 为空，保存及终局 checkpoint 均为空。没有成功保存或后续三进程，不授予恢复、胜利、终局拒槽及四进程链资格；public/SDK/release/human/credited/defeat 资格仍为 false。未读取原 profile，因而不对外部 Slot/LC 的实际落盘状态额外推断。

初/后完整身份、子进程终态、锁所有权、引擎通道空闲及锁释放均 true。原 receipt 保留 436 pins；本次只复核选定原件和来源，未重扫全部资源或全部 pins。

20 份 raw 原件共 998,916 B：receipt/report/log、本轮 8 frozen 工具、5 actual workers 与 bindings、3 小身份/import 元数据。均取自本次 run 冻结输入，逐字核对；实际无 controller，不编造。12 个未变依赖与本轮 frozen bytes 及旧归档精确 SHA 核对，另有 11 bounded full-freeze 引用和 manifest；参考 `../full_freeze_20261027_050851/`，不递归复制旧 import 日志。

未复制 EXE/DLL、缓存、完整资源树、profile/Slot/LC/CFG/IPC 业务文件。原 report 中必要 QA 开局状态/typed opening、普通指令及有限残兵观察原样保留；包含本机路径、PID、nonce 用于追溯。旧工具 README/sources 的准备时状态保留原文，不冒充本次运行结果。

manifest 覆盖除自身外 23 文件；README、summary、verification 标明派生说明，20 raw 均记录 original_source_path、字节数、SHA，并于落盘后回读核验。
