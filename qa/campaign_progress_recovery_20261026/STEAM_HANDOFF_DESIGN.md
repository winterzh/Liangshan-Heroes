# 战役终局到 Steam 本地账本的可靠交接

2026-10-26。只读设计；本文所列新字段/API **尚未实现**。生产、当前14文件候选、运行驱动均未修改，未启动引擎。本设计补齐的目标是：同一合法 credited run 在正常进程中断与重试后，最终形成一次本地奖励结算，再由现有绝对目标发布器同步；既不能重复累计，也不能在 gen3 后丢失尚未写入的结算。

## 1. 现在的缺口与可复用能力

| 已核对源码 | 实际行为与影响 |
| --- | --- |
| 候选 `run_campaign_progress_coordinator.gd:158–201`、`continue_flow.gd:450–492` | 先 CFG、gen3 ACK，再消费 live completion 并调用 Battle。gen3 后中断会使启动扫描把它视作历史。 |
| `scripts/steam_service.gd:163–169`、`steam_local_run_session.gd:55–73` | `settle()` 仅 `queue_terminal()` 后 deferred checkpoint；内存排队不是持久完成。`queue_terminal` 重复时也不比较结果。 |
| `scripts/steam_run_receipt.gd:13–17,192–209` | VERSION=2；run只有 context、credited_kills、terminal、victory。`ALREADY_TERMINAL` 在比较本次结果前返回，不能作为精确交接凭据。 |
| 同文件 `226–251` | invalidation 将全部 run 置 terminal；correction 覆盖统计并清全局标记，却保留 run。正常失败与纠正墓碑可能完全同形，没有终局来源或持久 result。 |
| `scripts/steam_local_run_session.gd:6,78–86` | 实际 binding 六字段为 kind/owner/token/credited_kills/generation/receipt_sha256。`binding(total,context)` 会 observe、checkpoint、can_resume，能得到真实持久击杀高水位。 |
| `scripts/steam_service.gd:356–363` | `_persistent_binding` 核对真实活动 handle、context、SDK账号和 stats_ready。调用方必须传 `battle._steam_valid_kills`，不是普通 `kills`。 |
| `scripts/steam_run_ledger.gd:17–78,91–107` | 底层已有锁、CAS、持久回读和模型提交；但 `_persist` 写入/释放失败会置 `_fault=true`，目前没有原对象继续重试的接口。 |
| `scripts/run_snapshot_store.gd:233–291` | 可复用 `inspect_owned_commit/retry_owned_commit`，只重试原 proposal、原 revision/SHA、原锁身份；进程死亡另走 `inspect_recovery/recover`。 |

修复不能只是把 gen3 后的 checkpoint 改成同步。**必须把精确 Steam 本地终局持久回读移到 gen3 之前，并让 gen2 重启恢复可以完成这一数据事务。**

## 2. 必须成立的不变量

```text
真实 END 与身份/资格冻结
  → campaign gen2(pending, immutable intent including credit)
  → campaign.cfg 提交及独立回读（失败局无胜利进度写入）
  → 同 token Steam 本地终局提交及精确回读（uncredited 为明确 no-op）
  → campaign gen3(applied, CFG proof + Steam-local proof)
  → live 仅一次 UI/metrics 展示；SDK按持久绝对目标重试
```

- gen3 的含义变为“本地进度及本地奖励交接均完成”；它仍不是 Steam 服务器已确认的凭据。
- 任意 gen2 窗口中断后，独立进程沿同一个冻结 intent/token 重试；两侧均幂等。已经写入账本但未写 gen3 时，只核对精确结果，不再次累计。
- 重启恢复不得创建 Battle/Mission、调用 `begin_run/install_prepared/on_level_won/finish_metrics/_complete_end` 或补放 UI。不重新生成 token，不从全局胜场或成就已亮推断该 run 已结算。
- 当前账号不同、权威纠正、来源/内容/引擎漂移、记录损坏、凭据缺失时，明确保留 pending 并拒绝授予成功；不得降级为 uncredited 来绕过。

## 3. gen2 要冻结的受信数据

建议新 `campaign_progress_intent_v2` 在当前严格字段集上增加 `credit`，新 `local_campaign_continue_lifecycle_v3` 用该 intent。其它字段继续包含 token、context、profile_id、profile owner、content_version、engine_sha256、victory 及六字段 result。结果仍由真实 Mission 冻结，不能由测试或调用者拼造。

`credit` 为严格 tagged union：

| 类型 | 固定字段 | 唯一合法来源 |
| --- | --- | --- |
| uncredited | `{kind:"uncredited"}` | 真实 Battle 在此局启动/恢复时未取得 credited handle，且不存在矛盾的已授信 Steam lineage。Steam后来可用不能追授本局资格。 |
| steam | `{kind:"steam", binding:<实际六字段binding>, correction_epoch:<int>}` | 真实 SteamService、其真实 LocalRunSession 与当前账号的最新持久账本；不能读取slot字段后自行认定可信。 |

credited 冻结顺序：在 END、非physics、无新局/账号切换/并发写入的保留事务下，检查真实脚本/当前 Battle/活动 handle/token/context；`Campaign.cloud_owner` 必须与真实 SDK owner 一致（未完成绑定先走现有绑定事务，不能临时改 owner）。调用 `_persistent_binding(handle, actual_context, battle._steam_valid_kills)`，独立 capture 后核对六字段与 run，再冻结新的 `correction_epoch`。

binding 中 `credited_kills` 就是最终高水位：checkpoint 后已不小于真实 `_steam_valid_kills` 或恢复前已记入值；不能用较早世界快照回退它。`generation` 是 Steam **文档代际**，不是 lifecycle gen1/2/3，也不是 snapshot envelope revision（现有 Steam store 为 document generation + 1）。所有数值做严格非负有界整数校验。

顶层 token/context/owner 与 binding/实际 run 必须一致；binding.kind 固定 steam、hash固定64小写十六进制。规范化字段后从可信实现计算 `intent_sha256`，不接受调用者提供的摘要作为真相。既有 CFG intent hash 同步覆盖新 credit 字段；账本最终SHA放在 ACK 中，避免 intent 自引用。

## 4. Steam 账本 v3 与新纯数据 API

建议 `steam_run_receipt` VERSION=3：根增加单调 `correction_epoch`；run保留原四字段，并增加 `terminal_reason` 与 `settlement`。来源至少区分 active、normal settlement、server invalidated、legacy unknown terminal。正常非战役结算也必须写明来源，不能与战役交接混淆。

新战役 `settlement` 固定保存协议名 `campaign_steam_handoff_v1`、规范 intent SHA、冻结六字段 result、最终 credited_kills、victory 和当时 correction_epoch；owner/token/context 由该记录根与 run 键取得并纳入摘要校验。可以同时保存模型自算的 descriptor SHA，但不能只保存调用者输入的哈希。

需要新增的接口（名称为建议，调用契约为必须）：

| 层 | API与职责 |
| --- | --- |
| Receipt纯模型 | `prepare_campaign_handoff(normalized_intent)`：校验owner/token/context/epoch/结果与真实账本。active run在**一个proposal**内把最终击杀增量、胜败奖励、终局来源与descriptor写入；相同已结算descriptor返回 `EXACT_HANDOFF_ALREADY_APPLIED`；其它terminal、摘要/胜败/高水位不同均拒绝。 |
| Ledger | `apply_campaign_handoff(intent)` 与 `retry_campaign_handoff()`：持有原proposal/CAS/锁直到模型提交及释放确认；成功或精确幂等命中后重新开头读回，核对run descriptor、epoch、结果、owner/context/token，返回持久proof。 |
| LocalRunSession | `apply_campaign_handoff(intent)`：操作已打开的真实账号ledger；无需活动 `_token`、不安装任何 Battle。新进程 `open()` 后 `_token` 为空，因此不能复用旧 `queue_terminal()` 或借 `install_prepared()`伪装恢复。 |
| SteamService | `capture_campaign_credit(battle)`、`commit_campaign_handoff(intent)`、`retry_campaign_handoff()`：所有入口核对实际service/当前SDK账号、ledger持有者、固定生产根、correction状态和保留scope。live与startup均可调用数据交接，不生成新的run。 |
| Coordinator/Lifecycle | 新增 `steam_handoff` stage，位于CFG后、ACK前；ACK v2包含CFG proof及Steam-local proof。`ack_progress` 重新验证两者后才写gen3。 |

对相同token的幂等命中，必须读到 `terminal_reason=normal settlement` 且本协议descriptor逐字段一致、epoch未变、requires_correction=false；单个 `terminal=true`、victory相同、`ALREADY_TERMINAL` 或“全局胜场至少够大”均不足。高水位大于冻结值也视为scope漂移，不擅自扩展冻结intent。

proof至少包含协议名、owner/token/context、intent SHA、descriptor SHA、correction_epoch、当前Steam文档generation和文件SHA。同一ACK前必须精确回读；以后正常新局/偏好导致整体文件更新，旧SHA只是历史收据，不要求最新账本永久等于旧文件。后验依靠该token保留的descriptor与epoch，不能因后来其它run增加全局数值而再奖一次。

live交接成功后应把 LocalRunSession 内存状态同步为已结算、清除该run的旧pending，更新Service从账本种出的绝对targets。战役 `_complete_end` 消费claim后只展示，不再调用通用 `SteamService.settle()`重走业务结算；可调用仅刷新绝对targets的接口。经典防守/AI现有结算路径保留并按账本v3验证。

## 5. 重试、启动与发布时序

当前 Ledger 的 `_fault=true` 不能直接清掉重试。新增handoff保留 `{expected_revision, expected_sha, proposal.record, proposal.sha256, owned phase}`；不要在返回失败后重新prepare。使用 `retry_owned_commit` 完成原写入、确认模型恰好commit一次，再完成释放；release失败也保留阶段，不能重新加奖励。CAS/锁身份丢失、半写损坏按unsafe拒绝，不强夺锁；只有原PID确认死亡后新进程做底层恢复。

启动顺序需分开“只读SDK身份/统计快照”“账号ledger打开/恢复”“SDK发布”：

1. 只读扫描CFG/lifecycle pending及其绑定账号；取得当前真实SDK账号。账号不符或暂不可用时显示待确认并允许安全退出/重试，不能访问另一账号目录。
2. 对引用的credited journal必须要求对应ledger已存在；不得让现 `_open_persistent_runs` 在丢失账本时自动seed空账本掩盖缺失。正常新账号、没有任何交接引用时才可创建。
3. 使用当前service唯一ledger持有者恢复底层待写记录；只读确认/必要显式schema升级。完成gen2的CFG与handoff，再gen3。不得创建第二个同账号独立写者。
4. gen3本身也应验证其credited proof对应账本存在且token有精确交接凭据；缺失/未知不能作为“已完成奖励”悄悄跳过。它无需重新累加，只确认持久链。
5. 全部启动事务确认后才允许新局、后台Campaign/Cloud写入、`_import_legacy`及Steam绝对targets发布。当前 `_read_initial_state` 会较早调用legacy import与publisher，必须接入此门闩；handoff恢复专用内部路径不能因发布门闩而死锁。

普通失败重试保留同一个live Coordinator/descriptor；不同进程只依赖验证过的gen2和账本，不依赖消失的内存handle。到gen3才释放live completion；重启完成gen3返回 `settlement_authorized=false`，但 `steam_local_handoff_complete=true`，两者含义不可混淆。

SDK仍发布持久账本的绝对统计与解锁目标；进程在gen3后、发SDK前退出，下次启动从账本继续发布，不再丢失本次目标。`user_stats_stored` 没有可关联本次run的请求ID，不得用它删除本地凭据或宣称确认某一generation。真实平台完成须再用 `SteamStatsReader.request/poll` 的实际owner/handle/source快照确认目标，并保留本地proof。

## 6. 账号纠正与旧schema

- 收到需纠正事件时立即阻止发布/交接；将 `correction_epoch` 增一并持久写入 `requires_correction`，相关run标为server invalidated，保留原descriptor作审计。authoritative correction保留epoch和墓碑来源，不将旧token重新变active。
- gen2中的旧epoch、server invalidated、legacy unknown terminal不能被 `EXACT_HANDOFF_ALREADY_APPLIED` 接受。正常胜利也不能绕过后续权威纠正重奖。UI应明确“账号状态已纠正，交接未获确认”，而不是将其算作通过或自动降级；已有CFG进度与平台奖励状态分别保留。
- v2账本须按原schema原样读取；不能在validator中默默补字段，`run_snapshot_store.gd:108` 会检查原payload canonical JSON。通过一次显式的新代际事务升级到v3，保留owner/计数/解锁/所有token。旧active可标active；旧terminal一律legacy unknown，不能推断正常结算或纠正来源。v2 requires_correction必须先保持纠正障碍，不以升级清掉。
- 新实现同时保留严格v2历史reader与v3 reader，升级写入v3并验证完整前后链；旧程序不能回写v3。文档版本与文件envelope版本分开，不复用旧schema名承载新字段。
- lifecycle v2/Intent v1的pending缺少credit信息，返回明确 `LEGACY_CAMPAIGN_HANDOFF_UNBOUND`；不根据owner非空、token存在与否或旧Steam ledger猜资格。旧已applied记录可保留为历史，但不得授予新交接资格或盲目补奖。现有classic生命周期不变。
- 涉及旧slot/profile/content identity的拒绝保持不变，尤其黄泥冈旧三担与当前七车v2/contract3；本协议不是通用旧档迁移器。若未来要迁移旧active内部档，须另有可验证原始credited证据和显式迁移规则，不在本轮偷偷换槽/换token。

## 7. 最小实现文件范围

新增/改动应独立作为下一候选批，不能改正在验证的14文件快照：

- `run_campaign_progress_intent`、`run_campaign_local_lifecycle`、`run_campaign_progress_coordinator`、`run_campaign_startup_scan`：credit/ACK schema、handoff阶段、启动proof检查。
- `steam_run_receipt`、`steam_receipt_store`、`steam_run_ledger`：v2严格历史读取与显式v3升级、原子handoff模型、保留原proposal重试和精确proof。
- `steam_local_run_session`、`steam_service`：可信capture、无Battle恢复API、内存同步、启动/发布/legacy-import门闩和纠正epoch处理。
- `continue_flow`、`battle`：错误重试状态及UI/metrics单次消费；战役不再第二次排队settle。`run_world_session`仅在binding/schema兼容需要时做最小适配，不改七车/训练/世界恢复语义。

目录上限256与Steam run上限10000仍需单独的凭据保留/退役设计，不能为了解除上限删除尚承担幂等凭据的token。

## 8. 必须覆盖的故障点与完成标准

| 故障/场景 | 独立进程后的必需结果 |
| --- | --- |
| gen2刚落盘，CFG之前 | 同intent恢复CFG和账本，然后gen3；一次胜场/演义结算。 |
| CFG备份/安装/回读窗口 | 恢复原CFG事务，不换intent；handoff最终一次。 |
| ledger proposal写入前、pending验证后、rename后 | 精确owned retry或死PID恢复；不可产生第二token或第二累计。 |
| ledger已回读、gen3之前 | 精确descriptor幂等命中，补gen3，胜场/击杀不再增加。 |
| gen3后、live claim/UI之前 | 重启不播UI/metrics，但账本奖励已存在且能继续SDK发布。 |
| gen3后、SDK发布前；SDK写入后、本地未收到成功 | 重启发布相同绝对targets；真实读回最终满足目标，不能再记第二次run。 |
| 活进程写入/释放失败后点击真实重试 | 使用原proposal/锁；成功后至多一次model commit/一次展示。 |
| 同token不同victory/result/高水位/intent SHA | 明确冲突，原账本与gen2不变，不能ALREADY_TERMINAL成功。 |
| 账号改变、不同profile owner、内容/引擎改变 | 保留原事务并拒绝交接，不访问/写入错误账号。 |
| correction在gen2后、ledger后gen3前、gen3之后 | 旧epoch/墓碑不会假冒成功或被重新奖励；权威纠正状态明确报告。 |
| v2正常失败与纠正墓碑相同字段；v2升级中断 | 不猜终局来源；升级恢复同一原始链，旧未知结果不被确认为精确handoff。 |
| 较早世界恢复，持久击杀高水位更高 | 冻结真实持久最大值；只加尚未记入增量，不能回退或重算旧击杀。 |
| 正常失败局、uncredited/Steam-disabled局 | 有明确no-op/失败终局凭据，不增加胜场/演义奖励，不冒称credited验证。 |
| 缺失ledger、伪造descriptor、锁/CAS漂移、截断记录 | 失败保留；不seed替代账本、不重建token、不放宽校验。 |

完成报告分开给出本地handoff与真实SDK读回。模型/故障测试可以证明本地幂等机制，不能替代真实账号/SDK证据。完整资格要求普通正常路线、上述中断收敛、真实错误UI重试、同账号独立进程及受控真实SDK前后读回；不能仅证明“不重发”而留下gen3后漏发窗口。权威服务器纠正与跨设备并发属于不同边界，不能把服务端明确撤销的奖励当作客户端应强行重发的任务，也不从单机事务推导跨设备全局事务保证。
