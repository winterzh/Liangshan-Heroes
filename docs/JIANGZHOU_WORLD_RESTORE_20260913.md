# 江州整世界保存与恢复（2026-09-13）

从 stable `d2372ae28d7958fa6e5849f23f5fbf031cb8ea62` 按[统一计划](CONTINUE_DELIVERY_20260908.md)推进，江州内部整世界恢复里程碑已完成。全新默认27用例世界批 `20260913_085554_ae1d1fcb` 通过1628项，同版经典全新默认 `20260913_084224_c71345c4` 完整296项通过，联合核验通过。`PLAYER_ENTRY=false`，本轮未打包或发布Steam；最近正式构建仍以[发布交接](STEAM_UPDATE_20260913.md)为准。下方失败、中止和缓存专项记录保持原结论。

## 最终全新批与联合核验

[085554世界原始收据](../qa/level3_world_restore_20260909/20260913_085554_ae1d1fcb/receipt.json) 的 `complete/full_suite/fresh_import/acceptance_complete` 均true。1628项全部来自这一个全新默认批：既有19用例在本批重跑916项，江州[组件381项](../qa/level3_world_restore_20260909/20260913_085554_ae1d1fcb/level2_component_report.json)，自然 save/alarm/rescue/escort/board/finish/terminal_reject 分别27/58/58/61/61/54/12项，共331项。[真实胜利报告](../qa/level3_world_restore_20260909/20260913_085554_ae1d1fcb/level2_cross_finish_report.json) 确认八名角色登船、实际开船和4/4；[终局新进程](../qa/level3_world_restore_20260909/20260913_085554_ae1d1fcb/level2_terminal_reject_report.json) 对前一保存槽返回 `LOCAL_RUN_TERMINAL`。

[084224经典原始收据](../qa/continue_flow_20260909/20260913_084224_c71345c4/receipt.json) 为全新默认完整296项通过、退出0。联合验证器已通过，[validation_summary.json](../qa/jiangzhou_world_restore_20260913/validation_summary.json) 确认两批与当前checkout的2962份生产文件完全同SHA，`world_qa_source_differences=[]`；生产清单SHA256为 `2809029c4e399502ada5b8534f92b75b1c8128e1a3fd6f8c2cef46440f09bdc0`，世界原始收据SHA256为 `6e0adc72a8568ab69712494e371d0a1d0016abf81af11f05ab8ad226d73e03ea`。源码无运行中漂移、玩家档未变、锁已释放，未遗留引擎。完整复现命令见[QA说明](../qa/jiangzhou_world_restore_20260913/README.md)。

江州11张及经典16张PNG全部通过SHA核验。人工目检仅本批江州[首次保存](../qa/level3_world_restore_20260909/20260913_085554_ae1d1fcb/level2_cross_save_report_saved.png)、[宋江先登船保存](../qa/level3_world_restore_20260909/20260913_085554_ae1d1fcb/level2_cross_board_report_saved.png)、[胜利结果](../qa/level3_world_restore_20260909/20260913_085554_ae1d1fcb/level2_cross_finish_report_victory.png)，以及经典[中文覆盖确认](../qa/continue_flow_20260909/20260913_084224_c71345c4/screenshots/overwrite_confirm_zh_CN.png)、[英文终局等待](../qa/continue_flow_20260909/20260913_084224_c71345c4/screenshots/terminal_pending_en.png)，共五张代表画面；文字可读，无明显问题。这不表示27张全部目检，也不是性能或真人验收。

## 本轮实施与验收要求

固定选型 `campaign_level2_v1` 仅对应已安装的 `level2_jiangzhou_rts.gd`。接入有限金木、两营付费训练、敌方有限生产、任务进度、两次囚徒替换、追兵、护送和登船。恢复不重跑开局部署或奖励回调，使用独立人物、景物和视觉分区合同。

江州地图为 60×58 town；围观者朝向与静态贴图在离树准备中按原工厂确定，五个路牌和既有景物均需保留。开船按钮使用固定 `jiang_depart` 回调；关卡中的按钮引用在 Mission 界面重建后绑定实际禁用控件，再随整世界事务一起启用。

人物图使用独立 `level2_unit_graph_v1` / `level2_unit_state_v1`，区分两名绑缚者与两次新建的获救实体、六名具名本体、原有追兵和有限付费增援。已登船者按实际玩法继续保留在 `Battle.units` 与节点根下，只隐藏并停止指令；移动单位死亡保留动画窗口，建筑拆毁按实际回调释放。燕顺 Q 的虎与张横 Q 的复制体也按真实技能来源单独校验。

MapState 仅在精确 `level2` 官方上下文允许既有围观标记的零尺寸：固定八格 `(24,17)、(25,21)、(26,14)、(33,14)、(36,18)、(35,23)、(24,24)、(38,22)`，四项格式 `crowd / Vector2i / float 0.0 / int(x+y)`。尺寸不参与这类人群绘制；普通装饰仍要求正尺寸。组件会从真实保存槽取出地图，分别修改人群尺寸为 `1.0`、编号偏移、普通装饰尺寸为 `0.0`，要求 MapState 拒绝并报告对应装饰路径。八人朝向、variant、贴图与五个路牌另做保存前后比较。

装饰类型判定先检查 `typeof(d[0]) == TYPE_STRING`，再与 `crowd` 比较。组件新增第四项地图负例：把普通装饰首项改为 `Vector2(1,2)`，经 Codec 编码后调用实际 MapState.validate，要求返回 `DECOR_VALUE` 与准确路径，不以脚本异常代替拒绝。

组件夹具与自然路线分开记录。自然路线通过真实指令、原价补兵与实际战斗分七进程覆盖训练开局、起事、先救宋江、双人护送、单人登船、全员安全撤离与开船胜利，最后由新进程拒绝终局旧槽。不得用传送、阶段注入、伤害修改、造兵或时钟加速代替这条路线。

组件使用九个独立槽覆盖付费训练队列、真实技能召唤、起事与取粮/敌军生产、先后解缚、单人登船、开船按钮就绪、追兵死亡动画、追兵与巡防营释放后的引用。夹具中的摆位、推进关卡回调和致死伤害均明确标记。整槽比较保留 Graph.capture 已验证的完整人物/关卡记录，只对额外资源、时钟、选择和任务快照单独编码，避免将全部已编码记录再次挤入单个 Codec 的预算；没有放宽共享 Codec。

本轮已完成包含既有章节和江州专项的全新默认世界批、同版经典默认回归及联合核验，覆盖生产文件、PID/nonce、保存链、检查项与原生图像。原始失败和缓存诊断收据原样保留，不追记为整批成功，也不重复计入1628项。证据入口：[QA](../qa/jiangzhou_world_restore_20260913/README.md)。

## 已发生的失败批次

以下三批均为 `complete=false`、`acceptance_complete=false`，runner 汇总检查数为 0，没有自然路线结果；原始收据和日志保持原样。后续第四批缓存专项的实际结果单独记录如下。

| 原始批次 | 实际停止位置与后续修正 |
| --- | --- |
| [072428_863226ed 收据](../qa/level3_world_restore_20260909/20260913_072428_863226ed/receipt.json) / [日志](../qa/level3_world_restore_20260909/20260913_072428_863226ed/level2_component.log) | 全新导入后，付费队列组件在 UnitGraph 捕获时报 `CODEC_UNSUPPORTED_TYPE`。江州定义覆写新增键使用了 `StringName`；生产改为显式 String 下标，未修改 Codec。 |
| [073149_138ae1f2 收据](../qa/level3_world_restore_20260909/20260913_073149_138ae1f2/receipt.json) / [日志](../qa/level3_world_restore_20260909/20260913_073149_138ae1f2/level2_component.log) | 缓存诊断中 UnitGraph 捕获已推进通过，但 QA 对整张已编码图再次调用 Codec 失败，当时未打印底层 code/path。改为完整记录独立精确比较及额外小快照单独编码，并补失败路径诊断。 |
| [073714_a77604d5 收据](../qa/level3_world_restore_20260909/20260913_073714_a77604d5/receipt.json) / [日志](../qa/level3_world_restore_20260909/20260913_073714_a77604d5/level2_component.log) | 缓存诊断的实际 Session 保存到地图验证时，报 `DECOR_VALUE`、`$/header/decor/15`。既有 authored crowd 尺寸为未消费的 `0.0`，与通用正尺寸约束冲突；按上述固定八格规则接入并新增三项坏档负例。 |

三批均记录 `source_changes=[]`、锁已释放且无遗留引擎。缓存诊断即使后续通过，也不能替代全新默认完整批及同版经典回归。

## 上一版本缓存专项诊断（不计最终验收）

[074244_559c84ea 原始收据](../qa/level3_world_restore_20260909/20260913_074244_559c84ea/receipt.json) 为 `complete=true`、`total_checks=710`，其中[组件报告](../qa/level3_world_restore_20260909/20260913_074244_559c84ea/level2_component_report.json) 379 项，七个自然进程依次 27/58/58/61/61/54/12 项，共 331 项。真实付费训练、先后解缚、追兵与西路护送、白龙庙会合、八名角色登船和实际开船已贯通；[终局报告](../qa/level3_world_restore_20260909/20260913_074244_559c84ea/level2_cross_finish_report.json) 取得 4/4 故事目标，[下一进程](../qa/level3_world_restore_20260909/20260913_074244_559c84ea/level2_terminal_reject_report.json) 对原槽返回 `LOCAL_RUN_TERMINAL`。

该批 `fresh_import=false`、`full_suite=false`、`acceptance_complete=false`，仍是缓存复用的江州专项证据。收据记录源码无运行中变化、玩家目录保护通过、锁释放且无遗留引擎。人工目检范围为本批[训练开局保存](../qa/level3_world_restore_20260909/20260913_074244_559c84ea/level2_cross_save_report_saved.png)、[宋江先登船保存](../qa/level3_world_restore_20260909/20260913_074244_559c84ea/level2_cross_board_report_saved.png)、[胜利结果](../qa/level3_world_restore_20260909/20260913_074244_559c84ea/level2_cross_finish_report_victory.png)三张代表画面。

本批710项是地图装饰类型守卫补齐前的缓存诊断证据，不能代表修正版本已验证。后续全新候选 `080826_d5b19593` 的失败另见下节；最终085554完整世界、084224经典及联合核验另列顶部，本节仍不构成正式验收完成结论。

## 第五候选导入期主动中止

[075432_74ed99f6 原始收据](../qa/level3_world_restore_20260909/20260913_075432_74ed99f6/receipt.json) / [导入日志](../qa/level3_world_restore_20260909/20260913_075432_74ed99f6/import.log)：独立审查发现 `d[0]` 与字符串比较前缺少类型守卫，根任务在导入阶段受控停止该候选，未进入其他用例。driver 退出 1；收据为 `complete=false`、`acceptance_complete=false`、`total_checks=0`，保留 `fresh_import=true` / `full_suite=true` 的计划范围，不能据此计为通过。源码无运行中变化、玩家目录保护、锁释放与无遗留引擎均有原始记录。随后生产补先类型检查、QA 补上述 Vector2 坏档负例，下一轮重新执行全新完整批。

## 第六候选导入期主动中止

[080022_e11ca7f0 原始收据](../qa/level3_world_restore_20260909/20260913_080022_e11ca7f0/receipt.json) / [导入日志](../qa/level3_world_restore_20260909/20260913_080022_e11ca7f0/import.log)：根任务预查发现野猪林组件中“未接入关卡必须拒绝”的负例仍指向此次新增的 `level2`，在导入阶段受控停止后，将该负例改为仍未接入的 `level4`，保留既有 183 项检查。该候选未运行玩法用例，`total_checks=0`、`complete=false`、`acceptance_complete=false`，不是生产回归失败，也没有全量通过结论。原始收据记录源码和玩家目录未变、锁已释放、无遗留引擎；兼容性核查完成后，下一全新 27 用例候选 `080826_d5b19593` 已启动，该中止批仍保持原失败状态。

后续依次快活林、连环马、高俅、大名府；快活林隔离候选未晋级或原生测试。最终版本完整30波和九玩法统一回归、真实Steam持久确认、1800秒长跑、性能、双机/双账号和真人验收仍未完成。`PLAYER_ENTRY=false`，本轮没有打包或发布Steam。

## 第七候选：全新完整批因 QA 金币净额断言失败

[080826_d5b19593 原始收据](../qa/level3_world_restore_20260909/20260913_080826_d5b19593/receipt.json) 使用已补 Vector2 装饰类型守卫、野猪林未接入负例改为 level4 的冻结版本，实际执行 fresh 默认 27 用例。既有 19 用例、江州组件 381 项、save/alarm/rescue 的 27/58/58 项已通过，收据 `total_checks=1440` 是 runner 截止失败时已记录的数量，不是整批通过总计；[护送报告](../qa/level3_world_restore_20260909/20260913_080826_d5b19593/level2_cross_escort_report.json) 61 项中只有 `paid finite patrol reinforcements existed during rescue` 失败，后续 board/finish/terminal 未运行。该批 `complete=false`、`acceptance_complete=false`，没有全量通过结论；源码和玩家目录未变、锁释放且无遗留引擎均由收据记录。

[日志](../qa/level3_world_restore_20260909/20260913_080826_d5b19593/level2_cross_escort.log) 中 `recruits=11` 是中途玩家付费招兵数。实际 rescue 保存与 escort 恢复均为敌产 1、累计花费 25 金 8 木、敌池 153 金 92 木，恢复状态一致；护送终态已敌产 2、累计花费 50 金 16 木、敌池 160 金 84 木。`Battle._on_unit_died` 的对称击杀赏金会补入敌方金币，因此 `faction_gold(1) < 160` 不能证明是否真实付费，也不能作为正确的拒绝条件。

仅QA改为验证累计产量1..8、增援角色槽数、按刀/刀/弓实际价格累计的精确金木账，以及无赏金补入的敌木材 `100 - spent_wood`；原断言标签/数量、自然操作和生产合同保持。死亡增援保留空角色槽，累计购买数不等于当前活体数。原失败收据不重写；随后已用085554全新27用例批完整重跑，同版经典与联合结果见顶部，不把本失败批改记为通过。

最终同版经典 `20260913_084224_c71345c4` 已完整296项通过；其后执行的全新默认世界 `20260913_085554_ae1d1fcb` 已完整1628项通过，2962份生产来源联合核验通过。当前后续工作为快活林，不再等待本轮测试结果。
