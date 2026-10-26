# 连环马自然胜利四进程驱动

本目录与 `../../run_lianhuanma_terminal.py` 是新增外部 QA，尚未通过 Godot 编译或原生运行。当前范围采用四进程契约；早期三进程草稿未运行，不能授予保存界面验收资格。本片不修改生产、既有测试、候选 20 文件或冻结工程，也不继承训练专项、旧 3/61 阶段、23c 经典回归的通过资格。

| 独立进程 | 必须发生的真实行为与证据 |
| --- | --- |
| `save_training` | 实际菜单“剧情模式”→按标题识别连环马卡→可见启用的“出征”按钮；原对话/开战按钮。原兵营普通训练扣 36 金、24 木、预留 2 人口，20 秒原计时；至少运行 5 秒后，Viewport Esc 打开暂停菜单，点击实际 `SaveAndExit`，保存固定 `user://continue/v1` 槽代际 1，由生产 `AppLifecycle` 以 `continue_saved` 退出。 |
| `resume_training` | 新进程点击实际菜单 `ContinueBattle`；同 profile、同槽、同 lifecycle token 恢复暂停画面及精确原状态。点击真实继续按钮，原队列正常完成，总用时 20 秒（最多两物理帧取整），唯一新单位；再观察 21 秒无重复，Esc→`SaveAndExit`→`ConfirmSave`，原槽代际 2，生产再次正常退出。 |
| `resume_victory` | 第三进程再次点击 `ContinueBattle`，核对原槽 gen2 与唯一已完成单位。实际暂停菜单继续后，以普通驻扎、教场、经营、技能和守两路/反攻命令到达自然胜利，读取已冻结完整结果与终局事务。 |
| `reject_terminal` | 第四进程正常 startup scan 将同 token 归为已应用历史；点击实际菜单继续，Flow 明确拒绝 `LOCAL_RUN_TERMINAL`，保留 Menu、显示错误且没有 Battle；点击真实“返回”关闭提示，槽原字节、生命周期、CFG 与离线奖励状态不增长。 |

当前 `Campaign.is_unlocked(i)` 返回 `implemented(i)`，八幕从开局全部开放。驱动不设置 `Campaign.current`、解锁值或前章通关记录；按 Level4 的真实标题选择卡片，不按卡片序号。滚动使用现有容器，点击前核对标题及按钮在 viewport 与所有裁剪祖先范围内、按钮未禁用。此处 `.pressed.emit()` 验证真实按钮回调链，Viewport Esc 验证游戏输入分发；不称桌面鼠标命中或人工体验验收。

第三阶段必须完整完成 `lhm_training / lhm_hooks / lhm_han / lhm_hu` 四目标：真实诱骑撤步和协同演练、十二骑均先钩破、韩滔被擒、呼延灼败走；同时原中军/宋江存活，十二骑和官军大营自然解除。教场成员完成前不接收全军守线指令；接近点须可通行且在重摆旗标点击半径之外。不会用核心胜利或部分演义进度替代四目标通过。路线失败时保留日志、报告及 profile，不注入摆位、HP、资源、进度或伤害，不调用 win/lose、直接发波或改速。

严格读取实际 LC v3 / Intent v2 / ACK v2、`campaign_level4_v1`、Level4 contract 2，核对 lifecycle `gen1→gen2 pending→gen3 applied` 原链、完整冻结 goals/missed/pending、CFG schema 2/解锁 5/四目标记录、同 token 的 `campaign_uncredited_handoff_v1` proof。第二次保存仍是原 lifecycle 对象与 gen1；存档槽自身由 gen1 升至 gen2。场景内与独立重启均不得重复结算。跨进程训练、槽与终局数据使用生产 Codec 保存精确类型及浮点位，同时保留人可读 JSON。原生训练队列没有独立 job ID；报告使用真实生产者 entity ID、队列索引/key、下单 tick，不虚构任务号。

默认命令只读预检，不创建 profile、不占锁、不启动引擎。两个路径必须来自同一实际冻结及其当前候选清单：

```powershell
python -B qa/campaign_progress_recovery_20261026/run_lianhuanma_terminal.py --base-run <已导入的独立冻结目录> --candidate-manifest <该冻结实际绑定的候选manifest.json>
```

由主线程安排串行通道，显式添加 `--run --timeout 1500 --wait-lane 1800` 才运行。宿主动态核对实际 20 文件清单、当前生产基线、生成身份与引擎，四进程使用真实 `gl_compatibility` 屏外窗口、正常 1x/60 Hz。首波仍为 150/270 秒，每阶段默认 1500 秒，战斗策略自身上限 1000 秒；超时不是通过。记录原 Popen PID、独立 process nonce、共同 batch nonce、前序 report SHA、前后源/生成/worker/helper/引擎 pins；只释放自己持有且子进程已终态的共享锁。

每批新建短 profile 与输出目录 `.godot/lianhuanma_natural_terminal_20261026/<batch>`，四个 profile 环境根由共享助手隔离。外部 bootstrap 绑定五个 GD 文件 SHA，离开 physics frame 后加载，`can_instantiate()` 失败快退。环境为 `LT_MODE / LT_PROFILE / LT_PROJECT / LT_WORKERS / LT_BINDINGS / LT_BINDINGS_SHA256 / LT_REPORT / LT_NONCE / LT_PROCESS_NONCE / LT_CANDIDATE_SHA256`，后三阶段另有 `LT_PREVIOUS / LT_PREVIOUS_SHA256`。`STEAM_DISABLED=1`、`CAMPAIGN_QA` 为空；既有 `LSH_CONTINUE_FLOW_QA=1` 与 `LSH_CONTINUE_FLOW_PROFILE` 仅在严格匹配的隔离 profile 内启用实际 Flow UI。A/B 成功必须观察生产退出理由 `continue_saved`，测试不自行替代保存后的正常退出。

公开战役保存/继续门槛保持原状。离线 uncredited、私有 Flow UI 不授真实 Steam SDK、credited 账本、导出 EXE、发布、人工体验或全战役资格。自然失败两进程链尚未实现：后续另用新 profile 保存活动槽，让宋江以普通移动遭真实敌军击杀，验证 loss ACK `CAMPAIGN_PROGRESS_NOT_REQUIRED / persisted=false / 空 CFG SHA`、不新增通关记录，再独立菜单继续拒旧槽。

复用来源为当前 `tests/training.gd` 的训练观察、`tests/huang/` 的终局读取、`handoff_candidate/tests/classic/driver.gd` 的实际 Flow UI/退出观察，以及旧 RTS 工具中的普通经营策略；没有复用旧工具的开场捷径、4 倍速、种子重置、教场或 contracts 注入。`static_audit.json` 只记录本次 Python AST/帮助入口与源级复核、SHA；不等于 GDScript 编译或自然路线通过。
