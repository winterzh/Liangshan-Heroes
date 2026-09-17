# 祝家庄世界恢复接入准备：未应用草稿

根任务提供的运行基线为 clean `b734123`。本目录仅在工程外准备；未操作 Git、未运行 Godot、未编辑工程的 scripts/assets/tools/project，也未改变运行入口。当前完整经典 30 波由根任务独占引擎。以下是接入方案，**不是祝家庄已可存档、完整世界验收或 Steam 续玩交付**。

## 可直接审阅的首批草稿

- `draft/scripts/run_official_restore_profile.gd`：固定经典 30 波与官方 `level3` 两种选择；比较已安装 catalog 与预加载脚本；规范化 JSON 的整数/浮点 waves；拒绝未知上下文、额外字段、其他官方关卡、自定义玩法、内容/引擎不一致。只返回选型，不授予 save/activate/Steam 权限。
- `draft/scripts/run_level3_world_factory.gd`：先以安装内容按正常顺序构建关卡运行定义，再使用现有 CampaignLevelState 恢复真实 Level3 的 31 个字段。此关没有外部 UI 字段，可在 Presentation 之前恢复 Level，无需增加 `restore_into` 或临时 Level 替身。
- `level3_profile_factory.patch`：上述两个新增文件的统一 diff，仅供审阅。没有修改现有 Core/Root/Session 的半成品补丁。
- `level3_map_review.md`：独立逐行审查，包含真实墙段、五项城门视觉 metadata、占地、囚徒、偏门撤退和终局的来源行号。
- `source_manifest.json`：当前有关源码的 SHA-256；基线名由根提供，未通过 Git 再查询。草稿未经过 GDScript 原生解析。

首批的唯一实现范围是可信选型与纯关卡工厂。`ok=true` 表示其局部选择/值恢复成功，返回始终保留 `complete_world=false`；这两个文件单独接入也不能打开玩家入口。

## 当前硬编码与最小扩展位置

| 组件 | 当前事实 | 祝家庄必要变化 |
| --- | --- | --- |
| WorldCore | `classic_world_core_preparation_v7`、20 sections，L/LevelState 固定 skirmish；root 传入同一个 L | 从可信 profile 选择固定 Script/LevelState；增加 Mission、Presentation、精确 fx 混排记录，不从存档读取 Script/Callable/path；构造前完成 schema/profile/content 校验。 |
| RootState | `defense_battle_root_v4`；拒绝非空 mission；值层要求 FIGHT+economy | Level3 同样符合 FIGHT+economy，基础数值字段可复用；将 mission/level 外部约束换成明确 profile + exact MissionScript/owner/token 校验。不能直接取消检查。跨帧布局另需拆分值预安装与时钟最终 arm。 |
| Barrier | 明确 defense/waves30/skirmish/mission=null | 用选型后的真实 `_official_context`、exact level Script、Mission owner 验证 Level3；保留 60 Hz、完整物理步、输入关闭、延迟排空、diagnostic/AI 拒绝。已有 HUD 全子树门控会包含任务面板。 |
| SlotStore | **`classic_continue_slot_v3`**，9 顶层字段；有 `session_settings.auto_micro_level` | 增加官方版本的严格 codec 与 context 对应的 world section 集；保留当前 v3 所有 settings/CAS/pending 语义。不能用早期 v2 草案覆盖新设置。 |
| Session | 固定 FLAGS 与 `Store.CONTEXT`，包括已保存的 Settings | 每次准备前先选 profile；Level3 安装/回滚 Campaign.current=2 与 5 个玩法 bool；当前 OPTIONS、auto_micro_level 均保留并按实际消费约束。跨帧后再次核验 menu/Steam lease/Campaign/Settings/slot hash/receipt；成功前保留菜单。 |
| LocalLifecycle | 文档 context 固定 classic30 | 改为构造时可信 context，文档验证和 binding 校验必须和 slot/profile 全等；旧 classic receipt 只能按显式旧 schema 接受。首次保存先 active receipt，终局先 durable terminal，再发结果。 |
| ContinueFlow | 玩家入口 false；restore 同步一次 commit | 玩家入口继续 false。内部 QA 增加可重入的 mounted-layout 阶段与次数/时间上限，只有 `PRESENTATION_LAYOUT_PENDING` 可等待，其他失败立即清理并保留菜单/档。 |

建议先保留 classic 当前 reader/writer 不动，为 Level3 增加独立明确版本路径：`official_world_core_preparation_v1` 的 5 个顶层字段 `schema/profile/content_version/engine_sha256/sections`；`profile` 固定 5 字段 `schema/id/context/mission_token/presentation_token`，id=`campaign_level3_v1`，schema=`official_restore_profile_v1`。Level3 sections 是原 20 节加 `mission/presentation/fx_layout`，共 23 节。未来其他七关逐个增加实际完成的 profile，不能因现 LevelState.SCRIPTS 有八关就全部放行。

同一个继续槽应使用统一有版本分派的文档校验，仍保留单槽路径、scope key、文件替换/CAS/回滚，不另开“战役槽”。旧 v3 与新官方 schema 只按显式规则读取；无法证明兼容时保留旧文件并拒绝，不猜迁移。建议保持现底层 transaction magic（它只是格式身份，不是玩法许可），只扩文档版本分派，避免更换 magic 导致旧槽无法被检查或提示覆盖。

## 真正的工厂与部署分离

恢复前的 private runtime 必须按 `Defs → content pack → Level3.apply_overrides → AbilityVisuals` 构造；ContinueFlow 现 `_runtime()` 少了 Level3 覆写。后续训练和补兵读取 `_defs`，仅恢复已存在 Unit 的定义不够。草稿只写私有字典；返回 `environment_buildings={zhu_gate:zhu_gate}` 供受控安装，未写 Art。

`Art.environment_buildings` 是实际全局渲染依赖。新世界的门、Scenery 和视觉资源准备前，要保存当前 Art 环境/运行别名，建立当前 Level3 环境后再枚举可信贴图；失败回滚，成功才交接。不得从 slot 发出 Art 路由或任意资源加载。该全局变更应晚于最初 slot/身份/receipt 静态验证，但必须早于依赖它的工厂；若旧菜单仍在树上，禁止其操作改变环境。

允许的 Level3 工厂调用只有固定 `Zhu.new()`、`apply_overrides`（私有数据）、CampaignLevelState.validate/restore。恢复不调用 `Campaign.make_level`（有用户模式与 fallback）、`level.paint_map/decorate/deploy/on_start/process`、`Mission.begin/configure_campaign`、奖励/命令/剧情回调。现 Battle 的 prepared `_ready` 能直接跳过常规部署，不需要本批修改 Battle 或 Unit 的玩法代码。

## 地图与对象身份

MapState 已覆盖 `campaign_wall_segments`、高度、decor、五套导航、`_block_count` 和 revision；gate 的五项 metadata 也已能通过 UnitState metadata codec 保存，**这些不是待新增的 Level 字段**。恢复 metadata/高度必须在 CampaignScenery.setup 前，否则会构造错误的四段旧墙。实际墙是 x19..21，y0..55，两个 3×3 门洞；视觉是三段边界墙。图和占地计数直接恢复，禁止再 bake/register footprint。

真正待补的是 CampaignScenery 专用状态/工厂：精确 `_style/_walls`、StorySign、元数据及纹理白名单、继承树木/影子/可见性状态；根 Script 放宽不足以恢复三块牌匾和墙体运行引用。构造读取已有 map 值，不重新 level.decorate；重建后核对网格/导航/占地/高度零变化。

UnitState 现明确拒绝 `defeat_outcome/story_outcome/_pose_previous_variant/_story_pose_t/is_captive` 的章节状态。需要在 **状态组件** 内增加 Level3 的明确规则和实例图验证；禁止简单移除拒绝。初始七囚徒、扈三娘 captured 以及开偏门 retreated 都是正常玩法路径。获救者仍可 noncombat/passive/atk0，不能套用默认英雄模板。撤离偏门 hp≥1、hidden、引用仍存、footprint_blocked=false；不能按 dead/不可战斗剔除。无需同时修改 Unit 的生产玩法实现。

全局单位 ID 同一份，Core 的 object→ID 表需明确反转成 Mission/Level 要求的 ID→Unit 表；不按名字查旧单位。Level3 31 字段可先恢复后直接装 owner.level，再调用 `Battle.configure_restored_gameplay_rng`。当前 Core 无条件调用的 `level.bind_gameplay_rng_owner` 只存在于 Skirmish，Level3/LevelBase 没有该方法；应仅在 classic profile 固定调用，不能照搬给 Level3。七囚徒必须保留 7 个槽及次序，死亡槽可 null，不压缩。

## Mission / Presentation / Level 与跨帧安装

1. 捕获：真实 Barrier.HELD → 完整 Unit graph/两向 ID 表 → Presentation.capture（读取 Barrier 原 UI flags）→ MissionState.capture 与 LevelState.capture 共用 mission_token、presentation_token、content_version 和同一 capture_ticks_msec → Root/map/其余组件 → 全图关系校验。token 由当前外层事务产生一次并复用，不允许各组件随意替换。
2. 准备：严格 profile/content/schema → private Battle/world/map → MapState.stage_map_values → 全 Unit graph → LevelState.restore → RNG → fog/战役 Scenery → fx 分区/HUD shell/environment/camera → Presentation.prepare（内部创建 Mission，恢复 44 字段、真实按钮、marker、翻译绑定）。此时不开启任何玩法。
3. fx 所有权：只允许已验证的 MissionMarker 外部 token；保存 fx_root 所有直接子节点的混排表，包含 effect token 与 marker token。Visual.capture/prepare/activate 都必须理解精确 partition/topology，不能仅 capture 跳过 marker；其他 effect children 规则继续原样拒绝。每个 marker 只能属于 Mission registry，每个 effect 只能属于 Visual registry，集合加顺序必须覆盖整个 fx_root。
4. 挂载布局：新增 Core/Root/HUD 的受控阶段。Root 先解码并一次安装值/引用，**不创建 clock**；HUD 用这些值构建 gated UI。此时设置 restored RNG 和 `_run_core_prepared`，保持无 `_run_core_clock_bound`、无 clock/barrier、disabled/blocked。现 `Battle._prepared_clock_entry_valid` 允许该状态（17262），无需改 Battle 守卫。挂入暂停树后执行 Presentation.finish_layout，至少跨两个后续 process frame。
5. 最终 arm：原准备事务持有内部一次性 ticket 和原 record。最终帧重新核验 gates/拓扑/旧菜单与全局状态/slot/receipt；只绑定 Root 的输入绝对时钟和 simulation clock，设置本帧 `_run_core_clock_bound`。禁止重新调用完整 Root.bind 覆写已准备值。Mission `_stage_started_ms` 也按保存 stage_age_ms 在此帧重定位，排除布局等候时间。HUD 最终校验并记录本帧激活 token；只有本帧能够完成下一步。
6. 激活：安装官方 context 与 receipt → 在同一个最终帧连接新 Unit 的 died/story_resolved 固定 callback → 激活单位/特效/雾/显示/HUD → 激活 Presentation → 添加新 Barrier、激活 clock → root flags → Steam binding最终安装（仅已获支持的统计模式）→ current_scene 交接/销毁旧菜单/恢复原暂停状态。HUD 的整树计划会看到已 gated Mission，要保留其 flags 给 Presentation 最后启用，不能双重恢复错序。

失败时先 Presentation.dispose，断开 Localize.language_changed/移除绑定，再销毁 private/mounted 世界；回滚 Art/Campaign/Settings/canvas，保留菜单、receipt 和槽。必须给 layout_pending 设置明确上限；队列中已有 prepare/commit/退出事件不可复用 ticket。当前 Root.bind 与 HUD.finish/activate 的同帧契约不可直接跨帧 await；上面是待实现的分阶段接口，不是现有代码能力。

## 终局与验证出口

MissionState.validate 返回 `resume_eligible=false`（冻结结果/终局 metrics）时外层直接拒绝；Phase.END 档也拒绝。Level3 manor_fallen 本身不等于胜利，救出时迁回营和完成 finish action 仍可能未结束，不能据单个布尔直接标终局。

未计统计继续局沿现 durable local terminal → `_complete_end` 顺序；context 扩为 campaign 后可保护旧槽不能再次发放 Chapter 结果。真实统计 credited 路径仍需独立确认其生命周期及 outbox 成功确认，不能因局部 Level3 工厂完成就放开。终局先写 terminal 再 Campaign.on_level_won 可阻止重复，但“terminal 后、chapter.cfg 前”中断仍可能漏发：完整交付需可重试的独立结算收据，保存结果并以 receipt ID 幂等更新 Chapter 记录，最后确认发奖。这个缺口不可用拒绝继续槽冒充完整 exactly-once 收益。

后续最小串行落地顺序：本目录选型/纯工厂 → Chapter UnitState + CampaignScenery → fx partition + Mission/Level/Core 组合 → Root/HUD 分阶段与 Session/receipt context → 真实 Level3 快照切片跨进程 → 正常战斗完整通关。保留 classic 回归，玩家入口等九种玩法全部通过再统一开放。

针对每个新契约的验收：错/额外上下文、JSON 30.0/0.0 规范化和 NaN/未知模式拒绝；受信运行定义顺序；七囚徒/扈三娘/撤退偏门、破门与导航一致；孙立动作及撤离两个按钮焦点指向新实例；marker 与在途伤害混排；中途退出布局和外部状态变化回滚、Localize 连接无泄漏；终局中断/重试与重复读档不重复或漏发奖励。每片都需真实源世界捕获→进程退出→新进程恢复→继续 FIGHT 的证据。组件 fixture、静态 review、完整经典 30 波与上述祝家庄验证分别记录，不相互代替。
