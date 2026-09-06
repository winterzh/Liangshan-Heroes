# Unit 272 字段处理表

当前 Unit LF SHA `f4382456b8c619cbb86c40cd8a9ed6ea9f171ba0a8a90c191538f689176d49ee`；运行时使用显式字段，下面的扫描仅在离线 prepare 中核对覆盖。

241 个声明值字段 + position/modulate；26 个待引用/关系层；5 个纯绘制缓存。完整恢复未实现。

| Field | Current source line | Handling | Type / range |
| --- | --- | --- | --- |
| `defeat_outcome` | 20 | captured_value | string / Exact String; aggregate codec byte budget |
| `story_outcome` | 21 | captured_value | string / Exact String; aggregate codec byte budget |
| `movement_profile` | 22 | captured_value | string / Exact String; aggregate codec byte budget |
| `art_variant` | 23 | captured_value | string / Exact String; aggregate codec byte budget |
| `animation_direction` | 29 | captured_value | string / Exact String; aggregate codec byte budget |
| `_direction_candidate` | 30 | captured_value | string / Exact String; aggregate codec byte budget |
| `_direction_votes` | 31 | captured_value | int / Exact signed int64 |
| `_story_pose_t` | 32 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_pose_previous_variant` | 33 | captured_value | string / Exact String; aggregate codec byte budget |
| `story_assist_partner` | 34 | reference_next_layer | — / none/entity/expired; ordered arrays retain order; never encode Node/ObjectID |
| `story_assist_owner` | 35 | reference_next_layer | — / none/entity/expired; ordered arrays retain order; never encode Node/ObjectID |
| `key` | 37 | captured_value | string / Exact String; aggregate codec byte budget |
| `display_name` | 38 | captured_value | string / Exact String; aggregate codec byte budget |
| `faction` | 39 | captured_value | int / [0, 1] |
| `max_hp` | 40 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `hp` | 41 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `atk` | 42 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `atk_cd` | 43 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `atk_range` | 44 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `base_speed` | 45 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `is_ranged` | 46 | captured_value | bool / Exact bool; no numeric coercion |
| `can_melee_switch` | 47 | captured_value | bool / Exact bool; no numeric coercion |
| `melee_mode` | 48 | captured_value | bool / Exact bool; no numeric coercion |
| `is_cavalry` | 49 | captured_value | bool / Exact bool; no numeric coercion |
| `bonus_vs_cav` | 50 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `defense` | 51 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `is_hero` | 52 | captured_value | bool / Exact bool; no numeric coercion |
| `is_building` | 53 | captured_value | bool / Exact bool; no numeric coercion |
| `is_captive` | 54 | captured_value | bool / Exact bool; no numeric coercion |
| `is_objective` | 55 | captured_value | bool / Exact bool; no numeric coercion |
| `is_noncombat` | 56 | captured_value | bool / Exact bool; no numeric coercion |
| `setup_def` | 57 | captured_value | definition_values / String-keyed Dictionary <=512 top keys; full value tree budgeted, business schema deferred |
| `aura` | 58 | captured_value | string / Exact String; aggregate codec byte budget |
| `aura_radius` | 59 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `aura_power` | 60 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `radius` | 61 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `visual_scale` | 62 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `aggro_range` | 63 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `battle` | 65 | runtime_relation_next_layer | — / bind new Battle/Map or dedicated HeroInventory adapter; no Resource/Node encoding |
| `map` | 66 | runtime_relation_next_layer | — / bind new Battle/Map or dedicated HeroInventory adapter; no Resource/Node encoding |
| `_track_combat_stats` | 67 | captured_value | bool / Exact bool; no numeric coercion |
| `is_worker` | 70 | captured_value | bool / Exact bool; no numeric coercion |
| `is_resource` | 71 | captured_value | bool / Exact bool; no numeric coercion |
| `res_kind` | 72 | captured_value | string / Exact String; aggregate codec byte budget |
| `res_left` | 73 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_gold_miner` | 74 | reference_next_layer | — / none/entity/expired; ordered arrays retain order; never encode Node/ObjectID |
| `_gold_waiters` | 75 | reference_next_layer | — / none/entity/expired; ordered arrays retain order; never encode Node/ObjectID |
| `_queue` | 76 | order_queue_next_layer | — / ordered move/amove/attack/gather/build/repair/garrison shapes; targets need reference protocol |
| `_gather_node` | 77 | reference_next_layer | — / none/entity/expired; ordered arrays retain order; never encode Node/ObjectID |
| `_drop` | 78 | reference_next_layer | — / none/entity/expired; ordered arrays retain order; never encode Node/ObjectID |
| `_carry_kind` | 79 | captured_value | string / Exact String; aggregate codec byte budget |
| `_carry_amt` | 80 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_gather_t` | 81 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `is_constructing` | 86 | captured_value | bool / Exact bool; no numeric coercion |
| `_pending_build` | 87 | captured_value | bool / Exact bool; no numeric coercion |
| `build_progress` | 88 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `build_time` | 89 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_build_site` | 90 | reference_next_layer | — / none/entity/expired; ordered arrays retain order; never encode Node/ObjectID |
| `garrisoned` | 93 | captured_value | bool / Exact bool; no numeric coercion |
| `garrison_holder` | 94 | reference_next_layer | — / none/entity/expired; ordered arrays retain order; never encode Node/ObjectID |
| `_garrison_dest` | 95 | reference_next_layer | — / none/entity/expired; ordered arrays retain order; never encode Node/ObjectID |
| `passengers` | 96 | reference_next_layer | — / none/entity/expired; ordered arrays retain order; never encode Node/ObjectID |
| `garrison_cap` | 97 | captured_value | int / Exact signed int64 |
| `_train_queue` | 99 | captured_value | string_array / Array of nonempty String, <=8 training entries |
| `production_blocked` | 100 | captured_value | bool / Exact bool; no numeric coercion |
| `_production_retry` | 101 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_train_t` | 102 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `rally` | 103 | captured_value | vector2 / Finite native Vector2 components |
| `has_rally` | 104 | captured_value | bool / Exact bool; no numeric coercion |
| `rally_node` | 105 | reference_next_layer | — / none/entity/expired; ordered arrays retain order; never encode Node/ObjectID |
| `rally_kind` | 106 | captured_value | string / Exact String; aggregate codec byte budget |
| `_repair_g` | 107 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_repair_w` | 108 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_research_key` | 109 | captured_value | string / Exact String; aggregate codec byte budget |
| `_research_t` | 110 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `selected` | 112 | captured_value | bool / Exact bool; no numeric coercion |
| `is_active` | 113 | captured_value | bool / Exact bool; no numeric coercion |
| `inspected` | 114 | captured_value | bool / Exact bool; no numeric coercion |
| `fog_visible` | 115 | captured_value | bool / Exact bool; no numeric coercion |
| `passive` | 116 | captured_value | bool / Exact bool; no numeric coercion |
| `stance` | 117 | captured_value | int / [0, 3] |
| `_hold_order_active` | 118 | captured_value | bool / Exact bool; no numeric coercion |
| `_hold_prev_stance` | 119 | captured_value | int / [0, 3] |
| `_patrol_a` | 120 | captured_value | vector2 / Finite native Vector2 components |
| `_patrol_b` | 121 | captured_value | vector2 / Finite native Vector2 components |
| `_patrolling` | 122 | captured_value | bool / Exact bool; no numeric coercion |
| `hidden_in_reeds` | 123 | captured_value | bool / Exact bool; no numeric coercion |
| `buff_atk` | 124 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `buff_speed` | 125 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `face_left` | 126 | captured_value | bool / Exact bool; no numeric coercion |
| `group_nums` | 127 | captured_value | group_array / Strictly increasing unique int Array, <=32 badges |
| `ability` | 130 | captured_value | string / Exact String; aggregate codec byte budget |
| `ability_cd` | 131 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_ability_t` | 132 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `ability_slots` | 134 | captured_value | ability_slots / <=4 slots; exact 7 keys and native member types |
| `inventory` | 135 | runtime_relation_next_layer | — / bind new Battle/Map or dedicated HeroInventory adapter; no Resource/Node encoding |
| `_hero_leveled` | 136 | captured_value | bool / Exact bool; no numeric coercion |
| `hero_level` | 137 | captured_value | int / [1, 12] |
| `hero_xp` | 138 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `skill_points` | 139 | captured_value | int / Exact signed int64 |
| `auto_micro` | 140 | captured_value | bool / Exact bool; no numeric coercion |
| `ai_tick_phase` | 141 | captured_value | int / [0, 15] |
| `_ai_dest` | 142 | captured_value | vector2_positive_inf_sentinel / Finite Vector2 or exactly Vector2(+INF,+INF) |
| `_base_atk` | 143 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_base_hp` | 144 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_base_speed` | 145 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_base_defense` | 146 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `temp_atk` | 148 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_temp_atk_t` | 149 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `temp_atk_add` | 150 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_temp_atk_add_t` | 151 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `temp_speed` | 152 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_temp_speed_t` | 153 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_temp_move_boost` | 154 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_temp_move_boost_t` | 155 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_stun_t` | 156 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `temp_lifesteal` | 157 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_temp_lifesteal_t` | 158 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `cav_ls_chance` | 159 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `cav_ls_frac` | 160 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_lin_guard_t` | 162 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_lin_guard_rank` | 163 | captured_value | int / [0, 3] |
| `_lin_guard_used` | 164 | captured_value | bool / Exact bool; no numeric coercion |
| `lin_spear_rank` | 166 | captured_value | int / [0, 3] |
| `_lin_spear_target_id` | 167 | identity_or_source_next_layer | — / stable entity/effect/tombstone IDs; mixed source namespaces require explicit mapping |
| `_lin_spear_stacks` | 168 | captured_value | int / Exact signed int64 |
| `_lin_spear_t` | 169 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_buff_glow` | 170 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `is_summon` | 172 | captured_value | bool / Exact bool; no numeric coercion |
| `summon_kind` | 173 | captured_value | string / Exact String; aggregate codec byte budget |
| `_summon_ttl` | 174 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `stat_owner_key` | 175 | captured_value | string / Exact String; aggregate codec byte budget |
| `stat_ability_id` | 176 | captured_value | string / Exact String; aggregate codec byte budget |
| `_drunk_t` | 178 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_drunk_lo` | 179 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_drunk_hi` | 180 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_drunk_reroll` | 181 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_drunk_move` | 182 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_drunk_atk` | 183 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_phys_immune_t` | 185 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_absorbed_phys` | 186 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_drunk_god_bonus_per_hit` | 187 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_drunk_god_stacks` | 188 | captured_value | int / Exact signed int64 |
| `_drunk_god_max_stacks` | 189 | captured_value | int / Exact signed int64 |
| `_def_down` | 191 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_def_down_t` | 192 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_blind_t` | 194 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_attack_miss_chance` | 196 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_attack_miss_t` | 197 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `aura_slow` | 199 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `slow_aura_r` | 200 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_shield` | 202 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_shield_t` | 203 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_silence_t` | 204 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_root_t` | 205 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_disarm_t` | 206 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_taunt_t` | 207 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_taunt_src` | 208 | reference_next_layer | — / none/entity/expired; ordered arrays retain order; never encode Node/ObjectID |
| `_channel_t` | 209 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_channel_dur` | 210 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_invis_t` | 211 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_invis_strike_bonus` | 212 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_invis_strike_pending` | 213 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_hex_t` | 214 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_form_t` | 215 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_form` | 216 | captured_value | form / Known 7 optional keys only; finite numeric or Color tint |
| `_form_backup` | 217 | captured_value | form_backup / Empty or exact 6 original float fields |
| `_order_serial` | 218 | captured_value | int / Exact signed int64 |
| `temp_atkspeed` | 219 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_temp_atkspeed_t` | 220 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_attack_speed_slow` | 221 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_attack_speed_slow_t` | 222 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_aura_atkspeed` | 223 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_aura_atkspeed_sources` | 224 | identity_or_source_next_layer | — / stable entity/effect/tombstone IDs; mixed source namespaces require explicit mapping |
| `atkspeed_mult` | 226 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `crit_chance_bonus` | 227 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `crit_mult_bonus` | 228 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `evasion` | 229 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_temp_evasion` | 230 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_temp_evasion_t` | 231 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `bash_chance` | 232 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `bash_dur` | 233 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `on_hit_slow` | 234 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `on_hit_slow_dur` | 235 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `on_hit_dmg` | 236 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_dmg_amp` | 238 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_dmg_amp_t` | 239 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_damage_reduction` | 241 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_damage_reduction_t` | 242 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_damage_reduction_sources` | 243 | identity_or_source_next_layer | — / stable entity/effect/tombstone IDs; mixed source namespaces require explicit mapping |
| `_stats_mitigation_t` | 244 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_charge_t` | 246 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_charge_dash` | 247 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_charge_dir` | 248 | captured_value | vector2 / Finite native Vector2 components |
| `_charge_dmg` | 249 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_charge_ability_id` | 250 | captured_value | string / Exact String; aggregate codec byte budget |
| `_charge_slow` | 251 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_charge_slow_dur` | 252 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_charge_width` | 253 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_charge_hit` | 254 | identity_or_source_next_layer | — / stable entity/effect/tombstone IDs; mixed source namespaces require explicit mapping |
| `_charge_phys_immune` | 255 | captured_value | bool / Exact bool; no numeric coercion |
| `_hua_lock_target` | 257 | reference_next_layer | — / none/entity/expired; ordered arrays retain order; never encode Node/ObjectID |
| `_hua_lock_shots` | 258 | captured_value | int / Exact signed int64 |
| `_state` | 261 | captured_value | int / [0, 8] |
| `_path` | 262 | captured_value | packed_vector2 / PackedVector2Array, <=4096 finite points; no repath |
| `_path_i` | 263 | captured_value | int / Exact signed int64 |
| `_amove_dest` | 264 | captured_value | vector2 / Finite native Vector2 components |
| `_resume_amove` | 265 | captured_value | bool / Exact bool; no numeric coercion |
| `_target` | 266 | reference_next_layer | — / none/entity/expired; ordered arrays retain order; never encode Node/ObjectID |
| `_chase_intent` | 267 | captured_value | int / [0, 3] |
| `_group_cap` | 268 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_home` | 269 | captured_value | vector2 / Finite native Vector2 components |
| `_has_home` | 270 | captured_value | bool / Exact bool; no numeric coercion |
| `_cd` | 271 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_repath` | 272 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_acq_t` | 273 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_flash` | 274 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_muzzle_t` | 275 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_tower_aim` | 276 | captured_value | vector2i / Native signed int32 components |
| `_tower_aim_hold` | 277 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_stuck_t` | 278 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_idle_push_t` | 279 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_blocker_check_t` | 280 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_chasing_path_blocker` | 281 | captured_value | bool / Exact bool; no numeric coercion |
| `_eject_t` | 282 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_block_rp` | 283 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_burn_t` | 284 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `manual_order_t` | 285 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `manual_order_active` | 286 | captured_value | bool / Exact bool; no numeric coercion |
| `mission_order_active` | 288 | captured_value | bool / Exact bool; no numeric coercion |
| `mission_order_arrival_t` | 289 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `mission_order_target` | 290 | captured_value | vector2_positive_inf_sentinel / Finite Vector2 or exactly Vector2(+INF,+INF) |
| `mission_order_token` | 291 | captured_value | int / Exact signed int64 |
| `_move_retry` | 292 | captured_value | int / Exact signed int64 |
| `_move_retry_pos` | 293 | captured_value | vector2 / Finite native Vector2 components |
| `_last_pos` | 294 | captured_value | vector2 / Finite native Vector2 components |
| `_combat_cool` | 295 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_hit_recent_t` | 296 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_chase_t` | 299 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_chase_last_id` | 300 | identity_or_source_next_layer | — / stable entity/effect/tombstone IDs; mixed source namespaces require explicit mapping |
| `_chase_best_distance` | 301 | captured_value | float_positive_inf_sentinel / Nonnegative finite float or exactly +INF |
| `_giveup_id` | 302 | identity_or_source_next_layer | — / stable entity/effect/tombstone IDs; mixed source namespaces require explicit mapping |
| `_giveup_t` | 303 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_stepped` | 309 | captured_value | bool / Exact bool; no numeric coercion |
| `_move_blend` | 310 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_anim_t` | 311 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_lunge` | 312 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_lunge_dir` | 313 | captured_value | vector2 / Finite native Vector2 components |
| `_swing_kind` | 314 | captured_value | int / [0, 5] |
| `_swing_speed` | 315 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_hit_at` | 316 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_pending_target` | 317 | reference_next_layer | — / none/entity/expired; ordered arrays retain order; never encode Node/ObjectID |
| `_pending_done` | 318 | captured_value | bool / Exact bool; no numeric coercion |
| `_flinch` | 319 | captured_value | vector2 / Finite native Vector2 components |
| `_gather_anim_t` | 320 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_harvest_pulse` | 321 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_cast_t` | 322 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_cast_dur` | 323 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_cast_color` | 324 | captured_value | color / Finite float32 components; HDR/negative finite values retained |
| `_cast_serial` | 325 | captured_value | int / Exact signed int64 |
| `_weapon` | 326 | captured_value | int / [-1, 5] |
| `_idle_t` | 327 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_real_frames` | 328 | visual_cache_omitted | — / pure draw cache or dust; never call simulation to rebuild |
| `_frame_directional` | 329 | visual_cache_omitted | — / pure draw cache or dust; never call simulation to rebuild |
| `_animated_redraw_t` | 330 | visual_cache_omitted | — / pure draw cache or dust; never call simulation to rebuild |
| `_queued_redraw_frame` | 331 | visual_cache_omitted | — / pure draw cache or dust; never call simulation to rebuild |
| `_dying` | 332 | captured_value | bool / Exact bool; no numeric coercion |
| `_death_t` | 333 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_death_lean` | 334 | captured_value | float / Finite float; signed timer values preserved without clamping |
| `_dust` | 335 | visual_cache_omitted | — / pure draw cache or dust; never call simulation to rebuild |
| `_killer` | 862 | reference_next_layer | — / none/entity/expired; ordered arrays retain order; never encode Node/ObjectID |
| `_killer_source_id` | 863 | captured_value | string / Exact String; aggregate codec byte budget |
