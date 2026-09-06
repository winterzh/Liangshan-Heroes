# 飞斧已释放目标边界 QA 草稿

只写本目录；没有运行 Godot、修改 production/V2、GUI 或 Git。原始问题日志是 `scratchpad/reduced_effects_v2/runs/20260906T095337814487Z/report_freed_target_boundary.log`：`resolve_hits` 在 `is_instance_valid` 之前把已经 freed 的 Variant 赋给 typed Unit，脚本中断，后续目标未命中且效果未 queue_free；`_draw` 有相同顺序。不要通过丢弃错误日志或把“预期失败”记成 PASS 掩盖原版问题。

## 提取与两处修复

`prepare.py` 从 `scratchpad/physics_step_diag/frozen/battle_original.bin` 提取整个 `LiBrawnAxesFx` 类，先校验冻结 Battle 完整 LF SHA、原 class SHA、`resolve_hits` / `_draw` 方法 SHA。提取原版只把类头换成顶层 `extends Node2D`、去一级缩进；逆变换必须恢复原类。没有 helper/stub 替换、删分支、改变时长或改原方法。

固定候选仅在两处将原声明替换为：

```gdscript
var target_value: Variant = hit.get("target")
if not is_instance_valid(target_value):
	continue
var target: Unit = target_value
```

保留原声明后面的 hp/garrison/story 条件以及冗余的 target 有效性判定。`fixed.replace(NEW, OLD)` 必须逐字节恢复冻结原类。生成 `generated/original_effect.gd.txt`、`fixed_effect.gd.txt` 及 `pins.json`，文本不会被编辑器提前当脚本加载；QA 在生产 Autoload ready 后才通过 `GDScript.source_code/reload()` 编译。

原类 LF SHA：`21cc35423a6485dd4271e8da05161552add4d938b501531fe06c2ed0e162de3f`。冻结 Battle LF SHA：`784373eede18a82c24fc50a6e36a42b6c20516bf439cf200fe5be7d239db6e2c`。所有候选/方法/独立脚本摘要由 `pins.json` 给出。

可选 `prepare.py --candidate-battle <guard-only源文件>` 只读比对根任务已应用类必须与这份纯两处修复相同；若包含 V2 其他绘制变化，会明确拒绝，不悄悄替换冻结参照。当前任务验收的是原类边界修复，V2 组合由根任务自己的集成 QA 验证。

## 相同夹具与严格结果

`qa.gd` 两个模式共用全部断言。使用真实 `Unit`，仅将夹具 Unit 隐藏、禁用过程逻辑、关闭其战绩记录并设置初始 HP；真实 `take_damage/absorb_physical_damage` 不替换。ImpactRecorder 只计真实类对外发出的 impact 请求。

- 有效 caster/目标的正控制，保持真实攻击来源。
- `hits[0]` 是已释放的目标，后续有效目标必须减 11 HP、产生一次 impact；不能因第一项中断整个数组。
- caster 已释放，后续有效目标仍命中，来源为空。
- 死亡、驻军、story_outcome 目标在 resolve 中跳过，后续有效目标正常命中。
- 物免目标保持 HP、真实吸收字段增加 11。
- 同帧二次 `resolve_hits` 不重复伤害/吸收/impact。
- 检查真实 `queue_free`、`tree_exiting` 恰好一次和 weakref 释放；原版泄漏先记录失败，再由夹具统一清理。
- 保持 0.36 秒原时长，启用真实 `_process`，等待 0.70 秒后确认有效尾目标命中及实际生命周期退出。
- 两个真实 SubViewport：干净有效尾目标与 freed 首项+同一个坐标的有效尾目标；原生 Canvas 调用原 `_draw`，不直接调用或覆盖。使用 Art 的生产 axe 贴图，输出必须非空且两份 RGBA 一致，保存 clean/freed PNG。渲染夹具暂停效果计时，不发生伤害。

死亡/驻军/story 的跳过要求对应原 `resolve_hits`。原 `_draw` 只排除无效/死亡目标，本稿不额外添加驻军/story 绘制规则。没有借由 QA 扩大生产修复。

## 复现命令（需要根任务先取得 Godot 独占）

准备不调用 Godot：

```powershell
python -X utf8 scratchpad/axes_freed_boundary/prepare.py
```

下面两个入口必须分开跑，并使用新的输出目录。`$godot` 由根任务本机忽略配置读取，不写死路径。设置 CAMPAIGN_QA，正常玩家偏好问题仍沿根任务既有隔离运行方式；本脚本不保存玩家设置。

```powershell
$env:CAMPAIGN_QA = '1'
$env:AXES_BOUNDARY_MODE = 'original'
$env:AXES_BOUNDARY_OUT = 'res://scratchpad/axes_freed_boundary/runs/original_01'
& $godot --path . --rendering-method forward_plus --rendering-driver vulkan --script res://scratchpad/axes_freed_boundary/qa.gd --log-file scratchpad/axes_freed_boundary/original_01.log

$env:AXES_BOUNDARY_MODE = 'fixed'
$env:AXES_BOUNDARY_OUT = 'res://scratchpad/axes_freed_boundary/runs/fixed_01'
& $godot --path . --rendering-method forward_plus --rendering-driver vulkan --script res://scratchpad/axes_freed_boundary/qa.gd --log-file scratchpad/axes_freed_boundary/fixed_01.log
```

**原版预期退出 1 且 report.passed=false**；保留 typed-freed SCRIPT ERROR、后续目标未命中/残留和空绘制的日志/截图。若原版全绿，说明复现未建立，不能直接宣布修复通过。

**修复版要求退出 0、report.passed=true、failures 空、引擎日志无 SCRIPT ERROR/ERROR**；只看 JSON 不足以宣布 strict green。原版失败与候选通过分别报告，不合并为“全部通过”。脚本编译失败同样保留引擎日志，不能把未跑的断言算通过。此处不证明 V2 集成、全战斗平衡或 FPS。

当前仅完成 Python AST、来源/原类/方法摘要、双替换逆变换和提取逆变换；真实 Godot 编译、原版失败复现、修复版严格通过均待根任务执行。
