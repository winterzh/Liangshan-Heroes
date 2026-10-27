# 项目目录索引（2026-10-27）

## 当前文档入口

| 用途 | 文件 |
| --- | --- |
| 仓库首页 | [README](../README.md) |
| 版本、交付范围与剩余工作 | [项目总览](PROJECT_STATUS.md) |
| 后续顺序与完整验收条件 | [开发计划](DEVELOPMENT_PLAN.md) |
| 启动、换机、共享引擎与源码同步 | [源码设置](SOURCE_SETUP.md) |
| 按批次记录完成事项 | [开发日志](WORKLOG.md) |
| 本轮重复缓存清理与恢复 | [清理收据与恢复器](../qa/storage_cleanup_20261027/README.md) |
| 10月27日取消全量测试及27个进程结果 | [停止原件](../qa/campaign_progress_recovery_20261026/daming_continue_candidate/evidence/negative_user_stop_20261027_183950/README.md)、[等待预算重规划原件](../qa/campaign_progress_recovery_20261026/daming_continue_candidate/evidence/negative_budget_cancel_20261027_175238/README.md) |
| 本次Steam更新 | [更新文档](STEAM_UPDATE_20261019.md) |
| Steam交付步骤 | [发布指南](STEAM_RELEASE_GUIDE.md) |
| 美术缺口与来源 | [全量美术台账](ART_COMPLETION_20260926.md)及各人物/场景实现说明 |
| 入口文档历史与本次清理 | [QA及恢复说明](../qa/storage_cleanup_20261020/README.md) |

## 运行与资源目录

| 位置 | 用途 |
| --- | --- |
| `project.godot`、`Play.cmd` | Godot工程及本机启动器 |
| `scripts/`、`scenes/`、`assets/` | 运行代码、场景、正式资源及必要来源链 |
| `native/`、`vendor/` | 原生接口、第三方依赖与许可 |
| `tools/` | 构建、检查及受控执行工具 |
| `docs/` | 当前入口及人物/场景/玩法等专题说明 |
| `qa/` | 实际检查、失败记录、候选和来源证据；存在文件不代表已采用 |
| `marketing/` | 平台说明与宣传材料 |
| `.godot/`、`build/`、`scratchpad/` | 本地缓存/产物/临时资料，不据此同步全部文件 |
| `D:/AI项目/水浒/历史资料`、`归档` | 历史材料和可恢复归档 |

## 本批索引与新增规则

`qa/campaign_progress_recovery_20261026/daming_continue_candidate/`：基于941c的Session/Core/UnitContract三脚本候选、精确diff和来源；补章节定义装配与严格单囚安全撤离；`integration_941/`为只替三个已有文件的新冻结准备器，默认34项轻量来源检查；新3365完整准备及独立导入已完成；`evidence/full_freeze_20261027_063133/`为紧凑原件及旧来源SHA引用，`tests/daming_flow/`与`run_daming_flow.py`为五GD已原生加载、八进程尚未运行的双角色工具，实际资格集中在`VALIDATION.md`。

`qa/campaign_progress_recovery_20261026/recovery_readset_candidate/`：只对原Slot启用的严格读集优化候选、固定d7来源的新工程准备器、原Flow适配器与原生替换专项；768b6e59已导入，真实保存/恢复两案88项及12类异常/旧4MB副本285项通过。`VALIDATION.md`维护当前资格，创建时来源清单和工具README保持原字节，未采用生产。

`qa/campaign_progress_recovery_20261026/continue_binding_candidate/tests/classic_recovery_timing/`为原档只读、隔离副本原API计时工具；`evidence/classic_recovery_timing_20261027_031418/`保留15项诊断检查、原始来源/日志与文件不变证据，首次inspect超时，未执行恢复。

`qa/lianhuanma_resume_20261026/`：连环马自然付费训练、同槽同token三进程接续的外部驱动、执行器、成功及失败收据；私有存档与运行缓存留本机，100项只属于内部活动期专项。新的事务集成图在该目录。

`qa/campaign_progress_recovery_20261026/`：重基14文件候选、新context生命周期的135项训练证据、自然终局/重启旧槽拒绝1364项成功与首轮失败；`rebased_candidate/`尚未采用生产，`handoff_candidate/`的23c源码已通过99项模型、尾账/纠正回归、13阶段真实文件专项（含两类预期拒绝）及黄泥冈1386项；同源经典30波六进程443项也已通过。`store_protocol_candidate/`为仅替Store的后继候选和独立原生工具，修复唯一目录释放与首次重试CAS冲突，已另冻导入，14项模型及23进程/370项真实文件专项符合预期，延迟写入首批暴露外部PID判死问题，须先修统一恢复准入，尚无完整恢复或生产资格。当前资格见[本批README](../qa/campaign_progress_recovery_20261026/README.md)。

`qa/huangnigang_production_20261020/`：当前七车十一担生产接入、真实路线和内部冷恢复驱动；源码快照、导出程序及原始运行日志存于被忽略的`.godot`同名批次目录。隔离用户目录使用同盘短路径`D:/CodexQA/hngp/<唯一标识>`，具体位置见每次收据；完成证据以本批README为准。

`qa/storage_cleanup_20261020/`记录六份入口文档归档、哈希、重复缓存映射、实际删除流水和保护后验。10月19日旧缓存清理见[原记录](../qa/storage_cleanup_20261019/README.md)，本次Steam交付见[发布QA](../qa/steam_release_20261019/README.md)。

每类信息只维护一个当前入口，其他文档用链接引用；旧批次PID、命令和状态留对应QA，不再六处复制同一段过程日志。新增实现与QA目录后更新本索引，保留原图/提示/父图/原著依据/失败记录。候选与生产、源码同步与平台交付分别说明。

[历史全文与恢复说明](../qa/storage_cleanup_20261020/README.md)含整理前完整3,509行索引；旧来源清单绝对路径不批量改写。

## 2026-10-20 待提交来源入库

- `qa/pending_source_sync_20261020/`：原107个文件清单、SHA与只读检查。
- [公孙胜原型](../qa/gongsun_sheng_mounted_draw_20261019/README.md)：补齐剑臂与rig_v1/v2/v3候选源码。
- [杨林连续腿预览](../qa/yang_lin_continuous_leg_preview_20261019/README.md)：补齐构建/诊断/HTML/JS，候选未采用。

## GitHub导航与协作文件

- [CHANGELOG](../CHANGELOG.md)：Steam更新及15个历史GitHub Release索引。
- [CONTRIBUTING](../CONTRIBUTING.md)：协作与反馈入口。
- [docs导航](README.md)、[QA导航](../qa/README.md)：当前文档与证据分工。
- [仓库约定](GITHUB_REPOSITORY.md)：两个分支、38个标签、Release与管理员字段。
- `qa/github_organization_20261020/`：本次平台快照与整理检查。

## 2026-10-26 历史测试快照

`qa/storage_cleanup_20261026/` 保存54个旧project的归档索引、逐文件清单、SHA校验、保护结果和恢复工具；本机ZIP位于外层`归档/`，不入Git。旧批次原目录保留恢复提示及原有`.godot`，需要复验时先按[恢复说明](../qa/storage_cleanup_20261026/README.md)还原对应快照。

## 2026-10-26 第二轮与失效归档入口

`qa/storage_cleanup_20261026_round2/`：三个旧project的重复文件->当前保留文件/Git blob映射、独有文件索引、恢复器和保护检查。上一轮ZIP及9月7日7z已在其他聊天按用户要求删除，旧QA顶部已有现状提示；最新入口见[第二轮说明](../qa/storage_cleanup_20261026_round2/README.md)。

## 2026-10-26 战役奖励交接候选与故障证据

`qa/campaign_progress_recovery_20261026/process_liveness_candidate/`：独立C# Windows进程查询helper、Godot三态适配器和构建/模型/原生组件证据。已有13例helper、22项模型、49项Godot组件及独立19项超时检查通过；exe在忽略产物中，后继Store恢复准入另验。

`qa/campaign_progress_recovery_20261026/live_owner_candidate_tests/`：真实双进程活写者保护驱动；f6ef基线已复现活锁误清理，原始证据见同级`evidence/live_owner_baseline_20261026_234140/`。诊断成功不等于修复通过。

`qa/campaign_progress_recovery_20261026/process_liveness_integration_candidate/`：base/Steam Store、进程级manager和oracle v2的独立恢复候选、来源清单及专项验证；资格以该目录实测收据为准，未采用生产。

`qa/campaign_progress_recovery_20261026/prepare_liveness.py`：23脚本及固定native helper的独立冻结入口；默认预检，`--prepare`只创建新的私有工程，不启动引擎或改生产。导入和运行需另占共享通道。

`qa/campaign_progress_recovery_20261026/handoff_candidate/`：20文件独立候选、精确清单、模型/尾账回归/真实I/O/经典30波外部驱动及后继恢复协议设计。`evidence/` 保留每版来源、原始失败和成功worker收据；`generated_uids/` 是绑定冻结身份的少量文本证据，不能作为普通缓存忽略。当前范围和未验证门槛以[候选说明](../qa/campaign_progress_recovery_20261026/handoff_candidate/README.md)为准。

`qa/campaign_progress_recovery_20261026/tests/lianhuanma/`与`run_lianhuanma_terminal.py`：实际菜单/Flow的四进程自然胜利驱动，独立绑定当前20文件候选；只读身份预检通过，尚未编译或原生验收。使用方式及不授予的资格见[执行器说明](../qa/campaign_progress_recovery_20261026/tests/lianhuanma/README.md)。

`qa/campaign_progress_recovery_20261026/tests/lianhuanma_loss/`与`run_lianhuanma_loss.py`：真实Flow自然失败三进程代码，尚未原生运行。`evidence/store_protocol_io_20261026_220853/`保存23进程/370项已退出前提的真实文件证据；`store_delayed_first_failed_20261026_223919/`及`process_liveness_api_20261026_225300/`保留外部PID判断失败、最小原生API复现和官方来源。

## 2026-10-27 存档恢复与交错专项

`qa/campaign_progress_recovery_20261026/process_liveness_integration_candidate/tests/io_v2/`：严格23脚本＋helper的独立执行适配；23进程370项文件故障、4进程129项延迟写入已通过。原始输入、宿主、断点、helper JSON与逐文件SHA分别保存在 [文件专项](../qa/campaign_progress_recovery_20261026/evidence/liveness_io_v2_20261027_003556/README.md)、[交错专项](../qa/campaign_progress_recovery_20261026/evidence/liveness_delayed_v2_20261027_010849/README.md)，合成账号目录、exe与缓存留本机。半pending拒绝与成功恢复分别记录，不授全战役或SDK资格。

## 2026-10-27 继续入口三脚本候选

`evidence/classic_recovery_baseline_20261027_022930/`保存旧源两案82项缺陷复现；`evidence/classic_recovery_fixed_partial_20261027_023731/`保存新源pending成功/record超时、实际helper查询和完整失败输入。均位于`qa/campaign_progress_recovery_20261026/`，后者整体未通过。

`qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/`保存高俅章节runtime单文件候选、相对d7差异和13项来源；`integration_768/`准备器已创建941c4786完整冻结并独立导入。`tests/gaoqiu_training/`及`run_gaoqiu_training.py`为三进程正常造船续玩工具；`tests/gaoqiu_loss/`及`run_gaoqiu_loss.py`为已通过三进程200项的自然失败/终局拒槽工具；`evidence/full_freeze_20261027_050851/`保留准备/导入原件，`evidence/training_complete_20261027_052101/`保留实际造船三进程190项原件；`evidence/loss_complete_20261027_054801/`保留自然失败200项原件；`tests/gaoqiu_terminal/`为核心胜利四进程工具，首次语法失败、`terminal_load_check_20261027_061546/`加载检查与`terminal_wave_failure_20261027_061644/`首次策略失败分别保留，完整玩法仍待验证。当前资格统一见该目录`VALIDATION.md`，未采用生产。

`evidence/lianhuanma_victory_20261027_014835/`与`evidence/lianhuanma_loss_20261027_020834/`分别保存当前d7源自然胜利345项、自然失败205项原件、来源映射与SHA清单。`continue_binding_candidate/tests/classic_recovery/`是独立的中断保存源码分支诊断工具，初始私有gate与公开入口资格分开，实际结果统一见下方VALIDATION。以上路径均相对`qa/campaign_progress_recovery_20261026/`。

qa/campaign_progress_recovery_20261026/continue_binding_candidate/：Flow/Session/本地生命周期修复、新独立冻结准备器、baseline/fixed真实磁盘模型及来源。当前资格集中于 [VALIDATION](../qa/campaign_progress_recovery_20261026/continue_binding_candidate/VALIDATION.md)，原README与source_manifest保持准备时字节；新增分支诊断工具未运行时仍不得当公开入口验收。

`qa/campaign_progress_recovery_20261026/daming_continue_candidate/evidence/flow_load_20261027_065614/`保留五GD原生加载原件；`evidence/fixture_model_20261027/`保留A闭合原件留存的53项隔离模型。`tests/daming_flow/fixture_freeze.py`只冻结已退出A的两份原件，后续只pin副本；未复制业务存档至Git。高俅`terminal_guard_failure_20261027_064112/`和`terminal_focus_load_20261027_070450/`分别保留纯H实跑失败与点目标策略加载证据。

`qa/campaign_progress_recovery_20261026/projectile_filter_candidate/`保存正常箭矢MIP过滤与Graph合同的最小修复、组件工具、无缓存完整准备/首次冷导入器，以及仅更新准入的新高俅复跑宿主。`VALIDATION.md`记录当前边界。大名府`tests/daming_negative_v2/`只包含52负例的准入与规划草案，完整负例执行循环尚未实现；`evidence/flow_first_failure_20261027_072035/`保留首轮A/B通过、C伤员阵亡的失败原件，业务存档载荷留本机。

大名府`evidence/flow_escort_load_20261027_080320/`保留新护送策略五GD独立加载的32命名pins；新统一源宿主位于`projectile_filter_candidate/run_daming_flow.py`及`tests/daming_replay/`，只改26+1/cold准入，尚无新实跑结果。
新统一源完整准备与首次冷导入原件：`qa/campaign_progress_recovery_20261026/projectile_filter_candidate/evidence/full_freeze_20261027_075456/`，只授该源准备和冷导入资格。

新52执行代码及8GD加载清单：`daming_continue_candidate/tests/daming_negative_v2/`；加载原件：同候选`evidence/negative_load_20261027_084545/`。高俅b22失败原件：`projectile_filter_candidate/evidence/terminal_toggle_failure_20261027_081838/`。以上均位于`qa/campaign_progress_recovery_20261026/`下。

高俅真实Viewport toggle修订加载原件：`qa/campaign_progress_recovery_20261026/projectile_filter_candidate/evidence/terminal_toggle_load_20261027_090855/`。

原19类故障当前协议适配：`qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/persistence19/`保留19案映射、GD worker、只读默认计划、真实9／12协议证明和19进程宿主。当前19个独立进程／566项组件矩阵已通过；原失败和协议证明仍单独保留。[矩阵原件](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/evidence/persistence19_matrix_20261027_103731/README.md)为99文件紧凑归档，当前资格以专属VALIDATION为准。

高俅完整胜利416项原件：`qa/campaign_progress_recovery_20261026/projectile_filter_candidate/evidence/terminal_core_success_20261027_091102/`。外部七GD加载的seed冲突失败及最小修正：同候选`evidence/tools_load_seed_failure_20261027_094230/`；原19工具当前资格见`tests/persistence19/VALIDATION.md`。

大名府双路线部分结果原件：`qa/campaign_progress_recovery_20261026/daming_continue_candidate/evidence/flow_escort_partial_20261027_094353/`。原七GD修正后加载：同QA下`projectile_filter_candidate/evidence/tools_load_complete_20261027_101643/`；真实保存／取消／文件占用重试三进程外部工具：`projectile_filter_candidate/tests/ui_save_retry/`。

`projectile_filter_candidate/evidence/persistence19_protocol_20261027_101914/`为实际9／12故障证明60项原件；`ui_save_retry_load_20261027_102958/`与`guard_margin_load_20261027_103329/`为对应外部GD加载原件，均位于同候选evidence下。A修订后实际三进程216项已通过；新大名府双角色八流程未完成，加载不授实际流程资格。

`qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_config_retry/`与`tests/ui_startup_retry/`分别为B1设置重试、B2启动恢复重试工具，B1修订后实际两进程406项通过，B2实际三进程387项通过，各自VALIDATION维护当前资格。三GD纯加载原件位于同候选`evidence/ui_config_retry_load_20261027_111841/`（36运行pins）与`evidence/ui_startup_retry_load_20261027_111956/`（40运行pins）；均未实例化worker。

`qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_terminal_retry/`：自然核心终局四进程的6GD、宿主、契约与来源，新C不继承旧高俅416项；原六GD已加载，首跑宿主末阶段取证失败原件保留；Python宿主修正后新profile四进程737项完整通过。`evidence/ui_save_retry_breakpoint_failure_20261027_112148/`、`ui_config_retry_codec_failure_20261027_113510/`分别保存两次未完成首跑；`ui_save_retry_rearm_load_20261027_114727/`保存A修订加载，`config_active_key_probe_20261027_114911/`保存StringName语言模型与原Codec结果，均位于同候选evidence下。模型、加载与完整UI链分开记资格，业务载荷与host blocker不入Git。


`projectile_filter_candidate/evidence/ui_retry_tools_load_20261027_121008/`保留B1/B2/C修订组合12GD原生加载原件：129运行pins、62文件，实际流程资格仍分别维护于各工具VALIDATION。


`projectile_filter_candidate/evidence/ui_save_retry_complete_20261027_115057/`保存修订后A三进程216项完整原件与来源引用：31文件，864运行pins；其旧失败档继续保留。


`qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_release_fault_model/`保存D永久时钟故障下的真实RetryRelease／Leave／NO_SLOT两进程工具；同候选`evidence/ui_release_fault_load_20261027_122159/`保存44pins的三GD原生加载原件。模型实际执行资格见VALIDATION，加载未注入故障。


`projectile_filter_candidate/evidence/ui_config_retry_complete_20261027_121110/`保存B1设置重试两进程406项原件：17文件、849pins分类闭合；不包含私有业务profile、blocker载荷或EXE。


`qa/campaign_progress_recovery_20261026/daming_continue_candidate/evidence/flow_inner_failure_20261027_122311/`保存内圈修订首A307项的失败原件与冻结源码映射：13文件，未safe／未保存，实际伤员自然阵亡；物理profile和EXE未复制。侧向脱离修订与新执行资格见同候选VALIDATION。


同一`projectile_filter_candidate/evidence/`下：`daming_first_exit_load_20261027_125222/`为新侧向路线五GD纯加载原件（69pins，39文件）；`ui_startup_retry_complete_20261027_124055/`为B2中断写入后的启动恢复387项原件（871pins，28文件）。三份private_prepared_scope物理业务副本只保descriptor，不入Git。


`projectile_filter_candidate/run_lianhuanma_replay.py`及`tests/lianhuanma_replay/`保存b22胜4／败3同源复跑适配、README／来源表与当前VALIDATION；原九GD仍从原tests目录逐字冻结。同QA下`daming_continue_candidate/evidence/flow_flank_failure_20261027_125326/`保存侧向移动已生效、首次safe前仍自然失败的13文件原件，未复制业务profile／EXE。


`projectile_filter_candidate/evidence/pursuit_lian_load_20261027_134543/`保存大名府五GD与连环马九GD组合原生加载原件（59文件、118pins），只授加载。`ui_terminal_retry_checkpoint_failure_20261027_131330/`保存C四报告737项通过但宿主D取证失败的24文件原件，原整批资格false；`ui_release_fault_model_complete_20261027_134727/`保存D永久故障模型两进程154项完整原件（15文件、854pins），模型注入与自然运行资格分开。以上均位于`qa/campaign_progress_recovery_20261026/projectile_filter_candidate/evidence/`；物理业务profile、blocker原载荷及EXE均未复制。


`daming_continue_candidate/evidence/flow_pursuit_cancelled_20261027_135845/`为根任务确认QA集合点缺陷后主动中断的9文件原件，非自然失败、无最终GD报告；`projectile_filter_candidate/evidence/daming_pursuit_regroup_load_20261027_141224/`为该单调用修正后五GD加载原件（39文件／69pins）。两者均位于`qa/campaign_progress_recovery_20261026/`下。


`qa/campaign_progress_recovery_20261026/projectile_filter_candidate/run_gaoqiu_training.py`、`run_gaoqiu_loss.py`与`tests/gaoqiu_aux_replay/`保存高俅造船／自然败局到b22的外部复跑适配；原七GD继续取自gaoqiu_continue_candidate/tests，不重复复制为新的玩法实现。当前资格单独维护于[VALIDATION](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/gaoqiu_aux_replay/VALIDATION.md)。


`projectile_filter_candidate/evidence/ui_terminal_retry_complete_20261027_141329/`为C宿主修正后的新profile实际四进程737项原件：21文件、905pins、完整来源／句柄／helper／子进程／锁终态通过；独立重启正常空checkpoint的实际磁盘读回已通过。该路径相对`qa/campaign_progress_recovery_20261026/`，旧取证失败档保持原资格。


`projectile_filter_candidate/evidence/gaoqiu_aux_replay_load_20261027_144549/`保存高俅造船3GD／自然败局4GD在b22上的纯加载原件（45文件／83pins），只授加载；同源实际三进程仍分别待跑。路径相对`qa/campaign_progress_recovery_20261026/`。


`qa/campaign_progress_recovery_20261026/daming_continue_candidate/tests/qualification61/`保存1+8+52同源原件核验器、来源合同、README和独立VALIDATION；复用原八Flow／closed-A准入及52报告验证，默认不启动引擎／profile，原部分批已实证拒绝，完整正向证据尚缺。该工具不运行或补造61阶段，不授原19／全战役／SDK资格。


`daming_continue_candidate/evidence/flow_pursuit_guard_failure_20261027_144758/`为Lu四报告746项通过、Shi首A近卫损失失败的18文件原件（875pins、整批933项932通过）；`projectile_filter_candidate/evidence/daming_guard_reserve_load_20261027_153202/`为普通预留护卫选择修订后的五GD纯加载原件（39文件／69pins）。路径均相对`qa/campaign_progress_recovery_20261026/`；两份Lu closed-A业务record及EXE仅保留hash元数据，原件不入Git。


`qa/campaign_progress_recovery_20261026/daming_continue_candidate/evidence/flow_complete_20261027_153316/`保存双角色八进程1398项完整原件：23文件／884pins，完整来源／自身cold／子进程／锁终态通过；四份原closed-A业务record及8EXE仅hash元数据，不入Git。后续52执行器固定消费这批完整原件；8通过不等于52／61已完成。

`daming_continue_candidate/evidence/negative_timeout_20261027_162116/`保留首次52负例首world超时原件：8文件／1810pins，原业务record只hash；`projectile_filter_candidate/evidence/daming_negative_timing_load_20261027_164702/`保存仅增加耗时输出的8GD纯加载原件：39文件／72pins。两路径相对`qa/campaign_progress_recovery_20261026/`，不授52／61通过。

`qa/campaign_progress_recovery_20261026/daming_continue_candidate/evidence/negative_timed_timeout_20261027_164910/`保存耗时版首world完成177／264行后900.252秒超时原件：8文件／1810pins，177行不授world／52／61；后继172552以既有CLI的3600秒宿主等待预算重新完整执行，原worker与断言保持。

`daming_continue_candidate/evidence/negative_apphang_20261027_172552/`保存首world在255行后Windows Application Hang关闭原件：9文件／1810pins，系统事件原XML只本地保留；`projectile_filter_candidate/evidence/daming_event_pump_load_20261027_175125/`保存暂停态逐行让帧版8GD纯加载：39文件／72pins。两路径相对`qa/campaign_progress_recovery_20261026/`；完整52／61待新批实际结果。
