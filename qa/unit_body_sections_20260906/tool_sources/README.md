# Unit 完整物理主体粗分段归因草稿

2026-09-06。仅生成约 429 KiB 小型脚本/补丁证据；**未运行 Godot、未改生产、未创建/扫描/改写大镜像、未做优化，也没有性能结果。** 本目录全部是私有诊断准备，不写公共 QA 或正式文档。

root 当前认为分离建桶首窗约 0.205 ms/步不足 0.5 ms 候选预算，本稿转向原生旧计时约 3.929 ms/步的完整 Unit `_phys_body`。这些是此前不同探针的参考背景，不能预先当成本稿的同源同开销结果。本稿只找值得继续研究的粗段，不能用某段总耗时直接承诺可节省同样时间。

## 源与四段边界

来源固定 Git 快照 `4baafc11af55b0e46a57a48e54df181b8c1917a2`，从已存在的 `../separation_sections_diag/frozen/` 逐字节读取，不从可能正在变化的生产 Unit 或私有项目读取。

- Unit raw SHA：`c8310fd12a29858df8f7410dd06d2f1dc51f40f5eedc0e7a6a16599eb5e58856`；LF SHA：`c8a692bff598b6ac9199d113ccc9ff39ea8943f127012b45fc67ff2cd6c4deec`。
- 原 `_phys_body` 为 1070–1478 行（其后空行也原样保留）；粗段完全按照原语句位置切开，没有提取/重排原业务代码。
- 原 M1 `tools/polish_performance_probe.gd` raw/LF SHA：`04a47115c8cd05670b465086653491466fdae99f6fadf9c41c40379aee0c1407`。本稿继承它的 fixture、TickDriver、设置、输入与观察；生成时用其完整 `_run`，只插入 5 处观察钩子。

| 段 | 原文范围/起点 | 实际包含内容 | 原有外层早退 |
| --- | --- | --- | --- |
| lifecycle_building_death | 1071 起，1120 的 `_cd` 前 | 剧情姿态/俘虏、重绘计时、建筑起火/塔索敌/训练/研究/驻军回血、死亡与 queue_free、驻军停止 | 5 个：剧情/俘虏、已毁建筑、建筑分支结束、倒地分支结束、已驻军 |
| status_timers | 1120 `_cd` 起，1304 `_eject_t` 前 | CD/受击、被动回血、技能/库存、增益/控制/光环/召唤/任务与命令计时 | 0 个 |
| target_state_movement | 1304 `_eject_t` 起，1433 `_move_blend` 前 | 硬占位弹出、目标有效性、花荣锁定、引导/抬手/冲锋、眩晕、目标/状态机、索敌/寻路/采集/建造/驻军等下级调用 | 3 个：引导、施法抬手、冲锋 |
| tail_animation_hit_watchdog | 1433 起至完整原方法末尾 | 动画/扬尘/重绘，**1453 `_deal_hit` 命中结算**，受击位移，**1458 后卡死重寻路看门狗** | 0 个；dust.filter 中的 lambda return 不是外层早退 |

尾段不叫“纯视觉成本”，不能删除或降低它的频率来推导优化。原 `_physics_process` 1004–1017 的原生 profiler 分支及 story-partner redraw 尾巴完全未改；本稿只测其调用的完整 `_phys_body`，不包含调用后双角色重绘尾巴。

## 插桩、早退与开销

将原 `_phys_body` 仅改名 `_unit_body_sections_original`，外层 `_phys_body` 在源码中恰好一次调用这个完整原方法；原 body 只新增 3 个 `section(1/2/3)` 标记。**8 个原外层 return 均留在原位置，不改成额外 return 包装、不改返回条件。** 每个正常/提前返回最终都回到外层，外层用同一结束时刻收最后到达的粗段。脚本异常不是正常早退：引擎日志与入口/完成计数不一致必须使诊断失败。

所有时刻来自 `Time.get_ticks_usec()`。外层开始时间在 `begin_body` 记账之前；每个段切点以一个时间戳同时作为上一段结尾/下一段起点；外层结束时间既结束完整 body，也结束最后一个实际到达的段。因此每步必须精确满足 `四段和 == 完整 body 合计`，不做估算减法。

这不是无开销原体计时：`begin_body` 校验/计数、原体包装分发、3 个边界函数调用和记账进入被测范围；每个切点时间戳之后的记账算入下一段，结束时间戳之后的 `end_body` 写入不计入 body、仍影响真实帧。最早返回单位只有开始/结束 2 次时钟，走到底是 5 次；每个物理步/呈现/进程信号还有公共时钟和缓冲写入。

两模式加载**相同 Unit、driver、ledger 字节**：

- `timed`：每单位计时，报告四段、完整 body 及进入/退出计数。
- `clockless`：仍走相同 wrapper、边界、计数及 frame/step 观察，但不调用单位级时钟；各段/完整 body 时长写 `-1`，不是 0。它不是原生产，也不等于“去掉所有探针”。

没有新增 Node/RefCounted 实例、RNG、每单位 Dictionary/Array 行、每帧扩容或日志。共享 GDScript 资源加载仍可能扰动 instance ID；PackedInt64Array 在 Battle 创建前分配，测量时只对四段/计数及每物理步记录做定长写入。begin/end 的静态深度和 token 会把意外重入标为无效，仍调用完整原体；不覆盖单位原生身份，不修改阵营、命令、目标、HP、计时、RNG 或 delta。

额外调度/时钟会改变墙钟驱动的音效 RNG、呈现节奏和 render-frame 飞斧结算；同种子不能证明 timed/clockless 战斗轨迹相同。不得将两模式 FPS 相减当作精确探针开销，或从旧 3.929 ms 减去本稿某段推算新性能。

## 同一 M1 时钟与物理步账本

`generated/driver.gd` 沿原 M1 `_run` 的音乐准备、标准 defense200、固定镜头、300 真实物理步预热和原 `frame_post_draw` 时间戳；不另起测量循环。5 个钩子只做：预分配、接物理/进程信号、记录原 started 锚点、用**原 now** 分组呈现、结束锚点。原文删除这些钩子后逐字节还原。

`_on_tick` 沿已有 separation_sections 方法，在下一次优先级 -10000 的 TickDriver 先收前一步、执行原 TickDriver、再开当前步；frame_post_draw 收当前完整步，并记录零步/多步呈现的区间。收尾 `_dispose` 先关闭 Battle 处理并收最后一步，再导出。

每物理步只一行：M1 tick、引擎物理/进程号、同钟边界、body 开始/完成总数、完整 body、四段、4 个到达计数、4 个结束计数、partition 差值。原暖场也记录在其中；测量行严格按 `m1_start.step_count` 到 `m1_end.step_count` 切片，不取文件前 600 行。无每单位矩阵。

必须满足所有步的 start/completion、段到达/退出守恒、顺序、深度和 partition 校验；实际值异常、缓冲溢出、缺首尾步或引擎 ERROR/WARNING 一律无效。现脚本只准备完成，GDScript 尚未解析，不能把 Python 静态通过标成引擎通过。

## 交付文件与原样还原证明

- `prepare.py`：只读现有少量 frozen 文件，生成本目录产物；不运行 Git/引擎，不读取/写入生产或私有项目，不复制目录。
- `instrumentation.patch`：Unit 的 LF 文本审阅补丁。正式应用应先核对容器原文，按下列 raw/LF 精确产物选择，不盲目套用补丁改变整文件换行。
- `generated/unit_instrumented.raw.gd.txt` / `.lf.gd.txt`：分别对应原 raw 或完全 LF 的同一冻结 Unit。逆操作删除确切 wrapper/3 个标记并恢复方法名后，**整个文件每一字节**分别还原到对应来源。
- `generated/original_phys_body.gd.txt`：完整旧方法对照；`generated/driver.gd`、`generated/ledger.gd` 是容器候选入口。
- `pins.json` / `preparation_receipt.json`：完整来源、所有产物摘要、原方法/行号/早退数量、M1 逆向证明、精确容器改动清单。
- `static_checks.py` / `static_receipt.json`：原样还原、负例、Python AST、常量开销结构及记账公式检查；数学样例不冒充 Unit 运行或玩法等价 QA。

只做准备/静态检查的命令：

```powershell
python -X utf8 scratchpad/unit_body_sections_diag/prepare.py
python -X utf8 scratchpad/unit_body_sections_diag/static_checks.py
```

生成器只接受 Unit 的 exact raw/LF SHA；源有其他改动或已插桩时拒绝，不能把当前生产源码重基成“4baafc1”来强行通过。

## 容器选择与精确变更清单（待 root 执行）

可以复用已完成分离诊断的专用项目。已有 `../separation_sections_diag/resume_plan.json` 指向 `runs/20260906T104036739951Z/project`；本稿只读该既有定位收据，**没有操作该项目**。该项目的所有旧报告、来源清单、导入/缓存收据和历史失败都保留，生成新的 Unit 归因代次收据，不覆盖成“原分离环境”。

选择该项目后，在新代次前后持共同引擎锁和真实引擎进程句柄，逐项检查：

1. 原分离插桩不只改 Crowd，也改了 Battle。将 `scripts/battle.gd` 恢复为 4baafc1 原文（LF `784373eede18a82c24fc50a6e36a42b6c20516bf439cf200fe5be7d239db6e2c`），`scripts/crowd_separation.gd` 恢复为原文（LF/raw `3f6eb8221547787d5da59f58976ba506228c22ed5a3aa71822b160d659ce817b`）；先确认当前各文件确实是该代已知插桩源码，不覆盖外来变化。
2. `scripts/unit.gd` 必须等于 pins 中 exact raw/LF 原文，换成对应 instrumented Unit。只允许这一个生产脚本承担本轮计时。
3. 添加 `scratchpad/unit_body_sections_diag/generated/driver.gd` 和 `ledger.gd`。此前 Separation driver/ledger 可继续留作历史，但本轮不能加载；不能留下 Battle 的 SeparationDiag preload/计数。
4. `project.godot`、其他生产脚本、资源、公共 M1 三工具不变；运行参数选择新 driver。核对既有 source/import whitelist，形成新增两路径及必要新 UID/缓存的**新代次**收据；首次导入结束后再冻结实际源/缓存。不能把此前 3302 文件的收据当作新代次完整清单。
5. 不复用真实玩家目录，也不从已有私有 profile 复制玩家状态；为 timed/clockless 创建各自本轮空 profile，子进程 APPDATA/LOCALAPPDATA/TEMP/TMP 只指向这些目录。源项目与导入缓存可复用，profile 不复用。

除了上述私有三脚本的恢复/替换与两个新入口，没有别的授权改动；本稿没有自动应用器、还原当前源码 runner 或镜像复制器。独占目前在 root 的 first_use import，不能并行启动。

## 首轮只跑 timed / clockless 各 10 秒

root 审阅并确认容器后，使用实际非 `_console` Godot exe，沿已有 GUI Vulkan Forward+、固定镜头、分辨率、垂直同步/音频等 M1 条件，不设 fixed-fps、不 headless、不改变游戏速度/物理频率。只先 1×timed 和 1×clockless，不起多组或长跑；源码/入口字节在两模式间不切换。

子进程环境必填：`UNIT_BODY_SECTIONS_MODE=timed|clockless`、`UNIT_BODY_SECTIONS_OUT=<本代私有输出>/report.json`、`UNIT_BODY_SECTIONS_OUTPUT_ROOT=<本代私有输出父目录>`、`UNIT_BODY_SECTIONS_USER_ROOT=<本代空私有 profile>`。driver 强制原 `POLISH_CASE=defense200`、`POLISH_CAMERA=fixed`、`POLISH_SECONDS=10`，原 M1 报告输出同目录 `m1_10s.json`。环境值是运行参数，不能写成本机公共路径。

新执行收据应记录引擎版本/SHA、准确 PID/退出、模式、全部实际来源与缓存代次、私有 user://、准备/音乐/300 步预热、M1 原 started/now、原始日志/两报告。报告完毕且严格日志通过仍需确认真实进程退出才释放共同锁；首次编译/引擎失败保留原目录，修复后创建新的运行编号。不要为了此 2 窗口另造通用 runner。

有效性检查除了原 M1 与 sidecar 的全部断言，还要将实际两个报告联查：测量锚点 tick/帧数/秒数相同，步切片数量等于 M1 physics_ticks，原 raw_ms 与 sidecar 同一 now 的呈现间隔相同，每一步 body 起止相等、四段和相等、早退守恒；timed 时长非负，clockless 时长全部 -1。同场景、初始化和固定设置必须一致；测量中状态/伤害/单位数可能受计时扰动，不假称逐步一致。

首份汇总只列实际测量步数 N、各段每步均值/中位/p95、四段相对同次完整 body 的份额、单位回调总数/每步数、四类结束计数、呈现对应实际物理步数。均值按 `该段全部测量步 us 之和 / N`；不是“每次进入该段的均值 × 假定单位数”。首窗不足 600 步就用实际 N，不补齐、不把 10 秒墙钟改叫 600 步模拟。

结果只能决定是否值得进一步剖析某段。若候选总预算看似超过 0.5 ms，也须排除探针主导、同帧追赶和原本必要业务工作，再设计一个小范围具体候选；本轮不能变成优化、生产性能验收或 FPS 改善结论。
