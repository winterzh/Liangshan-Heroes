# C：自然高俅终局的同事务重试与独立重启

准备时本目录只交付外部 QA 代码、契约与来源绑定；尚未取得本片脚本加载、实际故障、四进程或自然终局重试通过资格。后续资格必须引用完整新运行收据。本片不修改固定工程，也不修改已经封口的高俅、UI 保存、B1 或 B2 工具。

固定工程为 .godot/campaign_progress_recovery_20261026/20261027_075456_3e4a48ab/project，身份 source-v1:b22f76f7bf4b8309f9257829364f4afdd6c9262282a25cb6aefacce5aa916132。执行须通过 integration_3365/prepare_projectile.py 的完整新源与自身首次冷导入准入，26 个脚本、1 个 native 输入，cold_import_qualified=true。默认仅检查命名小输入，不建 profile、不启动引擎、不扫描完整资源树。

## 保留原四进程自然流程

A save_after_wave1：从真实菜单启动高俅，正常 1x/60Hz 与普通游戏命令，保留原波次派发时仍活、第一波自然清场等门槛；后两波未派发时通过真实 SaveAndExit 保存 slot gen1，生产 AppLifecycle 以 continue_saved 退出。

B resume_core_save：独立 Continue 还原 A，依据原保存的 level.elapsed 继续正常波次与战斗；真实旗舰失去战力、三批主力清场后，保留原 gao_end 任务按钮，再真实保存 slot gen2 并退出。两次保存使用同一 active LC gen1/token，不能先合成终局或写 Campaign 进度。

C resume_finish：独立 Continue 还原 B 的暂停检查点。保持原完整恢复、任务按钮重建和原 callback 断言；在真实 Resume 前新增宿主故障 gate。宿主确认 user://campaign_cfg_candidates 原本完全不存在，才 CREATE_NEW 自有 nonce regular file。随后原 Resume、任务面板输入与真实可见“收兵通关”按钮按原路径触发自然胜利。第一次 CFG_STAGE_PARENT、保持阻塞的实际 RetryTerminal 再失败、解除自有阻塞后的实际 RetryTerminal 成功，都发生在同一个 C 进程和同一个原终局对象内。

D reject_terminal：独立正常启动，不再结算原终局；按原 Continue 按钮得到 LOCAL_RUN_TERMINAL，保持菜单且无 Battle，原 slot、LC、CFG 和进度不变。继续保留原严格 LC v3 / Intent v2 / ACK v2、完整四目标分类、原实际解锁与奖励门槛。高俅 contract_version=3、story_total=4；要求自然核心胜利，不要求或伪造可选生擒与四目标全达成。

原 source_driver/base/terminal/policy 从既有高俅工具逐字复制；新 driver 只覆盖 C 的终局重试控制，新 bootstrap 绑定实际六个 worker。来源表同时绑定原五份 GD 的 ancestry，包括不作为运行 worker 的原 bootstrap。这里不使用旧 V16/Intent v1，不能将旧 61 阶段资格迁移过来。

## 故障前后的准确状态

固定 b22 的 continue_flow.gd:429–441 接收原 Battle END 并延迟磁盘操作；446–477 在非物理帧暂停 Battle，创建一次 CampaignCoordinator，之后调用同对象 retry。run_campaign_progress_coordinator.gd:172–178 先由真实 Lifecycle 提交 terminal gen2，再执行 CFG。因此第一次父路径失败时必须观察到 LC gen2、progress_state=pending、同 token/Intent v2，且 progress_receipt 为空。

CFG 的 commit_prepared:226–252 已经创建并冻结真实 ConfigFile，_active.stage=staging；retry_write:277–280 在父路径安全检查时返回 CFG_STAGE_PARENT。此时 CFG journal 的 head revision 为 0/ZERO，只有当前 writer 锁；没有 generation 0 记录、没有 candidate.cfg，也没有 prepared journal gen1。LC gen2 与 CFG head0 是两个不同的持久化链，不能混写成“所有记录都没有变化”。

Coordinator._drive_cfg:136–141 再次检查当前 owned preproposal 后，直接调用同 busy _cfg.retry_write。因为 stage=staging 且 _frozen_cfg 非 null，preparation_pending 为 false，不会 abort 或重新创建提案。应保留实际 Battle、LC、Coordinator、Coordinator._cfg、_frozen_cfg、_active、_intent、_gate_scope、transaction、owner raw/SHA 和 frozen Values.semantics；不能用新的同值对象冒充同对象重试。

内部 staging _active 的新增 semantics_sha256 键实际可为 StringName。exact_active 因此使用 QA 专用 qa_cfg_staging_active_observation_v1：只接受原六字段，按原顺序记录键的 index、原 String/StringName key_type、key_text，以及各原值的生产 Codec 编码。任一未知/重复键或值编码失败都拒绝；不编码不受支持的原 Dictionary，不修改它或生产 Codec，不用 JSON 转换抹去类型。is_same 引用保持、原事务/文件/语义断言不变。这是对 B1 失败原件所揭示观察器限制的适配，不是生产修复，也不授予 C 实跑资格。

四个实际 RefCounted 对象的 instance_id 按规范非零 signed-int64 字符串核验，允许 Godot 实际返回的负值；拒绝 +号、前导零、-0、零和越界，仍要求对象互异及同进程前后同 ID。PID/provider PID 等正数约束不变。

writer 属于 Coordinator._cfg，不是 Campaign._cfg_writer。Campaign.persistence_busy:291–292 仅检查偏好 writer，可能仍为 false；本片排他和保留证明应使用 ContinueFlow busy、ProgressGate 的原 holder/pending scope 以及 Coordinator 内的真实 writer，不能套用 B1/B2 的对象路径。

Flow._terminal_failed:493–499 每次失败都发出 operation_finished，并将 battle_held、terminal_pending 标记为 true；原 CFG 错误不保证携带 local_terminal_committed 等附加字段，LC gen2 必须由实际记录证明。RetryTerminal:501–505 在原下一 process_frame 重试。两次失败后，原 Battle 仍 END、树暂停、终局 HUD 尚未发放，原 mission metrics 尚未由 _complete_end 关闭；同 frozen intent、CFG proposal、owner、slot 与业务文件库存必须保持。

这里的 battle_held 是 Flow 终局错误标记，不能解释成 SaveBarrier.HELD。实际保存恢复并 Resume 后，原 SaveBarrier 应为 IDLE；C 核 Battle.END、树暂停、clock 不在 step 中，并保留真实终局对象。

解除阻塞后，真实 CFG 完成 prepared1→applied2，Coordinator 写 ACK v2 并由原 Lifecycle 追加 gen3，然后 Campaign._load、Gate.leave、consume_live_completion 与原 Battle._complete_end 才发生。Flow:489 清空 _campaign_terminal 是预期成功收尾；测试须提前保留原引用以核原 Coordinator 到 done、消费一次，不能要求 Flow 成功后仍持有它。实际终局 HUD、任务 metrics 和最终进度只完成一次，D 再启动不能新增提交。

## 不提前改写自然结果

禁止在 arm gate 前调用 Mission.result_snapshot(true)。campaign_mission.gd:233–247 会冻结和归类任务结果，这不是只读观察。应先按原恢复和按钮链触发胜利，等 Intent.capture:119 已由生产自然冻结后，再读取 _result_cache、LC intent 与实际完整结果。

A/B 的原保存链只走 Session 的 Slot/LC binding；章节菜单出征和 AppLifecycle SaveExit 没有写 CFG candidate parent 的必经调用。原高俅工具也检查两次 active 保存未改变 CFG/奖励，但它没有证明 parent 目录不存在。因此 C 宿主必须独立核查原路径、profile 边界、普通文件/目录类型、no-links 和实际不存在；若已存在就停止，不删除目录来制造故障前提。

宿主阻塞物只能位于实际私有 user://campaign_cfg_candidates，不能创建 v1，也不能覆盖已有文件。原 CREATE_NEW 句柄、nonce、原字节/SHA/长度和路径绑定后才发 ACK；撤销时只能移动或移除自己的原件。故障保留期间通过原 RetryTerminal 实际失败证明 CFG_STAGE_PARENT，不以存在阻塞物或stdout PASS代替原 API 结果。读取对象和 metadata 不授权修改 production state、注入奖励、伪造 LC/Intent/CFG 或调用终局内部方法。

## 协议、来源与范围

保留原 GVT_ 四模式和 campaign_gaoqiu_terminal_v1 报告，C 增加 observations.terminal_retry，schema 为 ui_terminal_retry_observation_v1，分别保存 before、first_failure、blocked_retry、success、operations 和 gates。新增 UTR_GATE_DIR、UTR_SOURCES_SHA256、UTR_MANIFEST 控制字段，原 GVT_ 环境和前驱绑定继续保留。宿主总收据 schema 为 ui_terminal_retry_four_process_v1。

请求 schema 为 ui_terminal_retry_gate_v1，公共十字段是 schema/mode/phase/pid/batch_nonce/process_nonce/profile/content_version/engine_sha256/detail。ui_terminal_retry_ack_v1 将 detail 换成 request_sha256 与 ok，共十一字段；PID 按有限整数规范，原路径、SHA、nonce 与 profile 精确匹配。

arm_terminal_stage_parent 位于 C 恢复暂停、Resume 前，detail 精确为 stage_parent/cfg_path/journal_directory/lifecycle_directory/token/slot_sha256。release_terminal_stage_parent 位于第二次真实失败之后，detail 为 stage_parent/cfg_path/journal_directory/lifecycle_directory/token/transaction/expected_code，expected_code 必须是 CFG_STAGE_PARENT。宿主核原自有 blocker 与两次失败实证后才撤销故障并 ACK，不能只按请求中一个 path 盲目删除。

六个 worker 为 bootstrap.gd、driver.gd、source_driver.gd、base.gd、terminal.gd、policy.gd。本片源码表仅在两作者停改后生成，开发中的草稿不能提前标记为固定输入。

宿主仅复用已封口 B1 的文件系统、完整来源准入和自有 blocker helper，以及原高俅宿主的 source_pins 来源读取；不执行旧 runner，不以旧测试结果代替本片四个进程。来源表 files 精确包含本片 README、cases、宿主与六 GD 共九件，dependencies 同时保留实际 helper 和原高俅完整 ancestry，sources 自身另行 pin。

同一批次只创建一次私有 profile 环境，四个独立 Popen 使用不同 process nonce。A/B 必须由原 AppLifecycle 真正退出 0；C/D 使用测试正常退出，不能冒称生产 SaveExit。每阶段绑定实际 source identity、engine、candidate manifest、worker sources、前驱原件 SHA、PID/nonce/profile；跨进程 typed 检查保留原 Codec 约束，不用 raw JSON 数值类型全等误判恢复。

复用完整来源、共享 lane、自有 Popen、长路径和原件保留 helper；所有故障清理均限原自有路径/句柄，未确认 child terminal 不撤销控制后伪称通过，也不强杀外部 PID。最终来源验证、原始 traceback、cleanup 错误、实际进程终态与锁释放分别写入收据。默认命名准入和纯加载不授予运行资格；四进程总资格只能由宿主在完整终态后决定。

本片是 source-private 的引擎内原 UI/Viewport 与受控文件故障验证，不是 OS 桌面输入、真人体验、公开入口或原生 Steam SDK 验收。没有 full_campaign、full_61、原19故障、发布或其他章节终局资格。

## 使用方式

在开发工程根目录运行默认命名检查：

```powershell
python -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_terminal_retry/run_ui_terminal_retry.py
```

只有显式 --run 才进入共享 lane、完整 b22/自身冷导入验证和四进程实跑：

```powershell
python -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_terminal_retry/run_ui_terminal_retry.py --run --timeout 1320 --wait-lane 0
```

--timeout 是每个实际进程的墙钟上限，最小 1200 秒，不包含完整来源前后验；原自然路线自身时限仍保留。--wait-lane 0 表示 lane 被占用即停止，不排队启动其它引擎。默认 --base-run 是本页固定 b22，显式 --full-preflight 才执行昂贵的完整来源只读检查，它不建 profile、不启动引擎。输出为 .godot/ui_terminal_retry_20261027/<batch>，每阶段 controller/report/log/gate 原件和末尾 receipt 分别保存；失败保留原始 traceback 与独立 cleanup 错误，不清空收据。

## 仍未实现

本片不覆盖 credited Steam 终局、其它 CFG/ACK 失败阶段和未知 layout。RetryRelease 的合法完整 HELD 路径仍未找到外部可解除 I/O 故障；后续只可另行验证真实 clock.abort_step 持久故障模型、RetryRelease 持续拒绝和 LeaveHeldBattle 取消/确认，不得清 fault 或捏造成功分支。


## 2026-10-27 独立终局拒槽的检查点来源修订

131330原四份GD报告125／129／419／64项全真、四进程均exit0；宿主在D处理正常的checkpoint={}时误当作新Battle检查点而报Original uncredited slot binding required，整批仍失败，原receipt.actual_checks=673只含前三个宿主成功阶段。原737报告、673宿主累计及来源均保留，不回填原件为通过。

D未恢复Battle，不应新造战斗checkpoint。后继宿主只在D显式要求当前checkpoint为空、C前驱检查点存在，再用已经通过C验证的原gen2检查点核本进程原槽落盘；原两文件库存、同token binding、LC3／Intent2／ACK2、CFG hash和两条journal仍实际读取校验，D终局检查点仍须与C完全相同。另增terminal.slot_binding与该原槽binding直接相等，未跳过磁盘或状态检查。

仅四份QA宿主／文档／契约／来源表变更；六GD和生产不改。只读事后诊断不授新四进程运行资格，正式修订仍须新profile完整四流程，不能继续失败profile冒充新通过。
