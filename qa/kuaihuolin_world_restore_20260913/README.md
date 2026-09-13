# 快活林恢复QA（内部里程碑完成）

## 当前结果：完整世界2811项、同版经典296项与联合核验通过

[110348_38bd4cf4世界收据](../level3_world_restore_20260909/20260913_110348_38bd4cf4/receipt.json) 已退出0，`complete/full_suite/fresh_import/acceptance_complete`与`level7_uid_inventory_complete`均true。2811项全部来自该同一全新默认37用例批：既有27用例1628项、快活林15槽组件789项与九自然进程394项（25/60/53/50/50/49/51/44/12）。[finish报告](../level3_world_restore_20260909/20260913_110348_38bd4cf4/level7_cross_finish_report.json) 确认真实4/4、零击杀非致死制服；[terminal报告](../level3_world_restore_20260909/20260913_110348_38bd4cf4/level7_terminal_reject_report.json) 对terms进程留下的旧槽返回`LOCAL_RUN_TERMINAL`。世界批`source_changes=[]`、`protected_player_unchanged=true`、`lock_released=true`、`engines_after=[]`。

[同版全新默认经典114838_3ea9d869](../continue_flow_20260909/20260913_114838_3ea9d869/receipt.json) 已退出0，`complete/fresh_import=true`、296项通过，`source_changes=[]`、`source_inventory_matches/engine_unchanged/scene_unchanged=true`、`lock_released=true`、`engine_running_at_release=false`。经典收据没有`protected_player_unchanged`字段，玩家目录前后SHA保护结论来自上述世界批，不向经典补造同名字段。

[联合核验](../kuaihuolin_world_restore_20260913/validation_summary.json)已退出0、`complete=true`：2966份生产文件与两批及当前checkout同SHA，世界12份/经典4份QA来源全部匹配当前，`world_qa_source_differences=[]`。快活林15张与经典16张PNG的SHA全部通过。人工仅目检快活林[首次保存](../level3_world_restore_20260909/20260913_110348_38bd4cf4/level7_cross_save_report_saved.png)、[冲撞在途保存](../level3_world_restore_20260909/20260913_110348_38bd4cf4/level7_cross_rush_report_saved.png)、[胜利结果](../level3_world_restore_20260909/20260913_110348_38bd4cf4/level7_cross_finish_report_victory.png)三张，以及经典[中文覆盖确认](../continue_flow_20260909/20260913_114838_3ea9d869/screenshots/overwrite_confirm_zh_CN.png)、[英文终局等待](../continue_flow_20260909/20260913_114838_3ea9d869/screenshots/terminal_pending_en.png)两张，均清晰正常；不能把SHA验证说成全部目检或性能验收。

快活林内部恢复里程碑完成。验证基线为已同步`34200d967f989a80a4cea47c0550753fc37ca70f`，最终源码同步以本轮提交与远端回读为准；本轮未重构建或发布Steam，`PLAYER_ENTRY=false`。下一连环马只有隔离准备候选，连环马/高俅/大名府未完成原生验收；完整30波最终同版、九玩法统一、真实Steam持久确认、1800秒长跑/性能、双机双账号和真人门槛保持。以下旧失败、中止、UID差异及缓存专项保留其原批结论，不计入本轮2811之外的追加通过数。

## 先前专项与修正过程（历史）

首轮全新导入[094019_25187821原始收据](../level3_world_restore_20260909/20260913_094019_25187821/receipt.json) 为 `complete=true`、`total_checks=789`、`level7_component_checks=789`、`fresh_import=true`；[组件报告](../level3_world_restore_20260909/20260913_094019_25187821/level7_component_report.json) 的789项及15个独立槽全部通过。[094820_198b1aa2缓存自然批](../level3_world_restore_20260909/20260913_094820_198b1aa2/receipt.json) 九进程393项也全部通过，实际4/4与终局旧槽拒绝完成。两批 `full_suite=false`、`acceptance_complete=false`，不能称完整验收通过。095748完整候选因提交字节预查受控中止；随后[全新默认37批100226_3c8ac914](../level3_world_restore_20260909/20260913_100226_3c8ac914/receipt.json) 在opening的一条QA冲撞距离断言失败，整批未通过。当时只修QA与聚合合同，生产不变；后续完整世界、经典及联合通过状态见顶部。

[缓存104708_3e4d1adb](../level3_world_restore_20260909/20260913_104708_3e4d1adb/receipt.json) 已在opening的派生rotation比较失败，同一rush真实接续断言已通过。仅QA将自然预警观察改为生产同款 `basis_x/basis_y` 精确比较后，[第三缓存九进程105428_bc4e6e43](../level3_world_restore_20260909/20260913_105428_bc4e6e43/receipt.json) 已完整通过394项、真实4/4及终局旧槽拒绝。该批仍为缓存子集，`fresh_import=false/full_suite=false/acceptance_complete=false`；后续110348全新默认37结果已单独记录于顶部；该缓存批的子集标志原样保留。

首批源码与玩家目录保护通过：`source_changes=[]`、`protected_player_unchanged=true`、`lock_released=true`、`engines_after=[]`。其 `level7_uid_inventory_complete=false` 原样保留：两份新GD的UID在首次导入前尚未收录。引擎退出后，根任务已从该私有导入复制并收录真实生成的 [factory UID](../../scripts/run_level7_world_factory.gd.uid) `uid://dycttfat0lkug` 与 [visual UID](../../scripts/run_level7_visual_state.gd.uid) `uid://d20oo0hgvppeg`；补齐后已由110348新批完成全新默认世界验收，不将首批历史字段改为true。

自然批 `complete=true`、`total_checks=393`、`level7_uid_inventory_complete=true`，但 `fresh_import=false`；save/drill/fist/rush/opening/subdued/terms/finish/terminal_reject实际为25/60/53/50/49/49/51/44/12项。该批单独确认 `source_changes=[]`、`protected_player_unchanged=true`、`lock_released=true`、`engines_after=[]`。[真实胜利](../level3_world_restore_20260909/20260913_094820_198b1aa2/level7_cross_finish_report.json) 为4/4，[新进程终局拒绝](../level3_world_restore_20260909/20260913_094820_198b1aa2/level7_terminal_reject_report.json) 对terms槽返回 `LOCAL_RUN_TERMINAL`。首批是fresh但UID清单不完整，第二批UID齐全但复用缓存；二者都保持子集标志，不合并成默认fresh验收。

接续基线为根任务已确认同步的 `34200d967f989a80a4cea47c0550753fc37ca70f`。江州原1628项世界及296项经典证据保持原样，不自动作为本轮快活林的同版回归。玩家保存/继续入口保持 `PLAYER_ENTRY=false`，本轮没有新Steam发布结论。

## 依赖与隔离

组件脚本为 [level7_world_restore_qa.gd](../../tools/level7_world_restore_qa.gd)，自然脚本为 [level7_cross_process_qa.gd](../../tools/level7_cross_process_qa.gd)，均已由 [世界QA驱动](../../tools/run_level3_world_restore_qa.py) 接入。二者按正常 `res://scripts/...` 路径加载固定 `Profiles.KUAI_*`、[Level7工厂](../../scripts/run_level7_world_factory.gd)、独立Unit图/状态、[预警适配器](../../scripts/run_level7_visual_state.gd)与景物/视觉合同；还依赖[短版关卡](../../scripts/levels/level7_kuaihuolin_short.gd)中的固定选人按钮和共享Session、Codec、槽、Mission、HUD、Battle/Unit等，不依赖工程外的准备候选目录。

私有profile由launcher建立，`APPDATA/LOCALAPPDATA/TEMP/TMP` 指向该profile对应目录，并核对 `OS.get_user_data_dir()` 边界。需有 `LSH_LEVEL3_RESTORE_PROFILE`、`STEAM_DISABLED=1`、`CAMPAIGN_QA=1`，以及 `LSH_LEVEL7_CASE / STATE / NONCE`；报告路径可回退通用 `LSH_LEVEL3_RESTORE_REPORT`。未满足边界必须以 `PRIVATE_PROFILE_REQUIRED` 退出，不能接触真实玩家目录或Steam。

组件用 `user://level7_component_<fixture>/v1` 分开15个槽；自然路线用 `user://level7_continue/v1` 和 `user://level7_handoff.json`。各自然进程按顺序串行，PID及nonce必须不同，槽SHA、前一模式和内容版本一致；最后保留terms的终局前槽供新进程拒绝。共享引擎锁、源码与玩家目录前后保护、进程退出和清理按每批原始收据分别记录，不将两个已完成专项的保护结论提前套用到当前完整世界批。

## 覆盖方案

15个组件槽与789项通过断言分开计数；110348当前fresh自然九进程为394项。旧393项仅属于094820缓存专项，不与当前2811项重复相加。组件槽清单及各项边界见[实现说明](../../docs/KUAIHUOLIN_WORLD_RESTORE_20260913.md)。组件明确使用摆位、直接任务回调、冷却复位与显式计时/冲撞推进，首批已运行实际技能、死亡、Session与验证器路径；不能把这些夹具称为自然通关。

重点保留：零饮酒R到期后的持续酒势、R期间再饮酒、四店不重复领奖、两种预警与真实冲撞、命中原始captive招牌的引用、W当次序号和实际移动后等待E、已记分延迟回调不重放、制服后活体及可见性、谈条件与接店之间的保存。隐藏夹具通过相机/显示预算设置和真实 `_grid_build` 产生，不直接写 `Unit.visible`，不据此证明八实体关卡自然启用了大规模显示预算。

组件每次比较完整已编码Unit/Level记录、单独编码的额外小状态、原生景物及DuelTell字段。不会为了二次整图编码放宽Codec限制。坏档必须先能正确编码，再由实际合同明确拒绝；现场预警故障必须还原和清理。真实武松/施恩死亡应进入终局并拒绝捕获与建槽。

自然进程固定为：

```text
level7_cross_save
level7_cross_drill
level7_cross_fist
level7_cross_rush
level7_cross_opening
level7_cross_subdued
level7_cross_terms
level7_cross_finish
level7_terminal_reject
```

`drill` 保存四酒已完成、练步圆圈仍在；下一进程用真实W和移动离圈再挑战。`rush` 必须处于真实冲撞在途，具备 `charge_running`、`_charge_dash>0`、实际位置已离 `rush_from` 且 `fist_marker.progress==1`；不能用蓄力阶段代替。`opening` 要求当前破绽仍大于0.6秒，W当次序号吻合、真实移动至少24像素且E尚无命中信用；暂停HELD后再验证。最后要求真实4/4终局及新进程 `LOCAL_RUN_TERMINAL`，任何超时或错过断点都保留失败。

100226失败后的QA修正保留全部上述门槛，新增同一已保存rush的完成检查：ready和结果均绑定原 `special_index`，恢复后真实继续位移>1，`rush_dodges`原值+1、`heavy_dodges`原值不变、dash及冲锋计时归零，且未命中武松/施恩。聚合器同步核对前槽和恢复后的原序号/计数/位移/命中集合。`charge_travel`只作采样观察，不再要求累计>100。新增断言已在104708通过；该opening报告实际50条，仍因另一观察比较失败，不把单条通过扩大为整批成功。

## 复现与联合归档

驱动已接入默认37用例。以下命令使用独立私有短路径，Godot由被忽略的 `godot.local.txt`、`GODOT_PATH` 或 `--godot` 参数提供；各引擎运行必须串行。110348完整默认世界、114838全新默认经典及联合核验均已完成，无需为交接重复运行。以下是后续独立新批的执行入口；新批应使用新私有目录和相应新收据。

```powershell
py -3 -X utf8 -B tools/run_level3_world_restore_qa.py --work-root "<本机组件QA绝对短路径>" --cases level7_component --run
py -3 -X utf8 -B tools/run_level3_world_restore_qa.py --work-root "<本机完整世界QA绝对短路径>" --run
py -3 -X utf8 -B tools/run_continue_flow_qa.py --work-root "<本机经典QA绝对短路径>" --run
```

本轮联合核验已执行通过；从checkout根目录只读复核已归档证据可使用以下确切收据（省略`--write-summary`不会改写汇总）：

```powershell
py -3 -X utf8 -B qa/kuaihuolin_world_restore_20260913/verify_evidence.py --full-world qa/level3_world_restore_20260909/20260913_110348_38bd4cf4/receipt.json --classic-receipt qa/continue_flow_20260909/20260913_114838_3ea9d869/receipt.json
```

[validation_summary.json](validation_summary.json)绑定本轮完整生产集合、两批及当前QA来源；不取旧失败/缓存批补足检查数。

| 已核验对象 | SHA256 |
| --- | --- |
| 世界110348原始收据 | `167ae56277cbb8dc360dc3340310ee772e1eae62db722af6b5db24d30fe462e3` |
| 经典114838原始收据 | `0122ffe2bf427c9c7d869a35f962a314ba7f71671fe6d6bad781d9a4a8e08d02` |
| 2966份生产清单 | `1cf6ab1883da20147e53172290f67edcdcba5121d16b9dbb476ba3e2b2daebf6` |

默认完整世界不传 `--cases` 或 `--cache-from`；组件或自然子集、缓存复用必须保留对应子集/非fresh标志。`--cache-from` 指向先前私有run目录，驱动会校验素材/import字节并重新扫描源码，但不能因此把缓存批计为fresh。导入上限600秒，快活林用例420秒，经典玩法240秒；不因瞬时断点难捕获而放宽它的真实状态条件。

后续每批保留原始receipt、各用例报告和日志、私有来源及进程身份；失败、主动中止、缓存诊断和全新默认成功分别记录，不重写历史收据。最终联合核验要绑定两份实际收据、当版生产文件完整集合及SHA、QA来源、全部自然保存链、保护后验和已归档原生图片。

自然截图代码在暂停后等待两帧布局，再强制视口绘制读取PNG，避免取证消耗有限决斗窗口。094820缓存批已归档15张PNG，人工仅查看[首次保存](../level3_world_restore_20260909/20260913_094820_198b1aa2/level7_cross_save_report_saved.png)、[真实冲撞在途保存](../level3_world_restore_20260909/20260913_094820_198b1aa2/level7_cross_rush_report_saved.png)、[胜利结果](../level3_world_restore_20260909/20260913_094820_198b1aa2/level7_cross_finish_report_victory.png)三张，画面清晰、预警与胜利信息正确。110348新fresh的三张代表图已另行目检，准确路径见顶部；本次15张图及经典16张图的联合SHA核验已通过。缓存目检不计入本次fresh目检，也不能推导帧率或性能结果。

当前剩余不变：完整30波最终同版、其余三关、九玩法统一交付、真实Steam写确认、1800秒/性能、两台Windows/双账号和真人验收。恢复入口和Steam发布状态不能随组件或自然子集通过而自动开放。

## 已发生的组件批与UID补齐

[094019_25187821](../level3_world_restore_20260909/20260913_094019_25187821/receipt.json) 是全新导入的组件子集，789项全部通过；其完整范围与UID字段按顶部记录保留。两个UID来自该批实际Godot导入，根任务在引擎退出后复制回源码并收录；没有把UID缺口说成组件引擎失败，也没有把子集通过改写为正式默认验收。

随后094820_198b1aa2复用首批缓存完成九进程393项，UID清单已完整，仍为缓存子集。首次完整候选095748中止后仅做LF规范化；100226又因QA距离假设误拒而失败，详见下文。修正后105428缓存与110348新fresh均已有下述独立结果；114838经典296项及联合核验也已通过。旧专项来自规范化和此次断言修正前QA字节，不能宣称与新QA文件SHA相同；原始报告、收据、UID差异、缓存和失败标志不重写。

## 095748完整候选主动中止（不计通过）

[095748_faf02a7c收据](../level3_world_restore_20260909/20260913_095748_faf02a7c/receipt.json) 记录导入与 `profile_guard` 已通过，`freeplay_core` 刚开始时受控中止，driver正常清理后退出1。`total_checks=0`、`complete=false`、`acceptance_complete=false`，`full_suite=true`/`fresh_import=true` 只说明计划范围。`source_changes=[]`、玩家档未变、锁释放和 `engines_after=[]` 均保持原记录。

中止原因是提交前字节检查发现两份新增QA仍有CRLF/混合行尾，Git依据 `.gitattributes` 收录LF会改变受测文件。根任务只停止核实属于该私有工程的 `freeplay_core` 进程61784；先前查询的import PID已退出，没有被再次停止。该批不是原生玩法断言失败，也不能记作完整通过。

退出后仅把两份 `level7_*_qa.gd` 的CRLF改为LF，生产逻辑和QA断言内容未改。确认暂存/工作区字节一致后启动100226批；其后发生的QA断言失败单独记录，不重写095748原始中止记录。

## 100226完整候选QA断言失败（不计完整通过）

[100226_3c8ac914收据](../level3_world_restore_20260909/20260913_100226_3c8ac914/receipt.json) 的 `complete=false`、`acceptance_complete=false`，`fresh_import=true/full_suite=true` 只表明此次执行计划为全新默认37。已接受报告汇总 `total_checks=2605`：旧27用例1628、组件789、前四自然25+60+53+50均通过；失败[opening报告](../level3_world_restore_20260909/20260913_100226_3c8ac914/level7_cross_opening_report.json) 另有49条，48过、唯一失败 `both distinct specials really missed before first E`。该失败报告未加入driver的通过进程汇总，不能写“2605含失败49”或“2605完整通过”。余下自然进程未继续；`source_changes=[]`、玩家目录未变、锁释放、`engines_after=[]` 均已回读。

根任务与独立审查已确认：短版关卡用 `map.limit_displacement` 把名义190冲撞路径截为约79.1667，Unit遇阻也会提前停止；旧QA采样漏结束边界，报告 `charge_travel=65.3332138061523`，因此硬编码>100并不是合法游戏合同。生产逻辑不改，仅以同一保存rush的实际继续移动、完成及未命中结果替换该假设，并增加原序号绑定断言；W真实移动和冲撞在途条件保持。后续缓存诊断及110348新fresh结果另记，旧393专项不能代替新合同的运行证据。

## 104708缓存候选派生rotation比较失败

[104708_3e4d1adb原始收据](../level3_world_restore_20260909/20260913_104708_3e4d1adb/receipt.json) 为 `complete=false/fresh_import=false/full_suite=false/acceptance_complete=false`，已接受前四自然 `total_checks=188`；另[opening报告](../level3_world_restore_20260909/20260913_104708_3e4d1adb/level7_cross_opening_report.json) 50条中49过、仅 `restored tells matches disk` 失败。新同一rush接续断言已过，原始旋转角却由0.74953150749206变为0.74953144788742。该批source_changes为空、玩家不变、锁已释放、engines_after为空，失败报告保留。

生产Visual原本按basis矩阵保存/恢复，组件也精确比较basis；root和独立审查确认自然QA不应要求派生rotation重复计算后字节相同。仅将自然tell观察从rotation改为 `basis_x/basis_y` 原始向量，保留position精确比较，无epsilon、舍入或生产改动。修正后105428结果见下节；104708的188已接受加另50条（49过1失败）口径原样保留。

## 105428缓存九进程394项通过（非fresh验收）

[105428_bc4e6e43原收据](../level3_world_restore_20260909/20260913_105428_bc4e6e43/receipt.json) 为 `complete=true/total_checks=394`，九段25/60/53/50/50/49/51/44/12项均过；`level7_uid_inventory_complete=true`、`source_changes=[]`、`protected_player_unchanged=true`、`lock_released=true`、`engines_after=[]`。[胜利报告](../level3_world_restore_20260909/20260913_105428_bc4e6e43/level7_cross_finish_report.json) 为实际4/4，[终局拒绝报告](../level3_world_restore_20260909/20260913_105428_bc4e6e43/level7_terminal_reject_report.json) 返回 `LOCAL_RUN_TERMINAL`。归档15张PNG，目前尚未人工目检这些图片。

其 `fresh_import=false/full_suite=false/acceptance_complete=false` 保留，不能称默认完整世界验收或替代同版经典。后续110348新fresh世界、114838经典296项及联合核验均已通过；不把旧789组件、旧393缓存与本394相加为一次通过数，不重写100226/104708原始失败。
