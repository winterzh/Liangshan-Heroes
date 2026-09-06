# 原生分段诊断草稿

固定源码参考 `4baafc11af55b0e46a57a48e54df181b8c1917a2`。仅新增本目录文件，没有改生产/公共工具、运行 Godot 或验证 GDScript 解析；没有正常 FPS 或性能改善结论。源码与安全 helper 的 SHA 见 pins.json。

## 最小继承与账本顺序

`driver.gd.in` 直接继承 `tools/polish_performance_probe.gd`，**不覆盖、不拷贝或改写它的 `_run`**。原来的 fixture、音乐预热、固定种子/输入、300 个实际物理步预热、frame_post_draw 起点、采样、截图、清理和玩家保存哈希检查继续执行。

- `_initialize` 只校验本目录内的输出、预分配 8192×18 的 PackedInt64Array，并固定 defense200/fixed/20 秒后调用 super。原生 M1 报告会按它原有的 `seconds >= 60` 规则保持 `acceptance_eligible=false`，原始 JSON 不被改写。
- `_new_battle` 等待 super 完成全部 setup，包括它最后的 `_prof_on=false`，再清原生计数、设 `_prof_on=true`、`_prof_print_acc=-1e9`。Battle 此时仍禁用处理，不会漏掉第一次正式模拟。负累加器抑制每模拟秒 `_prof_dump` 的打印和清零。
- 原生 TickDriver 的 physics priority 为 -10000。子 `_on_tick` 在 `super._on_tick()` **之前**收取上一完整物理步：`_prof`、`_prof_frames`、`_unit_proc_us`，校验一份 Battle 计数、九个标签、连续 tick，写入预分配行并清计数。随后恰好调用一次 super，记录本步的待收编号；不添加节点或修改 Battle/Unit 回调。
- 父 `_run` 在 `_dispose` 前已清空 `battle_ref` 并 queue_free TickDriver，所以子 `_dispose(b)` **只用传入的 b**：先禁用 b，收最后一个 pending 步，停止计时、导出，再 `await super._dispose(b)`。待收标志收取时即清掉，末步不会与普通边界重计。

采集覆盖第一次暖机到测量结束的所有 M1 tick。测量起点是父 `_run` 中等待 `frame_post_draw` 后的局部变量，子类不窥探或重写它。外部分析使用原始报告的 `sample_start.tick < row.m1_tick <= sample_end.tick`，要求行数恰好等于 `physics_ticks`、结束 tick 等于全部采集行数。因此不会把“达到 300 步”和“实际测量开始”混为一谈，预热之后等待绘制完成的额外步同样排除。

## 记录范围与扰动

九个标签按原有顺序保存：grid、aura、stealth_ecast、automicro、summon_eco、separation、fog、zones、level_hud。另存原 `_unit_proc_us` 为 `unit_phys_body_us`。这些都是生产内置计时器的读数，没有新增完整回调计时器。

原 `_pf` 先读取时钟，再读写 `_prof` 字典并返回这个时钟。因此本次 `_pf` 的字典操作会进入下一标签跨度；最后一项的该部分和 `_prof_tick`/smoke 尾段没有下一标签可收。开头的 phase 检查、部分计数/hero item snapshot 工作也不在标签链内。标签名只表示原先放置的计时区间，不能视为该函数纯净执行时间。

Unit 内置分支测量 `_phys_body` 及调用开销，**不含尾部剧情配对重绘**，也不提供逐单位回调次数。原来的计时读取/字典累积，加上每步 collector 的字典读取、清空和 packed 写入都会扰动运行；这里没有扣减探针开销、确定性战斗重放或正常 FPS 对照。标签/Unit 体是较小范围，不能再加到此前完整 Battle/Unit 回调账本上形成第二份“总成本”。采集时钟也不是完整 physics 阶段或屏幕呈现边界。

20 秒窗口仍沿用自然消耗 fixture，不补齐敌人、不延长暖机；`contact_covered` 原样带到分析收据，观察未接战时不把它当接战成本结论。任何溢出、丢标签、重复/缺步、Battle 原生计数不为一均令诊断失败。

## 使用与输出

默认只准备本目录生成件，检查固定 HEAD/源码/草稿哈希，不启动 Godot：

```powershell
python scratchpad/native_sections_diag/prepare_and_run.py
```

根任务取得独占时段后仅运行一次 fixed／20 秒：

```powershell
python scratchpad/native_sections_diag/prepare_and_run.py --run
```

Godot 路径取 `--godot`、`GODOT_PATH` 或本 checkout 忽略的 godot.local.txt。安全 helper 使用本轮已锁定的实际 renderer 启动参数，不从旧收据猜测后端。默认准备不受其他诊断占用影响；本诊断已经持有共享锁时，禁止重新生成自己的 driver。

运行器共用 `.godot/redraw_rejection_source.lock`，沿用精确 Popen、超时/中断终止、退出确认；运行前后检查原 M1 source receipt 与额外草稿/安全 helper 的原字节。无法确认进程退出或发生来源变化时保留锁和证据，不修改任何源文件来“恢复”。父工具的 CAMPAIGN_QA 和不保存设置逻辑保持原样；原生 sidecar 记录玩家 settings/campaign 前后 SHA，父工具再于完整清理后核对同样文件。

每次 runs 下分开保存：

- `instrumented_m1_20s.json` 和对应 PNG：原 M1 `_run` 的原样输出，包含带原生探针的帧时，验收资格必须为 false。
- `native_profile.json`：全部预热/测量原始分段行、标签掩码、步数、保存哈希、明确的 scope。
- `native_analysis.json`：仅用原 M1 tick 起止选出的分段总微秒、每物理步均值/最大值；不计算正常 FPS，不把各标签叠加到已测完整回调。
- 配置、引擎 SHA、来源前后快照、精确子进程及最终锁收据。

初次运行仍需验证 GDScript 继承解析、真实 callback/frame 顺序、末步与保存收据。静态夹具只能证明源码继承结构和 Python 选择区间，不代替真实运行；本目录不生成正式已通过文档。
