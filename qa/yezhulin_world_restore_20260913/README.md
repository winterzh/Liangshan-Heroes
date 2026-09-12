# 野猪林世界恢复：完整默认世界与经典同版验证（2026-09-13）

全新默认世界批 `20260913_040000_60d3e221` 已916项通过：同版任务核心/祝家庄/黄泥冈425项、野猪林组件183项、七进程308项；19用例及导入/profile_guard均达到预期，原收据 `complete/full_suite/fresh_import/acceptance_complete` 均true。四人实际出林、3/3与 `LOCAL_RUN_TERMINAL` 通过。**本轮世界主证据只取这一新完整批，不复用旧分阶段来源。**

经典全新默认批 `20260913_042455_e8f43126` 已296项通过、退出0，`complete=true`、`fresh_import=true`、`terminal_only=false`。[经典收据](../continue_flow_20260909/20260913_042455_e8f43126/receipt.json)。联合核验退出0，两批与当前checkout的2960份生产文件逐文件同SHA，世界11张路线图及经典16张图SHA通过；[核验JSON](validation_summary.json)。生产清单SHA为 `e3230d4733b409fdbb06edd71f2b8724c5672a385c37fc51bc5c1730347396ec`，`world_qa_source_differences=[]`。世界批已记录源码无变化、玩家目录保护通过、锁释放及无遗留引擎。当前默认驱动验收标志不代表九玩法全部完成，玩家入口仍隐藏。本目录不修改任何原始收据、报告或日志。

| 批次 | 已确认事实 | 边界 |
| --- | --- | --- |
| [032402](../level3_world_restore_20260909/20260913_032402_2721a50a/receipt.json) | 导入期间主动中止，0项检查；锁释放，无遗留引擎 | 只读审计发现组件代码问题后停止已核实的私有引擎，未执行到相应检查点；不写成实际引擎报错。 |
| [032721](../level3_world_restore_20260909/20260913_032721_5ec2066f/receipt.json) | 导入/profile_guard达到预期退出码；[组件报告](../level3_world_restore_20260909/20260913_032721_5ec2066f/level6_component_report.json)162项，160项通过、2项失败 | CARE阶段无选择按钮属于QA错误预期；死亡解差释放后的保存被 `DISPLAY_SHADOW_REFERENCE` 拒绝。整批 `complete=false`、`acceptance_complete=false`，runner累计 `checks/total_checks=0`，未进入自然路线。 |
| [033816](../level3_world_restore_20260909/20260913_033816_d3ee8aa1/receipt.json) | 缓存诊断；[组件报告](../level3_world_restore_20260909/20260913_033816_d3ee8aa1/level6_component_report.json)192项，183项通过、9项失败；六次Session往返和三处阴影边界断言通过 | 9项均为QA误把任务动作按钮当成固定选人按钮；整批仍失败，`fresh_import=false`，源码无变化，锁已释放。 |
| [034128](../level3_world_restore_20260909/20260913_034128_8190c980/receipt.json) | `complete=true`，491项通过：组件183，七进程308（25/55/53/57/58/48/12）；四人实到、3/3、`LOCAL_RUN_TERMINAL`通过 | `fresh_import=false`、`acceptance_complete=false`；源码无变化，锁已释放。缓存专项通过不代替全新默认世界及同版经典回归。 |
| [035452](../level3_world_restore_20260909/20260913_035452_57cab55a/receipt.json) | 全新默认批的导入在240.27秒超时，进度日志至98%，0项检查，错误扫描0条 | 导入未完成、未进入玩法；整批false，源码无变化、锁释放、无遗留引擎。98%不计导入成功。 |
| [040000完整世界](../level3_world_restore_20260909/20260913_040000_60d3e221/receipt.json) | 916项全部通过，425+183+308；19默认用例，`complete/full_suite/fresh_import/acceptance_complete`均true | 源码无变化、玩家目录保护通过、锁释放、无遗留引擎；已与经典042455及当前checkout联合核验。 |
| [042455经典默认](../continue_flow_20260909/20260913_042455_e8f43126/receipt.json) | 296项通过、退出0；`complete/fresh_import`为true、`terminal_only=false`；13步骤均达到预期退出码，错误扫描0条 | `source_guard_checks=5928`、`source_changes=[]`、锁已释放；同版普通场景操作回归，不计完整30波验收。 |

032721结束后已确认显示引用的捕获竞态：死亡实体在最后一个physics帧释放，保存屏障先暂停，ShadowBatch未及在idle阶段清理。现于HELD后、`capture_ready`前刷新固定ShadowBatch的派生buffer/retained/count；不推进单位、任务、时钟或RNG。组件增加捕获前残留、HELD清空、恢复无残留的检查，按钮描述符与原阶段精确比较。033816之后只将选人回调检查限定为 `descriptor.kind=level`，生产代码未再改动。034128缓存诊断的保存首图、求情图和胜利图已由主代理目检，胜利图显示3/3、四人出林文案和清晰按钮；此目检仅属于诊断图，最终全新图像另见下文。

035452之后仅调整世界/经典两个QA驱动的资源导入时限为600秒，普通玩法240秒、野猪林组件420秒不变，生产代码未改。040000全新默认世界已取得实际916项通过收据；此前预计数现在以原始报告和真实覆盖替代。

## 最终世界批的原生画面

040000批已目检3张代表画面：[拦棍办理中保存](../level3_world_restore_20260909/20260913_040000_60d3e221/level6_cross_rescue_report_saved.png)、[求情阶段保存](../level3_world_restore_20260909/20260913_040000_60d3e221/level6_cross_care_report_saved.png)、[四人出林胜利](../level3_world_restore_20260909/20260913_040000_60d3e221/level6_cross_finish_report_victory.png)。前两张的倒计时/求情文字和底部指令区无遮挡；胜利图的3/3、四人出林文案和三个结果按钮清楚。路线共归档11张PNG，完整SHA核验已通过；不声称11张均已目检，瞬时FPS也不作为性能验收。

经典042455批另目检[中文覆盖确认](../continue_flow_20260909/20260913_042455_e8f43126/screenshots/overwrite_confirm_zh_CN.png)与[英文终局等待](../continue_flow_20260909/20260913_042455_e8f43126/screenshots/terminal_pending_en.png)，对应说明和各自两个按钮清楚无遮挡。经典16张四语状态图SHA均通过，人工目检仅以上2张；图像SHA检查与人工审阅分开记录。

## 完整世界覆盖与联合核验

040000主证据精确覆盖19个用例及导入/profile_guard：本轮同版任务核心28、祝家庄67+8+18、黄泥冈组件46+六进程258，合计425项；野猪林组件183、七进程25/55/53/57/58/48/12合计308项。自然进程为 `level6_cross_save`、`level6_cross_rescue`、`level6_cross_care`、`level6_cross_escort`、`level6_cross_leave`、`level6_cross_finish`、`level6_terminal_reject`。联合核验已逐条回查新PID/nonce、串行起止时间、前一进程、角色两次替换、保存/恢复状态、四人实际出林、3/3与明确终局拒绝；图像哈希与人工目检分开记录。

组件包含显式摆位、照料时间步进和死亡故障设置；七进程南路只使用实际选择/移动/任务命令，不计新增追兵、不覆盖自然全分支。跨批组合必须逐文件核对生产来源与当前checkout；即使具备相同生产依赖，也保留各批原始失败、子集和缓存状态，不改写 `acceptance_complete`。

历史[黄泥冈425项分阶段证据](../huangnigang_world_restore_20260913/README.md)与[经典296项](../continue_flow_20260909/20260913_024947_f6a8c09f/receipt.json)属于旧冻结来源，不能自动代表本轮同版回归。玩家入口保持隐藏；完整30波、其余五关、真实Steam持久确认、长跑/性能、双机/双账号及真人门槛保留。本轮没有Steam构建或发布。[本轮实现说明](../../docs/YEZHULIN_WORLD_RESTORE_20260913.md)。

## 只读核验脚本

`verify_evidence.py` 核验收据、归档文件SHA、实际检查报告、进程绑定、自然胜利/拒档及生产依赖。无参数时输出 `pending` 并退出2，不生成成功JSON；不运行Godot。提供失败批时退出1，不将部分通过累计成成功。

```powershell
py -3 -X utf8 -B qa/yezhulin_world_restore_20260913/verify_evidence.py
```

本轮已实际执行以下命令并退出0，生成[联合核验JSON](validation_summary.json)：

```powershell
py -3 -X utf8 -B qa/yezhulin_world_restore_20260913/verify_evidence.py --full-world qa/level3_world_restore_20260909/20260913_040000_60d3e221/receipt.json --classic-receipt qa/continue_flow_20260909/20260913_042455_e8f43126/receipt.json --write-summary
```

工具核对默认19用例、425+183+七进程的实际合计、全新导入、两份收据的完整生产依赖与当前checkout，以及经典默认流程全部报告。`--component-receipt`/`--route-receipt` 仅保留为诊断核对方式；缓存诊断不能作为全新验收输入，不能生成最终汇总。

当前生产文件集合按 `run_steam_integration_qa.py` 的 `ROOT_FILES` / `RUNTIME_DIRS` 和 `git ls-files -z --cached --others --exclude-standard` 精确枚举，须与收据生产集合完全相等，不能仅比较两份可能共同漏项的清单。经典四个实际保存/恢复用例还须 `result.ok=true`。两类私有目录防护均核对 `PRIVATE_PROFILE_REQUIRED`；经典不得生成 `profile_guard.json`，世界共用的 `world_restore_report.json` 则须归属后续真实world_restore进程，不能以最终文件存在情况虚构较早时点的缺席证据。

只有完整世界与同版经典候选全部核对成功，再显式传 `--write-summary`，才会在本目录生成 `validation_summary.json`。无此选项时仅向标准输出报告，任何情况下都不修改原始批次；未指定最终候选或只有诊断来源时不写最终成功JSON。

核验JSON只声明实际覆盖的完整默认世界916项及同版经典296项回归，不自动声明九玩法、人工目检或Steam验收。人工目检范围由上文单独记录为最终世界3张及经典2张，未扩大为全部27张。
