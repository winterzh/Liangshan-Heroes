# 野猪林整世界保存与恢复（2026-09-13）

基线为 stable `de0f8bd6`。全新默认世界批 `20260913_040000_60d3e221` 已916项通过：同版既有任务核心/祝家庄/黄泥冈425项，野猪林组件183项、七进程308项。原收据 `complete`、`full_suite`、`fresh_import`、`acceptance_complete` 均为true，完整覆盖当前驱动19个用例；四人实际出林、3/3与终局旧槽拒绝通过。[世界原始收据](../qa/level3_world_restore_20260909/20260913_040000_60d3e221/receipt.json)。

经典全新默认批 `20260913_042455_e8f43126` 已296项通过、退出0，原收据 `complete=true`、`fresh_import=true`、`terminal_only=false`。[经典原始收据](../qa/continue_flow_20260909/20260913_042455_e8f43126/receipt.json)。联合核验退出0，两批与当前checkout的2960份生产文件逐文件同SHA，世界11张路线图及经典16张图SHA均通过。[核验汇总](../qa/yezhulin_world_restore_20260913/validation_summary.json)。世界收据中的 `acceptance_complete` 仅指当前默认QA集合，不代表九玩法全部交付。玩家保存/继续入口保持隐藏，本轮未打包、上传或发布 Steam；所有失败、缓存与旧分阶段收据保持原状。

## 实现范围

- 官方 profile 为 `campaign_level6_v1`，固定上下文为 `{"mode":"campaign","level_id":"level6","waves":0}`，只对应已安装的 `level6_yezhulin.gd`。`run_level6_world_factory.gd` 准备本关定义与能力，恢复时不重跑 `deploy` 或 `on_start`，不从存档加载替代脚本或任意工厂。
- 景物使用 `level6_scenery_state_v1`，核对本关 `environment_style=level6`、52×40、`marsh` 地图及原生景物。通过 WorldCore、Session 和保存屏障接入完整世界安装，不能借用黄泥冈或祝家庄上下文接受错关档。
- 野猪林战斗根固定为无经济系统，恢复拒绝把 `economy` 改成 true 的档案，并有编码后的坏档负例对应检查。
- 单位使用独立 `level6_unit_state_v1` / `level6_unit_graph_v1` 合同。角色从已验证的关卡记录派生：鲁智深、当前林冲形态、按原顺序保留的董超/薛霸；检查角色身份、阶段、存活及活动成员、剧情姿态和护送命令序号。
- 林冲有两次真实实体替换：开局披枷林冲到松树后换为绑树林冲，解缚后再换为护送林冲。恢复保留当前角色的 `entity_id`、阶段与血量，不重新生成已退出的旧形态。鲁智深从开局即存在；“现身”是拦棍动作及剧情姿态，董超/薛霸也是原有押解者，本关没有新增追兵军团。
- 关卡保存包含救援倒计时、求情/照料进度、南北跟随状态、护送目标与令牌，以及四人的真实位置、路径、命令和姿态。死亡动画尚在时保留非活动的死亡实体；释放后允许经角色身份约束的旧护送命令键，不复活死者。
- 保存屏障进入HELD后、发送 `capture_ready` 前，刷新固定ShadowBatch派生的buffer/retained/count，消除最后一个physics帧死亡释放后尚未idle清理的显示引用；不推进单位、任务、时钟或RNG。
- 裸建选择按钮改用已有 `add_level_button` 与固定 `activate_mission_button`：`pine_lu` 选择鲁智深，`pine_group` 选择当前存活相送队伍。存档保存稳定按钮 ID，恢复后仍通过本关固定回调选择真实角色。

## 组件夹具与自然路线分开记录

`tools/level6_world_restore_qa.gd` 是显式组件夹具。它先保存/恢复真实开局，再把已有演员摆到明确测试位置，以真实 `resolve_story("subdued")` 回调触发提前强救；随后显式推进关卡照料回调，检查绑树、解缚、解差重新护送和整槽安装。它还清除一名解差的默认“制服”结局后调用真实伤害/死亡路径，分别覆盖死亡动画仍在根节点和动画释放后的旧命令引用，检查剩余三人的控制。

这些夹具使用独立本地槽，包含坏图 schema、错误/缺失林冲角色、解差顺序交换、错误活动成员和非法姿态等负例；固定选择按钮通过真实 `pressed` 信号检查。040000全新批[组件183项报告](../qa/level3_world_restore_20260909/20260913_040000_60d3e221/level6_component_report.json)全部通过。**夹具摆位、显式时间步进和死亡故障设置不计自然玩法通关。**

`tools/level6_cross_process_qa.gd` 则使用七个独立进程共享私有槽 `user://level6_continue/v1`，沿现有短关南侧芦丛路线，通过真实选择与 `minimap_order` 自然推进；无演员传送、阶段注入、直接完成任务或时钟加速。

| 进程 case | 自然推进和保存边界 |
| --- | --- |
| `level6_cross_save` | 鲁智深向南侧芦丛移动，押解林冲仍在行进，保存未结束的跟随路线。 |
| `level6_cross_rescue` | 恢复原路线至松树，核对第一次林冲替换；实际点击拦棍旗标，保存尚未完成的0.8秒办理进度和救援倒计时。 |
| `level6_cross_care` | 原拦棍命令接续完成，保存林冲求情、鲁智深拦棍姿态、两名解差眩晕及未结束的解缚计时。 |
| `level6_cross_escort` | 自然解缚、照料并完成第二次林冲替换；由玩家实际下达歇脚命令，保存四人护送在途。 |
| `level6_cross_leave` | 接续抵达歇脚点并获得留命/训诫事件，再实际下达出林命令，保存新的四人行进路线。 |
| `level6_cross_finish` | 原出林命令继续，要求四人实到出口、3/3剧情目标，以及本地终局收据持久提交后显示原生结果面板。 |
| `level6_terminal_reject` | 新进程读取未改写的出林在途旧槽，要求明确返回 `LOCAL_RUN_TERMINAL` 并保留菜单。 |

每次接续核对前一进程、不同 PID/nonce、槽 SHA、冻结内容版本、角色引用、阶段/任务/路径/姿态/时钟及原生景物。两次替换均检查旧林冲 ID 不残留；原鲁智深及两名解差的身份应贯穿自然路线。若歇脚动作要求同伴到齐后重试，QA 仅在四人真实到达后重新右键旗标，最多三次，不直接补事件或治疗。

## 复现与收据

普通玩家仍使用 `Play.cmd`。配置本机被忽略的 `godot.local.txt` 或 `GODOT_PATH` 后，可用本机 Python 3 执行以下野猪林专项；`--work-root` 可换为本机存在磁盘上的短路径：

```powershell
py -3 -X utf8 -B tools/run_level3_world_restore_qa.py --work-root E:/CodexTemp/yezhulin_restore --cases level6_component level6_cross_save level6_cross_rescue level6_cross_care level6_cross_escort level6_cross_leave level6_cross_finish level6_terminal_reject --run
```

沿用的驱动名及证据组为 `run_level3_world_restore_qa.py` / `qa/level3_world_restore_20260909/`，现已涵盖多个官方章节。省略 `--cases` 的默认批还包含任务核心 `freeplay_core`、祝家庄、黄泥冈组件和既有跨进程回归；本轮先跑野猪林专项。专项即使全部通过，也不能将 `full_suite` 或 `acceptance_complete` 写为 true。`--cache-from` 仅供显式诊断复用，实际缓存来源写入收据。

驱动建立私有工程与玩家目录、禁用 Steam、独占共享引擎锁，并记录原始脚本/生产依赖、真实进程 PID/nonce、检查数、图像和源码保护结果。内部环境变量为 `LSH_LEVEL6_CASE`、`LSH_LEVEL6_STATE`（报告路径）、`LSH_LEVEL6_NONCE`，私有目录防护沿用通用 `LSH_LEVEL3_RESTORE_PROFILE`；不写入玩家启动配置。

040000全新默认世界批实际916项通过，包含19个用例及导入/profile_guard两个保护步骤；野猪林七进程25/55/53/57/58/48/12合计308项。收据记录 `source_changes=[]`、`protected_player_unchanged=true`、`lock_released=true`、`engines_after=[]`。这里的425项由同一个040000批重新执行，没有借用旧分阶段证据。[本轮证据汇总与核验](../qa/yezhulin_world_restore_20260913/README.md)。

经典042455全新默认回归296项通过，13个步骤均达到预期退出码，日志错误扫描0条；`source_guard_checks=5928`、`source_changes=[]`、`lock_released=true`。联合核验已回读完整生产集合、两批源快照、当前checkout、报告和图像，生产清单SHA为 `e3230d4733b409fdbb06edd71f2b8724c5672a385c37fc51bc5c1730347396ec`，`world_qa_source_differences=[]`。两个QA驱动的资源导入时限均为600秒，普通玩法240秒、野猪林组件420秒。失败或主动中止批次保留原始收据和日志，不追记为通过，也不改写子集/缓存批的原始 `acceptance_complete`。

本轮联合核验的完整命令如下，仅回读证据，不运行Godot；`--write-summary` 只写本轮汇总文件：

```powershell
py -3 -X utf8 -B qa/yezhulin_world_restore_20260913/verify_evidence.py --full-world qa/level3_world_restore_20260909/20260913_040000_60d3e221/receipt.json --classic-receipt qa/continue_flow_20260909/20260913_042455_e8f43126/receipt.json --write-summary
```

## 最终世界批代表画面

040000全新批已目检以下3张代表画面：

- [拦棍办理中保存](../qa/level3_world_restore_20260909/20260913_040000_60d3e221/level6_cross_rescue_report_saved.png)：倒计时与底部指令区无遮挡。
- [林冲求情保存](../qa/level3_world_restore_20260909/20260913_040000_60d3e221/level6_cross_care_report_saved.png)：求情文字与底部指令区无遮挡。
- [四人出林胜利](../qa/level3_world_restore_20260909/20260913_040000_60d3e221/level6_cross_finish_report_victory.png)：3/3、四人出林文案及三个结果按钮清楚。

路线共归档11张原生PNG，完整SHA复核已通过；这11张不全部计为人工目检。经典042455批另目检以下2张代表画面：

- [中文覆盖确认](../qa/continue_flow_20260909/20260913_042455_e8f43126/screenshots/overwrite_confirm_zh_CN.png)：覆盖说明和两个按钮清楚无遮挡。
- [英文终局等待](../qa/continue_flow_20260909/20260913_042455_e8f43126/screenshots/terminal_pending_en.png)：终局说明和两个按钮清楚无遮挡。

经典16张四语状态图SHA均通过，仅以上2张计为本轮人工目检。图像SHA检查不代替人工审阅，画面上的瞬时FPS不作为性能验收。

## 本轮尝试记录

`20260913_032402_2721a50a` 在导入期间主动中止，0项检查，`complete=false`。当时只读审计发现组件快照把 `PackedVector2Array` 直接交给不支持该类型的 Codec，并误用 `Unit._process` 推进死亡动画；尚未执行到这两个检查点，不写成实际引擎报错。仅停止已核实属于本批的 Godot PID16584，runner 的原始收据以通用 `import failed; see archived log` 记录退出；已核对 `lock_released=true`、无遗留引擎且来源未变化。[原始收据](../qa/level3_world_restore_20260909/20260913_032402_2721a50a/receipt.json)。

随后组件QA将路径转换为普通 Array 并增加编码成功门槛，改用真实 `_physics_process` 推进死亡动画；生产根合同另收紧野猪林 `economy=true` 拒绝并补坏档负例，进入下述032721全新批。

`20260913_032721_5ec2066f` 的全新导入和 `profile_guard` 均达到预期退出码；组件报告实际执行162项，160项通过、2项失败，进程退出1且日志扫描无引擎错误。`untied fixed selection button restored` 属于QA错误预期：解缚后的CARE阶段原本没有选择按钮；`expired_guard actual Session save` 被 `DISPLAY_SHADOW_REFERENCE` 拒绝，死亡实体释放后的显示引用尚待诊断，不预断根因。runner未进入自然路线，原收据 `complete=false`、`acceptance_complete=false`、累计 `checks/total_checks=0`，不能用组件报告的160项覆盖原始整批状态；锁已释放、无遗留引擎、源码未变化。[原始收据](../qa/level3_world_restore_20260909/20260913_032721_5ec2066f/receipt.json) · [失败组件报告](../qa/level3_world_restore_20260909/20260913_032721_5ec2066f/level6_component_report.json)。

该显示问题随后确认为捕获竞态：死亡单位已在最后一个physics帧释放，但屏障先暂停了世界，ShadowBatch来不及idle清理。已按上文HELD边界刷新精确的派生显示数据；组件新增“捕获前残留→HELD清空→恢复无残留”三处断言。按钮检查改为源阶段真实描述符对照，CARE期没有按钮也是正确状态。

缓存诊断批 `20260913_033816_d3ee8aa1` 组件192项中183项通过、9项失败，9项均为QA把任务动作按钮误当作固定选人按钮的 `only installed selection callback` 断言；六次Session往返及三个阴影边界断言均通过。整批仍失败，`fresh_import=false`、`source_changes=[]`、`lock_released=true`。[原始收据](../qa/level3_world_restore_20260909/20260913_033816_d3ee8aa1/receipt.json) · [组件报告](../qa/level3_world_restore_20260909/20260913_033816_d3ee8aa1/level6_component_report.json)。随后QA仅对 `descriptor.kind=level` 检查并触发固定选人回调，所有按钮描述符仍与源状态精确比较；生产逻辑未因这9项错误再改动。

缓存诊断批 `20260913_034128_8190c980` 最终 `complete=true`、491项通过：组件183项，七进程25/55/53/57/58/48/12合计308项，四人实际出林、3/3和明确 `LOCAL_RUN_TERMINAL` 拒绝均通过。`source_changes=[]`、`lock_released=true`，但 `fresh_import=false`、`acceptance_complete=false`；本轮缓存诊断不代替后续全新默认世界和全新经典回归。[原始收据](../qa/level3_world_restore_20260909/20260913_034128_8190c980/receipt.json)。诊断的保存首图、求情图及胜利图已由主代理目检，胜利图显示3/3、四人出林文案和清晰结果按钮；此目检仅对应诊断图，最终全新图像另验。

完整默认全新批 `20260913_035452_57cab55a` 在资源导入240.27秒后由外层时限终止，日志至98%导入进度，未完成导入，也未进入任何玩法。原收据 `complete=false`、`acceptance_complete=false`、`fresh_import=true`、0项检查；导入步骤 `stop_reason=timeout`、错误扫描0条、`source_changes=[]`、`lock_released=true`、无遗留引擎。[原始收据](../qa/level3_world_restore_20260909/20260913_035452_57cab55a/receipt.json)。此后仅将 `tools/run_level3_world_restore_qa.py` 和 `tools/run_continue_flow_qa.py` 的资源导入时限调整为600秒，普通玩法仍为240秒、野猪林组件420秒；不修改生产逻辑或玩法断言。后续040000全新默认批916项通过，结果见上文，不改写本批失败状态。

## 历史证据与交付边界

基线前黄泥冈的425项为分阶段世界恢复证据：`20260913_021853_de632b8f` 六进程258项，加 `20260913_015956_3bc1fd31` 已通过的前段167项；旧完整批仍失败，新六进程仍是子集。2958份生产文件同 SHA 的核对结论属于该轮冻结来源，不能自动延伸为本次修改后的同版回归。[黄泥冈原始说明与汇总](../qa/huangnigang_world_restore_20260913/README.md)。经典默认回归296项通过另见 [`20260913_024947_f6a8c09f` 收据](../qa/continue_flow_20260909/20260913_024947_f6a8c09f/receipt.json)，也保留其原版本边界。

野猪林已通过本轮完整默认世界验证、经典042455默认回归及联合证据核验，后续继续江州、快活林、连环马、高俅、大名府。完整30波同版重验、九玩法统一回归、真实 Steam 持久确认、1800秒长跑、性能、双机/双账号及真人检查仍按[统一交付计划](CONTINUE_DELIVERY_20260908.md)执行。组件或单条南路通过均不代表全部分支和九玩法验收，也不构成玩家入口或 Steam 发布授权。
