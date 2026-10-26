# 连环马自然失败三进程驱动

本目录与 `../../run_lianhuanma_loss.py` 为独立外部 QA。真实 `SaveAndExit` 成功即由 `AppLifecycle` 退出，因此本需求必须采用三进程：保存退出、恢复后自然失败、独立重启拒旧槽。不能以内部 Session 保存但继续运行凑成名义两进程。

代码只做静态准备，未通过 Godot 编译或原生运行。不会修改、调用或继承胜利四进程的运行资格；胜利目录及生产、候选 20 文件、冻结工程均保持原样。

| 进程 | 操作与必需证据 |
| --- | --- |
| `save_before_loss` | 新 profile 通过实际剧情菜单、按 Level4 标题找到可见卡片并点击出征。普通训练原兵营钩镰手，实际扣 36 金、24 木、预留 2 人口，原 20 秒队列运行至少 5 秒后，Viewport Esc→真实 `SaveAndExit`，写固定 `user://continue/v1` gen1；读取精确存档、CFG/通关记录/奖励基线，观察生产 `continue_saved` 退出。 |
| `resume_loss` | 新进程点击真实 `ContinueBattle`，同 profile/槽/token、精确训练状态及暂停界面恢复。点击继续，仅选宋江，普通命令卡切换被动姿态，再发一次地图移动至原官军营地附近的可走格 `(50,31)`。等待真实敌军击杀原宋江，原中军必须存活；限时 240 秒，超时或其他失败原因不通过。 |
| `reject_terminal` | 第三进程正常 startup scan，将同 token gen3 识别为已应用历史。实际菜单继续返回 `LOCAL_RUN_TERMINAL`，有错误提示、保留 Menu、没有 Battle；点击真实返回按钮。原槽、终局链、CFG、奖励及 proof 不变。 |

失败动作只用正常姿态/移动命令，正常 1x/60 Hz，不重置种子、修改位置/HP/资源、注入伤害或敌军、直接调用 `lose`、设置胜败/任务状态。死亡信号只读：记录原宋江 entity ID、实际 `Unit.take_damage` 写入的 `_killer`、敌方及注册身份、致命来源、位置和时钟；另保留移动轨迹、自然血量下降、实际攻击目标。没有调用伤害方法或替换信号处理。该路线尚未实跑，240 秒不是必败保证；失败时保留全部证据。

终局要求实际 Flow 异步完成和败局 HUD 已出现，再读取生产已冻结的完整结果。严格验证 LC v3 / Intent v2 / ACK v2、Level4 context、`campaign_level4_v1` 和 contract 2、同 token 原链 `gen1 active→gen2 pending→gen3 applied`。保留四个目标真实的 `done/missed/pending` 及完整 goal 行；失败时允许原生 pending，不伪造目标完成，也不把六字段 Intent 投影当完整结算。

失败 ACK 必须精确为 `CAMPAIGN_PROGRESS_NOT_REQUIRED`、`persisted=false`、`suppressed=false`、空 `file_sha256`，带同 token/intent SHA 的 `campaign_uncredited_handoff_v1` proof，并由实际 SteamService 独立回读。比较 CFG 的原缺失状态或原字节，不把“文件存在”当新进度；通关 records、unlocked、owner 和离线奖励均须与保存基线一致。真实 mission metrics 仅新增一次 `defeat`；场景内观察和下次重启均不得重放结算。

宿主默认只读预检，不占引擎锁、不创建 profile、不启动游戏：

```powershell
python -B qa/campaign_progress_recovery_20261026/run_lianhuanma_loss.py --base-run <已导入的独立冻结目录> --candidate-manifest <该冻结实际绑定的候选manifest.json>
```

主线程在胜利批完成后统一调度，才显式添加 `--run --timeout 600 --wait-lane 1800`。三进程串行使用真实 `gl_compatibility` 屏外窗口；独立短 profile 位于 `D:/CodexQA/lhmloss/<nonce>` 所在开发盘根，输出为 `.godot/lianhuanma_natural_loss_20261026/<batch>`。宿主按明确 schema 动态核对实际 20 脚本或 23 脚本＋helper 清单、生产基线、生成身份、引擎、四个 GD、runner、README、前序报告和日志的 SHA，绑定实际 Popen PID、独立 process nonce 与共同 batch nonce。只释放自己持有且子进程已终态的锁。

环境使用独立 `LL_` 前缀：`MODE / PROFILE / PROJECT / WORKERS / BINDINGS / BINDINGS_SHA256 / REPORT / NONCE / PROCESS_NONCE / CANDIDATE_SHA256 / PROVENANCE_SHA256`，后两阶段另有 `PREVIOUS / PREVIOUS_SHA256`。`STEAM_DISABLED=1`、`CAMPAIGN_QA` 为空，现有 `LSH_CONTINUE_FLOW_QA=1` 仅在严格匹配的隔离 profile 中启用实际按钮。外部 bootstrap 逐字节绑定四个 GD，离开 physics frame 后加载；`can_instantiate()` 失败快退。

`provenance.json` 记录每个派生来源的原 SHA、修改点及本片全部源文件 SHA；运行时使用本目录独立副本，不动态依赖胜利目录，也不修改共同文件。base 仅复用已审实际菜单/Flow/Codec/训练保存机制并删去成军及第二次保存；terminal 仅复用只读快照、菜单拒绝和报告写出，败局契约独立实现；宿主独立适配三阶段与 profile。来源记录不转授原生通过资格。

当前已做 Python AST/`--help` 和独立只读接口审查；不是引擎编译、自然败局、公开战役继续、真实 Steam SDK/账号账本、导出 EXE 或人工鼠标键盘验收。此处按钮使用可见启用校验后的真实回调，Viewport Esc 走游戏输入分发；不声称 OS 鼠标命中测试。首次保存的训练只证明非空真实进行中状态，完整 20 秒成军防重复仍由独立胜利/训练专项承担。


## 2026-10-27 候选绑定适配（未原生运行新绑定）

宿主新增明确 schema 分支：原 `campaign_steam_handoff_candidate_manifest_v1` 与 `campaign_steam_store_protocol_integrated_manifest_v1` 仍要求精确 20 脚本集合、manifest 邻接源码和冻结副本的逐项 SHA；不把缺失邻接源码降级为其它路径。新 `campaign_liveness_integrated_manifest_v1` 经公共 `../../lianhuanma_candidate_binding.py` 调用只读 `prepare_liveness.preflight()` 重建精确 23 脚本＋1 helper 清单，要求与传入清单及冻结清单字节 SHA 一致。所有 source_path 必须是仓库内无链接的严格相对路径；helper 源码、构建收据、实际 EXE、完整 generation/expected_identity、成功 import 收据／日志与实际引擎均被绑定。

新候选的 manifest 实参使用 QA 中已归档原字节清单，无需在归档目录旁复制 scripts。下面命令仍仅只读预检，不占锁、不创建 profile、不启动引擎：

```powershell
python -B qa/campaign_progress_recovery_20261026/run_lianhuanma_loss.py --base-run .godot/campaign_progress_recovery_20261026/20261027_000821_ba1f231b --candidate-manifest qa/campaign_progress_recovery_20261026/process_liveness_integration_candidate/evidence/full_freeze_20261027_000821/candidate_manifest.json
```

本次仅调整宿主绑定、README 和 provenance；全部胜败 GDScript、自然命令策略、终局断言、保存退出链保持原字节。历史 static_audit / derived_from 原 SHA 保留，不改写成新宿主 SHA。新绑定尚未进行 Godot 编译或原生路线运行；e97a 的冻结导入、组件及活写者测试不转授连环马胜败链资格。首次引擎执行仍由根任务串行安排。

首次 LF 宿主准备已完成 Python AST、`--help` 和 e97a 只读预检（exit 0）；该结果保留为历史准备记录。随后按 Git HEAD 恢复原有字节风格：失败宿主 CRLF、本 README LF、provenance CRLF；逻辑不变，当前源 SHA 以 provenance.files 为准。最终字节的 AST、帮助入口与同一 23 脚本预检由任务另行复查，不把首次 LF 预检转授为新字节的原生资格。全部 GDScript、自然路线及生产源码未变，仍未进行本胜败链的引擎编译或原生运行。
