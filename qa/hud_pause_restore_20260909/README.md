# 暂停确认恢复与忙碌拦截回归

2026-09-09：最终批 [`20260909_033710_8119f117`](20260909_033710_8119f117/receipt.json) `complete=true`，93 项原生行为检查全部通过。全新导入退出 0 / 错误 0；错误 profile 保护预期退出 2 / 错误 0；回归退出 0 / 错误 0。三个独立进程分别耗时 23.22、5.43、5.23 秒。

独立回读见 [final_review_20260909.json](final_review_20260909.json)：2,951 个来源与冻结副本共 5,902 次 SHA 比较、11 个归档源码/场景、实际报告与日志均一致。5,902 次完整性核对不计入 93 项行为检查。来源 HEAD `23cc5751803d805f42b12fa3a249df905ed1d50f` 仅是工作区基线，完整受测身份以逐文件 SHA 为准。问题、范围与源码身份见 [专用说明](../../docs/HUD_PAUSE_RESTORE_20260909.md)。

问题：`run_hud_state.finish()` 恢复 `pause.pending` 时调用正常 HUD 确认入口，而 `ContinueFlow` 仍处于恢复中，旧的无条件 busy 拦截会丢失暂停确认。修复仅在 HUD 具备 `_run_hud_prepared=true`、处于已暂停场景树中、禁用处理且阻断信号时允许恢复确认界面；实际执行离开战斗的入口仍检查 busy。

新增测试使用真实 HUD、ContinueFlow、Messages adapter 和 `run_hud_state.activate()`，以合成 host 提供安装时钟与信号连接边界。覆盖三种 pending（重开、主菜单、退出），实际控件内容、准备期间不抢焦点、激活后聚焦取消、取消后聚焦继续、信号阻断、busy 普通按钮拒绝，以及空闲时显式确认只发出一次动作。单独验证 prepared 元数据缺少暂停或输入门禁时不能绕过 busy。

这个测试不运行完整 `run_hud_state.finish()` 世界恢复，也不启动真实 Battle 或 Steam，不计入经典 30 波或八关续玩验收。合成 host 不证明世界时钟正确性，空消息队列不替代消息动画专门测试。

根任务统一持有引擎时运行：

```powershell
py -3.14 -X utf8 -B tools/run_hud_pause_restore_qa.py --run
```

运行器显式包含未跟踪的 ContinueFlow 依赖，冻结生产源码，创建全新私有 profile、执行全新导入及故意 profile 不匹配拒绝测试；保存源码快照、日志、行为报告和前后 SHA 校验。共享 Godot 锁禁止与其他引擎测试并行。脚本错误或超时只结束本次已知子进程，不查询或终止其他任务进程。
