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

## 2026-10-08：十四源接入、真实16检查与独立拒绝后继

候选`integrated_v4_r2/scripts/`已把恢复模型接到Campaign/ContinueFlow/Battle/Menu/SteamCloud，含固定目录最多256合法token只读扫描、当前pending与已确认历史区分、三代确认、真实Steam token侧日志及Core分配前旧槽拒绝、one-use完成展示、延后设置写入和错误重试。正式13来源（含原Core/Contract、classic）SHA/提交字节零差异，未安装生产。

R2真实解析批`integration_parse_7cb75b98`：导入23272/正常菜单180帧40996终态0、错误0。真实启动/设置批`integration_startup_8f93ba0c`：导入42372/探针45576终态0、错误0、16检查全过。根Flow确实startup_checked=true，Gate开放；正常save_prefs延后写实际CFG，fresh ConfigFile读回hard/regicide，同内容重存SHA不变，无运行日志或Steam活跃run。原收据/日志/报告在`actual_integration_parse_v4_r2/`、`actual_integration_startup_v4_r2/`，原第一轮Projection内置名称冲突失败保留`failed_integration_parse_v4/`。只覆盖空档案和正常prefs，不证明pending/UI/终局/重启/奖励。

用户明确授权扩展独立审查至十四源及后继全链执行器。R2独立审查拒绝8项P1：源身份重试不复核、设置队列不唤醒、云错误无重试、A→B误拒绝、mirror/exit绕过gate、空active自有锁释放无重试、startup非progress CFG对象丢失、零代/恢复锁误判无pending。收据`INTEGRATION_SOURCE_REVIEW_V1.json` SHA`8fbcd0b708dbff0a18816e4c91139d3c2dd19c432f160ed6aa518fa6beee1d83`；14源/77引用/13生产和原真实证据回读一致。R3/R4中间修复不升级为资格，所有源保留。

最新不可变`integrated_v4_r5/scripts/`与`SOURCE_AUDIT_V8.json`、`integrated_source_snapshot_v8/`封存14源/80引用。新增实时完整身份复核及门禁后设置调度，Cloud保留原owner/目标owner/bindingSHA/初始完整身份并可见同对象重试，最底层mirror拒绝shared pending；CFG/lifecycle保留已成功移除原owner后的空目录释放阶段，仅核同实例/原nonce/路径/head/SHA及空目录后重试，不删除staged/pending/data；无proposal自有锁失败状态保留，零代/恢复锁阻挡启动，startup保留非progress CFG对象/原提案。新批`integration_parse_fc392cb9`只做隔离解析/菜单，观察session58153，实际结果待终态；独立R5复审进行中，不给full批准。

完整normal fresh/续玩终局→gen2→真实CFG→gen3、跨进程故障、19案最终源、玩家pending/安全重试、多章节和真实Steam奖励仍待后继完整执行器及实际证明。旧V2 CFG四案八PID36检查/v27b19案194检查只属原组件，不能扩展给这些新接入源。

## 2026-10-08：V3候选保护；旧组件通过范围保持

新增`proposed_v3/scripts/`八文件候选，原V2及其真实四案/八PID/36检查CFG证据保持不可变。V3协调器在访问Battle属性前先核验固定缓存脚本及当前真实scene；纯进度投影拒绝时，只能释放本对象持有且仍处于building阶段、无冻结/暂存/待写记录的CFG锁。释放失败保留原状态供再次核验；未知/丢失所有权继续拒绝，不承诺所有故障都可原位重试。真实已暂存提案/原文件/日志不丢弃。生产9来源SHA不变。

`SOURCE_AUDIT_V6.json`和`combined_source_snapshot_v6/`封存全部八源；本轮核对23个固定脚本引用及未限定本地方法名称闭合。这只是源码核对，V3未Godot解析、未独立审查、未原生、未接入游戏。旧V2组件和v27b19案均不扩展为V3资格。正常fresh/续玩terminal→cfg→ack、startup有界扫描、玩家失败UI、prefs/cloud排他写入及奖励一次性仍需集成和实际验证。

完整续玩V8-R3实际rally检查失败后已保留，独立V9批准的新完整批`office_full_b0f1d997`启动；本轮不同时开启V3/CFG native批。

## 当前：CFG四案例实际组件通过，完整续玩V8-R3启动

CFG新批 `cfg_component_40939c93`已完整终态退出0，锁释放：四案例、八个实际不同PID，36检查全部通过。正常替换/同内容重存、真实backup窗口中断并新进程恢复、真实install窗口中断并恢复、控制器实际外部CFG变更后的拒绝覆盖及新进程再次拒绝全部完成。真实断点源/函数/行/thread和文件SHA已由控制器绑定，偏好/未知字段/无关record保持。

原收据SHA `c555249e35c509b12655ed5c9f23bb4dcd26f639e646840a10ee4fc03604c09f`；原收据/日志/报告存`actual_cfg_component_v6/`，资格明细见ACTUAL_CFG_COMPONENT_PASS_V6。原V5初轮首案失败、原profile及源全部保留；V6只等待真实process frame进入非physics阶段并补失败code观察，生产磁盘守卫/原检查数不放宽。

新增progress gate和保留式terminal→cfg→ack协调器候选，冻结同局意图、每次重试再核对实际Battle/owner/context/安装身份，完成展示仅可消费一次；恢复只能进度，不重新构造战斗/Mission/结算。八GD来源见SOURCE_AUDIT_V5/combined_source_snapshot_v5。除CFG组件涉及的存储/语义两文件外，其余新候选仍未解析/native；新协调器未接Campaign/ContinueFlow/Battle/startup/UI/prefs/cloud，不宣称玩家恢复功能、gen2→cfg→gen3实际全链或奖励通过。

完整续玩用同一V8批准producer/seal_v8/v28三源、新UUID/profile再开V8-R3；目前真实结果须读本批，不能继承旧ABC作为全链。当前只运行这一自有完整批，不同时重开CFG组件。完整八关/生产运输/美术UI/九玩法/性能/Android原计划继续。

## 当前六份GD候选与完整批终态

新增WorldSession候选：campaign用严格v2、classic用原v1；在Core.prepare前和mount前核对真实脚本/token/root/context/安装身份/owner。旧不绑定章节的campaign v1明确拒绝，不迁移、不修改原记录。新增纯同局投影保留偏好/未知CFG及record数据，不union跨局目标；无文件/回调/战斗/奖励操作。六候选原字节与9生产来源核对记录在SOURCE_AUDIT_V4/combined_source_snapshot_v4，未解析/未native/未接入正式游戏。

完整V8-R2已在Lu-first A期间因外部Godot进入终止，完整双角色仍无资格。当前唯一新自有批为CFG组件cfg_component_c5212404/session41902，使用源封存V5；控制器等待自然空闲，尚无Godot结果。没有同时新开完整续玩批。旧19案只属v27b，不能延伸为本轮候选或玩家恢复通过。

## 当前v2后继与受控CFG组件候选

`proposed/`原v1与SOURCE_AUDIT_V1原样保留；其三代模型会受到父存储默认只留两代的影响，不可作为native准入。`proposed_v2/`四文件候选修正三代保留、只有本对象实际提交/持有原锁才取得结算能力，新增v27b原数据Variant/语义helper和受控CFG替换。

Windows官方tag的不同名rename会先删目的文件，候选先将旧CFG移入自有固定备份、再向空目的安装；全流程固定元数据/SHA、深拷贝ConfigFile、真实save/fresh load/完整语义回读。旧文件未知字段、偏好及无关record保留，backup/install窗口可由新进程按同事务恢复。备份前重新读SHA，拒绝外部改动时保留公开CFG。全文件encode_to_text缺少章节名转义，仅用于大小估计，不再作为恢复序列化。

当前仅Python解析/固定依赖与源检查，全部9份生产源码SHA未变；没有安装正式工程、没有Godot解析/native资格、没有独立审查。当前源为`CFG_COMPONENT_SOURCE_PREFLIGHT_V5.json`与`SOURCE_AUDIT_V3.json`，完整案例和执行约束见[组件计划](CFG_COMPONENT_PLAN.md)。v27b旧19案通过不延伸到这些新候选。完整协调器、入口/扫描、pending/UI/prefs/cloud、自然终局及gen2→cfg→gen3 ack仍未集成。

# 战役终局进度恢复：v2 日志基础候选

当前只有两份新GD候选，放在本目录`proposed/scripts/`，没有安装到正式工程或任何正在运行的QA。尚未经过独立审查、Godot解析或原生测试；不是玩家恢复功能交付。

原`run_local_lifecycle.gd`经典v1和`run_snapshot_store.gd`保持原字节，分别SHA e68cb817…/581e638b…。新campaign sibling沿用原存储层的canonical UTF8/envelope/payload、previous SHA/CAS、持有者原锁重试与死进程恢复，不放宽v1。新版精确gen1 active→gen2 terminal/pending（原同局冻结结果）→gen3 terminal/applied（真实cfg确认）；3代全部保留，缺genesis、跨context/token/owner/installed identity、gen2→gen3结果/胜败改变均拒绝。

Intent从真实当前END Battle、安装章节分类、原Mission对象和实际result_snapshot取得，仅记录原同局6个进度字段。八章固定version/goal IDs已与当前叶脚本/继承父脚本逐值核对；这只是目录/源码闭合，不证明八章自然结果。恢复验证只读数据，不重新创建Battle、Mission或章节工厂，不重复tick/胜利画面/Steam结算。

ack只能接受真实非QA写盘回读收据；另外独立读取固定`user://campaign.cfg`，核验稳定原SHA、owner、解锁和单局非叠加结果。QA suppression不能作为ack；败局只能确认“不需要写进度”，不声称写盘。历史gen3的cfg SHA只作为当时收据，后来合法偏好/其他关进度更新不要求永远保持同一SHA。

原存储层原锁重试会对任何terminal record标记终态，因此新版另持结算能力：progress-only recovery的ack重试不会获得新Battle/Steam结算授权。所有cfg/ack不确定写入仍待完整协调器接入。

仍需实现和验证：Campaign纯投影及受控临时文件/CAS替换，prefs/cloud与进度pending写入锁；WorldSession按actual/slot context选择v1或v2并在Core分配前二次核对；ContinueFlow的普通fresh无save胜利与terminal→cfg→ack协调、startup有界发现/恢复与async安装；Battle结果只冻结一次、玩家失败UI/安全重试/一次性展示。然后独立源码审查、正常QA=0双角色ABCD、gen2后退出/cfg后ack前退出的跨进程故障、旧classic原字节/完整故障回归。完整原计划与平台/性能/真机资格保留。

`SOURCE_AUDIT_V1.json`为当前候选及实际生产来源/八章目标表的源码核对，所有runtime资格仍false。设计依据为`qa/zhu_wounded_20261005/proposals/campaign_local_context_progress_20261008/DESIGN.md`，当前运行批及旧失败profile均未修改。
