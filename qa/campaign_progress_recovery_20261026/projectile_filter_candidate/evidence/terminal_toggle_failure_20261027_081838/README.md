# 高俅 b22：第三进程 toggle 操作失败原件

本包保存 `.godot/gaoqiu_projectile_terminal_20261027/20261027_081838_4be25b3b` 的已终态失败证据。只整理原件，不修改工具或生产，不重跑引擎。

A（PID 52992，312.071 秒）127/127、B（PID 13612，592.461 秒）133/133 均真实 `continue_saved` 退出，槽 gen1→gen2、同 token/LC gen1。三波按原 140/330/540 秒派发，B 已自然击停旗舰并得到 `gao_end`；两次 SaveAndExit 成功。本包没有重新读写原 profile，只核原报告。

C（PID 26468，116.211 秒）从原 gen2 独立 Continue，完整 typed checkpoint 与 B 相同、恢复状态等于 B 保存状态；46 项中45项通过，唯一失败为 `normal scroll exposes requested enabled button within clipping bounds`。冻结 driver 调 `press_button` 展开任务折叠按钮，而 base 只 `pressed.emit()`；同源生产按钮是 `toggle_mode=true`、只连 `toggled→_set_expanded`。这是本次 QA 操作缺陷，不能据此声称生产 UI 损坏。原可见性门槛没有削弱。

合计 3 个实际进程、306 项/305 真/1 假，原宿主 `complete=false`。D 未启动，无自然终局/奖励/拒旧槽全链资格。三个日志均无 Script ERROR；宿主源码后验、子进程终态、锁归属、lane idle、锁释放均 true。二次保存到核心就绪不等于通关结果已提交。

`raw/` 保留原 host receipt、三 report/log、实际运行的五 GD 与 bindings、原宿主和必要 sources/manifest。`source_map.json` 逐项映射原 866 个 pins，优先使用原 run/runner_inputs；未改依赖以已提交 d55efdf4 的 b22 full-freeze 紧凑包或精确 Git blob 原字节引用，不递归复制历史链。每个引用都实读核 SHA，EXE 只保留原收据 hash。`manifest.json` 的 raw 项有精确 source 字段，派生说明不冒充原件。

不包含独立 Slot/LC record、profile、工程资源、EXE、cache。原报告中的 slot/lifecycle 审计字段按原字节保留。本包不授完整四进程、公开入口、SDK、原版 EXE、OS 键鼠、人工验收或发布资格；后续修复必须另批验证。
