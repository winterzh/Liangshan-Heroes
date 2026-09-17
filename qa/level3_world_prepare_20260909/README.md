# 祝家庄世界恢复设计候选交接

**状态：未原生解析、未应用、未接入、未验收。** 本目录只归档两份工程外设计草稿，供 GitHub 后续开发交接；不计入生产功能完成度、八关续玩验收或 Steam 发布。

原始草稿继续保存在 `D:/CodexTemp/level3_world_prepare_20260909/` 及其 `unit_state_draft/`。本批未运行 Godot/Git，未改生产脚本、资源或项目设置。目录含 `.gdignore`，三份候选源码使用 `.gd.txt` 扩展名，不能作为运行脚本加载。补丁只有设计用途，不应自动应用。

## 两份候选

| 候选 | 内容 | 审阅文件 |
| --- | --- | --- |
| 官方选型与 Level3 纯工厂 | 固定 classic30/官方 Level3 上下文；安装内容与脚本身份；纯运行定义/关卡值恢复，不部署、不重发任务或奖励 | [补丁](level3_profile_factory.patch)、[世界接入方案](reviews/world_preparation_notes.md)、[独立地图与关卡审查](reviews/level3_map_review.md) |
| Level3 UnitState 状态契约 | 保持 classic 拒绝章节状态；用可信 Level 角色 ID 和独立 schema 约束囚徒/获救者、captured 扈三娘及 retreated 偏门 | [补丁](run_unit_state_level3.patch)、[规则与待测矩阵](reviews/unit_state_notes.md)、[独立状态转移审查](reviews/unit_transition_review.md) |

候选全文为 [官方 profile](candidates/run_official_restore_profile.gd.txt)、[纯工厂](candidates/run_level3_world_factory.gd.txt)、[UnitState](candidates/run_unit_state.gd.txt)。它们分别对应补丁的目标文件；未调用 Core、Battle、Unit 或玩家入口。现有 UnitGraph 也还没有接入新上下文/角色参数。

## 来源与后续代码漂移

[世界准备来源](provenance/world_prepare_source_manifest.json)保存准备时 35 份源码；[单位状态来源](provenance/unit_state_source_manifest.json)保存准备时 7 份源码。这些是**准备时来源清单，不是当前冻结版或测试通过证明**。原清单中的 `repository_written=false` 等字段仅描述工程外准备阶段；本批新增本候选目录和专用说明，不更改原清单的历史含义。

根任务随后已修改 WorldCore 的 ward 序号恢复顺序：先验证 Root 状态并安装 `_ward_serial`，再准备 visual/effects。首次世界清单记录 Core SHA-256 `8313e756d9fb62c37ba3ea4d88341cd46aeeb7020018b7a09619136e55dcde8c`；归档时只读取得 `21d4e0e93faed9a97c78ba396c17204651a2ef03134c602f67e7cf6940e01e7e`。旧方案里有关 Core 构造顺序的文字必须结合这项修复复核，不能用草稿覆盖后续实现。

槽规范以当前 **`classic_continue_slot_v3`** 为准，保留 `session_settings.auto_micro_level` 及现有 OPTIONS/CAS/待写事务语义。不得退回早期 v2 方案或丢失 settings。schema、内容身份或依赖顺序不匹配时保留原存档并拒绝，不猜迁移。

[归档映射](archive_manifest.json)逐项列出 11 个拷贝的原路径、归档路径、大小与 SHA-256；均为原字节副本。原说明中出现的相对路径及生成器名属于工程外目录的历史语境，可用该映射定位本归档副本。生成器/辅助片段继续留在原目录；完整补丁和候选全文已归档。未包含玩家存档、Steam 登录/私有 profile 或导出安装包。

## 验证边界与下一步

已完成的是静态接口/状态转移审查、来源哈希和候选拷贝一致性核对；这些不能替代 GDScript 解析与行为验证。真正接入仍缺 CampaignScenery/StorySign、章节 UnitGraph、MissionMarker 与普通特效精确混排、Root/HUD 跨帧安装、Session/receipt 上下文及可重试结算。三十一项 Level 字段覆盖也不等于完整世界恢复。

应用前先核对当前源码与准备时来源，保留根任务后续修复，再在独立冻结版本中串行原生验证。入口继续关闭，九种玩法全部验收后才统一开放。根任务本轮完整经典测试的结果应由其正式 QA 记录证明，本目录不代表该测试结果。
