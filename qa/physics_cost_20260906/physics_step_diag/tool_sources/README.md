# 物理步成本账本草稿

仅诊断当前标准 200 敌压力段。默认只准备；本次没有应用插桩、运行 Godot 或 Git，没有验证 GDScript 解析，也没有正常 FPS 结论。所有草稿、冻结副本、生成件和将来运行输出限定在 `scratchpad/physics_step_diag/`。

## 来源与保留范围

- Unit：候选 LF SHA `c8a692bff598b6ac9199d113ccc9ff39ea8943f127012b45fc67ff2cd6c4deec`，原始字节 SHA `c8310fd12a29858df8f7410dd06d2f1dc51f40f5eedc0e7a6a16599eb5e58856`。
- Battle：原始字节 SHA `9fe157e49ef18f2ced0b10ee96f893a1f0ded4ce64e6d757e936d4ef4e9e1ee4`。完整方法、M1 driver、继承测试基类、安全 runner 等 SHA 见 `pins.json` 和 `preparation_receipt.json`。
- Unit 始终从 `scratchpad/redraw_reject_validation/unit_before.bin` 和 `apply_redraw_candidate.py` 中的两个纯文字方法替换重建，只用 AST 读取字典，绝不执行该修改脚本。最终完整 raw/LF SHA 必须同时匹配；正在轮换的工作树 Unit 不参与重新定版。
- 完整 `_physics_process` 只改名为私有方法，外层同名 SceneTree 回调恰好调用一次，再计时。原函数体的所有字节、早退、`_phys_body` 和剧情配对重绘尾段都保留。Battle 与 Unit 是 SceneTree 分别调度的回调，两个完整跨度不嵌套。没有包裹其内部 `_phys_body`，没有 crowd/grid 子项，不会重复计费。
- 继承固定的 `tools/polish_performance_probe.gd`，复用 `_new_battle`、`_configure_settings`、`_on_tick` 和原 TickDriver；仍是 200 敌、6 个 rank 2 英雄、实际 auto micro 3、标准属性和自然消耗。音频音乐等待、随机种子、300 个实际物理步预热、fixed/auto 镜头设置均沿用 M1。不是持续补齐 200 人，也不是 30 波驻守通关。

## 账本语义和扰动

`SceneTree.physics_frame` 边界读取 `Engine.get_physics_frames()`，每步在标量中分别累计 Battle / Unit 总微秒与回调数；每步只写一行预分配 PackedInt64Array。回调计时尾部再次携带 Engine physics frame，若与边界不一致即标记无效，不偷偷归到相邻步。

`RenderingServer.frame_post_draw` 冲刷最后一个物理步，每个绘制完成帧记录 `[first_step_index, physics_step_count]`，允许一个帧包含 0、1 或多个追赶步。这个信号是渲染完成边界，不能解释为显示器实际扫描呈现时刻。每个物理步必须只属于一个边界区间，离线分析检查连续性、唯一归属、M1 tick 总数及同帧成本上界。

缓冲固定为 8192 步与 65536 帧，在创建 Battle 前一次分配，测量期间不 resize、不 append、不建逐单位 Dictionary、不逐步写日志。溢出使诊断无效并结束采样。JSON 行转换、汇总、文件输出发生在 Ledger 停止且 Battle 禁用处理之后；继承的 M1 TickDriver 每 60 步轨迹采样仍保留，它已有的数组/字典分配不是本草稿新增，但会占未归因时间。

两个模式使用完全相同的包装源码、共享 Ledger 脚本资源、缓冲容量和节点结构：

- `timed`：每个原回调增加两次时钟读取、一次 Engine frame 读取和标量累计。时间跨度包含调用完整私有原方法的分派，尾部记录成本不在该跨度内。
- `clockless_control`：同样只调用一次完整原方法，但跳过上述逐回调读取/累计；物理边界与呈现账本仍启用。成本和回调次数保存 `-1`，离线输出为 `null`，不能视为零成本。它可以粗查计时探针新增扰动，但仍有包装器与账本，不能充当生产基准。

没有新增 RNG 调用或诊断 Node，但新增共享 GDScript Resource、预加载和包装器可能改变实例 ID 分配、分帧分组、缓存和代码布局。两个模式分配结构相同仍不保证精确战斗复现；原有音频全局 RNG、墙钟节流、渲染帧驱动斧头伤害也会随耗时改变战斗。必须记录初始部署和多次统计，不从一次 A/B 直接声称探针开销百分比。

`last_measured_callback_end_us - start_us` **不是**完整引擎 physics 成本；它还夹有未测回调与间隔，也可能没覆盖末尾其他回调。只有 Battle 完整回调与所有 Unit 完整回调可各加一次。呈现区间减两者的 `unattributed_interval_us` 仍包含探针、其他回调、渲染、引擎阶段和等待，不能命名为 process、draw 或某个新瓶颈。`presentation_bookkeeping_us_partial` 只记录呈现入账的大部分工作，未覆盖末尾写入、边界回调和计时包装，不能拿来从所有结果扣掉“总探针成本”。

## 使用顺序

在 checkout 根目录，用可用 Python 3.9+ 执行。下列第一组只生成草稿和运行 Python 静态/离线夹具，当前任务只做到这一组：

```powershell
python scratchpad/physics_step_diag/prepare_and_run.py
python scratchpad/physics_step_diag/static_checks.py
python scratchpad/physics_step_diag/recovery_checks.py
```

将来由根任务取得独占 Godot 时段，先跑 10 秒入口检查；这一步首次验证 GDScript 是否可解析、回调帧 ID 是否对齐、日志和恢复是否正常：

```powershell
python scratchpad/physics_step_diag/prepare_and_run.py --run --seconds 10 --cameras fixed --repeats 1
```

入口通过后，用 20 秒测量覆盖完整 M1 前十秒和其后上下文，fixed/auto 各重复三次；两个模式默认随重复奇偶交替顺序。300 步预热后才开始这段墙钟计时，不延长预热来隐藏压力：

```powershell
python scratchpad/physics_step_diag/prepare_and_run.py --run --seconds 20 --cameras fixed auto --repeats 3
python scratchpad/physics_step_diag/analyze.py scratchpad/physics_step_diag/runs/具体运行目录/timed_fixed_1.json
```

需要与 M1 全时长位置对照时可显式使用 `--seconds 60`，仍只作诊断，不产生 FPS 验收。Godot 路径从 `--godot`、`GODOT_PATH` 或当前 checkout 的 `godot.local.txt` 获取，没有写死本机路径。控制继承环境时复用既有 helper，只记录允许的开关，不记录环境全集或凭据。

离线分析输出每步均值、每帧实际步数直方图、超过 100 ms 的帧以及前两帧/后一帧上下文。前十秒统计包含起点在区间内的完整帧，会保留与十秒边界交叠的整帧和整步，不按墙钟比例拆一次物理计算。读取的是原始逐帧账本，不使用低频 Performance monitor 拼凑成本。

## 独占、备份和恢复

运行前复用已增强的 `scratchpad/redraw_reject_diag/run_redraw_reject_diagnostics.py`：确认无既有 Godot 进程、保留精确 Popen 句柄、超时/中断 kill 后 wait、子进程退出不明确时阻止任何恢复。共用 `.godot/redraw_rejection_source.lock`，不会与根任务的参考/候选切换同时改源。

两份原始完整字节与插桩副本在首次生产替换前全部保存并核对。每次替换前再次确认独占和预期当前字节，通过同盘临时文件 `os.replace` 原子替换一个文件。两个文件不是跨文件原子事务；第二份失败时 finally 恢复第一份，期间绝不启动 Godot。运行前后校验生产来源指纹与四个生成件，UID 派生旁文件不作为草稿源码变化，其他新来源变化使样本失败。

finally 先确认所有 Godot 已退出，再逐文件只恢复“当前等于本次插桩”的文件；已等于原件则保留；未知当前字节另存冲突，不覆盖。恢复使用已验证的内存原字节，磁盘备份若损坏会明确写入收据。只有两份文件都回到原字节且锁仍归本运行，才解除锁。任何无法确认的进程/恢复/冲突都保留锁和 `restoration_receipt.json`。

进程被外部强杀后可显式恢复，脚本会检查当前锁归属、两个备份 SHA、插桩可重建性及当前文件是否是已知原件/插桩件。遇到外来修改停止，不提供强制覆盖选项：

```powershell
python scratchpad/physics_step_diag/prepare_and_run.py --recover scratchpad/physics_step_diag/runs/具体运行目录
```

`static_checks_receipt.json` 只证明源码变换与离线账本夹具通过；`recovery_checks_receipt.json` 记录在本目录模拟文件上执行的原子恢复、部分应用、备份损坏、未知编辑、未确认子进程和第二文件恢复中断检查，未调用实际进程管理。两者不能替代 GDScript 解析、真实回调调度、Godot 异常退出/恢复演练或正常无插桩性能基线。
