# 大名府双角色继续候选（2026-10-27，未编译/未运行）

本目录只保存独立候选。底座为已冻结的 941c4786，来源工程 `.godot/campaign_progress_recovery_20261026/20261027_050851_9bd328cf/project/`。没有修改生产、该冻结工程、旧 v25 候选或高俅测试输入；未 prepare、导入、运行 Godot、公开续玩或发布。

## 本次三份增量

- `run_world_session.gd`：只添加固定 `Level8Factory` 和精确 `Profiles.DAMING_CONTEXT` 分支，按安装章节的正常顺序装配定义，再交给 Core。保留此前连环马、高俅分支及所有身份、范围、账号与存档检查。
- `run_level8_unit_contract.gd`：采用旧 v25 受审增量。只有具名卢俊义/石秀、正常解枷且牢门/城门已开、真实 `retreated` 才能进入安全者验证；要求存活、隐藏、被动、取消选择、停止动作/命令/目标、准确出口区域及既有获救身份。保留原 root/active 成员规则。这里的安全者仍是原实体，不能删掉或伪造替身。
- `run_battle_world_core.gd`：只移植两个大名府专用 helper，以及完整捕获返回前、恢复分配 Battle 前的两处调用。逐份验证 Level/UnitGraph/Root/Mission/Presentation 与 casts/item_casts；安全事件和同一具名实体撤离状态必须对应，另一个必需角色仍活着且在完整注册表中，两人都安全不能伪装成可续玩的 FIGHT。解枷动作、事件、阶段和任务 token 均须一致。

旧 v25 Core 不能整件覆盖：941c 新增的黄泥冈 `hg_mission_events` 声明、从已验证 Mission 读取及 `_graph().prepare(..., hg_mission_events)` 第八参数全部保留；当前 `_abort` 实现及其他非大名府内容保持原字节。旧组件资格不转给本组合。

## 固定合同与需要验证的现象

官方 context 只有 `{mode: campaign, level_id: level8, waves: 0}`，profile 为 `campaign_level8_v1`。`first_role=lu` 和 `first_role=shi` 是同一 context 的两条路线，不是两个新 context。

实际 `level8_daming_rts.gd` 的故事合同为版本 2：核心目标是守营并使两名囚犯活着出城；三个故事目标是 `daming_infiltration`、`daming_signal`、`daming_response`。后继报告必须读取当前完整目标，不能只核历史 done 数量或捏造阶段。当前底座继续使用 LCv3 / Intentv2 / ACKv2；胜利必须正常 gen1→gen2→CFG 实读→gen3，同 token、同作用域与正确 handoff，败局保持 NOT_REQUIRED/不新增 CFG 的原语义。

最小原生重点是：

1. 正常菜单进入关卡、实际暂停菜单 SaveAndExit、由 AppLifecycle 退出、独立进程通过可见 Continue 按钮恢复。不能把直接 Session 调用授予真实 Flow 资格。
2. 恢复后的运行定义中三名内应和双囚均 `pop=0`、`hero_trainable=false`，hall 生产表及城防覆盖保持正常开局值；同时核旧实体 `setup_def`。旧实体已保存定义可以仍正确，缺少章节装配不等于旧档已损坏。后续正常招募/建造应再检查新实体读取正确定义。
3. 分别让卢俊义、石秀先正常到达出口，保存时只有其对应 safe 事件；恢复后原实体/事件/停止状态保持、不重复通报，第二人仍可自然完成撤离。不得用摆位、伤害、跳阶段、直接终局或合成存活判断代替。
4. 保留组件与整世界负例：错误角色/阶段/出口、残留命令或选择、事件和实体不匹配、另一必需角色缺失或死亡、双安全但仍 FIGHT、错误 token/身份与未知字段均不得被放宽。

## 旧 61 阶段与新资格

旧入口是 `tools/run_durable_campaign_chain_v16.py`：1 冷导入 + 两条角色路线各 ABCD 共 8 个进程 + 52 个负例进程 = 61。它使用旧 LCv2/Intentv1 等结构，并直接给 Session 传 `Level8Factory.prepare_runtime()`；因此不能直接复跑为新来源资格，也不会发现本次真实 Flow runtime 缺口。可复用路线、精确矩阵和标签合同，须明确适配当前严格结构与来源绑定；真实 Flow 路线需要独立覆盖。

封存的 V16 原生观察只证明旧源冷导入、Lu A 315 项、Lu world 264 行/1540 项，观察时 3/61、full=false。原工作/observer 目录目前不存在，不能把旧“运行中”文字解释为今天仍运行，也不能据缺目录推断最终失败或完整成功。closed prior 消费器只有 source-only 初审，未消费完整成功 prior。原 19 类故障、实际错误界面与同对象重试是另外的门槛，61 不等于覆盖原 19 类。

本目录没有新原生结果。后续须另冻统一来源、独立导入，在该来源重验双路线和矩阵，并完成最终统一来源的章节/经典回归；不跨源转授941c高俅190、d7连环马或旧v25/V16结果。公开入口、真实 SDK、导出EXE、人工/性能、完整验收与发布资格均为 false。

## 来源和静态验证

`sources.json` 固定三份941c原件、所借旧v25两份原件、必要的当前依赖、小型冻结元数据、三份候选和逐文件diff。三份候选保留原件 UTF-8 无BOM、LF行尾。静态逆向移除全部声明增量以及独立逆用三个unified diff，均还原941c原始 bytes/SHA；这只是文本/来源验证，不是 GDScript 编译。

| 脚本 | 候选 SHA-256 |
|---|---|
| Session | `247ee293ee486fd35b6dc08406ff664347e9cd7ef4271682352906df61558862` |
| Core | `5cb47d999409d7755c52265521a3ee12118a90efdde3c5fc7c7fa13ada027db1` |
| UnitContract | `b2f52bcce60b27507b498a6d32e45b5cadd3409030fcd2e1024c78dac90e90d5` |
