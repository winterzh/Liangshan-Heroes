## 2026-09-08 普通 Steam 统计修复与续玩组件收尾

- `docs/STEAM_STATS_FIX_20260908.md`：普通统计初始化、旧保存通知与服务器校正处理的修复，以及本轮已获授权、执行中的候选/Steam更新/公告状态；以最终收据区分各阶段。
- `docs/CONTINUE_DELIVERY_20260908.md`：经典30波与八关统一交付边界、生产持久确认BLOCKED及整体验收待办；玩家保存/继续仍未开放。
- `tools/run_steam_integration_qa.py`、`tools/build_steam_candidate.py`、`tools/steam_package_probe.gd`：GodotSteam与只读reader共同依赖冻结、原生整合QA、候选复制及同包检查入口。最新191项整合QA通过，候选构建在本条记录时仍执行中。
- `qa/steam_stats_fix_20260908/`：本批191项整合结果、六张已目检截图、前序fixture失败及候选/平台收据的归档入口；不能以未完成候选认定已发布。
- `scripts/run_campaign_level_state.gd`、`tools/campaign_level_state_qa.gd`、`tools/run_campaign_level_state_qa.py`：八关显式Level状态组件与隔离运行器。
- `docs/CAMPAIGN_RESUME_STATE_AUDIT_20260908.md`、`qa/campaign_level_state_20260908/`：逐关字段、共享世界阻塞、最终205项行为检查、profile_guard及5890次SHA核验；保留旧152项和中间批次。
- `scripts/steam_persistent_outbox.gd`、`scripts/steam_persistent_outbox_state.gd`、`scripts/steam_persistent_outbox_store.gd`：内部持久发送意图/不确定标记及磁盘事务；生产确认未放行。
- `tools/run_steam_persistent_outbox_qa.py`、`tools/steam_persistent_outbox_qa.gd`、`qa/steam_persistent_outbox_20260908/`：221项原生断言、18个PID强杀检查点和13条fake SDK trace的最终证据与保留诊断，不能替代真实Steam/完整续玩验收。
- `marketing/steam_stats_fix_20260908/copy.json`、`marketing/steam_stats_fix_20260908/README.md`：四语公告初稿、字段长度检查和复用800×450封面的来源；公告发布状态另记。

下方条目保留其批次当时语境；只读reader现已进入候选管线，不再沿用旧条目的“尚未加入候选”作为当前结论。

## 2026-09-08 真实 Steam 读取修复

- `tools/run_steam_stats_live_read.py`、`tools/steam_stats_live_read.gd`：独立真实账号只读诊断，默认预检。
- `docs/STEAM_LIVE_READ_20260908.md`、`qa/steam_stats_live_read_20260908/`：真实 ABI 失败与修复证据、86项隔离检查及脱敏读取收据。
- `vendor/steam_stats_reader/provenance.json`：已指向本次修正版，旧批次证据保留历史上下文。

## 2026-09-08 Steam 读取适配器

- `native/steam_stats_reader/`：原生只读桥接源码、CMake/精简绑定配置、合成核心/ABI测试及 MIT 头文件来源；`native/.gdignore` 阻止扫描。
- `scripts/steam_stats_reader.gd`：完整统计/成就读取门面，当前为内部接口。
- `tools/build_steam_stats_reader.py`、`tools/steam_stats_reader_qa.gd`：可复现编译和真实 Godot 隔离验证。
- `vendor/steam_stats_reader/`：受测 DLL、许可和来源清单，尚未加入现有 Steam 候选安装步骤。
- `docs/STEAM_STATS_READER_20260908.md`、`qa/steam_stats_reader_20260908/`：合同、86项验证及首次导入失败诊断。

## 2026-09-08 四语公告与商店语言表

- `marketing/steam_localization_announcement_20260908/copy.json`：四语标题、副标题、摘要、正文与图片占位符。
- `marketing/steam_localization_announcement_20260908/rendered_copy.json`：替换为 Steam 图片引用的四语正文。
- `marketing/steam_localization_announcement_20260908/images.json`：原图来源、尺寸、哈希、上传引用与封面记录；不复制或修改图片像素。
- `docs/STEAM_LOCALIZATION_ANNOUNCEMENT_20260908.md`：已发布公告 708907988310559012、商店语言表与后续维护边界。
- `qa/steam_localization_announcement_20260908/`：公开文本/图片、商店语言表的 `publication_receipt.json`、`validation.json` 及说明；`.gdignore` 阻止 Godot 扫描。本轮未变更运行代码或 EXE。

## 2026-09-08 Steam 四语交付

- `docs/STEAM_LOCALIZATION_UPDATE_20260908.md`、`qa/steam_localization_update_20260908/`：四语与校订内容的 Windows 更新记录。
- `tools/build_steam_candidate.py`、`tools/steam_package_probe.gd`：纳入四语资源的候选白名单与实际 Steam 包检查。

## 2026-09-08 文本校订与布局检查

- `scripts/lore_data.gd`：108 篇校订生平与回目索引。
- `scratchpad/.gdignore`：受控保留的扫描边界；目录中其他测试数据仍被 Git 忽略。
- `assets/localization/text_review_ui.json`：出处、改编说明与补充界面词条。
- `tools/apply_text_review.py`、`tools/normalize_localization_names.py`：精确替换及术语统一工具。
- `tools/text_ui_review.gd/.tscn`、`tools/battle_text_ui_review.gd/.tscn`、`tools/text_review_contract.gd/.tscn`：界面、战斗文本和玩法定义回归。
- `docs/TEXT_REVIEW_20260908.md`、`qa/text_review_20260908/`：逐人原著依据、应用收据、运行记录与选定截图。

## 2026-09-08 本地化文件

- `scripts/localization.gd`：四语注册、偏好保存、显示绑定。
- `assets/localization/`：运行词库、源分片、完整传记、术语和精确排除清单。
- `assets/fonts/`：Noto CJK 字体集合、OFL 许可证与来源哈希。
- `tools/build_localization.py`、`tools/localization_catalog.py`：重建及完整性检查。
- `tools/run_localization_qa.py`、`tools/localization_qa.gd/.tscn`：隔离运行与画面验证。
- `tools/run_localization_package_qa.py`、`tools/localization_package_probe.gd`：本地 PCK 导出、四语资源与主菜单启动检查。
- `docs/LOCALIZATION_20260908.md`、`qa/localization_20260908/`：实现说明与本批证据。

## 2026-09-08 恢复组件Steam更新

- docs/STEAM_RESUME_UPDATE_20260908.md：本轮构建、上传状态和接续。
- qa/steam_resume_update_20260908/：原生/包/身份/EXE证据与交付清单。

## 2026-09-08 收尾交接

- docs/CLOSEOUT_20260908.md：当前代码/QA/玩家与Steam交付边界、固定版本接口研究和后续顺序。

## 2026-09-08 持久局会话

- scripts/steam_local_run_session.gd：累计意图、检查点、持久绑定及恢复验证。
- docs/PERSISTENT_RUN_SESSION_20260908.md：SteamService与世界会话的内部连接合同。
- qa/persistent_session_20260908/：四进程防重/终局、失败与原未计统计回归。

## 2026-09-08 单槽与跨进程会话

- scripts/run_snapshot_store.gd：共享双快照事务基类。
- scripts/run_slot_store.gd：经典据守单槽模型与读写。
- scripts/run_world_session.gd：HELD保存、当前菜单恢复事务。
- docs/WORLD_SLOT_20260908.md、qa/world_slot_20260908/：合同、失败记录及跨进程/存储兼容证据。

## 2026-09-08 战斗累计击杀

- docs/STEAM_BATTLE_COUNTER_20260908.md：root v4、有效击杀累计/内存高水位合同。
- qa/steam_counter_20260908/：真实死亡、第三次世界替换及Steam假SDK重试证据。

## 2026-09-08 Steam独立局记录

- scripts/steam_run_receipt.gd：账号、局token、高水位、终局与校正纯模型。
- scripts/steam_receipt_store.gd：独立快照文件事务、压缩和死写者恢复。
- scripts/steam_run_ledger.gd：内部串行落盘及新鲜度检查API。
- docs/STEAM_RUN_LEDGER_20260908.md、qa/steam_ledger_20260908/：合同及原生崩溃/坏记录证据。

## 2026-09-08 统一世界替换

- scripts/run_world_swap.gd：同进程HELD世界替换与旧场景/Steam内存局交接。
- docs/WORLD_SWAP_20260908.md：激活/回滚/所有权合同。
- qa/world_swap_20260908/：原生生产/移动/伤害持续运行证据与受测SHA。

## 2026-09-08 跟随及贴图特效恢复

- scripts/run_linked_fx_state.gd：12类固定字段、引用/贴图表及缓存校验。
- docs/LINKED_FX_RESUME_20260908.md：当前Art登记与生命周期合同。
- qa/linked_fx_20260908/：原生输入、来源/日志/报告及晋级SHA。

## 2026-09-08 程序化特效恢复

- scripts/run_procedural_fx_state.gd：30类固定字段/缓存校验及受信Script白名单。
- docs/PROCEDURAL_FX_RESUME_20260908.md：字段清单、恢复闸、剩余类。
- qa/procedural_fx_20260908/：两轮原生证据、候选及来源/晋级SHA。

## 2026-09-08 战场环境恢复

- scripts/run_environment_state.gd：Overlay/氛围/浮尘的状态、隐藏准备及同帧激活。
- docs/ENVIRONMENT_RESUME_20260908.md：环境相位与原生渲染验证。
- qa/environment_resume_20260908/：原生运行、受测候选、来源和晋级SHA。

## 2026-09-08 HUD 整体恢复

- scripts/run_hud_state.gd：FIGHT HUD状态、隐藏准备及同帧激活。
- docs/HUD_RESUME_20260908.md：真实根绑定后的安装顺序与剩余工作。
- qa/hud_resume_20260908/：原始失败/通过、受测候选、来源和安装SHA。

## 2026-09-08 HUD 消息恢复

- scripts/run_hud_messages_state.gd：消息历史、阅读位置和有限提示动画的显式状态。
- docs/HUD_MESSAGES_RESUME_20260908.md：恢复合同、原生证据及剩余工作。
- qa/hud_messages_resume_20260908/：失败/通过原始运行、受测输入和安装SHA。

## 2026-09-08 相机恢复

- scripts/run_camera_state.gd：显式相机字段、屏障输入与暂停激活。
- docs/CAMERA_RESUME_20260908.md：合同、原生结果及剩余工作。
- qa/camera_resume_20260908/：原始执行证据、候选和SHA安装收据。

## 2026-09-08 世界显示恢复

- scripts/run_world_display_state.gd：世界组成、受信资源、阴影缓冲与身份、暂停激活。
- docs/WORLD_DISPLAY_RESUME_20260908.md：合同、原生结果、失败修复和剩余安装门。
- qa/world_display_resume_20260908/：八轮原始证据、候选、执行器及SHA安装收据。

## 2026-09-08 死亡残留恢复

- `scripts/run_death_remains_state.gd`：残留字段/贴图/元数据与所属列表和缓存的显式恢复。
- `docs/DEATH_REMAINS_RESUME_20260908.md`：合同、失败修复、原生结果与完整世界后续。
- `qa/death_remains_resume_20260908/`：八轮原始失败/通过、最终候选与驱动、SHA和安装收据。

## 2026-09-08 世界核心准备事务

- `scripts/run_battle_world_core.gd`：实际屏障捕获、同一身份的多模块离树准备与失败释放。
- `docs/WORLD_CORE_PREPARATION_20260908.md`：接口顺序、原生证据、完整世界与继续槽后续。
- `qa/world_core_20260908/`：五轮原始运行、失败/成功记录、冻结候选/驱动、来源与安装收据。

## 2026-09-08 混合FxRoot

- `docs/MIXED_FX_RESUME_20260908.md`：统一Projectile/飞斧/视觉图合同、原生结果与世界工厂后续。
- `qa/mixed_fx_20260908/`：两轮原始原生记录、冻结候选/驱动、来源清单和安装收据。

## 2026-09-08 闪现箭光恢复

- `docs/BLINK_RESUME_20260908.md`：BlinkShotFx恢复合同、原生验证及后续世界工厂步骤。
- `qa/blink_resume_20260908/`：受测原始候选/驱动、原生日志与报告、来源清单和安装收据。

## 2026-09-08 公告发布归档

- `docs/STEAM_ANNOUNCEMENT_20260908.md`：已发布中英文内容、正文实机配图来源与公开页检查。
- `qa/steam_announcement_20260908/`：独立公告发布收据；复用任务框QA原图，不复制图片或改写构建收据。

## 2026-09-08 Windows Steam 上传完成

- `docs/STEAM_UPDATE_20260908.md`：本轮Steam构建、分支和验证范围。
- `qa/steam_upload_20260908/`：全新原生、导出、实际EXE短测、原始失败、路径脱敏映射及服务端回读证据。

## 2026-09-07 任务框Steam交付

- `docs/STEAM_MISSION_PANEL_UPDATE_20260907.md`：实际线上Build与来源范围。
- `docs/UPDATE_ANNOUNCEMENT_MISSION_PANEL_20260907.md`：简短公告草稿。
- `qa/steam_mission_panel_20260907/`：独立成品验证、截图、双来源清单及服务端收据。

## 2026-09-07 并行开发第一批

- `scripts/run_battle_clock.gd`、`run_battle_barrier.gd`：已接入的模拟时钟和经典捕获屏障；根状态升级v3。
- `docs/STABILIZATION_PARALLEL_BATCH_20260907.md`：本批实测结果、限定范围及下一批世界工厂顺序。
- `qa/stabilization_battle_barrier_integration_20260907/`：失败/成功原记录、四份候选、9正常开局、安装收据、独立审查与世界工厂设计。
- `qa/steam_receipt_disk_20260907/`：A1迟到回调缺陷、A2假SDK/磁盘强杀矩阵、合成fixture和来源映射；未接生产。
- `qa/art_song_jiang_a1_candidates_20260907/`：独立网页原图、提示词、来源、明暗对照、初审和淘汰记录；不属于生产美术。

## 2026-09-07 任务框交互

- `docs/MISSION_PANEL_TOGGLE_20260907.md`：默认收起、点击展开/收回的玩家说明与实现。
- `tools/campaign_objective_toggle_test.gd`：真实GUI点击、地图空出区域、隐藏状态更新及滚动验证。
- `qa/mission_panel_toggle_20260907/`：首轮警告、最终原生结果、截图、候选字节、来源SHA与隔离复现入口。

## 2026-09-07 本轮收尾交接

- docs/STABILIZATION_CLOSEOUT_20260907.md：已同步代码基线、待验范围与下一次执行顺序。
- qa/stabilization_battle_barrier_draft_20260907/：实际Battle屏障/根v3冻结候选与驱动，原生未运行，未接生产。
- qa/stabilization_art_a1_brief_20260907/：宋江/林冲制作依据、状态表与输入摘要，没有新增生成图。

## 2026-09-07 恢复图与待发送事务

- scripts/run_battle_root_state.gd、run_remaining_effect_state.gd、run_item_cast_flow_state.gd、run_visual_graph.gd：四个已验证的局部恢复模块；整体世界工厂仍未完成。
- docs/STABILIZATION_RESUME_GRAPH_20260907.md、qa/stabilization_resume_graph_20260907/：原生有限范围结果、历史失败、冻结候选及五脚本安装收据。
- docs/STEAM_RECEIPT_OUTBOX_DRAFT_20260907.md、tools/contracts/steam_receipt_outbox_draft_20260907/：原生62项的纯事务模型和恢复执行说明。
- docs/STABILIZATION_DUST_FILTER_QA_20260907.md、qa/stabilization_dust_filter_20260907/：原生数据等价与六次正常性能筛选；候选已停止。

## 2026-09-07 稳定编号与后续基础

- `docs/STABILIZATION_IDENTITY_INTEGRATION_20260907.md`、`qa/stabilization_identity_integration_20260907/`：25生产脚本、9正常开局、45桥接行为和精确接入收据。
- `docs/STABILIZATION_IDENTITY_NATIVE_QA_20260907.md`、`qa/stabilization_identity_20260907/`：原24文件候选的86行为及失败入口历史。
- `tools/run_stabilization_identity.py`、`tools/run_stabilization_overlay.py`：冻结候选的原生私有执行入口。
- `docs/STABILIZATION_UNIT_BODY_QA_20260907.md`、`qa/stabilization_unit_body_20260907/`：33范围的高开销诊断，只用于定位。
- `docs/STEAM_RUN_RECEIPT_DRAFT_20260907.md`、`qa/steam_run_receipt_draft_20260907/`、`tools/contracts/steam_run_receipt_draft_20260907/`：纯回执候选、原生结果和原字节恢复清单。

## 2026-09-07 性能与 Steam 配置记录

- `docs/STABILIZATION_PERFORMANCE_20260907.md`、`qa/stabilization_performance_20260907/`：五组三次正常基线、Unit诊断、失败尝试、原始工具与SHA清单。
- `tools/run_stabilization_performance.py`、`prepare_unit_remainder_diagnostic.py`、`run_unit_remainder_diagnostic.py`、`unit_remainder_observer.gd`：冻结源码、私有执行及分段诊断入口。
- `qa/steam_configuration_publish_20260907/`：60图标后台/玩家页面标识、原图SHA、发布及构建回读的脱敏观察；不含登录缓存或分支口令。

## 2026-09-07 收尾计划与来源恢复

- `docs/STABILIZATION_EXECUTION_20260907.md`：用户批准的Windows收尾范围、顺序、并行边界和实际批次结果。
- `docs/ART_PROVENANCE_RECOVERY_20260907.md`、`qa/art_provenance_recovery_20260907/`：来源统计修复、失败与最终报告、正反例、独立副本和精确白名单。
- `tools/contracts/art_provenance_recovery_20260907/`：固定mapping与451份去重原字节来源证据；随源码同步，不能按临时截图或Godot缓存排除。
- `tools/campaign_art_evidence.py`、`campaign_art_evidence_selftest.py`、`campaign_art_portability_check.py`、`recover_campaign_art_provenance.py`：严格来源映射、TRES验收、隔离验证和受控历史回收工具。

## 2026-09-07 缓存清理与历史归档映射

- `D:\AI项目\水浒\归档\水浒_过期资料_20260907.7z`：9 组历史目录、4,161 个文件的归档，1,455,622,866 字节；已完成 `7z t` 和完整解压 SHA-256 零差异核对。
- 已归档的历史目录：`_archive/release_candidates/release_candidate_20260901_134110`、`_archive/campaign_history/campaign_environment_v8_20260831`、`_archive/visual_samples/visual_sample_20260831` 与同目录的 `visual_sample_v2_20260831` 至 `visual_sample_v6_20260831`，以及 `implementation_20260904`。以上相对路径均位于 `D:\AI项目\水浒\历史资料`，原位置保留 `已归档.md`。
- 继续展开：原始 ZIP、`_archive/campaign_history/campaign_rework_20260831_173850`、视觉 v7、`implementation_20260902` 和 `implementation_20260903`，以保持来源与基线可读。
- 缓存处理：3 份已核验的重复导入缓存和旧历史工程的标准 `.godot` 已删除；当前工程主缓存保留，旧工程再次启动时重建缓存。最新候选 ZIP、冻结源码、原始收据、正式素材和来源保留。
- `qa/storage_cleanup_20260907/`：本轮清理、归档及最终保护和启动验证的证据入口。50 个 Git 临时垃圾文件因删除被自动审批策略阻止而保留；不计入本轮约 1.89 GiB 净释放量。

游戏内容及启动方式不变；更早的目录记录保持原文，已归档项目按上方入口还原。

## 2026-09-07 本机存储迁移映射

| 本机路径 | 当前用途 |
| --- | --- |
| `D:\AI项目\水浒\开发工程` | 当前 Git checkout 与 Godot 工程，后续开发和验证使用此实路径 |
| `D:\AI项目\水浒\历史资料` | 原 C 外层的完整已核验副本，包含历史工程、来源、备份及交接材料 |
| `D:\AI项目\水浒\README.md`、`开始游戏.cmd` | 本机总入口与当前游戏启动器，位于 Git checkout 外 |
| 原 `D:\CodexTemp\liangshan-github-sync-20260905-5f8a7c2e` | 指向新开发工程的目录联接 |
| 原 `C:\Users\rsb\Desktop\AI项目\水浒` | 保留普通根目录及 10 个根文件（含迁移 README）；8 个子目录分别联接到 D 历史资料对应目录 |
| `qa/storage_migration_20260907/` | 本轮迁移清单、路径兼容及 Godot 启动验证收据 |

本轮仅调整存储位置与文档，游戏内容及历史来源 JSON 未改。旧 C 材料 17,241 个文件 SHA-256 核对零差异，Godot 隔离导入与 180 帧 headless 启动通过。下方目录与路径记录保留各轮原始语境，当前本机入口以上表为准。

## 2026-09-07 公司 Steam 构建与上传

- `qa/company_steam_upload_20260907/`：本机短路径工具验证及本轮候选、服务器上传收据。
- `.godot/company_steam_build_20260907/`：本机源码/真实玩家保护与原始运行缓存，保持忽略；ZIP 留在 `.godot/steam_candidates/`。

## 2026-09-07 公司接续入口

- `qa/company_handoff_20260907/`：公司环境恢复、首次导入元数据分类、原始失败/成功收据、受测运行输入清单和主菜单/驻守画面。
- `godot.local.txt` 与 `.godot/company_handoff/`：本机引擎路径及隔离检查缓存，均被忽略；正式交接证据使用上方 QA 目录。
- 旧共享外层的本机交接提示指向当前独立 checkout；该目录不再作为本次开发与提交入口。

## 2026-09-07 迷雾恢复组件与证据

- `scripts/run_fog_state.gd`：第 15 个恢复组件，保存迷雾逻辑、刷新余时、真实滞后图像与默认 FogLayer。
- [qa/run_fog_runtime_20260907/](../qa/run_fog_runtime_20260907/README.md)：GL、R1、R2 三次失败和 R3/正式两次通过的原始收据，正式轮 6 个 PNG 实体文件、R3 的 6 个原路径/SHA 映射，精确源码与复用映射。

本批不包含根状态候选。

停止前另将根状态 R2、稳定实体、ItemCast 和时钟准备物保存为[未晋级交接草稿](RUN_RESUME_HANDOFF_20260907.md)。这些草稿不纳入生产组件或 Steam 候选；本机停止新开发，由“完成项目收尾并发布”任务统一合入和同步。

## 2026-09-07 早间收尾入口

- `docs/MORNING_HANDOFF_20260907.md`：七点源码检查点、Steam实际状态与阻塞、公司电脑接续步骤。
- `qa/morning_handoff_20260907/`：本轮原生合同、候选验证、交付清单与不含账号信息的Steam页面观察记录。

## 2026-09-07 RNG与安装身份新增入口

- scripts/run_content_identity.gd：实际安装身份；R2依据Script backing严格验证源码或编译资源，native/callsite及source/PCK身份合同均已验证。
- tools/contracts/run_content_identity_20260907/：构建身份生成、source/PCK probe；probe R1修复JSON字段传输比较。
- qa/run_gameplay_rng_integration_20260907/：本批已冻结正式档，包含两native、两callsite、三build（两失败/最终通过）、两diagnostic、APP14及两修复链，source_index schema2使用仓库根相对路径并复用既有精确QA原文。

旧/R2调用点各102来源联合103个唯一SHA，101个共有，93个已有归档原文可复用。原provider候选和R2当前来源分开；正式档manifest为597e75dd6802c82a622725a34e7c1b2bb988c87050ca3fed9d2fdeb1b3235a1a；295份原始产物16,493,620 bytes，不含生成sidecar和后补README。

## 2026-09-07 技能施法三数组及修复证据

- `scripts/run_cast_flow_state.gd`：第14恢复组件，保存走近、抬手、引导三数组；依赖外层Unit计时/CD/路径与统一identity，累计12/17权威数组。
- `qa/run_cast_flow_20260907/`：原生产真实失败、生产修复R1、正式路径三轮；各16运行源码映射、原始收据/日志/摘要、模块/driver/runner/pins及原patch/application/准备/修复/晋级脚本。
- [组件说明](RUN_RESUME_COMPONENTS_20260907.md)区分真实freed目标修复、同矩阵63项复验和整局边界；旧Battle等按SHA复用，不含profile、玩家内容或PCK，后续物品候选不纳入。

## 2026-09-07 标准驻守关卡恢复及证据

- `scripts/run_defense_level_state.gd`：第13恢复组件，已启动经典30波skirmish的12声明状态；hall/末波采样接共享Unit身份图。
- `qa/run_defense_level_20260907/`：原型/正式各253项、各100运行源码映射，原始收据/日志/摘要、模块/driver/runner/pins及晋级脚本来源；精确复用旧Battle/Map等字节。
- [组件说明](RUN_RESUME_COMPONENTS_20260907.md)区分同Battle容器内两次Unit+Level安装与完整Battle恢复；记录首波/末波实证及正式pins字节数描述差异，不含私有profile/PCK/玩家内容。

## 2026-09-07 陨石与守卫模块及证据

- `scripts/run_meteor_wards_state.gd`：第12恢复组件，只含meteor/wards；命中身份走目标域，根负责精确ward_serial与Unit来源池。
- `qa/run_meteor_wards_20260907/`：原型/正式各54项、25步真实consumer/Unit TTL对照，两轮收据/日志/摘要、模块/driver/runner及旧依赖精确SHA映射。
- [组件说明](RUN_RESUME_COMPONENTS_20260907.md)记录权威数组累计9/17及事务约束；旧视觉Node、其余效果和M3整局未完成，后续关卡草稿未纳入。

## 2026-09-07 物品 UID、区域效果与复活证据

- `scripts/run_item_id_state.gd`、`scripts/run_zone_effects_state.gd`：第10/11恢复组件；配合同批Battle/Inventory连续UID窄补丁。counter依赖可信完整图证明，区域只含chrono/orbit/trail/ice四数组。
- `qa/run_item_identity_zones_20260907/`：五轮53/81/81/149/231项原始收据、日志、来源/玩家摘要、实际Battle/Inventory、两正式模块、candidate/builder及复活case/driver/runner/pins；source index保留99个复活运行来源并按SHA复用旧依赖。
- [组件说明](RUN_RESUME_COMPONENTS_20260907.md)区分allocator与正式路径补验、原Unit同矩阵回归、原物品自检和真实付费复活；不含私有profile/PCK/玩家文件，整局继续仍未完成。

## 2026-09-07 Steam 后台与候选证据

- `docs/STEAM_BACKEND_SETUP_20260907.md`：保存后回读、30项成就/60图标映射、文件访问与命名弹窗接续条件；授权有效，配置/包尚未发布。
- `qa/steam_backend_20260907/backend_state.json`：交互UI观察摘要，区分已保存草稿、未上传图标、未创建测试分支和未完成双账号实测，不是HTTP原响应。
- `qa/steam_backend_20260907/candidate/`：固定df7ed18的新176项原生、65项PCK和真实发行EXE/DLL证据、来源映射、脱敏记录与ZIP成员哈希。实际ZIP留`.godot/steam_candidates/20260907_034452_e661f0ee/`，不随Git同步。

## 2026-09-07 运行时 RNG 模块与独立包证据

- `scripts/run_gameplay_rng.gd`：第9个正式恢复组件，独立原生随机流与可信内容版本；恢复不依赖原始`.gd`源码，不迁移Battle调用。
- `qa/run_gameplay_rng_runtime_20260907/`：源码writer161/reader47，原PCK失败，R1及正式资源路径各24/33检查；保留报告/log/来源玩家摘要、合成handoff、模块/driver/runner/pins、模板和精确旧依赖引用。PCK、私有工程/profile、玩家文件、缓存不入档。
- [组件说明](RUN_RESUME_COMPONENTS_20260907.md)单列独立PCK七种子各64结果续接边界；原内部24项true不能掩盖writer退出2，正式路径重复矩阵不新增场景，M3整局仍待完成。

## 2026-09-07 Unit 顺序图模块与证据

- `scripts/run_unit_graph.gd`：完整Unit sibling/root顺序、独立active顺序、dying节点及全图引用恢复组合；prepare只返回计划、开放identity和活tombstones，不安装Battle数组。
- `qa/run_unit_graph_20260907/`：原型`20260906T192949868331Z`与正式`20260906T193154174815Z`各73条原文，包含模块、runner/driver、promotion、原准备pins/README与依赖索引；同SHA旧依赖明确复用，归档文本由`.gdignore`隔离。
- [组件说明](RUN_RESUME_COMPONENTS_20260907.md)明确所有FX/整数图须共用返回identity，全部绑定后才由外层release并激活；M3整局、菜单及PCK仍待完成。

## 2026-09-07 三数组持续效果模块与证据

- `scripts/run_continuous_effect_state.gd`：只恢复`_ground_dots`、`_hua_snipe_dots`、`_lin_duels`的剩余值、顺序与对象引用，按原型同字节晋级。
- `qa/run_continuous_effects_20260907/`：原型与最终正式各52条证据，首轮正式manifest覆盖缺口、旧runner/修正记录独立保留；包含runner/driver/模块、promotion和精确索引，相同依赖复用已提交QA原字节。
- [组件说明](RUN_RESUME_COMPONENTS_20260907.md)补充剩余3次地火、4次百分比流血及一次决斗奖励的实证；不覆盖其他14类效果或完整死亡清理，M3整局续玩保持开放。

## 2026-09-07 飞斧恢复组件与证据

- `scripts/run_li_brawn_axes_state.gd`：真实`Battle.LiBrawnAxesFx`的待结算值、Node状态、有序命中和新对象图恢复；与已通过原型同字节。
- `qa/run_axes_20260907/`：原型`20260906T190607921584Z`及正式`20260906T191522544612Z`两轮各46条证据、runner/driver/factory、promotion、manifest与来源索引；相同依赖复用旧组件归档，不重复大Battle源码。GDScript以`.gd.txt`保存，`.gdignore`隔离，无profile、缓存、玩家存档或资源二进制。
- [组件说明](RUN_RESUME_COMPONENTS_20260907.md)追加飞斧边界；两轮是相同组件复验，M3整局、菜单和PCK续玩仍待完成。

## 2026-09-07 追击诊断、独立 RNG 与真实恢复组件

- `docs/CHASE_PATH_DIAGNOSTIC_20260907.md`、`qa/chase_path_20260907/`：冻结4baafc1的602/597步、0 fallback与约0.186ms/步取舍，55/88原生Map和186离线检查；原始收据、诊断和分析器按字节归档，不是生产优化或正常FPS验收。
- `docs/RUN_GAMEPLAY_RNG_20260907.md`、`qa/run_gameplay_rng_20260907/`：R1私有独立流writer137/reader47检查及7×64=448个后续结果，原失败、成功双进程与精确源码/helper。未迁移生产全局随机流，不复制私有profile或引擎。
- `scripts/run_unit_state.gd`、`scripts/run_graph_identity.gd`、`scripts/run_projectile_state.gd`、`scripts/run_map_state.gd`、`scripts/run_scenery_state.gd`：五个正式组件；Unit149、Projectile54、Map63在原型及正式加载路径复验，同一组检查不重复当新场景。
- `docs/RUN_RESUME_COMPONENTS_20260907.md`、`qa/run_resume_components_20260907/`：原型五轮含两次失败，`production_path/`独立保留正式路径三轮；逐轮manifest/报告/进程/来源与玩家摘要、失败原文、源码映射和哈希清单。正式五模块作为明确仓库依赖；Map只改Scenery preload路径，63条headless数据/材质检查无截图验收。
- 本批原始受测基线199aac6保持，精确文件身份以run manifest为准；快进fe1faf5加受测时尚未提交的五个正式模块后，Unit149/Projectile54/Map63兼容性复测已通过。`qa/run_resume_components_20260907/integrated_head/`独立保留新三轮源码/进程/来源保护收据及[说明](../qa/run_resume_components_20260907/integrated_head/README.md)，不覆盖原型/正式路径历史，也不新增场景计数。Steam接入仍是本地候选，线上Build25154403不变。下一步整局顺序/UID/tick/全部效果与RunSession尚未构成已验收菜单或PCK续玩入口。
- 归档均由`.gdignore`隔离，GDScript按文本封存，不含私有工程、profile、缓存或玩家数据；复现时按README恢复到新的忽略路径，已存在不覆盖。

## 2026-09-07 Steam 成就与工坊

- `scripts/steam_*.gd`、`scripts/workshop_*.gd`：成就目录/状态/官方模式/Steam 适配、工坊数据校验/服务/示例及共享面板。
- `assets/ui/achievements/`：60 张 256×256 生产图标及导入侧车；矢量原文和后台清单位于 `tools/contracts/steam/`。
- `vendor/godotsteam/`：固定版本 Windows x86_64 依赖、许可证、上游原文和逐文件 SHA；`.gdignore` 防止普通源工程加载。
- `tools/run_steam_integration_qa.py`、`tools/build_steam_candidate.py`：隔离 QA 和 Windows Steam 候选导出入口；辅助 GD 均排除出包。
- `docs/STEAM_INTEGRATION_20260907.md`、`qa/steam_integration_20260907/`：产品规则、后台待执行清单、真实离线/原生/界面证据与失败轮。
- `.godot/steam_integration_qa/`、`.godot/steam_candidates/`：仅本机私有工程、用户目录、缓存和候选 EXE/DLL，不提交 Git。

## 2026-09-07 Steam 商店与公告素材

- `marketing/steam_store_20260907/`：四种商店封面、三种库图、生成来源/提示词/哈希、复现脚本与中英文介绍；只把交付图拖入Steam，源图及失败证据不投放。
- `marketing/steam_store_20260907/video/`：45秒1080p宣传片、五张原生截图、时间线、录制脚本、来源摘要与音画检查；不含原始电影或玩家数据。
- `docs/STEAM_STORE_MEDIA_20260907.md`、`qa/steam_store_media_20260907/`：本地美术QA、已发布文案/标签与待上传素材的分项收据。
- `docs/STEAM_ANNOUNCEMENT_20260907.md`、`qa/steam_announcement_20260907/`：另一发布任务的9月7日玩家公告与公开回读，事件708907988310558255，关联Build25154403。
- `marketing/.gdignore` 隔离营销素材；原始电影、录制用户目录留在忽略的 `.godot/steam_store_media_20260907/`，不上传Git。

## 2026-09-07 Steam Windows 更新证据

- `docs/STEAM_UPDATE_20260907.md`：本轮已上线Windows包、功能变化、验证范围和Steam状态。
- `qa/steam_update_20260907/`：逐文件归档、437项资源、11次短测、61项设置复验、3图、原QA失败和发布收据；不含成品、缓存或profile。
- `.godot/steam_update_20260907/windows/`：仅本地EXE与已校验ZIP，不进入Git。

## 2026-09-07 迷雾与临时侦察数据

- `docs/RUN_BATTLE_FOG_20260907.md`：五个迷雾值与真实地图宽高、182条实测、完整恢复延期范围。
- `qa/run_battle_fog_20260907/`：本轮报告/日志/来源、实际进程与私有路径收据、独立复核及精确归档清单。
- `tools/contracts/run_battle_fog_20260907/`：受测适配器/QA/pins、原准备说明和冻结controller/helper；按README恢复后复验，不参与生产启动。

## 2026-09-07 Unit 局部恢复数据与四段诊断

- `docs/RUN_UNIT_REFERENCES_20260907.md`、`qa/run_unit_references_20260907/`：14 直接引用、两个数组、七类命令队列；原两次失败、五键修复、162 条实测与原路径复现说明。
- `docs/RUN_INVENTORY_VALUES_20260907.md`、`qa/run_inventory_values_20260906/`、`tools/contracts/run_inventory_values_20260906/`：HeroInventory 五个局部声明值、155 条实测、精确旧 controller/helper 与源合同。
- `qa/unit_body_sections_20260906/`：冻结源 11 文件、插桩/反向还原、导入/两场原始 M1 和逐步报告、分析及 100 组独立审阅条件；结果追加到 `docs/PHYSICS_COST_20260906.md`。
- 所有草稿以忽略目录或文本名归档；不包含玩家数据、引擎缓存/程序、实际私有工程或导出安装包。新增说明不改变启动入口。

## 2026-09-06 R01 与续玩基础值模块

- `scripts/run_state_value_codec.gd`：已受测、无 Autoload 的显式基础值编码模块，尚无 Battle 调用方。
- `docs/RUN_STATE_VALUES_20260906.md`：类型/位/有界契约、341 项当前验收、旧 NUL 诊断与尚未完成的战斗接入；`docs/RUN_SAVE_FOUNDATION_20260906.md` 追加 R01 范围。
- `qa/run_save_recovery_20260906/`：R01 草稿原文、1,625 条断言的实际报告/退出收据、29 次快照调用摘要与原路径恢复说明；三份 `.gd` 以 `.gd.txt` 保存。
- `tools/contracts/run_state_values_20260906/`：值模块/QA/小项目三文件原文、私有恢复名称与 raw pins，不新增公共 runner。
- `qa/run_state_values_20260906/`：341 项通过的新轮、旧 340 项 Unicode 诊断、修复前驱动、准备/晋级收据与独立摘要。
- 三个归档根均保留固定 `.gdignore` 与 raw 换行属性，不含私有 project/profile、实际 fixture、玩家数据或 Godot 缓存。

- `docs/FIRST_USE_20260906.md`：首次加载归因、V2完整区间统计和预加载短对照的取舍。
- `qa/first_use_20260906/`：准备/导入记录、375事件原始报告、同钟V2分析和独立复核，GD与配置按文本封存。
- `qa/animation_preload_20260906/`：同源none/current_units各10秒原始报告与候选源码；没有生产预加载入口。
- `docs/RUN_UNIT_VALUES_20260906.md`、`qa/run_unit_values_20260906/`：272声明字段的分类、真实Unit值采集/验证草稿、77项实际QA及恢复原路径说明；尚无战斗恢复赋值。

## 2026-09-06 续玩基础与分离诊断

- `docs/RUN_SAVE_FOUNDATION_20260906.md`：被测磁盘协议、49案例、历史失败及未接生产的边界。
- `tools/contracts/run_save_store_draft_20260906/`：实测store、QA与runner原文、raw摘要及新checkout复现说明；GD按文本封存。
- `qa/run_save_store_20260906/`：当前五场完整运行、历史失败、空摘要修复和白名单复制收据。
- `qa/separation_sections_20260906/`：4baafc1分离内部10秒配对诊断、实际生成源、严格同钟分析、导入失败与后续恢复收据。
- 两份QA和草稿合同有 `.gdignore` 与局部raw换行属性；均不含私有用户目录、fixture文件、Godot缓存或引擎。

## 2026-09-06 持续打磨 M2C

- `docs/REDUCED_EFFECTS_20260906.md`、`docs/PHYSICS_COST_20260906.md`：可选特效、独立错误修复、同源性能结果与物理热点诊断。
- `tools/run_reduced_effects_qa.py`、`tools/reduced_effects_qa.gd`、`tools/reduced_effects_ui_qa.gd`、`tools/contracts/reduced_effects/`：可复用私有用户目录行为/GUI/旧Settings入口与冻结旧源。
- `qa/reduced_effects_20260906/`：公共最终复验、12个正式窗口、图片审阅、原始类缺陷对照、开发失败尝试及来源收据。
- `qa/physics_cost_20260906/`：完整回调、原生分项、控制/计时配对窗口、实际生成驱动/账本和精确恢复收据。两QA目录均以 `.gdignore` 隔离，归档GD为文本；不含私有玩家文件和引擎缓存。
## 2026-09-06 持续打磨 M2B

- `docs/REDRAW_REJECT_20260906.md`：重绘提前拒绝、状态/像素/计时证据、12个正式窗口及未达性能门槛。
- `tools/prepare_redraw_reject_validation.py`、`tools/redraw_reject_validation_base.gd`、`tools/redraw_reject_qa.gd`、`tools/redraw_reject_timing.gd`：可复用准备/全范围来源复核/真实渲染与函数计时；不改生产源。
- `tools/contracts/redraw_reject/`：e516c83两段完整旧方法、旧/新方法哈希和命令说明。
- `qa/redraw_reject_20260906/`：局部诊断、正式重复窗口、最终公共工具复验及单列旧失败；生成诊断代码存为文本，原始字节SHA清单与 `.gdignore` 隔离。

## 2026-09-06 持续打磨 M2A

- `docs/POLISH_FEEDBACK_20260906.md`：野猪林与祝家庄操作/失败反馈、边界和335项最终结果。
- `tools/yezhulin_feedback_qa.gd`、`tools/zhujiazhuang_feedback_qa.gd`：输入、文案、布局及败北专项；临时输出在忽略的 `.godot/`。
- `qa/polish_feedback_20260906/`：最终报告、日志、截图、逐文件哈希及单列旧QA失败/留图问题；目录排除Godot扫描。

## 2026-09-06 持续打磨首批

- `docs/POLISH_ROADMAP_20260906.md`：完整路线、指标、当前里程碑及持续目标结束条件。
- `docs/POLISH_BASELINE_20260906.md`、`qa/polish_baseline_20260906/`：测试入口修复、15个60秒基线、原始分段/图像/日志和失败记录；QA目录排除Godot扫描。
- `docs/PLAYTEST_CHECKLIST_20260906.md`：至少三名首次玩家、八关、驻守、续玩、动作和两电脑验收，真人结果全部待测。
- `tools/run_polish_performance.py`、`tools/polish_performance_probe.gd`：串行真实渲染、来源与环境受控的统计采样。
- `tools/analyze_polish_performance.py`：全部10秒墙钟分段诊断；临时输出位于忽略目录 `.godot/polish_performance/`。

## 2026-09-06 Steam Windows 更新证据

- `docs/STEAM_UPDATE_20260906.md`：PR合并、冻结源、包身份、验证范围与Steam实际状态入口。
- `docs/UPDATE_ANNOUNCEMENT_20260906.md`：简短玩家更新公告文案。
- `qa/steam_update_20260906/`：50份白名单构建/包内检查/实际EXE测试/Vulkan图片证据，逐文件哈希清单及根任务合并/发布收据；`.gdignore`排除Godot常规扫描。
- `.godot/steam_update_20260906/`：本机忽略的冻结源码、副本、导出EXE/ZIP和隔离用户目录，不进入Git。

## 2026-09-06 统一状态入口

- `docs/PROJECT_STATUS.md`：当前版本、八关实现、近期反馈、四向覆盖、验收缺口和后续顺序。
- `docs/UNIFIED_SNAPSHOT_20260906.md`、`qa/unified_20260906/`：两会话整合、1,729项验证、实际截图与输入收据。
- `docs/RELEASE_READINESS_20260905.md`：当前可售门槛；`docs/RELEASE_READINESS_HISTORY_20260906.md`保留本轮整理前的完整历史快照。
- `tools/directional_frame_scale_qa.gd`：每帧身体比例与脚锚的实际像素测试。
- `tools/contracts/sun_li_direction4_draft_20260906/`：尚未接入的36次原生生成、便携来源清单、7张姿势参考和原型；`.gdignore`防止常规资源扫描。

## 2026-09-06 索敌候选增量

- `tools/enemy_candidates_qa.gd`、`tools/contracts/enemy_candidates/`：查询顺序/实时阵营/完整目标行为与旧方法冻结参考。
- `docs/ENEMY_CANDIDATES_20260906.md`、`qa/enemy_candidates_20260906/`：450 项验证、正常压力、实际查询分布、初步诊断和原始来源收据。

## 2026-09-06 重绘帧号增量

- `tools/redraw_stamp_qa.gd`、`tools/redraw_stamp_timing.gd`：旧/新请求方法的真实渲染生命周期与物理回调耗时。
- `tools/contracts/redraw_stamp/`：68a9430 完整方法与原始字节保护。
- `docs/REDRAW_STAMP_20260906.md`、`qa/redraw_stamp_20260906/`：247 项行为验证、实际图片、配对计时、正常压力和未采用移动候选诊断。

## 2026-09-06 兵群导航复用增量

- `tools/crowd_nav_qa.gd`：完整分离、精度/封格修改、初始格查询成本与配对计时。
- `tools/contracts/crowd_nav/`：9c19c93 完整求解器、分派及字节保护属性。
- `docs/CROWD_NAV_20260906.md`、`qa/crowd_nav_20260906/`：实现、868 项整合验证、正常压力、未采用方案和来源收据。

## 2026-09-06 林冲四向素材与证据

- `assets/characters/lin_chong_direction4_20260906/`：7张原生RGBA与导入配置。
- `assets/anim/lin_chong_<动作>_<方向>.tres`：20个基础五状态排帧；`assets/direction4/lin_chong_20260906.json`：来源哈希/实际导入尺寸/区域/脚锚/顺序。
- `tools/build_directional_spriteframes.py`、`tools/directional_character_sources.py`：通用排帧复核/写入与只读来源审计；`tools/lin_chong_direction4_qa.gd`：资源、实际命令和绘制验证。
- `tools/contracts/lin_chong_direction4_20260906/`：实际提示词、被采用的原生参考链、三维迈步参考生成代码和姿态配方，`.gdignore`排除常规资源扫描。
- `docs/LIN_CHONG_DIRECTION4_20260906.md`、`qa/lin_chong_direction4_20260906/`：实现范围、实际截图/回归/全库盘点/输入收据。

## 2026-09-06 追击速度增量

- `tools/chase_speed_qa.gd`：完整旧/新追击函数的判断、真实移动、速度调用与配对计时。
- `tools/contracts/chase_speed/`：69125b3 完整追击函数和原始字节保护。
- `docs/CHASE_SPEED_20260906.md`、`qa/chase_speed_20260906/`：实现、339 项验证、真实状态计数、恢复证据、正常压力图及来源收据。

## 2026-09-06 网格重建投影增量

- `tools/grid_build_qa.gd`：旧完整函数与现版的网格/层级/可见性/查询及 19 组配对计时。
- `tools/contracts/grid_build/before_877e713.txt`：旧函数冻结参照。
- `docs/GRID_BUILD_20260906.md`、`qa/grid_build_20260906/`：实现、741 项最终组合验证、实际压力图、诊断和来源收据。

## 2026-09-06 战役死亡造型证据

- `tools/campaign_terminal_costume_qa.gd`、`tools/campaign_terminal_visual_unit.gd`：终态来源/缓存隔离、实际致命伤和Unit绘制观察。
- `docs/CAMPAIGN_TERMINAL_COSTUME_20260906.md`：缺图策略、复现与未完成范围。
- `qa/campaign_terminal_costume_20260906/`：旧Art控制脚本、失败/通过画面、回归、覆盖摘要及来源收据；`.gdignore`排除常规资源扫描。

## 2026-09-06 AI 决策时序增量

- `tools/ai_schedule_qa.gd`：生产生成/派发的轨迹、资格、暂停与分段清理验证。
- `docs/AI_SCHEDULE_20260906.md`：装饰对象依赖原因、修复边界、验证和性能限制。
- `qa/ai_schedule_20260906/`：327 项报告、完整决策轨迹、真实压力图、固定渲染/前后控制/插桩诊断与来源哈希。临时诊断驱动以 `.txt` 保存，目录有 `.gdignore`。

## 2026-09-06 寨墙整合证据

`qa/wall_visibility_20260906/integration/` 保存 9739fbe 整合后的 322 项报告、入口精确合并校验、门楼/墙图、正常压力及隔离运行与源码恢复收据。根 QA 目录保留整合前证据，最终状态见 integration/README.md。

## 2026-09-06 寨墙遮挡检查增量

- `tools/wall_visibility_qa.gd`：旧版完整入口对照、边界/实际士兵命中、图片及七组配对计时。
- `tools/contracts/wall_visibility/`：2ea8c69 完整入口冻结参照。
- `docs/WALL_VISIBILITY_20260906.md`：算法边界、验证与复现。
- `qa/wall_visibility_20260906/`：最终渲染/无画面报告、四张遮挡/恢复图、墙体回归、正常压力、诊断及来源收据。

## 2026-09-06 木墙方向增量

- `tools/wall_direction_qa.gd`：六种方向/坡度的真实像素对照与三地图比例验证。
- `docs/WALL_DIRECTION_20260906.md`、`qa/wall_direction_20260906/`：实现、失败/通过日志、前后画面和输入收据。

## 2026-09-06 邻居筛选增量

- `tools/crowd_neighbor_qa.gd`：完整派发、人数/状态/桶序边界及独立候选计数。
- `tools/contracts/crowd_neighbors/`：5457de7已缓冲算法的完整冻结参照。
- `docs/CROWD_NEIGHBORS_20260906.md`：实现、计时边界与复现。
- `qa/crowd_neighbors_20260906/`：99项位置回归、导航/接应/新门楼整合、正常战斗、未采用候选及原始诊断和收据。

## 2026-09-06 祝家庄原生门楼增量

- `assets/campaign/objects/zhu_gate_native_20260906_default.png`：带原生alpha的生产门楼及标准导入侧车。
- `tools/contracts/zhu_gate_native_20260906/`：四次内置生成的完整提示词、三张中间原图、引用和SHA链。
- `tools/zhujiazhuang_gate_art_qa.gd`、`tools/zhujiazhuang_gate_sources.py`：实机锚点/隔离与只读来源审计。
- `docs/ZHU_GATE_NATIVE_20260906.md`、`qa/zhu_gate_native_20260906/`：实现、前后图、日志和收据。

## 2026-09-06 单位重绘增量

- `tools/unit_redraw_qa.gd`：真实物理追帧、双视口像素和生命周期验证；`tools/unit_redraw_stress.gd`：无计时包装的实战窗口。
- `tools/contracts/unit_redraw/`：57e2512直接重绘参照及边界说明。
- `docs/UNIT_REDRAW_20260906.md`：实现、计时限制及复现。
- `qa/unit_redraw_20260906/`：原始逐帧诊断、42项像素/生命周期、动作/剧情/菜单回归、实战窗口和哈希收据。

## 2026-09-06 宋江四向

- `assets/characters/song_jiang_direction4_20260906/`：15张原生透明生产图及Godot导入设置；`assets/anim/song_jiang_*_<方向>.tres`：16个排帧资源。
- `assets/direction4/song_jiang_20260906.json`：生产采样/对齐/导入清单；`tools/contracts/song_jiang_direction4_20260906/`：真实提示词、来源链、参考图及资源配置过程。
- `tools/song_jiang_direction4_qa.gd`、`tools/song_jiang_direction4_sources.py`：实际动作与只读来源验证；`qa/song_jiang_direction4_20260906/`：最终证据。
- `docs/SONG_JIANG_DIRECTION4_20260906.md`：当前内容和复现；全库与驻守审计新增TRES识别并默认写入 `.godot/`。

## 2026-09-06 芦苇重建增量

- `tools/reed_mesh_qa.gd` / `tools/reed_mesh_render_probe.gd`：八关网格、查询计数和真实渲染配对。
- `tools/contracts/reeds/`：4e4665c旧函数、固定哈希和来源。
- `docs/REED_MESH_20260906.md`：实现、复现与限制。
- `qa/reed_mesh_20260906/`：原结果、树冠回归、渲染/战斗窗口、七机位及收据；重跑结果在 `.godot/`。

## 2026-09-06 树冠遮挡增量

- `tools/canopy_visibility_qa.gd`：八关真实场景、边界及旧新配对验证。
- `tools/contracts/canopy/`：2b14c2a旧循环、固定哈希和来源说明。
- `docs/CANOPY_VISIBILITY_20260906.md`：实现、复现和性能限制。
- `qa/canopy_visibility_20260906/`：98项报告、阶段诊断、七机位画面、最终压力窗口与收据；重跑输出在 `.godot/`。

## 2026-09-06 门墙衔接增量

- `docs/WALL_JOIN_POLISH_20260906.md`：祝家庄栅顶与色调校准、适用范围及复现。
- `qa/wall_join_polish_20260906/`：同机位前后截图、最终墙体/接应日志与关键输入收据。

# 水浒项目目录索引

密集分离：`scripts/crowd_separation.gd`、`tools/crowd_buffer_qa.gd`、`docs/CROWD_BUFFER_20260906.md`；当前旧函数在 `tools/contracts/separation/before_4589c85.txt`，审核证据 `qa/crowd_buffer_20260906/`，临时输出 `.godot/crowd_buffer_qa/`。

密集分离与寨墙修正的223项整合报告及独立输入收据在 `qa/crowd_buffer_20260906/integration/`。

端点转换：`docs/SEGMENT_ENDPOINT_20260906.md`、`tools/segment_endpoint_qa.gd`；增量旧函数在 `tools/contracts/navigation/segment_before_66d27aa.txt`，审核证据在 `qa/segment_endpoint_20260906/`，重跑输出 `.godot/segment_endpoint_qa/`。

端点优化与快活林整合的175项报告及独立输入收据位于 `qa/segment_endpoint_20260906/integration/`，不覆盖两批原报告。

2026-09-06 快活林当前入口：`scripts/levels/level7_kuaihuolin_short.gd`；验证 `tools/kuaihuolin_short_test.gd`、`kuaihuolin_short_boundaries.gd`、`kuaihuolin_short_ui_test.gd`，旧深度工具为当前边界兼容入口。说明 `docs/KUAIHUOLIN_SHORT_20260906.md`，证据 `qa/kuaihuolin_short_20260906/`，临时输出 `.godot/kuaihuolin_short/`。

拥挤分离：`docs/CROWD_SEPARATION_20260906.md`、`tools/crowd_separation_qa.gd`；冻结旧函数在 `tools/contracts/separation/`（`.gdignore`），审核证据在 `qa/crowd_separation_20260906/`，重跑输出 `.godot/crowd_separation_qa/`。

路径检查：`docs/SEGMENT_NAVIGATION_20260906.md`、`tools/segment_navigation_qa.gd`、`tools/rts_collision_profile.gd`；旧函数参考在 `tools/contracts/navigation/`，本批证据在 `qa/segment_navigation_20260906/`，重跑输出 `.godot/segment_navigation_qa/`。

2026-09-06 黄泥冈当前短篇新增：`scripts/levels/level1_huangnigang_short.gd`、`tools/huangnigang_short_test.gd`、`tools/huangnigang_short_ui_test.gd`、`docs/HUANGNIGANG_SHORT_20260906.md`、`qa/huangnigang_short_20260906/`。原生透明纲担在 `assets/campaign/objects/tribute_load_alpha_20260906_default.png`，原输出即生产字节；完整提示词与来源在 `tools/contracts/huangnigang_tribute_20260906/`，旧环境图及历史69项清单不覆盖。

暂停操作：`docs/PAUSE_MENU_20260906.md`、`tools/pause_menu_qa.gd`；最终证据在 `qa/pause_menu_20260906/`，重跑输出在 `.godot/pause_menu_qa/`。

地表透明缝：`docs/TERRAIN_ALPHA_SEAMS_20260906.md`、`tools/terrain_alpha_seam_probe.gd` 与 `tools/terrain_alpha_seam_qa.gd`；旧shader原字节固定在 `tools/contracts/terrain_seams/`（`.gdignore`），审核证据在 `qa/terrain_alpha_seams_20260906/`，临时结果在 `.godot/terrain_seam_probe/`、`.godot/terrain_alpha_seam_qa/`。

田地增量：生产图 `assets/campaign/environment/shared/surfaces/surface_field.png`；独立来源在 `tools/contracts/environment/field_20260906/`（原图/提示词/接入/固定SHA审核增量，含 `.gdignore`）。`tools/environment_field_render_qa.gd` 为真实两关对照；`docs/ENVIRONMENT_FIELD_20260906.md` 和 `qa/environment_field_20260906/` 保存说明、证据及失败尝试。

野猪林短篇：`docs/YEZHULIN_SHORT_20260906.md`记录当前合同2；`tools/yezhulin_short_test.gd`覆盖实际四路线及独立边界，旧`campaign_yezhulin_depth_test.gd`为兼容入口。临时结果在`.godot/yezhulin_short/`，本批证据在`qa/yezhulin_short_20260906/`。

江州当前入口：`scripts/levels/level2_jiangzhou_rts.gd`，说明 `docs/JIANGZHOU_RTS_20260906.md`；旧 `level2_jiangzhou.gd`保留地图来源。`tools/jiangzhou_rts_test.gd`、`tools/jiangzhou_rts_play.gd`、`tools/jiangzhou_rts_visual.gd`分别验证边界、真实两路线和界面/地图；临时结果在 `.godot/jiangzhou_rts/`，已审核证据在 `qa/jiangzhou_rts_20260906/`。

更新日期：2026-09-06（Asia/Hong_Kong）。

## Git checkout 目录（家里接续）

Git 克隆版以仓库根目录为工程根：`project.godot`、`assets/`、`scripts/`、`scenes/`、`tools/` 和 `qa/` 直接位于根下，交接文档统一在 `docs/`。下文“根目录约定”和迁移映射记录的是办公室外层工作区，不能照此在 clone 内再建立 `Liangshan-Heroes/`。

- `Play.cmd`、`tools/run_local.ps1`：源码游戏、编辑器及导入入口。
- `tools/resolve_godot.ps1`：共享 Godot 4.6.3 路径解析；`godot.local.txt` 为每台电脑独立配置，不入库。
- `qa/home_setup_20260905/`：本机接续日志、动作检查报告和主菜单截图。
- `.godot/`：本机导入缓存及临时验证文件，不入库。
- `tools/environment_art_audit.py`、`tools/environment_validation_selftest.py`、`tools/environment_validation_common.py`：环境生产/来源审计、隔离反例与跨电脑路径处理。
- `tools/contracts/environment/`：生产字节与来源缺口清单；`legacy/`记录待恢复历史原件及哈希，固定证据不按缓存处理。
- `docs/ENVIRONMENT_VALIDATION_PORTABILITY_20260906.md`、`qa/environment_validation_20260906/`：本轮入口、缺口、验证记录和输入收据。
- `docs/WORKLOG.md`、`docs/SOURCE_SETUP.md`：当前 Git 开发进度和跨电脑启动说明。
- `docs/WALL_AND_NAVAL_FOUNDATION_20260906.md`：木墙脚点修正与限定关卡启用的造船底层说明。
- `scripts/naval_production.gd`、`tools/naval_production_test.gd`、`tools/naval_production_visual.gd`：泊位、岸边施工、付费下水及取消/重建验证；高俅当前入口显式启用船坞，驻守不启用。
- `tools/wall_alignment_test.gd`、`tools/wall_alignment_visual.gd`、`tools/rts_performance_probe.gd`：墙脚/门接缝/遮挡与实机对照，正常1倍短窗性能采样。
- `qa/wall_naval_20260906/`：本批墙与船坞的通过日志、失败尝试、前后图和输入哈希。
- `docs/CAMPAIGN_FUN_REWORK_20260905.md`：八关总体设计与官方参考；祝家庄、连环马、大名府、高俅及江州补给关已有样板，三个短篇后续实施。
- `docs/GAO_RTS_20260906.md`、`scripts/levels/level5_gao_rts.gd`：当前高俅入口、持续水陆经营、火攻接应和实际押俘回堂。
- `tools/gao_rts_test.gd`、`tools/gao_capture_test.gd`、`tools/gao_rts_play.gd`、`tools/gao_rts_visual.gd`：经济/来源/结局边界，真实两路线与图形/长任务列表验证。
- `qa/gao_rts_20260906/`：高俅最终结果、失败尝试、两尺寸图、实战图和输入哈希；受控夹具与实战分别记录。
- `docs/DAMING_RTS_20260905.md`、`scripts/levels/level8_daming_rts.gd`：大名府当前入口、经营/潜入/火号/护送说明；旧level8脚本保留地图来源。
- `tools/daming_rts_test.gd`、`tools/daming_infiltration_test.gd`、`tools/ranged_firing_path_test.gd`、`tools/daming_rts_visual.gd`：两条实战、输入边界、隔墙远程接近和图形验证。
- `qa/daming_rts_20260905/`：本轮结果、失败尝试、截图与输入哈希收据，包含其他关卡回归的独立子目录。
- `docs/LIANHUANMA_RTS_20260905.md`、`scripts/levels/level4_lianhuanma_rts.gd`：当前连环马菜单入口、持续经营/反骑/辎重营与教场说明；旧level4脚本保留作历史参考。
- `tools/lianhuanma_rts_test.gd`、`tools/lianhuanma_drill_test.gd`、`tools/lianhuanma_rts_visual.gd`：本关边界、两条实战、教场输入及图形验证。
- `qa/lianhuanma_rts_20260905/`：最终182项、三张图、输入哈希；attempts保留失败尝试，不属于最终通过项。
- `docs/RELEASE_READINESS_20260905.md`：首个可售版本的当前证据、缺口与后续验收，未宣称已经达到发行质量。
- `docs/ZHUJIAZHUANG_RTS_20260905.md`：祝家庄 RTS 样板玩法、实现边界及验证入口。
- `scripts/levels/level3_zhujiazhuang_rts.gd`：当前祝家庄菜单入口；旧 `level3_zhujiazhuang.gd` 保留作原流程参考。
- `tools/zhujiazhuang_rts_test.gd`、`tools/zhujiazhuang_rts_visual.gd`：场内回归、真实自动路线与图形检查。
- `qa/zhujiazhuang_rts_20260905/`：本轮验证结果、图形截图与文件收据。
- `tools/zhujiazhuang_rts_feedback_test.gd`、`tools/zhujiazhuang_rts_gate_visual.gd`：守军接敌/施法回归、双英雄冲关对照及寨门轴向截图。
- `qa/zhujiazhuang_rts_feedback_20260905/`：试玩问题复现与修复后的路线、守军和门体对照记录；不覆盖初版样板证据。
- `scripts/campaign_gate_visual.gd`：按原图墙脚锚定门墙连接与阴影；祝家庄两门和大名府南门分别显式配置，大名府另有关闭门扇。
- `tools/zhujiazhuang_gate_contact_test.gd`、`tools/zhujiazhuang_gate_contact_visual.gd`：群选接应回归与门墙/开门图形检查。
- `qa/zhujiazhuang_gate_contact_20260905/`：本轮门墙、接应、路线与跨模式QA。
- `tools/character_direction4_inventory.gd`、`docs/CHARACTER_DIRECTION4_20260905.md`：全库角色四向清单生成与制作状态。
- `qa/character_direction4_inventory_20260905/`：逐key缺口和首批被拒收候选；候选目录不属于生产素材。

## 2026-09-05 测试上传与 GitHub 接入

- `Liangshan-Heroes/qa/steam_test_build_20260905/`：本轮冻结输入清单、成品专项、Steam 上传与 GitHub 同步收据。
- `Liangshan-Heroes/docs/STEAM_TEST_BUILD_20260905.md`：构建 `25136463` 已成为 public/default，SteamCMD 强制刷新回读确认；远端回下载和客户端状态分别记录，不再把旧 `25121101` 当作当前包。
- `<server_verify>`：本轮服务器隔离回下载验证目录，appmanifest、EXE 哈希与主菜单启动已通过，证据为 `Liangshan-Heroes/qa/steam_test_build_20260905/server_download_verified.json`；不是玩家 Steam 库或开发主目录。
- `<frozen_project_snapshot>`：2364 文件独立只读测试输入快照；不是新的开发主目录。
- `<steam_build>\windows`：仅一份可上传的游戏 EXE；禁止上传开发工程、QA 或凭据。
- `<fresh_clone>`：本轮 GitHub 同步专用 checkout；开发工程仍保持原位置。目标分支 `codex/sync-20260905-stable`、PR #1，代码/素材提交 `863fcf0` 已回读，main 未变。
- 上一轮临时 Git index 混合状态不作同步依据；没有删除或搬动任何现有工程。

## 根目录约定

| 路径 | 用途 | 处理规则 |
| --- | --- | --- |
| `Liangshan-Heroes/` | 当前 Godot 开发工程 | 保持原路径；源码、生产素材、项目内 QA 均从这里运行 |
| `implementation_20260902/` | 当前工具仍读取的网页来源、候选与改前备份 | 暂不移动；改路径前必须同步工具和清单 |
| `implementation_20260903/` | 9 月 3 日仍被生产清单引用的实施证据 | 暂不移动；完成来源闭环后再归档 |
| `_design/` | 视觉设计源、已批准基线与未接入草稿 | 概念图不直接作生产贴图；接入状态以各批 manifest 为准 |
| `_archive/` | 只读历史快照、基线、旧发布候选和原始包 | 不作为当前生产输入；不得用旧证据宣称当前完成 |
| `_logs/` | 根目录级工具和导入日志 | 可再生成日志可按批次清理 |
| 根目录 `*.md` | 当前交接、进度、设计原则和本索引 | 每轮目录或完成度变化后同步更新 |
| 根目录 `*.cmd` | 当前开发/预览入口 | 必须指向现行目录，不指向已迁移旧路径 |
| `AGENTS.md` | 项目协作与每轮收尾规范 | 开发完成后更新相关项目文档，并向已确认的 GitHub 目标同步；未配置目标时明确报告阻塞 |

## 当前结构

```text
水浒/
├─ Liangshan-Heroes/             当前 Godot 工程
├─ implementation_20260902/      活动实施来源与备份
├─ implementation_20260903/      活动实施证据
├─ _design/
│  └─ ui_design_20260902/        已接入的“克制宋韵”UI视觉基线
├─ _archive/
│  ├─ baselines/                 历史哈希与需求基线
│  ├─ campaign_history/          环境和战役重做历史批次
│  ├─ release_candidates/        旧发布候选
│  ├─ source_packages/           原始下载包
│  └─ visual_samples/            v1-v7 视觉迭代与源码备份
└─ _logs/                         根目录日志
```

## 2026-09-03 迁移映射

- `art_requirements_baseline_20260902_024451/` → `_archive/baselines/art_requirements_baseline_20260902_024451/`
- `campaign_environment_v8_20260831/` → `_archive/campaign_history/campaign_environment_v8_20260831/`
- `campaign_rework_20260831_173850/` → `_archive/campaign_history/campaign_rework_20260831_173850/`
- `release_candidate_20260901_134110/` → `_archive/release_candidates/release_candidate_20260901_134110/`
- `visual_sample_20260831/` 至 `visual_sample_v7_20260831/` → `_archive/visual_samples/`
- `Liangshan-Heroes-0109b6f-complete.zip` → `_archive/source_packages/`
- `ui_design_20260902/` → `_design/ui_design_20260902/`
- `godot-import.log` → `_logs/godot-import.log`

历史 QA 快照中记录的旧绝对路径保持原文，以免篡改当时证据；读取这些快照时按本表转换。当前入口文档、预览启动器和仍会读取战役基线的审计工具已经改为新路径。

## 后续新增规则

1. 当前可执行工程只放在 `Liangshan-Heroes/`，不要在工程内部嵌套另一份 Godot 工程。
2. 新网页原图、候选和改前备份按日期进入一个 `implementation_YYYYMMDD/`，不要散落根目录。
3. 结束且不再被工具读取的实施批次，完整迁入 `_archive/implementation_history/`，同时更新本索引和活动工具路径。
4. 新视觉对比放入 `_archive/visual_samples/<批次名>/`，不要再创建新的根目录 `visual_sample_*`。
5. 新发布候选放入 `_archive/release_candidates/<批次名>/`；Steam 发布目录仍与本工作区隔离。
