extends RefCounted
## Standard-defense Unit factory, explicit module schema + caller content version.
## Compiled Script injection works in exported PCKs; no source_code/raw-file reads.
## Caller must stop simulation, validate the entire run, instantiate in saved order,
## bind every graph, connect Battle signals, attach while paused, then activate.
## Never calls setup/spawn_at/order/Inventory.restore or recomputes gameplay stats.
## Only art_variant's existing setter runs: signals are blocked, detached redraw only.
## Five draw caches are regenerated; draw cadence is not gameplay state.
const SCHEMA := "defense_unit_state_v1"
const ID_FIELDS := ["_lin_spear_target_id", "_chase_last_id", "_giveup_id"]
const POOL_FIELDS := ["_aura_atkspeed_sources", "_damage_reduction_sources"]
const INVENTORY_FIELDS := ["slots", "cooldowns", "proc_cooldowns", "_uid_seq", "_periodic_acc"]
const SLOT_COUNT := 6
const PERIODIC_STEP := 0.25
const MAX_ID_CHARS := 128
const MAX_EVENT_CHARS := 128
const MAX_PROC_KEYS := 256
const NODE_FIELDS := ["name", "basis_x", "basis_y", "visible", "self_modulate", "z_index", "z_as_relative", "show_behind_parent", "top_level", "y_sort_enabled", "activation"]
const ACTIVATION_FIELDS := ["mode", "priority", "physics_priority", "process", "physics", "input", "shortcut", "unhandled_input", "unhandled_key", "signals_blocked"]
var _unit_script: Script
var _inventory_script: Script
var _codec: Variant = null

func _init(codec_script: Script, unit_script: Script, inventory_script: Script) -> void:
	_unit_script = unit_script
	_inventory_script = inventory_script
	if codec_script != null and unit_script != null and inventory_script != null:
		if codec_script.can_instantiate() and unit_script.can_instantiate() and inventory_script.can_instantiate():
			_codec = codec_script.new()

func _failure(code: String, field: String = "") -> Dictionary:
	return {"ok": false, "code": code, "field": field}

func _version(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not value.is_empty() and value.length() <= 256

func _unit(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT and is_instance_valid(value) and value.get_script() == _unit_script and not value.is_queued_for_deletion()

const DECLARED_COUNT := 272
const CAPTURED_DECLARED_COUNT := 241
const RULES := {
  "defeat_outcome": "string",
  "story_outcome": "string",
  "movement_profile": "string",
  "art_variant": "string",
  "animation_direction": "string",
  "_direction_candidate": "string",
  "_direction_votes": "int",
  "_story_pose_t": "float",
  "_pose_previous_variant": "string",
  "key": "string",
  "display_name": "string",
  "faction": "int",
  "max_hp": "float",
  "hp": "float",
  "atk": "float",
  "atk_cd": "float",
  "atk_range": "float",
  "base_speed": "float",
  "is_ranged": "bool",
  "can_melee_switch": "bool",
  "melee_mode": "bool",
  "is_cavalry": "bool",
  "bonus_vs_cav": "float",
  "defense": "float",
  "is_hero": "bool",
  "is_building": "bool",
  "is_captive": "bool",
  "is_objective": "bool",
  "is_noncombat": "bool",
  "setup_def": "definition_values",
  "aura": "string",
  "aura_radius": "float",
  "aura_power": "float",
  "radius": "float",
  "visual_scale": "float",
  "aggro_range": "float",
  "_track_combat_stats": "bool",
  "is_worker": "bool",
  "is_resource": "bool",
  "res_kind": "string",
  "res_left": "float",
  "_carry_kind": "string",
  "_carry_amt": "float",
  "_gather_t": "float",
  "is_constructing": "bool",
  "_pending_build": "bool",
  "build_progress": "float",
  "build_time": "float",
  "garrisoned": "bool",
  "garrison_cap": "int",
  "_train_queue": "string_array",
  "production_blocked": "bool",
  "_production_retry": "float",
  "_train_t": "float",
  "rally": "vector2",
  "has_rally": "bool",
  "rally_kind": "string",
  "_repair_g": "float",
  "_repair_w": "float",
  "_research_key": "string",
  "_research_t": "float",
  "selected": "bool",
  "is_active": "bool",
  "inspected": "bool",
  "fog_visible": "bool",
  "passive": "bool",
  "stance": "int",
  "_hold_order_active": "bool",
  "_hold_prev_stance": "int",
  "_patrol_a": "vector2",
  "_patrol_b": "vector2",
  "_patrolling": "bool",
  "hidden_in_reeds": "bool",
  "buff_atk": "float",
  "buff_speed": "float",
  "face_left": "bool",
  "group_nums": "group_array",
  "ability": "string",
  "ability_cd": "float",
  "_ability_t": "float",
  "ability_slots": "ability_slots",
  "_hero_leveled": "bool",
  "hero_level": "int",
  "hero_xp": "float",
  "skill_points": "int",
  "auto_micro": "bool",
  "ai_tick_phase": "int",
  "_ai_dest": "vector2_positive_inf_sentinel",
  "_base_atk": "float",
  "_base_hp": "float",
  "_base_speed": "float",
  "_base_defense": "float",
  "temp_atk": "float",
  "_temp_atk_t": "float",
  "temp_atk_add": "float",
  "_temp_atk_add_t": "float",
  "temp_speed": "float",
  "_temp_speed_t": "float",
  "_temp_move_boost": "float",
  "_temp_move_boost_t": "float",
  "_stun_t": "float",
  "temp_lifesteal": "float",
  "_temp_lifesteal_t": "float",
  "cav_ls_chance": "float",
  "cav_ls_frac": "float",
  "_lin_guard_t": "float",
  "_lin_guard_rank": "int",
  "_lin_guard_used": "bool",
  "lin_spear_rank": "int",
  "_lin_spear_stacks": "int",
  "_lin_spear_t": "float",
  "_buff_glow": "float",
  "is_summon": "bool",
  "summon_kind": "string",
  "_summon_ttl": "float",
  "stat_owner_key": "string",
  "stat_ability_id": "string",
  "_drunk_t": "float",
  "_drunk_lo": "float",
  "_drunk_hi": "float",
  "_drunk_reroll": "float",
  "_drunk_move": "float",
  "_drunk_atk": "float",
  "_phys_immune_t": "float",
  "_absorbed_phys": "float",
  "_drunk_god_bonus_per_hit": "float",
  "_drunk_god_stacks": "int",
  "_drunk_god_max_stacks": "int",
  "_def_down": "float",
  "_def_down_t": "float",
  "_blind_t": "float",
  "_attack_miss_chance": "float",
  "_attack_miss_t": "float",
  "aura_slow": "float",
  "slow_aura_r": "float",
  "_shield": "float",
  "_shield_t": "float",
  "_silence_t": "float",
  "_root_t": "float",
  "_disarm_t": "float",
  "_taunt_t": "float",
  "_channel_t": "float",
  "_channel_dur": "float",
  "_invis_t": "float",
  "_invis_strike_bonus": "float",
  "_invis_strike_pending": "float",
  "_hex_t": "float",
  "_form_t": "float",
  "_form": "form",
  "_form_backup": "form_backup",
  "_order_serial": "int",
  "temp_atkspeed": "float",
  "_temp_atkspeed_t": "float",
  "_attack_speed_slow": "float",
  "_attack_speed_slow_t": "float",
  "_aura_atkspeed": "float",
  "atkspeed_mult": "float",
  "crit_chance_bonus": "float",
  "crit_mult_bonus": "float",
  "evasion": "float",
  "_temp_evasion": "float",
  "_temp_evasion_t": "float",
  "bash_chance": "float",
  "bash_dur": "float",
  "on_hit_slow": "float",
  "on_hit_slow_dur": "float",
  "on_hit_dmg": "float",
  "_dmg_amp": "float",
  "_dmg_amp_t": "float",
  "_damage_reduction": "float",
  "_damage_reduction_t": "float",
  "_stats_mitigation_t": "float",
  "_charge_t": "float",
  "_charge_dash": "float",
  "_charge_dir": "vector2",
  "_charge_dmg": "float",
  "_charge_ability_id": "string",
  "_charge_slow": "float",
  "_charge_slow_dur": "float",
  "_charge_width": "float",
  "_charge_phys_immune": "bool",
  "_hua_lock_shots": "int",
  "_state": "int",
  "_path": "packed_vector2",
  "_path_i": "int",
  "_amove_dest": "vector2",
  "_resume_amove": "bool",
  "_chase_intent": "int",
  "_group_cap": "float",
  "_home": "vector2",
  "_has_home": "bool",
  "_cd": "float",
  "_repath": "float",
  "_acq_t": "float",
  "_flash": "float",
  "_muzzle_t": "float",
  "_tower_aim": "vector2i",
  "_tower_aim_hold": "float",
  "_stuck_t": "float",
  "_idle_push_t": "float",
  "_blocker_check_t": "float",
  "_chasing_path_blocker": "bool",
  "_eject_t": "float",
  "_block_rp": "float",
  "_burn_t": "float",
  "manual_order_t": "float",
  "manual_order_active": "bool",
  "mission_order_active": "bool",
  "mission_order_arrival_t": "float",
  "mission_order_target": "vector2_positive_inf_sentinel",
  "mission_order_token": "int",
  "_move_retry": "int",
  "_move_retry_pos": "vector2",
  "_last_pos": "vector2",
  "_combat_cool": "float",
  "_hit_recent_t": "float",
  "_chase_t": "float",
  "_chase_best_distance": "float_positive_inf_sentinel",
  "_giveup_t": "float",
  "_stepped": "bool",
  "_move_blend": "float",
  "_anim_t": "float",
  "_lunge": "float",
  "_lunge_dir": "vector2",
  "_swing_kind": "int",
  "_swing_speed": "float",
  "_hit_at": "float",
  "_pending_done": "bool",
  "_flinch": "vector2",
  "_gather_anim_t": "float",
  "_harvest_pulse": "float",
  "_cast_t": "float",
  "_cast_dur": "float",
  "_cast_color": "color",
  "_cast_serial": "int",
  "_weapon": "int",
  "_idle_t": "float",
  "_dying": "bool",
  "_death_t": "float",
  "_death_lean": "float",
  "_killer_source_id": "string",
  "position": "vector2",
  "modulate": "color"
}
const INT_RANGES := {
  "faction": [
    0,
    1
  ],
  "stance": [
    0,
    3
  ],
  "_hold_prev_stance": [
    0,
    3
  ],
  "_state": [
    0,
    8
  ],
  "_chase_intent": [
    0,
    3
  ],
  "_swing_kind": [
    0,
    5
  ],
  "_weapon": [
    -1,
    5
  ],
  "hero_level": [
    1,
    12
  ],
  "ai_tick_phase": [
    0,
    15
  ],
  "_lin_guard_rank": [
    0,
    3
  ],
  "lin_spear_rank": [
    0,
    3
  ]
}
const DEFERRED_FIELDS := ["story_assist_partner", "story_assist_owner", "battle", "map", "_gold_miner", "_gold_waiters", "_queue", "_gather_node", "_drop", "_build_site", "garrison_holder", "_garrison_dest", "passengers", "rally_node", "inventory", "_lin_spear_target_id", "_taunt_src", "_aura_atkspeed_sources", "_damage_reduction_sources", "_charge_hit", "_hua_lock_target", "_target", "_chase_last_id", "_giveup_id", "_pending_target", "_killer"]
const OMITTED_VISUAL_FIELDS := ["_animated_redraw_t", "_dust", "_frame_directional", "_queued_redraw_frame", "_real_frames"]

const MAX_ENTITIES := 4096
const MAX_ARRAY_ITEMS := 4096
const MAX_ORDERS := 4096
const MAX_ID := "9223372036854775807"
const DIRECT_FIELDS := ["story_assist_partner","story_assist_owner","_gold_miner","_gather_node","_drop",
	"_build_site","garrison_holder","_garrison_dest","rally_node","_taunt_src","_hua_lock_target","_target","_pending_target","_killer"]
const ARRAY_FIELDS := ["_gold_waiters","passengers","_charge_hit"]
const FIELDS := ["story_assist_partner","story_assist_owner","_gold_miner","_gold_waiters","_gather_node","_drop",
	"_build_site","garrison_holder","_garrison_dest","passengers","rally_node","_taunt_src","_hua_lock_target","_target","_pending_target","_killer","_queue","_charge_hit"]

func _read_explicit(unit) -> Dictionary:
	return {
		"defeat_outcome":unit.defeat_outcome,
		"story_outcome":unit.story_outcome,
		"movement_profile":unit.movement_profile,
		"art_variant":unit.art_variant,
		"animation_direction":unit.animation_direction,
		"_direction_candidate":unit._direction_candidate,
		"_direction_votes":unit._direction_votes,
		"_story_pose_t":unit._story_pose_t,
		"_pose_previous_variant":unit._pose_previous_variant,
		"key":unit.key,
		"display_name":unit.display_name,
		"faction":unit.faction,
		"max_hp":unit.max_hp,
		"hp":unit.hp,
		"atk":unit.atk,
		"atk_cd":unit.atk_cd,
		"atk_range":unit.atk_range,
		"base_speed":unit.base_speed,
		"is_ranged":unit.is_ranged,
		"can_melee_switch":unit.can_melee_switch,
		"melee_mode":unit.melee_mode,
		"is_cavalry":unit.is_cavalry,
		"bonus_vs_cav":unit.bonus_vs_cav,
		"defense":unit.defense,
		"is_hero":unit.is_hero,
		"is_building":unit.is_building,
		"is_captive":unit.is_captive,
		"is_objective":unit.is_objective,
		"is_noncombat":unit.is_noncombat,
		"setup_def":unit.setup_def,
		"aura":unit.aura,
		"aura_radius":unit.aura_radius,
		"aura_power":unit.aura_power,
		"radius":unit.radius,
		"visual_scale":unit.visual_scale,
		"aggro_range":unit.aggro_range,
		"_track_combat_stats":unit._track_combat_stats,
		"is_worker":unit.is_worker,
		"is_resource":unit.is_resource,
		"res_kind":unit.res_kind,
		"res_left":unit.res_left,
		"_carry_kind":unit._carry_kind,
		"_carry_amt":unit._carry_amt,
		"_gather_t":unit._gather_t,
		"is_constructing":unit.is_constructing,
		"_pending_build":unit._pending_build,
		"build_progress":unit.build_progress,
		"build_time":unit.build_time,
		"garrisoned":unit.garrisoned,
		"garrison_cap":unit.garrison_cap,
		"_train_queue":unit._train_queue,
		"production_blocked":unit.production_blocked,
		"_production_retry":unit._production_retry,
		"_train_t":unit._train_t,
		"rally":unit.rally,
		"has_rally":unit.has_rally,
		"rally_kind":unit.rally_kind,
		"_repair_g":unit._repair_g,
		"_repair_w":unit._repair_w,
		"_research_key":unit._research_key,
		"_research_t":unit._research_t,
		"selected":unit.selected,
		"is_active":unit.is_active,
		"inspected":unit.inspected,
		"fog_visible":unit.fog_visible,
		"passive":unit.passive,
		"stance":unit.stance,
		"_hold_order_active":unit._hold_order_active,
		"_hold_prev_stance":unit._hold_prev_stance,
		"_patrol_a":unit._patrol_a,
		"_patrol_b":unit._patrol_b,
		"_patrolling":unit._patrolling,
		"hidden_in_reeds":unit.hidden_in_reeds,
		"buff_atk":unit.buff_atk,
		"buff_speed":unit.buff_speed,
		"face_left":unit.face_left,
		"group_nums":unit.group_nums,
		"ability":unit.ability,
		"ability_cd":unit.ability_cd,
		"_ability_t":unit._ability_t,
		"ability_slots":unit.ability_slots,
		"_hero_leveled":unit._hero_leveled,
		"hero_level":unit.hero_level,
		"hero_xp":unit.hero_xp,
		"skill_points":unit.skill_points,
		"auto_micro":unit.auto_micro,
		"ai_tick_phase":unit.ai_tick_phase,
		"_ai_dest":unit._ai_dest,
		"_base_atk":unit._base_atk,
		"_base_hp":unit._base_hp,
		"_base_speed":unit._base_speed,
		"_base_defense":unit._base_defense,
		"temp_atk":unit.temp_atk,
		"_temp_atk_t":unit._temp_atk_t,
		"temp_atk_add":unit.temp_atk_add,
		"_temp_atk_add_t":unit._temp_atk_add_t,
		"temp_speed":unit.temp_speed,
		"_temp_speed_t":unit._temp_speed_t,
		"_temp_move_boost":unit._temp_move_boost,
		"_temp_move_boost_t":unit._temp_move_boost_t,
		"_stun_t":unit._stun_t,
		"temp_lifesteal":unit.temp_lifesteal,
		"_temp_lifesteal_t":unit._temp_lifesteal_t,
		"cav_ls_chance":unit.cav_ls_chance,
		"cav_ls_frac":unit.cav_ls_frac,
		"_lin_guard_t":unit._lin_guard_t,
		"_lin_guard_rank":unit._lin_guard_rank,
		"_lin_guard_used":unit._lin_guard_used,
		"lin_spear_rank":unit.lin_spear_rank,
		"_lin_spear_stacks":unit._lin_spear_stacks,
		"_lin_spear_t":unit._lin_spear_t,
		"_buff_glow":unit._buff_glow,
		"is_summon":unit.is_summon,
		"summon_kind":unit.summon_kind,
		"_summon_ttl":unit._summon_ttl,
		"stat_owner_key":unit.stat_owner_key,
		"stat_ability_id":unit.stat_ability_id,
		"_drunk_t":unit._drunk_t,
		"_drunk_lo":unit._drunk_lo,
		"_drunk_hi":unit._drunk_hi,
		"_drunk_reroll":unit._drunk_reroll,
		"_drunk_move":unit._drunk_move,
		"_drunk_atk":unit._drunk_atk,
		"_phys_immune_t":unit._phys_immune_t,
		"_absorbed_phys":unit._absorbed_phys,
		"_drunk_god_bonus_per_hit":unit._drunk_god_bonus_per_hit,
		"_drunk_god_stacks":unit._drunk_god_stacks,
		"_drunk_god_max_stacks":unit._drunk_god_max_stacks,
		"_def_down":unit._def_down,
		"_def_down_t":unit._def_down_t,
		"_blind_t":unit._blind_t,
		"_attack_miss_chance":unit._attack_miss_chance,
		"_attack_miss_t":unit._attack_miss_t,
		"aura_slow":unit.aura_slow,
		"slow_aura_r":unit.slow_aura_r,
		"_shield":unit._shield,
		"_shield_t":unit._shield_t,
		"_silence_t":unit._silence_t,
		"_root_t":unit._root_t,
		"_disarm_t":unit._disarm_t,
		"_taunt_t":unit._taunt_t,
		"_channel_t":unit._channel_t,
		"_channel_dur":unit._channel_dur,
		"_invis_t":unit._invis_t,
		"_invis_strike_bonus":unit._invis_strike_bonus,
		"_invis_strike_pending":unit._invis_strike_pending,
		"_hex_t":unit._hex_t,
		"_form_t":unit._form_t,
		"_form":unit._form,
		"_form_backup":unit._form_backup,
		"_order_serial":unit._order_serial,
		"temp_atkspeed":unit.temp_atkspeed,
		"_temp_atkspeed_t":unit._temp_atkspeed_t,
		"_attack_speed_slow":unit._attack_speed_slow,
		"_attack_speed_slow_t":unit._attack_speed_slow_t,
		"_aura_atkspeed":unit._aura_atkspeed,
		"atkspeed_mult":unit.atkspeed_mult,
		"crit_chance_bonus":unit.crit_chance_bonus,
		"crit_mult_bonus":unit.crit_mult_bonus,
		"evasion":unit.evasion,
		"_temp_evasion":unit._temp_evasion,
		"_temp_evasion_t":unit._temp_evasion_t,
		"bash_chance":unit.bash_chance,
		"bash_dur":unit.bash_dur,
		"on_hit_slow":unit.on_hit_slow,
		"on_hit_slow_dur":unit.on_hit_slow_dur,
		"on_hit_dmg":unit.on_hit_dmg,
		"_dmg_amp":unit._dmg_amp,
		"_dmg_amp_t":unit._dmg_amp_t,
		"_damage_reduction":unit._damage_reduction,
		"_damage_reduction_t":unit._damage_reduction_t,
		"_stats_mitigation_t":unit._stats_mitigation_t,
		"_charge_t":unit._charge_t,
		"_charge_dash":unit._charge_dash,
		"_charge_dir":unit._charge_dir,
		"_charge_dmg":unit._charge_dmg,
		"_charge_ability_id":unit._charge_ability_id,
		"_charge_slow":unit._charge_slow,
		"_charge_slow_dur":unit._charge_slow_dur,
		"_charge_width":unit._charge_width,
		"_charge_phys_immune":unit._charge_phys_immune,
		"_hua_lock_shots":unit._hua_lock_shots,
		"_state":unit._state,
		"_path":unit._path,
		"_path_i":unit._path_i,
		"_amove_dest":unit._amove_dest,
		"_resume_amove":unit._resume_amove,
		"_chase_intent":unit._chase_intent,
		"_group_cap":unit._group_cap,
		"_home":unit._home,
		"_has_home":unit._has_home,
		"_cd":unit._cd,
		"_repath":unit._repath,
		"_acq_t":unit._acq_t,
		"_flash":unit._flash,
		"_muzzle_t":unit._muzzle_t,
		"_tower_aim":unit._tower_aim,
		"_tower_aim_hold":unit._tower_aim_hold,
		"_stuck_t":unit._stuck_t,
		"_idle_push_t":unit._idle_push_t,
		"_blocker_check_t":unit._blocker_check_t,
		"_chasing_path_blocker":unit._chasing_path_blocker,
		"_eject_t":unit._eject_t,
		"_block_rp":unit._block_rp,
		"_burn_t":unit._burn_t,
		"manual_order_t":unit.manual_order_t,
		"manual_order_active":unit.manual_order_active,
		"mission_order_active":unit.mission_order_active,
		"mission_order_arrival_t":unit.mission_order_arrival_t,
		"mission_order_target":unit.mission_order_target,
		"mission_order_token":unit.mission_order_token,
		"_move_retry":unit._move_retry,
		"_move_retry_pos":unit._move_retry_pos,
		"_last_pos":unit._last_pos,
		"_combat_cool":unit._combat_cool,
		"_hit_recent_t":unit._hit_recent_t,
		"_chase_t":unit._chase_t,
		"_chase_best_distance":unit._chase_best_distance,
		"_giveup_t":unit._giveup_t,
		"_stepped":unit._stepped,
		"_move_blend":unit._move_blend,
		"_anim_t":unit._anim_t,
		"_lunge":unit._lunge,
		"_lunge_dir":unit._lunge_dir,
		"_swing_kind":unit._swing_kind,
		"_swing_speed":unit._swing_speed,
		"_hit_at":unit._hit_at,
		"_pending_done":unit._pending_done,
		"_flinch":unit._flinch,
		"_gather_anim_t":unit._gather_anim_t,
		"_harvest_pulse":unit._harvest_pulse,
		"_cast_t":unit._cast_t,
		"_cast_dur":unit._cast_dur,
		"_cast_color":unit._cast_color,
		"_cast_serial":unit._cast_serial,
		"_weapon":unit._weapon,
		"_idle_t":unit._idle_t,
		"_dying":unit._dying,
		"_death_t":unit._death_t,
		"_death_lean":unit._death_lean,
		"_killer_source_id":unit._killer_source_id,
		"position":unit.position,
		"modulate":unit.modulate,
	}

const MAX_PATH_POINTS := 4096
func _assign_values(unit: Variant, values: Dictionary) -> void:
	unit.defeat_outcome = values["defeat_outcome"]
	unit.story_outcome = values["story_outcome"]
	unit.movement_profile = values["movement_profile"]
	unit.art_variant = values["art_variant"]
	unit.animation_direction = values["animation_direction"]
	unit._direction_candidate = values["_direction_candidate"]
	unit._direction_votes = values["_direction_votes"]
	unit._story_pose_t = values["_story_pose_t"]
	unit._pose_previous_variant = values["_pose_previous_variant"]
	unit.key = values["key"]
	unit.display_name = values["display_name"]
	unit.faction = values["faction"]
	unit.max_hp = values["max_hp"]
	unit.hp = values["hp"]
	unit.atk = values["atk"]
	unit.atk_cd = values["atk_cd"]
	unit.atk_range = values["atk_range"]
	unit.base_speed = values["base_speed"]
	unit.is_ranged = values["is_ranged"]
	unit.can_melee_switch = values["can_melee_switch"]
	unit.melee_mode = values["melee_mode"]
	unit.is_cavalry = values["is_cavalry"]
	unit.bonus_vs_cav = values["bonus_vs_cav"]
	unit.defense = values["defense"]
	unit.is_hero = values["is_hero"]
	unit.is_building = values["is_building"]
	unit.is_captive = values["is_captive"]
	unit.is_objective = values["is_objective"]
	unit.is_noncombat = values["is_noncombat"]
	unit.setup_def = values["setup_def"]
	unit.aura = values["aura"]
	unit.aura_radius = values["aura_radius"]
	unit.aura_power = values["aura_power"]
	unit.radius = values["radius"]
	unit.visual_scale = values["visual_scale"]
	unit.aggro_range = values["aggro_range"]
	unit._track_combat_stats = values["_track_combat_stats"]
	unit.is_worker = values["is_worker"]
	unit.is_resource = values["is_resource"]
	unit.res_kind = values["res_kind"]
	unit.res_left = values["res_left"]
	unit._carry_kind = values["_carry_kind"]
	unit._carry_amt = values["_carry_amt"]
	unit._gather_t = values["_gather_t"]
	unit.is_constructing = values["is_constructing"]
	unit._pending_build = values["_pending_build"]
	unit.build_progress = values["build_progress"]
	unit.build_time = values["build_time"]
	unit.garrisoned = values["garrisoned"]
	unit.garrison_cap = values["garrison_cap"]
	unit._train_queue = values["_train_queue"]
	unit.production_blocked = values["production_blocked"]
	unit._production_retry = values["_production_retry"]
	unit._train_t = values["_train_t"]
	unit.rally = values["rally"]
	unit.has_rally = values["has_rally"]
	unit.rally_kind = values["rally_kind"]
	unit._repair_g = values["_repair_g"]
	unit._repair_w = values["_repair_w"]
	unit._research_key = values["_research_key"]
	unit._research_t = values["_research_t"]
	unit.selected = values["selected"]
	unit.is_active = values["is_active"]
	unit.inspected = values["inspected"]
	unit.fog_visible = values["fog_visible"]
	unit.passive = values["passive"]
	unit.stance = values["stance"]
	unit._hold_order_active = values["_hold_order_active"]
	unit._hold_prev_stance = values["_hold_prev_stance"]
	unit._patrol_a = values["_patrol_a"]
	unit._patrol_b = values["_patrol_b"]
	unit._patrolling = values["_patrolling"]
	unit.hidden_in_reeds = values["hidden_in_reeds"]
	unit.buff_atk = values["buff_atk"]
	unit.buff_speed = values["buff_speed"]
	unit.face_left = values["face_left"]
	unit.group_nums = values["group_nums"]
	unit.ability = values["ability"]
	unit.ability_cd = values["ability_cd"]
	unit._ability_t = values["_ability_t"]
	unit.ability_slots = values["ability_slots"]
	unit._hero_leveled = values["_hero_leveled"]
	unit.hero_level = values["hero_level"]
	unit.hero_xp = values["hero_xp"]
	unit.skill_points = values["skill_points"]
	unit.auto_micro = values["auto_micro"]
	unit.ai_tick_phase = values["ai_tick_phase"]
	unit._ai_dest = values["_ai_dest"]
	unit._base_atk = values["_base_atk"]
	unit._base_hp = values["_base_hp"]
	unit._base_speed = values["_base_speed"]
	unit._base_defense = values["_base_defense"]
	unit.temp_atk = values["temp_atk"]
	unit._temp_atk_t = values["_temp_atk_t"]
	unit.temp_atk_add = values["temp_atk_add"]
	unit._temp_atk_add_t = values["_temp_atk_add_t"]
	unit.temp_speed = values["temp_speed"]
	unit._temp_speed_t = values["_temp_speed_t"]
	unit._temp_move_boost = values["_temp_move_boost"]
	unit._temp_move_boost_t = values["_temp_move_boost_t"]
	unit._stun_t = values["_stun_t"]
	unit.temp_lifesteal = values["temp_lifesteal"]
	unit._temp_lifesteal_t = values["_temp_lifesteal_t"]
	unit.cav_ls_chance = values["cav_ls_chance"]
	unit.cav_ls_frac = values["cav_ls_frac"]
	unit._lin_guard_t = values["_lin_guard_t"]
	unit._lin_guard_rank = values["_lin_guard_rank"]
	unit._lin_guard_used = values["_lin_guard_used"]
	unit.lin_spear_rank = values["lin_spear_rank"]
	unit._lin_spear_stacks = values["_lin_spear_stacks"]
	unit._lin_spear_t = values["_lin_spear_t"]
	unit._buff_glow = values["_buff_glow"]
	unit.is_summon = values["is_summon"]
	unit.summon_kind = values["summon_kind"]
	unit._summon_ttl = values["_summon_ttl"]
	unit.stat_owner_key = values["stat_owner_key"]
	unit.stat_ability_id = values["stat_ability_id"]
	unit._drunk_t = values["_drunk_t"]
	unit._drunk_lo = values["_drunk_lo"]
	unit._drunk_hi = values["_drunk_hi"]
	unit._drunk_reroll = values["_drunk_reroll"]
	unit._drunk_move = values["_drunk_move"]
	unit._drunk_atk = values["_drunk_atk"]
	unit._phys_immune_t = values["_phys_immune_t"]
	unit._absorbed_phys = values["_absorbed_phys"]
	unit._drunk_god_bonus_per_hit = values["_drunk_god_bonus_per_hit"]
	unit._drunk_god_stacks = values["_drunk_god_stacks"]
	unit._drunk_god_max_stacks = values["_drunk_god_max_stacks"]
	unit._def_down = values["_def_down"]
	unit._def_down_t = values["_def_down_t"]
	unit._blind_t = values["_blind_t"]
	unit._attack_miss_chance = values["_attack_miss_chance"]
	unit._attack_miss_t = values["_attack_miss_t"]
	unit.aura_slow = values["aura_slow"]
	unit.slow_aura_r = values["slow_aura_r"]
	unit._shield = values["_shield"]
	unit._shield_t = values["_shield_t"]
	unit._silence_t = values["_silence_t"]
	unit._root_t = values["_root_t"]
	unit._disarm_t = values["_disarm_t"]
	unit._taunt_t = values["_taunt_t"]
	unit._channel_t = values["_channel_t"]
	unit._channel_dur = values["_channel_dur"]
	unit._invis_t = values["_invis_t"]
	unit._invis_strike_bonus = values["_invis_strike_bonus"]
	unit._invis_strike_pending = values["_invis_strike_pending"]
	unit._hex_t = values["_hex_t"]
	unit._form_t = values["_form_t"]
	unit._form = values["_form"]
	unit._form_backup = values["_form_backup"]
	unit._order_serial = values["_order_serial"]
	unit.temp_atkspeed = values["temp_atkspeed"]
	unit._temp_atkspeed_t = values["_temp_atkspeed_t"]
	unit._attack_speed_slow = values["_attack_speed_slow"]
	unit._attack_speed_slow_t = values["_attack_speed_slow_t"]
	unit._aura_atkspeed = values["_aura_atkspeed"]
	unit.atkspeed_mult = values["atkspeed_mult"]
	unit.crit_chance_bonus = values["crit_chance_bonus"]
	unit.crit_mult_bonus = values["crit_mult_bonus"]
	unit.evasion = values["evasion"]
	unit._temp_evasion = values["_temp_evasion"]
	unit._temp_evasion_t = values["_temp_evasion_t"]
	unit.bash_chance = values["bash_chance"]
	unit.bash_dur = values["bash_dur"]
	unit.on_hit_slow = values["on_hit_slow"]
	unit.on_hit_slow_dur = values["on_hit_slow_dur"]
	unit.on_hit_dmg = values["on_hit_dmg"]
	unit._dmg_amp = values["_dmg_amp"]
	unit._dmg_amp_t = values["_dmg_amp_t"]
	unit._damage_reduction = values["_damage_reduction"]
	unit._damage_reduction_t = values["_damage_reduction_t"]
	unit._stats_mitigation_t = values["_stats_mitigation_t"]
	unit._charge_t = values["_charge_t"]
	unit._charge_dash = values["_charge_dash"]
	unit._charge_dir = values["_charge_dir"]
	unit._charge_dmg = values["_charge_dmg"]
	unit._charge_ability_id = values["_charge_ability_id"]
	unit._charge_slow = values["_charge_slow"]
	unit._charge_slow_dur = values["_charge_slow_dur"]
	unit._charge_width = values["_charge_width"]
	unit._charge_phys_immune = values["_charge_phys_immune"]
	unit._hua_lock_shots = values["_hua_lock_shots"]
	unit._state = values["_state"]
	unit._path = values["_path"]
	unit._path_i = values["_path_i"]
	unit._amove_dest = values["_amove_dest"]
	unit._resume_amove = values["_resume_amove"]
	unit._chase_intent = values["_chase_intent"]
	unit._group_cap = values["_group_cap"]
	unit._home = values["_home"]
	unit._has_home = values["_has_home"]
	unit._cd = values["_cd"]
	unit._repath = values["_repath"]
	unit._acq_t = values["_acq_t"]
	unit._flash = values["_flash"]
	unit._muzzle_t = values["_muzzle_t"]
	unit._tower_aim = values["_tower_aim"]
	unit._tower_aim_hold = values["_tower_aim_hold"]
	unit._stuck_t = values["_stuck_t"]
	unit._idle_push_t = values["_idle_push_t"]
	unit._blocker_check_t = values["_blocker_check_t"]
	unit._chasing_path_blocker = values["_chasing_path_blocker"]
	unit._eject_t = values["_eject_t"]
	unit._block_rp = values["_block_rp"]
	unit._burn_t = values["_burn_t"]
	unit.manual_order_t = values["manual_order_t"]
	unit.manual_order_active = values["manual_order_active"]
	unit.mission_order_active = values["mission_order_active"]
	unit.mission_order_arrival_t = values["mission_order_arrival_t"]
	unit.mission_order_target = values["mission_order_target"]
	unit.mission_order_token = values["mission_order_token"]
	unit._move_retry = values["_move_retry"]
	unit._move_retry_pos = values["_move_retry_pos"]
	unit._last_pos = values["_last_pos"]
	unit._combat_cool = values["_combat_cool"]
	unit._hit_recent_t = values["_hit_recent_t"]
	unit._chase_t = values["_chase_t"]
	unit._chase_best_distance = values["_chase_best_distance"]
	unit._giveup_t = values["_giveup_t"]
	unit._stepped = values["_stepped"]
	unit._move_blend = values["_move_blend"]
	unit._anim_t = values["_anim_t"]
	unit._lunge = values["_lunge"]
	unit._lunge_dir = values["_lunge_dir"]
	unit._swing_kind = values["_swing_kind"]
	unit._swing_speed = values["_swing_speed"]
	unit._hit_at = values["_hit_at"]
	unit._pending_done = values["_pending_done"]
	unit._flinch = values["_flinch"]
	unit._gather_anim_t = values["_gather_anim_t"]
	unit._harvest_pulse = values["_harvest_pulse"]
	unit._cast_t = values["_cast_t"]
	unit._cast_dur = values["_cast_dur"]
	unit._cast_color = values["_cast_color"]
	unit._cast_serial = values["_cast_serial"]
	unit._weapon = values["_weapon"]
	unit._idle_t = values["_idle_t"]
	unit._dying = values["_dying"]
	unit._death_t = values["_death_t"]
	unit._death_lean = values["_death_lean"]
	unit._killer_source_id = values["_killer_source_id"]
	unit.position = values["position"]
	unit.modulate = values["modulate"]

func _fields(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size(): return false
	for key in value:
		if typeof(key) != TYPE_STRING or key not in expected: return false
	return true

func _finite_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value))

func _check_values(values: Dictionary) -> Dictionary:
	if not _fields(values, RULES.keys()): return _failure("VALUE_FIELDS")
	for field in RULES:
		var value: Variant = values[field]
		var rule: String = RULES[field]
		match rule:
			"string":
				if typeof(value) != TYPE_STRING: return _failure("VALUE_TYPE",field)
			"bool":
				if typeof(value) != TYPE_BOOL: return _failure("VALUE_TYPE",field)
			"int":
				if typeof(value) != TYPE_INT: return _failure("VALUE_TYPE",field)
				if INT_RANGES.has(field) and (value < INT_RANGES[field][0] or value > INT_RANGES[field][1]): return _failure("VALUE_RANGE",field)
			"float":
				if typeof(value) != TYPE_FLOAT: return _failure("VALUE_TYPE",field)
				if not is_finite(value): return _failure("NON_FINITE",field)
			"vector2":
				if typeof(value) != TYPE_VECTOR2: return _failure("VALUE_TYPE",field)
				if not value.is_finite(): return _failure("NON_FINITE",field)
			"vector2i":
				if typeof(value) != TYPE_VECTOR2I: return _failure("VALUE_TYPE",field)
			"color":
				if typeof(value) != TYPE_COLOR: return _failure("VALUE_TYPE",field)
				for component in [value.r,value.g,value.b,value.a]:
					if not is_finite(component): return _failure("NON_FINITE",field)
			"vector2_positive_inf_sentinel":
				if typeof(value) != TYPE_VECTOR2: return _failure("VALUE_TYPE",field)
				if value != Vector2.INF and not value.is_finite(): return _failure("SENTINEL_VALUE",field)
			"float_positive_inf_sentinel":
				if typeof(value) != TYPE_FLOAT: return _failure("VALUE_TYPE",field)
				if value != INF and (not is_finite(value) or value < 0.0): return _failure("SENTINEL_VALUE",field)
			"packed_vector2":
				if typeof(value) != TYPE_PACKED_VECTOR2_ARRAY: return _failure("VALUE_TYPE",field)
				if value.size() > MAX_PATH_POINTS: return _failure("PATH_LIMIT",field)
				for point in value:
					if not point.is_finite(): return _failure("NON_FINITE",field)
			"string_array":
				if typeof(value) != TYPE_ARRAY: return _failure("VALUE_TYPE",field)
				if value.size() > 8: return _failure("TRAIN_QUEUE_LIMIT",field)
				for key in value:
					if typeof(key) != TYPE_STRING or key.is_empty(): return _failure("TRAIN_QUEUE_SHAPE",field)
			"group_array":
				if typeof(value) != TYPE_ARRAY: return _failure("VALUE_TYPE",field)
				if value.size() > 32: return _failure("GROUP_LIMIT",field)
				for index in range(value.size()):
					if typeof(value[index]) != TYPE_INT: return _failure("GROUP_SHAPE",field)
					if index > 0 and value[index] <= value[index-1]: return _failure("GROUP_ORDER",field)
			"definition_values":
				# Preserve the complete effective definition as bounded values. This
				# does NOT certify its business keys, cross-references or content ID.
				if typeof(value) != TYPE_DICTIONARY: return _failure("VALUE_TYPE",field)
				if value.size() > 512: return _failure("DEFINITION_LIMIT",field)
				for key in value:
					if typeof(key) != TYPE_STRING: return _failure("DEFINITION_KEY",field)
			"ability_slots":
				if typeof(value) != TYPE_ARRAY: return _failure("VALUE_TYPE",field)
				if value.size() > 4: return _failure("ABILITY_SLOT_LIMIT",field)
				for slot in value:
					if typeof(slot) != TYPE_DICTIONARY or not _fields(slot,["id","rank","cd_t","passive","charges","recharge_t","cast_seq"]): return _failure("ABILITY_SLOT_FIELDS",field)
					if typeof(slot.id) != TYPE_STRING or slot.id.is_empty() or typeof(slot.passive) != TYPE_BOOL: return _failure("ABILITY_SLOT_TYPE",field)
					for key in ["rank","charges","cast_seq"]:
						if typeof(slot[key]) != TYPE_INT or slot[key] < 0: return _failure("ABILITY_SLOT_TYPE",field)
					if slot.rank > 3: return _failure("ABILITY_SLOT_RANK",field)
					for key in ["cd_t","recharge_t"]:
						if typeof(slot[key]) != TYPE_FLOAT or not is_finite(slot[key]) or slot[key] < 0.0: return _failure("ABILITY_SLOT_TIMER",field)
			"form":
				if typeof(value) != TYPE_DICTIONARY: return _failure("VALUE_TYPE",field)
				for key in value:
					if typeof(key) != TYPE_STRING or key not in ["hp_mult","atk_mult","speed_mult","atk_cd_mult","range","radius","tint"]: return _failure("FORM_FIELDS",field)
					if key == "tint":
						if typeof(value[key]) != TYPE_COLOR: return _failure("FORM_TYPE",field)
					elif not _finite_number(value[key]): return _failure("FORM_TYPE",field)
			"form_backup":
				if typeof(value) != TYPE_DICTIONARY: return _failure("VALUE_TYPE",field)
				if not value.is_empty() and not _fields(value,["atk_cd","base_speed","radius","mod_r","mod_g","mod_b"]): return _failure("FORM_BACKUP_FIELDS",field)
				for key in value:
					if typeof(value[key]) != TYPE_FLOAT or not is_finite(value[key]): return _failure("FORM_BACKUP_TYPE",field)
			_: return _failure("RULE_UNIMPLEMENTED",field)
	# Standard defense excludes chapter state; references remain the next layer's
	# responsibility even when current pointers happen to be null.
	for field in ["defeat_outcome","story_outcome","_pose_previous_variant"]:
		if values[field] != "": return _failure("CHAPTER_STATE_UNSUPPORTED",field)
	if values._story_pose_t != 0.0 or values.is_captive: return _failure("CHAPTER_STATE_UNSUPPORTED")
	if values._path_i < 0: return _failure("VALUE_RANGE","_path_i")
	return {"ok":true}

func _to_wire(values: Dictionary) -> Dictionary:
	var wire := values.duplicate(false)
	var points: Array[Vector2] = []
	for point in values._path: points.append(point)
	wire._path = points
	for field in ["_ai_dest","mission_order_target"]:
		wire[field] = {"state":"positive_inf"} if values[field] == Vector2.INF else {"state":"finite","point":values[field]}
	wire._chase_best_distance = {"state":"positive_inf"} if values._chase_best_distance == INF else {"state":"finite","distance":values._chase_best_distance}
	return wire

func _from_wire(wire: Dictionary) -> Dictionary:
	if not _fields(wire,RULES.keys()): return _failure("VALUE_FIELDS")
	if typeof(wire._path) != TYPE_ARRAY or wire._path.size() > MAX_PATH_POINTS: return _failure("PATH_SHAPE","_path")
	var points: Array[Vector2] = []
	for point in wire._path:
		if typeof(point) != TYPE_VECTOR2 or not point.is_finite(): return _failure("PATH_SHAPE","_path")
		points.append(point)
	var values := wire.duplicate(false)
	values._path = PackedVector2Array(points)
	for field in ["_ai_dest","mission_order_target","_chase_best_distance"]:
		var tagged: Variant = wire[field]
		if typeof(tagged) != TYPE_DICTIONARY or not tagged.has("state") or typeof(tagged.state) != TYPE_STRING: return _failure("SENTINEL_SHAPE",field)
		if tagged.state == "positive_inf":
			if not _fields(tagged,["state"]): return _failure("SENTINEL_SHAPE",field)
			values[field] = INF if field == "_chase_best_distance" else Vector2.INF
		elif tagged.state == "finite":
			var key := "distance" if field == "_chase_best_distance" else "point"
			if not _fields(tagged,["state",key]): return _failure("SENTINEL_SHAPE",field)
			values[field] = tagged[key]
			if field == "_chase_best_distance":
				if typeof(values[field]) != TYPE_FLOAT or not is_finite(values[field]) or values[field] < 0.0: return _failure("SENTINEL_VALUE",field)
			elif typeof(values[field]) != TYPE_VECTOR2 or not values[field].is_finite(): return _failure("SENTINEL_VALUE",field)
		else: return _failure("SENTINEL_SHAPE",field)
	return {"ok":true,"values":values}

func _id(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.is_empty() or value.length() > MAX_ID.length(): return false
	if value.unicode_at(0) < 49 or value.unicode_at(0) > 57: return false
	for i in range(1, value.length()):
		var c: int = value.unicode_at(i)
		if c < 48 or c > 57: return false
	return value.length() < MAX_ID.length() or value <= MAX_ID

func _registry(registry: Variant) -> Dictionary:
	if typeof(registry) != TYPE_DICTIONARY or registry.is_empty() or registry.size() > MAX_ENTITIES: return _failure("REGISTRY_SHAPE")
	var ids: Dictionary = {}
	for object in registry:
		# A queued deletion is still live, but this draft requires the caller's
		# snapshot barrier to finish deletion before building its registry.
		if typeof(object) != TYPE_OBJECT or not is_instance_valid(object): return _failure("REGISTRY_OBJECT")
		if object.get_script() != _unit_script: return _failure("REGISTRY_UNIT_TYPE")
		if object.is_queued_for_deletion(): return _failure("REGISTRY_PENDING_DELETE")
		var entity_id: Variant = registry[object]
		if not _id(entity_id): return _failure("REGISTRY_ID")
		if ids.has(entity_id): return _failure("REGISTRY_DUPLICATE_ID")
		ids[entity_id] = true
	return {"ok":true,"ids":ids}

func _tag(value: Variant, registry: Dictionary, path: String) -> Dictionary:
	# Do not compare to null first: freed Object Variants must retain expired.
	if typeof(value) == TYPE_NIL: return {"ok":true,"value":{"state":"none"}}
	if typeof(value) != TYPE_OBJECT: return _failure("REFERENCE_TYPE", path)
	if not is_instance_valid(value): return {"ok":true,"value":{"state":"expired"}}
	if value.get_script() != _unit_script: return _failure("REFERENCE_UNIT_TYPE", path)
	if not registry.has(value): return _failure("REFERENCE_UNREGISTERED", path)
	return {"ok":true,"value":{"state":"entity","id":registry[value]}}

func _check_tag(value: Variant, ids: Dictionary, path: String) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not value.has("state") or typeof(value.state) != TYPE_STRING: return _failure("REFERENCE_TAG", path)
	match value.state:
		"none", "expired":
			if not _fields(value,["state"]): return _failure("REFERENCE_TAG", path)
		"entity":
			if not _fields(value,["state","id"]) or not _id(value.id): return _failure("REFERENCE_TAG", path)
			if not ids.has(value.id): return _failure("REFERENCE_UNKNOWN_ID", path)
		_: return _failure("REFERENCE_TAG", path)
	return {"ok":true}

func _read_references(unit) -> Dictionary:
	return {"story_assist_partner":unit.story_assist_partner,"story_assist_owner":unit.story_assist_owner,
		"_gold_miner":unit._gold_miner,"_gold_waiters":unit._gold_waiters,"_gather_node":unit._gather_node,"_drop":unit._drop,
		"_build_site":unit._build_site,"garrison_holder":unit.garrison_holder,"_garrison_dest":unit._garrison_dest,
		"passengers":unit.passengers,"rally_node":unit.rally_node,"_taunt_src":unit._taunt_src,"_hua_lock_target":unit._hua_lock_target,
		"_target":unit._target,"_pending_target":unit._pending_target,"_killer":unit._killer,"_queue":unit._queue,"_charge_hit":unit._charge_hit}

func _order(order: Variant, registry_or_ids: Dictionary, capturing: bool, path: String) -> Dictionary:
	if typeof(order) != TYPE_DICTIONARY or not order.has("kind") or typeof(order.kind) != TYPE_STRING: return _failure("ORDER_SHAPE", path)
	var result: Dictionary = {"kind":order.kind}
	match order.kind:
		"move", "amove":
			if not _fields(order,["kind","pos","group_cap"]): return _failure("ORDER_FIELDS", path)
			if typeof(order.pos) != TYPE_VECTOR2 or not order.pos.is_finite(): return _failure("ORDER_POSITION", path)
			if typeof(order.group_cap) != TYPE_FLOAT or not is_finite(order.group_cap): return _failure("ORDER_GROUP_CAP", path)
			result["pos"] = order.pos
			result["group_cap"] = order.group_cap
		"attack", "gather", "build", "repair", "garrison":
			var names: Array = ["kind","target","explicit"] if order.kind == "attack" else ["kind","target"]
			if not _fields(order, names): return _failure("ORDER_FIELDS", path)
			if order.kind == "attack":
				if typeof(order.explicit) != TYPE_BOOL: return _failure("ORDER_EXPLICIT", path)
				result["explicit"] = order.explicit
			var tagged: Dictionary = _tag(order.target, registry_or_ids, path+".target") if capturing else _check_tag(order.target, registry_or_ids, path+".target")
			if not tagged.ok: return tagged
			result["target"] = tagged.value if capturing else order.target.duplicate(true)
		_: return _failure("ORDER_KIND", path)
	return {"ok":true,"value":result}

func _references(values: Variant, registry_or_ids: Dictionary, capturing: bool) -> Dictionary:
	if typeof(values) != TYPE_DICTIONARY or not _fields(values,FIELDS): return _failure("REFERENCE_FIELDS")
	var result: Dictionary = {}
	for field in DIRECT_FIELDS:
		var tagged: Dictionary = _tag(values[field], registry_or_ids, field) if capturing else _check_tag(values[field], registry_or_ids, field)
		if not tagged.ok: return tagged
		result[field] = tagged.value if capturing else values[field].duplicate(true)
	for field in ARRAY_FIELDS:
		if typeof(values[field]) != TYPE_ARRAY or values[field].size() > MAX_ARRAY_ITEMS: return _failure("REFERENCE_ARRAY", field)
		var entries: Array = []
		for i in range(values[field].size()):
			var path := "%s[%d]" % [field,i]
			var tagged: Dictionary = _tag(values[field][i], registry_or_ids, path) if capturing else _check_tag(values[field][i], registry_or_ids, path)
			if not tagged.ok: return tagged
			# Never deduplicate, sort or sweep stale passengers/waiters here.
			entries.append(tagged.value if capturing else values[field][i].duplicate(true))
		result[field] = entries
	if typeof(values._queue) != TYPE_ARRAY or values._queue.size() > MAX_ORDERS: return _failure("ORDER_QUEUE")
	var orders: Array = []
	for i in range(values._queue.size()):
		var checked := _order(values._queue[i], registry_or_ids, capturing, "_queue[%d]" % i)
		if not checked.ok: return checked
		orders.append(checked.value)
	# New transport keys must be String; dot assignment inserts StringName.
	result["_queue"] = orders
	return {"ok":true,"values":result}

func _remaining(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT and is_finite(value) and value > 0.0

func _check_inventory(values: Dictionary) -> Dictionary:
	if not _fields(values, INVENTORY_FIELDS): return _failure("INVENTORY_FIELDS")
	if typeof(values.slots) != TYPE_ARRAY or values.slots.size() != SLOT_COUNT:
		return _failure("SLOT_SHAPE", "slots")
	var held_ids: Dictionary = {}
	var held_uid_text: Dictionary = {}
	for index in range(SLOT_COUNT):
		var item: Variant = values.slots[index]
		var field: String = "slots[%d]" % index
		if typeof(item) != TYPE_DICTIONARY: return _failure("ITEM_SHAPE", field)
		if item.is_empty(): continue
		if not _fields(item, ["id", "count", "uid"]): return _failure("ITEM_FIELDS", field)
		if typeof(item.id) != TYPE_STRING or item.id.is_empty() or item.id.length() > MAX_ID_CHARS:
			return _failure("ITEM_ID", field)
		if typeof(item.count) != TYPE_INT or item.count <= 0: return _failure("ITEM_COUNT", field)
		if typeof(item.uid) != TYPE_INT or item.uid <= 0: return _failure("ITEM_UID", field)
		# Do not derive UID from the current owner or compare UID against _uid_seq:
		# transfer_slot preserves another owner's UID without raising receiver seq.
		var uid_text: String = str(item.uid)
		if held_uid_text.has(uid_text): return _failure("DUPLICATE_UID", field)
		held_uid_text[uid_text] = true
		held_ids[item.id] = true
	if typeof(values.cooldowns) != TYPE_DICTIONARY or values.cooldowns.size() > SLOT_COUNT:
		return _failure("COOLDOWN_SHAPE", "cooldowns")
	for key in values.cooldowns:
		if typeof(key) != TYPE_STRING or not held_ids.has(key):
			return _failure("COOLDOWN_ITEM", "cooldowns")
		if not _remaining(values.cooldowns[key]): return _failure("COOLDOWN_VALUE", "cooldowns")
	if typeof(values.proc_cooldowns) != TYPE_DICTIONARY or values.proc_cooldowns.size() > MAX_PROC_KEYS:
		return _failure("PROC_SHAPE", "proc_cooldowns")
	for key in values.proc_cooldowns:
		if typeof(key) != TYPE_STRING or key.length() > 20 + 1 + MAX_EVENT_CHARS:
			return _failure("PROC_KEY", "proc_cooldowns")
		var colon: int = key.find(":")
		if colon <= 0 or colon == key.length() - 1 or key.find(":", colon + 1) >= 0:
			return _failure("PROC_KEY", "proc_cooldowns")
		# Match an already checked exact decimal int64; never parse through float.
		if not held_uid_text.has(key.left(colon)): return _failure("PROC_UID", "proc_cooldowns")
		if key.length() - colon - 1 > MAX_EVENT_CHARS: return _failure("PROC_KEY", "proc_cooldowns")
		if not _remaining(values.proc_cooldowns[key]): return _failure("PROC_VALUE", "proc_cooldowns")
	if typeof(values._uid_seq) != TYPE_INT or values._uid_seq < 0:
		return _failure("UID_SEQUENCE", "_uid_seq")
	if typeof(values._periodic_acc) != TYPE_FLOAT or not is_finite(values._periodic_acc) \
			or values._periodic_acc < 0.0 or values._periodic_acc >= PERIODIC_STEP:
		return _failure("PERIODIC_PHASE", "_periodic_acc")
	return {"ok": true}


func _known_ids(ids: Dictionary) -> Dictionary:
	if ids.is_empty() or ids.size() > MAX_ENTITIES: return _failure("REGISTRY_SHAPE")
	for key in ids:
		if not _id(key): return _failure("REGISTRY_ID")
	return {"ok": true}

# Identity callbacks receive (field_name, value/token). Capture/decode return
# {ok:true,value:...}; validate returns {ok:true}. Callbacks must be pure.
# No sign/range heuristic: pools mix ward serials, item hashes and ObjectIDs.
func _identity_call(callback: Callable, field: String, value: Variant, needs_value: bool) -> Dictionary:
	if not callback.is_valid(): return _failure("IDENTITY_CALLBACK_REQUIRED", field)
	var result: Variant = callback.call(field, value)
	if typeof(result) != TYPE_DICTIONARY or typeof(result.get("ok")) != TYPE_BOOL:
		return _failure("IDENTITY_CALLBACK_RESULT", field)
	if not result.ok:
		return _failure("IDENTITY_" + String(result.get("code", "REJECTED")), field)
	if needs_value and not result.has("value"): return _failure("IDENTITY_CALLBACK_VALUE", field)
	return result

func _pool_state(value: Variant, field: String) -> bool:
	var amount_key: String = "mult" if field == "_aura_atkspeed_sources" else "amount"
	if typeof(value) != TYPE_DICTIONARY or not _fields(value, [amount_key, "t"]): return false
	for key in [amount_key, "t"]:
		if typeof(value[key]) != TYPE_FLOAT or not is_finite(value[key]): return false
	# Preserve remaining values exactly; no clamp, refresh or pruning during restore.
	return true

func _identities(ids: Variant, pools: Variant, callback: Callable, operation: String) -> Dictionary:
	if typeof(ids) != TYPE_DICTIONARY or not _fields(ids, ID_FIELDS): return _failure("IDENTITY_FIELDS")
	if typeof(pools) != TYPE_DICTIONARY or not _fields(pools, POOL_FIELDS): return _failure("POOL_FIELDS")
	var result_ids: Dictionary = {}
	var result_pools: Dictionary = {}
	for field in ID_FIELDS:
		if operation == "capture" and typeof(ids[field]) != TYPE_INT: return _failure("IDENTITY_INTEGER", field)
		var result: Dictionary = _identity_call(callback, field, ids[field], operation != "validate")
		if not result.ok: return result
		if operation == "decode" and typeof(result.value) != TYPE_INT: return _failure("IDENTITY_INTEGER", field)
		result_ids[field] = ids[field] if operation == "validate" else result.value
	for field in POOL_FIELDS:
		var source: Variant = pools[field]
		var entries: Array = []
		if operation == "capture":
			if typeof(source) != TYPE_DICTIONARY or source.size() > MAX_ARRAY_ITEMS: return _failure("POOL_SHAPE", field)
			for key in source:
				if typeof(key) != TYPE_INT or not _pool_state(source[key], field): return _failure("POOL_STATE", field)
				var encoded: Dictionary = _identity_call(callback, field, key, true)
				if not encoded.ok: return encoded
				entries.append({"source": encoded.value, "state": source[key]})
		else:
			if typeof(source) != TYPE_ARRAY or source.size() > MAX_ARRAY_ITEMS: return _failure("POOL_SHAPE", field)
			entries = source
		var seen: Array = []
		var mapped: Dictionary = {}
		for entry in entries:
			if typeof(entry) != TYPE_DICTIONARY or not _fields(entry, ["source", "state"]) or not _pool_state(entry.state, field):
				return _failure("POOL_ENTRY", field)
			if seen.has(entry.source): return _failure("POOL_DUPLICATE_TOKEN", field)
			seen.append(entry.source)
			if operation != "capture":
				var decoded: Dictionary = _identity_call(callback, field, entry.source, operation == "decode")
				if not decoded.ok: return decoded
				if operation == "decode":
					if typeof(decoded.value) != TYPE_INT: return _failure("POOL_INTEGER", field)
					if mapped.has(decoded.value): return _failure("POOL_REMAP_COLLISION", field)
					mapped[decoded.value] = entry.state.duplicate(true)
		result_pools[field] = mapped if operation == "decode" else entries
	return {"ok": true, "ids": result_ids, "pools": result_pools}

func _read_metadata(unit: Variant) -> Dictionary:
	var result: Dictionary = {}
	var names: Array[StringName] = unit.get_meta_list()
	if names.size() > 128: return _failure("METADATA_LIMIT")
	for meta_name in names:
		var key: String = String(meta_name)
		if key.is_empty() or key.length() > 256: return _failure("METADATA_KEY", key)
		var value: Variant = unit.get_meta(meta_name)
		if typeof(value) == TYPE_RECT2:
			result[key] = {"kind": "rect2", "position": value.position, "size": value.size}
		else:
			# Codec rejects unsupported Objects/Resources; never silently drops meta.
			result[key] = {"kind": "value", "value": value}
	return {"ok": true, "value": result}

func _check_metadata(values: Variant) -> Dictionary:
	if typeof(values) != TYPE_DICTIONARY or values.size() > 128: return _failure("METADATA_SHAPE")
	var result: Dictionary = {}
	for key in values:
		if typeof(key) != TYPE_STRING or key.is_empty() or key.length() > 256: return _failure("METADATA_KEY")
		var entry: Variant = values[key]
		if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("kind")) != TYPE_STRING: return _failure("METADATA_ENTRY", key)
		if entry.kind == "rect2":
			if not _fields(entry, ["kind", "position", "size"]) or typeof(entry.position) != TYPE_VECTOR2 or typeof(entry.size) != TYPE_VECTOR2:
				return _failure("METADATA_RECT", key)
			if not entry.position.is_finite() or not entry.size.is_finite(): return _failure("METADATA_RECT", key)
			result[key] = Rect2(entry.position, entry.size)
		elif entry.kind == "value":
			if not _fields(entry, ["kind", "value"]): return _failure("METADATA_ENTRY", key)
			result[key] = entry.value
		else: return _failure("METADATA_KIND", key)
	return {"ok": true, "value": result}

func _read_node(unit: Variant) -> Dictionary:
	# Engine-generated @ names are transient. Recreate them on attachment;
	# stable entity IDs, rather than generated NodePaths, bind gameplay graphs.
	var saved_name: String = "" if String(unit.name).begins_with("@") else String(unit.name)
	return {"name": saved_name, "basis_x": unit.transform.x, "basis_y": unit.transform.y,
		"visible": unit.visible, "self_modulate": unit.self_modulate, "z_index": unit.z_index,
		"z_as_relative": unit.z_as_relative, "show_behind_parent": unit.show_behind_parent,
		"top_level": unit.top_level, "y_sort_enabled": unit.y_sort_enabled,
		"activation": {"mode": int(unit.process_mode), "priority": unit.process_priority,
			"physics_priority": unit.process_physics_priority, "process": unit.is_processing(),
			"physics": unit.is_physics_processing(), "input": unit.is_processing_input(),
			"shortcut": unit.is_processing_shortcut_input(), "unhandled_input": unit.is_processing_unhandled_input(),
			"unhandled_key": unit.is_processing_unhandled_key_input(), "signals_blocked": unit.is_blocking_signals()}}

func _check_activation(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _fields(value, ACTIVATION_FIELDS): return _failure("ACTIVATION_FIELDS")
	for key in ["mode", "priority", "physics_priority"]:
		if typeof(value[key]) != TYPE_INT: return _failure("ACTIVATION_INTEGER", key)
	if value.mode < 0 or value.mode > 4: return _failure("ACTIVATION_MODE")
	for key in ["priority", "physics_priority"]:
		if value[key] < -2147483648 or value[key] > 2147483647: return _failure("ACTIVATION_RANGE", key)
	for key in ["process", "physics", "input", "shortcut", "unhandled_input", "unhandled_key", "signals_blocked"]:
		if typeof(value[key]) != TYPE_BOOL: return _failure("ACTIVATION_BOOL", key)
	return {"ok": true}

func _check_node(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _fields(value, NODE_FIELDS): return _failure("NODE_FIELDS")
	if typeof(value.name) != TYPE_STRING or value.name.length() > 256: return _failure("NODE_NAME")
	for key in ["basis_x", "basis_y"]:
		if typeof(value[key]) != TYPE_VECTOR2 or not value[key].is_finite(): return _failure("NODE_TRANSFORM", key)
	for key in ["visible", "z_as_relative", "show_behind_parent", "top_level", "y_sort_enabled"]:
		if typeof(value[key]) != TYPE_BOOL: return _failure("NODE_BOOL", key)
	if typeof(value.z_index) != TYPE_INT or value.z_index < -4096 or value.z_index > 4096: return _failure("NODE_Z")
	if typeof(value.self_modulate) != TYPE_COLOR: return _failure("NODE_COLOR")
	for part in [value.self_modulate.r, value.self_modulate.g, value.self_modulate.b, value.self_modulate.a]:
		if not is_finite(part): return _failure("NODE_COLOR")
	return _check_activation(value.activation)

func _read_inventory(unit: Variant) -> Dictionary:
	var inv: Variant = unit.inventory
	if inv == null: return {"ok": true, "value": null}
	if typeof(inv) != TYPE_OBJECT or not is_instance_valid(inv) or inv.get_script() != _inventory_script:
		return _failure("INVENTORY_INSTANCE")
	if not is_same(inv.owner, unit): return _failure("INVENTORY_OWNER")
	var values: Dictionary = {"slots": inv.slots, "cooldowns": inv.cooldowns,
		"proc_cooldowns": inv.proc_cooldowns, "_uid_seq": inv._uid_seq, "_periodic_acc": inv._periodic_acc}
	var checked: Dictionary = _check_inventory(values)
	if not checked.ok: return checked
	return {"ok": true, "value": values}

func capture(unit: Variant, entity_id: String, content_version: String, object_to_id: Dictionary, encode_identity: Callable) -> Dictionary:
	if _codec == null: return _failure("MODULE_CONFIGURATION")
	if not _version(content_version): return _failure("CONTENT_VERSION")
	if not _unit(unit): return _failure("UNIT_INSTANCE")
	var registry: Dictionary = _registry(object_to_id)
	if not registry.ok: return registry
	if not object_to_id.has(unit) or object_to_id[unit] != entity_id: return _failure("SUBJECT_ID")
	var values: Dictionary = _read_explicit(unit)
	var checked: Dictionary = _check_values(values)
	if not checked.ok: return checked
	var references: Dictionary = _references(_read_references(unit), object_to_id, true)
	if not references.ok: return references
	var identities: Dictionary = _identities(
		{"_lin_spear_target_id": unit._lin_spear_target_id, "_chase_last_id": unit._chase_last_id, "_giveup_id": unit._giveup_id},
		{"_aura_atkspeed_sources": unit._aura_atkspeed_sources, "_damage_reduction_sources": unit._damage_reduction_sources}, encode_identity, "capture")
	if not identities.ok: return identities
	var metadata: Dictionary = _read_metadata(unit)
	if not metadata.ok: return metadata
	var inventory: Dictionary = _read_inventory(unit)
	if not inventory.ok: return inventory
	var node: Dictionary = _read_node(unit)
	checked = _check_node(node)
	if not checked.ok: return checked
	# Preserve null inventory exactly, including unusual externally created heroes.
	var payload: Dictionary = {"values": _to_wire(values), "references": references.values, "ids": identities.ids,
		"pools": identities.pools, "inventory": inventory.value, "metadata": metadata.value, "node": node}
	var encoded: Dictionary = _codec.encode(payload)
	if not encoded.ok: return _failure("CODEC_" + String(encoded.code), String(encoded.get("path", "")))
	return {"ok": true, "record": {"schema": SCHEMA, "content_version": content_version, "entity_id": entity_id, "payload": encoded.value}}

func validate(record: Variant, content_version: String, known_ids: Dictionary, validate_identity: Callable) -> Dictionary:
	if _codec == null: return _failure("MODULE_CONFIGURATION")
	if not _version(content_version): return _failure("CONTENT_VERSION")
	if typeof(record) != TYPE_DICTIONARY or not _fields(record, ["schema", "content_version", "entity_id", "payload"]): return _failure("RECORD_FIELDS")
	if typeof(record.schema) != TYPE_STRING or record.schema != SCHEMA: return _failure("SCHEMA")
	if typeof(record.content_version) != TYPE_STRING or record.content_version != content_version: return _failure("CONTENT_VERSION")
	var checked: Dictionary = _known_ids(known_ids)
	if not checked.ok: return checked
	if not _id(record.entity_id) or not known_ids.has(record.entity_id): return _failure("SUBJECT_ID")
	var decoded: Dictionary = _codec.decode(record.payload)
	if not decoded.ok: return _failure("CODEC_" + String(decoded.code), String(decoded.get("path", "")))
	var payload: Variant = decoded.value
	if typeof(payload) != TYPE_DICTIONARY or not _fields(payload, ["values", "references", "ids", "pools", "inventory", "metadata", "node"]): return _failure("PAYLOAD_FIELDS")
	if typeof(payload.values) != TYPE_DICTIONARY: return _failure("VALUE_FIELDS")
	var values: Dictionary = _from_wire(payload.values)
	if not values.ok: return values
	checked = _check_values(values.values)
	if not checked.ok: return checked
	var references: Dictionary = _references(payload.references, known_ids, false)
	if not references.ok: return references
	var identities: Dictionary = _identities(payload.ids, payload.pools, validate_identity, "validate")
	if not identities.ok: return identities
	if payload.inventory != null:
		if typeof(payload.inventory) != TYPE_DICTIONARY: return _failure("INVENTORY_FIELDS")
		checked = _check_inventory(payload.inventory)
		if not checked.ok: return checked
	var metadata: Dictionary = _check_metadata(payload.metadata)
	if not metadata.ok: return metadata
	checked = _check_node(payload.node)
	if not checked.ok: return checked
	return {"ok": true, "entity_id": record.entity_id, "values": values.values, "references": references.values,
		"ids": identities.ids, "pools": identities.pools, "inventory": payload.inventory, "metadata": metadata.value, "node": payload.node}

func instantiate(record: Variant, content_version: String, known_ids: Dictionary, validate_identity: Callable) -> Dictionary:
	var state: Dictionary = validate(record, content_version, known_ids, validate_identity)
	if not state.ok: return state
	# No setter sees a Battle, map, parent, signal listener or live simulation.
	var unit: Variant = _unit_script.new()
	unit.set_block_signals(true)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	_assign_values(unit, state.values)
	var node: Dictionary = state.node
	if not node.name.is_empty(): unit.name = node.name
	unit.transform = Transform2D(node.basis_x, node.basis_y, state.values.position)
	unit.visible = node.visible
	unit.self_modulate = node.self_modulate
	unit.z_index = node.z_index
	unit.z_as_relative = node.z_as_relative
	unit.show_behind_parent = node.show_behind_parent
	unit.top_level = node.top_level
	unit.y_sort_enabled = node.y_sort_enabled
	for key in state.metadata: unit.set_meta(StringName(key), state.metadata[key])
	if state.inventory != null:
		var inv: Variant = _inventory_script.new(unit)
		inv.slots = state.inventory.slots
		inv.cooldowns = state.inventory.cooldowns
		inv.proc_cooldowns = state.inventory.proc_cooldowns
		inv._uid_seq = state.inventory._uid_seq
		inv._periodic_acc = state.inventory._periodic_acc
		unit.inventory = inv
	return {"ok": true, "unit": unit, "entity_id": state.entity_id, "activation": node.activation,
		"pending_bind_fields": FIELDS + ID_FIELDS + POOL_FIELDS + ["battle", "map"], "bound": false}

func _resolve_tag(tag: Dictionary, units: Dictionary, expired_unit: Variant) -> Variant:
	match tag.state:
		"entity": return units[tag.id]
		"expired": return expired_unit
	return null

func _expired_count(refs: Dictionary) -> int:
	var count: int = 0
	for field in DIRECT_FIELDS:
		if refs[field].state == "expired": count += 1
	for field in ARRAY_FIELDS:
		for tag in refs[field]:
			if tag.state == "expired": count += 1
	for order in refs._queue:
		if order.has("target") and order.target.state == "expired": count += 1
	return count

# expired_unit MUST still be alive and detached here. Caller frees all tombstones
# only AFTER binding every Unit/Effect/Battle field, while the whole run is paused.
# We never assign an already freed object into a typed Unit property.
func bind(unit: Variant, record: Variant, content_version: String, id_to_unit: Dictionary,
		battle: Variant, game_map: Variant, decode_identity: Callable, validate_identity: Callable,
		expired_unit: Variant = null) -> Dictionary:
	if not _unit(unit) or unit.get_parent() != null or unit.is_inside_tree() or not unit.is_blocking_signals() or unit.process_mode != Node.PROCESS_MODE_DISABLED:
		return _failure("SHELL_NOT_DETACHED_DISABLED")
	var known: Dictionary = {}
	var seen: Dictionary = {}
	for key in id_to_unit:
		if not _id(key) or not _unit(id_to_unit[key]): return _failure("BIND_REGISTRY")
		if seen.has(id_to_unit[key]): return _failure("BIND_DUPLICATE_OBJECT")
		seen[id_to_unit[key]] = true
		known[key] = true
	var state: Dictionary = validate(record, content_version, known, validate_identity)
	if not state.ok: return state
	if not is_same(id_to_unit[state.entity_id], unit): return _failure("BIND_SUBJECT")
	if typeof(battle) != TYPE_OBJECT or not is_instance_valid(battle): return _failure("BATTLE_REQUIRED")
	if typeof(game_map) != TYPE_OBJECT or not is_instance_valid(game_map): return _failure("MAP_REQUIRED")
	var map_script: Variant = game_map.get_script()
	if map_script == null or map_script.get_global_name() != &"GameMap": return _failure("MAP_TYPE")
	var count: int = _expired_count(state.references)
	if count > 0:
		if not _unit(expired_unit) or expired_unit.is_inside_tree() or expired_unit.get_parent() != null or seen.has(expired_unit):
			return _failure("LIVE_DETACHED_TOMBSTONE_REQUIRED")
	var identities: Dictionary = _identities(state.ids, state.pools, decode_identity, "decode")
	if not identities.ok: return identities
	# All failure-returning validation/remapping finishes before the first assignment.
	var refs: Dictionary = {}
	for field in DIRECT_FIELDS: refs[field] = _resolve_tag(state.references[field], id_to_unit, expired_unit)
	for field in ARRAY_FIELDS:
		var entries: Array = []
		for tag in state.references[field]: entries.append(_resolve_tag(tag, id_to_unit, expired_unit))
		refs[field] = entries
	var orders: Array = []
	for encoded_order in state.references._queue:
		var order: Dictionary = encoded_order.duplicate(true)
		if order.has("target"): order["target"] = _resolve_tag(order.target, id_to_unit, expired_unit)
		orders.append(order)
	refs["_queue"] = orders
	_assign_references(unit, refs)
	unit._lin_spear_target_id = identities.ids._lin_spear_target_id
	unit._chase_last_id = identities.ids._chase_last_id
	unit._giveup_id = identities.ids._giveup_id
	unit._aura_atkspeed_sources = identities.pools._aura_atkspeed_sources
	unit._damage_reduction_sources = identities.pools._damage_reduction_sources
	unit.battle = battle
	unit.map = game_map
	return {"ok": true, "bound": true, "expired_bindings": count, "activation": state.node.activation,
		"tombstone_release_owned_by_caller": true}

# Call only after root has attached all nodes in saved order, installed every
# graph and signal connection, freed tombstones, and restored RNG. Tree must
# remain paused until ALL Units/Effects/Battle are released by the transaction.
func activate(unit: Variant, activation: Dictionary) -> Dictionary:
	if not _unit(unit): return _failure("UNIT_INSTANCE")
	var checked: Dictionary = _check_activation(activation)
	if not checked.ok: return checked
	if not unit.is_inside_tree() or not unit.get_tree().paused: return _failure("ACTIVATION_REQUIRES_PAUSED_TREE")
	unit.process_priority = activation.priority
	unit.process_physics_priority = activation.physics_priority
	unit.set_process(activation.process)
	unit.set_physics_process(activation.physics)
	unit.set_process_input(activation.input)
	unit.set_process_shortcut_input(activation.shortcut)
	unit.set_process_unhandled_input(activation.unhandled_input)
	unit.set_process_unhandled_key_input(activation.unhandled_key)
	unit.set_block_signals(activation.signals_blocked)
	unit.process_mode = activation.mode
	return {"ok": true}

func _assign_references(unit: Variant, refs: Dictionary) -> void:
	unit.story_assist_partner = refs["story_assist_partner"]
	unit.story_assist_owner = refs["story_assist_owner"]
	unit._gold_miner = refs["_gold_miner"]
	unit._gold_waiters = refs["_gold_waiters"]
	unit._gather_node = refs["_gather_node"]
	unit._drop = refs["_drop"]
	unit._build_site = refs["_build_site"]
	unit.garrison_holder = refs["garrison_holder"]
	unit._garrison_dest = refs["_garrison_dest"]
	unit.passengers = refs["passengers"]
	unit.rally_node = refs["rally_node"]
	unit._taunt_src = refs["_taunt_src"]
	unit._hua_lock_target = refs["_hua_lock_target"]
	unit._target = refs["_target"]
	unit._pending_target = refs["_pending_target"]
	unit._killer = refs["_killer"]
	unit._queue = refs["_queue"]
	unit._charge_hit = refs["_charge_hit"]
