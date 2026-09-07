# 稳定实体身份候选交接（2026-09-07）

本目录为唯一开发工程 `D:/AI项目/水浒/开发工程` 内的隔离候选，未覆盖生产，未运行 Godot，未提交 Git。状态为 `static_verified_runtime_pending`。原七文件草稿的 before 与当前生产逐文件 LF 相同，另将当前所有关卡创建路径纳入审查。正式生产和当前候选 SHA 均在 `source_receipt.json`；本轮冻结输入见 `freeze.json`。`parser_runtime/` 是隔离安装的第三方检查依赖，不纳入生产或归档发布清单。

## 已实现的候选语义

Battle 分配正 int64 的 `entity_id`，从 1 开始；最大 int64 仅为耗尽的 next 哨兵，实际最后可分配 ID 为 9223372036854775806。先分配再构造；分配后的构造失败、死亡、章节清场均不回收 ID。允许空壳 Unit 以 0 存在于检查/绑定阶段，正式捕获和激活拒绝它。`next_entity_id` 以十进制文本保存，避免 JSON 浮点截断；图准备仅返回 pending allocator，外层先安装它再激活任何单位。

稳定 ID 用于排序、分离方向/分相、自动经济对象表、末波位置跟踪/纠偏及章节实体键。原生 ObjectID 仍用于短期战斗 target/source/hit token，并由 `run_graph_identity.gd` 显式映射。不能把这两个键域合并。Unit schema 为 v2，273 个显式声明，244 个值字段（其中 242 个声明字段，另加继承的 position/modulate）；graph schema 为 v2。root/active 顺序分开保留，死亡动画对象仍在 root 中，typed tombstone 到所有图绑定结束再由外层释放。

共享生产/建造/召唤及据守/AI 的旧候选保护得以保留。关卡所有直接创建调用加失败检查并向调用者传播；必需替换先创建成功再移除旧实体，涵盖新旧江州、野猪林、连环马演练骑、高俅上岸。已付费的新战役敌军补兵失败先退回本次金木，完成计数不前进。标准、竞技场、scenario 波次与固定清场重部署先检查 ID 容量；波次提交仅在创建成功后进行。正常成功路径的创建调用参数和源码顺序、RNG 调用参数和源码顺序、Engine 帧计数调用保持不变，未改变波次/敌军数值。

这不是全部世界的任意失败回滚。初始部署或合法 ID 已分配后出现地形/自定义 hook 错误，可能保留部分新对象；候选会停止该世界。尤其 `campaign_mission.gd` 在 `on_mission_action` 前已设置 action.done、禁用控件并写 mark，所以保留旧实体只是保护局部对象，不能宣称整个任务原地回滚。必需替换失败会进入 `_gameplay_rng_stop`，当前真实代码会暂停并提示“本局运行异常”。候选 graph 捕获返回 `BATTLE_FAULT`，当前 RNG 捕获也拒绝故障；未来 RunSession 保存入口必须在请求受理、屏障捕获/写入提交前分别检查健康态，失败不得创建/覆盖槽位或返回“保存成功”。当前还没有可测试的玩家保存入口。

## 静态证据

运行 `py -3.14 -X utf8 -B scratchpad/stabilization_identity_20260907/review.py`。

`static_review.json` 记录 24 文件、154 方法白名单、113 个改动关卡函数格式展开前后 AST 相同；补丁在内存中精确回放，生产原字节不变。`semantic_inventory.json` 保留 350 个源码创建调用位置：8 个共享路径，207 个关卡路径，135 个只在新鲜 allocator 上运行的开发自测。行数并非动态测试场景数。真实 `Unit.new()` 的 Battle 热补丁探针不加入世界，唯一正式出生路径是 `spawn_unit`；图的离树空壳不是 gameplay spawn。

旧审查把下一个顶层常量块算进上一个函数，误报 `_unit` 和 `_id`；现在函数在任何下一个顶层代码处结束，常量变更单独由完整 diff/SHA 审查覆盖。gdtoolkit 4.5.0 通过全部候选与驱动语法；它对 Battle 两条原有 `== not hud.touch_ui` 不兼容，检查器只在解析内存中加括号，候选未更改这两句。语法检查不等于 Godot 类型检查或运行验证。

## 待执行的真实驱动

`identity_smoke.gd` 从正式归档的 5 个真实 Unit 图驱动移植，保留 root/active 独立顺序、dying、引用重复、typed tombstone、原生 target/source token、物品 UID、无部署绑定与暂停激活，并增加稳定 ID 和失败案例。实际 Battle 的出生、已释放 ID 不重用、int64 边界、故障 RNG/graph 捕获拒绝都使用真实脚本；关卡替换/退款/波次失败使用明确拒绝创建的 Battle 测试替身，测试真实关卡方法的消费边界。

由 QA 所有者在新建独立工程内覆盖 `source_receipt.json` 的 24 文件白名单，将驱动复制为 `tools/stabilization_identity/identity_smoke.gd`。不在生产运行，不套旧 `run_smoke.py`。私有 APPDATA/LOCALAPPDATA/TEMP，源代码和真实玩家目录前后 SHA 守护，持独占 Godot 槽，保留进程退出和原始日志。命令：

```text
Godot --headless --path <独立测试工程> --script res://tools/stabilization_identity/identity_smoke.gd
```

环境变量 `RUN_RESTORE_QA_MANIFEST` 指向 manifest JSON，字段为 `run_id`、`private_user`（实际 Godot user_data_dir）、`report`（全新绝对路径）、`source_sha256`（工程根相对路径到 SHA；须包含实际驱动及候选与加载依赖）。驱动拒绝已存在报告，不进入 Battle._ready，不读写正式玩家文件。报告 suite 为 `stable-identity-candidate`，stdout 前缀为 `[stable-identity candidate QA] `。

晋级还需 Godot 解析/类型/驱动通过，标准 30 波和八关原成功路径回归，以及根事务、时钟/屏障和玩家保存入口的失败测试。首版继续本局范围仍是标准 30 波，之后祝家庄，再其余七关；本次给旧关卡、AI、scenario 的保护不等于开放这些模式续玩。

## 根状态接续注意

候选新增 Battle `next_entity_id`，后续字段清单不能静默漏掉。`_focus_counts`、`_res_block_cache`、`_eco_lane_cache` 内与实体相关的映射、skirmish `_final_cleanup_positions` 现在使用稳定 ID；它们应保留整数值域，不应通过 native target/source ID 编码后再恢复为 ObjectID。视觉重绘分相使用稳定 ID，但 Engine 帧时钟尚未迁移；这仍需模拟时钟候选接续完成。战斗 `_pending_casts/_channels` 和其余效果不能仅恢复数值数组而遗漏对应 Fx 节点和角色动作态。

## CLI entry revision 2

First native attempt `identity_20260907T061258Z_551411d4` failed before behavioral validation: entry preload and test-only typed signatures compiled game classes before Art/Sfx autoload availability. Prior driver/receipts are retained under `attempt_history/first_entry_compile_failure`. Revision 2 defers Graph load inside `_run` and removes production-class annotations only from RejectBattle. All 24 overlay scripts remain frozen. Parser passes; native rerun pending.
