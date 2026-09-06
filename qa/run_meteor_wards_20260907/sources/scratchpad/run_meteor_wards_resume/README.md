# 陨石与守卫恢复切片（仅准备，未运行 Godot）

本批选择 `_meteor_zones`、`_wards` 两数组。`_bolts` 包含 bolt/bolt_line/hook_out/hook_drag 四模式、实际 BoltFx 引用、骑手和拖拽地图消费，留给独立批次；这里不把 fx=null 当成已经恢复了该系统。

`meteor_wards_state.gd` 注入真实 codec/Battle/Unit Script 与三个身份 Callable，构造器为 `new(codec, battle, unit, encode_hit, validate_hit, decode_hit)`。三个回调各接收一个 Variant：encode 接原正整数 ObjectID，返回 `{ok,value:token}`；validate 接 token，返回 `{ok}`；decode 接 token，返回 `{ok,value:新正整数ID}`。失败返回 `{ok:false,code}`。只接受目标域 entity/retired token；拒绝 scalar/source-pool token、重复 token、解码后碰撞。smoke 显式桥接现有 production `run_graph_identity` 的 `_chase_last_id` 目标域，未改任何 Unit 字段，也未编辑 identity 模块。

其他接口沿此前数组模块：`capture(battle, trusted_content_version, object_to_id)`、`validate(record, trusted_content_version, known_ids)`、`instantiate(...)`、`bind(battle, record, trusted_content_version, id_to_unit, live_tombstone)`。先 declare stable IDs → validate → 创建真实 Unit → configure 新身份图 → bind → 全图统一 release_tombstones。任何 bind 失败须丢弃整份私有事务；虽然 Battle 数组尚未赋值，身份 decoder 可能已经分配墓碑。

| 数组 | 全量实际创建字段 |
|---|---|
| `_meteor_zones` | pos,dir,remain,speed,hw,foe,caster,ability_id,impact,dps,dot_dur,hit,trail |
| `_wards` | pos,r,t,pulse,pulse_t,aura_t,mode,ally,foe,caster,ability_id,heal,dmg,atkspeed,banner_kind,slow,slow_dur,hero_reduction,troop_reduction,aura_id,col |

创建点为真实 `_do_meteor`、`_do_ward`，消费为 `_zone_pass` 的 meteor 分支与 `_ward_pass`。meteor 的 `hit` 原本是有序 `int ObjectID → true` 字典；保存为有序 identity/hit 记录，再按相同顺序恢复新 ID 键，已释放目标不会变成新单位的命中凭证。`trail=999` 的首次落火标记和所有剩余计时原样保留，不重新设定、不改为追帧循环。

`_ward_serial` 是这批必需的根事务边界：payload 额外保存源 serial，validate/instantiate 返回 `required_ward_serial`，bind 要求根 Battle 已恢复精确值，不代写或递增。当前 active aura_id 必须为唯一正整数且不超过该 serial。Unit 已获得的减伤/攻速来源池仍归 Unit 模块；只恢复 ward 会遗漏旗阵的离域宽限时间，不能据此宣布完整恢复。

## root 实跑

入口 `res://scratchpad/run_meteor_wards_resume/meteor_wards_restore_smoke.gd`；沿现有 `RUN_RESTORE_QA_MANIFEST`，suite `meteor-wards-restore`，stdout `[meteor-wards-restore QA] `。host 继续独占锁、真实非 console PID、私有 APPDATA、严格日志、完整生产/玩家前后守护。GD source_manifest 需包含新两 GD、project、Battle、Unit、Inventory、codec、game_map 和 production run_graph_identity，传递依赖由既有全源码守护覆盖。

真实 source creator 先消耗一次 meteor 冲击/起手铺火、一次 heal/attack/poison 脉冲及忠义旗 aura。实际 JSON 后，新图复用真实身份图恢复一个仍活着的已命中目标和一个 retired hit；另覆盖 none/expired 施法者。夹具独立直接供应 Unit 血量与已有来源池，不用 apply_* 重新授予它们。避战姿态、无 inventory、保持战斗冷却的真实 Unit 每步调用原 `_physics_process`，实际执行池 TTL/降档；不是复制一份计时实现。

25 组实际原 `_zone_pass`/`_ward_pass` 和 Unit 计时调用，比较效果记录、血量、来源池与新地火数量。预期旧目标不重复吃陨石，新目标仅一次；剩余地火在步 10/20；守卫继续原脉冲；强忠旗到期后降到仍存义旗，再各自 TTL 清空；空数组不重授，根恢复的 serial 使下一次真实建桩使用 6 而非复用 1–5。坏 hit/未知 ID、float serial、未知字段与未恢复根 serial 均在赋值前拒绝。

## 视觉与未覆盖边界

数组提供的描述只够定位剩余权威区域：meteor 的当前 pos/dir/speed/remain/hw；ward 的 pos/r/t/mode/banner_kind/col/aura_id。它们不能完整描述已有视觉 Node。

真实类名是 `Battle.MeteorFx`（不是 RollingMeteorFx）：外层还需保存 start_w/end_w、life、TimedFx t/dur、_roll、_embers 和 Node 状态，不能调用 _ready 重新消耗视觉 RNG。`Battle.WardFx` 还需 life、t/dur、style、lite、_ph 与 Node 状态；尤其 style 可由 ward_style 覆盖，不能只从 mode 推断。忠/义视觉偏移不应改变实际 aura 圆心。既有 GroundFireFx/FlameburstFx/BlinkShotFx 及 DOT 由对应外层工厂/数组层恢复。

本 smoke 会由原消费者新建真实视觉节点，但不验证旧视觉重建、画面、RNG 隔离、其他数组、整局继续或一般实体未来分配。没有生产修改或引擎运行；当前只有静态准备结果。
