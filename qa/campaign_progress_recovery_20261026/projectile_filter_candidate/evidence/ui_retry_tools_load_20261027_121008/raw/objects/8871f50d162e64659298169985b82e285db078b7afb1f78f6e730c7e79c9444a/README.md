# 高俅自然核心胜利四进程

本文记录工具准备时状态：仅代码、Python AST/帮助入口/轻量来源核对及静态审查；未编译、未原生执行。本路线不继承造船、失败路线或旧 4 倍速工具的资格。后续运行以本工具独立收据为准。

1. `save_after_wave1`：新私有档经可见菜单进入高俅，原剧情开场、正常 1x/60Hz。宋江使用实际驻扎命令卡入原忠义堂；工匠正常采集、付费建船坞/房屋/兵营，正常招募和技能。观察 140 秒原波次派发，第一组岸军与舰队都清除、第二三波尚未派发时，实际 Escape → SaveAndExit，生产 `continue_saved` 退出。全章时间超过 320 秒仍未到该边界即失败。
2. `resume_core_save`：独立菜单 Continue 恢复同槽 gen1、同 LC gen1/token，生产 Codec 精确比较完整观测 roster、实体/队列/费用/人口/波次/经营计时/mission 目标/核心状态；策略按恢复后的 `level.elapsed` 运行，外部累计指令计数从上次报告恢复，不更改世界。继续观察 330/540 秒自然派发，正常交战击停原旗舰，记录真实 HP 下降与 `story_resolved(subdued)`。三组水陆主力清空、原 `gao_end` 出现、仍未终局时，实际 SaveAndExit + ConfirmSave 二存主槽 gen2；原 LC 保持活动 gen1。全章 1200 模拟秒或本进程 1100 墙钟秒未达成即失败。
3. `resume_finish`：再次独立 Continue，严格同槽 gen2/同 token，验证唯一重建 `gao_end` 是原 Mission-owned 节点、元数据一致、唯一原 `_activate_level_button("gao_end")` 绑定。真实 Resume、展开/滚动到可见按钮并点击收兵。完整 contract3 四目标保留实际 done/missed，胜利正常 finalize 后无 pending；可选生擒不要求完成，不伪造四目标全满。
4. `reject_terminal`：独立正常 startup 与菜单 Continue，原 gen2 槽必须返回 `LOCAL_RUN_TERMINAL`，保持菜单/错误层且不生成 Battle，再正常关闭错误层。原 LC gen1→gen2→gen3、CFG、uncredited proof、奖励、槽 SHA 均不重放/重写。

胜利严格要求 LC v3 / Intent v2 / ACK v2 / Level5 contract3。CFG 必须实际持久化，与同 token ACK 的 SHA 一致；fresh 档只增加第五章通关记录，实际 best_done/best_goal_ids/story_complete 与完整结果一致，解锁数为 6。SDK 关闭，原奖励快照不变；mission metrics 只闭合一次，20 帧后 CFG/proof/metrics/HUD 不重复。保留完整四目标，不用 intent 的六字段投影替代完整结果。

## 操作与边界

只复用旧 `gao_rts_play.gd` 的普通经营/分路选兵思路及 LHM 的已审 Flow 操作；不继承其 launcher、CAMPAIGN_QA、seed、4 倍速、跳开场。策略不提前下令攻击未派发波次成员，普通敌方索敌/补兵/波次完全保留；第三波后可正常攻击补给建筑。隐藏登船刘唐、驻军、非战斗人物不混入岸军重发命令。旗舰观察只读，保存前 observer 已自然 one-shot 解绑或显式断开，未替换生产回调。

所有资源、人口、HP、位置、造船/建筑进度、敌军与波次值均只读；不直调 win/lose/resolve、不直装 Session、不赋暂停/完成状态。普通建造与招募每次接受时记录实际扣费，招募还核实际人口预留与完整正常 timer。地图/已有单位位置只用于选择正常命令目标。若策略败亡、道路/出生口堵塞、按钮未重建或超时，保留真实失败，不降低验收条件。

程序触发真实可见 UI 与源工程玩法，仍不授公开 Continue、OS 真人键鼠、原版 EXE、Steam SDK/实际账号奖励、完整四目标演义或独立失败路线资格。

## 入口与来源

```powershell
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/run_gaoqiu_terminal.py --help
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/run_gaoqiu_terminal.py
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/run_gaoqiu_terminal.py --run --base-run .godot/campaign_progress_recovery_20261026/20261027_050851_9bd328cf --timeout 1320 --wait-lane 60
```

无参数默认仅命名来源/工具 pins 的轻量核对，不完整工程哈希/创建 profile/锁/引擎。带 base 而无 run 才做完整只读准入；显式 `--run` 在自身共享锁内调用固定 Gao `prepared_state(new_run)`，要求该工程自己的完整 23 脚本/helper 来源、生成身份与独立 import。示例941c只授已存在的来源/编译资格，本胜利路线必须另跑。

宿主记录4个不同原 Popen PID与nonce，只有实际 exit0、无日志错误、全部报告检查通过、前后完整 pins/生成/引擎身份一致和 owned-lock 安全释放才 complete。单 profile 仅创建一次；失败保留每阶段原报告/日志/外部输入。五个 GD 外部 bootstrap 检查 SHA，can_instantiate 失败快退。`sources.json` 逐项绑定本批8文件中除清单自身的7项，以及原派生/固定依赖来源；不改旧工具、生产或冻结工程。

## 2026-10-27 任务展开输入修复（尚未复跑）

b22 批 `20261027_081838_4be25b3b` 的 A 127 项与 B 133 项通过；C 45/46 项通过，停在任务终局按钮可见性检查。外部工具原先只发 `_toggle.pressed`，但生产 toggle 通过 `toggled` 驱动展开；这不是一次完整的原生按钮点击，未证明恢复 UI 布局损坏。原运行输入和失败证据保留。

本次仅把 C 的任务展开操作改为 `Window.push_input` 内部鼠标移动、左键按下/释放，观察原 `pressed`/`toggled` 各一次、`button_pressed` 从 false 到 true、原 Mission 回调和详情/滚动区实际可见；不直接设置展开状态、visible 或游戏状态。保存/波次/自然目标/终局/奖励断言及原 6 次滚动与全部裁剪边界保持。报告增加输入 PID/nonce/帧/坐标/按键边缘、展开前后状态，以及失败时所有 Control 祖先可见性/矩形/裁剪和滚动范围。此内部 Viewport 派发不授桌面 OS 键鼠或人工验收资格。

修改后的五个外部 GD 仍须独立加载，再重跑真实四流程；静态差异检查不转授 C 点击成功、完整胜利或 52/61 验收。
