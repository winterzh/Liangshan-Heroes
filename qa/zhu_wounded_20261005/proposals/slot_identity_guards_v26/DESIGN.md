# Slot 外层身份类型 guard v26（未 apply、未执行）

当前 public `scripts/run_slot_store.gd` SHA-256 为 `d67fe7794f23fe1bda3d74c7e284ba6b90d2cb488a5d35cb1a187eea77fa3532`，r2 正在固定它。本目录只保存外部源方案，public、r2/q1、旧批次和收据均未修改。候选 SHA-256：`908f8591f012752b192278362b48a83f212a7e596727214b5b0734dce23bdbde`。

## 精确源风险位置

| public 原行 | 原操作 | 缺少的前置条件 |
| --- | --- | --- |
| 29 / 32 | slot.schema 与两个固定 String 比较及 campaign 分支 | schema 必须 TYPE_STRING |
| 37 | classic context.mode、level_id 与 String 比较 | mode / level_id 必须 TYPE_STRING；waves 沿用 INT/FLOAT |
| 39 | binding.get(kind) 与 uncredited 比较以选择 validator | 此时尚无 validator 证明，kind 必须 String；缺 key 保留 STEAM_BINDING_FIELDS |
| 67 / 73 | campaign / classic world.schema String 比较 | world.schema 必须 String |
| 69 | profile.schema String 比较、String(profile.id)、typed Profiles selector | schema / id 必须 String；删除 ID coercion |
| 76–79 | Profiles.normalize_context 与随后 profile.id 比较 | Slot 先严格 profile.context 三字段容器和 primitive；id 已严格 String |
| 99 / 106 | JSON schema fixed String membership、Profiles context入口 | typeof(schema) 先于 membership；context 先有严格字段/类型；fallback 沿原 model |

上表是逐行确认的“malformed 叶能够到达比较/构造/typed call”的 source 风险，不是已运行的 SCRIPT ERROR 复现。Profiles.normalize_context 原 `67–69` 已有 Variant、三字段和 String/INT/FLOAT 保护，故未发现 Profiles 内此入口的未控 context 访问，未修改 Profiles。LocalLifecycle `23–26` 与 LocalRun `20–25` 的 binding validator 在 Slot 分类之后才调用，不能为原 `39` 预先提供可靠 String 证明。

## 候选范围和拒绝合同

仅修改 `_validate_document` 与 `_validate_json_document`。204 原始 raw lines 保留 202 行 byte-identical；两个替换为 profile.id 去 String coercion、JSON schema typeof 短路。其余新增是比较前 guard。原 field/key 数量、schema/profile 清单、generation、options/settings/root_node、bindings 后续原验证、numeric 规则、scenery JSON 窄边界、source validator、canonical/hash 链和 writer 所有函数保持原字节。

- slot schema 非 String → SLOT_SCHEMA；slot context 不满足原三字段或 mode/id String、waves INT/FLOAT → SLOT_CONTEXT。
- profile schema / id 非 String，或 profile.context 不是原三字段 / primitive types → SLOT_WORLD_PROFILE。
- 两分支 world.schema 非 String → SLOT_WORLD_IDENTITY。
- binding Dictionary 缺 kind → 原 STEAM_BINDING_FIELDS；存在 kind 且非 String → 新 SLOT_BINDING_TYPE；正确类型未知 String 保留原 routing/errors。非 Dictionary binding 继续原 LocalRun controlled field refusal。
- JSON schema malformed / 未知 schema 继续调原 `_validate_document` fallback，保留 `FaultSlot` 无 schema、generation/value 两字段自定义 model；没有 model opt-in/宽泛迁移。
- INT/FLOAT 波次仍同时接受原合法 0 / 30；未升 INT-only。原 normalized int(waves) 与 source/schema 字符串处理保持原机制；canonical `_decode` 的 byte equality 仍可能拒绝非 canonical 0.0/30.0 payload，这是原合同。
- 不检查新增字段，不放宽 profile wrapper 原允许形状，不扩展 mission/presentation token、深层 Codec/其他组件或任意 saved script/path；不增加转换器。

## 必需 native 验证矩阵（均待执行）

`NATIVE_MATRIX.json` 固定真实 v24p pending original/normalized payload path、SHA 和 UTF8 bytes，仅引用原文件，不覆盖或拷贝玩家 slot。原 pending schema=official_continue_slot_v1，context=campaign/level8/0，profile=campaign_level8_v1，binding=uncredited 三字段。

共 134 个单叶负例，源与 JSON 两 route 共 268 拒绝检查：9 个身份 String 叶分别换 Nil/Bool/Int/Float/Array/Dictionary；6 个外层容器换 Nil/Bool/Int/Float/String/Array；两 waves 叶换非数值及错误整数/分数；正确类型空/未知 String 保留原语义拒绝；12 个 key removal。每例仅替换/移除一个 leaf，返回 Dictionary + ok=false + 精确原/指定 code，输入 typeof-aware 全深度未变，无 SCRIPT ERROR/Parse Error/ERROR，保留每例报告和原 native log。

JSON base 独立 Godot parse 原 pending 文本；native source base 从同一真实 pending 独立 parse 后，仅沿已有已固定 SceneryJSON normalize_json 修复指定 ownership integer fields，必须原完整 Scenery validate 通过，之后才做单叶变异。不能向 typed helper 传已损坏的 context/content 作为所谓 trusted 参数，也不能泛修整个 DTO。

正例包括原 pending JSON 和对应 native source document validation、波次 TYPE_FLOAT0.0 保留原 document rule、原 76+ OwnedSlot FaultSlot 完整 suite、原 canonical/hash encode/decode；这些都待 native 证实，历史失败 pending 不能被标成成功 save。Classic 两分支还必须使用新的实际 current native classic 完整 slot 或已合格 current fixture，做相同上下文/schema/binding 叶矩阵和完整正例；历史 Scenery-only component 不能冒充 current whole-slot，也不能把 campaign pending 换几个标签当实际 classic 正例。

没有引擎运行、GDScript parse、public apply 或 producer 改动；不宣称 native pass、任意 DTO 全叶零 SCRIPT ERROR、完整继续游戏或发行资格。
