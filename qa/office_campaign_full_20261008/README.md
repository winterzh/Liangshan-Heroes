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

## 2026-10-08：V9/V10真实失败保留；东营经济后继待审

V9 `office_full_b0f1d997`终态失败、锁释放：前序JSON533/Owned76/半程ABC39/351/342通过；Lu-first A PID12360、46检查在prison approach clear natural deadline失败。phase=FIGHT、营HP1500、四真实守兵110血、吴用24.85血、assault为空，卢/石尚未救。rally检查已通过；可确认守营与攻城队存活是不同问题，完整撤离未通过。26份原收据/日志/报告保留`actual_failed_v9/`。

普通付费采集/第二民居/作坊/2投石车/12步兵的v30经独立V10审查准入，原51必需标签和52负例不变；新批`office_full_74d3a3eb`终态退出1、锁释放。Lu-first A PID37532、59检查：两house及workshop实际建造完成，第二次六工人存活采集检查失败，尚未到攻城训练/营救；原报告没有工人详情，不能确定具体死亡/路径原因。26份原证据保留`actual_failed_v10/`，原profiles/CFG/存档未改或上传。

新不可变v31在开局先用普通资源中心minimap_order安排六原工人采集东营实际金/木，再限制新增建筑普通preview在东营；仍要求六工人，失败记录实际hp/dying/outcome/position。付费/人口/队列、军队规模、原ABCD/负例和validator均不改。源bundle/seal_v11已封存，独立审查待完成，尚未启动新full。当前唯一新自有native为恢复候选R5解析批；不并行新full，观察超时不重开。

## 2026-10-08：V8-R3失败保留，V9新完整批

V8-R3 `office_full_f2d8d7cc`实际终态失败、锁已释放；Lu-first A PID30668退出1，24检查仅“normal building order sets camp rally”失败。实际JSON533、OwnedSlot76、办理半程独立ABC39/351/342及来源审计通过，不能拼成完整双角色资格。原收据SHA `f4b9e370918d64ff60db791649f2324d97a3384351445309d4ab0543aa898c0d`，27份原收据/日志/报告已逐字节保存于`actual_failed_v8_r3/`；玩家/测试profile、CFG及存档不入Git，原位置保持。

源码核实普通minimap_order经to_screen→_issue_order→to_logic；高度场unproject做20次二分，原逻辑点与反算命令点不要求逐位相等。旧失败报告未记录实际rally，因此不能把运行原因写为已确证。后继v29保留玩家命令，要求真实selection/produces/has_rally、exact API逆投影目标及原cell，并记录实际请求/画面/API/集结数据。原v28和不可变消费者/全部门禁未修改。

同一用户授权独立审查员完成V9来源/API/full审查：收据SHA `87e3a55c033a622b8e318425e25ce1e272dac62345111a99ad5cf1512012c443`，绑定producer `6a3fbe5b…`、prep `5864a673…`、seal_v9 `5e04a907…`、v29三源清单。54 QA pins、两端5132 runtime、5031基线来源、engine/native闭合；只读完整预检实际通过。静态批准不证明守营或完整续玩通过。

全新批`office_full_b0f1d997`控制器于本机15:25启动（观察session36807），使用新UUID/profile及新有界截止UTC2026-10-08T13:25:19.483091Z；实际argv见`../office_campaign_route_20261008/ACTUAL_LAUNCH_V9.json`。各native阶段仍等待自然空闲60秒，启动后外部Godot进入则整批失败并保留；未控制/消息协调其它任务。本段仅记录启动，结果须读本批实际终态，不因观察过期或缺收据另开批。

## 最新：CFG受控替换组件36检查通过，完整V8-R3继续

CFG组件四案例/八个不同实际PID/36检查完整通过，包含backup/install两处真实进程中断后恢复与外部CFG改动后的拒绝覆盖。原失败保留，正式生产源码未改；结果不延伸为玩家UI、自然战役、完整gen2→cfg→ack或奖励通过。[真实组件证据](../campaign_progress_recovery_20261008/README.md)。

恢复候选增至八GD，新进度gate和保留式协调器只完成源码闭合，尚未安装/解析/独立审查或集成Campaign/ContinueFlow/Battle/startup/prefs/cloud。源快照与实际原失败均完整。

同一V8批准的完整续玩源启动新全批 `office_full_f2d8d7cc`，观察session36886，当前等自然引擎空闲；V8-R2原失败未复用，新结果须等本批实际终态。[完整QA](../qa/office_campaign_full_20261008/README.md)。原19案/194检查v27b组件资格保留，其余完整计划继续。

## 当前完整批终态与CFG组件观察

V8-R2 `office_full_e8f3fca4`已真实终态退出1，锁释放。其导入/守卫/JSON533/OwnedSlot76/办理半程ABC39/351/342和源审计通过；Lu-first A PID22392开始后另一引擎进入，按原守卫终止，原profile/失败完整保留并归档actual_failed_v8_r2。新守营策略未完成验证，完整双角色/負例/自然终局仍未通过。

当前唯一自有新批为CFG组件 `D:/CodexTemp/lsh-campaign-cfg-20261008/cfg_component_c5212404`（观察session41902），使用源封存V5、同引擎实际协议proof/基线；目前只控制器启动、等待自然空闲，尚无组件Godot/结果。没有同时运行新的完整续玩批。后续只观察本批终态，不按观察超时重启。

## 当前V8-R2：V8已终止，新批不继承前序资格

`office_full_933181f4`真实导入/守卫/JSON533/OwnedSlot76/办理半程A39通过，B进程期间另一Godot进入，整批退出1、锁释放；原日志/profile原样保存，收据/逐阶段/报告归档`actual_failed_v8/`。没有测试到新守营路线，不宣称策略失败或通过。

相同已批准producer/seal_v8/v28路线未改，用全新UUID/profile启动`office_full_e8f3fca4`；`../office_campaign_route_20261008/ACTUAL_LAUNCH_V8_R2.json`保存实际命令与新截止UTC2026-10-08T10:17:07.645475Z。当前真实导入PID39084退出0、守卫PID7464预期2、JSON PID11812/533退出0；其余阶段尚待实际结果，不沿用旧批成功。当前观察session40788仍活。以下旧“唯一新批”属于历史。

## 2026-10-08 11:49：独立V8静态通过，新完整批启动

当前唯一新批 `office_full_933181f4`，全新UUID/profile，实际argv与新6小时截止UTC2026-10-08T09:49:16.717669Z封存于 `../office_campaign_route_20261008/ACTUAL_LAUNCH_V8.json`。启动时等待共享Godot连续自然空闲60秒，不启动第二批，不控制其它任务。完整结果仍以这个批次实际终态为准。

独立V8审查SHA `33cedc5d60246dcc82cc0b9c13258e90645101a4d3b04b1e5218437527da4468`、producer `6a3fbe5b…`、seal_v8 `22e915a5…` 和v28 bundle `a58bba32…`精确绑定；54 QA pins、两端5132 runtime、5031基线输入与engine/native闭合。新路线使用普通合法建屋、实际扣费/人口/正常训练与集结守营，原双角色ABCD、world264/component362/live24及52负例全部保留。V6/V7拒绝及旧失败profile不变；静态批准不是策略或完整续玩通过。

# 公司完整续玩后继：独立静态审查与实际启动

## 当前 V5 与实际 V4 失败

V5后续已真实终态失败（11:10）：JSON533/OwnedSlot76/办理半程ABC39/351/342全部通过；Lu-first真实A在未救出两人时phaseEND，33checks内一项不通过，整批退出1、锁释放、producer PID37484已不存在。`actual_failed_v5/`保留整批、逐阶段/源审计收据、全部日志、成功前序报告与失败Lu报告；所有原profile仍完整，不复用。完整双角色ABCD与负例资格仍false。普通守营策略后继及独立失败审查另存[路线QA](../office_campaign_route_20261008/README.md)。下方V5“仍运行”文字为历史。

V4 实际完成导入（PID5752/退出0）、私有 profile 拒绝守卫（PID8416/预期退出2）、JSON533（PID30036/退出0）与 OwnedSlot76（PID27600/退出0）。办理半程 A 尚未创建子进程时，另一引擎进入；整批退出1、complete=false、锁释放。实际 producer PID6416 已确认不存在。`actual_failed_v4/`保存整批/逐阶段收据、日志和两份报告原字节，旧profile留在工程外，不复用。

V5 只修正启动前竞争：尚无自有子进程时释放自己的锁，回到连续自然空闲60秒；启动后的原检查/失败策略完整保留。用户允许的同一独立审查子代理已比较原消费者 AST，V5 full 静态通过，审查SHA `c742d44e…`；producer `dbf31328…` 和 seal_v5 `b16aeb4d…` 精确绑定。

新的唯一完整批为 `D:/CodexTemp/lsh-office-restore-20261008/office_full_8499098a`，producer实际PID37484，session28901。`ACTUAL_LAUNCH_V5.json` 保存实际命令，新批截止UTC2026-10-08T08:15:02.308150Z；它仅约束本测试批。`source_snapshot_v5/`与`delivery_v5.json`封存启动来源。原V1—V4来源/审查保持。V4前序通过不继承成V5全链通过，继续只轮询实际活批；所有完整计划仍开放。

以下V4启动文字保留为历史，当前以本段及新批实际终态为准。

V1、V2、V3为真实未通过的独立审查，保留三项来源/工具解析问题与原pins。修正后的V4独立审查 `static_api_closure_passed=true`、`approved_stages=["full"]`，绑定实际producer `7de38d40…`、原preparation及seal_v4 `b59eebf5…`。这仅是开始完整运行的源准入，不是原生测试通过。

新完整来源表包含两端各5132项runtime、50条QA/helper/11fixtures源；真实5031份启动基线、引擎与native依赖也由独立审查核对。49个非提案文件只有LF/CRLF表示差异，候选已精确对齐并保留原字节。只有Core/UnitContract两项语义提案，Main正式代码未变化。

执行器继承原固定四模块的真实完整消费者：JSON533、OwnedSlot76、办理半程ABC39/351/342、Lu-first/Shi-first两份真实A、各world264/component362/live24及ABCD自然终局/新进程旧槽拒绝，合计52负例进程。固定pin持续检查，不重新以漂移字节建立基准。新冷导入只可添加有对应原源文件的UID/import描述，原源码/native bytes必须不变；随后整个身份封存。

`ACTUAL_LAUNCH_V4.json` 保存实际argv和本次6小时批次截止。唯一活批为 `D:/CodexTemp/lsh-office-restore-20261008/office_full_4d0eefc5`，观察时实际producer PID6416存活、仍在自然空闲等待，原生阶段尚未开始。后续必须轮询同一session/实际PID与其终态，不能因观察超时重启，也不能把旧审查或准备判为运行通过。原始运行日志/profile/receipt留在工程外，完成或失败后按实际原字节另归档。

`delivery.json` 为此次静态来源交付SHA；`source_snapshot_v4/`为实际启动执行器和封存工具字节。旧首版源码在 `qa/office_baseline_20261008/source_snapshot/` 保持历史，不替换为当前版本。

完整目标仍含真实进度落盘/19故障、玩家错误反馈与恢复、八关动态及生产运输、美术UI、九玩法发行程序、正常时钟约10分钟性能和Android真机。当前 `runtime_qualified=false`。
