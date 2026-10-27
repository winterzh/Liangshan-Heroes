# 源码设置与换机（2026-10-27）

## 当前入口

本机开发目录：`D:/AI项目/水浒/开发工程`；打开其中 `project.godot`。桌面旧目录为历史兼容入口。黄泥冈首批开发已切回 `codex/sync-20260905-stable`，从main/stable同源的1598c7c0开始；已验证实现及证据提交`f5325c25`已推送并回读一致，后续交接文档独立同步，最新SHA仍以Git回读为准。[当前版本](PROJECT_STATUS.md)、[开发计划](DEVELOPMENT_PLAN.md)。

## 启动与导入

需要Godot **4.6.3**。仓库根目录运行 `Play.cmd`；进入编辑器用 `Play.cmd -Mode editor`，仅准备导入用 `Play.cmd -Mode import`，强制重新导入加 `-Reimport`。启动器会先检查导入缓存。

本机引擎路径依次来自 `-GodotPath` 参数、`GODOT_PATH` 环境变量、被Git忽略的 `godot.local.txt`，最后查PATH。不要将机器绝对路径、SDK凭据或签名配置写入生产脚本。Steam发布程序与源码启动分开，不能用编辑器启动代替发行包验收。

## 换机与Git同步

在自己的Git checkout开发，不嵌套克隆。开工先运行：

```powershell
git status --short --branch
git remote -v
git fetch origin
```

核对目标分支和远端后，仅在无未完成修改且可快进时 `git pull --ff-only`。若有分叉或共享修改，先检查来源，不自动stash、reset或覆盖。既定开发同步分支为 `codex/sync-20260905-stable`；本次主线合并有用户明确授权，未来合并和平台发布仍按AGENTS.md与当次授权。

每轮验证后同步更新本文件、WORKLOG及本批文档；按逐文件白名单提交，不用全盘git add、强推或改写历史。推送后读回远端SHA。禁止上传Steam登录/缓存、玩家存档、Godot缓存、安装包、密钥和无关历史备份。

## 验证与共享引擎

后继[恢复读集候选](../qa/campaign_progress_recovery_20261026/recovery_readset_candidate/VALIDATION.md)使用新768b6e59完整冻结，仅替Store；已独立导入并通过新源真实Flow两处中断/恢复的四进程88项。prepare_readset默认只读，--prepare仅复制新工程；测试必须使用新完整清单及同引擎的独立成功导入，不能复用d7运行资格。原失败档仅在逐字新副本验证，content不改写；该Store诊断不能替代新源正常Flow。

readset专项在全新profile已完整通过：12类案例248项、旧4MB逐字副本37项，共285项；3个实际进程及25次helper查询终态、来源后验和锁释放通过。两次执行器失败原件保留，正式计数只取各reader最终report，不累加case快照或prepared检查。旧档恢复只授Store协议资格，不授跨版本世界加载；原件和本次证据见候选VALIDATION。

新增[classic只读计时工具](../qa/campaign_progress_recovery_20261026/continue_binding_candidate/tests/classic_recovery_timing/README.md)固定d7源与原失败批次；默认只读预检，显式执行时仅对逐字隔离副本运行原API，原profile不得交给引擎。[本次诊断](../qa/campaign_progress_recovery_20261026/evidence/classic_recovery_timing_20261027_031418/README.md)15项检查通过，首次inspect仍超时；诊断完成不等于恢复通过。

[高俅当前验证](../qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/VALIDATION.md)使用新的941c4786完整冻结及其独立成功导入，完整7062文件只换Session；[准备器](../qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/integration_768/README.md)默认轻量检查不授运行准入。新[造船三进程工具](../qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/tests/gaoqiu_training/README.md)无参数仅核代码来源，--base-run核完整新源，--run才占共享锁启动；真实运行时直接一次完整准入，不预先重复。新源活动期造船三进程190项已通过，实际来源/原件在VALIDATION；新[自然失败工具](../qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/tests/gaoqiu_loss/README.md)已完整通过三进程200项，含正常败局及独立重启拒旧槽；[核心胜利工具](../qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/tests/gaoqiu_terminal/README.md)已修复初次语法问题并通过原生加载，后继普通点目标路线已清完正常首波，实际保存拒绝TIMED_RENDER_OVERRIDE/projectile；另建最小视觉合同修复候选，完整玩法尚无胜利资格。执行同样要求新Gao prepared_state完整准入，不能沿用其他路线通过结果。

新增[大名府三脚本候选](../qa/campaign_progress_recovery_20261026/daming_continue_candidate/README.md)保留941c已有增量，只补正常Level8定义及严格单囚安全撤离合同。来源和三份diff静态核验通过；[独立准备器](../qa/campaign_progress_recovery_20261026/daming_continue_candidate/integration_941/README.md)默认仅核34项指定来源，显式--prepare才完整验证941c并新建只替3个已有文件的工程。清单从23扩为25项是补跟踪两个已有脚本，不新增游戏资源；自己的成功导入仍为运行准入。新3365完整准备及独立导入已完成，原生玩法结果以[当前验证状态](../qa/campaign_progress_recovery_20261026/daming_continue_candidate/VALIDATION.md)为准；旧61阶段与19类故障门槛保持。

新增[继续入口三脚本候选](../qa/campaign_progress_recovery_20261026/continue_binding_candidate/VALIDATION.md)必须用自己的d7f2258b完整冻结与新manifest，不能套用e97a的恢复专项资格。已导入并通过独立本地绑定模型，连环马实际Flow自然胜利345项及独立自然失败205项通过。prepare_continue默认只读，--prepare只建新目录；磁盘模型的baseline/fixed模式和真实胜败执行器分别记资格，禁止复用同一结果混算。

当前新增[进程存活三态组件](../qa/campaign_progress_recovery_20261026/process_liveness_candidate/README.md)，已有13例原生helper、22项报告模型、49项Godot组件及独立19项超时证据；未集成生产。构建exe只留忽略产物，换机必须按源码构建并核对本次SHA；Godot组件执行器默认只读预检，显式`--execute`才持共享锁运行。[同步恢复桥接](../qa/campaign_progress_recovery_20261026/process_liveness_integration_candidate/README.md)另行验证，不能把独立组件通过当成存档修复完成。

后继23脚本候选已独立冻结/导入，活写者保护双进程45项、同源23进程文件故障370项及两种延迟写入交错4进程129项通过；半 pending 明确安全拒绝，未授完整恢复或双 Ledger 全并发资格。`prepare_liveness.py`默认只读，`--prepare`只准备新私有工程，实际导入及原生运行分别占共享引擎；当前运行命令和精确身份集中在[桥接入口](../qa/campaign_progress_recovery_20261026/process_liveness_integration_candidate/README.md)，不采用到生产或沿用旧冻结资格。

基础[20文件奖励交接候选](../qa/campaign_progress_recovery_20261026/handoff_candidate/README.md)为独立冻结`20261026_194542_27c8aea9`、身份`source-v1:23c0b07fcba83a9d7938ed338a9775559b6041be61d048db619c31fd5edc2a80`，已导入并通过99项模型和纠正/尾账逻辑回归。真实I/O已完成13阶段专项（含两类预期拒绝），同源黄泥冈自然终局/重启拒旧槽另通过1386项，经典30波六进程443项也已通过（30波778敌、三次保存独立恢复、两次终局拒旧槽）；不能把旧811源75/135项或14文件源1364项转授新版。原脚本、原worker和失败证据保留；准备/模型/文件故障/经典30波执行器及未运行范围在该目录说明。

后继[唯一目录释放候选](../qa/campaign_progress_recovery_20261026/store_protocol_candidate/README.md)必须用自己的20文件清单另建冻结；19文件与23c原字节一致，仅替Steam Store。新冻结`20261026_211212_dd3104df`的f6ef源码已导入、14项模型及23进程/370项真实文件专项通过（含半pending预期拒绝），延迟写入首批因外部PID存活查询限制停止，须先修统一恢复准入再另冻验证；旧23c经典通过不授予f6ef完整回归资格。模型、23进程真实文件故障及[两种延迟写入交错](../qa/campaign_progress_recovery_20261026/store_protocol_candidate/tests/io/README_delayed.md)均有独立宿主，不能套用旧23c或旧199c冻结的结果。经典回归运行时固定其外部worker/README；不要边跑边改。

连环马新增[四进程自然胜利执行器](../qa/campaign_progress_recovery_20261026/tests/lianhuanma/README.md)：默认只读预检，必须显式`--run`才启动引擎。原f6ef预检保留为历史准备。宿主现已分别绑定e97a与d7f2258b的23脚本和固定helper，胜利四流程及失败三流程各自串行运行、各自取得资格；实际终态以执行器收据为准，旧源预检不转授新版。保存退出走真实Flow，前两阶段由生产AppLifecycle正常退出，不能用Session直调替代。最新d7源胜败终态已分别通过，当前结果以[继续入口验证](../qa/campaign_progress_recovery_20261026/continue_binding_candidate/VALIDATION.md)为准；原执行器README保留准备时输入。

新的[战役context候选](../qa/campaign_progress_recovery_20261026/README.md)有独立准备/导入及训练执行器；连环马135项验证新生命周期活动期，黄泥冈1364项验证正常离线终局和重启旧槽拒绝。使用同一已导入冻结根、外部驱动和新隔离profile，`CAMPAIGN_QA`须为空，不能对旧候选或下一奖励交接草稿转授结果。

连环马新增[三进程训练执行器](../qa/lianhuanma_resume_20261026/README.md)，复用已导入且身份匹配的冻结工程，在独立短profile、屏幕外真实GL上运行，最终100项通过。它只证明旧内部活动期同槽接续；新的战役context事务候选须重新冻结，不能沿用这份结果。真实迷雾存档不能用headless dummy渲染替代，跨进程报告使用无损Codec保留整数类型和浮点位。

黄泥冈当前已接入七车十一担与内部v2存档边界。最终冻结`20261026_162550_230a5af6`的包内普通计时路线1206项和九阶段专项1768项通过；原版EXE启动/退出检查通过，完整键鼠流程待继续。用户暂不恢复界面自动操作，后续代码/文档工作可继续；不得据此标为整批完成或开放战役续玩。复现命令、精确来源及历史失败统一见[本批QA](../qa/huangnigang_production_20261020/README.md)。新生成旧三担夹具时须使用真实旧Git基线；七车实现提交后，当前HEAD不再是旧布局，不能重标v2档作为旧档测试。

依据具体修改选择对应 `qa/` 及实现文档的当前入口。旧harness/producer只证明其绑定的冻结源码，不因为文件仍在就能用于新版本。先检查已有执行器/共享锁及实际进程，等自然空闲，串行使用Godot；不重复启动或控制其他聊天的进程。新执行器按相应审查要求接入，失败原证据保留。

旧私有测试工程的重复缓存已有清理记录；复验前按对应Godot版本重新导入，或按保留副本与SHA映射恢复缺失文件，不能覆盖仍存在的差异缓存。主缓存、源码/原图、发布包、存档和Git对象不在本轮删除范围。

## 发布与历史

当前Steam Build26048429，冻结生产来源0083b47a；[发布指南](STEAM_RELEASE_GUIDE.md)、[本批更新文档](STEAM_UPDATE_20261019.md)。源码同步、上传、default上线、四语公告、客户端下载/启动与真人接受分别记录。完整战役续玩未开放，经典固定30波保存/继续保留。

[历史全文与恢复说明](../qa/storage_cleanup_20261020/README.md)包含本次整理前全部设置/旧工具说明。临时批次命令留在对应QA，避免再次把历史状态堆入当前启动入口。

## 2026-10-20 待提交候选已全部保存

原81份资源导入配置及26份候选工具/预览源码已补交，详见[入库记录](../qa/pending_source_sync_20261020/README.md)。`.import`设置随原资源入库，`.godot`生成缓存仍不上传；候选绝对路径与冻结绑定只作原批快照，换机执行前重新核对，不据源码同步授予生产资格。

## GitHub入口

当前版本与历史安装包见[更新记录](../CHANGELOG.md)，分支和管理字段见[仓库约定](GITHUB_REPOSITORY.md)，源码参与方式见[协作说明](../CONTRIBUTING.md)。专题资料从[文档导航](README.md)和[QA导航](../qa/README.md)进入，不移动原有工具/素材路径。

## 旧测试工程恢复（2026-10-26）

54 个旧人物测试 project 已转为本机去重归档；历史 receipt/重放需要这些路径时，先按[本批说明](../qa/storage_cleanup_20261026/README.md)恢复所选 prefix，再使用原绑定的引擎与数据。当前游戏启动方式不变；主缓存、旧私有缓存、当前黄泥冈和Steam批次保留。

## 旧快照恢复状态更新（2026-10-26）

上一轮54快照ZIP及9月7日7z已按用户在另一聊天的明确要求删除，不能再依赖旧归档路径恢复。第二轮三个旧快照只去掉与现有文件和Git原始blob一致的副本，按[本轮映射与恢复器](../qa/storage_cleanup_20261026_round2/README.md)补齐；未列入映射的独有文件和私有缓存保持。

连环马[自然失败三进程执行器](../qa/campaign_progress_recovery_20261026/tests/lianhuanma_loss/README.md)已完成代码和静态复核，尚未编译或原生执行；与胜利驱动各自保留独立来源和报告，不共享通过资格。

[箭矢视觉合同候选](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/VALIDATION.md)以3365为底，只替VisualGraph。组件模型仅命名来源范围；integration_3365默认只读，--prepare才另建无导入缓存种子的完整工程，--import-cold在自有锁内再次核完整冷库存后首次导入，失败不能热重试冒充冷导入。新高俅宿主只接受其完整冷导入资格，外部五GD保留原玩法断言，任务展开改为真实Viewport输入。大名府实际A/B两次保存恢复已通过，C护送失败；[52执行工具](../qa/campaign_progress_recovery_20261026/daming_continue_candidate/tests/daming_negative_v2/README.md)已完成完整执行循环及8GD原生加载；执行前仍必须严格通过同源八Flow终态/原A夹具/自有cold准入，不能按加载通过宣称52通过。

大名府普通护送修订已通过3365上的五GD加载，真实双角色下一轮改用projectile_filter_candidate/run_daming_flow.py，严格消费b22完整冻结及自己的首次cold成功收据。DF_SOURCES继续绑定原五GD/fixture清单，新宿主和README另有独立replay清单；两者均进入运行pins，不将新宿主误充旧worker来源。当前b22完整准备和自有首次冷导入均通过（PID55952，退出0/错误0，77.656秒）；generation e4caa656、expected identity c1386aae。高俅新源四进程125/131/96/64项共416项全部通过，两次保存、自然核心胜利和终局拒旧槽闭合；来源后验与锁释放通过。大名府前次首A因全军集合条件未满足而未保存；后继实际护送组策略已通过五GD加载；卢先四进程633项全过，石先首A近卫轻微移出140px条件而失败，完整八流程仍未通过。

[原19故障工具](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/persistence19/VALIDATION.md)固定b22及自身首次冷导入；默认36／41项命名输入检查不授完整准入。真实9／12故障协议60项与随后19个独立进程／566项组件矩阵均已通过，后者严格消费同源、同工具的协议收据；case6仅有本案原坏CFG的一条预期EOF解析诊断，其余无原生错误。重跑仍使用`prove_fault_protocol.py --prove`和`run_persistence19.py --run --protocol-receipt`的原门槛，工具或来源变化后不得沿用旧proof。仅组件资格，不证明自然战斗、公开入口、SDK、云上传或奖励仅一次。

[界面保存重试工具](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_save_retry/README.md)使用固定b22，默认仅18项命名输入；`--run`才完整准入并执行同profile三进程。第一进程真实gen1保存；第二进程确认／取消、真实owner删除句柄占用及同Session／Store／proposal重试至gen2；第三进程菜单读取拒绝、CloseError、解占用再继续gen2。修订后实际三进程216项及完整来源后验已通过，不能当作公开入口或OS验收。

[B1设置重试](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_config_retry/VALIDATION.md)已通过15项命名输入／10份Python AST及三GD原生加载；[B2启动恢复重试](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_startup_retry/VALIDATION.md)已通过17项命名输入／12份Python AST及三GD原生加载。加载只检查`can_instantiate`，不实例化worker，不授UI执行资格；B1修订后实际两进程406项已通过；B2实际三进程387项已通过（producer预定非零中断，两reader正常退出）。实际运行须完整b22、自身首次冷导入和共享引擎锁准入。B1使用自有`campaign_cfg_candidates`父路径regular-file阻塞；B2使用完整prepared journal、原死owner与candidate不共享删除句柄，不能把两种故障或成功资格互相替代。

当前UI重试执行须先看[A保存](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_save_retry/VALIDATION.md)、[B1设置](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_config_retry/VALIDATION.md)、[B2启动恢复](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_startup_retry/VALIDATION.md)、[C自然终局](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_terminal_retry/VALIDATION.md)的最新来源和资格。首跑验证器失败不复用profile续称通过；A修订新profile三进程216项已通过，B1/B2/C统一修订组合57命名来源／18Python AST及12GD原生加载已通过（PID40988，129pins）；B1新profile两进程406项通过，B2实际三进程387项通过。C旧批四份GD报告737项通过但宿主D取证失败原件保持false；Python宿主窄修后新profile141329_f6e4c555实际四进程737项完整通过，原槽1→2、自然终局两次真实故障后同事务完成LC3／ACK2与CFG1→2、独立重启拒旧槽及真实磁盘读回闭合，来源／句柄／子进程／helper／锁后验通过。新C四进程宿主run_ui_terminal_retry.py默认只读，--run才完整b22／自身cold准入并重跑原两保存、真实终局重试和独立拒旧槽，不能沿用旧416资格。


[D释放失败模型](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_release_fault_model/VALIDATION.md)默认只核19命名来源；run_ui_release_fault_model.py --run才以新profile完整准入并运行两进程。三GD已加载，新profile实际两进程154项已通过，来源／自有终态／锁后验通过；唯一原abort_step为明确QA注入，不允许将它写成自然玩家缺陷或成功释放恢复。


大名府最新运行状态与来源见[当前验证](../qa/campaign_progress_recovery_20261026/daming_continue_candidate/VALIDATION.md)。122311首A原100／140保护通过、后续伤员阵亡，未保存；后继routef338b3b8的普通侧向移动和真实出口路径已在125326首A验证，但仍因另一伤员自然阵亡而失败、未保存；当前保留移动核验并在(30,34)附近以普通A截击原六追兵，30命名来源与组合14GD原生加载通过（PID59876、118pins），追兵截击135845批因QA误用牢内集结判定被根任务主动中断，exit99、无最终报告；后验／子进程／锁正常闭合，不作自然失败或通过。只将城南集结调用改为既有_convoy_arrived的(30,34)判断，保留初次牢内检查；五GD重新加载PID39100／33.123秒／退出0、错误0、69pins通过，144758批最终Lu四报告746项通过、Shi首A187项中近卫不足失败，整批933项932通过，来源／子进程／锁后验通过但complete=false；不能授52前置。后继route0fee9eec只改普通预留护卫选择和全预留者到100px内，原至少三人140px条件保持；五GD新加载PID29648／30.749秒／退出0、错误0／69pins通过，新八流程153316_d6a3cb06已完整通过1398项：Lu388／104／141／65、Shi396／104／135／65；完整来源／子进程／锁后验通过。52执行器162116_c86e8835已通过完整准入并进入原生执行，整批负例尚无通过资格；必须继续消费本次完整8原收据与两份原closed-A，不能用旧部分批。继续用projectile_filter_candidate/run_daming_flow.py固定b22／自身cold准入；失败收据不授52前置，不能重用失败profile续算新成功。


[连环马b22同源复跑](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/lianhuanma_replay/VALIDATION.md)入口为projectile_filter_candidate/run_lianhuanma_replay.py；默认仅26命名来源／Python AST，--run --base-run <b22自身cold批> --route both --timeout 1500 --wait-lane 0才执行。原胜利5GD和失败4GD逐字保留，两条路线各用新profile／nonce，组合14GD原生加载已通过（PID59876、44.415秒、118pins），仅load／can_instantiate；整体7P仍待验证，旧d7通过不转授。


[高俅b22训练／败局复跑](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/gaoqiu_aux_replay/VALIDATION.md)使用独立run_gaoqiu_training.py与run_gaoqiu_loss.py；默认25／27命名来源及全部Python AST，组合36唯一命名输入。原造船3GD／败局4GD及旧来源链逐字不变；--run仅以完整26+1／自身cold及新profile执行，各三进程独立取得资格。当前七GD原生加载PID73744／42.362秒／退出0、错误0／83pins通过，仅load／can_instantiate，实际两条三进程待验，旧941训练190／败局200不转授；公开入口与生产仍未采用。


[大名府61证据核验](../qa/campaign_progress_recovery_20261026/daming_continue_candidate/tests/qualification61/VALIDATION.md)默认只核33命名来源／10Python AST，不读live profile或启动引擎；--verify --flow-receipt <完整八Flow/receipt.json> --negative-receipt <完整52负例/receipt.json>才回核同一b22／base／26+1／自身cold及全部原件。--write-proof只在全组通过后写ignored元数据，不复制业务载荷。实际旧部分Flow已被拒；当前完整正向消费待验，full_61_qualified仍未授予，原19、全战役及SDK继续单列。
