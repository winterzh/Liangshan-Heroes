# 四类区域效果恢复切片（尚未运行）

仅 `zone_state.gd` 与 `zone_restore_smoke.gd`；没有生产修改、Godot 运行或 Git 操作。沿已验证三数组模块的事务接口，禁止用本模块结果表示完整 Battle 已恢复。

接口：`new(codec_script, battle_script, unit_script)`；`capture(battle, trusted_content_version, object_to_id)`；`validate(record, trusted_content_version, known_ids)`；`instantiate(...)` 返回真实、离树、DISABLED、信号阻断的 Battle 壳；`bind(battle, record, trusted_content_version, id_to_unit, live_tombstone)`。也可直接 bind 外层已创建的同类空壳。根持有完整事务，先恢复地图和 Unit 值/引用，再绑定这里的四数组，所有模块绑定后统一释放墓碑，最后才能入树启用。

当前源码创建键已逐处核对：

| 数组 | 精确字段 |
|---|---|
| `_chrono_zones` | `pos,r,foe,t,tick,tick_t` |
| `_orbit_zones` | `caster,foe,ability_id,r,t,tick,tick_t,dmg,slow,slow_dur` |
| `_fire_trails` | `caster,ability_id,t,drop_t,drop,dps,dot_dur,r,foe` |
| `_ice_walls` | `cells,t`；两个实际创建点均如此 |

来源为 Battle 的 `orbit_axes`/`chrono`/`fire_trail` 分支、`_do_fissure` 和 `_do_ice_wall` 相关登记位置；继续消费仅原 `_zone_pass`、`_trail_pass`、`_ice_wall_pass`。所有实际标量类型通过 codec 保留，`cells` 保序保重、元素必须 Vector2i，float/int 不互换。总效果上限 4096、总墙格贡献上限 32768；实体 ID 沿现有正整数字符串合同。`tick_t/drop_t` 可以非正，不夹取、不改为 while 追帧，也不改原消费者到期最后一跳行为。

冰墙的 map block_count 与导航必须先由 `run_map_state` 恢复。这里仅核对格子界内且现有计数至少覆盖所有墙贡献；不调用 `block_footprint`，不重新烘焙导航。计数多出的部分可能属于建筑，完整来源/导航一致性由根地图事务负责。四数组赋值前，缺少地图/墓碑、计数不足、字段或版本错误均拒绝，不留下部分数组。

## root 实跑约束

使用现有 reviewed host runner 的 `RUN_RESTORE_QA_MANIFEST`（run_id/private_user/report/source_sha256），真实私有用户目录、共同引擎锁、实际非 console PID、严格日志和全生产/玩家前后守护。入口为 `res://scratchpad/run_zone_effects_resume/zone_restore_smoke.gd`，suite `zone-effects-restore`，唯一 stdout 前缀 `[zone-effects-restore QA] `。本目录 .gdignore 不影响外部显式脚本加载。

manifest 至少覆盖新两 GD、project.godot、真实 Battle/Unit/Inventory/codec/map/map_state/scenery_state；地图适配器的既有 Height/Scenery 传递依赖沿当前 production map QA 清单复用，完整源码守护继续覆盖其余生产代码。所有 Script 在 Autoload ready 后加载；没有 Battle._ready/deploy，没有假 Unit/Battle/Map。

smoke 先用真实 pass 消耗一次 orbit 伤害、一次 trail 铺火和部分墙时间。经过真实 JSON 后，目标地图仅用 `run_map_state.restore_into` 重建，然后绑定效果；原图与新图各调用一次原 pass，共 20 组逐步比较。Unit 本地血量/状态由夹具独立提供；为了观测 chrono 是否续晕，每步清零两个观察 Unit 的旧 stun，再调用真实消费者，这不是完整 Unit 计时模拟。已有一块地火由外层夹具独立提供，四数组模块不得改它。

预期：剩余 orbit 两跳共 20 伤害；trail 在步 2/5/8/11 四次按当前位置落真实地火，第一步无提前掉落；expired/none 由原消费者移除且不伤害/掉落；重叠墙在步 3 只释去一份计数，步 6 最后一份释放，独立建筑占地仍为 1。反复调用空数组不重复释放/伤害。重叠场景是用真实计数 API 构造的权限边界，不宣称普通技能可以在已阻挡格再次施放墙。

测试过程中由原消费者新建真实 HitSpark/GroundFireFx，并检查实例数量；**保存时已存在的视觉 Node 不由本模块恢复**，其剩余时间、随机视觉字段等交给外层效果 Node 工厂。这批也不验证完整地火恢复、其他效果、RNG 隔离、完整战斗继续或画面验收。
