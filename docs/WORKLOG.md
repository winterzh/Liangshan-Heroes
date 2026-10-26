# 开发日志

## 2026-10-27 驻守战恢复超时只读计时

在原失败档的逐字隔离副本上运行原API，15项诊断检查通过；inventory 359.302ms、完整chain 1479.211ms，首次inspect 3807.554ms后返回原3000ms预算超时。实际helper正常退出并报告writer已退出，Oracle观察间隔119ms。首次inspect失败后未执行preclaim或recover；原件与副本各3文件/8目录完全保持。重复严格校验的成本已实测，下一步通过完整已验证字节读集绑定减少重复解析，仍保留身份、独立查询、目录和文件替换检查，不调大预算。

[原始计时及来源](../qa/campaign_progress_recovery_20261026/evidence/classic_recovery_timing_20261027_031418/README.md)。本批只是诊断完成，恢复尚未修复，不授生产、公开入口或键鼠资格。

## 2026-10-27 驻守战中断保存基线与部分恢复结果

观察器改为发射前记录真实ONE_SHOT注册后，旧e97a四进程82项完整复现两类提前读槽拒绝。d7后继四进程只有完整pending恢复成功；record案返回PROCESS_LIVENESS_TIMEOUT，整体83项中82过/1失败，完整来源后验与锁释放通过。独立核对确认record槽、owner和LC原3文件/8目录无增删改，5份实际helper JSON均确认各自writer已退出；已有查询结果不能解释总scope为何超时。保留失败及原4MB数据，下一步只读计时定位，不加大预算或降低断言。

[基线原件](../qa/campaign_progress_recovery_20261026/evidence/classic_recovery_baseline_20261027_022930/README.md)、[部分成功与超时原件](../qa/campaign_progress_recovery_20261026/evidence/classic_recovery_fixed_partial_20261027_023731/README.md)。仅私有源码恢复分支诊断，公开入口/SDK/发行版均未验收。

## 2026-10-27 高俅章节runtime最小候选准备

在d7原Session上仅新增固定Level5Factory及严格GAO_CONTEXT分支，补正常章节定义装配；原槽/账号/本地生命周期校验顺序、失败返回和成功后释放旧Core保持。独立审查、13项来源SHA及逆去新增片段逐字还原检查通过。候选Session为420b5936，尚未冻结、导入或运行，实际高俅影响尚未原生复现，不能沿用连环马结果。[代码与来源](../qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/README.md)。

## 2026-10-27 连环马自然胜败接续完成

当前d7f2258b候选的胜利四进程20261027_014835_c6004ced共345项通过，失败三进程20261027_020834_fe953cf1另有205项通过；所有实际子进程退出0，完整来源后验及共享锁释放均通过。两次实际保存退出与继续后，原20秒训练只产生一兵、预留人口保持2；自然四目标胜利与宋江自然阵亡分别结算，独立终局重启均拒旧槽，记录/进度/奖励不重复。原人口2→1失败继续保留。

[胜利原件](../qa/campaign_progress_recovery_20261026/evidence/lianhuanma_victory_20261027_014835/README.md)、[失败原件](../qa/campaign_progress_recovery_20261026/evidence/lianhuanma_loss_20261027_020834/README.md)。这是私有源码屏幕外GL的当前连环马路线结果；仍未采用生产，不授Steam SDK、公开战役继续或原版键鼠资格。独立classic分支工具首批因错误检查一次性信号的连接状态而停止；只有writer运行，未授存档恢复资格。失败输入保留，工具改为发射前注册取证，后续原生结果另记。

## 2026-10-27 继续入口三脚本修复另冻与磁盘模型通过

公开 classic 的提前读槽、credited 本地 gen1 绑定及连环马章节 runtime 三处接线已在独立候选修正。新 d7f2258b 冻结完整 7,062 文件仅三 GD 变化，导入进程46284退出0/错误0。旧 e97a 的独立磁盘模型复现 cold binding 拒绝；新源进程68316的30项修复回归通过，另外3项夹具与3项旧路径对照分别计数。此项是实际文件＋合成 credit/terminal 模型，不授 SDK 或自然结算资格。

原连环马人口2→1失败及旧源码保持。胜败宿主严格绑定新23脚本＋helper，两次默认只读预检通过；新的胜利四流程已开始，完整自然胜败与公开 classic 分支仍待独立结果。未接入生产，原版键鼠仍暂停。[当前实现、原始证据与剩余边界](../qa/campaign_progress_recovery_20261026/continue_binding_candidate/VALIDATION.md)。

## 2026-10-27 连环马实际继续入口发现章节参数遗漏

连环马真实菜单继续首批 20261027_011539_12cfec3e 已退出 1并释放共享锁：首次保存退出53项通过，恢复阶段40项中2项失败，胜利与终局拒槽尚未执行。实际训练队列预留人口从2变1；来源确认 Flow 通用 runtime 缺少 Level4.apply_overrides，而旧直接 Session 测试传入了专用 Factory runtime。本地记录比较的第二个失败由已有失败使 lifecycle_row 返回空字典连带产生，不能另判生命周期损坏。后继 Session 候选将按已验证的 Level4 context 装配固定 Factory runtime，再另冻验证，不放宽人口或保存断言。

[原始失败及执行输入](../qa/campaign_progress_recovery_20261026/evidence/lianhuanma_victory_failed_20261027_011539/README.md)。原生产与 e97a 冻结保持不变，原版键鼠仍暂停。

## 2026-10-27 新源文件恢复与写入交错专项通过

2026-10-27：同一 e97a 冻结已完成 23 进程／370 项真实文件故障专项，以及两种延迟写入交错共 4 进程／129 项检查。所有实际 PID、前后源码与引擎、原始 helper 结果、共享锁释放均通过独立回读。半 pending 的 ENVELOPE_JSON 仍是保留原件的安全拒绝；B 使用 Store+Receipt，不能据此声称双 Ledger 全并发或自动修复所有坏档。

23 进程批 20261027_003556_2423499b 为 14 个正常退出和 9 个指定断点中断，235 个最终 pin 不变；4 进程批 20261027_010849_dd205bef 的 first_after_clear 为 61 项，retry_under_barrier 为 68 项，191 个最终 pin 不变。两批终态完整，未覆盖 19 类／61 阶段、v2 超时隔离、完整战役或 SDK。

[文件故障原件](../qa/campaign_progress_recovery_20261026/evidence/liveness_io_v2_20261027_003556/README.md)、[写入交错原件](../qa/campaign_progress_recovery_20261026/evidence/liveness_delayed_v2_20261027_010849/README.md)、[独立执行入口](../qa/campaign_progress_recovery_20261026/process_liveness_integration_candidate/tests/io_v2/README.md)。连环马胜败宿主已显式绑定同一 23 脚本＋固定 helper，保持原自然路线和真实 Flow 保存退出；后续按实际运行结果独立记录，不沿用旧源资格。用户仍选择暂不恢复原版键鼠验收。

## 2026-10-27 活写者保护双进程专项通过

23脚本和固定helper的新冻结`20261027_000821_ba1f231b`导入退出0/错误0，实际身份`source-v1:e97a07b9ff04b677fbc1934a40976cc6e1f82479855cf39f305147ae4f6d1eea`。真实双Ledger批`20261027_001429_a52fb5dc`45项通过（A24/B21）、双退出0、完整来源后验通过、共享锁释放。A仍在写入时，B普通open明确返回WRITER_ALIVE且可重试，业务目录及全部文件原字节不变；A按原提案正常提交，B保留同Ledger/Store再打开并读到同一九字段proof，重复handoff无重复记奖或文件变更。

本结果仅修复并验证该活写者时序，尚未覆盖活claimant、全部死亡恢复/文件故障、v2超时隔离或战役路线；生产与公开继续入口保持原状态。旧f6ef误清理基线、manager退出崩溃及宿主失败全部保留。[完整来源与导入](../qa/campaign_progress_recovery_20261026/process_liveness_integration_candidate/evidence/full_freeze_20261027_000821/README.md)、[活写者保护收据](../qa/campaign_progress_recovery_20261026/evidence/live_owner_fixed_20261027_001429/README.md)。下一片继续死亡恢复与延迟写入专项，再推进连环马自然胜败。

## 2026-10-27 恢复桥接组件与退出生命周期修复

四文件桥接的真实组件测试发现Engine metadata强持有脚本对象会在退出时崩溃；独立三例对照确认原生RefCounted正常、Engine持脚本对象崩溃、根viewport持脚本对象正常。manager改由进程根viewport持有，跨场景保留oracle及quarantine，退出仅在Engine留下不含对象引用的状态，禁止退出后再建查询。旧失败源码、原生日志和宿主失败全部保留，没有在测试worker中手动清对象掩盖问题。

最终最小批`20261027_000715_3a07df82`正常导入及运行均exit0，22项报告模型、60项组件检查、7次真实helper查询通过；实际current_scene替换后manager和oracle同引用，前后目标创建身份一致、源码pin一致、共享锁释放。仅证明组件接线和正常退出，不授活锁/死者恢复或战役资格。新增`prepare_liveness.py`将原20文件与4文件覆盖合成23脚本，helper单独绑定源码/构建收据/实际exe并进入完整内容身份，默认只读预检；新完整候选另冻后验证。[详细范围及证据](../qa/campaign_progress_recovery_20261026/process_liveness_integration_candidate/README.md)。

## 2026-10-26 活写者误清理原生复现与超时控制

f6ef冻结的新批`20261026_234140_40126e64`已实际复现：A仍存活且停在真实acquire之后，B普通Ledger.open删除A的writing/owner；A继续原提案后返回LOCK_CHANGED，已提交记录未变。宿主绑定Win32 HANDLE/创建身份确认A存活，两进程退出0、诊断complete=true，slice_passed=false；这是缺陷复现，不是修复通过。[原始证据](../qa/campaign_progress_recovery_20261026/evidence/live_owner_baseline_20261026_234140/README.md)。

独立v1适配器超时批`20261026_233903_cf27b0b5`19项通过，实际3013毫秒超时，仅终止自己创建的休眠测试助手一次；宿主确认助手退出，目标全程存活且创建身份不变后自然退出。首轮宿主在退出后查询映像路径失败的原件、旧脚本均保留。此项只覆盖超时控制，不授Store或真实查询助手故障资格。[组件收据](../qa/campaign_progress_recovery_20261026/process_liveness_candidate/README.md)。基础Store、Steam Store与进程级manager的同步恢复候选已另存，运行状态见[独立入口](../qa/campaign_progress_recovery_20261026/process_liveness_integration_candidate/README.md)；生产、旧冻结和原版键鼠状态不变。

## 2026-10-26 三态查询组件原生验证

新增独立Windows C# helper和Godot begin/poll适配器，使用持有的Win32进程句柄、WaitForSingleObject和创建FILETIME，异常/权限不足保留unknown；不再用Godot的外部PID布尔查询判死。助手编译退出0，Python宿主13例通过；最小Godot批`20261026_232303_95fc2aac`另通过22项报告模型和49项组件检查，5次真实查询、exit0、pin前后不变、共享锁释放。原始provider JSON、worker、宿主和收据保留，exe仅忽略产物；没有修改Store、生产或旧冻结。timeout及恢复接线仍待独立验证，[组件状态与命令](../qa/campaign_progress_recovery_20261026/process_liveness_candidate/README.md)。

## 2026-10-26 外部进程判死风险复现与后继代码准备

延迟写入首批`20261026_223919_4ffc4c0b`两时序均在B检查活A时停止，整体exit1、来源后验通过、锁释放，目标交错尚未执行。官方4.6.3源码及同引擎最小原生探针确认：Godot只识别自身process_map进程，外部兄弟进程由Win32及Popen前后证实仍存活，Godot却返回false。基类SnapshotStore与候选Steam Store据false接管的路径存在正确性风险，优先修统一alive/dead/unknown准入；未运行夺锁或观察数据丢失。23IO已知退出前提的结果保留，不授活写者保护。39份失败原件及探针/官方来源保留于[诊断记录](../qa/campaign_progress_recovery_20261026/evidence/process_liveness_api_20261026_225300/README.md)，生产与旧冻结未修改。

另完成独立连环马自然失败三进程代码：实际保存退出、菜单继续后普通命令自然阵亡、再重启拒旧槽；严格验证同token/完整目标/loss ACK/CFG及奖励不增长。AST、帮助入口、独立静态复核通过，尚未编译或原生运行；胜利驱动源码保持。两条路线均待上述基础修复另冻后重新绑定。[失败驱动](../qa/campaign_progress_recovery_20261026/tests/lianhuanma_loss/README.md)。

## 2026-10-26 唯一目录释放真实故障专项通过

f6ef候选新批`20261026_220853_bcbb8766`完整23进程/370项worker断言符合预期：五种真实Windows文件拒绝重试、pending/record重启、cleanup/marker释放中断及恢复者再次中断后接手、删除尾段重启均完成；半pending明确拒绝而非自动修复。宿主exit0、23个独立PID、前后源码/引擎/pin一致、共享锁释放。149份原始文本证据已保留，合成账号目录副本留本机；旧宿主长路径失败原件保持。[本批收据](../qa/campaign_progress_recovery_20261026/evidence/store_protocol_io_20261026_220853/README.md)。后继两种延迟写入时序已启动，尚无终态结论；此批不授予双Ledger、完整战役、SDK或生产资格。

## 2026-10-26 连环马自然胜利四进程代码准备

新增独立外部驱动，覆盖真实菜单选择连环马、付费训练中的保存退出、独立继续成军且21秒无重复、第二次保存退出、再继续完成教场及四目标自然胜利，最后独立菜单拒绝旧槽。保存退出由生产AppLifecycle完成；不调用Session替代Flow、不注入摆位/伤害/任务进度、不加速。Python AST、帮助入口、独立源码复核和f6ef当前20文件/生成身份预检通过，尚未编译或原生执行。当前Store原生批继续占用共享引擎，后续按文件故障→延迟写入交错→连环马顺序执行。自然失败必须另用保存退出、恢复失败、重启拒槽三个进程，相关实现另行推进；不以旧两进程设想缩减真实保存流程。[代码及使用说明](../qa/campaign_progress_recovery_20261026/tests/lianhuanma/README.md)。

## 2026-10-26 经典完整回归通过，后继存档协议开始原生验证

23c源码六进程回归`20261026_205941_49da5b83`完整443项通过：经营/交战/换波三次真实保存、三个独立进程同token恢复，正常1倍速/60Hz在1029.85模拟秒自然完成30波778敌，厅1500血；终局后两个独立进程均拒绝旧槽，CFG/奖励/记录保持。原始报告、worker、旧失败、运行README和宿主均保留，4张图留本机未新增人工目检。不授真实SDK、原版键鼠、性能或后继f6ef源码资格。[完整收据](../qa/campaign_progress_recovery_20261026/evidence/handoff_classic_20261026_205941/summary.json)。

11bf Store的新冻结`20261026_211212_dd3104df`导入exit0/错误0，实际身份f6ef；14项命名/布局模型通过，23进程原生文件故障开始执行。原生测试的控制ACK改为写闭唯一临时文件后用不覆盖hardlink发布，避免测试误读半份通知；生产、冻结和worker不变。运行结果以[独立状态](../qa/campaign_progress_recovery_20261026/store_protocol_candidate/VALIDATION.md)和新收据为准。首轮原生前5类通过，第6类由宿主275字符路径读取失败而停止；原件完整保留，不计删除故障覆盖。宿主现已补齐扩展路径与后置异常记录，16项只读/隔离复制probe通过且原现场SHA不变，新profile全23阶段重跑已启动。

## 2026-10-26 经典回归重跑与存档释放并发修复

经典首批 `20261026_204744_59a00e09` 新局真实保存39项通过，第二进程在QA身份的原始JSON字典比较处失败；原始源码/引擎身份前后通过且JSON值相同。外部驱动改为生产Codec的精确类型编码与JSON摘要双核对；旧证据保留，新批 `20261026_205941_49da5b83` 使用全新隔离profile重跑六阶段。未修改23c候选或游戏档案，目前三个保存阶段41/58/49共148项通过，完整回归结果待终态收据。

独立Store后继候选采用唯一cleanup/marker保留原所有权字节，避免正常释放中断后出现无归属空锁。静态复核发现首次重试CAS冲突遗漏释放自有活锁，原199c源码与清单已保留，11bf已修正该分支并另冻`20261026_211212_dd3104df`；24项源码和10项宿主静态检查通过，导入仍在等共享引擎。原生23进程文件故障与两进程交错分别验证，不据静态检查授予完整恢复。原版键鼠继续按用户选择暂停。[当前候选](../qa/campaign_progress_recovery_20261026/store_protocol_candidate/README.md)。

延迟写入交错工具另补4个文件，宿主AST/帮助入口及实际断点唯一性检查通过，尚未编译或原生执行；B使用真实Store+Receipt以隔离Store分支，双Ledger最终回读被另一活锁阻挡的行为保留待办。连环马自然终局的可复用普通策略、新断言及旧61阶段差异已整理为[下一片接线](../qa/campaign_progress_recovery_20261026/LIANHUANMA_NEXT.md)。

## 2026-10-26 战役奖励交接与重启读回修复

20文件独立候选增加gen2→CFG→同token本地Steam终局回读→gen3交接；旧生命周期与账本保留严格历史读取。实际扩展测试发现JSON数字类型导致结算凭据及账本拒绝读回，另复现旧progress重试后尾账被新局清空、权威撤销成就被启动合并重新推导。四脚本修订后另冻为`20261026_194542_27c8aea9`，导入、99项纯模型及两类逻辑回归（8项宿主、14项Receipt、27项Session）通过。原始失败、811旧源四脚本与实际worker均保留。

真实Store/Ledger的9案例/13阶段文件专项已完成178项worker断言，前后身份与pin通过。正常写入、显式v2升级、实际WRITE_OPEN/两种LOCK_RELEASE重试、闭合pending/已rename记录的独立进程恢复均符合预期；半pending与缺owner空目录仍拒绝自动恢复。原执行器类型/时序/收据重名失败保留，正常文件通过不授予完整恢复资格。同一新源另完成黄泥冈普通酒计自然终局和独立重启拒旧槽1386项（1333+53），精确核对ACKv2、Service未记账proof与四语实际UI；首轮旧驱动ACKv1失败已原样保留，再按新严格契约验证。新源没有继承811旧源135项训练或14文件源1364项资格；未采用到生产、未开放战役继续、未发布Steam。后续异常释放所有权和半pending协议缺口见[当前候选及证据](../qa/campaign_progress_recovery_20261026/handoff_candidate/README.md)。原版键鼠仍按用户选择暂停。

## 2026-10-26 战役context候选活动期验证

14文件事务候选独立冻结导入后，连环马普通付费训练、恢复成军、同token再存及第三进程21秒防重复共135项通过（35/57/43）。lifecycle现在实际绑定level4、内容版本、引擎和离线owner，固定继续槽代际1→2→2，正常训练20秒只产生一名新兵；正式源码未采用。黄泥冈新终局首轮在开场按钮完整可见断言停下，原失败保留；修复布局等待后，两进程1364项通过，正常酒计终局写入同token gen3与CFG，重启拒绝终态旧槽且进度/奖励无重复。下一版可靠Steam本地交接仍为独立实现草稿，未编译/运行；原版键鼠继续按用户选择暂停。[本批证据和范围](../qa/campaign_progress_recovery_20261026/README.md)。

## 2026-10-26 连环马自然训练与同槽跨进程接续

在未修改生产源码的冻结版本上新增外部三进程驱动，正常支付36金24木、预占2人口并训练20秒：训练中保存、独立进程恢复成军、保留原token同槽再存、第三进程继续21秒验证无重复。最终`20261026_175247_098b8c87`共100项通过（27/43/30）、源码/引擎/驱动前后身份一致；槽代际1→2→2，仅第一次进程发出一次训练命令。首轮headless纹理读取失败与第二轮普通JSON数值类型比较失败均保留；后继使用实际GL与已有无损Codec，没有放宽生产检查。[实现与原始证据](../qa/lianhuanma_resume_20261026/README.md)。

此专项只验证现有内部活动期生命周期，其文档仍为classic context；不授予战役context终局事务、全章节通关、Steam SDK或公开续玩资格。另已编写14文件战役事务重基候选，保留七车v2、contract3、完整结算目标与现有Esc；候选未修改生产、未编译、未运行，下一步另冻结验证。黄泥冈原版键鼠验收按用户选择暂缓，四批完整计划仍保留。

## 2026-10-26 黄泥冈七车十一担：实现及自动回归

七位好汉各自取回原车、推空车装货、按2/2/2/2/1/1/1担运出冈；保留死亡接力、强夺和提前撤离，八人全活仍为可选目标。四语运输与选择按钮已接入；黄泥冈内部profile、单位图及单位组件升级v2，旧三担档拒绝且原文件保留，公开战役续玩入口仍关闭。另修正窄窗底栏姓名溢出和鼠标停在提示框上时Esc未能暂停的问题。

最终冻结`20261026_162550_230a5af6`导入、导出通过；实际包内普通计时酒计路线1206项、九阶段专项1768项通过，前后源码及包身份一致，13张路线图与24张四语多尺寸UI图分别目检。最终强夺路线为自然三人伤亡、两车接力，七车十一担交付后真实提前撤离；不沿用旧候选的四人伤亡/三车接力记录。上述由编辑器加载实际编译PCK验证，不等于原版EXE键鼠通关。

原版EXE已实际启动并正常退出，来源检查通过；用户按Esc停止界面自动操作，并选择暂不恢复、先继续代码和文档，完整实操验收保留待办。本批实现与自动证据共108文件已提交并推送既定stable分支，远端回读`f5325c25e4c8a5c6b412ab8712d60d944f0c72a5`一致；main仍为`1598c7c0`，未发布Steam。批次整体尚未验收完成。原始失败、当前证据和后续验收入口见[本批QA记录](../qa/huangnigang_production_20261020/README.md)；源码提交后的交接文档修订另行同步。

## 2026-10-20 GitHub仓库入口整理

首页改为游戏入口与当前版本表，新增CHANGELOG、协作说明、docs/QA导航和仓库约定；问题模板更新Build示例、运行来源及原著依据。回读main/stable同源、无开放PR/Issue，15个历史Release/38个标签建索引并保留，AndroidLatest与SteamWindows区分。当前协作者无管理员权限，About建议字段已列明但未应用。运行代码/生产资源和Steam不变，详见[整理收据](../qa/github_organization_20261020/README.md)。

## 2026-10-20 全部待提交文件补交

按用户明确要求，将原107个待提交文件全部入库：81份已有资源的导入配置、26份公孙胜/杨林候选工具和预览源码。14份Python AST、4份JSON、JS语法、44条原图SHA及HTML/fixture绑定检查通过；候选未运行、未采用，不更新Steam。新增候选README和[入库清单](../qa/pending_source_sync_20261020/README.md)，原文件字节保持。提交后以Git状态和远端回读确认不再遗留未跟踪文件。

## 2026-10-20 冗余整理

六份入口文档原共16,405行，已先完整ZIP归档、逐文件解压读回并核对SHA-256，再将当前入口与历史记录分开。首页、总览、计划、源码设置和目录索引只保留各自职责；原批次日志、原图、依据与QA没有永久删除。缓存清理仅限有相同SHA保留副本的旧私有导入缓存，实际数量、保护后验与磁盘变化以[本批收据](../qa/storage_cleanup_20261020/README.md)为准。

## 2026-10-20 GitHub首页与主线收尾

48042d84补齐旧stable合并历史，ffa625de补齐交接，391f2cc6纠正首页README与总览/计划。main和stable内容一致，工作区为main；107个未跟踪文件保持本地，未混入生产或文档提交。当前提交以Git历史与远端回读为准。

## 2026-10-20 Steam人物与场景更新发布

Windows default Build26048429 / Manifest697009053566575953；[四语公告](https://steamcommunity.com/games/5088120/announcements/detail/669505296465397048)已公开。生产来源0083b47a，原生219、包内1169、身份各10和EXE十一场景通过；服务器、全新下载、客户端文件与库内启动分别核实。首个失败批保留，QA断言修正未改变生产人物数据。[更新文档](STEAM_UPDATE_20261019.md)、[发布收据](../qa/steam_release_20261019/README.md)。完整续玩、全流程真人与长期性能仍未完成。

## 当前开发与历史

剩余范围和次序见[项目总览](PROJECT_STATUS.md)、[开发计划](DEVELOPMENT_PLAN.md)，人物与剧情先核对百二十回本。逐批人物/场景/工具文档仍保留，不把候选生成或技术检查当玩家功能完成。

[历史全文与恢复说明](../qa/storage_cleanup_20261020/README.md)。归档含本次整理前全部4,850行日志，可按Git快照或本地ZIP查询和恢复。以后仅在本文件新增实际完成的批次摘要，运行命令放源码设置，证据细节放对应QA。

## 2026-10-26 旧测试工程去重归档

54 个旧人物测试快照共 312,191 个非缓存文件完整归档，逐内容读回与实际整批恢复通过后移除展开副本；扣除归档约减少 81.06 GiB，另有少量审计开销。267,159 个保护文件前后SHA一致，进行中的黄泥冈修改保留。未运行玩法验收或发布，详见[清理与恢复](../qa/storage_cleanup_20261026/README.md)。

## 2026-10-26 第二轮重复文件清理

三个旧快照删除 20,189 个有当前文件和Git原字节双重保留的副本，约 6.69 GiB；845个独有文件保留。48,261文件SHA及其余目录元数据后验通过，原开发修改未混入。同步更正两份已由用户另行删除的归档状态，详见[本批记录](../qa/storage_cleanup_20261026_round2/README.md)。
