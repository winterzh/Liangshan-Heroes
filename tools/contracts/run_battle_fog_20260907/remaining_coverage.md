# 标准 30 波剩余恢复覆盖（有界字段核对）

2026-09-07。正式依据是 docs/POLISH_ROADMAP_20260906.md 的 M3 验收与保存/恢复条款，以及 RUN_SAVE_FOUNDATION、RUN_STATE_VALUES、RUN_UNIT_VALUES 三份基础说明；它们没有宣称完整 schema。详细候选字段来自既存 scratchpad/defense_resume_schema.md，本次按当前方法/实际字段核对重点；不是又一份已验完整 schema。

当前 Unit 值草稿覆盖 241 个声明值和 position/modulate；refs 运输层覆盖 14 个直接引用、两个有序引用数组和 `_queue`，合计覆盖 258/272 声明字段。refs 的默认值修订/实际结果由根任务另案处理，本清单不改它或重新认定通过。Inventory 已实测五个局部值，但未赋值恢复、连接 owner、验证业务定义/全局 UID。现有来源与内容标签均不能替代有效整局内容指纹。

本轮选 Battle 迷雾五值+实际地图维度，原因是它直接影响可见与锁定，且完全不需要 Unit registry。`fog_values.gd` 只补运输/严格验证草稿，尚待引擎；下列其余项目仍是主路径阻塞。

| 区块 | 仍须明确保存/验证/恢复的实际字段或对象 | 必须保留的语义 |
|---|---|---|
| 身份/有序对象 | 未来 run_id、next_entity_id、next_item_uid、next_effect_id；Battle.units:73 的原序、units_root 中活体和尚未释放尸体的顺序、fx_root 权威效果的顺序 | ID 永不复用；活跃列表不含尸体不表示尸体可丢弃。需同拍伤害/归因顺序，不能仅按当前数组下标登记 |
| Unit 剩余身份与来源 | `_lin_spear_target_id,_chase_last_id,_giveup_id,_charge_hit,_damage_reduction_sources,_aura_atkspeed_sources`；以及 `battle,map,inventory` 三关系 | 已命中 tombstone 即使实体释放仍保留；默认/旗阵/环绕/林冲护卫/决斗的混合整数源键要转显式 kind+entity/effect 身份，不能全当 Unit 指针 |
| Unit meta 与图 | fcell、fhalf、footprint_blocked、resource_footprint、production_berth、liangshan_gate_id、scene_visual_only、final_cleanup_pos/stall；忠义堂 campaign_environment_* 白名单；hall、矿工/排队、驻军双向关系 | 现有 refs 只是 none/entity/expired 运输，未完成引用有效性/容量/矿位/注销/过期消费政策。实际恢复不能把 expired 一律变 null；尸体不重新发 died/on_death |
| 玩法时钟 | `_ai_tick_frame:43,_sep_phase:86,_stealth_acc:133,_ecast_acc:134,_eco_t:44,_res_block_frame:80,_eco_lane_cache_bucket:49`、本局 physics tick/process 顺序、Settings.game_speed | Battle._physics_process:2316 在 grid/分离/迷雾/效果/level 之间有固定顺序；本局时钟需替代引擎累计帧的玩法用途。退出墙钟不扣 CD/波次 |
| RNG 与 ObjectID 玩法用途 | Unit 1176–1177 醉态、1930/1937 未命中/闪避、1970 暴击、2012/2018 触发；Battle 6488 物品 proc；Crowd solve 的 ObjectID 配对，Battle._separation_pass:5413、末波回填、训练择序；Inventory._new_uid:46 | 当前玩法和视觉共用全局 randf/randi；Projectile.setup:38/43/47、Unit._dust:3258 和大量 FX ready 也消费全局 RNG。需要可持久玩法 RNG state 和视觉隔离/等价验证，记录 seed 不足以恢复当前位置；当前没有这样的已接通 RNG 模块 |
| 运行模式/有效内容 | Campaign skirmish/arena/custom_defense/scenario、defense_waves/hero_cap/random、ai_friendly/scale_on；Settings auto_micro_level/formation_mode/game_speed；Battle `_defs/_abilities/_items` 与直接使用的 Defs 表、固定 WAVES/地图规则 | 首合同标准 skirmish、30 波、非随机、hero_cap=4、scale_off、ai_friendly=false、FIGHT。其余模式暂拒；有效内容指纹未构建。加载失败须还原全局菜单上下文，不能改章节成绩 |
| Battle 经济/科技 | gold、wood、pop_cap、current_age、_tech_done、tech_atk/hp、hero_tech_atk/hp、tech_gather；faction_res/faction_gather_mult 及 `_eco_last_wood,_eco_wood_stall,_eco_trap_cd,_eco_trap_lane` | 基础年龄来自 LevelBase.start_age()=3；不按 Battle 初值1重建，不重扣训练费，不重复累加人口。首标准禁用的敌经营私池仍需显式断言边界 |
| 战功/死亡复活 | kills、hero_kills、hero_combat_stats、hero_progress、hero_item_progress，Battle:143–151 | 复活账本独立继续库存 CD（2319–2322）；尚存尸体的库存可能是退休镜像，同 UID 不能按两份活跃库存处理，也不能全部判冲突 |
| 行为缓存 | `_blocker_cache,_blocker_cache_revision,_blocker_query_budget`（81–83），`_eco_lane_cache/_eco_lane_cache_bucket`（49–50） | 命中堵路缓存不耗本帧8次新查询预算；分路缓存保留旧周期结果（3742）。清空/提前重算会改变行为。`_res_block_cache` 及空间网格可重建需对齐恢复首帧边界，不能用旧 Engine frame |
| 地图/导航 | GameMap.w/h/theme/base_fill/grid:47–52；_base_solid/_block_count/_navigation_revision:60–62；五套 AStar；标准地图 four meta；建筑、资源树、持续墙足迹 | 保存 grid（PackedInt32）与导航版本，五套导航按冻结规则重建，足迹只登记一次，再比对计数。不能 nearest_open 搬人或调用 advance_build 封地。_block_count 不是可与再次登记叠加的第二份权威 |
| 迷雾之外 | Battle.lit_cells:152；Unit.fog_visible 及实际 visible；Image/ImageTexture/FogLayer | 本轮五值不覆盖高亮倒计时或跨 Unit 可见性一致。纯资源可重建；禁止调用 _fog_pass 扣侦察时间来“初始化” |
| 标准关卡 | skirmish:93–103 `hall,_wave,_wave_t,_wave_spawned,_started,_final_cleanup_last_alive,_final_cleanup_last_hp,_final_cleanup_positions,_final_cleanup_quiet,_final_cleanup_tick,_final_cleanup_active`；_wavelist_cache:182 | `_final_cleanup_positions` 键当前为 ObjectID（386），须稳定 ID；首/末波倒计时、重叠波和8秒清理进展必须保留。不能重跑 on_start:320（重设120秒、清全部末波状态） |
| 视图/未提交交互 | selection、_active、_inspect_unit、_groups、_camera_locs、camera.position/zoom；_autocam_*:27–34 | 已提交 orders/walk/pending 全保留；拖框、armed、按下时间等未提交手势有明确清除合同。视图可便利恢复，但不能驱动科技/属性/伤害重算 |

以下效果全在 Battle，数组顺序、已解析 effect/ability 数据、剩余寿命、子周期、归因与历史命中均需显式合同；“完整 Unit 值”不会自动覆盖它们：

| 容器/类 | 还需的明确字段（当前构造/消费方法为准） |
|---|---|
| `_ground_dots` | pos,r,foe,caster,follow,attack_slow,attack_miss,ability_id,t,tick_t,tick,per |
| `_hua_snipe_dots` / `_lin_duels` | target,caster,ability_id,t,tick_t,tick,pct,ticks_left / caster,target,t,heal_pct |
| `_chrono_zones` / `_orbit_zones` | pos,r,foe,t,tick,tick_t / caster,foe,ability_id,r,t,tick,tick_t,dmg,slow,slow_dur |
| `_meteor_zones` / `_gong_lines` | pos,dir,remain,speed,hw,foe,caster,ability_id,impact,dps,dot_dur,hit,trail / kind,origin,dir,length,traveled,speed,half_width,foe,caster,ability_id,dmg,push,slow,slow_dur,hit |
| `_ice_walls` / `_wards` | cells,t / pos,r,t,pulse,pulse_t,aura_t,mode,ally,foe,caster,ability_id,heal,dmg,atkspeed,banner_kind,slow,slow_dur,hero_reduction,troop_reduction,aura_id,col；另 `_ward_serial:203` |
| `_fire_trails` | caster,ability_id,t,drop_t,drop,dps,dot_dur,r,foe |
| `_bolts` | mode,pos,tgt 或 dir,traveled,len,width,speed,eff,sc,rank,caster；hook_drag 追加 victim；fx 指针须替换纯显示描述 |
| `_walk_casts` / `_walk_item_casts` | c,slot 或 uid,tgt,point,serial,t,age；point 的合法 INF 哨兵单独处理 |
| `_channels` | caster,center,eff,sc,rank,r,tick,tick_t,ad；与 Unit._channel_t/_channel_dur 配套 |
| `_pending_casts` / `_pending_item_casts` | caster,slot,lp,tgt,serial / caster,slot,uid,point,target,serial；不能清空或重新发招 |
| `_traps` | key,pos,trigger_r,arm_t,effect,owner；owner 是阵营 int；不要调用扣费布置 |
| 独立 Projectile | target,shooter,dmg,crit,damage_ability_id,speed,_dir,_life,kind,splash,on_slow_mult,on_slow_dur,_dist0,_spin 与 position（projectile:5–19）；不调用 setup 重新算初距/方向/随机 |
| LiBrawnAxesFx | caster,game 运行绑定、hits[{target,dmg}]、dur,elapsed,resolved、position 及 tex 来源描述（battle:14983–15020）；elapsed 由 _process 推进，不能只冻结 physics 或把恢复后的每斧再结算一次 |

上述持续效果还缺 visual_kind/content_key/方向范围/原总寿命等最小显示描述，需从各创建点补足，不保存完整 Node/Resource、不重放技能来建图。命中集合、来源池、排队失效目标依赖不同的 tombstone/none/expired 政策，不能用一个统一“清理引用”代替。

最后还必须把既有磁盘 store/R01/value codec 与显式图 validator 接通，拆 Battle._ready、Unit.setup/spawn、Skirmish.on_start 的新局副作用；在完整 physics+process 回调与 deferred 删除边界暂停采集，先完整验证、建壳、赋值、连图、登记导航、纯建显示、最后恢复玩法 RNG，成功才提交场景，失败回滚上下文且保存不退出。需要不同 PID 继续实际付费生产、携货/排矿/驻军/尸体复活、抬手/箭弹/飞斧/DOT/墙/旗/末波行动的证据，基础层断言不能替代。

旧详细草稿中的 Inventory“0.5秒周期/0.49秒夹具”文字已与当前 `hero_inventory.gd:220–230` 的 0.25 秒取模周期不符；本次已测 Inventory 用 0.24975。旧文件是冻结历史来源索引，不能直接把这两处陈旧数值带入新实现，也不能改旧文件造成旧 pin 漂移。
