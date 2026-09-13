# 快活林整世界保存与恢复（2026-09-13，内部里程碑完成）

## 当前结果：完整世界2811项、同版经典296项与联合核验通过

[110348_38bd4cf4世界收据](../qa/level3_world_restore_20260909/20260913_110348_38bd4cf4/receipt.json) 已退出0，`complete/full_suite/fresh_import/acceptance_complete`与`level7_uid_inventory_complete`均true。2811项全部来自该同一全新默认37用例批：既有27用例1628项、快活林15槽组件789项与九自然进程394项（25/60/53/50/50/49/51/44/12）。[finish报告](../qa/level3_world_restore_20260909/20260913_110348_38bd4cf4/level7_cross_finish_report.json) 确认真实4/4、零击杀非致死制服；[terminal报告](../qa/level3_world_restore_20260909/20260913_110348_38bd4cf4/level7_terminal_reject_report.json) 对terms进程留下的旧槽返回`LOCAL_RUN_TERMINAL`。世界批`source_changes=[]`、`protected_player_unchanged=true`、`lock_released=true`、`engines_after=[]`。

[同版全新默认经典114838_3ea9d869](../qa/continue_flow_20260909/20260913_114838_3ea9d869/receipt.json) 已退出0，`complete/fresh_import=true`、296项通过，`source_changes=[]`、`source_inventory_matches/engine_unchanged/scene_unchanged=true`、`lock_released=true`、`engine_running_at_release=false`。经典收据没有`protected_player_unchanged`字段，玩家目录前后SHA保护结论来自上述世界批，不向经典补造同名字段。

[联合核验](../qa/kuaihuolin_world_restore_20260913/validation_summary.json)已退出0、`complete=true`：2966份生产文件与两批及当前checkout同SHA，世界12份/经典4份QA来源全部匹配当前，`world_qa_source_differences=[]`。快活林15张与经典16张PNG的SHA全部通过。人工仅目检快活林[首次保存](../qa/level3_world_restore_20260909/20260913_110348_38bd4cf4/level7_cross_save_report_saved.png)、[冲撞在途保存](../qa/level3_world_restore_20260909/20260913_110348_38bd4cf4/level7_cross_rush_report_saved.png)、[胜利结果](../qa/level3_world_restore_20260909/20260913_110348_38bd4cf4/level7_cross_finish_report_victory.png)三张，以及经典[中文覆盖确认](../qa/continue_flow_20260909/20260913_114838_3ea9d869/screenshots/overwrite_confirm_zh_CN.png)、[英文终局等待](../qa/continue_flow_20260909/20260913_114838_3ea9d869/screenshots/terminal_pending_en.png)两张，均清晰正常；不能把SHA验证说成全部目检或性能验收。

快活林内部恢复里程碑完成。验证基线为已同步`34200d967f989a80a4cea47c0550753fc37ca70f`，最终源码同步以本轮提交与远端回读为准；本轮未重构建或发布Steam，`PLAYER_ENTRY=false`。下一连环马只有隔离准备候选，连环马/高俅/大名府未完成原生验收；完整30波最终同版、九玩法统一、真实Steam持久确认、1800秒长跑/性能、双机双账号和真人门槛保持。以下旧失败、中止、UID差异及缓存专项保留其原批结论，不计入本轮2811之外的追加通过数。

## 先前专项与修正过程（历史）

本轮接续 stable `34200d967f989a80a4cea47c0550753fc37ca70f`。固定快活林工厂、人物/视觉合同和两份QA已接入；首轮全新导入[组件批094019_25187821](../qa/level3_world_restore_20260909/20260913_094019_25187821/receipt.json) 实际789项通过，15个组件槽全部完成。[缓存自然批094820_198b1aa2](../qa/level3_world_restore_20260909/20260913_094820_198b1aa2/receipt.json) 九进程393项通过，真实4/4和终局旧槽拒绝完成。两批均为子集，`full_suite=false`、`acceptance_complete=false`。首次完整候选095748因提交字节预查受控中止；随后[全新默认37批100226_3c8ac914](../qa/level3_world_restore_20260909/20260913_100226_3c8ac914/receipt.json) 在opening用例的一条冲撞距离断言失败，整批未通过。当时仅修QA及聚合判定，生产逻辑不变；后续新批世界、经典及联合通过状态见顶部。`PLAYER_ENTRY=false`，玩家保存/继续仍未开放。

修正后的[缓存九进程104708_3e4d1adb](../qa/level3_world_restore_20260909/20260913_104708_3e4d1adb/receipt.json) 又因QA对派生旋转角的精确比较失败；同一rush真实接续断言已通过。仅把自然观察的rotation改为生产同款 `basis_x/basis_y` 精确比较后，[第三缓存九进程105428_bc4e6e43](../qa/level3_world_restore_20260909/20260913_105428_bc4e6e43/receipt.json) 已完整通过394项、真实4/4和终局旧槽拒绝；生产不改，不加epsilon或舍入。该批仍为缓存子集，`fresh_import=false/full_suite=false/acceptance_complete=false`。后续110348完整fresh结果已单独记录于顶部；该缓存批不追溯改为完整验收。

组件原始收据为 `complete=true`、`total_checks=789`、`level7_component_checks=789`、`fresh_import=true`，记录 `source_changes=[]`、`protected_player_unchanged=true`、`lock_released=true`、`engines_after=[]`。[组件报告](../qa/level3_world_restore_20260909/20260913_094019_25187821/level7_component_report.json) 保留实际检查标签与15个槽；这些是显式夹具，不能称自然路线已通过。

首批 `level7_uid_inventory_complete=false`：两个新GD当时尚无根目录UID。引擎退出后已把该私有导入真实生成的UID复制回源码并收录：[工厂UID](../scripts/run_level7_world_factory.gd.uid) 为 `uid://dycttfat0lkug`，[视觉适配UID](../scripts/run_level7_visual_state.gd.uid) 为 `uid://d20oo0hgvppeg`。后续自然批该字段已为true，但 `fresh_import=false`；首批则为 `fresh_import=true`、UID清单不完整。两批差别如实保留，不能把它们拼成UID齐全的默认fresh验收，原批次字段不改写。

江州上一里程碑的全新世界1628项与经典296项属于其既有冻结证据，不自动覆盖快活林改动。本轮不改写江州原始记录，也没有新的Steam包或发布结论。正式源码、QA和复现入口见[本轮QA说明](../qa/kuaihuolin_world_restore_20260913/README.md)。

## 已接入的实现范围

固定官方选型为 `campaign_level7_v1`，上下文为 `{mode: campaign, level_id: level7, waves: 0}`，仅对应已安装目录中的 [level7_kuaihuolin_short.gd](../scripts/levels/level7_kuaihuolin_short.gd)。[run_level7_world_factory.gd](../scripts/run_level7_world_factory.gd) 按既有接口离树准备定义并恢复关卡；不得重放部署、饮酒奖励、技能命中或任务完成回调。Battle根/Core接入该固定上下文，不用玩家槽中的脚本路径选择任意工厂。

地图为60×38 town。已补快活林景物/视觉分区，以及孟州门的离树准备；已存在的固定阴影子节点在入树时复用，不能二次创建或覆盖恢复后的显示状态。普通Unit可见性按记录保留，不能假定制服后的蒋门神一定可见。

独立 `level7_unit_state_v1` / `level7_unit_graph_v1` 约束八个原始实体：武松、施恩、四家酒望、蒋门神及店前招牌。保留原始身份与相对部署顺序，不引入囚徒式实体替换。四家饮酒标记与累计饮酒数、武松拳力增量及四项固定二级拳技互相校验。四家酒望和招牌是原生captive建筑，未登记 `fcell/fhalf/footprint_blocked`，恢复不能补造占格元数据。

酒势与稳酒计时都需保存。未饮酒时使用R、R结束后仍有持续酒势是合法组合；R尚在稳酒计时内再次饮酒也会切换酒势倍率，不能简单要求 `steady_left>0` 时倍率永远为1。蒋门神的护势来源若仍存在须按原值验证，有限999秒时长不意味着整个决斗都必须永久带护势。

当前短版 `DuelTell` 只有 `kind/progress/extent` 三项业务字段。关卡外部引用只使用 `level7:fist` 与 `level7:drill`，按真实FX根、固定脚本、几何与元数据绑定；未知、孤立、错误脚本或别名引用必须拒绝。真实冲撞开始后预警节点仍可保留且 `progress=1`；命中列表可包括武松、施恩及原始酒望/招牌，不能误限为两名英雄。

W的当次招式序号、实际起点和已移动距离，以及当前破绽序号/剩余时间均需保真。E只在实际造成伤害后由原有延迟核验记入反击/招牌拳路；恢复不得重放已排空的延迟命中。蒋门神 `subdued` 后仍活着并保留在active图中；谈条件和施恩接店分开处理，实际接店立即终局，终局前旧槽必须被后续新进程拒绝。

原有两个选人按钮改为固定 `forest_wu / forest_shi` 描述符与 `activate_mission_button` 回调；恢复后必须选择本次新安装的武松/施恩实体。任务动作按钮不混同为选人按钮，所有原阶段描述符仍需精确比较。

## 15个组件槽（首批789项通过）

首批[组件报告](../qa/level3_world_restore_20260909/20260913_094019_25187821/level7_component_report.json) 已完成下列15槽，合计789项检查全部通过。每一槽实际调用Session保存、读槽、prepare和install，并在暂停状态比较完整人物/关卡记录、额外任务/时钟/选择状态、原生景物和DuelTell显示字段。已编码人物/关卡记录按完整原值比较，避免将整图再次编码进单记录Codec预算。

| 独立槽 | 首批实际验证的组件边界 |
| --- | --- |
| `road` | 初始八实体、四酒选择、固定选人按钮 |
| `sober_steady` | 零饮酒使用真实R，稳酒尚未结束 |
| `sober_expired` | 零饮酒的R到期，合法持续酒势 |
| `steady_then_drink` | R计时仍在时调用真实饮酒，单店不重复领奖 |
| `four_taverns` | 四店分别已饮，酒势和拳力正确 |
| `four_steady` | 四店后真实R的稳酒状态 |
| `drill_tell` | 练步圆圈在场，尚未完成离圈 |
| `heavy_windup` | 重拳部分蓄力、进度及非限时姿态 |
| `moved_w_before_e` | 真实W归属后经明确夹具摆位移动，E尚未命中 |
| `verified_counter` | 真实E造成伤害并记分，恢复不重放延迟核验 |
| `rush_windup` | 冲撞部分蓄力及锁定方向 |
| `charge_hit_sign` | 实际共享冲撞在途，原始招牌已被扫入命中列表 |
| `subdued_alive` | 真实非致命制服，活体保留、尚未谈条件 |
| `subdued_offscreen` | 显式显示预算和相机夹具经真实网格计算造成隐藏，保存可见性原值 |
| `terms_before_shop` | 真实谈条件完成，施恩尚未接店 |

组件中的位置变化、直接任务回调、冷却复位、关卡计时和冲撞步进都是显式阶段/边界夹具，不能称自然路线。命中招牌夹具保持招牌在原坐标，仅摆放决斗双方，首批已通过其实际碰撞与恢复断言。隐藏夹具仅证明共享可见性字段保真：本关八实体会令网格末尾按实际人数把 `_lite_fx` 重算为false，不能据此宣称正常玩家路线自然启用了大规模显示预算；不会直接改 `Unit.visible`。

另对武松/施恩调用真实致死伤害，要求实际终局拒绝捕获与建槽；这是终局边界，不是假装支持死亡后的八活体继续。负例从有效保存记录派生，分别检查编码成功与实际验证拒绝，覆盖角色别名、饮酒计数、非法终局值、错误W序号、缺失/错误外部引用、死亡活体伪装、伪造建筑占格、自命中冲撞以及制服后错误结局。现场孤立/错误脚本/别名预警夹具必须清理后再继续。

## 九进程自然路线（缓存诊断393项通过）

[094820_198b1aa2原始收据](../qa/level3_world_restore_20260909/20260913_094820_198b1aa2/receipt.json) 为 `complete=true`、`total_checks=393`、`level7_uid_inventory_complete=true`，但 `fresh_import=false`、`full_suite=false`、`acceptance_complete=false`。九进程依次25/60/53/50/49/49/51/44/12项全部通过；[finish报告](../qa/level3_world_restore_20260909/20260913_094820_198b1aa2/level7_cross_finish_report.json) 完成真实4/4，[terminal报告](../qa/level3_world_restore_20260909/20260913_094820_198b1aa2/level7_terminal_reject_report.json) 对terms保存的终局前槽返回 `LOCAL_RUN_TERMINAL`。该批独立记录 `source_changes=[]`、玩家目录未变、锁释放且无遗留引擎。

本缓存批归档15张PNG。人工仅查看[首次保存](../qa/level3_world_restore_20260909/20260913_094820_198b1aa2/level7_cross_save_report_saved.png)、[真实冲撞在途保存](../qa/level3_world_restore_20260909/20260913_094820_198b1aa2/level7_cross_rush_report_saved.png)、[胜利结果](../qa/level3_world_restore_20260909/20260913_094820_198b1aa2/level7_cross_finish_report_victory.png)三张，画面清晰，预警与胜利信息正确。这是缓存诊断的目检范围，不能提前算作最终fresh批的图像验收。

自然候选只用实际选人、原点击任务意图、地图移动、攻击和技能输入；不传送、直接回调、改伤害、造胜利或加速。每个保存由真实屏障暂停，下一进程必须有新PID/nonce、相同内容身份与原槽SHA，并在推进前比较恢复状态。

| 进程 | 必须真实到达的断点 |
| --- | --- |
| `level7_cross_save` | 第一店已饮，其余准备未完成，施恩已获真实候场移动指令 |
| `level7_cross_drill` | 四店已饮并主动触发练步，圆圈仍在、尚未离圈 |
| `level7_cross_fist` | W加实际移动完成练步，再真实挑衅，重拳正蓄力 |
| `level7_cross_rush` | 真正冲撞在途：仍有dash、已离起点、预警进度1；蓄力阶段不能替代 |
| `level7_cross_opening` | 当前破绽内，W后真实移动至少24像素，E尚未命中 |
| `level7_cross_subdued` | 正常战斗实际制服蒋门神，保留活体、反击及招牌拳路，尚未谈条件 |
| `level7_cross_terms` | 武松实际走到并谈完条件，施恩尚未接店 |
| `level7_cross_finish` | 施恩实际接店、双人存活、真实终局与4/4目标 |
| `level7_terminal_reject` | 新进程对terms进程留下的终局前槽要求 `LOCAL_RUN_TERMINAL` |

冲撞窗口按完整physics/process帧观察，一旦真正到达即暂停，HELD后再检查在途；W破绽也在HELD后复查。达不到或错过瞬时断点必须留作失败，不能改成较弱阶段后继续声称通过。前段仅通过真实移动暂缓攻击以保留观察机会；后段才正常Q/E/攻击/R至制服。它不是所有分支、真人操作节奏或性能验收。

100226失败后，opening新增同一已保存冲撞的完成断言：绑定原 `special_index`，恢复后实际继续位移>1、`rush_dodges`比原值增1、`heavy_dodges`保持原值，dash及冲锋计时归零，命中列表不含武松/施恩。ready也绑定原招式序号；原rush在途、当前W真实移动及E尚未记分门槛保留。`charge_travel`保留为观察量，不再把采样累计>100当作合法冲撞必要条件；聚合器同步核对上述跨槽合同。该新增断言已在104708实际通过，但该批因另一观察字段失败，不能因此称整批通过或回填100226。

## 联合证据与旧专项边界

110348全新默认37用例世界2811项、114838同版全新默认经典296项及2966份生产清单/QA来源/图片的联合核验均已完成，准确收据与目检路径见顶部。首批789组件、旧393缓存和修正后的394缓存均保持独立专项，不与新批2811重复相加。095748中止后曾仅做LF规范化；100226及104708之后仅修QA的距离假设和派生旋转观察，生产逻辑不变。旧专项来自规范化或QA修正前的字节，不能宣称新旧QA文件SHA相同；首批UID清单缺口、子集、缓存及失败标志原样保留。

## 首次完整候选095748受控中止

[095748_faf02a7c原始收据](../qa/level3_world_restore_20260909/20260913_095748_faf02a7c/receipt.json) 的导入和 `profile_guard` 已通过；提交前字节检查发现两份新增QA包含CRLF/混合行尾，而 `.gitattributes` 要求LF，Git收录会改变受测字节。根任务为让最终受测QA与提交字节一致，受控停止了刚开始的 `freeplay_core` 私有进程61784；先前查询的import进程已退出，没有对其再次停止，也未停止其他工程。

driver正常清理、归档后退出1，该批 `total_checks=0`、`complete=false`、`acceptance_complete=false`，`full_suite=true`、`fresh_import=true` 只代表原计划范围；`source_changes=[]`、玩家目录未变、锁已释放、`engines_after=[]`。这是提交字节预查引发的主动中止，不是已跑玩法断言失败，不计全量通过。

引擎退出后仅将 `tools/level7_world_restore_qa.gd` 和 `tools/level7_cross_process_qa.gd` 的CRLF规范为LF，未改变生产逻辑或QA断言内容。根任务确认暂存与工作区字节一致后启动100226批，其后发生的QA断言失败见下节；095748原中止收据保持不变。

## 完整候选100226在opening失败

[100226_3c8ac914原始收据](../qa/level3_world_restore_20260909/20260913_100226_3c8ac914/receipt.json) 为 `complete=false`、`acceptance_complete=false`、`fresh_import=true`、`full_suite=true`，整批未通过。已入收据的 `total_checks=2605` 等于旧27用例1628、快活林组件789及前四自然25/60/53/50项之和；失败的[opening报告](../qa/level3_world_restore_20260909/20260913_100226_3c8ac914/level7_cross_opening_report.json) 另有49条检查，其中48过、唯一失败为 `both distinct specials really missed before first E`。driver只汇总已接受的自然报告，不能把2605写成完整37通过，也不能把该49条再说成已含在2605内。失败发生后未继续余下自然用例。该批 `source_changes=[]`、`protected_player_unchanged=true`、`lock_released=true`、`engines_after=[]`。

根任务与独立审查确认原因是QA硬编码累计冲撞位移>100：实际关卡的 `map.limit_displacement` 将名义190路径截为约79.1667，Unit碰撞又可提前终止；QA采样也会漏掉结束边界，本报告 `charge_travel=65.3332138061523`。这是合法生产路径被距离假设误拒，不能据此改地图、冲撞距离或伤害。当时仅按上一节修QA及聚合器，保留原W窗口和冲撞在途要求；后续缓存及110348新fresh结果另记，原失败收据/报告原样保留。

## 缓存候选104708在派生旋转观察失败

[104708_3e4d1adb收据](../qa/level3_world_restore_20260909/20260913_104708_3e4d1adb/receipt.json) 为 `complete=false`、`fresh_import=false`、`full_suite=false`、`acceptance_complete=false`；`total_checks=188` 是前四自然25/60/53/50的已接受总数。[opening报告](../qa/level3_world_restore_20260909/20260913_104708_3e4d1adb/level7_cross_opening_report.json) 另有50条，49过、唯一失败 `restored tells matches disk`；同一rush在恢复后真实移动、完成且未命中两人的新增断言已过。源码无漂移、玩家目录未变、锁释放且无遗留引擎，原始失败记录不改写。

根任务与独立审查确认仅派生 `marker.rotation` 从0.74953150749206变为0.74953144788742。生产Visual以原始 `basis_x/basis_y` 保存和恢复，组件也比较该矩阵；自然QA应观察同一原始矩阵，而不是重新由矩阵推导的角度。仅QA改为两条basis向量精确比较，position保留，不增加容差、不舍入、不修改生产。修正后的105428缓存结果另记下节，不改写104708失败。

## 第三缓存自然批105428完成（仍非最终验收）

[105428_bc4e6e43收据](../qa/level3_world_restore_20260909/20260913_105428_bc4e6e43/receipt.json) `complete=true/total_checks=394`；九进程实际25/60/53/50/50/49/51/44/12项全部通过，opening包括同一rush真实接续与basis向量精确比较。[finish](../qa/level3_world_restore_20260909/20260913_105428_bc4e6e43/level7_cross_finish_report.json) 确认真正4/4，[terminal](../qa/level3_world_restore_20260909/20260913_105428_bc4e6e43/level7_terminal_reject_report.json) 对terms旧槽返回 `LOCAL_RUN_TERMINAL`。UID清单完整、`source_changes=[]`、玩家目录未变、锁释放、`engines_after=[]`。

该批归档15张PNG，尚未人工目检本批图片。`fresh_import=false/full_suite=false/acceptance_complete=false` 均保留；394只属于修正后缓存九进程，不能与旧组件拼成最终完整通过。后续110348全新默认37已完成2811项，114838经典296项与联合核验也已完成；该缓存批不因此成为fresh或完整批。

截图SHA/尺寸与人工目检分别记录；当前fresh已目检顶部链接的三张代表画面，经典另两张；快活林15张及经典16张PNG联合字节核验已通过。早期缓存批的三张目检保持独立范围，不代替本批。没有冻结整合版本测量前不写性能达标。完整30波最终同版、其余连环马/高俅/大名府、九玩法统一回归、真实Steam持久确认、1800秒长跑、双机双账号及真人门槛均保持。运行与归档说明见[QA README](../qa/kuaihuolin_world_restore_20260913/README.md)。
