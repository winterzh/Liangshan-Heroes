# Level3 Unit 状态转换只读审查

日期：2026-09-09。范围：当前真实 `D:/AI项目/水浒/开发工程` 的 Unit、Battle、Level3；未启动 Godot，未运行 Git，未修改工程。本记录是源码推导，不代表 native QA 通过。

## 可用于章节门禁的结论

1. `is_captive` 与 `story_outcome == "captured"` 是两条不同状态轴。Level3 的七名囚徒以 faction=2、is_captive=true 出生；扈三娘被擒后仍 faction=1、is_hero=true、is_captive=false。不可把 captured 改成囚徒字段组合。
2. resolved 节点继续留在 `Battle.units` 和 `units_root`，其原 entity_id、Level 字段和原 active 顺序应保留。真正死亡才从 `Battle.units` 删除；死亡演出节点可继续留在 units_root。
3. 章节身份应由可信 Level 记录中的固定角色与七个 prisoner 槽确定，不能按 key 相同就获得特殊状态许可。`prisoners[0]` 一直是时迁；死亡/expired 槽不能压缩。
4. classic 的 faction=[0,1]、chapter 字段拒绝门禁应保持。只有已验证的 Level3 prisoner 角色需要 faction=2。`run_unit_state.gd:290–293,932–934` 是当前对应限制。

## 转换表

| 路径 | 明确发生的变化 | 不发生的变化 / 注意 |
|---|---|---|
| 囚徒部署，Level3:264–279 | faction=2；is_captive/is_noncombat/passive=true；stance=PASSIVE；base_speed=0；atk=0；ability=""；ability_slots.clear()；art_variant="bound_"+key | 使用真实英雄 key；并未将 is_hero 改成 false；七槽原顺序保留。 |
| 营救，Level3:337–352 | 先置 prisoners_freed=true；仅 `_alive(u)` 者改 faction=0、is_captive=false、is_hero=false、base_speed=82、art_variant="" | 不清 hp、状态效果、路径、stance、passive、is_noncombat 等；死亡/失效囚徒直接跳过。 |
| 获救者收到普通命令，Unit:567–583 | `_enqueue` 接受并写 passive=false，后续按正常 move/attack/amove/garrison 指令更新状态 | rescued 不可被限定 passive=true 或 ST_IDLE；H/姿态循环也可改 stance。 |
| 扈三娘致命伤，Unit:911–914；Level3:225–226,468–470 | defeat_outcome="captured" 触发 resolve_story；Level 回调只标记 zhu_hu_captured | 不触发 died，不给死亡击杀/奖励，不转为我方，不创建尸体，不移出 active 列表。 |
| 孙立开偏门，Level3:329–336 | inside_open=true → unregister footprint → side_gate.resolve_story("retreated") → mission mark | 先释放占地才结算；不是摧毁，不删除节点，不置 main_breached，不走 on_unit_died。 |
| 正常单位死亡，Unit:979–1014；Battle:2273–2382 | hp=0；先 died.emit，Battle 从 units 删除；建筑释放占地并排队释放；人形随后置 _dying=true、_death_t=0 | died 回调早于人形 _dying 赋值；捕获应在同步栈结束的稳定点。Level 的旧引用不会自动设 null。 |

## captured 扈三娘：窄范围稳定条件

在当前真实 Level3 的正常转换与输入路径下，下列条件有源码支持：

- faction=1、is_hero=true、is_captive=false、defeat_outcome="captured"、story_outcome="captured"。
- hp>=1、!_dying、passive=true、stance=Unit.STANCE_PASSIVE、selected=false。
- `_queue`、`_path` 为空；`_state=ST_IDLE`；`_target`、`_pending_target`、`_hua_lock_target` 为 null；`_pending_done=true`；`_lunge=0`、`_cast_t=0`、`_stepped=false`、`_move_blend=0`。
- 依据：Unit.resolve_story:4435–4455、移动单位 order_stop:468–484。普通 UI 重新选取被 Battle._set_selection:10056 拒绝；普通命令被 Unit._enqueue:568 拒绝；技能被 slot_ready:2558 与 Battle._begin_cast:7106 拒绝；Level3.on_unit_resolved:468–470 没有改动这些字段。

这是 **Level3 hu 角色** 的条件，不应推广为所有章节、所有 public 方法调用后的 resolved 单位通用规范。Unit.set_stance:519 和 order_hold_position:488 自身没有 story guard，其他章节若直接使用它们需要独立审计。

不能附加：hp==1、visible=true、is_captive=true、is_noncombat=true、所有 timer/buff 为零、ability_slots 为空、is_active/inspected=false、_path_i=0、_chasing=false、_hold_prev_stance 固定值、_home==position。其中 order_stop 根本不写 _path_i、_chasing、is_active 或 inspected；resolve 直接赋 selected=false，没有调用会同步清 is_active 的 set_selected(false)。

hp=max(1,hp) 不是强制 hp=1；Unit.heal:2836 没有 story guard；已排出的命中尾部还可应用慢速、眩晕等（Unit:2074–2103；Projectile:84–95）。需保留实际有限数值，不能清理成理想化状态。

## retreated 偏门：不得套用人形停止状态

`Unit.order_stop:469–470` 遇 is_building 立即 return。因此偏门只确定具有 resolve_story 的显式结果：story_outcome=retreated、hp>=1、passive=true、stance=PASSIVE、selected=false、visible=false、pending_target=null、pending_done=true、lunge/cast_t=0、stepped=false、move_blend=0。

不能据此要求其 `_queue`、`_path`、`_state`、`_target`、`_hua_lock_target`、mission_order_* 等等同于人形清理结果。即使部署模板里这些恰好为空，也应区分“已验证固定模板初值”与“resolve 保证”。

Level3 开门路径可要求 `inside_open=true` 的实际偏门为 retreated，且 `footprint_blocked=false`。原 fcell/fhalf 仍保留；Map 的 block count 由 unregister 减一（Battle:849–865）。不要把该区域全部 block_count 强制写零：其他建筑/障碍/墙仍可叠加阻挡。强攻摧毁偏门走另一条路径，不产生 inside_open=true；不应让“偏门已失效”与 inside_open 等价。

## 囚徒 / 获救者不能强加的条件

- `prisoners_freed=true` 不等于七槽都 faction=0/!is_captive。营救循环跳过已死亡者；部分非时迁囚徒先死后救援是 Level 支持的路径，死亡槽可仍 faction=2/is_captive=true/is_hero=true。只对仍 `_alive` 的实体要求营救后的组合。
- `is_captive=true` 不等于 hp>0 或 !_dying。take_damage 没有 captive 拒绝；Level3:479–504 明确处理囚徒死亡。Unit._phys_body:1131 的 captive 早退又在 _dying:1163 之前，因此已死被囚人的 death timer 可停止，节点可以长期留在 root 而不在 active 列表。不能用“超过死亡动画时长必须消失”纠正存档。
- 被囚人的出生 position 不是永久不变量：Battle._grid_build 与 _separation_pass:5697 的过滤没有 is_captive，正常群体软分离可移动其位置。
- 获救者可被选择并下 move、patrol、hold、stance、garrison 指令，不能要求其 queue/path/target/selection/garrisoned 始终为空。Unit._begin_garrison:791–803 没有 noncombat 排除，Battle._order_garrison_at:6254–6263 使用正常 movers；进入后设置 passengers/holder、隐藏并置 idle（Unit:828–846）。
- 获救者 hp/max_hp 不能等于部署值：受伤、治疗、驻军回血，且 Battle.on_research_done:2157–2167 会把现役 faction=0 非英雄的 hp/max_hp 按科技倍率更新。
- visible 不是身份条件：Battle._fog_pass:4271–4280、_grid_build:5570–5575 按雾和屏幕裁剪改写。retreated 仍受明确隐藏约束；captured 可以显示也可以隐藏。

## 全图引用审计的真实边界

`Battle._on_unit_story_resolved:17156–17176` 同步清 selection、ability/item caster；删除以该单位为 caster 的 pending cast、pending item、walk cast、walk item、channel；遍历当前 units 清匹配的 current target / pending_target / hua lock；最后调 Level.on_unit_resolved。

但它 **不** 删除或改写以下对象：

- resolved Unit 自身在 units / units_root / Level role 中的条目。
- 其他单位排队攻击中的 target；只有当前 `_target==unit` 时才对整个移动单位 order_stop。
- 建筑当前 `_target`：即使匹配，order_stop 因 building 直接返回；下一次 `_tower_tick:1887–1890` 才通常清理，因此保存屏障可观察到旧引用。
- `_taunt_src`、`_lin_spear_target_id`、`_chase_last_id`、`_giveup_id` 等状态引用，以及已生成的 projectile/effect/dot/duel 目标。`_lin_duel_pass:9734–9737` 只检查有效性和 hp，captured 的 hp>=1 可让 duel 记录留到正常超时。
- 以 resolved 单位为 **目标** 而非 caster 的 pending cast / walk cast 等记录；不能与 caster 清理混淆。
- inspection、groups、其他 UI 或效果保存的引用。

因此独立 `audit_chapter_graph` 应验证合法身份、引用能解析、active/root 集合关系及已声明的清理条件，不能笼统拒绝全图任何引用指向 resolved 实体，也不能清除这些记录后继续宣称精确恢复。

## 冻结 timer / pose 附记

Unit._phys_body:1125–1132 在 captive/story 早退之前只推进 story pose。其余既有 cd、hitflash、stun、taunt、shield、channel、buff、move 等字段可冻结在非零值；Battle 自己仍可按 pass 改 aura、fog、modulate 等。`play_story_pose:4464–4468` 保存 previous variant；到期 `_story_pose_t` 可小于零且 `_pose_previous_variant` 没有被清空，不能以“pose已结束必须全部空/零”作为跨章节规范。当前 Level3 本身未调用 play_story_pose，允许该字段应另有确切来源。

## 本次回读 SHA-256

- scripts/unit.gd: `56e8458e4dbea7e4737fe2b857bac80c282165098c3ebbe69fa83cda90379309`
- scripts/battle.gd: `5e6cdbdd081c119f70d003c453dd75d872eddb197313fb16f46b07c631611326`
- scripts/levels/level3_zhujiazhuang_rts.gd: `7fe40d07350110d2c3f07815fd40819dbe848a8e59b90093955d6a50bf77d248`
- scripts/run_unit_state.gd: `976130a3da822907d6d29778b61f71d77009c043c06d06616cf7f237409280f7`
