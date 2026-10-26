# Steam 账本底座候选

本说明覆盖 handoff 候选的 Receipt/Store/Ledger 底座及其上层接口；候选尚未采用到生产。当前冻结为 `20261026_194542_27c8aea9`，源码身份为 `source-v1:23c0b07fcba83a9d7938ed338a9775559b6041be61d048db619c31fd5edc2a80`，已成功导入。验证边界见文末，不把候选或模型通过当作完整恢复验收。

## 已实现

- Receipt v2与v3分开严格验证。v2读取保持原schema；只有 `prepare_upgrade()` 的新一代事务会增加v3字段。旧terminal统一标记 `legacy_unknown`，不猜测正常结算。新建账本直接v3。
- v3增加 `correction_epoch`、每run的 `terminal_reason` 与 `settlement`。新纠正事件增加一次epoch，将run标为invalidated并保留既有descriptor；authoritative correction不清除这些身份信息。旧epoch和墓碑不能充当交接成功。
- `prepare_campaign_handoff()` 在单一proposal里写入最终击杀差额、胜败奖励及精确descriptor。相同descriptor重试不改变代际或累计；其它结果/来源/高水位拒绝。原classic统计与普通重复结算行为保留，但宽泛ALREADY_TERMINAL不授予handoff proof。
- Ledger保留原proposal、预期revision/SHA、事务kind、handoff、写入/模型提交/释放阶段。使用既有Store的owned retry；失败不会重新prepare或再加奖励。Store的OwnedRelease保留“原owner文件已移除但空目录尚未移除”的本对象证据，支持同对象继续释放。
- proof必须重新读回当前账本头，并验证模型中的精确run descriptor；它不是SDK成功确认。

## 上层接口（已落代码）

`Ledger.open(account, stats, unlocked, root_path, require_existing=false)` 兼容原四参数；新增可选末参数确保有credited引用时缺失/恢复后代际0不会seed空账本。`retry_open()`冻结原账号、物理目录、初始targets与require_existing，前置失败保留同一Store继续初始化/读取/恢复，创建proposal已有pending时只续原写入。旧账本成功时返回 `upgrade_required=true`；上层在首次正常写事件前调用 `upgrade()`。不要把v2读取成功当已升级。升级失败可用同对象 `retry_pending()` 或 `upgrade()` 重试；不可换对象、token或proposal掩盖pending。

`apply_campaign_handoff(h)`、`retry_campaign_handoff(h=null)`、`campaign_handoff_proof(h)` 接受以下严格12字段对象：

```text
schema = campaign_steam_handoff_v1
owner, token, context, intent_sha256, correction_epoch
basis_generation, basis_sha256, basis_credited_kills, final_credited_kills
victory, result
```

`result`严格为 `core_cleared/story_complete/story_done/story_total/done_ids/contract_version`。所有hash为64位小写十六进制，context必须campaign，token为32位小写十六进制。上层先校验真实Mission/章节契约与gen2 intent；底座验证数据域、owner/run/context/epoch/高水位及稳定摘要。生产可信capture已先checkpoint最终击杀，因此上层映射通常为 `basis_credited_kills == final_credited_kills == credit.binding.credited_kills`；底座亦支持同proposal内补最后尚未记入的击杀差额。

只有basis与当前账本代际相同时要求当前文件SHA精确相等；较新头须保留同run身份、高水位、epoch，并由上层持有原始gen2受信descriptor。不能拿任意输入SHA当授信证明。

成功外层严格为 `{ok, code, proof}`；proof严格9字段：

```text
schema = campaign_steam_handoff_proof_v1
owner, token, context, intent_sha256, descriptor_sha256, correction_epoch
ledger_document_generation, ledger_file_sha256
```

`pending_status()` 只读返回pending/kind/phase/owned_lock/原CAS/handoff/错误；kind为upgrade、other或handoff。`retry_campaign_handoff()`拒绝非handoff pending；传h时必须与原h完全一致。`apply_campaign_handoff()`遇到任何不同h或不同kind时也拒绝。`retry_pending()`仅继续已保留写入，handoff成功时仍返回精确proof。

Ledger在pending时拒绝其它写入。因此Service收到账号纠正事件应立即停止发布及gen3 ACK，保留该纠正请求，等原写入安全确认后先持久invalidate；不能丢弃NOT_READY，也不能让纠正事件修改原handoff proposal。

## 检查与尚未验证

新冻结的[模型批次 20261026_195458_c880fc60](../../../.godot/campaign_progress_handoff_model_20261026/20261026_195458_c880fc60/receipt.json)已终态：99项全部通过、退出0，`receipt.complete=true`、`final_identity_passed=true`。`tests/receipt_model.gd::run_all()` 是无账本文件/SDK/Battle操作的合成模型检查，覆盖单proposal、精确重试、v2升级、纠正墓碑、classic行为，以及LC/Receipt JSON往返的规范字节和proof严格拒绝反例。它没有授予真实账号、存档或SDK资格。

本次相对旧源的4文件修订是：`run_campaign_local_lifecycle.gd` 与 `run_campaign_progress_intent.gd` 先规范化Intent/proof context再校验ACK，并输出规范ACK；`steam_run_receipt.gd` 用规范run校验嵌套settlement，且epoch>0的远端合并不重新推导被纠正的成就；`steam_local_run_session.gd` 处理旧批重试后新增击杀/终局的双批尾账。这些实现仍需相应原生文件事务与上层接线验收。

此前75项与135项通过记录属于旧源码 `811c0a12f05f7f380fb469e0ef6cf961298c59b054eafb6e3b0f349817869aa4`，不能算本次新源通过。[原32项静态报告](static_audit_steam_ledger.json)和[source_manifest_steam_ledger.json](source_manifest_steam_ledger.json)保留最初切片的历史SHA；没有改写成新字节的审查收据，也不能替代本次验收。

当前尚无原生I/O专项全通过、真实SDK或完整61阶段资格。未知/损坏锁、scope/CAS变化、半pending和缺owner的孤立writing仍fail closed。OwnedRelease仅能凭本对象保留的证据继续释放；进程死亡后的旧无标记空锁不能自动认领或删除。释放标记、staging、恢复所有权及真实I/O复验属于[后继设计](STORE_RECOVERY_NEXT.md)，尚未实现；不修改已固定测试的通过条件来掩盖缺口。

模型结果仍受int32计数上限约束；正常进程回读不证明断电原子性。真实Steam服务器读回及上层gen2→CFG→ledger→gen3链由主线程独立验收。

## 真实文件专项补充

同一23c源的`20261026_200759_741207e6`已完成9案例/13阶段、178项已完成worker断言，source/engine/worker前后pin通过。真实WRITE_OPEN、两种LOCK_RELEASE可用原proposal重试，闭合pending/已rename记录在原PID终止后可独立恢复；半pending和缺owner空目录保持原文件并拒绝，不称为已恢复。[完整证据和边界](../evidence/handoff_io_20261026_200759/summary.json)。本专项使用合成账号，无SDK或真实玩家资格。

同源黄泥冈`20261026_201649_979e4211`两进程1333+53=1386项通过，实际普通酒计终局保留原token，完成gen2→CFG→未记账proof→gen3，独立重启拒绝旧活动槽且原CFG/记录/奖励不增长。验证包含实际四语界面断言；未记账路径不授予真实Steam账号/SDK或全61阶段资格。
