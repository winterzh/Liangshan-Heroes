# Unit 显式值字段适配器草稿

2026-09-06。只在 scratchpad 实现，没有修改生产或旧已测草稿。当前实际值层 QA 已通过 **77 项检查（12 项来源、65 项其余断言）**，详见末节；完整战斗恢复仍未实现。`prepare.py` 静态核对当前 Unit 的 **272 个顶层 var** 与 `defense_resume_schema.md` 精确索引一一对应；完整表在 `FIELD_TABLE.md` / `field_catalog.json`。扫描发生在离线准备阶段，运行时代码是逐字段 `unit.hp` 等显式读取，没有 property list、Node 序列化或反射遍历。

## 当前覆盖与接口

- **241 个声明值字段**：基础/当前属性、成长与派生断言、全部非引用临时数值和剩余计时、技能槽、原定义值树、变身和原始备份、训练链、路径/命令数值、死亡/挥击/施法状态、UI 断言及廉价视觉连续性。另显式读取 Node2D 的 `position`、`modulate`，共 243 个值。其余继承属性、meta、registry/信号/物理顺序另有接口需求，不计入 272 声明覆盖。
- **26 个明确待实现字段**：16 个 Unit 引用/有序引用数组，6 个稳定 ID/来源池，Battle/Map/Inventory 三项关系，以及包含目标引用的 `_queue`。每次成功都携带完整 deferred_fields，不会因为某次恰好为空就当作已适配。
- **5 个只绘制缓存**：`_real_frames`、`_frame_directional`、`_animated_redraw_t`、`_queued_redraw_frame`、`_dust`。刷新画面时由独立纯绘制入口重建，不能用完整物理步代替。

旧索引把 `_weapon` 列为绘制缓存，本草稿改为保留：`_weapon_kind` 的返回决定 `_attack` 下一击的 `_swing_kind`，继而选择 `_swing_speed/_hit_at`（Unit 1882–1898、2134–2158），不能未经证明清掉。`_stepped` 也廉价保留。`_lunge/_hit_at/_pending_done/_cast_t/_cast_serial` 均是显式值，不能重播攻击/施法来凑现场。

```gdscript
# 仅在 Autoload 就绪后，由受控调用方加载固定来源。
var adapter = adapter_script.new(unit_script, value_codec_script)
var captured = adapter.capture_values(actual_unit, expected_content_sha256)
var checked = adapter.validate_record(parsed_record, expected_content_sha256)
```

`capture_values` 返回 `{ok,record,coverage,restore_ready:false}`。record 严格包含 `schema,unit_source_lf,content_fingerprint,values`；values 是有限值 codec 的标签树。`validate_record` 完整解码、转换、复验后返回原生值字典，不赋值给 Unit。任一步失败不返回部分值，缺字段/多字段/错误类型/范围/源合同或 caller content fingerprint 不符均拒绝。每个 Unit 整体调用一次 codec，避免逐字段绕过总节点/字节预算。

构造时一次性核对已加载 Unit/codec 的 LF 源摘要与冻结常量，capture 再核对实例所用脚本身份。源里增删字段或方法会先得到 SOURCE_CONTRACT，不等直接成员访问报错。这里只读固定脚本文本作来源校验，不扫描 Node 属性；没有每物理 tick 读源码。

调用方仍须建立暂停/采集屏障，包含 process 与 physics 的权威效果；逐字段同步读取没有自行建立跨线程或跨对象原子快照。QA 的孤立未入树 Unit 只能验证本值层不会主动推进或修改状态。

当前内容指纹是**调用方传入并比对的合同值**；此模块不计算有效 Defs、能力/物品覆盖或业务内容指纹。`setup_def` 整棵值树被保存并受 codec 限制，顶层只能是 String 键，Object/Resource/Callable/循环/非有限值拒绝；尚不验证未知业务键、定义引用或数值含义。coverage 因而明确 `business_definition_validated=false`。本草稿是值层适配器，不能当作可接受不可信战斗存档的完整 validator。

## 具体类型和边界

- 当前 Unit 的 Array 字段声明均为普通 Array，并没有 Array[Unit] 之类声明；不伪造恢复其不存在的泛型约束。`_train_queue` 检查非空 String 顺序和生产入口 8 项上限（Battle 1713）；`group_nums` 是已排序不重复整数的 UI 断言，最终以 Battle groups 为唯一权威重新核对。
- `_path` 原类型是 PackedVector2Array。编码前检查 4096 点上限及有限组件，显式转 Array[Vector2]；JSON 解码后逐点验证，再构建 PackedVector2Array。不会隐式把数值/Array 元素转 Vector2，也不重算路径。`_path_i` 必须是非负整数，允许当前消费逻辑中已耗尽/旧态的光标；跨字段与地图规则仍需上层校验。
- `_ai_dest`、`mission_order_target` 仅接受有限 Vector2 或精确 `Vector2(+INF,+INF)`；`_chase_best_distance` 仅接受非负有限 float 或 +INF。各字段分别变成严格的 finite/positive_inf 小结构，经普通有限值 codec 中转；−INF、半无限向量、NaN 和额外字段拒绝。普通字段无全局 INF 开关。
- `_form` 仅接受源码读取的 `hp_mult,atk_mult,speed_mult,atk_cd_mult,range,radius,tint`；`_form_backup` 必须为空或完整六项 `atk_cd,base_speed,radius,mod_r,mod_g,mod_b`。技能槽必须完整七项 `id,rank,cd_t,passive,charges,recharge_t,cast_seq`，保留 int64 cast_seq 和浮点计时。
- 精确枚举包括 0..8 的 Unit 状态、阵营/姿态/追击意图/武器、英雄等级、16 相位 AI 序号等。普通临时 float 只要求有限，保留合法的负剩余计时，不随意 clamp 或拿定义默认值覆盖。默认未 setup 的真实 Unit 可用于本值层 QA；业务层仍须检查 key、HP/上限、成长/库存与场景合法性。
- 标准驻守下非默认 `defeat_outcome,story_outcome,_story_pose_t,_pose_previous_variant,is_captive` 拒绝。两个 story assist 引用仍须下一层验证，不能据本值层成功认定没有剧情关系。

引用层必须分别处理 none/entity/expired，强关系（矿位/驻军等）和短期失效目标按原消费语义验证。`_queue` 有序项包括 move/amove `{kind,pos,group_cap}`、attack `{kind,target,explicit}`、gather/build/repair/garrison `{kind,target}`，不能调用 order/_enqueue 重新生成。`_charge_hit`、`_giveup_id/_chase_last_id/_lin_spear_target_id` 不是普通数值；两个来源池还混合 ward serial 与负 ObjectID 偏移，须保持实体/效果/历史 tombstone 身份。Battle/Map 重新绑定，HeroInventory 用独立六槽/CD/UID/周期相位适配器，不能序列化 RefCounted 对象。

## QA 准备方案与范围

`qa_driver.gd` 延迟加载真实 `scripts/unit.gd` 与有限值 codec，创建实际 Unit 实例但不调用 setup，不放进模拟树。正例有默认 243 值、完整非默认 HP/护盾/隐身池/负冷却/路径/施法/挥击/施工/待出口训练/技能槽/变身；跨真实 JSON 语法后检查类型与大于 2^53 的序号，再核对来源 Unit 值未变、无 RNG 消耗/信号、解码容器不与源共享。负例含缺字段/多字段/错误类型/枚举/技能槽/形态/哨兵/路径、NaN、剧情态、过期引用明确延期及定义树内 Object 拒绝。

最小真实验证方案是 **root 当前已导入的完整工程作为只读来源 + 本次全新私有 profile**。不复制整套资源、不调用 editor import、不启动主场景或模拟树。工程须保留当前真实 Autoload（Art/Campaign/Settings/Sfx/Music/Screen 等）与 Unit 依赖的全局类和资源导入缓存；不能用没有这些依赖的空项目冒充实际 Unit 编译。

`run_qa.py` 默认只核对冻结源，`--run` 才启动单个真实非 console headless exe；由 root 运行。它复用公共 source/project/user/environment guards 的已读字节、相同实际 Popen 退出保护和 `.godot/redraw_rejection_source.lock` 共同独占，不按 PID/名字杀进程。只为本次建立 `runs/<UTC>/private_profile`，APPDATA/LOCALAPPDATA/TEMP/TMP 全部隔离，显式关闭自动更新和已有生产 smoke 开关；检查真实玩家 settings/campaign/screen 原字节摘要前后一致。GD 的 user:// 核对发生在 Autoload 初始化之后，外部启动前的隔离仍是必要前提。

```powershell
python scratchpad/run_unit_state_adapter/run_qa.py
# root 取得独占后，只运行一次完整 QA；默认上限 120 秒：
python scratchpad/run_unit_state_adapter/run_qa.py --run --godot "<实际非 console Godot.exe>"
```

`UNIT_ADAPTER_QA_MANIFEST` 由 runner 创建，含 `run_id,private_user,report,source_sha256`。GD 前后核对六份固定运行来源；Python 另对公共完整生产目录/路径集合/所有原字节及全部 adapter pins 前后复核，保留 sources/manifest/configuration/process/report/receipt。严格拒绝 UTF-8 解码失败、Unicode parsing error、Parse Error、SCRIPT ERROR、ERROR/WARNING/FAIL、非零或未确认退出、PID/user/source/manifest 不符；关键行为序列必须全部出现，不能只凭 passed 或来源哈希检查数接受。来源/玩家状态/锁归属漂移或退出未确认时保留共同锁及日志。

原 adapter/QA 的 `pins.json` **保持冻结**。QA 仍引用原冻结 `scratchpad/run_state_value_codec/value_codec.gd`，runner 同时核对已晋级的 `scripts/run_state_value_codec.gd` 与其原字节相同（c8c4a58d…），没有为换路径改写未测代码。新 runner 用独立 `runner_contract.json` 绑定原 pins 摘要与自身源码；它没有覆写原 pins。此方案只跑一次 QA，不添加性能矩阵或完整 Battle 恢复测试。

准备阶段原记录（保留为历史）：

> 当前仅执行 prepare 静态对齐，GDScript 尚未解析或运行，不能声明 QA 通过。

所有成功接口仍返回 restore_ready=false，未实现字段赋值、完整引用/meta、地图/效果/Inventory/Battle 适配器或真实战斗续玩。尤其禁止通过 setup/order/take_damage/advance_build/recompute 重建原始状态；未来赋值层还要避开 `art_variant` setter 的重绘/信号副作用，不能照着字段表循环 set 后宣称静默恢复。

## 当前实际 QA：20260906T150602925243Z

主任务已在当前真实 checkout、全新隔离 profile、Godot 4.6.3 实际非 console headless 进程完成一次 QA。PID **39904**、exit **0**，实际退出已确认，运行约 4.14 秒。`runs/20260906T150602925243Z/receipt.json` 的 complete/source_unchanged/lock_released 均为 true；独立复核了 report、process.log、process_receipt、manifest/configuration/sources 与冻结 pins 的一致性。

报告 **77/77 PASS，0 failures**：6 份运行来源前后各 1 次，共 **12 项来源检查**；其余 **65 项**含行为、边界和负例夹具辅助断言。共有 54 个不同 label，JSON 跨语法及负例准备检查有重复，不能写成 77 个独立场景。日志只有引擎头和 `checks=77 failures=0`，无严格错误/警告匹配。

真实覆盖：默认/非默认实际 Unit 的 241 个声明值 + position/modulate 两个继承值，经真实 JSON 和原有限值 codec 转换、验证；保留路径类型、int64 序号、特殊正无穷哨兵、负计时、挥击/施法/待出口训练/变身状态；缺字段、多字段、错误类型/枚举/形态/路径/哨兵、NaN、标准驻守不支持的剧情值、定义内 Object、失效主体等拒绝；捕获不消费额外 RNG，捕获/验证不发信号且被捕获值不变，容器解码不与源别名共享。

来源清单共 2713 个生产文件，保存的 raw manifest combined SHA 为 `f12de07498b7074dd1c8fb0edf0bde9bdc5f0dfad5b95d850624b32e2a65fa20`。本次独立复核重算了该清单自身摘要，并复核六份运行关键源/原 pins/runner 字节；没有额外重读全量资产。运行前后全量源不变与玩家 settings/campaign/screen 不变由本轮 runner 原收据记录，不能把此只读复核说成第二次引擎运行。

原 report SHA-256：`a95cefeec92c3187cfaefb41faaf1ca7983d312590b1c2a97d656ce200503836`。当前结果摘要与精确归档范围分别是 `current_qa_summary.json`、`archive_whitelist.json`。归档只含草稿与本轮明确证据，不含 private_profile、玩家存档或缓存；GD/IN 以追加 `.txt` 归档，根 `.gdignore` 保留。

**范围仍未扩大**：26 个引用/身份/关系/队列字段延期，5 个绘制缓存省略；references_encoded、metadata_capture_implemented、business_definition_validated、restore_ready、battle_resume_tested 均为 false。实测对象未 setup、未进入模拟树，此次通过不证明赋值恢复、业务内容安全校验、对象关系恢复或真实续玩。
