# HeroInventory 显式局部值草稿

2026-09-06。仅在本 scratchpad 新建适配器和真实对象 QA；没有修改生产、既有测试或运行 Godot。`inventory_values.gd` 对实际 `scripts/hero_inventory.gd` 实例显式 capture/validate。当前状态是**待根任务解析与真实运行**，不能宣称 QA 通过或完整续玩完成。

## 字段与来源

当前 HeroInventory 只有六个顶层 var；其中五个是完整局部值，一个 `owner` 关系明确延期。运行时不扫描属性清单，不反射 Node，也不自行 dump RefCounted。

| 实际声明 / 行 | 本草稿处理 | 不能派生的原因 |
| --- | --- | --- |
| `owner`，9 | 不读取、不编码，成功始终标记 deferred | 需要稳定 Unit 身份、none/entity/expired 语义和 Battle 生命周期；局部值成功不证明 owner 有效 |
| `slots`，10 | 六个有序槽；空槽严格 `{}`，占用槽完整 `id,count,uid` | 槽序影响玩家选择；重复 item id 可存在，UID 是不同物品实例身份 |
| `cooldowns`，11 | String item id → 正有限 float；保留实际 Dictionary 迭代顺序 | 同名主动物品共享剩余冷却；不能按定义初始 CD 重建 |
| `proc_cooldowns`，12 | 规范 `uid:event` → 正有限 float；保留迭代顺序 | 每件物品被动内置 CD；转交保留 UID 及该件 CD |
| `_uid_seq`，13 | 非负精确 int64 | 不能由当前槽数或最大现存 UID 反推，不能重新购买/put_item 生成 |
| `_periodic_acc`，14 | 精确有限 float，0 ≤ phase < 0.25，保留负零位 | 原 tick 的周期相位；重置会改变下一次被动 periodic 事件时点 |

`_init` 17–19 只赋 owner 和建立六个空槽，两个 CD 字典、序号与周期相位使用声明默认值；QA 覆盖这一实际构造后状态。`tick` 220–230 先减少 CD、累加并取模周期相位，再向 Battle 发 periodic 事件；本草稿不能通过 tick 对齐相位。

旧 `snapshot` 306–308 没有 `_periodic_acc`，不是本草稿的完整值入口。旧 `restore` 311–320 会重置槽位、对 seq 取 max，随后 `_notify_changed` 334–339 重算英雄属性、重绘并刷新 HUD；本草稿不用它。恢复赋值层尚未实现，QA 对非默认对象的直接字段赋值只是布置输入，不是从存档恢复。

`_new_uid` 46–49 使用 `owner.get_instance_id()*1000 + _uid_seq`；`transfer_slot` 125–149 保留转入物品 UID，但不抬高接收者 `_uid_seq`。因此 UID 与 seq 都逐值保存，不要求 seq ≥ 当前 UID，也不把新 owner ObjectID 代入旧 UID。未来跨对象 UID 唯一性、旧物品来源/待施法引用和下一次分配器策略仍须上层处理。本层接受的正 int64 极值仅验证保存精度，并不保证随后分配不会溢出/碰撞。

## 接口与严格边界

```gdscript
# 项目 Autoload/全局类就绪后，由受控调用方加载固定源。
var adapter = adapter_script.new(inventory_script, value_codec_script)
var captured = adapter.capture_values(actual_inventory, expected_content_sha256)
var checked = adapter.validate_record(parsed_record, expected_content_sha256)
```

返回成功时始终 `restore_ready=false`。capture 产生精确四字段 `schema,inventory_source_lf,content_fingerprint,values`，values 是对五字段整棵树调用一次 c8c4… codec 的标签树；不会逐字段分开预算。validate 解码、检查完整字段与局部关系后返回独立 values，完全不赋给 Inventory。任一失败不返回部分 values/record。

构造时核对加载的 Inventory / codec 源码 LF 摘要，capture 再核对实际对象的脚本身份；源码漂移先以 SOURCE_CONTRACT 拒绝。原文件 raw/LF 双摘要与五份运行来源见 `pins.json`；没有每 tick 读取源码或调用 owner 的任何方法。

局部规则为：恰好六槽；id 为非空 String、最多 128 字符；count/uid 为正 int64，不默默转换 float；槽内 UID 不重复；共享 CD key 必须对应持有的 item id；proc key 的 UID 文本必须逐字对应某个持有 UID，event 非空、无额外冒号、最多 128 字符。两类 CD 必须正有限 float，已到期项在原 tick 会删除，故稳定采集点不接受零/负项。proc 最多 256 项，所有宽度先检查再遍历；整个值树仍受 codec 的深度/节点/1 MiB 保守字节预算限制。没有排序、clamp、丢弃未知字段或自动填默认值。

内容指纹由上层提供并精确比对，本模块不自行计算或证明它。它不调用 `item_def`，不查询当前 Battle 的动态物品覆盖，不验证 id 是否存在、count 是否小于真实 max_stack、event 是否为该定义触发器或 CD 是否符合业务规则；`business_item_definitions_validated=false` 明确保留。Defs.ITEMS 当前为空，真实 `HeroInventory.item_def` 28–32 可委托 owner.battle，不能偷偷拿静态默认表代替有效内容。

这些局部结构限制只覆盖当前源码可产生的稳定形状。上层须在完整模拟步边界同步采集，验证内容/物品定义和所有关联对象；多次字段读取并未自行建立跨对象原子快照。零/负 CD、超长自定义事件或手工扩展槽字段会明确拒绝，不暗中剪裁。

## 与 Unit / Battle 的边界

局部值中保存的 UID 不是完整引用图。Battle 的 `_pending_item_casts`、`_walk_item_casts` 等持有 caster/slot/uid/目标，`hero_item_progress` 保存死亡待复活的旧 snapshot；它们还需要独立适配。Unit 的属性、护盾、毒/火/光环/来源池，以及 Battle 的效果目标与 RNG 均不属于 Inventory 字段。本草稿不使用购买、装备、使用、转交、被动结算、重算属性或旧 restore 重造这些状态。

`_uid_seq`、槽 UID 与 proc key 原样保留，只证明局部数值精确；重新建立 owner、全局去重、效果/来源和未来分配仍未实现。不能把 owner 恰好为空/过期时 capture 成功写成引用已恢复。没有 apply/restore、磁盘 I/O、目录恢复、菜单继续或真实战斗复演。

## 真实对象 QA 草稿

QA 延迟加载真实 HeroInventory 脚本并直接构造对象，使用已晋级 c8c4… codec；正例都执行真实 JSON.stringify/parse，再验证类型、UID/seq 精度、槽位置/空槽、两类 CD 顺序、周期相位及精确重新编码。覆盖默认/稀疏/满六槽、重复 item id、转交形状下 seq=0、大于 2^53 的 UID/seq、int64 UID 上限和近周期阈值。解码容器修改不影响源对象，捕获/验证不消费额外 RNG；owner/Battle 是记录回调的测试 probe，不能因此声称测到了真实 Unit 效果。

负例包括缺/多字段、五/七槽、错误 item/count/uid、重复 UID、孤立 CD/UID、非规范 proc 文本、错误相位、NaN/INF、来源/内容指纹不符、恶意 Object、无效主体与过期 owner 延期语义；本次新增的标识符/256 项宽度边界也有草稿检查。非法 Object 直接进入拒绝路径，不先 stringify。所有 QA 尚未运行；实际检查数以根任务新 report 为准。

不建立新 runner。根任务复用现有独占/真实进程句柄/源与玩家保护，使用当前已导入工程（HeroInventory 依赖全局 Defs）和本次独立 APPDATA/LOCALAPPDATA/TEMP/TMP；不要无保护地指向正常玩家 profile。传入 `INVENTORY_QA_EXPECTED_USER_DIR` 的实际绝对路径，GD 开始时必须与 OS 的实际 user 目录一致。

```text
<actual non-console Godot exe> --headless --path <current imported checkout> --script res://scratchpad/run_inventory_state/qa_driver.gd
```

可选 `INVENTORY_QA_OUT` 只能是本次私有 user 目录内尚不存在的报告文件，父目录须已存在；省略则 stdout 输出完整 JSON。报告包含实际 PID、user://、engine、五份源码 raw SHA、非空 checks、check_count、failures 与明确的未实现范围。父控制器仍须严格核对 Unicode parsing error / Parse Error / ERROR / WARNING / FAIL、准确退出、源码/玩家数据和锁归属，不能只信 report.passed。
