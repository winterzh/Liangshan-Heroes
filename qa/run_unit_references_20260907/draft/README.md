# Unit 引用传输草稿（未运行 Godot）

本目录只读采集、验证固定 16 个 Unit 引用字段及 `_queue` 的七种已知订单。已经完成源码核查和静态字段集合检查；**GDScript 编译和实际 QA 仍待根任务独占运行，不是已通过证据**。未修改生产、旧值适配器、旧 QA、存档或 Git。

## 接口与边界

运行时在 Autoload 就绪后加载真实 `scripts/unit.gd`、生产 `scripts/run_state_value_codec.gd`、冻结的 `scratchpad/run_unit_state_adapter/unit_values.gd`，再实例化 `unit_references.gd.new(unit_script, codec_script, values_script)`。构造器先核对三份源码的 LF SHA；原始字节 SHA 和全部草稿身份见 `pins.json`。来源不同直接拒绝，不能静默重锁。

- `capture_references(unit, registry, content_fingerprint)`：返回 `record`；主体必须在 `registry` 中。引用记录包含主体 ID、Unit 源码指纹和调用者内容指纹，17 字段作为一棵有限 codec 树编码。
- `validate_record(record, registry, expected_entity_id, expected_content_fingerprint)`：返回独立的 `references` 值描述，不返回或写入 Node。期望主体 ID 由调用者提供，不能从待验记录取来冒充校验。
- `capture_unit(...)` / `validate_unit_record(...)`：组合调用原值适配器；任一层拒绝时不暴露半份成功结果。只表示 241 个声明值 + 16 引用/数组 + 1 订单队列的运输范围，即 258/272 声明字段，另有继承的 `position/modulate` 两值。
- 所有结果 `restore_ready=false`。余下 6 个混合 ID/来源池、3 个 Battle/Map/Inventory 关系仍延期；5 个纯视觉缓存明确遗漏。存档元数据、定义业务校验、稳定 ID 对玩法 ObjectID 用途的迁移、完整引用图、过期引用恢复政策都未完成。

`registry` 是调用者提供的 `Dictionary`：**实际有效 Unit 对象键 → 稳定 ID 字符串**，不是 ObjectID 或当前活体数组下标。ID 要求规范正十进制、无前导零、范围 1..9223372036854775807，唯一且由调用者保证永不复用。主体、尸体以及引用涉及的有效实体都要登记。拒绝无效键、其它对象类型、重复 ID、数值 ID 和等待删除的注册节点。不同加载壳可以绑定同一份快照 ID 后验证；本草稿没有分配、持久保存或重映射这些 ID。

引用描述严格为 `{"state":"none"}`、`{"state":"entity","id":"..."}` 或 `{"state":"expired"}`。判断先看 Variant 类型，再检查有效性；已释放 Object 不归一为 null。有效但 HP=0 的尸体仍是 `entity`，有效未登记的 Unit 必须拒绝。过期项没有猜测的旧 ID；历史命中池的 tombstone 身份在延期的 6 字段内，本层不覆盖。

数组保留原顺序、长度和重复项。捕获/校验不排序、去重、清理队首、推进状态，也不调用 orders/setup/damage/physics/gold_busy。结构上接受重复或 none 槽不表示其归属关系合法：整局校验尚须处理唯一性、矿工状态、驻军双向关系、章节限制。过期标签也不能直接写成 null 或虚拟活节点后宣称可运行。

预算是防止无界输入的拒绝边界：注册表最多 4096 实体，两个数组各最多 4096 项，订单最多 4096 项；整份 17 字段还受现有 codec 总节点/字节/深度预算限制。不是保证任意同时达到单项上限的记录都被接受。

## 实际消费依据

完整固定表见 `field_contract.json`。本轮只读源核查：

| 字段 | 实际消费与需要保留的语义 |
|---|---|
| `story_assist_partner/owner` | `unit.gd:4036` 后互指和状态/距离判断；先保留引用，章节/双向约束尚未判定。 |
| `_gold_miner/_gold_waiters` | `unit.gd:1575` 占用条件自校验，只扫无效队首；后插入使用 `has`，轮候有序。不能提前调用或清掉尾部过期项。 |
| `_gather_node/_drop/_build_site` | `unit.gd:1595/1656/1701/1723` 在实际回调中择新资源、交货或推进任务，不能为保存触发这些回退。 |
| `garrison_holder/_garrison_dest/passengers` | `unit.gd:789/826/848` 双向驻军；通常插入去重，但 `1087` 逐条回血、`1847` 逐条发箭，重复会影响结果，不能变成集合。容量按数组长度判断。 |
| `rally_node` | `battle.gd:1964` 新生工人先复用有效资源，否则按种类/地点回退；不在采集时提前选新节点。 |
| `_taunt_src/_hua_lock_target/_target` | `unit.gd:1232/1310/1314/1346` 结合计时和可见性清理、重锁目标。`_do_chase:1481` 本身先读 ObjectID，正常物理入口有前置清理；这不是本轮新缺陷结论。 |
| `_pending_target/_killer` | `unit.gd:1913` 延迟命中先标记已结算，再检查目标；`971` 记录有效击杀者，尸体引用不能因 HP=0 被删除。 |
| `_queue` | `unit.gd:446–543` 七种固定生产形状；`585/635` 从前弹出并执行，不去重。`move/amove={kind,pos,group_cap}`；`attack={kind,target,explicit}`；`gather/build/repair/garrison={kind,target}`。缺已知字段、未知种类/字段、非有限 Vec2/float 和非 bool explicit 都拒绝，不套用消费函数的 get 默认值。 |

## 最小实际引擎验证（由根任务运行）

使用当前根 checkout 资源，只 runtime load 上述脚本并 `.new()` 真实 Unit，**不入模拟树、不 setup、不载 Battle**。不必复制资源工程。`.gdignore` 防止编辑器自动扫描草稿；显式 runtime load 路径仍是这个目录。外部启动器必须采用已测私有 profile 模式：子进程独有 APPDATA/LOCALAPPDATA/TEMP/TMP，拒绝 project 的 custom_user_dir，先后保护真实玩家 settings/campaign 文件，核对源路径集合和 raw SHA，持共同 `redraw_rejection_source.lock`，无其它 Godot 并发。

本目录没有再造 runner。供根任务接入现有进程守卫的一次入口为实际非 console exe：`--headless --path <checkout> --script res://scratchpad/run_unit_references/qa_driver.gd`，仅运行这一份完整 QA。`UNIT_REFERENCES_QA_MANIFEST` 指向新建 `scratchpad/run_unit_references/runs/<id>/manifest.json`，最小字段如下：

```json
{
  "run_id": "<unique id>",
  "run_dir": "<absolute new scratchpad/run_unit_references/runs/id>",
  "private_user": "<verified actual user:// under this run private APPDATA>",
  "report": "<run_dir>/report.json",
  "source_sha256": {
    "project.godot": "<current raw SHA>",
    "scripts/unit.gd": "<frozen raw SHA>",
    "scripts/run_state_value_codec.gd": "<frozen raw SHA>",
    "scratchpad/run_unit_state_adapter/unit_values.gd": "<frozen raw SHA>",
    "scratchpad/run_unit_references/unit_references.gd": "<frozen raw SHA>",
    "scratchpad/run_unit_references/qa_driver.gd": "<frozen raw SHA>"
  }
}
```

源清单的六项 runtime 检查不代替外部全生产来源收据。QA 在 Autoload 完成后才能比对实际 `user://`，因此外部私有环境保护必须在 Popen 前成立。report 只允许写入上述新目录的 `report.json`。外部必须确认实际 PID、退出码、manifest SHA、完整报告和最终覆盖检查；失败、超时、Parse Error、Unicode parsing error 或空结果不得当通过。复用之前严格日志/超时/owned-process 退出保护，不自动 import、不改源码。

QA 草稿覆盖默认全字段、14 直接引用逐项读取、两数组保序/保重、真实 free 后 Variant、活尸体、七种订单和重复/过期订单、JSON 类型与 >2^53 ID、调用者另建壳同 ID 验证（同 PID）、未登记活对象/重复或非法 ID/类型/字段/订单拒绝、与原值层组合拒绝、RNG/信号/原容器不变。`check_groups` 分开 behavior/rejection/json/fixture/source/environment；真实检查数待引擎报告，不预填通过数量。没有真实跨进程续玩、任务推进或图恢复实验。
