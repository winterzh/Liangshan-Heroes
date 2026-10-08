## 2026-10-08：白胜实际身体阻挡定位，R12组合南侧普通路线候选

旧V5实际批 `natural_terminal_1577d6e0` / session42979已终态失败并释放锁：import PID25388退出0/错误0；normal_fresh PID7880退出1/错误0，22检查唯一失败仍为原60秒自动卸酒。实际白胜位置911.29565,741.92834停滞，hp70/root0/stun0/manualfalse/auto/serial1均正常；next60Hz步map_open=true、body_open=false，两轴body也false。原军汉entity20位于891.7191,752，下一步与其距离20.9854，小于身体允许22。结合真实Unit._follow_path和static-only watchdog，此次停滞已定位到押队身体阻挡；不把诊断当终局、CFG或修复通过。五份原receipt/identity/log/report封存 `actual_failed_natural_terminal_v5/`，原失败档保留不复用，诊断来源及实际数值在 `BAI_BODY_STALL_DIAGNOSIS_V1.json`。

父关卡候选 `huangnigang_bai_arrival_candidate_v1/` 只将白胜自动初始命令改为普通队列经过南侧(40,30)/(23,30)，再到原WINE_UNLOAD。没有修改身体碰撞、坐标/生命/敌军/时钟，玩家接管、同演员、serial门禁及1.5秒正常idle卸酒保持。两次queued=true不会改变替代命令serial，内部执行队列也不增加serial。

新 `tools/run_campaign_natural_terminal_r12_bai_candidate.py` 明确绑定14份R12恢复源、该父关卡、原两份Core/Contract候选及110来源/81引用；runtime安装路径固定。原完整冷导入/identity、共享idle60、owned-process串行、正常无QA环境、实际自然终局/真CFG/gen3和三组重启/真实中断窗口全部保留。spec逻辑SHA `017d01e338cece864018c9e57e7002347089864393f9c3815e90f1a5e8c38b86`，独立准入见 `NATURAL_TERMINAL_INDEPENDENT_REVIEW_R12_BAI_V1.json`，仅natural_terminal_scoped。候选实际启动/结果以当轮独立收据为准，当前不宣称修复或完整恢复通过。

双角色ABCD/19故障/52负例/实际失败UI重试/Steam奖励一次性仍待最终执行器；大名府牢前推进也仍待定位。八章、九玩法/导出、性能内存、Android真机原目标保持。正式游戏源码未晋升；本轮只同步stable，不发布。

## 2026-10-08：真实启动屏障上下文及空屏障防线修正，R12静态候选

最终恢复的办理半程后继 `final_executor_candidate_v1_r2/` 保留原79项标签，新增正常startup门禁、真实Battle屏障归属与完整五参数v2生命周期检查。独立审查初步拒绝 FINAL-ADM-001：R9实际新游戏入口用缺省classic上下文创建保存屏障，原测试额外configure掩盖该问题。没有删除断言或恢复测试注入。

R10将Battle屏障创建/configure/add移到实际SteamRunPolicy.classify之后，显式传入本次实际上下文，prepared restore分支不变。独立复核确认上下文问题已解决，同时拒绝FINAL-ADM-002：失败启动可能没有屏障，而ContinueFlow保存入口直接调用空对象。R11在request_save_exit设置source前、confirm的_begin_save修改UI/连接信号前和_disconnect_capture读取屏障后检查实际有效性，返回既有RUN_BARRIER_UNAVAILABLE或安全结束disconnect。相对R9仅Battle/ContinueFlow变化，另12源字节不变。R11的第二层guard进入_fail后仍会空对象访问，因此独立拒绝；R12继续保护_fail、retry_release、has_capture_request与cancel-for-terminal路径，保留原错误及确认前pause意图，不伪装已解除持有。十四候选/80固定引用/13正式来源及新快照封存在 `SOURCE_AUDIT_V14.json`、`integrated_source_snapshot_v14/`；正式源码零修改。独立复核见 `INTEGRATION_SOURCE_REVIEW_V5_R12.json`，仅静态源/API范围，未授予任何native/full阶段。R10/R11及其拒绝收据原样保留。

旧完整续玩 `office_full_3eb4617b` / session27770已实际终态退出1，Lu A PID45692、131项检查唯一失败“prison approach clear natural deadline”。真实受验、内应、举火、开南门事件已发生，部队仍有存活，但失败报告不足以定位移动/攻击原因；43份原始记录85,208,161字节在 `qa/office_campaign_full_20261008/actual_failed_v12/`，原档不改不复用。普通终局V4_R2诊断 `natural_terminal_e75e0f96` / session9861也已终态失败、锁释放：normal_fresh PID42496、22checks唯一白胜60秒内自动卸酒失败；五份原记录在 `actual_failed_natural_terminal_v4_r2/`。从tick2697至5397白胜位置911.29565,741.92834完全不变，ST_MOVE/path仍指向752,784，静态segment畅通，hp70、无手动接管、serial1/auto保留。只能确认正常自动走路停滞，不能仅凭静态路线穿过押队站位认定动态身体阻挡。V5仅补充实际128范围敌对移动body半径/距离及下一60Hz步/轴步的map与can_unit_step结果，所有命令/60秒边界/断言不变；107来源封存spec及快照、独立静态scoped准入收据同目录，未转移R12全链资格。最终R12完整producer及双角色/19故障/52负例/真实CFG重启/错误UI/奖励一次性继续待实现和验收。八章、九玩法/导出、性能内存和Android真机仍在计划内。

本轮仅同步候选、独立审查和交接到既定stable；不晋升正式源码，不合并main或发布。

## 2026-10-08：普通终局V3实际白胜失败；V4_R2只读诊断准入

`natural_terminal_a30fe00d`已终态失败、锁释放，session2937退出1：导入26860退出0/零错误；normal_fresh13248退出1/引擎错误0，22项检查唯一失败为白胜在原60秒内自动卸酒。真实菜单、六项完整identity、普通时钟、押队到场与一次玩家刘唐应答均通过；没有进入自然终局或写CFG确认，白胜精确状态未采集，不能认定具体路径/控制原因。五份原收据/identity/日志/report在`actual_failed_natural_terminal_v3/`，原profile不改不复用。

V4_R2只添加每15秒白胜原对象的hp/位置/state/path/queue/serial/manual/unload/near/segment只读观测及失败详情，PackedVector2Array使用for遍历；原玩家命令、60秒/正常tick/墙钟上限、终局/CFG/gen3和所有重启/debugger断言不变。只读preflight成功，spec SHA`8fcdcc13c90610aeee88867683dd0c6360f9e6896bf18297f03997c31fbbf85f`；独立收据`NATURAL_TERMINAL_INDEPENDENT_REVIEW_V4_R2.json` SHA`86b438174e8ae5507a98688cd7512a44d245dee70f506684a286b36ff9b6687f`已回读，107固定来源一致，仅scoped静态准入、尚未native，失败资格不转移为绿色。

当前唯一新自有原生批是已准入v32旧完整续玩`office_full_3eb4617b`，session27770，单独全新profile；实际导入已退出0，前置JSON/store/半程ABC及双角色流程继续，不能按日志滚动认定whole通过。等它实际终态后才能串行执行V4_R2诊断。不缩短或改自然条件，不用玩家接管代替自动卸酒检查。

最终R9双角色/19故障/52负例/真实CFG重启/错误UI/奖励一次性仍未完成；八章、九玩法/导出、性能内存和Android真机目标继续。正式源码未晋升，Git只同步stable，不合并main或发布。

以下此前“V3运行中”等段落保留历史，以本段和实际终态为准。

## 2026-10-08：v32旧full静态准入与普通终局V3实际导入

v32独立V12收据`qa/office_campaign_route_20261008/OFFICE_FULL_INDEPENDENT_REVIEW_V12.json` SHA`032312d7f03b80760194a607923ddd3227379eb57dc28369b3b6a5343d0db5f0`已回读：原旧full范围静态准入，native_started=false；仅调整admission/扩军时序并补诊断，原Core/Contract候选与全部原矩阵不变。该批准不覆盖R9完整恢复consumer，旧V11实际失败不能升级，v32尚未启动。待普通终局批实际终态后再串行安排。

普通终局新批`natural_terminal_a30fe00d`导入PID26860已真实退出0、零引擎错误；session2937仍运行，后续normal fresh/restart与两个中断窗口待实际结果。无自然终局或重启通过可宣称。

## 2026-10-08：普通终局scoped V3独立准入，新档实际运行

V3独立审查收据`qa/campaign_progress_recovery_20261008/NATURAL_TERMINAL_INDEPENDENT_REVIEW_V3.json` SHA`392f11d5e8c317b2383aa0b3fd94bfb2729e364a9340995288d0927b42957160`已实际回读，spec3e3a3d…、producer不变、probe固定autoload后load、十四R9/80引用/两项CoreContract组合一致；仅natural_terminal_scoped准入。V2真实导入22748/启动43612的成功/编译失败和保留原档均纳入审查，不转移原生资格。

全新`natural_terminal_a30fe00d`已实际启动，观察session2937，原V2失败profile不复用；必须逐阶段实际终态检查，当前尚未完成三组。最终双角色/原19/52/SDK/故障UI仍未通过。正式游戏源码未改。

## 2026-10-08：普通终局V2实际解析失败保留，固定延后加载V3待复审

`natural_terminal_b58fec06`已实际终态失败、锁释放（session35059退出1）：import PID22748退出0、引擎错误0，前后完整源/冷导入派生元数据及postcold identity核验完成；normal_fresh PID43612退出1、一个Compile Error：SceneTree primary probe过早预载Intent→Profiles→Campaign，autoload名称SteamService尚未注册。未进入自然玩法、没有终局/CFG/重启结果。原receipt/postcold identity/两日志保留`actual_failed_natural_terminal_v2/`，原profile不改不复用。

修正仅在V3探针：Provider/Intent/Lifecycle为固定Script变量，实际autoload/菜单180帧后才加载固定路径，生命周期变量显式RefCounted；producer/R9十四源不改，V1/V2源与spec保持。V3只读preflight成功，spec SHA`3e3a3d94f22d4778e68187e35c48f9fe47a3d5596f4824eaa41d45356c209f2a`，冻结`natural_terminal_executor_v3/`。新独立复审待终态，尚未新native；V2旧独立准入不能覆盖改后probe或代替运行通过。

当前没有自有Godot运行。最终双角色/19/52及SDK完整目标继续；正式生产源码未改，旧V11完整失败和v32后继仍保留。此前“新批运行中”等是历史，以本段及实际收据为准。

## 2026-10-08：普通自然终局三组执行器独立准入并实际启动

scoped V2独立收据`qa/campaign_progress_recovery_20261008/NATURAL_TERMINAL_INDEPENDENT_REVIEW_V2.json` SHA`e52b0b657ede0bbc70f4bd2ada17fc8531e479f3e1fcb8fc95ceb5437ead25e4`已实际回读。11 helpers、14 R9、80依赖、选用的两项Core/Contract及冻结副本一致，三类V1阻断修复；仅`natural_terminal_scoped`准入，不授予双角色/19/52/SDK/错误UI或full资格。

实际新批`natural_terminal_b58fec06`已启动（session35059），仅在连续idle60后按单进程隔离执行。三组：normal fresh/restart；真实gen2源码点中断/restart；真实CFG后ACK前源码点中断/restart。必须实际PID/nonce/stack、完整冷导入identity、普通时钟/CFG/gen3/无重放与原链不变全部通过才计此范围；正在准备/运行，当前没有结果可升级。失败保留全批，不重开或复用档案。

最终完整恢复consumer仍未实现，详见`FINAL_EXECUTOR_ADAPTATION.md`；V11旧full实际失败已保留，v32另待独立静态准入。正式生产源码未改，平台未发布。

## 2026-10-08：V11完整续玩实际失败，新普通终局检查准备

完整批`office_full_e85e9994`已终态退出1、锁释放，不能继续视为运行。导入11016、JSON5456、OwnedSlot16496及半程ABC27944/45552/34464均终态0；档案保护38872/41692按预期拒绝。Lu-first A PID37260、119检查，在real admission complete natural deadline失败；军队19仍存活、营1500血、吴用186血、没有牢门/火号/营救事件。六原工人及付费第二house/workshop/2投石车/12步兵均已实际走过，入牢失败具体原因未观察到。42份原收据/日志/报告保留`qa/office_campaign_full_20261008/actual_failed_v11/`，原profile保持，未上传CFG/玩家档。

旧full无法直接安装R9后验收：原producer要求Core/Contract两项变化、QA=1、v1构造器及两代生命周期；新普通恢复要求R9六替换八新增、正常QA空、固定root、active1→pending2→applied3，并真实写CFG。ABC/组件/live继承base和consumer必须有更严格后继，保留原检查/矩阵，不豁免或转移历史green。详细约束见`qa/campaign_progress_recovery_20261008/FINAL_EXECUTOR_ADAPTATION.md`。

新增普通终局工具`tools/run_campaign_natural_terminal_recovery.py`与`campaign_natural_terminal_probe.gd`：实际菜单首关、原生时钟1、普通玩家酒计/挑担/撤离，自然END后真实CFG/gen3与新菜单不重放；两处真正Coordinator源码断点经实际PID/stack确认后只结束自有Popen，再新进程恢复。三组各fresh/restart、四用户目录隔离、来源/native/冷导入/完整identity/nonce/ERROR/foreign闸绑定。V1静态发现revision字符串和来源/进程闸缺口，原V1源/spec保留；V2修复并真实只读preflight成功，spec SHA`1390dfbcf3b29d05dd665086d9027fc647d2e839bbc9511d3ff478f06b840dd9`。仍待独立具体准入，尚未native；只承担首关自然终局与两个恢复窗口，不是最终双角色+19+52/故障UI/Steam完整consumer。

v32旧路线候选仅将同样的付费扩军移到真实admission/入内院后、火号前，新增实际spy hp/invis/位置/命令诊断；六工人、军队规模/成本、所有原检查/ABCD/52仍保持。bundle/seal_v12（SHA`5dda50a489695c34a9bfeeec4ef8ee6ce3678976ac6a0db4d7dcde962bcc9f55`）已封，独立审查待完成、未native、不保证解决入牢失败。

完整开发目标继续：最终组合双角色自然ABCD+负例；普通fresh/续玩与最终19故障/配置确认重启/真实错误重试/奖励一次性；八章动态、美术动画UI/多尺寸；九玩法与导出EXE；正常时钟性能/内存及Android真机/平板。正式游戏源码未改，只白名单同步stable、不合并main或发布。

以下“V11运行中”等较早段落为历史，以本段及原终态为准。

## 2026-10-08：R9独立静态源码准入完成

独立审查收据`qa/campaign_progress_recovery_20261008/INTEGRATION_SOURCE_REVIEW_V2.json` SHA`6c558b6e5279972819c0ea90789e1e183ee86f00f045d4fc28e52f0ae63f47ec`已实际回读：R9十四源、80固定引用、十三正式来源、十四快照完全一致，12个历史阻断逐项静态解决。`approved_static_sources_only=true`，但`approved_stages=[]`、`full_executor_not_ready=true`、`native_started=false`。后继恢复全链执行器尚未完成，未扩展成原生/终局/重启/UI/奖励资格。

完整旧续玩v31批`office_full_e85e9994`继续串行运行；本轮生产源码没有变更。下一步在该批实际终态后串行解析并验证R9接入，再完成与独立审查最终全链执行器，核验自然终局、真实CFG和第三代确认/重启/故障UI及奖励一次性。更早“待审”描述为历史记录，以本段与实际收据为准。

## 2026-10-08：当前恢复接入源R9，来源与规范化同时保留

R8独立复审发现合法旧云记录的缺省字段/旧best_total与Campaign规范化结果不同，会导致严格确认无法完成。R9先验证原来源并单独保留原payload，再按既有固定记录规则形成唯一写入目标；初次attach和普通apply均在实际共享写入前冻结规范目标，不放宽最终SHA/目标owner/配置语义的漂移拒绝。十四源、80固定引用、十三生产来源零差异封存在`qa/campaign_progress_recovery_20261008/SOURCE_AUDIT_V11.json`与`integrated_source_snapshot_v11/`；R8及以前不变。R9目前仅通过来源预检，独立审查待终态、尚未运行原生解析，不称完整恢复通过。

当前完整旧续玩批仍为`office_full_e85e9994`（session53649），串行等待各阶段自然闲置60秒，不并发新恢复原生批。后继恢复全链执行器尚待实现和独立审查；完整目标仍继续。

## 2026-10-08：R5解析终态与R8确认保护，完整V11运行中

R5真实解析批`integration_parse_fc392cb9`已终态成功：导入PID1712、正常菜单180帧PID6124均退出0、引擎错误0、锁释放。原收据和两个日志完整保留`qa/campaign_progress_recovery_20261008/actual_integration_parse_v4_r5/`；仅证明这份R5源能导入/启动菜单，不能证明终局恢复。

独立复审发现R5首次binding失败前没有完整提案冻结，R6修复后又发现首次写入可覆盖未知tmp及close重试缺少共享CFG重读。R6/R7原源保留；最新R8十四源、80引用及十三生产来源冻结在`SOURCE_AUDIT_V10.json`和`integrated_source_snapshot_v10/`。R8共同binding入口拒绝已有tmp文件/目录；进入close前冻结实际campaign/settings/language三个文件的稳定SHA和目标owner/进度/设置语义，首次及每次close重试都重新核对、漂移拒绝不重置基线；shared未确认期间设置请求保留，确认后重新调度。R8未原生解析、独立复审待结论；新恢复全链执行器尚未完成，原生产未安装。

旧完整续玩路线v31经独立V11静态准入（SHA`4a770182fb38ee0afe8765cbdd243f87d0d421cfabfc3e8eb46c79917fc4c070`），全新批`office_full_e85e9994`已串行启动，观察session53649。完整原validator、双角色ABCD与52负例保留；当前运行中，不能写成通过。东侧金矿只有一个、正常单工人机制可能让后来的工人转去其他矿，静态准入只保证初始命令目标，持续存活必须以实际检查为准。此V11批准不覆盖新恢复十四源。

后续依次完成：双角色完整自然续玩；最终恢复源normal fresh/续玩终局→第二代日志→实际CFG→第三代确认及跨进程重启、19故障、错误界面/安全重试/奖励只一次；八章动态、美术动画UI/多尺寸；最终九玩法与导出EXE；正常时钟性能/内存及Android真手机和平板。Git只同步已记录范围到stable，不合并main或发布Steam。

以下段落记录较早状态，最新范围以本段和实际终态为准。

## 2026-10-08：恢复接入十四源与实际启动证据，完整目标继续

恢复候选R2接入Campaign/Flow/Battle/Menu/Cloud并实现startup扫描、设置排他、终局消费和真实Steam token侧记录。实际官方4.6.3导入/正常菜单两PID退出0、错误0；新的实际启动与普通设置探针16检查全过，根startup确认/Gate开启、真实ConfigFile写盘/读回/同内容SHA均观察到。这只是空档案与正常prefs范围，未安装生产。[真实证据](../qa/campaign_progress_recovery_20261008/README.md)。

用户批准新源独立审查，R2因8个P1拒绝；14源/77引用/13正式来源回读无差异。R3/R4修复中间版保留，最新R5封存14源/80引用，解决身份重试/设置唤醒、Cloud原/目标owner和初始身份冻结/可见原对象重试、镜像下层门禁、自有preproposal及空目录释放状态、startup持有CFG/原提案、零代/恢复锁门禁。R5隔离解析批`integration_parse_fc392cb9`已启动，独立复审与真实结果待完成；全链执行器尚未完整，未宣称终局/重启/UI/Steam通过。

完整V9真实rally通过但原攻城军在牢区全灭（营1500血）；付费扩军v30经独立V10静态通过后实际V10在作坊完成后的工人存活采集处失败（59检查，未到投石车训练）。两原失败profiles和各26份收据/日志/报告完整保留。东营实际采集/普通选址v31后继已准备，仍保留六工人检查、原双角色ABCD/52负例，待独立准入。[完整QA](../qa/office_campaign_full_20261008/README.md)。

后续仍是完整双角色自然续玩、normal fresh/续玩gen2→CFG→gen3及重启、原19故障在最终源/玩家错误界面/安全重试/奖励一次性；八章动态与付费生产/船运自然胜败、美术动画UI/多尺寸、最终九玩法导出EXE、正常时钟约10分钟性能与切换内存、Android真手机/平板全部继续。正式游戏源码没有晋升；每轮只白名单同步stable，不合并main或发布平台。

以下旧进展为历史，当前以本段与各实际终态/独立收据为准。

## 2026-10-08 15:25：完整续玩V9启动，当前待验收范围

完整V8-R3已实际失败退出：JSON533/OwnedSlot76/半程独立ABC39/351/342通过，Lu-first A PID30668的24检查仅兵营集结点检查失败，原profile及27份原收据/日志/报告保留。v29对齐普通玩家命令的地形反算目标、仍核验原目的格，增加真实诊断；不修改生产源码、旧消费者、双角色ABCD或52负例门禁。独立V9完整源码/来源审查通过，实际只读预检通过，全新完整批`office_full_b0f1d997`已启动；必须以这批真实终态判定，不能继承前序成功补齐完整资格。[完整QA](../qa/office_campaign_full_20261008/README.md)；[V9来源和新argv](../qa/office_campaign_route_20261008/README.md)。

进度恢复新增V3八源候选：真实Battle属性访问前守卫，纯投影拒绝时释放未暂存的自有CFG锁，失败仍保留。9生产来源零差异，23固定引用/本地方法名称源码闭合；未解析/独立审查/native/集成，旧V2四案八PID36检查通过与v27b19案194检查通过不扩展到新源。[恢复候选](../qa/campaign_progress_recovery_20261008/README.md)。

后续顺序：完成双角色自然ABCD及全部负例；集成普通fresh/续玩terminal→实际cfg→ack、startup恢复与玩家pending/重试UI、prefs/cloud写入排他及奖励一次性；再核验八关动态/付费生产/舟船运输/自然胜败、美术动画UI和多尺寸全流程、最终源码九玩法及导出EXE、正常时钟约10分钟60FPS(P95≤16.7/P99≤33.3)与切换内存、Android真实手机和平板。完整原计划不缩小。源码同步仅stable，不合并main或发布Steam。

以下旧日期进展属于历史记录，当前以本段及对应实际终态为准。

## 最新：CFG受控替换组件36检查通过，完整V8-R3继续

CFG组件四案例/八个不同实际PID/36检查完整通过，包含backup/install两处真实进程中断后恢复与外部CFG改动后的拒绝覆盖。原失败保留，正式生产源码未改；结果不延伸为玩家UI、自然战役、完整gen2→cfg→ack或奖励通过。[真实组件证据](../qa/campaign_progress_recovery_20261008/README.md)。

恢复候选增至八GD，新进度gate和保留式协调器只完成源码闭合，尚未安装/解析/独立审查或集成Campaign/ContinueFlow/Battle/startup/prefs/cloud。源快照与实际原失败均完整。

同一V8批准的完整续玩源启动新全批 `office_full_f2d8d7cc`，观察session36886，当前等自然引擎空闲；V8-R2原失败未复用，新结果须等本批实际终态。[完整QA](../qa/office_campaign_full_20261008/README.md)。原19案/194检查v27b组件资格保留，其余完整计划继续。

## 最新观察：完整V8-R2失败保留，CFG组件等待

V8-R2的办理半程ABC39/351/342及前序真实通过；Lu-first A开始后外部Godot进入，整批终止退出1、锁释放，原档案保留，不补齐成完整双方资格。当前唯一新批为CFG组件cfg_component_c5212404/session41902，正在等待自然空闲，尚无Godot结果。[完整记录](../qa/office_campaign_full_20261008/README.md)。

当前恢复候选扩为六GD：v2日志/冻结意图/CFG语义/受控替换、WorldSession双层实际scope派发，以及保留无关/未知数据的纯同局投影。源码闭合/9生产SHA不变，未解析/未native/未晋升；完整协调器、startup扫描/玩家失败UI/pending/prefs/cloud和普通fresh路径尚未实现。[候选证据](../qa/campaign_progress_recovery_20261008/README.md)。原完整计划保持。

## 当前：V8-R2与CFG受控替换源码候选

完整V8已因B期间外部Godot进入终止，原失败保存；同一批准来源用新UUID/profile开启V8-R2 `office_full_e8f3fca4`，当前实际导入/守卫/JSON533通过，其余门禁待本批终态。未测试到新守营策略，未沿用旧成功补齐全链。[当前完整QA](../qa/office_campaign_full_20261008/README.md)。

新增v2日志后继、CFG数据语义helper和受控替换候选、四案例八进程的真实CFG/中断/CAS组件工具。源码检查发现并修正父层两代保留、外部writer尝试不能授予结算能力、Windows覆盖rename、whole-file encode转义和备份前再次SHA检查。当前8源封存V5/9生产来源回读不变，只有Python/方法/来源检查，尚未Godot解析/执行/独立审查，不安装生产。详情见[组件矩阵](../qa/campaign_progress_recovery_20261008/CFG_COMPONENT_PLAN.md)。

已通过的旧v27b19案/194检查组件资格保持；不能延伸为新CFG候选、gen2→cfg→ack、玩家UI/安全重试或自然战役/奖励通过。原完整开发/发行/性能/真机计划继续。

## 2026-10-08 11:49：19案组件通过与完整续玩新批

真实19案V4 `campaign_19_7aac9db9`完成194检查、零失败，runtime PID43016终态退出0、锁释放。Godot调试断点和Windows原生oplock已分别实测，矩阵内真实ConfigFile.load期间文件变化也命中；原V2/V3失败保持。该资格仅属于QA v27b持久化组件，正式Campaign/Battle未修改。[实际组件证据](../qa/campaign_persistence_faults_20261008/README.md)。

原完整V5真实JSON533/OwnedSlot76/办理半程ABC39/351/342通过，Lu-first A在营救前END失败，整批退出1；完整双方续玩仍未资格。新普通守营路线v28经用户授权的同一独立审查通过V8，producer/seal_v8/bundle三源精确绑定。全新完整批 `office_full_933181f4`11:49已启动，等待共享引擎自然空闲；全部原门禁保留，结果须等实际终态。[完整批](../qa/office_campaign_full_20261008/README.md)与[新路线](../qa/office_campaign_route_20261008/README.md)。

新增 `qa/campaign_progress_recovery_20261008/` 两份v2终局进度日志/意图基础候选，只做源码核对，不安装生产、不声称解析/原生通过。下一步是普通fresh/续玩终局→gen2→真实cfg→gen3 ack、受控临时文件/CAS、prefs/cloud pending锁、玩家失败UI/安全重试与重启恢复；奖励一次性、八关动态/生产运输、美术UI、九玩法发行程序、正常时钟约10分钟性能及Android真机均继续开放。源码同步stable不等于发布。

以下旧日期状态为当时记录，当前以本段及对应实际原生终态为准。

<!-- night-wrap-completed-metadata -->
## 2026-10-08 06:06：收尾同步与心跳暂停已回读

本夜交接提交d609b38e已推送stable并独立ls-remote回读一致，工作区在交接提交后干净。两未资格生产候选已精确回原，候选/备份/原失败仍完整，四资格SHA不变。一次性心跳6已由automation工具暂停，实际文件回读PAUSED、原prompt/周期/目标线程保留。对应最终收据见qa/zhu_wounded_20261005/night_wrap_completion_metadata_20261008.json；本元数据提交仍会单独推送并回读最终SHA，之后关闭本夜有界任务。全开发计划仍开放，不宣称单人撤离/持久恢复/19故障/整项目完成。

<!-- night-final-20261008 -->
## 2026-10-08 06:02：本夜开发截止收尾

已到香港06:00，停止启动新开发批。所有本线程原生后台均真实终态；新六文件单人撤离候选未完成C/双方A/完整负例及BCD，整体资格仍false。最后71d4275a原生导入因共享Godot恢复占用退出1，锁已释放；原failures/profile/五个前序文件全部保留。原四文件JSON修复及限定办理半程ABC资格保留。

06:02实际执行精确最新终态绑定的r4工具，逐文件复原本线程Core/UnitContract两份未资格生产候选；当前before逐字节等于备份/QAoriginal/HEAD，QA proposed与备份完整，JSON四文件SHA不变。没有reset/stash、没有控制其它任务或删除失败数据。原r3编码与自匹配阻断、两次只读审计采集失败均保存为独立记录，r4只排除本工具exact自身PID。

Campaign真实保存回读v27b两文件提案与独立源码/API审查已存QA，current=proposed_b；未应用生产、未native解析、19条故障未执行。玩家失败UI、pending锁/安全重试、章节日志/终局gen2→cfg→ack与跨进程故障恢复仍未完成。完整动态/付费生产/船体运输、自然胜败奖励、九玩法发行程序、美术UI多尺寸、正常时钟长跑性能及Android真机计划全部保留。

公司从 [OFFICE_START_20261008.md](OFFICE_START_20261008.md) 继续；最终实际结果见 [NIGHT_PROGRESS_20261008.md](NIGHT_PROGRESS_20261008.md) 及qa/zhu_wounded_20261005/night_final_wrap_delivery_20261008.json。本收尾只源码/QA/文档同步stable，不发布新Steam/Android、不合并main。最终推送独立回读后暂停一次性心跳6，再关闭本夜有界任务；这些调度操作另以实际收据为准。

<!-- campaign-proposal-v27x1 -->
## 2026-10-08 05:12：战役真实保存回读收据提案完成源码审查

新的v27b外部候选已完成Campaign/Battle两文件实现与独立源码/API审查，原best单局/no union、旧QA内存语义和Steam当局结算保持。候选将逻辑accepted、memory_applied、真实save+全新ConfigFile完整语义回读的persisted、QA suppressed分开；坏既有cfg/不支持数据写前拒绝，写后读回失败明确disk_state_unconfirmed而不声称回滚。Cloud callback在candidate内存安装后请求，不等于上传确认。

当前仅源码提案，未应用Root、未运行Godot解析/真实磁盘/19条故障矩阵。玩家失败提示、pending锁/安全重试、终局gen2→cfg→ack与跨进程故障恢复仍未实现，不可当作战役持久恢复验收完成。当前提案目录为qa/zhu_wounded_20261005/proposals/campaign_persistence_observability_v27，使用proposed_b及V27B文档，oldff与原版证据保留。

当前没有本线程原生后台；单人撤离两生产候选仍未资格。收尾精确双文件复原工具r2已独立静态审查，只可在22UTC后重新核最新71d终态、无own进程与全部字节条件后执行；目前未复原。完整剩余计划与06:00最终同步不变，公司续做先看[OFFICE_START_20261008.md](OFFICE_START_20261008.md)。

<!-- offline-terminal-v25x16 -->
## 2026-10-08 04:36：离线准备通过，原生导入仍中断

新F/run71d4275a在实际导入64.42秒后因共享Godot恢复占用终止exit1，锁已释放。原独立复制与完整endpoint审计通过，不能替代未完成的import；profileguard/C/双方单人撤离A均未执行，E1闭合proof不存在、full未启动。完整失败证据见qa/zhu_wounded_20261005/offline_import_interruption_delivery_v25x15.json，原prefix五文件及失败profile保留，editor cache未上传。两生产候选仍未资格，当前没有活跃本线程原生后台。后续独立计划项可继续准备，但06:00按实际结果收尾，完整原计划与公司新基线要求不变。

<!-- night-progress-v25x14 -->
当前阶段快照与完整续做顺序见 [NIGHT_PROGRESS_20261008.md](NIGHT_PROGRESS_20261008.md)；普通源码启动与原生QA依赖已分开说明。原生结果及06:00终态以最终收据为准。

<!-- offline-prepare-v25x10 -->
## 2026-10-08 04:19：新离线准备入口已启动，待原生结果

此前5284b47e也在import被共享引擎恢复占用中止，actual exit1、锁已释放，没有新C或双方撤离A；完整原失败证据见second_prefix_interrupted_delivery_v25x9.json。新的r2f/run71d4275a已唯一启动，Python206868；只把纯文件准备提前、合并相邻无写入的重复全树走读。原base约2.145GB独立复制、一次末尾完整Root/private5102/native9/QA9核验及所有native前后/空闲/lease/foreign守卫保留，真实import/guard/C342/bothA仍必须完成，目前没有新原生资格。

原“每native约120秒全是空闲”措辞另存更正：连续空闲窗是60秒，其余主要为完整SHA守卫；准备优化收益尚未实测，不能称性能提升。新的r2e1仅准备接受r2f真实闭合来源，原942不改；当前缺实际C/bothA证明，full仍阻断。20:17只读CIM确证当次foreign是manghe工作树，不据此推断历史已退出PID身份，也未控制或消息其他任务。

公司入口仍为 [OFFICE_START_20261008.md](OFFICE_START_20261008.md)。两生产候选仍未资格，不纳入生产提交；复原范围已独立预审但尚未执行，必须所有本线程后台真实终态且full仍false后才能逐文件回原。06:00按实际证据收尾，原开发计划完整保留。

<!-- prefix-interruption-v25x7 -->
## 2026-10-08 03:46：恢复批导入被共享引擎占用中断

run8f3d393d 实际 exit1、锁已释放；尚未执行C或双方单人撤离A，整体资格仍false。原始收据和完整日志已保留于QA，详见 [当前公司交接](OFFICE_START_20261008.md)。后续仅在更长自然空闲后建全新批，原失败profile不重用；完整计划继续保留。

<!-- office-prefix-v25x6 -->
## 2026-10-08 03:35：恢复入口启动与公司续做准备

新 r2d/run8f3d393d 已由本线程唯一观察者启动，Python220144，私有冻结阶段完成。严格回读原失败批 source6、私有5102、28证据和五个完整前序文件后，只复制到新profile；仍须实际 C342 与双方真实单人撤离 A，未宣称新的原生通过或 v25 整体资格。原run07ad37bf/producer/失败profile不改。准备与启动证据见 `qa/zhu_wounded_20261005/safe_retreat_prefix_preparation_delivery_v25x5.json` 及 proposals/daming_safe_retreat_v25 的 PREFIX_C_STARTED_8F3D393D_FX.json。

r2e 完整复用入口已独立静态闭合，继承 r2b2/e61 修正后的三消费者；缺真实双方A闭合证明时前置阻断、不创建原生批。全部52负例和双方BCD保留，不能用A探索代替自然终止、完整负例或Campaign真实写盘。两份生产候选仍仅本地未验证，不纳入生产提交。首次启动器日期转换被前置拒绝，原输出另存，随后保留原ISO字符串启动；原producer/审查未修改。

公司最新简明入口为 [OFFICE_START_20261008.md](OFFICE_START_20261008.md)：正常Godot/原生依赖启动可用；旧QA物理缓存、固定今晚截止和同机时钟不能迁移，公司新批需建立本机基线与新后继。原稿两处路径控制字符已另存更正记录并修成原样命令，未执行文档里的公司命令。仍于香港06:00按实际结果收尾、逐文件同步，所有后续计划保留。

## 2026-10-08 03点后：第三进程被共享引擎恢复占用中断

原run07ad37bf已终止exit1并释放锁。新6路径候选的JSON533、OwnedSlot76、实际办理保存A39/B继续重存351已通过，第三进程C在运行中因foreign_engine_resumed中止；完整ABC仍未资格，Lu/Shi单人撤离尚未执行。原完整profile、producer、收据及日志全部保留，不覆盖或重用失败profile。主证据retreat_explorer_shared_interruption_review_v25x4.json。

后继必须新UUID/新profile并保留所有原源码/原生/packet/时钟/nonce/PID及缺失C实际验证门禁。若复用已完成B前序证据，必须先严格验证并复制原完整slot/journal/handoff到新profile，原失败profile只读保留；不得略过C或假称原批完成。未具备该门禁则全新批完整重跑。仍按用户要求等待共享Godot自然空闲，不控制其他任务。

两个生产候选仍仅本地未资格，Git生产源码继续为已验证版本；候选/工具/失败证据与真实持久进度设计均存QA供公司继续。完整consumer nullable和模块HEX64问题已由新不可变r2b2修复并独立静态闭合，尚未原生/full启动。公开战役继续、自然结局/奖励、真实Campaign写盘、全部后续计划均未由这些前序检查证明；6点按实际状态收尾同步。

## 2026-10-08 03点前：原回归继续，完整接入修复与持久进度设计

当前A探索保留原JSON533、OwnedSlot76和实际办理半程三进程，再分别取得Lu/Shi单人撤离存档。最新已实读JSON533/OwnedSlot76/首次办理保存A39通过，B/C及真实撤离A尚待结果；运行仍限定隔离冻结候选，两份本地生产候选未资格、不纳入生产提交。

完整测试consumer审查发现必需nullable字段缺失被当null接受，已保留旧源和更正收据，新后继加入字段存在与精确type/value门禁。随后复制回调的HEX64模块global遗漏也保留原失败设计，新后继补明确namespace闭合。这些是未执行测试接入的缺口，不是当前A原生失败；完整接入须新独立审查，不沿用旧通过文字。

下一计划项外部设计已存qa/zhu_wounded_20261005/proposals/campaign_local_context_progress_20261008：当前token/rawSHA/active-terminal绑定有效，缺章节context语义；Campaign.record_level_result忽略_save失败，而terminal先于cfg写盘形成恢复窗口。设计保留classic v1字节兼容，未来新campaign日志需要冻结结果与持久进度确认；CAMPAIGN_QA=0正常私有profile真实写盘/新进程回读及失败恢复另测。设计尚未实现/原生，不修改当前冻结批，不宣称Steam奖励或公开续玩入口已合格。

所有后续动态、付费生产/船体运输、自然结局奖励、九玩法发行EXE、美术UI、多尺寸、正常时钟长跑性能及Android真机继续保留。当前run/profiles不得在办公室并行复用；最终6点按实际证据收尾同步。

## 2026-10-08 02:20：真实单人撤离新批次已启动，待原生结果

Git稳定源码最新已回读845c59ca；随后只在本地受控应用v25的Core/UnitContract两文件候选，原字节备份完整、六路径SHA桥固定。它尚未原生资格、未提交为生产；已同步的JSON四文件保持不变。候选声明见safe_retreat_candidate_v25x1.json及safe_retreat_preparation_delivery_v25x1.json。

新r2a实际后台PID217168、run daming_safe_retreat_v25s_r2a_07ad37bf，明确选择Lu先撤离、Shi先撤离两独立profile。当前原生前置自然空闲/私有冻结阶段已完成，import阶段仍按共享Godot自然空闲规则等待/执行；未取得任何新通过结果。该探索保留完整JSON533/OwnedSlot76/办理半程ABC原回归后，才能用普通移动/战斗取得真实单人安全A存档。overall_v25_qualified始终false，不能将拿到A夹具当整个四进程/负例已验收。

独立复核发现旧执行器失败时丢已拥有场景与pending Session引用；新s1显式只记真实launch/commit场景、只释放自身场景，失败待写事务强持到进程退出，不重试/替换或判成功，原文件与原断言保留。新runner/producer独立闭合收据与可执行参数已存QA；48个实际对象负例、264世界DTO路线及362组件路线是准备数量，未运行即不计通过。

本机运行只由本线程观察，办公室不能重复同一run/profile。六点收尾时将把实际完整/失败/中断状态写回；若两文件仍未资格，保留完整候选与证据供公司续做，生产分支继续使用已验证代码。所有原计划、真实战役写盘、自然结局/奖励、九玩法发行EXE、美术/UI、长跑性能及Android真机仍保留；不发布新Steam版本。

## 2026-10-08 同步范围补充：冻结工程与本地完整目录分别记录

三进程通过范围为原冻结输入raw5041/distinct5037及明确补齐依赖、元数据后的隔离runtime5102。四个公开修复文件与该批精确同SHA；不能将这份资格解释为当前本地完整目录的运行资格。独立只读清单发现本地整树5042文件与隔离工程有24个额外草稿素材、84个依赖/元数据缺项及4个UID差异；草稿未混入本轮提交。公司使用既有bootstrap/重新导入后重新建立完整身份与私有profile，不能沿用家里content_version。完整差异见qa/zhu_wounded_20261005/independent_readonly_public_identity_v24s1.json。

额外核对实际active local journal头、原文件SHA、token、世代1/2 binding及存档副本相等，没有writing锁。原LocalLifecycle固定context为defense/空章/30，与本次Slot的campaign/level8/0不同；这是当前API的实际行为，只证明原声明的本地生命周期与binding，不证明逐战役context或奖励语义。原数据保留，未修改ledger。原生profile目录保留作为证据；释放的是进程及写锁。

独立Unit/Contract/Pair组件负例已准备181用例×2路线，尚未解析/运行；不把362计划行计为通过。单人撤离producer、五组实际live cast负例、自然结局/持久战役进度等仍待完成。完整计划继续按办公室交接推进。

## 2026-10-08 凌晨：大名府办理半程三进程磁盘续玩通过

当前 v24s 重新完整执行：固定 JSON 边界 11 案 533 项、原 OwnedSlot 故障事务 76 项通过；实际正常移动办理半程 A 保存退出 39 项、新进程 B 完整 Session 安装/正常办理完成/再保存 351 项、第三进程 C 世代 2 安装和 120 原生物理步无重复效果 342 项全部通过。三个实际 PID/nonce 不同且不重叠，世代 1→2 SHA 链及最终完整 5102 文件源码/原生依赖零漂移核对通过；生产四文件据此纳入 stable 同步。公开战役继续入口仍关闭。

主收据：`qa/zhu_wounded_20261005/daming_admission_continuation_qualified_v24s.json`，含原整批收据、完整 packet/world、原日志和隔离 QA 存档证据。历史 NONCANONICAL_RECORD、wrong-kind 夹具错误、r2 重复 QA 监听错误和共享引擎中断均保留；新 s 只修 QA 自己的监听生命周期，固定 JSON 读取转换仍限 Gao/Daming Map 所有权整数。原 canonical 字节/SHA/修订链保留。证据收集首版将 user:// 当文件系统路径失败，另存失败记录并用新 sibling 正确解析；原生通过结果不受影响。

单个获救者安全撤离提案仍未应用/未原生验收。已准备 world DTO 的 264 路径（246 Core、18 Slot canonical 拒绝）及 19 实际对象 capture 用例；数量是计划，不能称运行通过。组件负例及 producer 接入继续审核；缺真实 A 夹具或未实现门禁仍前置阻断。`CAMPAIGN_QA=1` 不写 campaign.cfg，本批不证明战役进度持久、自然通关或 Steam 奖励。

后续付费生产、船体/运输、其他动态、自然胜败奖励、同版九玩法 EXE、完整美术/UI、多尺寸、正常时钟长跑性能与 Android 真机全部保留。此前 Core 207、Presentation 348、FX 681 是独立组件资格。办公室入口为 [HANDOFF_20261007_OFFICE.md](HANDOFF_20261007_OFFICE.md)。本轮只同步源码、QA 和文档；既有 Steam Build 25768878/四语公告不变。用户要求香港时间 2026-10-08 06:00 最终收尾；下方条目保留历史。

## 2026-10-08 零点后：真实保存通过，独立继续测试修复中

固定JSON边界原生11案533项、原OwnedSlot故障事务76项通过；原失败pending payload逐UTF-8字节还原，错误数据仍受控拒绝。大名府正常移动进入办理半程后，真实Session保存世代1并正常退出，A32项通过。B完成独立安装的完整world/packet/时钟比较，但第二次HELD时QA重复连接capture_rejected导致ERROR，整批失败，B未写报告、C未启动；不能称完整磁盘续玩已验收。修复仅针对QA自己的一次性监听生命周期，生产候选四文件仍未提交为合格版本。原失败producer/profile/日志保留，新sibling另行验收。

主证据：qa/zhu_wounded_20261005/native_ownership_json_component_pass_v24r2.json、daming_admit_signal_failure_review_v24r2.json及各原始报告/完整数据。新helper与UID补明确Git字节属性，避免Windows换行转换破坏冻结SHA；QA目录本来已受-text保护、被Godot忽略。

单人安全撤离的两文件提案、普通指令路线/四进程runner及静态审查已保存于qa/zhu_wounded_20261005/proposals/daming_safe_retreat_v25；详见DAMING_SAFE_RETREAT_DESIGN_20261008.md。它尚未apply/native，旧runner也须采纳上述_hold后继修复。CAMPAIGN_QA=1跳过Campaign写盘，本批不可声称战役进度持久或Steam奖励；未来正常私有profile另测。负例工具和producer实现继续准备，缺门禁前置阻断，不跳过判绿。

此前Core9案207、Presentation348、FX681仍是各自原资格，不替代完整动态/自然结局。后续付费生产、船体运输、旧关动态、自然胜败奖励、同版九玩法EXE、完整美术/UI、正常时钟10分钟性能及Android真机全部保留。用户要求香港时间2026-10-08 06:00最终收尾同步；当前办公室入口为HANDOFF_20261007_OFFICE.md。以下阶段条目是历史。

## 2026-10-07 旧六章整局初态与 FX 组合回归已通过

旧六章完成真实HELD捕获、完整准备、暂停原生挂载、最终激活及再捕获，6案132项零失败；与双关初态/高俅按钮组件合计9案207项。完整非时钟字段精确一致，Mission墙钟年龄及Root逻辑tick/cache/输入重定位有独立边界校验。旧关动态与完整战斗跨进程尚未由这些初态测试证明。

FX组合回归同进程650项、独立重启31项，共681项零失败。原17类负例保留，精确实际ready连接错误flags拒绝、新世界Unit引用/Marker归属及原生布局后的实际新增本地化绑定清理通过；已将公共FX QA调用迁移为该原生已测试源码。5039冻结输入均不变，两个独立Presentation/FX QA调用工具均不在这份5039清单；原错误描述/辅助脚本失败保留并另记纠正。未修改运行时生产逻辑。

主收据：`original_world_qualified_v24l.json`、`original_world_complete_review_v24l.json`、`fx_partition_qualified_v24n1.json`、`fx_partition_caller_migration_v24n1.json`（均位于qa/zhu_wounded_20261005）。下一步准备大名府真实任务办理半程→实际保存退出→独立Session安装/自然tick完成办理→再保存/第三进程回读，尚无通过声明；单个获救者撤离中途保存的校验缺口也待原生复现。公开战役续玩入口保持关闭。

用户要求继续推进到香港时间2026-10-08早上06:00收尾同步GitHub；定时收尾心跳已建立。届时记录实际完成/未完成和办公室续做入口，不把未完成项目称为全项目完成。以下此前阶段保留为历史，以本段及原收据为准。

## 2026-10-07 办公室交接：当前状态

最新续做入口为 [HANDOFF_20261007_OFFICE.md](HANDOFF_20261007_OFFICE.md)。本轮完整世界初态与高俅收兵组件共75项、任务界面218+130项通过；旧关整局初态 case0 另22项通过，其他五关仍待完成。五份生产修复和已测试的独立界面QA调用迁移纳入本轮stable同步，公开战役续玩入口保持关闭。

源码审核发现FX partition独立QA仍需迁移原生入树调用顺序并重新回归，不能沿用它的历史通过结果。5039冻结输入零漂移；较早QA文字误称独立Presentation工具属于这5039输入，现已按清单纠正，原收据不覆盖。具体已完成/未完成边界及办公室启动步骤见交接，证据见 `qa/zhu_wounded_20261005/office_source_review_v24m.json`。

以下保留此前阶段的历史记录，旧后台编号、待验收状态与候选同步描述不代表当前状态。

## 2026-10-07 整局恢复当前复验状态

两关已实际完成完整世界捕获、准备、暂停挂载、最终激活与新世界捕获。v24e原生43项中2项失败，均为隐藏任务面板尺寸；Root全部非时钟数据精确相同，逻辑tick/cache与Mission墙钟边界通过。该批整体仍判失败，不能称整局已验收。

高俅两个静态码头节点入树后处理位重新开启已按原生差异修复，仅允许原工厂登记的永久静态节点；颜色变异/有限生命周期负例证明失败前不改处理位。隐藏Label文字提前写入导致新工厂尺寸与原世界不同；按原构造器“空Label先入树、再填文字”顺序及可见容器布局修正，完整UI字段比较保持。生产Root/Visual/Core/Scenery/Presentation五文件仅本地待验收，没有推送未合格生产候选。

v24f成功导入后因其他任务恢复Godot占用，仅停止自己的引擎子进程，未取得测试结果；原输入/日志/收据保留。当前后台81876复用该已导入冻结工程执行完全相同两案，另建profile/证据，原生结果尚待。高俅实际收兵按钮与损坏描述负例v24g已准备但未启动。全开发目标和所有剩余门槛继续保留，本轮不发布平台。

以下较早阶段条目保留为历史记录，以本段及最新原生收据为准。

# 当前开发范围与完成证据审计

2026-10-07。逐项回读现有原生收据、实际Git状态和来源SHA；本次审计没有启动引擎。生产源码中的Root/Visual/Core三文件候选尚未验收，不能把此前组件通过称为当前整局通过。历史明细继续保留在 DEVELOPMENT_AUDIT_20261006.md。

| 要求 | 已有直接证据 | 仍须完成 |
| --- | --- | --- |
| 原著人物特性、成人比例与动作 | 前批人物/待机/步态/受击/倒地/技能专项证据保留，林冲外围枪架修正已发布 | 拥挤人物与血条、无间断完整演出、全库/剧情终态、多尺寸完整流程；相位截图不替代全流程 |
| 当前八关动态阶段及真实演员/UI | 八关开场与真实取图、祝家庄七人撤回等专项证据保留 | 全部分支、自然训练、队列完成、船体与运输动态，不把开场当通关 |
| 高俅/大名府地图与场景 | fcdc10ce：两关及经典8案221项，其他六章初态6案60项；14案281项精确地图/场景复捕获，正常时钟1.0，5039输入零漂移 | 禁用/脱离世界组件资格，不是整局；当前新增三文件候选需完整世界验收 |
| 战役整局与跨进程续玩 | 既有章/获救七人跨进程和两关Unit/Level专项证据保留。实际Root/Visual/Core接入仅本地候选，原生后台78966等待引擎自然空闲 | 完整Mission/UI回调、FX、导航、时钟/最终激活；实际保存退出、独立进程继续/再保存，付费生产/船体/运输、自然胜败与奖励一次；公开战役入口尚未开放 |
| 九玩法同版及发行程序 | 历史发布/专项证据保留 | 同一最终源码素材的九玩法/保存作用域拒绝与真实发行EXE验收 |
| 性能、切换及清理 | 历史中位FPS139–190；严格尾帧/最终清理仍未通过 | 正常时钟同负载约10分钟、60FPS及P95≤16.7ms/P99≤33.3ms目标、节点/内存回收；不改成30分钟门槛 |
| Android及真人体验 | 历史2.0安装联网触控有用户确认 | 2.0.1实际手机/平板持续性能、DPI、安全区、触控；无攻略真人试玩需直接证据 |
| 审核、修错及受控冗余清理 | 本轮场景身份/原视觉船只/入口高度/灯光与新引用/只读准备捕获修正通过。仅删两闲置失败工程7476同路径同大小同SHA imported，1803637428字节；10303保护文件与keeper不变 | 新整局候选审核继续；不删源、原失败日志、存档、平台包或其他任务文件 |
| GitHub与平台边界 | stable源码fcdc10ce及元数据f0171d36独立回读一致。10-07历史Steam收据为Build25768878/default、Manifest7052320823704356026、既有四语公告703281660030877705 | 三文件整局候选尚未提交推送。此审计不进行新发布、不称Steam客户端更新通过；后续每轮验证后白名单同步 |

当前实现优先顺序：完成高俅/大名府整局及具名按钮绑定→动态分支/付费生产和运输→独立进程保存退出继续再保存与自然结局→既有关卡/九玩法同版EXE→拥挤与完整演出、多尺寸流程、约10分钟性能/切换清理→Android真实设备后验。原计划的平台功能方向保留，现有开发目标没有缩减。

任务stage_age_ms使用墙钟，Root输入时间戳也会重定位；不同捕获毫秒不得以字面相等冒充正确计时。必须保留完整原生记录，核对加载前后逻辑时钟及被允许重定位字段的实际范围。当前测试仍仅待执行，所有未完成项保持开放。

机器可复核证据：qa/zhu_wounded_20261005/development_evidence_audit_v24a.json；场景主收据full_scenery_qualified_v23f.json、official_scene_checkpoint_qualified_v23h.json；同步scene_source_sync_v23h.json；平台历史发布docs/STEAM_UPDATE_20261007.md。
