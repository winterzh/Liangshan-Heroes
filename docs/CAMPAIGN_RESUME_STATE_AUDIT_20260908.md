# 八关续玩状态审计与独立 Level 组件

日期：2026-09-08。生产清单来自 `scripts/campaign.gd`。本批新增 `scripts/run_campaign_level_state.gd`、`tools/campaign_level_state_qa.gd`，未接入保存按钮、Battle屏障、世界恢复或Steam；不代表八关已经可续玩。

## 本批组件接口和所有权

- `capture(level, level_id, content_version, id_to_unit, next_entity_id, external_to_token, boundary)`：仅支持当前八个固定生产脚本。显式字段清单包含短版继承字段。`boundary`必须明确提供`mission_token`及`deferred_drained=true`，这是外层对同一冻结快照的承诺，组件不自行证明整场屏障。
- `validate(record, level_id, content_version, known_unit_ids, next_entity_id, external_tokens, mission_token)`：独立校验形状、类型、稳定ID上界、版本、阶段/波次数及外部依赖是否完整。
- `restore(record, level_id, content_version, id_to_unit, next_entity_id, token_to_external, mission_token)`：只创建新的RefCounted关卡并回绑已有图；不部署、不启动、不激活、不发信号。返回始终标记`complete_world=false`。
- restore接收的全部Unit和外部Node必须**尚未进入SceneTree、PROCESS_MODE_DISABLED、signals blocked**；已挂载的暂停世界也拒绝，防止新关卡错误绑定旧世界。外层必须在私有图准备阶段调用，然后统一挂载/激活。
- Unit图由调用者持有；单位引用用十进制稳定entity ID，支持有序含空位数组、嵌套编组、生辰纲索引映射，以及快活林`{u,drunk}`酒馆条目。无效已释放引用规范为显式空位；仍存在但不在注册表、正在queue_free、entity_id冲突的对象拒绝。这不保存死者身份，若整场还有死者身份需求必须由Unit图的退休ID机制负责。
- 按钮和关卡视觉用外部固定token，不写对象或Resource。外部token必须一对一；缺少任一非空绑定拒绝。组件只约束Button/Node2D基本类别，可信外层视觉模块必须校验具体脚本、资源和节点生命周期。
- Mission、Unit metadata、世界/RNG、地形、UI、关键人物角色与任务相互约束仍归各自模块，不能凭本组件通过省略这些校验。反射仅对显式清单审计漏项，绝不自动选择待存字段。
- 野猪林`escort_player_target=Vector2.INF`使用独立标记保存；`escort_orders`的历史entity ID需小于分配器上界。进程ticks绝对值不属于本组件。

## 各关独有字段、引用和验收点

字段的完整、可执行白名单见新模块`FIELDS`。下表列出接入最容易遗漏的语义。

| 生产脚本与关卡 | 关键值和引用 | 完整世界必须验收的时点 |
| --- | --- | --- |
| `level3_zhujiazhuang_rts.gd` 祝家庄 | elapsed/train_clock/raid_clock/strategic_clock/stage；expansion_secured/supply_cut/inside_open/prisoners_freed/manor_fallen/sent_sun/main_breached；AI花费与raids_sent；hall/song/gate/side_gate/enemy_base/outpost/hu/sun；prisoners及工人、资源、预备、训练队数组 | 侦察/北矿/外营引出孙立只能一次；偏门打开后不能重复注销占地；150秒出击前后；七囚释放后保留索引0时迁与伤员阵营；时迁先回营、其余未齐时恢复选择/收军按钮 |
| `level1_huangnigang_short.gd`及父类 生辰纲 | st、酒计步序/疑心/试酒/药瓢/售酒布尔、attention_left/rest_t/team_t/distraction_serial；货担索引→Unit映射cargo、分工/ready/attempts、delivered/depart_requested；cart/yang/convoy/bundles/actors；枣车/酒桶牌等外部视觉 | 押队到冈不吞任务；22秒引目和3秒协作中恢复保持_order_serial；麻倒押队前后；三担并行搬运及携带者死亡后落担接力；三担已交但人物未齐；携带物隐藏节点不能丢 |
| `level6_yezhulin.gd` 野猪林 | st/exec_timer/care_t、暗随路线/注意/警告、tracking_done/treated/rest_reached；lin_bound/lin_freed/lu/escorts；escort_player_token/target/orders；help_t/victory | 暗随阈值；押送林冲→绑缚林冲替换；拦棍倒计时；1.8秒解缚与2.4秒治疗之间；休息35HP只发一次；四人手动命令和停止意图保持；两解差损失后核心与演义目标分离 |
| `level2_jiangzhou_rts.gd` 江州 | 150秒exec_left/execution_halted、alarm；cache_taken；追兵20秒pursuit_left/sent；付费补军train_left/produced/spent；宋戴bound/freed引用；named_units与各队；rally/meeting/victory，depart_button外部 | 仅一名刽子手死亡；领取补给+100金60木前后；只救下一人；追兵将出发；补兵第7/8人；一人已embarked、二人均embarked和可选全员收队；替换角色不重置_combat_cool |
| `level7_kuaihuolin_short.gd`及父类 快活林 | 酒量drunk/steady_left、st；fist_cd/windup/at、special_kind/index、rush_from/end、charge_running；exposed_left/opening_serial/step_serial/step_origin/counter_hits；wu/shi/sign/menshen/taverns；fist_marker/drill_marker外部 | 饮酒/练步；1.6秒重拳、1.25秒冲撞起手与真正冲撞中；2.2/2.8秒破绽踏步后踢；subdued之后复店。`_verify_hit.call_deferred`必须在外层屏障证明排空，或改为明确持久队列，本组件的boundary只是承诺 |
| `level4_lianhuanma_rts.gd` 连环马 | waves的time/warned/sent；elapsed/strategy_t/escort_t；broken_count/lhm_killed；教场entered/withdrew/coordinated/complete、lure/origin；hall/song/xu/hu/han/base/dummy；riders/posts/escorts/工人 | 150/270秒出击前后；拆辎重营延45秒只一次；诱骑撤步双人下钩；徐宁再招募/演练骑重摆；部分已破阵或死去；12骑和大营都解除后只结算一次 |
| `level5_gao_rts.gd` 高俅 | 三批waves、production_t/produced、AI花费；lure_started/cell、fire_prepared/lit、port_sealed/flagship_disabled/recovered/landed/capture_lost/core_ready；水陆嵌套groups；embarked_liu/liu_carrier/carrier/prisoner/fireboat/flagship；end_button外部 | 140/330/540秒波次；60木备火后；8秒地火在途；刘唐转接应艇及艇沉人口预留释放；座船停航→封港→接俘→岸上生成俘虏；capture_lost仍可基本通关；core_ready按钮需重建 |
| `level8_daming_rts.gd` 大名府 | gate_open/prison_open/rescued/signaled/signal_left/reserve_returned；elapsed/strategy_t/train_t、追兵warned/sent/t；spies/工人/预备队/追击队/escorts；hall/strategist/scout/chai/yue/gate/lu/shi/enemy_hq | 2.5秒疑心暴露和3秒蔡福家恢复中；90秒火号暂停补兵中与结束；强攻/内应两条开门路线；牢门地形阻塞；15秒追兵；一人已retreated安全另一人仍在路上 |

## 尚未解决的共享世界阻塞

1. `run_battle_barrier._scope`硬编码economy、defense30、skirmish及mission为空；短关本来不经营，不能仅把mission校验删去。
2. `run_battle_world_core`固定据守脚本/LevelState，无mission section；`run_battle_root_state`拒绝mission存在。恢复需由可信context注册表统一选择脚本，不能用存档中的路径加载。
3. `run_slot_store`与`run_world_session`固定classic schema/context/flags/hero_cap4；必须保存官方章节身份和实际Campaign.current，避免恢复后成绩归错关。
4. CampaignMission持有stage、events、story_goals、有序actions、active_action_id、actor、progress/retry、generation、阶段计时指标和冻结结果。按钮/marker/Callable不可直接序列化；`mission.begin()`会清空动作/进度，不可代替恢复。`_stage_started_ms`必须转换为跨进程流逝时间。
5. `run_scenery_state`仅接受LiangshanScenery，CampaignScenery要单独适配story_object状态（大名府翠云楼signal、牢门open等）。地图占地不能在恢复中重复注册。
6. Unit metadata普通标量已被现有Unit模块保存（乔装、阵型、载人、货担等）。**大名府敌工人`daming_mine`含Unit对象，当前codec拒绝**，必须专门稳定ID回绑，不能忽略整项。
7. `MissionMarker`、`DuelTell`、`JujubeCart`、`FieldSign`以及额外选择/结算按钮，须由外部受信工厂重建，并保持具体实例与本组件token一致。controls_generation相等时不会自动重建按钮，不能指望下一帧修复缺失UI。

## 本批验证

### 固定引用维度修正

独立复核发现首批152项未覆盖固定引用池缺项：例如高俅的空`water_groups/land_groups/posts`在旧组件可通过，但生产会直接索引。旧记录保留用于追踪，**不能据此认定固定维度安全**。新组件在capture和validate共同检查，restore复用校验；fixture不再统一用三项数组充当所有关卡。

显式维度为：生辰纲bundles=3（毁担立即失败，续玩不允许缺担空位）；江州caches=2、executioners=2；祝家庄prisoners=7；连环马posts=2、riders=12；高俅posts=2、water_groups外层3/内层3、5、6，land_groups外层3/内层4、6、8；野猪林escorts=2；快活林taverns=4；大名府posts=2。生产这些池在单位死亡后保留原槽，故除纲担外允许空引用，不能删除数组位置。高俅内层池也从未filter或重排，死亡不减少其部署维度。连环马/大名府的动态escorts会filter并补充，仍允许空数组，并有正向测试。

已逐个检查实际固定索引消费者及集合修改：江州cache索引来自0..1任务；祝家庄prisoners[0]依赖时迁；连环马与大名府posts按两路索引；高俅按三波和两处生产索引；快活林taverns索引同时对应四个TAVERN_CELLS，不能任意扩展；野猪林escorts[0]区分两名解差。按当前数组.size遍历的actors、convoy、workers等未仅凭相同关键词强加固定维度；on_start的enemy_nodes[i]不在恢复中重跑。本组件仍不代替实体角色、任务状态的全世界交叉核验。

R2冻结批次`20260908_181947_939bf440`通过205项，包含每个固定字段空数组的capture/validate/restore拒绝、超长数组拒绝、嵌套内层缺失拒绝、合法动态空数组及缺担拒绝。随后单独增加QA profile入口早退与runner负向用例，最终采用包含该检查的后续批次。

QA必须作为带autoload的Node主场景运行，不能用`--script`直接跑生产依赖（会在autoload标识注册之前解析，出现Sfx等缺失）。首轮直接脚本尝试发现这一问题，已改为主场景，并加入至少96项检查的下限，空报告不得当PASS。

最终冻结批次为`qa/campaign_level_state_20260908/20260908_182211_992a0be3/`，实际完成**205项行为检查**，全部通过。fresh import 23.22秒与component 3.89秒均退出0、错误0；独立profile_guard进程3.91秒按预期退出2、错误0，输出`PRIVATE_PROFILE_REQUIRED`且未产生报告，证明错误profile在fixture创建前拒绝。源码基线为`21d70bcf85f6cd7c8601dec110a84c54f01f59ba`加本批新组件，2945项输入在当前工程和冻结项目分别核对，共5890次SHA检查通过。这些SHA检查与profile_guard不计入205项行为检查。早期`20260908_181217_518d3e1e`的152项及中间R2的205项保留作修正追踪，不再称为最终批次。

使用`py -3.14 -X utf8 -B tools/run_campaign_level_state_qa.py --run`复现；不加`--run`仅预检。runner冻结生产依赖、使用共享Godot锁、新建私有APPDATA/LOCALAPPDATA/TEMP/TMP和fresh import，不复用未知导入缓存；核验Godot二进制和源码，并要求至少200项行为检查。QA报告路径通过`LSH_CAMPAIGN_STATE_REPORT`指定；没有该环境变量时仅输出stdout，不写工程根report.json。

测试创建八个实际生产关卡实例，使用真实Unit类的独立注册表，不调用deploy/on_start；验证JSON中转、引用同一性/顺序/空位、嵌套数组、外部节点绑定、非有限哨兵和版本/缺失引用拒绝。它不证明实际战斗角色匹配、任务一致性、全程通关、Steam统计、性能或真人验收。

### 最终独立复核

最终205项报告、三步退出码与日志均回读；重新计算2945项当前工程和2945项冻结文件SHA，均与receipt一致，已归档的源码快照和三份日志也零差异。此次复核未启动Godot、未修改三个已测源码，仅修正本说明和QA索引的旧批次表述。来源指纹与证据文件清单见`qa/campaign_level_state_20260908/final_review_20260908.json`。

| 已测源码 | SHA-256 |
| --- | --- |
| `scripts/run_campaign_level_state.gd` | `3c66f30484693163fbd518a7fc2c74701e8c0975788d5a02c7606daa6d9a5108` |
| `tools/campaign_level_state_qa.gd` | `b8e44bedc435c932c6921366151b895736f8244c143a27a4035edc7b67ed51ad` |
| `tools/run_campaign_level_state_qa.py` | `973e1f83cdec8863a45dc4835ad53cf9777e8a54fa9cfdbe0c58aacbd7aca3ba` |

本组件没有发现新的确定性实现缺陷；未测范围仍是上文列出的共享世界接入及真实任务角色交叉约束，不能据此开放八关或经典续玩入口。
