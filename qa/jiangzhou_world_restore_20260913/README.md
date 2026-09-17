# 江州恢复 QA（内部里程碑已完成）

全新默认27用例世界批 [20260913_085554_ae1d1fcb](../level3_world_restore_20260909/20260913_085554_ae1d1fcb/receipt.json) 通过1628项，`complete/full_suite/fresh_import/acceptance_complete` 均true；同版经典全新默认 [20260913_084224_c71345c4](../continue_flow_20260909/20260913_084224_c71345c4/receipt.json) 完整296项通过、退出0。联合核验已通过并生成 [validation_summary.json](validation_summary.json)。这是江州内部恢复里程碑，`PLAYER_ENTRY=false`，不表示九玩法、真实Steam、性能或真人验收完成。

1628项全部来自085554单个新批：既有19用例重跑916项、江州[组件381项](../level3_world_restore_20260909/20260913_085554_ae1d1fcb/level2_component_report.json)、七个自然进程331项（save/alarm/rescue/escort/board/finish/terminal_reject为27/58/58/61/61/54/12）。[胜利报告](../level3_world_restore_20260909/20260913_085554_ae1d1fcb/level2_cross_finish_report.json) 确认八人登船、实际开船及4/4，[终局报告](../level3_world_restore_20260909/20260913_085554_ae1d1fcb/level2_terminal_reject_report.json) 确认旧槽 `LOCAL_RUN_TERMINAL`。上一版本缓存710项及080826护送QA误报等失败、中止记录原样保留，不重复加入本轮合计；误报修正仅改QA购买账断言，没有因此修改生产。

联合核验确认两批与当前checkout的2962份生产文件完全同SHA，`world_qa_source_differences=[]`。生产清单SHA256为 `2809029c4e399502ada5b8534f92b75b1c8128e1a3fd6f8c2cef46440f09bdc0`；世界原始收据SHA256为 `6e0adc72a8568ab69712494e371d0a1d0016abf81af11f05ab8ad226d73e03ea`。源码无运行中漂移、玩家档未变、锁释放且未遗留引擎。江州11张和经典16张PNG均核验SHA；人工仅目检江州[首次保存](../level3_world_restore_20260909/20260913_085554_ae1d1fcb/level2_cross_save_report_saved.png)、[先登船保存](../level3_world_restore_20260909/20260913_085554_ae1d1fcb/level2_cross_board_report_saved.png)、[胜利](../level3_world_restore_20260909/20260913_085554_ae1d1fcb/level2_cross_finish_report_victory.png)及经典[中文覆盖确认](../continue_flow_20260909/20260913_084224_c71345c4/screenshots/overwrite_confirm_zh_CN.png)、[英文终局等待](../continue_flow_20260909/20260913_084224_c71345c4/screenshots/terminal_pending_en.png)五张代表图，画面可读、无明显问题，不声称27张全部目检。

默认世界驱动新增江州组件与七进程路线，总计27个玩法用例；另有资源导入和私有目录保护步骤。专项、缓存诊断或失败批均不能替代完整默认新批。

## 完整复现与只读核验

在本机配置Godot后，以下两次引擎运行必须串行，各用独立私有短路径；默认完整运行不传 `--cases` 或 `--cache-from`。本轮成功批无需重复执行，未来新批应绑定其新收据。

```powershell
py -3 -X utf8 -B tools/run_level3_world_restore_qa.py --work-root "<本机世界QA绝对短路径>" --run
py -3 -X utf8 -B tools/run_continue_flow_qa.py --work-root "<本机经典QA绝对短路径>" --run
```

本轮既有证据的联合核验命令如下；不传 `--write-summary` 时只读核验，只有全部检查通过才可写汇总。无收据参数时验证器返回pending/退出2，不默认接受任何历史批。

```powershell
py -3 -X utf8 -B qa/jiangzhou_world_restore_20260913/verify_evidence.py --full-world qa/level3_world_restore_20260909/20260913_085554_ae1d1fcb/receipt.json --classic-receipt qa/continue_flow_20260909/20260913_084224_c71345c4/receipt.json
```

仅调试江州专项时可显式选以下子集；该命令不代替默认27用例验收。

```powershell
py -3 -X utf8 -B tools/run_level3_world_restore_qa.py --work-root E:/CodexTemp/jiangzhou_restore --cases level2_component level2_cross_save level2_cross_alarm level2_cross_rescue level2_cross_escort level2_cross_board level2_cross_finish level2_terminal_reject --run
```

路径可替换为本机可用短路径，Godot使用被忽略的 `godot.local.txt`、`GODOT_PATH` 或 `--godot` 参数；驱动保留私有工程、共享引擎锁、生产与玩家目录保护、PID/nonce及原始日志。导入上限600秒，江州组件/自然进程和野猪林组件420秒，其余玩法240秒。自然路线禁止演员传送、阶段注入和时间加速，组件夹具另行标记。实现及完整剩余门槛见[江州交接](../../docs/JIANGZHOU_WORLD_RESTORE_20260913.md)。

组件有九个独立槽，覆盖真实训练队列、燕顺/张横 Q 召唤、有限敌产、两次囚徒替换、先后登船、固定开船回调和死亡引用；其摆位、回调推进与致死伤害属于显式夹具。自然七进程只用真实命令、付费训练、技能和战斗，保留宋江先解缚、追兵释放后护送、白龙庙会合、宋江先登船等断点，最后实际开船并由新进程验证 `LOCAL_RUN_TERMINAL`。

地图保存验证精确限定为 60×58 town 的江州上下文。原八个人群标记只能使用固定坐标、`float 0.0` 尺寸和 `int(x+y)` 编号；普通装饰尺寸仍须为正。`paid_queue` 从实际读回的槽执行三个 MapState 负例：人群尺寸改 `1.0`、人群编号偏移、普通装饰尺寸改 `0.0`，分别要求 `DECOR_CROWD` / `DECOR_VALUE` 和准确装饰路径。另比较八人朝向/编号/贴图、五个路牌，以及完整人物图、关卡、金木、队列和任务状态。

后续独立审查补齐 `d[0]` 的先类型检查，并增加第四项 MapState 负例：普通装饰首项改为 `Vector2(1,2)`，实际 Codec 编码后验证必须返回 `DECOR_VALUE` 及该装饰路径，不能出现脚本异常。

## 失败历史（不可改写为成功）

| 批次 | 导入方式 | 失败与修正 |
| --- | --- | --- |
| [072428_863226ed](../level3_world_restore_20260909/20260913_072428_863226ed/receipt.json) / [组件日志](../level3_world_restore_20260909/20260913_072428_863226ed/level2_component.log) | fresh | UnitGraph 捕获拒绝江州定义覆写中的新增 `StringName` 键；改为生产显式 String 下标。 |
| [073149_138ae1f2](../level3_world_restore_20260909/20260913_073149_138ae1f2/receipt.json) / [组件日志](../level3_world_restore_20260909/20260913_073149_138ae1f2/level2_component.log) | 缓存诊断 | QA 重复编码全部已编码图失败，原日志未带具体底层 code/path；改为完整 graph/level 原值比较、额外小快照单独 Codec，并补诊断。 |
| [073714_a77604d5](../level3_world_restore_20260909/20260913_073714_a77604d5/receipt.json) / [组件日志](../level3_world_restore_20260909/20260913_073714_a77604d5/level2_component.log) | 缓存诊断 | Session 保存报地图 `DECOR_VALUE`，路径 `$/header/decor/15`；按固定八人规则接入既有人群零尺寸，并新增上述三项负例。 |

三批均 `complete=false`、`acceptance_complete=false`、runner `checks=0`，未进入自然路线。均有 `source_changes=[]`、`lock_released=true`、`engines_after=[]`。修正不放宽共享 Codec，后续诊断结果仍需另外绑定实际收据；缓存复用不能当作 fresh 验收。

## 上一版本缓存专项结果

074244_559c84ea 的[组件报告](../level3_world_restore_20260909/20260913_074244_559c84ea/level2_component_report.json) 379 项全部通过；自然 save/alarm/rescue/escort/board/finish/terminal_reject 依次 27/58/58/61/61/54/12 项，共 331 项全部通过。[真实胜利报告](../level3_world_restore_20260909/20260913_074244_559c84ea/level2_cross_finish_report.json) 为 4/4 故事目标，八人均已登船；[终局拒绝报告](../level3_world_restore_20260909/20260913_074244_559c84ea/level2_terminal_reject_report.json) 返回 `LOCAL_RUN_TERMINAL`。

该批 `complete=true`，但 `fresh_import=false`、`full_suite=false`、`acceptance_complete=false`。源码无运行中变化、玩家目录保护、锁释放与无遗留引擎均由该收据记录。人工目检限于本批[首次保存](../level3_world_restore_20260909/20260913_074244_559c84ea/level2_cross_save_report_saved.png)、[登船保存](../level3_world_restore_20260909/20260913_074244_559c84ea/level2_cross_board_report_saved.png)、[胜利画面](../level3_world_restore_20260909/20260913_074244_559c84ea/level2_cross_finish_report_victory.png)三张代表图。

本次710项是在地图装饰类型守卫补齐前取得的缓存诊断证据。修正版本的后续全新候选 `080826_d5b19593` 已因QA断言失败结束，详情见下节；最终085554完整世界、084224经典及联合核验另列顶部，不把此前缓存专项填写为正式验收完成。

## 全新第五候选主动中止

[075432_74ed99f6 收据](../level3_world_restore_20260909/20260913_075432_74ed99f6/receipt.json) / [导入日志](../level3_world_restore_20260909/20260913_075432_74ed99f6/import.log)：独立审查发现装饰首项比较前缺少类型守卫，根任务在导入期受控停止，driver 退出 1，未运行其他用例。`complete=false`、`acceptance_complete=false`、`total_checks=0`；`fresh_import=true`、`full_suite=true` 只说明候选计划范围。`source_changes=[]`、`protected_player_unchanged=true`、`lock_released=true`、`engines_after=[]` 均已记录。生产守卫及第四项负例补齐后另启全新批，原中止收据不改写为通过。

## 全新第六候选主动中止

[080022_e11ca7f0 收据](../level3_world_restore_20260909/20260913_080022_e11ca7f0/receipt.json) / [导入日志](../level3_world_restore_20260909/20260913_080022_e11ca7f0/import.log)：根任务预查发现 `level6_world_restore_qa.gd` 的未接入关卡负例仍指新增的 `level2`，在导入期受控停止候选后改为未接入的 `level4`，既有组件 183 项检查保持。该批没有玩法运行结果，`total_checks=0`、`complete=false`、`acceptance_complete=false`；此次是 QA 兼容性预查后的主动中止，不是生产回归失败，不能计为全量通过。源码/玩家目录未变、锁释放且无遗留引擎均有原始收据；兼容性核查完成后下一全新候选 `080826_d5b19593` 已启动，原中止收据保持不变。

## 第七候选 fresh 完整批失败

[080826_d5b19593 收据](../level3_world_restore_20260909/20260913_080826_d5b19593/receipt.json) 为 `fresh_import=true`、`full_suite=true`，但 `complete=false`、`acceptance_complete=false`。前 19 用例、江州组件 381 项和 save/alarm/rescue 的 27/58/58 项通过；`total_checks=1440` 是截至失败时 runner 已记录的数量，不是整批通过总计。[escort 报告](../level3_world_restore_20260909/20260913_080826_d5b19593/level2_cross_escort_report.json) 61 项中仅付费敌产断言失败，[原日志](../level3_world_restore_20260909/20260913_080826_d5b19593/level2_cross_escort.log) 保留。board/finish/terminal 未运行，不能计为完整通过；源码/玩家未变、锁释放且无遗留引擎均有原始记录。

恢复前后敌产1、累计支出25金8木、敌池153/92一致；护送终态实际敌产2、累计支出50金16木、敌池160/84。生产的对称击杀赏金可把金币补回160，因此旧QA的净余额 `<160` 误报。仅将其改为累计产量1..8、增援角色槽数、刀/刀/弓精确金木购买账和敌木材 `100-spent_wood`，不要求已死增援仍存活，也不改自然操作或生产合同。原失败收据不变；随后085554全新完整批与084224同版经典、联合核验均已通过，不能据此改写本失败批。

本轮内部里程碑已完成。接下来快活林，再连环马、高俅、大名府；快活林隔离候选尚未晋级或原生测试。完整30波最终同版、九玩法统一回归、真实Steam持久确认、1800秒/性能、双机双账号及真人验收仍保留，`PLAYER_ENTRY=false`，本轮没有新打包或Steam发布。
