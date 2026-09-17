# 祝家庄世界恢复：设计候选交接

2026-09-09 将两份工程外草稿归档至 [qa/level3_world_prepare_20260909](../qa/level3_world_prepare_20260909/README.md)，用于 GitHub 后续开发交接。**两份均未原生解析、未应用、未接入、未验收，不计入生产功能完成度。** 原工程外目录保留；本批不运行 Godot/Git，不修改生产运行文件。

- [官方选型与 Level3 纯工厂补丁](../qa/level3_world_prepare_20260909/level3_profile_factory.patch)：固定官方上下文和安装脚本身份，复用现有 31 字段 LevelState，不部署或重发任务/奖励。
- [Level3 UnitState 补丁](../qa/level3_world_prepare_20260909/run_unit_state_level3.patch)：保留 classic 拒绝规则，用可信角色 ID 和独立 schema 描述囚徒/获救者、捕获扈三娘及撤离偏门。尚未接到 UnitGraph。

归档含 `.gdignore`；候选源码均为 `.gd.txt`。两份独立审查、来源清单与 [拷贝哈希映射](../qa/level3_world_prepare_20260909/archive_manifest.json)一并保留；不含真实存档、凭据或私有运行 profile。

来源清单属于准备当时。根任务后来已修复 Core 的 **Root/ward 序号先于 visual/effects 安装**顺序，应用前必须对照当前源码复核，不能覆盖该修复。槽 schema 以 **`classic_continue_slot_v3`** 为准，保留 `session_settings.auto_micro_level` 及现有事务语义，不回退到 v2。

剩余接入依赖为战役景物、章节单位图、marker/特效混排、Root/HUD 跨帧安装，以及 Session、生命周期和结算幂等。完整经典测试由根任务独立记录，本候选目录不代表其运行结果；九种玩法全部通过前，玩家续玩入口继续关闭。
