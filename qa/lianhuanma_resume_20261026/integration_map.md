# 连环马后续生产集成图（2026-10-26，只读结论）

基于当前 stable 生产与 `qa/campaign_progress_recovery_20261008/integrated_v4_r12/scripts/` 逐项对照。本文不授予运行资格；没有修改生产、冻结驱动或启动引擎。当前三进程训练切片仍由主线程执行，其结果不转授为以下事务链通过。

## 最小文件集合

本地战役 context 生命周期、可恢复 CFG 提交、live 结算一次性准入的最小集成是 **8 个新增组件 + 6 个现有文件的语义合并**。14 个文件只形成这一边界，不等于 Steam 奖励端到端保证。

| 新增到 `scripts/` | 必要职责与接线 |
| --- | --- |
| `run_campaign_progress_intent.gd` | `scope/validate/capture`：从真实 END Battle 和冻结 Mission 取得 context、owner、内容/引擎身份与结果；先把 `CONTRACTS.level1.version` 从候选 2 对齐当前 3。 |
| `run_campaign_local_lifecycle.gd` | `CampaignLifecycle.new(token, slot_root, context, identity, owner)`；active/gen1 → terminal pending/gen2 → applied/gen3；`prepare_resume`、`inspect_campaign_marker` 拒绝旧槽重开。 |
| `run_campaign_cfg_values.gd` | CFG 值域和独立语义摘要；保留未知配置键。 |
| `run_campaign_cfg_transaction.gd` | `begin_write/commit_prepared/retry_write/recover_pending`；原文件备份、候选安装、精确回读、保留待恢复写入。其 `OwnedRelease` 类已定义在本文件第470行，不需要为它修改基础 `run_snapshot_store.gd`。 |
| `run_campaign_progress_projection.gd` | `project`：只修改进度键，保留其它记录/偏好；单局最佳成绩，不跨局合并目标 ID。 |
| `run_campaign_progress_gate.gd` | 启动恢复完成且无 owned pending 时才允许后台偏好/云写入；同一个 Coordinator 持有重试权限。 |
| `run_campaign_progress_coordinator.gd` | `begin_live/retry/consume_live_completion`；恢复用 `begin_recovery`，只修进度，不重放 Battle、任务回调、metrics 或奖励。 |
| `run_campaign_startup_scan.gd` | `scan(identity, owner)` 只读扫描固定 `user://continue/v1/local_runs`；核对并交回待恢复事务，拒绝身份漂移。 |

| 当前生产文件/入口 | 最小语义合并范围 |
| --- | --- |
| `run_world_session.gd:60,144,182` | 加 `_new_local_receipt/_local_scope`；战役使用新 lifecycle，经典30波继续用原类。save 保持同 token/同槽 CAS；uncredited restore 在 Core 分配前校验，credited restore 增加同 token 的战役侧日志终局检查；最终 mount 前再检查。 |
| `battle.gd:411,456,4469,4483` | 将 barrier 的创建/配置放到真实 `_official_context` 分类之后；所有官方战役终局经 ContinueFlow/Coordinator，包括从未保存过的局。`_complete_end` 必须先消费一次性 claim，移除直接 `Campaign.on_level_won` 的重复进度路径，保留当前完整结果展示逻辑。 |
| `continue_flow.gd:23,144,260,380,397` | 加启动恢复、pending 错误/重试、战役 Coordinator 和 `claim_campaign_completion/can_launch`。战役 restore 使用 async commit。保留当前公开经典30波限制，只允许已有受隔离私有 QA 路径测试战役，不迁入 R12 的公开战役放行条件。 |
| `campaign.gd:162,176,251,255,284` | 普通战役进度改由 Coordinator 独占；偏好/云写入进入同一 CFG transaction 与 gate，加入 `progress_committed/retry_persistence/resume_pending_preferences`；保留失败 writer，不能降级为直接 `cfg.save`。 |
| `steam_cloud.gd:50,67,227,346` | attach/apply/flush/mirror/退出写入尊重 progress gate；保存原 owner、绑定 SHA、目标 payload 及 shared confirmation，失败后只重试原事务。必须与 Campaign/ContinueFlow 一起迁入，避免旁路写入破坏 CFG 原子恢复窗口。 |
| `menu.gd:31` | `_launch` 受 `ContinueFlow.can_launch()` 约束，启动恢复未完成不能开新局；保留候选的待启动重试逻辑。 |

## 必须处理的当前冲突

1. **黄泥冈 contract 2→3。** 当前 `levels/level1_huangnigang_short.gd:17` 返回 3，候选 Intent 第10行仍为 2。直接接入会在真实终局报 `CAMPAIGN_INTENT_CONTRACT_MISMATCH`。四个演义目标 ID 不变，八人全活仍是可选项，不增加“全活才通关”条件。
2. **不得覆盖七车新版存档。** 保留 `run_official_restore_profile.gd:25` 的 `campaign_level1_v2`、`run_unit_state.gd:12` 的 `level1_unit_state_v2`、当前 `huangnigang_transport.gd` 七原车/十一独立担与身份守恒，以及当前 `run_campaign_level_state` 的 `empty_cargo/force_attempts` 等字段。全局 `official_continue_slot_v1`、`official_world_core_preparation_v1` 不需为此次接线降版或泛化迁移；旧三担 profile 继续拒绝。14文件之外的这些现行组件是保留依赖，不从旧候选覆盖。
3. **完整 HUD 结果不能被缩成持久化投影。** R12 `consume_live_completion` 只返回6个 RESULT_FIELDS 加 `new_story_seal`；当前 `hud.gd:2900` 要读取 `goals`。`_complete_end` 应读取已经冻结的完整 `mission.result_snapshot(victory)`，逐个核对6个字段与 claim 一致，再附加 claim 的 `new_story_seal`。保留当前 `frozen_result`、报告行/英雄快照、`render_report` 与 `hud.show_end(..., frozen_result, render_report)`，不再写一次进度。
4. **不能整份替换 battle。** R12 会移除当前 `battle.gd:5973` 的 Esc `_input`，回退结算多语重绘、施恩/七星动作、地面范围圈和直立桩绘制。只迁 barrier、终局分派、claim 三处逻辑。
5. **不能无意开放入口。** 不迁入 R12 `_player_context_supported` 的全战役 return，也不放宽非私有 `request_save_exit/_restore` 到战役。启动恢复/普通新局终局仍须运行，公开“保存/继续战役”保持关闭。
6. **旧 lifecycle 明确拒绝。** 新 CampaignLifecycle 第43–45行将 classic schema 当战役读时返回 `LEGACY_CAMPAIGN_CONTEXT_UNBOUND`。当前自然训练切片产生的旧内部 token 只能作为原始证据保留；不能清 receipt、换槽或制造新 token 让旧档看似已迁移。新集成验证从独立全新 profile 开始，同一验证局全程保持同槽/token。
7. **固定槽根必须一致。** Coordinator 与 StartupScan 固定 `user://continue/v1`；现自然训练驱动使用 `user://lian_train/v1`，只能证明活动期切片，不能直接作为启动终局恢复消费者。新事务驱动必须使用实际固定生产根；不修改正在运行的旧驱动。

## 最小落地顺序与验收切口

1. 在当前生产上新增8组件并完成上述6文件语义合并，先核对 Intent 八章表与各章实际 `story_contract_version/story_goals`。这是一组相互依赖接线，不先提交一个会阻断普通终局或启动的半套版本。保持公开入口条件原样。
2. 冻结新的实际内容身份，重新导入；从新私有 profile 验证普通菜单启动、经典30波保存恢复、连环马正常付费训练 ABC。连环马此轮应记录新 context-bound lifecycle/gen1、实际固定槽根和 owner，旧活动期 ABC 的通过不得沿用。
3. 使用真实自然终局验证：live 同 token gen1→gen2→gen3；胜利 CFG 独立读回、失败不写胜利进度；同局重复 claim/重试不得再显示结算或调用 settle；terminal 后旧槽须在世界分配前拒绝。黄泥冈七车正常交付与有伤亡提前收队都要验证 contract3 接受、可选目标未达仍核心胜利及完整多语目标明细。
4. 在 gen2 后、CFG 备份/安装窗口、gen3 前分别做自有进程中断，再用独立进程走真实启动恢复/重试 UI。核对 pending owner/content/engine/token/intent SHA，不重播任务、metrics 或结算；偏好和云旁路不能覆盖 owned transaction。`CAMPAIGN_QA` 必须为空，候选 CFG 的 `begin_write/retry_write` 在其为1时明确拒绝持久化。

旧 `tools/run_campaign_natural_terminal_r12_bai_candidate.py` 固定旧14源、旧黄泥冈父关卡、旧 Core/Contract 和外部 bridge/baseline；不能直接作为本次执行命令，也不能以改 SHA 冒充原审查。后续从当前冻结源建立新消费者，沿用现 runner 的串行锁/profile/identity 机制，新增上述固定槽和终局阶段；待驱动具体生成后记录实际命令。

## 奖励与“原子”结论边界

R12 提供本地进度幂等、一次性 live completion；`run_campaign_cfg_transaction.gd:339–341` 明确只确认正常进程中断恢复，`power_loss_atomicity_qualified=false`、`external_uncooperative_writer_atomic_CAS=false`，不能称断电原子事务。

当前 `steam_service.gd:163–169` 的 `settle` 先内存 `queue_terminal`、再 deferred checkpoint；实际账本写入在 `steam_local_run_session.gd:62–71`。R12 gen3 后若进程在 Steam 持久终局前中断，启动恢复刻意 `settlement_authorized=false`，所以14文件**不足以证明奖励不漏发且不重发**。后续需以原 token 的持久账本交接补齐该窗口，涉及 Coordinator/ContinueFlow 与 `steam_service.gd`、`steam_local_run_session.gd` 的明确事务协议及真实 SDK 验收；不能靠启动时盲目重调 `settle`。本次建议先完成上述本地进度链，不将 gen3 或 Steam-disabled 结果表述为平台奖励已验收。
