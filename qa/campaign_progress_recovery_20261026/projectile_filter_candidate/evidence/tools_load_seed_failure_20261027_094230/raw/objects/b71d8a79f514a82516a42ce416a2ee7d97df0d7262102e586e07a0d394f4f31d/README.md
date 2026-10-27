# 大名府双角色八进程真实 Flow 外部工具

本目录记录工具准备与修订时状态；后续原生收据以候选 evidence 与项目 VALIDATION 为准。旧 072035 首批 Lu-first A 202 项、B 104 项成功，C 的石秀自然阵亡，八流程未完成。随后 b22 的 084726 护送版仅 A 166 项中 165 项通过：两座塔已自然击破，但新增全军集合条件超时，未解救、未 SaveAndExit。本次仅修 route/README/sources，新字节尚未原生加载或复跑；旧运行不转授当前策略资格。

## 来源与执行边界

`run_daming_flow.py` 位于候选目录根。它使用 `integration_941/prepare_daming.py`：默认只做具名小文件/元数据核对；指定 `--base-run` 才调用完整 `prepared_state`；`--run` 才允许启动 Godot。必须是本候选完整冻结、自有成功导入、`daming_941_integrated_manifest_v1` 的 25 个被跟踪脚本及 1 个原生资产。`state.base` 是 941c 祖先，实际运行只能用 `state.run_base/project`，不能回退祖先或凭准备元数据授原生资格。

当前准备目录为 `.godot/campaign_progress_recovery_20261026/20261027_063133_392242bc`；宿主通过准备器取得精确身份，不在驱动中伪造或硬填身份。首次运行前仍须完整核查来源及该冻结的独立 import。固定 25 条清单并不代表工程新增 25 文件：完整工程只替换既有 Session/Core/UnitContract 三文件。

```powershell
# 轻量，不读完整工程、不拿引擎锁、不建 profile、不启动 Godot
python qa/campaign_progress_recovery_20261026/daming_continue_candidate/run_daming_flow.py
python qa/campaign_progress_recovery_20261026/daming_continue_candidate/run_daming_flow.py --help

# 仅在根任务安排通道后执行；完整预检在拿锁后、首个引擎之前进行
python qa/campaign_progress_recovery_20261026/daming_continue_candidate/run_daming_flow.py --base-run .godot/campaign_progress_recovery_20261026/20261027_063133_392242bc --run --timeout 1320 --wait-lane 1800
```

默认每个进程最多 1320 秒，普通路线自身保持旧 900 秒总界和分步期限，任何真实战损/路线超时都保留失败，不补资源、复活、搬角色或加速。

2026-10-27 护送再修订：084726 的两次全军显式塔攻与突击队从 20→17、13→8 的损失窗口对应；报告没有逐个 killer，不把全部伤亡直接归因于箭楼。最后 `prison_guards=[]`，两囚犯仍健康并各有三名近卫；失败来自 `_jail_escort_ready` 要求所有 `_crew` 到牢门，而其中弓手已返营，不能称为未清敌军。前半恢复 072035 已成功的普通解救动作：不强制全军点塔，使用原生产 `_guarded(JAIL_ACTION,120)` 条件后由柴进真正开枷。

救出后从实际存活突击兵中选最近至多九名、排除投石车，记录原实体 ID；九名上限容纳两伤员各三名不同近卫及三名普通攻击者。先以普通 move 主动集合至 PRISON_INSIDE，须实际到位且每伤员 140 像素内至少三名选定护卫，不以选择成功代替保护。随后按 `PRISON_CHECK → (30,25) → (30,34) → (30,41)` 联合移动；到达、S/H 留守、可见局部敌人显式攻击均只约束该实际护送组与伤员，不再等待全军、返营弓手或慢投石车。仍逐个检查真实路径、普通命令目标与实际距离，保留每伤员三名近卫及其余三名攻击者的原门槛；不足、战损或超时均失败。C 从独立恢复后的实际伤员近处重新选择存活护卫，不从测试变量伪造跨进程小队。

集结点依据 `level8_daming_rts.gd:472` 的原安全判定：同时满足距 EXIT≤130 且格 y≥45 才撤离。(30,41) 在原南路、距 EXIT 中心 256 像素；代码仍逐个验证伤员真实阵型落点和到达位置均 y<45、距 EXIT>130，不能只凭中心点推断。最终 S 停伤员、H 只用于战斗护卫；第一人单独进入出口，其余伤员和近卫留在界外。B 原 120 ticks 无命令验证不变；C 恢复后按普通同编队命令护送第二人。新增观察仅记录原塔状态、实际近卫 ID 和出口距离。宿主、其余四份 GD、A fixture helper、世界源码与全部原通过门槛均未修改；新策略仍待重新原生加载及两条路线实测。

## 两条路线与八个进程

`first_role=lu` 和 `shi` 分别建立全新 profile，各自四个独立进程。全批 nonce、每角色 nonce、每进程 nonce 都写报告；同角色四进程只初始化一次 APPDATA/LOCALAPPDATA/TEMP/TMP，其后只复制环境字典，不重复 mkdir。固定槽 `user://continue/v1`。

| mode | 正常操作和验证 |
|---|---|
| save_single | 实际剧情菜单/Level8 卡片、介绍和开战按钮；普通采集、付费房屋/兵种/器械、潜入、举火、救人；只命令首人撤离；实际 Viewport Esc/SaveAndExit；slot gen1、LC gen1；由 AppLifecycle 以 `continue_saved` 退出 |
| resume_settle_save | 实际菜单 Continue；暂停态检查原槽/实体/Level/任务/运行定义/同 token；实际 Resume，至少 120 个正常 1×/60Hz ticks，无作战命令；仅 safe 状态与报告防重保持不变，允许其他世界自然变化；再次 Esc/SaveAndExit/ConfirmSave，slot gen2，LC 原 gen1；实际退出 |
| resume_finish | 独立 Continue 原 gen2；恢复暂停态再次精确核对；实际 Resume 后只用普通军队/第二囚犯移动完成护送；等待自然 END、真实事务信号和 HUD；验证完整结果、LC1→2→CFG/handoff→3，同 token，原 slot gen2 不改写 |
| reject_terminal | 独立启动分类为 applied history；实际菜单 Continue 返回 `LOCAL_RUN_TERMINAL`，同菜单/错误层，无新 Battle；CloseError；原 slot、LC、CFG、记录、奖励不增长 |

菜单和按钮通过实际 Control 的 `pressed` 信号进入原回调；Esc 经 Viewport 真实输入派发。普通战术命令使用原 Battle 选择、minimap_order、付费训练、建造/集结 API。这是源码流程自动验证，不是 OS 鼠标键盘/人工可用性验收。

## 章节与协议

只有一个 `Profiles.DAMING_CONTEXT={mode:campaign,level_id:level8,waves:0}`、`campaign_level8_v1`；先撤离角色是外部测试参数，不另造 context。

恢复后直接核查实际 `battle._defs`：hall produces 五项、城门/箭楼设防倍率 0.25 与官军阵营、三内应加两囚犯不可训练且人口 0。仅比较已有 Unit.setup_def 不能发现缺失章节 runtime 装配，因此两者不能混为一项。

首名 safe 仍在 active/root，隐藏/停止/非选中且事件和报告恰好一次；另一人存活、未 safe。双 safe 原生产立即自然胜利，不构造双 safe 的 FIGHT 存档。暂停态恢复精确比较采用生产 Codec 的 typed checkpoint，保留数字类型和浮点位；B 运行 120 ticks 后不要求全世界等于 A，只检查 safe 的身份和防重。

严格限定 LC `local_campaign_continue_lifecycle_v3`、Intent `campaign_progress_intent_v2`（完整字段含 credit）、ACK `campaign_progress_ack_v2`。Steam 禁用、owner 为空，credit 精确 uncredited。ACK 必须 persisted=true/suppressed=false、实际 CFG SHA、同 token/context/Intent SHA 的 uncredited proof，并由真实 Service.inspect_campaign_handoff 独立回读。

Daming 仍是 contract2：daming_infiltration / daming_signal / daming_response 三个故事目标，核心目标另列。普通路线允许真实攻破城门，终局保留三个目标的实际 done/missed、pending 必须清空；不要求/伪造全故事印章。必须先等生产结果已 frozen，再读取完整 goals/core_goal/done/missed/pending 和原始胜利结果投影。

当前源的 Campaign.on_level_won 与 run_campaign_progress_projection 使用 `max(previous_unlocked, catalog_index+2)`；Level8 实际 index7，所以新 profile 结果为 9，未 clamp 为 8。驱动从开场 unlocked 和真实 catalog 计算并精确核值。CFG 只新增 level8 的本局结果，独立重启读取后不再增长。

## 来源和未覆盖范围

`route.gd` 源自旧 v34 自然命令路线；初版适配 runner/check/观察接口、移除直接 paused/_hold、改真实 Resume，并把终局等待移到当前严格 terminal。本次恢复原解救前半，并修正选定近卫集合/联合护送策略。旧 fullGD 的 Session.save_held/prepare_restore/stage_mount/commit_restore 以及直接拒槽均未复制为执行入口。Flow 基类与终局协议借鉴已封存的 Gao 外部工具源码；`sources.json` 保存其原始路径/SHA，旧结果不继承。

本片不执行原 1+8+52 的完整 61 阶段，也不执行原 19 类故障；不覆盖败局、存储崩溃恢复、credited Steam SDK、公开 Continue、发行 EXE、性能、四语目检、人工接受或发布。即使八进程将来全过，也只授当次新源的私有离线双路线 Flow 资格。新玩法/公开入口/生产采用均不由本工具改变。

宿主保存实际 Popen PID/exit/log、每个报告 SHA、运行输入副本、初末完整 source/engine/pin 核对，并只在所有自有进程已终态、共享 lane 空闲且锁 owner 相同后释放锁。错误和 finally 取证/清理错误分别保存；不得把安全拒绝或失败阶段当完成。归档时排除 profile、完整槽/LC 世界载荷、EXE/assets/cache；报告中的有限 typed QA 状态保留来源链。

## A 正常退出后的原始夹具冻结

宿主先核对 A 的实际 `process_step`、独立报告与日志：exit0、errors[]、未强停、`continue_saved`、同角色/PID/批次/角色/进程三个 nonce、精确 source/engine/manifest。仅在这些原生结果全部通过后，才调用 `fixture_freeze.py`；hook 成功后才允许 B 启动。hook 本身没有修改 GD 或插入测试状态；上述后续护送修订仅限 `route.gd`。

每条路线写入当次私有 run 的 `closed_a/<lu|shi>/descriptor.json`，schema 为 `daming_flow_closed_a_fixture_v1`。原 `user://continue/v1` 必须恰为两个 genesis 记录与六个目录：slot `5088120/1/record_0000000001.json`，LC `local_runs/<token>/5088120/1/record_0000000001.json`。必须同 uncredited token、slot gen1、LC v3 active gen1、实际 Level8 context、同 source/engine、paused；拒绝 gen2、其他 token/owner、pending/writing/recovering、任何额外文件或空目录、路径越界、symlink/reparse 与已存在输出。

先比完整库存、原 envelope/payload SHA 和报告中的原文件 SHA，再以新目录及 `xb` 独占写入原两份字节；复制后再次比原完整库存与副本，原报告/日志也须未变。任何失败保留局部证据并停止，不启动 B。只有原 A 报告/日志、冻结副本、descriptor 加入长期 pins；原 profile 的“两文件/六目录”仅在冻结窗口核对，B/C 后续合法推进不受误拦。每阶段前及最终审计另核冻结目录完整库存，添加空目录也会失败。

描述文件保留原来源路径/大小/SHA、原 A 报告/日志引用、实际完整步骤、PID、三个 nonce、身份与目录清单。Python 只验证信封、关键头与原字节绑定，不生成 packet/world/Codec 数据，也不把这一新 schema 伪装为旧五件套。未来 52 负例必须重新核库存和来源，再由同候选原生 `Slot._decode` 读取冻结的原记录；不能从本 hook 推导已完成 52/61 或 19 故障。两份业务载荷只留本机私有 run，不提交 Git。

独立模型入口：

```powershell
python qa/campaign_progress_recovery_20261026/daming_continue_candidate/tests/daming_flow/test_fixture_freeze.py
```

实际模型收据：`D:/CodexQA/daming_fixture_model/69a3ca286750484eaf3b03cd18bffcff/receipt.json`，SHA `6d1d0afbdaa48f58db13501845b87d5254cafb447e0273428ce8c1e94b6e5b8b`。53 项通过，全部使用合成报告/PID与新隔离文件；覆盖双角色原字节复制、错误退出/PID/nonce/source/报告 hash、gen2/错上下文/错误 payload、额外 owner/记录/pending/空 writing、输出碰撞、源复制中变化、冻结后目录变化与后续活 profile 追加不误伤。Windows 创建 symlink 权限不足，明确跳过该创建用例；另以实际新建私有 junction 验证 reparse 拒绝通过。模型目录同时保留当时执行的四份 Python 来源原字节。未启动 Godot、未验证实际 A 或原生 Slot 解码；53 不计入八进程玩法检查数。
