# Steam receipt / outbox 最小持久化适配审查

2026-09-07；只读审查当前生产与两个已归档草案。本轮仅写本文件，未调用 Godot、Steam SDK，未运行测试或扫描资源。ROOT 通知生产基线为 `61f8f557cb19e5f6483f468ba3435767a2108584`；下列三个小文件本轮读取并核对原始 SHA-256。

| 输入（工程相对路径） | SHA-256 |
| --- | --- |
| `scripts/steam_service.gd` | `6948d2cf1678d1e91eef6c8c3644af336d8105d70977eac0221b5ed713a68998` |
| `tools/contracts/steam_run_receipt_draft_20260907/steam_run_receipt.gd.txt` | `acd21358de698c9a6c8e3806873439fe90abdc6ed3bc9b2a7153263de719cc66` |
| `tools/contracts/run_save_store_draft_20260906/run_save_store.gd.txt` | `86619f5cbf87e984ed253d66dddf2b852c8e11fe5e34d256c5a463bef16abca3` |

## 结论与阻断项

可以开始独立持久化宿主候选，但当前三部分直接拼接不能晋级。最小新增层是**账户独立、单写者的 receipt + outbox 同一事务记录**。它必须在第一条 SDK 写操作前持久化 `maybe_sent`，并在重启时先处理不确定发送，再允许新统计。

1. **发送前没有持久化屏障。** `SteamService` 79–104 行的初读在 91 行以 `setStatInt` 验证值，131–151 行 `_sync_state` 在 138、145 行直接写 SDK；只在 153–159 行包住 `storeStats` 已经太晚。91 行这项“读取自检”也应移出读取路径，不能绕过屏障。
2. **结果 8 的失效状态只有内存。** 161–176 行收到 8 后清 `stats_ready` / `_active_run`，但崩溃后仍可能读取旧 receipt 的高目标。纯模型 226–251 行确实能持久失效、保留 terminal token、精确校正；其前提是失效记录已落盘。8 回调已收到而该记录尚未落盘的窗口，必须由此前的 `maybe_sent` 覆盖，不能由 `max(local, server)` 解决。
3. **超时后回调可能错配。** 57–63 行 30 秒后清 `_store_busy`，后续可再次发送；161–166 行只检查 app/account，没有区分哪次请求。迟到的旧成功可能按新的 `_store_revision` 消掉新待办。最小版在未决期间禁止第二次发送；超时只改显示/恢复状态，不释放发送资格。
4. **旧战斗槽没有持久计数身份。** `battle.gd:14,401,2282,4337` 使用进程内整数 run id；`SteamService:107–115` 每次 begin 清 settled。当前 `record_kill` 接口也只表达“加一”，无法表示旧槽累计 10、账户最新已计到 20。新接口须接收持久 token 与累计合格击杀数。
5. **存储草案没有可直接生产使用的恢复接口。** `run_save_store:6,12–15,39–53` 仅允许测试目录与固定战斗槽名；153–160 行遇 pending / previous / lock 一律拒绝读；206–279 行保留失败残留。不能仅改目录常量就用于账户 receipt。新适配需独立名称、完整验证、CAS 与明确恢复计划。

官方语义核对：SetStat 修改 Steam 本地状态；StoreStats 之外，进程退出也可能提交尚未上传的修改。结果 8 会带回服务器修正值。因此屏障必须先于 SetStat/SetAchievement，而非仅先于 StoreStats。[Steamworks：SetStat / StoreStats](https://partner.steamgames.com/doc/api/ISteamUserStats#StoreStats)

## 最小记录与接口

归档草案保持不变；新候选在隔离目录复制并派生。持久记录与任何可回滚的 Battle 存档分开，受控账户目录由实时 AppID 与 SteamID 字符串生成，不能从存档路径拼接。初版不支持多机同时写、跨设备 receipt 回滚或自动清理历史 token。

```text
ReceiptEnvelope = {
  version, app_id, owner, store_revision, previous_file_sha256,
  receipt: <现有纯模型的完整已准备/已提交记录>,
  outbox: null | {
    attempt_id, receipt_generation, targets_sha256,
    stats, unlocked, phase: "maybe_sent" | "correction_required"
  }
}
```

`store_revision` 与模型 `generation` 分开：单独写 outbox / ack 也必须递增存储版本。字段完全白名单；版本、修订号、计数均为有限非负整数且设上限；owner 保持十进制字符串，token / attempt_id 固定格式。外层 hash、payload hash、模型准备 digest 各自验证，不能互相代替。目标快照冻结，禁止将后续 receipt 内容就地覆盖到已发送 attempt。

| 新层 | 最小接口 | 必须保证 |
| --- | --- | --- |
| 文件存储 | `open_owner(owner) -> verified_head / recovery_required / no_record` | 只读；完整 schema、owner、摘要验证；有残留不能偷偷回退 previous。 |
| 文件存储 | `commit(expected_revision, expected_file_sha, next) -> verified_head / recovery_required` | 单写者锁；重读 CAS；完整写入、关闭、回读；返回确切读取记录及摘要；失败不发 SDK。 |
| 文件存储 | `inspect_recovery(owner) -> plan / blocked`；`recover(plan, expected_inventory)` | 计划绑定各受控文件实际摘要；不删除未知文件，不覆盖非空目标，不把较旧 receipt 当最新恢复。 |
| 宿主事务队列 | `persist_proposal(prepared, expected_head)` | 同一写者序列内落盘后才调用模型 `commit`；写入期间不得再调用另一个 `prepare_*`（它会 abandon 旧 pending）。 |
| 宿主 | `begin_run(trusted_context) -> token / ineligible` | 实时 owner + 官方启动上下文；新 token 生成与 begin receipt 均成功持久化后才交 Battle。 |
| 宿主 | `resume_run(token, saved_total, trusted_context) -> eligible / ineligible` | 查最新账户 receipt 与 terminal/context；不新建 token 来补救旧槽。 |
| 宿主 | `record_progress(token, total_valid_kills)`；`settle(token, victory, trusted_result)` | 接纯模型已有 prepare 接口；先持久化再更新可发布目标。终局 receipt 成功写入后才算统计结算完成。 |
| SDK 接口 | `try_publish()`；`on_stored(app_id, result)` | 第一条 SDK 写前已持久化 maybe_sent；本进程唯一未决 attempt；回调只能确认该冻结快照。 |
| 恢复读取接口 | `start_authoritative_read(owner, epoch)`；`finish_authoritative_read(epoch, result)` | 绑定实时账户、AppID、当前会话/读取 epoch、存储 revision 与模型 generation；失败或陈旧返回不发布。 |

现有 `run_save_store` 可以借用 UTF-8、长度、envelope、摘要和完整验证逻辑，以及不覆盖非空目标的写入步骤。应新增 receipt 专用接口与文件名，保留原 fixture-only 草案。其 `flush` / readback 及可恢复重命名序列不构成已证明的断电原子性；报告按真实验证范围表述。

## 必须固定的状态流

### 正常发送与同进程回调

1. 从实时账户验证过的模型取 `publish_targets`。宿主处于 clean、无 pending / correction / residual，且没有未决 SDK 发送。
2. 将冻结目标和 `maybe_sent` 写入同一 envelope，回读验证成功；在此之前 SDK mutator 调用次数必须为 0。
3. 此后才允许 SetStat / SetAchievement / StoreStats。任一 mutator 失败或 StoreStats 返回 false 都保留 marker；已经写入 SDK 的其它字段不能因为 StoreStats 返回 false 而视作“绝对未发送”。不自动重试旧绝对目标。
4. StoreStats true 仅表示请求进入等待。等待期禁止下一批 SDK mutation / send。新的合格击杀可以继续写 receipt，但 outbox 的目标、attempt_id、receipt_generation 保持原值。
5. 结果 1 只确认冻结 outbox。先持久化清除该 outbox 的 ack，再考虑发布 receipt 中更高 generation 的后续进度。不能把当前最新 receipt 一并标成已确认；ack 落盘失败则保留本地屏障。
6. 结果 8 立即在内存关闭发布与当前局资格；将 receipt 的 `requires_correction=true`、所有旧 token terminal、outbox `correction_required` 一起持久化。失败时此前 maybe_sent 仍必须存在，不能先清它。
7. 在已持久化失效之后读取并验证修正值，调用 `prepare_server_correction`，以一次事务精确替换目标并清 outbox。保留全部 terminal token；不 max 合并，不根据旧目标重新 evaluate 解锁。普通 `prepare_remote_floor` 只能走明确 clean 的正常初读路径。

`UserStatsStored_t` 仅提供 game id 与 result，没有应用自定义 attempt id；其它相关接口也可能产生该回调。宿主只允许一个发送源，不调用未纳入 outbox 的统计发布接口。无对应本地未决发送的成功回调不能清待办；同 app 的未归属结果 8 应关闭发布并进入校正检查，不能当普通成功或忽略后继续上传。[Steamworks：UserStatsStored_t](https://partner.steamgames.com/doc/api/ISteamUserStats#UserStatsStored_t)

### 重启及“结果 8 已收到、失效尚未落盘”的窗口

加载到 maybe_sent 就必须认为发送结果不确定。它覆盖以下三种不可仅凭本地文件区分的情况：尚未真正调用 SDK；已接受但成功 ack 未落盘；已返回 8 但失效记录未落盘。**不能把重启后读到的数值与发送目标相等，当成服务端已经确认该 attempt 的证明。**

最小保守恢复：先把该 envelope 转为持久 correction_required 并终止旧 token；保持游戏可玩但统计不合格；取得有证据的服务器新读后执行 exact 校正。尚未确认且服务器未包含的本地进度可能丢失，这是该最小策略的明确代价。若要求同时保证“不重复且不丢任何未确认增量”，仅凭当前 Steam 绝对统计接口与本地文件无法证明，不能包装为已实现 exactly-once。

RequestUserStats 文档描述从服务器异步下载指定用户；UserStatsReceived 回调带用户与 AppID。当前 SteamService 没有该读取流程。实际所用 GodotSteam 对本账号读取缓存、信号关联与在线失败的行为必须另做适配验证；单纯启动 `getStatInt`、或已废弃 RequestCurrentStats 的立即返回，不能充当已完成的权威读取。能力未证实、离线或回调身份不符时保持失败关闭。[Steamworks：RequestUserStats](https://partner.steamgames.com/doc/api/ISteamUserStats#RequestUserStats)

### 存储残留恢复

最小自动恢复仅允许存在唯一可验证事务链：完整 schema + owner + payload/hash、连续 store_revision、previous_file_sha256 与受控原始文件吻合。最高数值本身不是充分条件。正常旧槽与有效新 pending / slot 的唯一链可以完成向前提交；任何发布相关残留仍按未决/校正处理。

如果有坏文件、两个不同同版本 head、未知锁 owner、链断裂或其它外部变化，保持原文件并返回 blocked；禁止为了恢复游戏统计而回退较旧 receipt。锁只在确认没有存活持有者且 plan 的文件摘要仍相同时处理。`new_verified` 但 cleanup 失败不能当 clean：现有草案 215–218、267–273 行会留下受控残留，需要上述恢复接口先完成收尾。

### 旧存档与累计计数

账户 receipt 已记录 token A 的 credited_kills=20，旧 Battle 槽保留 A 与 cumulative=10：恢复检查资格成功后，将每次真实合格击杀后的累计 11…20 传给 `prepare_progress`，增量均为 0；到 21 只增 1。不要按 `max(saved_total, credited_total)` 改写 Battle 的累计计数，否则旧槽第一杀就变成 21 并重复记入。

新的 `total_valid_kills` 应独立保存并只在原有 `Phase.FIGHT` 合格路径递增；现有 `kills` 在 `battle.gd:2279–2282` 中先于 phase 判断增加，不能未经核对直接替代。旧 Battle 槽无 token、owner/context 不匹配、最新 receipt 缺失/损坏、token terminal 时允许纯游戏恢复但统计不合格；不重建旧 token、不复制旧 receipt、不为旧局自动 mint 新 token。合法新局可以在新权威初读及新 begin 持久化后单独取得资格。

终局重复/重启回放由 terminal tombstone 拦截。若 Battle 的终局标记先于 receipt 成功持久化，且重启不再调用 settle，仍可能漏记：宿主必须保留可重试的同 token 结算请求，直到 receipt 已有 terminal；Battle 存档不能成为“已统计成功”的唯一事实。纯模型 MAX_RUNS=10000 / generation 上限保留失败关闭，首版不删除 tombstone 绕过上限。

## 下一批故障测试（候选要求，尚未执行）

使用假 SDK 与真实私有目录先测；计数假 SDK 所有调用并留原始日志。崩溃测试使用被测试进程主动发 checkpoint，由外部驱动杀其真实 PID 后重新启动。不能用同进程重建对象或正常退出代替所有崩溃窗口。

| 组 | 明确断点/反例 | 必须验收 |
| --- | --- | --- |
| 发送屏障 | prepare 后、pending 写一半、pending 完整、旧文件移走、新 slot 回读前；以及首条 SetStat 前 | marker 未验证前 SDK mutation=0；残留拒绝发布；受控恢复不回退最新计数。 |
| SDK 部分写入 | 第一项 SetStat 成功第二项失败；SetAchievement 成功后 StoreStats=false；退出自动提交由假 SDK 模拟 | 所有路径 marker 保留；重启不重发旧快照，不声称 false 等于无副作用。 |
| 结果 8 窗口 | SDK 回调 8 后、调用 prepare_invalidation 前；prepared 后、写失效前；失效写完但内存 commit 前 | 重启仍看到 maybe_sent 或 correction_required；SDK 写为 0；旧 token 不重获资格；exact 校正后旧高目标不复活。 |
| 成功窗口 | SDK 已接收但回调未到；结果 1 后 ack 写入前/中/后 | 未确认重启保守处理；已持久 ack 可正常恢复；不能凭相等数值伪造 ack。 |
| 正在发送时的新进度 | attempt generation G 发送后，本地进度写到 G+1，再接收结果 1 | 只清 G 的 attempt；G+1 仍需新的持久 marker 才能发布；结果 8 则关闭旧 token 全部后续资格。 |
| 回调归属 | 超时后晚到成功；重复回调；无 pending 成功；旧会话/错误 AppID/更换账户回调；无归属 8 | 无第二批并发发送；不清其它 attempt；错误身份不改目标；同 app 8 不能继续旧发布。 |
| 权威读取 | 启动缓存高于服务器、离线、失败、错误 owner/app、旧 epoch/revision；读取期间本地写者推进 | 未验证不校正不发布；陈旧读取拒绝；新读精确替换，不 max/重新 evaluate 被拒旧目标。 |
| 旧槽 | HWM20 + Battle10 回放到20/21；terminal重复 settle；无token/未知token/错误context/owner | 分别 +0/+1；终局 once；不合格槽不生成新 token。 |
| 终局事务 | 终局 receipt 写前/后崩溃，Battle 槽终局标记前/后重启 | 以同 token 重试到 terminal；不能因局部标记漏记或重复。 |
| 文件恢复 | slot/previous/pending 各阶段；坏/截断 UTF-8、错误长度/hash、同版本分叉、链断裂、外部替换、活锁、符号链接 | 原始证据保留；CAS 拒绝；不抢活锁、不越界、不选择较旧 receipt 发布；唯一链才向前恢复。 |
| 数值/schema | JSON `20.0` 合法；负数、小数、bool、NaN/Inf、LIMIT+1 非法；SteamID 字符串精度；多字段/缺字段；MAX_RUNS/LIMIT | 保留模型现有完整验证；外层同样严格；达到上限拒绝，不能删 tombstone 或整数回绕。 |

实施次序：先做完整 envelope validator + 账户私有存储/CAS/恢复；再做假 SDK 宿主与上述崩溃矩阵；然后新增 Battle token / 合格累计字段及恢复资格；最后验证真实 GodotSteam 权威读和回调行为，再由 ROOT 决定生产接入。纯模型已有测试和磁盘草案已有测试各自保留，不能相加后声称跨 SDK 崩溃链已经通过。
