# CampaignMission 独立状态组件

后续实现说明（2026-09-09）：原先缺少的定位器参数已在正式创建点登记明确 metadata，并新增 [界面/地图标记工厂](CAMPAIGN_PRESENTATION_STATE_20260909.md)，可与本文 Mission token/registry 接口配对。最新 Mission 回归批 `20260909_045557_eb6be9e0` 已通过 **142 项（120 组件＋22 独立重启）**：导入和行为进程退出 0、错误 0，私有 profile 保护预期退出 2、错误 0；2,953 个来源的当前/冻结 SHA 共 5,906 次核验通过。其受测 Mission SHA 为 `6514aa9cd028ab4af513b2349ccd0076104cebc193765203b14e932416b88171`，状态组件 SHA 仍为 `c9ae212121a4ed234f1aff2fc6e9d1c8242a47b70e097eb3d4a7c05fdd2077d5`。该 runner 不包含新 presentation，不能用这 142 项证明新界面工厂或完整世界恢复已通过。

初始组件交付（2026-09-09）新增 `scripts/run_campaign_mission_state.gd`、`tools/campaign_mission_state_qa.gd` 和 `tools/run_campaign_mission_state_qa.py`。历史批 `20260909_033618_46aa9054` 通过 142 项原生行为检查（120＋22）并独立回读；前两次解析失败原样保留。初始组件当时没有修改 `campaign_mission.gd`、Battle、Unit、世界槽或玩家入口；后续 Mission 固定构造 API 的新来源以上方回归批为准，不代表八关已经可以续玩。

## 接口及调用顺序

`context` 必须由安装内容给出，包含且仅包含 `level_id`、`content_version`、`mission_token`、`presentation_token`。关卡只接受当前官方 `level1` 至 `level8`，加载端提供的context与记录必须完全相等；不能从存档读取脚本路径并加载。`mission_token`与关卡Level组件指向同一任务快照，`presentation_token`指向同一批外部UI/标记/本地化绑定记录。

1. `capture(mission, context, id_to_unit, next_entity_id, external_to_token, capture_ticks_msec, boundary)`：调用者先冻结世界、排空延迟任务并捕获外部presentation。`boundary`要求 `deferred_drained=true` 与 `presentation_captured=true`；这些是外层合同输入，**不是本组件对完整屏障或UI捕获的证明**。所有仍存在的外部节点必须注册token，额外地图定位按钮也要保留在按钮顺序中。
2. `validate(record, context, known_unit_ids, next_entity_id, external_tokens)`：纯数据形状、精确类型、时钟、版本、引用、数组顺序、任务状态和冻结结算检查。统计为完成的动作不能仍处于活动状态；缺人物、未知字段、引用别名冲突、错误关卡/版本身份或记录缺项均拒绝。
3. `restore_into(mission, owner, record, context, id_to_unit, next_entity_id, token_to_external, restore_ticks_msec, presentation_restored)`：调用者通过固定可信工厂创建全新Mission及其UI/marker，并恢复外部presentation；本组件检查所有关系后一次性填入状态。owner必须是未挂载的根节点，单位及UI（含原生内部控件）未入树、禁用处理、阻断信号。不能把旧世界的暂停Mission当成新目标。

现有Mission构造器会创建基础面板并连接语言信号；本组件因此接收调用者准备好的实例，**不自行调用构造器或 `begin()`**。可信工厂允许创建相同有序动作和定位按钮，但不能提前运行章节配置、事件或阶段。每个动作按钮的pressed回调必须精确指向新Mission的 `focus_action(action_id)`；定位按钮及本地化render回调也必须属于新Mission，不能沿用旧闭包。基础控件必须属于新面板，按钮顺序、marker顺序和fx根归属必须一致。

所有失败检查先于赋值，失败不写现有Mission的任务值、不移动Unit、不发奖励、不触发UI。成功返回 `complete_world=false`、`events_replayed=0`、`begin_called=false`，并要求外层同帧完成整图安装。`presentation_after_layout`返回展开状态与横纵滚动位置，须在受控挂载和布局完成后应用；离树时直接设置滚动值可能被空范围钳为0，所以这里不假装已经恢复了可见滚动位置。

## 明确保存的语义

- 44个生产声明均由显式清单分类。反射只审计漏项，不自动决定保存字段。值使用现有严格codec，经JSON中转后保留int64、float和Vector2i类型。
- 阶段ID/标题、正文、核心目标、契约版本、总游戏时间、当前阶段游戏时间、命令/重寻路/打断计数及反馈状态。
- `story_goals`、`events`、`actions`转换成显式有序记录，再按顺序重建Dictionary；保留所需/禁止事件、done/missed/pending与note/reason，以及动作可选的actor_button、blocked_reason、settle_margin。
- 活动人物仅以稳定十进制entity ID关联调用者的Unit图；不复制Unit状态或消费玩家命令。人物存在但未注册、已排队删除或活动引用已释放时拒绝，不能把它静默变成空人物。是否等下一个实际任务tick完成中断再保存，由世界屏障协调。
- 动作完成后，生产代码会保留旧 `_progress/_retry` 数值，只有 `active_action_id/_actor`清空；这种空闲状态合法，不清零。活动动作则必须存在、未完成、未阻断且进度小于duration。
- `_stage_started_ms`不直接跨进程复制，保存 `capture_ticks_msec - started_ms`，恢复设为 `restore_ticks_msec - stage_age_ms`。恢复后的锚点可以为负数，这是新进程启动时间短于已经发生的阶段耗时的合法情况；离线时间不计入旧阶段。已关闭阶段的 `wall_seconds`作为历史数值原样保留。
- 冻结 `_result_cache`按已保存目标的顺序和状态独立核对done/missed/pending列表、总数、核心结果和契约版本。冻结结果以及已有victory/defeat终局指标只允许恢复供结果检查，返回 `resume_eligible=false`；世界槽仍必须拒绝将其作为可继续战斗。组件不调用 `result_snapshot()`重新评估、不授予章节成绩或Steam收益。

## 初始外部presentation阻塞与后续进展

初始组件交付时，`add_map_locator()` 的 cell/label 和 `add_actor_locator()` 的 actor_key 只存在于匿名闭包捕获值中，普通 Callable 绑定参数无法安全重建这些值。后续已迁移为显式描述及固定回调；实际界面、滚动、标记和本地化工厂的验证仍由专用 presentation 批次负责。按钮、本地化描述符和 marker 的外部 token，以及 `presentation_captured/restored` 布尔值，始终不能替代完整适配器验收。

初始交付提出的两个共享 API 调整现已实现：固定 locator 种类及参数作为可验证描述登记，由可信工厂重建回调。独立 presentation 最终批 `20260909_050932_4cb652ff` 已通过 348 项组件检查；它不从按钮已翻译文本猜人物/坐标，也不保留旧 Mission 闭包。该结果尚未接入 WorldCore，后续仍需完整世界与全部关卡流程验收。

另外，外层须保存并重建Localize的源文/格式参数/render描述、按钮显隐和禁用、marker视觉状态与地图位置、面板布局和语言刷新生命周期。恢复失败时须清理新面板的全局语言连接及本地化绑定；不能只释放RefCounted而把私有UI或闭包留在全局绑定表。

## 隔离验证入口与当前状态

由主任务确认引擎空闲后在开发工程根执行：

```powershell
py -3.14 -X utf8 -B tools/run_campaign_mission_state_qa.py --run
```

默认不加 `--run`只预检。运行器使用共享锁、全新ASCII工作目录和私有APPDATA/LOCALAPPDATA/TEMP/TMP，复制固定生产依赖并fresh import；Steam禁用。源码快照在启动引擎前归档，失败记录保留。依次运行错误profile负例、组件进程与独立重启进程，并在前后核对源码/冻结输入/引擎SHA。每 0.2 秒检查当前子进程日志，遇到 `SCRIPT ERROR`、`ERROR` 或 240 秒超时只结束本次已知子进程，收据记录原因与 PID。不会改玩家存档，不执行Git提交、推送或Steam操作。

当前主任务新增的ContinueFlow autoload依赖 `scripts/continue_flow.gd` 和 `assets/localization/continue_flow.json`也已逐项加入runner白名单；不会为解决依赖而扫描全部未跟踪文件。必须等主任务的ContinueFlow验证稳定并释放共享锁后再执行本组件。

QA使用实际CampaignMission与Unit类，宿主地图、HUD和关卡回调是明确的合成fixture。已验证半动作剩余时间、单次回调/奖励、已消费右键不启动同位置后续任务、重复事件、目标状态、UI回调归属、坏记录和终局结果。两个进程之间只传递本组件JSON，**没有世界槽、真实任务部署或真实关卡通关**。

以下保留初始组件交付的历史来源与步骤；最新回归已列在本文开头。初始批来源基线为 `23cc5751803d805f42b12fa3a249df905ed1d50f` 加当批工作区改动，不能把该 HEAD 当作全部受测源码身份。实际组件 SHA-256 为 `c9ae212121a4ed234f1aff2fc6e9d1c8242a47b70e097eb3d4a7c05fdd2077d5`；driver 为 `01d4dc475035660247901b411098cd8503c013c670d1696186b681adf7271b1e`；runner 为 `4e729c1c49a1c62f2b80cbdd6c93a5de02318aa66dca446c456290fb2141c9d6`。完整来源表在 [初始收据](../qa/campaign_mission_state_20260909/20260909_033618_46aa9054/receipt.json)。

| 最终步骤 | 退出码 / 错误 | 秒数 | 实际范围 |
| --- | --- | --- | --- |
| 全新导入 | 0 / 0 | 23.40 | 独立冻结工程 |
| 错误 profile 保护 | 2 / 0（预期） | 5.44 | 写入 fixture 前拒绝，未生成保护测试报告 |
| 组件进程 | 0 / 0 | 5.43 | 120 项实际行为断言 |
| 独立重启进程 | 0 / 0 | 5.22 | 22 项实际行为断言 |

四个步骤 PID 各不相同。独立 [复核脚本](../qa/campaign_mission_state_20260909/validate_evidence.py) 核对 2,951 个当前来源与冻结副本，共 5,902 次 SHA-256 比较，另核对 11 个归档源码/场景快照、引擎、四份日志、两个报告和 fixture JSON，均一致。142 条报告断言全部为真，名称唯一，且与实际引擎日志中的报告相等。5,902 次来源比较是完整性核对，不加入行为检查数。结果见 [独立复核清单](../qa/campaign_mission_state_20260909/final_review_20260909.json)。本批没有截图和真人关卡验收。

历史失败分别保留：`20260909_032943_e77c9e0b` 在导入时遇到共享 ContinueFlow 的局部变量类型推断错误，由主任务修复；`20260909_033057_5403ac54` 的 profile_guard 暴露本组件直接从类名调用非静态 `get_script_property_list()`，已改为显式 `Script` 变量后调用。两次均为未完成批次，不能与最终 142 项通过合并计数。

仍待外层完成：可信官方关卡/内容注册、Mission与Level/Unit角色关系交叉核验、已验证 UI/marker 工厂到世界流程的接入、世界准备/激活/失败释放、正常保存退出/继续入口、Steam持久确认，以及完整30波、八关、长期性能、双机和真人验收。
