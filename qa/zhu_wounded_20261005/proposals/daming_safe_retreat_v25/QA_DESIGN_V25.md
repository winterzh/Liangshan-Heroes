# 大名府单人撤离：原生 QA 设计 v25

状态：仅外部设计与可复用路由骨架，未启动 Godot、未 parse、未执行、未修改公共源码。该文件不表示候选已通过。原 v24o / v24r producer 与其失败证据保持不变。

源码复查修正：`Campaign._save()` 在 `CAMPAIGN_QA=1` 下直接返回 true，不写 campaign.cfg。原本设计的 C/D Campaign持久回读不成立，已收窄为 C真实内存结果、D确认Campaign文件未新增/未改且仍为原持久基线；持久Campaign资格必须false。未来另开正常私人profile批，专门审查环境flags和持久写盘，不在当前批去掉guard或改生产代码。

## 实际入口与边界

读取的入口为 `scripts/levels/level8_daming_rts.gd`、`unit.gd`、`battle.gd`、`campaign_mission.gd`、`campaign.gd`、`continue_flow.gd`、`run_local_lifecycle.gd`、`run_world_session.gd`、`run_level8_unit_contract.gd`、`run_battle_world_core.gd`，以及 `E:/ChatGPT/daming_admit_v24o_proposal/daming_admit_cross_process_v24o.gd`。

v24o 已有真实启动、私人 profile、普通玩家指令、HELD、Session 全量保存/恢复、全量 world/packet 对比、时钟重基与绑定审计。新 producer 必须从当前**已成功合格**的后继 harness 复制这些实现，并注明旧版失败修复，不能把 v24o 的未通过代码直接称为已验证基础。使用新 v25 sibling/profile/slot/handoff，不覆盖任何旧 producer。

原 L8.process 每 0.25 秒检查本人：rescued、gate_open、alive、距 EXIT_CELL≤130、cell.y≥45。只在这些条件真实满足后调用 `resolve_story("retreated")`，随后 mark 本人 safe event；两 safe 后 mark daming_victory 并 b.win。骨架只做普通选择/移动/攻击移动、观察和申请 HELD，不调用 mark、resolve_story、on_mission_action、win，不写 hp/坐标/计时/旗标/故事结果。

自然路线未经运行，战斗能否成功、双方护送是否存活都尚未知；若正常路线超时或败北，保留真实失败，不降低门/牢守军条件、免伤、清敌、传送或补事件。可以另开明确命名的 component_fixture 子批，将真实救出 callback 后 DTO 作为组件资格输入；它不得计入下面 natural_victory / full_disk_exit_continue 资格。直接调用正常 callback 只是组件 fixture，即使随后走路成功也不能声称完整自然营救路线。

## 路由候选：保留全部真实任务门槛

1. 用现 v24o 同样普通指令先让乐和到 PRISON_CHECK 邻格、柴进入实际受验标记。等待真实 daming_prison_admitted 和 admit.done，不注入进度。
2. 手动让柴进与乐和到 PRISON_INSIDE，并确认二人仍 disguised / inside；让时迁到 FIRE_CELL。等待真实 daming_fire_lit、signaled 及 daming_gate action。
3. 只使用初始场上且 alive 的鲁智深/武松及至少两名 FIELD_KEYS 战友：普通攻击移动清 GATE_APPROACH 周边敌人，随后普通移动在任务标记形成真实 mission order。等待门开、响应事件、原 gate retreated。若部队不足或守军未清，真实失败，不改 crew 数。
4. 同一真实部队攻击移动清 PRISON_CHECK / JAIL_ACTION 的 guard/tower；让柴进或乐和普通移动到 JAIL_ACTION，等待真实 rescue.done、prisoners_freed、两角色 faction0/captivefalse/speed68/art变化。记录是否完整原著路线；提前开枷的自然核心通关也必须保留其不同 story_result，不能伪称所有原著目标完成。
5. 将部队普通攻击移动清撤离通道，并护送**指定第一人**，另一人留在牢区、仍 live/root/active。首人普通移动至 EXIT_CELL，观察第一 completed physics 后 safe event / retreated 的一致状态。

路由骨架 `daming_safe_retreat_route_v25.gd` 可供 runner 调用；其等待与路线只是待测候选。runner 的 check/报告/身份/保存恢复仍由已合格基础 harness 提供，不允许路由模块构造存档。

## 每种 first_actor 的四进程流

两种变体 `lu_first` 与 `shi_first` 使用完全独立私人 profile，内容/引擎同一冻结身份。每个进程新 PID/nonce，handoff 保留全部先辈 PID/nonce 与完整 slot bytes SHA。

| 进程 | 真实动作 | 必须证据 |
| --- | --- | --- |
| A_single_save | 完整普通营救；第一人真实撤离，第一 completed physics 的 process_frame 立刻 pause→request_capture→HELD→Session.save_held→正常退出 | safe事件/报告各1；root FIGHT；另一人live且两者root/active；safe actor隐藏/停止/ID原值；世代1 diskhead与packet/world全量SHA；该帧cache/grids原数据，不清空 |
| B_install_settle_resave | 新进程读同 slot；Session prepare→paused mount→commit_async；HELD全量比较；release，正常120 physics；再HELD保存世代2退出 | 原完整22 sections、packet/flags/settings/binding/refs/signals/UI、逻辑tick/clock合同；第一人未复活/未重放，另一人可行动，FIGHT持续；第二次world含自然cache更新但不得用A等值强求 |
| C_install_finish | 新进程装世代2，完整安装同B；只普通指令把另一人护送至EXIT，第一人保持退出；等待原 L8 win 与 ContinueFlow 完成终结 | second safe/报告仅1；daming_victory仅1；Phase.END；`ContinueFlow.last_result.ok && terminal_completed && local_terminal`；local lifecycle世代2 terminal/victorytrue；Campaign真实内存结果、文件未新增/未改；UI result来源同一Mission |
| D_read_terminal | 新进程仅读profile，不续建已终结场景；校验终结receipt和Campaign文件未变/未新增；实际prepare_restore应拒绝旧活动slot | LOCAL_RUN_TERMINAL受控拒绝；不建Battle/Unit；terminal receipt逐文件SHA与C一致；Campaign仍为C之前的持久基线；持久Campaign资格false |

B 的120物理步要用实际 `_run_clock._next_tick` 差和 Mission.elapsed 增量验证，`Engine.time_scale=1`、60Hz、Settings.game_speed=1；不用 `_physics_process(delta)`、快进或手动 Level.process。A首帧与B后120步两种时间截面分别保留，不将A早期缓存当垃圾修整。骨架观察 signal 会早于 safe event：**不得在 story_resolved signal 内 pause/save**，只能在已完成真实 physics 的 process_frame 观察所有一致条件。

## 胜利、终结和奖励的实际界限

恢复 Battle 的 `b.win` 先将 phase改END；有 `_continue_receipt` 时 ContinueFlow延迟到physics后，先 durable `terminal(victory)`，再 `_complete_end`。因此只看到 END、safe事件或 HUD 不足以表示保存/结算成功。正常等待 operation_finished/last_result；如果 terminal失败，只能保留失败并按原重试契约修复，不能再直接 `_complete_end`。

STEAM_DISABLED/CAMPAIGN_QA 下 run_id=0，SteamService.settle立即返回；本批**不能证明 Steam统计、成就或服务端奖励一次**。可证明本地内存Campaign核心clear/本局story目标集合、HUD首次印章条件（仅全原著目标实际达成时，不代表持久印章）、durable terminal封闭、防止旧slot再恢复，以及120自然步无新增内存结果。Campaign持久资格false；其best结果相同也不是 callback 调用计数。实际一次 `operation_finished` signal可观测，但不能扩称 `_complete_end` 或 Campaign callback调用次数。

终结前记录 Campaign.records/unlocked、SteamService.state.stats/unlocked 与Campaign文件存在性及SHA。终结后记录真实内存 result / UI / localreceipt / ContinueFlow结果，并检查Campaign文件未变；继续120自然processframes后结果/receipt/配置同值。Battle在END仍会更新部分物理缓存/单位过程，故不能要求logicaltick停止或全world不变；只审查终结副作用。D重新加载原Campaign基线和同terminal文件。额外重复 `b.win` 或 lifecycle.terminal 调用可以另列 idempotence API 子测，但不得混入“完全自然回调次数”声明。

## 五项关键负例：source与JSON两个边界

正 fixture 必须来自A真实HELD捕获。负例均新 sibling，single-leaf mutation，记录原fixtureSHA、指定路径、before/after typed编码、受控错误code、零SCRIPT ERROR；不得修改正批slot或回写被拒数据。

| 审查点 | 源 DTO / 实际对象负例 | JSON边界负例 |
| --- | --- | --- |
| `refs._queue` | safe actor Unit.references._queue放一个合法目标订单；原value中没有 `_queue`，不能改错层造假绿 | 用Codec完整decode→改references._queue→Codec re-encode；canonical JSON解析经Store严格validator/Core.prepare；排除只是错误codec结构导致拒绝 |
| 原停止字段 | 每项单独：_chase_intent≠CHASE_AUTO；_group_cap>0；_home≠position；_has_homefalse；_hua_lock_shots>0；另保留_path、mission意图、target/pending等已有负例 | 同样从真实typed Unit.payload中逐项改并re-encode；不能要求原resolve_story未保证的is_active=false/manual_order_active=false/garrisoned=false/_path_i=0/processflags |
| 另人 live/root/active | otheractor null；hp0+dyingtrue（内部寿命自洽）；story_outcome非空；从root_order删除；从active_order删除；安全者对应root/active删除也保留 | Level.references、UnitGraph结构及真实typedactor分别改；保持能通过前置一般schema的情况下完整配对拒绝；source与JSON两个同根语义负例 |
| selection/caster | safeID加Root.selection；safe actor selectedtrue；_ability_caster/_item_caster/channel caster/相关pendingcast之一引用安全者（格式仍合法） | 使用Root实际Identity编码，不能用裸字符串替代tag导致泛化格式错误；其他actor指向安全者的target/pending/hualock也保留已有验证 |
| identity畸形 | 5 records(UnitGraph/Level/Mission/Presentation/Root)所有固定schema/context/content/mission/presentation/version identity leaf逐一替换Array/Dictionary/null/bool/float；另wrong合法字符串/token | JSON.parse完整envelope后同类型替换；Core.prepare及实际Store document decoder分别受控拒绝；无unhandled比较或强转。统计每个真实identity路径，不能以“五records”代替实际枚举数 |

source路线应区分 (a) **pure source DTO validator**：固定完整Core.prepare前置记录与Unit合同、无实例；(b) **真实capture source拒绝**：每row独立私人进程从同一真实正状态出发，只暂改该被检查对象字段、原Core.capture应受控拒绝，不进保存。回滚用原typed值并验证原值无漂移；拒绝可能dispose retained identity时不重用旧identity。不能把(a)称为(b)。

JSON路线第一层Store._validate_json_document只负责现固定map所有权及document形状，不能声称它已执行完整Core逻辑；必须随后实际Core.prepare。为避免hash前置掩盖语义负例：fixture writer只给**新的负例文件**按原规范重新生成canonical body/hash/chain，或直接调用document JSON hook再Core.prepare，明确省略hash生产者资格。应同时保留canonical和NONCANONICAL `.0`原回归，不可覆盖旧负例。

要求reject发生于第一个B.new/Unit/tombstone之前：运行后确认adapter._battle==null/_unit_plan为空/未挂载且旧场景全量不变，加源码序列审计证明safe_pair位置先于B.new和graph.prepare。仅root child count不变不能证明没有创建detached Unit。若需要强运行时allocate计数，应使用明确外部观察构建并独立标注，不给生产script加假factory、不给原prepare增加绕过参数。

## producer与准入顺序

新一次性producer应 pin当前4项JSON修复 + v25两个candidate文件 + 路由/runner/scene/fixture/manifest SHA；copy既定完整runtime含来源`.import/.uid`，实际import后全身份仍完全匹配。顺序为preflight→自然等待共享Godot→冻结→import→profile_guard→原JSON11正/全负回归→原OwnedSlot故障事务suite→v25组件/负例→lu四进程→shi四进程→原gate/初态/admit/救出未撤离/普通死者及其他章classic回归。首次工程失败终止并保留负证据；新修复另新sibling，不盲重试、不控制别任务引擎。

报告必须分别列 passed/not_run/failed，`natural_victory_qualified`只由完整C+durable终结真结果置true；`steam_reward_once_qualified`始终false；`public_campaign_continue_qualified`始终false；`release_exe_qualified`始终false。没有运行的项目不写through、完成或资格。至少导出source identities、producer SHA、全部native logs、case reports、完整packet/world/clock/refs、终结本地文件hash、每种first_actor结果、留存失败路径。
