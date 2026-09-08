# UnitState 的祝家庄章节适配：未应用草稿

本批只写 `D:/CodexTemp/level3_world_prepare_20260909/unit_state_draft/`。未修改仓库、未运行 Godot/Git，没有整合 Core/Battle/Unit。根任务正在独占引擎。本草稿应在经典回归结束后独立串行审查/原生验证；不计为已实现或八关验收。

## 文件与范围

- `run_unit_state_level3.patch`：只修改 `scripts/run_unit_state.gd` 的统一 diff。
- `draft/scripts/run_unit_state.gd`：应用该 diff 后的完整候选源，方便逐行查看。
- `chapter_helpers.gdinc`：新增校验函数的源片段，由生成器插入。
- `generate_patch.py`：只读当前源码，匹配唯一锚点，生成工程外候选/diff/来源 hash。不是 GDScript 测试工具。
- `transition_review.md`：独立静态核对 Unit/Level3/Battle 的真实状态转移。
- `source_manifest.json`：7 份相关源码及候选、diff SHA-256。

没有增加 Unit 的 273 个生产字段，也没有调用 setup/spawn/order/resolve_story/recompute/部署/发奖。现 242 个直接值、引用、metadata、节点、背包通道继续复用。新增 schema 只代表特定章节的校验语义。

## 可信上下文与角色接口

原三参数 `UnitState.new(Codec, Unit, Inventory)` 仍得到 classic 契约；原 `defense_unit_state_v2`、faction 0/1、章节标记拒绝原样保留。新构造参数仅由可信外层提供：

```gdscript
UnitState.new(Codec, Unit, Inventory,
    {"mode": "campaign", "level_id": "level3", "waves": 0},
    {"hu": hu_id, "gate": gate_id_or_null,
     "side_gate": side_gate_id_or_null,
     "prisoners": [shi_qian_id_or_null, shi_xiu_id_or_null, qin_ming_id_or_null,
                   yang_lin_id_or_null, huang_xin_id_or_null,
                   wang_ying_id_or_null, deng_fei_id_or_null]})
```

IDs 是现有十进制稳定实体 ID 字符串；禁止对象、显示名、node path。非零/未知 waves、额外 context 字段、其他官方关卡、空/未知 mode 全部拒绝。0.0/30.0 仅规范化为对应明确上下文。Level3 还要求注入的 Unit Script 等于当前安装的固定 `unit.gd`；不能以任意同字段脚本获得章节许可。新 schema 为 `level3_unit_state_v1`，classic 默认 decoder 不接受它，Level3 decoder 也不接受 classic schema。

**roles 不是存档直接可选的权限表。** 捕获时从已核验 exact Level3 的 `hu/gate/side_gate/prisoners` 实例与同一 object→ID registry 生成；恢复时先用已安装 CampaignLevelState.validate 校验 Level 记录及其固定 7 槽，再从校验输出生成 roles。不得从文件新增 role/key 字段自报身份。UnitState 要求角色 ID 唯一、全部属于完整 known_ids，并将每个角色与固定 key 绑定。关卡引用的 null 与普通 graph 的 expired token 含义不同，外层负责按当前 LevelState 既有规则处理。

此草稿未修改 UnitGraph 的工厂构造处。未来需由官方 profile 把这两个额外参数传入 graph 内部 factory，同时为全图规定匹配 schema；不能仅在 Core 的一个 `_unit_checker` 上设置参数而让 UnitGraph 仍生成 classic factory。以上依赖未接入，因此草稿没有实际开放任何存档路径。

## 明确允许的状态

| 状态 | 局部不变量 | 允许保留的差异 |
| --- | --- | --- |
| 普通 Level3 单位 | faction 0/1，非captive，defeat/story均空；无 Level3 未使用的 story pose/assistance | 原通用战斗/经济/死亡状态照旧保存。不能把其他角色的章节标记挂到同名普通单位。 |
| 未捕获扈三娘 | 必须是 Level.hu 的实体，key=hu_sanniang，hero=true、faction1，非建筑/资源/captive，defeat=captured，story空，hp>0，非dying | hp 可为 0.5，不能错设 hp≥1；普通战斗中的队列、路径、技能、目标继续保存。 |
| 已捕获扈三娘 | 同一实体和阵营，story=captured，hp≥1、非dying/驻军、passive=true、stance3、未selected；resolve 的待命/待伤害字段一致 | 不是 is_captive，不转我方；hp不必等于1；可被雾/屏外隐藏；保留buff、timer、AI/cache、inspected，不能清全部引用或强制 visible=true。 |
| 未救囚徒 | 仅固定7角色，key逐槽匹配，faction2、is_hero/is_captive/noncombat/passive=true、stance3、speed0、atk0、空ability/slots、bound_key外观；defeat/story空 | 不固定世界位置（软分离可能推动）；不要求一律存活。hp≤0且dying的非关键囚徒可以仍为root child，但必须已不在active名单。 |
| 获救囚徒 | 同一角色，faction0、非captive、非hero、仍noncombat，defeat/story空；speed82、atk0、空ability/slots/variant | 可以接令、passive=false、改姿态、移动/攻击/驻军/取消选择；不强制无路径/无目标/可见。不以出生英雄模板重算，基础约束不符就拒绝，不替用户修值。 |
| 现存正门 | gate角色、key=zhu_gate、faction1、建筑、非资源/captive、hp>0、非dying、defeat/story空；fcell(20,28)/fhalf1/footprint_blocked=true | 正常受损时的视觉和状态照旧保存。已毁正门经排空删除后应为null，不重建。 |
| 现存偏门未开 | side_gate角色，基础同正门；fcell(20,18)、fhalf1、占地true、story空 | 基础通用字段继续保存。 |
| 已开偏门 | 同一仍存在的side_gate Unit，story=retreated、hp≥1、非dying/驻军、passive/stance3、未selected，node.visible=false，footprint_blocked=false | 仍在 Battle.units。**order_stop 对建筑直接返回**，所以不要求建筑的queue/path/state/target清空；绝不能再注册占地或重建成普通关闭城门。 |

Level3 未调用 play_story_pose 或设置 story_assist_partner/owner，因此对应timer、旧variant、metadata、引用仍明确拒绝；不能因其他八关有这些功能而自动放开。掩码只允许 captured/retreated 的实际角色组合，不接受 unconscious/subdued/embarked 等其他关状态。

## 清理和目标的不变量

`resolve_story` 显式设置 story_outcome、hp=max(1,hp)、pending_target=null、pending_done=true、lunge/cast/move_blend=0、stepped=false、passive/stance、selected=false；retreated/embarked还隐藏。captured 人形执行 order_stop 后队列/路径、当前target、Hua锁定、巡逻、hold/mission意图清理；`_path_i` 和 `_chasing_path_blocker` 没有被该函数重设，不应强制0/false。

Battle._on_unit_story_resolved 不移除 units、不发 died、不增加击杀。它清除当前选择/施法者、本人 pending/walk casts/channels，并对当前 target/pending_target/Hua锁定做清理。**不能要求全世界再无指向 resolved 实体的引用**：建筑 order_stop 不清 target；其他单位的排队 attack、taunt、已发射弹体、持续技能与本步缓存仍可能合法保留对象，实际消费者自行拒绝对已解决对象再伤害。外层应保持这些引用和延迟时间，而不是在读档时扫除。

新 `validate_level3_membership(validated_states, active_ids)` 是对每条 `validate()` 输出的额外图义务：每个角色的存活/死亡状态必须与 active membership 一致，捕获扈三娘/撤退偏门仍属于 active，dead prisoner不能重新入队。它不替代 UnitGraph 原有 root_order/active_order/next_id/身份检查，也不能把任意拼装字典当作 validate 输出。必须在分配/激活前执行并将失败传播到整个世界事务。

顺带发现的现有行为问题需独立排期核实：`Unit._phys_body:1131` 先因 is_captive 返回，dying 衰减/queue_free 在1163之后。因此仍为 captive 的死亡角色不会执行普通死亡淡出；此处是源码可达路径判断，尚未原生复现。本补丁保存该实际残留状态，不借序列化重置/清除尸体来隐藏生产问题。未来修复 Unit 死亡顺序应单独验证后更新角色/消亡用例。

以下属于外层交叉校验，未在单 Unit 补丁里冒充实现：Level引用与角色表完全相等；root selection无resolved；Caster和cast/channel的清理符合组件规则；inside_open与side_gate.story_outcome/mission event相符；只有仍alive的囚徒才要求随 prisoners_freed 转阵营（提前死掉的其他囚徒被释放循环跳过）；Map._block_count必须与所有活跃占地贡献一致。开偏门后的区域可能又被其他建筑/效果阻塞，不能粗暴断言整块3×3的总block_count始终为0。

## 待原生验证的最小矩阵

原classic正常记录仍往返；classic拒绝faction2及所有章节标记；未知context/其他关卡/空roles/重复role ID/角色不在graph/错key/错schema都拒绝。Level3覆盖：初始七囚徒；扈三娘hp0.5未捕获；被擒后雾中隐藏、非零遗留buff；获救者移动且passive=false；获救者驻军；非关键囚徒先死后完成营救；偏门retreated仍active且不占地；正门已毁null；捕获时在途投射物与塔旧target；反例为偏门visible=true、重新阻塞、captured仍pending伤害或人形移动意图、陌生角色偷带captured。每项都应验证失败不创建/激活对象、不改原战斗/槽。

当前只完成静态来源核对、唯一替换锚点和字段存在性检查。没有原生 parse、行为测试、完整 UnitGraph/世界接入或真实玩家验证。
