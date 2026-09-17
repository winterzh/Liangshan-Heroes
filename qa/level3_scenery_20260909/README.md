# 祝家庄地图景物恢复组件原生验证 · 2026-09-09

最终批次 **`20260909_083845_5a3ee678`：197 项原生检查全部通过，其中 component 155 项、独立 restart 进程 42 项**。导入退出 0，私有 profile 反例按预期退出 2，两次行为进程退出 0，四阶段均无引擎错误。

本批验证真实菜单启动的祝家庄地图、单位和关卡状态，经过生产 Barrier 的 HELD 边界捕获，再通过地图状态组件和固定景物工厂恢复。目标 Battle 始终是暂停、禁用的组件宿主；**没有接入 WorldCore/Session 的完整世界恢复，没有开放玩家保存或继续入口，也不代表祝家庄通关、八关续玩、Steam 统计或发布验收完成**。

## 最终证据

| 证据 | 说明 |
| --- | --- |
| [receipt.json](20260909_083845_5a3ee678/receipt.json) | 原生阶段、退出码、来源、隔离保护、归档清单和释放锁结果 |
| [component_report.json](20260909_083845_5a3ee678/component_report.json) | 155 项实际断言、景物清单、坏状态反例、受控晚建 UI 和截图详情 |
| [restart_report.json](20260909_083845_5a3ee678/restart_report.json) | 新进程读取同一夹具后的 42 项实际断言 |
| [scenery_snapshot.json](20260909_083845_5a3ee678/scenery_snapshot.json) | 私有 QA 构造的组件夹具；不是玩家存档 |
| [source_manifest.json](20260909_083845_5a3ee678/source_manifest.json) | 本批 2,956 个来源文件的大小与 SHA-256 |
| [independent_readback.json](20260909_083845_5a3ee678/independent_readback.json) | 根任务独立回读：来源双份、报告、归档、进程关联与保护证据 |
| [visual_review.json](20260909_083845_5a3ee678/visual_review.json) | 根任务对最终 6 张截图的 Codex 目检记录，独立于原生断言 |

本 README 另经独立只读复核：2,956 份工程原件与 2,956 份私有冻结副本，共 **5,912 次来源 SHA-256 比对全部一致**；receipt 清单中的 **62 个归档文件，共 39,565,751 字节**全部回读一致。62 个文件不包含之后新增的独立复核、视觉记录和本 README，不能视为目录最终文件总数。

来源记录的 `source_head` 为 `dca4e4e6a0682edb0336fc9b90c77d6aca3193bc`，只是准备时的 Git HEAD；本批还包含冻结的新文件和未提交修改，实际受测版本以来源清单及冻结副本为准，不能用该 HEAD 单独重建本批。

| 关键受测文件 | SHA-256 |
| --- | --- |
| `scripts/run_scenery_state.gd` | `cc8e8fb6a5d5036d68ea00aa913c01a6fcc81272aae9f2a079c9eaff9996c1f2` |
| `scripts/run_map_state.gd` | `a66bfe0220cd2ac4f2be5497e5e41300a2da5dc9a1faeaf3c5240771cb93bbb7` |
| `scripts/run_battle_barrier.gd` | `5d49fd6662b425933f100d7d7f108ccd2ad47675e3494afe7ea7bd0e90fc8277` |
| `tools/level3_scenery_qa.gd` | `d129a30372aa64d8ec0821429931b9109ed0ec1381485aafa5f2f723523bd77c` |
| `tools/run_level3_scenery_qa.py` | `c55c185f3e16f5ca155f27591a5eff61ae617d6269ea8fcec73f31715a97229a` |

两份 QA 工具均保持纯 LF：GDScript 43,775 字节、616 个 LF、0 个 CRLF；Python 21,327 字节、341 个 LF、0 个 CRLF。原生引擎 SHA-256 为 `ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00`。

## 双进程和隔离保护

| 阶段 | Popen PID | 报告 PID | 检查 | 实际／预期退出码 |
| --- | ---: | ---: | ---: | --- |
| import | 42232 | 不适用 | 导入完成 | 0／0 |
| profile_guard | 20500 | 不生成行为报告 | 拒绝错误私有 profile | 2／2 |
| component | 12624 | 12624 | 155／155 | 0／0 |
| restart | 36912 | 36912 | 42／42 | 0／0 |

夹具 SHA-256 为 **`91d592ec9cdbb93992b627fe1855e8f8ca6249ddd230e30b70a06cdc5f6c4b51`**。夹具 `producer_pid`、两个行为报告的 `snapshot_producer_pid` 均为 12624；两个报告的 `snapshot_sha256` 均等于实际文件 SHA。生产者 12624 与消费者 36912 不同，各自又与 runner 的 Popen PID 一致，`process_link.verified=true`。

四个阶段的前后共 8 次保护检查均通过，每次核对 5,912 个来源散列，未发现其他引擎进程，公共锁仍由本次 runner 持有。受保护玩家目录的前后摘要一致，`protected_player_unchanged=true`。最终 `engines_after=[]`、`lock_owned_at_release=true`、`lock_released=true`；runner 在实际释放锁后写入 receipt。

运行使用 D 盘私有项目与 APPDATA/LOCALAPPDATA/TEMP/TMP，`STEAM_DISABLED=1`、`CAMPAIGN_QA=1`。归档只有源码证据、合成夹具、报告、日志和截图，不归档真实玩家存档、Steam 登录资料或完整私有 profile。报告明确标记 `component_only=true`、`normal_gameplay=false`、`full_world=false`、`real_steam=false`。

## 实际执行范围

1. 源端由真实菜单启动官方祝家庄，执行正常的关卡部署。现有生产 Barrier 默认经典配置仍拒绝祝家庄；显式受信 `Profiles.ZHU_CONTEXT` 才接受，并验证错误章节、上下文以及被替换的 Level/Mission 均拒绝。正常入口没有因此改变。
2. 在真实 HELD 边界捕获 Map/Scenery，并取得实际 UnitGraph、LevelState、Fog、Camera 与 RNG 记录。为保证动态值非零，QA 显式设置景物 `_visibility_tick=0.037`、首段墙面透明度 0.45、首个树冠透明度 0.40；这是受控状态注入，不算自然遮挡触发覆盖。
3. 目标使用离树、禁用且阻止信号的 Battle 宿主，按 `Map.stage_map_values → 固定运行时定义 → UnitGraph.prepare/挂接 → LevelState.restore → RNG → Fog.bind → Camera.bind → Map.finish_display` 顺序准备。景物只通过固定 `CampaignScenery.setup` 工厂重建，恢复端不调用地图 `paint`、关卡 `deploy/on_start` 或 Mission `begin`。
4. 保留 `Map.finish_display` 返回的同一个 `display_adapter`，准备期间 `complete=false`。离树激活、未暂停激活、真实物理回调中激活以及重复激活均受控拒绝；挂树后暂停跨过 3 个 process frame，逐值保持，再显式激活景物并重捕获。
5. 完整 Map/Scenery 记录保持严格相等；地图格子、阻挡计数、5 份导航数据、高度、资源、运行时定义、RNG 与活动单位身份守卫通过。第二个原生进程从同一 JSON 夹具重复恢复及严格比较。Fog 和 Camera 为截图检查执行各自的组件绑定与显式激活，目标 Battle 仍禁用；未验证整个世界的最终激活。
6. 覆盖错误内容、未知对象、墙段元数据缺失、模板外状态、非法激活条件和清理；缺元数据受控拒绝后按原顺序恢复源元数据，原有 source byte-exact 断言仍通过。失败工厂、离树失败、挂树失败、正常激活后清理和重复清理均核对工厂所有权及 StorySign 全局语言连接释放。

最终景物格式是 **`level3_scenery_state_v2`**，存档内 display context 精确为两个字符串 `{mode: "campaign", level_id: "level3"}`。受信构造参数仍要求三字段 `{mode: "campaign", level_id: "level3", waves: 0}`，其中 waves 必须是整数。实际反例覆盖旧 v1、v2 额外 waves（整数 0／浮点 0.0）、缺少字段、错误 mode/level_id/字段类型，以及受信构造参数浮点 0.0。新捕获的完整 Map/Scenery 经 JSON stringify/parse 后仍严格等于源，测试没有做类型归一化或放宽比较。

### 实际景物分支

真实安装内容共 **98 个景物节点**：CampaignScenery 根 1、Sprite 76、Stockade 18、StorySign 3、GroundOverlay 0。18 个 Stockade 面板由实际 **3 条固定墙段**生成，不能把面板数当作墙段数。三块牌示分别为李家庄、扈家庄、祝家庄。

配置声明的 6 个 overlay 锚点为 `twigs_bark`、`roots_moss`、`field_edge_bank`、`field_edge_stubble`、`field_edge_ditch`、`field_edge_willow`，本安装中对应纹理均不存在，资源检测及纹理解析均为 false。工厂跳过这些缺失纹理，实际 overlay 路由和节点为空；报告 `nonempty_overlay_branch_exercised=false`。本批只验证这一实际分支，**未覆盖存在 overlay 纹理时的非空恢复，也未覆盖另一套平地高度配置**，不生成假素材补齐覆盖。

### 最后完整物理步后的任务 UI 门控

主夹具保存与往返验证完成后另起一轮 Barrier 请求，使用 `process_frame → call_deferred` 在排空期间受控调用真实 `Level3._introduce_sun`。断言创建当刻实际为 DRAINING、暂停且非物理回调；本例并非仅依赖预期调度顺序，也不冒充自然任务推进。

该回调创建真实孙立单位、任务按钮和角色定位按钮。两个新按钮各在 `_saved_ui` 中登记一次，保存的原状态均为 `blocked=false, process_mode=0`；HELD 后两者均禁用且阻止信号，直接发送 pressed 不改变选中、镜头或任务。分别篡改单节点信号门控和 process mode 会使 health 拒绝，恢复后 health 通过；release 恢复原状态，按钮随后能实际移动镜头，角色按钮能选中孙立。报告标记 `natural_task_progression=false`，此控制案例不污染跨进程主夹具。

## 截图与目检边界

本批生成并归档 26 张截图，每进程 13 张：1 张保持保存时镜头与 Fog 的纯恢复全景，以及 4 种语言 × 3 块牌示的受控绘制样本。牌示样本临时显示目标牌示、隐藏 Fog 绘制层；截图后恢复可见状态，并通过完整 Map/Fog 再捕获比较。它们标记 `presentation_only_override=true`、`normal_visibility_acceptance=false`，不证明正常玩法可见范围正确。

根任务的 [visual_review.json](20260909_083845_5a3ee678/visual_review.json) 记录最终 **6 张 Codex 目检**：两个进程的无可见性改动恢复全景，以及 component 的简中、繁中、英文、日文祝家庄牌示（sign3）。该记录确认所选牌示可读、未见缺字，两个全景可见恢复的营地、单位、资源和 Fog，组件宿主没有完整 HUD。其余 20 张没有目检；记录中的 13 对跨进程 PNG 字节一致是文件比较，不能替代目检。**本批没有真人试玩或完整世界视觉验收**，此前失败批次的截图也不计入最终 6 张。

## 五次失败历史

以下原始目录均保留，`complete=false`；没有改写旧报告。各批导入退出 0、profile_guard 按预期退出 2、引擎错误数 0，最终锁均释放。表中检查数来自行为报告；失败阶段不会累计到旧 receipt 的成功检查总数，因此不能据 receipt 的 0 误认行为未执行。

| 批次 | 实际原生结果 | 失败与后续修正 |
| --- | --- | --- |
| [20260909_075429_c2405105](20260909_075429_c2405105/receipt.json) | component 133 项：132 通过、1 失败；未启动 restart | `actual authored ground overlay present` 错误要求非空 overlay。核实本安装 6 路纹理缺失、实际 0 节点后，QA 改为记录真实分支和未覆盖范围，没有修改生产素材。 |
| [20260909_081919_3dd36772](20260909_081919_3dd36772/receipt.json) | component 134 项：133 通过、1 失败；未启动 restart | `source remains byte-exact after fault probes`：缺墙元数据反例 remove/set 改变了原字典键顺序，Codec 保留 entries 顺序。QA 改为按原顺序恢复完整元数据，保留缺键拒绝与严格相等断言。 |
| [20260909_082317_d23a72bd](20260909_082317_d23a72bd/receipt.json) | component 134／134；restart 6 项：5 通过、1 失败 | `restart target component preparation` 返回 Fog `PAUSED_INSTALL_REQUIRED`。restart 已设 paused，但启动 deferred 仍可能在物理排空中执行；QA 改为等待真实 process frame，并断言暂停且非物理阶段。没有放宽 Fog 前置条件。 |
| [20260909_082826_f22462ac](20260909_082826_f22462ac/receipt.json) | component 134／134；restart 20 项：17 通过、3 失败 | 离树逐值比较、暂停 3 帧逐值比较失败，激活返回 `CAMPAIGN_PREPARED_STATE_CHANGED`；capture 本身成功。本批尚未证明根因，下一批增加带路径与叶类型的首处差异诊断，保留原断言。 |
| [20260909_083319_38021ac7](20260909_083319_38021ac7/receipt.json) | component 134／134；restart 20 项：17 通过、相同 3 项失败 | 原生诊断确认 `$/context/waves`：存档为 float `0.0`，新捕获为 int `0`。生产 display schema 改为 v2 两个字符串字段，受信构造参数仍严格整数 0，旧 v1 明确拒绝；增加格式和 JSON 严格往返反例后，最终第六批 197／197 通过。 |

## 复跑

从当前 D 盘开发工程运行，先保证无其他 Godot 原生验证或性能测量占用公共引擎锁：

```powershell
Set-Location -LiteralPath 'D:\AI项目\水浒\开发工程'
py -3.14 -X utf8 -B tools/run_level3_scenery_qa.py --run --work-root D:/CodexTemp/level3_scenery
```

不加 `--run` 只做 runner 预检。正式运行生成新时间戳目录，不覆盖历史。import/profile_guard 使用无头模式，component/restart 使用真实图形进程、`gl_compatibility`、Dummy 音频和 1280×720 窗口。runner 在 SCRIPT ERROR/ERROR 或超时后只终止自己创建的子进程；无论成功或失败均归档已生成报告、夹具、日志和截图，检查来源及玩家目录保护，并在释放锁后写收据。

本命令是地图景物组件正确性验证，不是性能测试、1800 秒长跑、完整经典 30 波、祝家庄最终胜利、八关续玩、两台 Windows、双 Steam 账号或正式发布验证。这些交付条件必须由各自流程另行记录。
