extends "terminal.gd"
const Policy := preload("policy.gd")
var policy: RefCounted
var next_economy_tick := 0
var combat_samples: Array = []

func run() -> void:
	while Engine.is_in_physics_frame(): await get_tree().process_frame
	mode = OS.get_environment("LT_MODE")
	var profile: String = OS.get_environment("LT_PROFILE").replace("\\", "/").simplify_path()
	var project: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var safe: bool = profile.is_absolute_path() and mode in MODES and OS.get_environment("STEAM_DISABLED") == "1" \
		and OS.get_environment("CAMPAIGN_QA").is_empty() and OS.get_environment("LSH_CONTINUE_FLOW_QA") == "1" \
		and OS.get_environment("LSH_CONTINUE_FLOW_PROFILE").replace("\\", "/").simplify_path() == profile \
		and Intent.hex(OS.get_environment("LT_PROCESS_NONCE"), 32)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		safe = safe and OS.get_environment(key).replace("\\", "/").simplify_path().to_lower() == profile.path_join(key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(profile.path_join("appdata").to_lower() + "/") \
		and project.to_lower() == OS.get_environment("LT_PROJECT").replace("\\", "/").to_lower()
	if not safe: push_error("LIAN_PRIVATE_PROFILE_REQUIRED"); get_tree().quit(2); return
	check(true, "real source project and four private profile roots with Steam disabled and QA suppression absent")
	check(DisplayServer.get_name() != "headless", "actual GL display is active")
	trusted = Provider.new().resolve_runtime_identity()
	if not check(trusted.get("ok", false) and trusted.get("save_eligible", false) and trusted.get("source_mode", false), "actual source runtime identity"): finish(); return
	if not check(Lifecycle.CAMPAIGN_SCHEMA == "local_campaign_continue_lifecycle_v3" and Intent.CONTRACTS.level4.version == 2,
		"current candidate lifecycle v3 and Level4 contract2 only"): finish(); return
	var pack: Dictionary = Factory.prepare_runtime(trusted)
	if not check(pack.get("ok", false) and not pack.get("deploy_or_start_called", true), "installed Level4 factory prepares without deployment"): finish(); return
	runtime = pack.runtime
	if not await wait_for_startup(): finish(); return
	flow = get_node("/root/ContinueFlow")
	if not check(flow.is_enabled() and flow._private_qa_enabled(), "actual private Flow UI entry is enabled without public campaign release"): finish(); return
	flow.operation_finished.connect(on_flow_operation)
	get_node("/root/Localize").set_language("zh_CN", false)
	var settings: Node = get_node("/root/Settings")
	settings.game_speed = 1.0; settings.auto_micro_level = 0; settings.edge_scroll = false
	if mode == "save_training":
		await first_process()
	elif read_predecessor():
		if mode in ["resume_training", "resume_victory"]:
			if await restore_same_slot():
				if mode == "resume_training": await complete_training()
				else:
					check(producer._train_queue.is_empty() and producer._train_t == 0.0 and new_ids() == [training.new_unit_id],
						"second independent Continue retains exactly one already completed paid soldier")
					if failures.is_empty(): await natural_victory()
		else:
			await reject_terminal()
	if save_exit_owned: return
	finish()

func alive(unit: Variant) -> bool:
	return is_instance_valid(unit) and unit.hp > 0.0 and unit.story_outcome == ""

func simulation_ok() -> bool:
	return is_instance_valid(battle) and battle.gameplay_rng_fault().is_empty() \
		and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60

func record_action(kind: String, actors: Array, detail: Dictionary = {}) -> void:
	var ids: Array = []
	for actor: Variant in actors:
		if is_instance_valid(actor): ids.append(str(actor.entity_id))
	action_evidence.append({"kind":kind, "actor_entity_ids":ids, "tick":battle._run_clock._next_tick, "detail":detail.duplicate(true)})

func economy_step() -> void:
	if battle._run_clock._next_tick < next_economy_tick: return
	next_economy_tick = battle._run_clock._next_tick + 75
	policy._economy_lhm(battle)

func wait_live(predicate: Callable, seconds: float) -> bool:
	var limit: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not predicate.call() and Time.get_ticks_msec() < limit and simulation_ok() and battle.phase == B.Phase.FIGHT and failures.is_empty():
		economy_step()
		await get_tree().process_frame
	return bool(predicate.call()) and simulation_ok() and battle.phase == B.Phase.FIGHT and failures.is_empty()

func stance_command(unit: Variant, wanted: int) -> void:
	if not alive(unit): check(false, "stance recipient remains alive"); return
	for count: int in range(4):
		if unit.stance == wanted: return
		battle.select_members([unit], false)
		battle._cycle_stance()
		record_action("cycle_stance", [unit], {"resulting_stance":unit.stance})
	check(unit.stance == wanted, "ordinary stance cycle reaches requested stance")

func natural_drill() -> bool:
	var level: Variant = battle.level
	var hooks: Array = battle.units.filter(func(u): return alive(u) and str(u.entity_id) == training.new_unit_id)
	var lures: Array = battle.units.filter(func(u): return alive(u) and u.faction == 0 and u.key == "liang_qiang")
	if not check(alive(level.xu) and hooks.size() == 1 and not lures.is_empty(), "real instructor, newly paid hook soldier and ordinary lure available"): return false
	var hook: Variant = hooks[0]
	var lure: Variant = lures[0]
	var instructor: Variant = level.xu
	var old_stances: Array = [instructor.stance, hook.stance, lure.stance]
	for actor: Variant in [instructor, hook, lure]: stance_command(actor, actor.STANCE_PASSIVE)
	# These actors receive only drill orders until completion. Economy continues;
	# no whole-army order, enemy pause, geometry assignment or early damage.
	policy.move(battle, [hook], level.DRILL + Vector2i(-2, -2))
	# Stage the lure outside trigger range while Xu Ning sets up the drill.
	var staging_cell: Vector2i = level.DRILL_ENTRY + Vector2i(-4, -4)
	var staging_position: Vector2 = battle.map.cell_to_world(staging_cell)
	policy.move(battle, [lure], staging_cell)
	policy.move(battle, [instructor], battle.mission.actions.lhm_drill_reset.cell)
	if not check(await wait_live(func(): return alive(level.dummy), 80.0), "instructor walks to actual mission action and completes one-second setup"): return false
	check(battle.mission.actions.lhm_drill_reset.actors.has("xu_ning") and not level.drill_complete \
		and not level.drill_entered, "authored practice starts without pre-awarded goal")
	if not check(await wait_live(func(): return alive(lure) and lure.position.distance_to(staging_position) <= 32.0, 85.0), "ordinary lure reaches the staging lane outside trigger range"): return false
	var dummy_id: String = str(level.dummy.entity_id)
	policy.move(battle, [lure], level.DRILL_ENTRY + Vector2i(0, 2))
	if not check(await wait_live(func(): return level.drill_entered and level.drill_lure == lure, 55.0), "ordinary non-hook infantry actually enters lure radius"): return false
	var entered_origin: Vector2 = level.drill_lure_origin
	policy.move(battle, [lure], level.DRILL + Vector2i(-5, 1))
	if not check(await wait_live(func(): return level.drill_withdrew, 55.0), "same lure actually withdraws west behind the hook line"): return false
	check(lure.position.distance_to(entered_origin) > 80.0 and lure.position.distance_to(level.dummy.position) > 128.0 \
		and lure.position.x < float(level.DRILL.x - 1) * 32.0, "observed real retreat satisfies all production geometry conditions")
	# Clicking within the reset flag's radius would order Xu Ning to set up a
	# replacement dummy. Approach from the east using ordinary open map cells.
	var reset_action: Dictionary = battle.mission.actions.lhm_drill_reset
	var reset_center: Vector2 = battle.map.cell_to_world(reset_action.cell)
	var approach_cells: Array = [level.DRILL + Vector2i(1, 0), level.DRILL + Vector2i(1, -1)]
	var approach_actors: Array = [instructor, hook]
	for index: int in range(approach_cells.size()):
		var approach: Vector2 = battle.map.cell_to_world(approach_cells[index])
		if not check(battle.map.is_open_cell(approach_cells[index], approach_actors[index].movement_profile) \
			and approach.distance_to(reset_center) > float(reset_action.click_reach) \
			and approach.distance_to(battle.map.cell_to_world(level.DRILL)) <= 88.0,
			"ordinary drill approach is open, near the dummy destination and outside reset click radius"): return false
		policy.move(battle, [approach_actors[index]], approach_cells[index])
	if not check(await wait_live(func(): return alive(level.dummy) and instructor.position.distance_to(level.dummy.position) <= 88.0 \
		and hook.position.distance_to(level.dummy.position) <= 88.0, 45.0), "both passive hooks walk into real melee approach"): return false
	check(not level.drill_coordinated and not level.drill_complete and str(level.dummy.entity_id) == dummy_id,
		"same live dummy and passive proximity do not fabricate coordinated hit")
	policy.target(battle, [instructor, hook], level.dummy, "drill_attack")
	if not check(await wait_live(func(): return level.drill_complete, 45.0), "real two-person attacks complete optional teaching"): return false
	check(level.drill_entered and level.drill_withdrew and level.drill_coordinated \
		and battle.mission.has_event("lhm_drill_complete") and battle.mission.actions.lhm_drill_reset.done,
		"actual teaching event and mission action close naturally")
	observations["natural_drill"] = {"instructor_id":str(instructor.entity_id), "hook_id":str(hook.entity_id),
		"lure_id":str(lure.entity_id), "dummy_id":dummy_id, "lure_origin":entered_origin,
		"lure_retreat":lure.position, "completed_tick":battle._run_clock._next_tick}
	var actors: Array = [instructor, hook, lure]
	for index: int in range(actors.size()): stance_command(actors[index], int(old_stances[index]))
	return failures.is_empty()

func natural_victory() -> void:
	var level: Variant = battle.level
	var original_receipt: Variant = battle._continue_receipt
	var original_hall: Variant = level.hall
	var original_song: Variant = level.song
	var rider_ids: Array = []
	for rider: Variant in level.riders:
		if is_instance_valid(rider): rider_ids.append(str(rider.entity_id))
	check(checkpoint.generation == 2 and rider_ids.size() == 12 and level.lhm_killed == 0,
		"resave precedes combat and retains twelve original riders")
	if not failures.is_empty(): return
	policy = Policy.new(self)
	if not press_button(battle.hud._pause_resume_button, "resume completed training save for natural Level4 battle"): return
	policy.garrison(battle, [level.song], level.hall)
	if not check(await wait_live(func(): return level.song.garrisoned, 30.0), "commander enters original camp by ordinary garrison command"): return
	if not await natural_drill(): return
	var lane: String = "north"
	var assault_ready: bool = false
	var limit: int = Time.get_ticks_msec() + 1000000
	var next_sample_tick: int = 0
	var dump_kill_once: bool = false
	var previous_hall_hp: float = level.hall.hp
	var next_hall_repair_tick: int = 0
	var next_hall_pressure_log: int = 0
	original_hall.died.connect(func(destroyed):
		var killer: Variant = destroyed._killer
		print("LIAN_HALL_LOST ", {"elapsed":level.elapsed, "killer_id":str(killer.entity_id) if is_instance_valid(killer) else "",
			"killer_key":killer.key if is_instance_valid(killer) else "", "source":destroyed._killer_source_id}))
	while battle.phase == B.Phase.FIGHT and Time.get_ticks_msec() < limit and simulation_ok() and failures.is_empty():
		economy_step()
		if not dump_kill_once:
			var dump_reason: String = ""
			if battle.mission.has_event("lhm_direct_break"):
				dump_reason = "lhm_direct_break"
			elif not alive(level.hall) or (is_instance_valid(level.hall) and float(level.hall.hp) < 50.0):
				for _r in level.riders:
					if not is_instance_valid(_r): continue
					if bool(_r.get_meta("formation_broken", false)): continue
					dump_reason = "hall_collapse"
					break
			if dump_reason == "":
				for _r in level.riders:
					if not is_instance_valid(_r): continue
					if alive(_r): continue
					if bool(_r.get_meta("formation_broken", false)): continue
					dump_reason = "unbroken_rider_dead"
					break
			if dump_reason != "":
				dump_kill_once = true
				for rider in level.riders:
					if not is_instance_valid(rider): continue
					if bool(rider.get_meta("formation_broken", false)): continue
					# hall_collapse: dump all non-broken; other paths: dead non-broken only
					if dump_reason != "hall_collapse" and alive(rider): continue
					var killer: Variant = rider._killer
					print("LIAN_DIRECT_KILL ", {
						"elapsed": level.elapsed,
						"tick": battle._run_clock._next_tick,
						"source": dump_reason,
						"victim_id": str(rider.entity_id),
						"victim_key": rider.key,
						"victim_wave": int(rider.get_meta("wave_group")),
						"victim_hp": rider.hp,
						"killer_valid": is_instance_valid(killer),
						"killer_id": str(killer.entity_id) if is_instance_valid(killer) else "",
						"killer_key": killer.key if is_instance_valid(killer) else "",
						"killer_faction": killer.faction if is_instance_valid(killer) else -1,
						"killer_source_id": rider._killer_source_id,
					})
				if dump_reason == "lhm_direct_break":
					check(false,"original all-hook objective is irreversibly missed; stop failed strategy early")
					break
		var army: Array = battle.units.filter(func(u): return alive(u) and u.faction == 0 and u != level.song \
			and not u.is_worker and not u.is_building and not u.is_noncombat and not u.garrisoned)
		var cell: Vector2i = level.LANES[0]
		var target: Variant = null
		var attack_move: bool = true
		# Prefer any wave that still has unbroken riders so hooks redeploy south
		# before north leftovers make may_attack true and miss the south reed choke.
		var unbroken_north: Array = level.riders.filter(func(u): return alive(u) and int(u.get_meta("wave_group")) == 0 and not bool(u.get_meta("formation_broken", false)))
		var unbroken_south: Array = level.riders.filter(func(u): return alive(u) and int(u.get_meta("wave_group")) == 1 and not bool(u.get_meta("formation_broken", false)))
		if not unbroken_north.is_empty(): lane = "north"
		elif not unbroken_south.is_empty(): lane = "south"
		elif level.riders.filter(func(u): return alive(u) and int(u.get_meta("wave_group")) == 0).is_empty(): lane = "south"
		if level.lhm_killed >= 12: lane = "counter"
		if lane == "south": cell = level.LANES[1]
		if lane == "counter":
			# v22: readiness, waves and target order live in the v22 counter block.
			assault_ready = bool(get_meta("v22_launched", false))
			cell = level.ENEMY_CAMP
		# Read the real rider metadata. Ordinary troops wait while any unbroken
		# rider remains; hook soldiers stage at the active wave reed choke.
		var wave_index: int = 0 if lane == "north" else 1
		var unbroken: Array = unbroken_north if wave_index == 0 else unbroken_south
		var may_attack: bool = level.lhm_killed >= 12 or (unbroken_north.is_empty() and unbroken_south.is_empty())
		var hooks: Array = army.filter(func(u): return u.key in level.HOOK_KEYS)
		var nonhooks: Array = army.filter(func(u): return u.key not in level.HOOK_KEYS)
		# v21 (external strategy only): hooks move as ONE pack, never a lone peel.
		# Root cause v19/v20: policy.move(hooks, cell_of(rider)) is an ordinary
		# right-click; Battle._issue_order resolves _enemy_at(p) to an explicit
		# order_attack, so a "PASSIVE move to rider" was a lone attack (gou_lian
		# #129/#130 killed unbroken #46 -> lhm_direct_break). v21 never right-clicks
		# a point that resolves to an enemy and only attacks when the production
		# break predicate (level4 _rider_tick) is already satisfiable this tick.
		var hook_target: Variant = null
		var approach_rider: Variant = null
		var choke_pos: Vector2 = battle.map.cell_to_world(cell)
		if not may_attack:
			for rider in unbroken:
				if not rider.fog_visible: continue
				if approach_rider == null or rider.position.distance_to(choke_pos) < approach_rider.position.distance_to(choke_pos):
					approach_rider = rider
				if battle.map.t_world(rider.position) not in [level.T.REEDS, level.T.MARSH] and rider.temp_speed >= 0.8: continue
				var team_n: int = level._hook_team(battle, rider).size()
				var best_n: int = level._hook_team(battle, hook_target).size() if hook_target != null else -1
				if hook_target == null or team_n > best_n or (team_n == best_n and rider.position.distance_to(choke_pos) < hook_target.position.distance_to(choke_pos)):
					hook_target = rider
		var unbroken_near_hall: bool = false
		for rider in unbroken_north + unbroken_south:
			if alive(rider) and rider.position.distance_to(level.hall.position) <= 420.0:
				unbroken_near_hall = true
		var approach_in_pack: bool = approach_rider != null and approach_rider.position.distance_to(choke_pos) <= 420.0
		# --- v21 helpers -------------------------------------------------------
		var enemy_click: Callable = func(pt: Vector2, rad: float) -> bool:
			for e in battle.units:
				if alive(e) and e.faction == 1 and not e.is_building and e.position.distance_to(pt) <= rad: return true
			return battle._enemy_at(battle.to_screen(pt)) != null
		var safe_cell: Callable = func(c: Vector2i, rad: float) -> bool:
			var w: Vector2 = battle.map.cell_to_world(c)
			if not battle.map.is_open_cell(c, "land"): return false
			if enemy_click.call(w, rad): return false
			return battle._garrisonable_at(battle.to_screen(w)) == null
		# Mirror of level4 _rider_tick: impeded AND >=2 _hook_team members already
		# inside atk_range+radii+8 of the rider.
		var break_ready: Callable = func(r: Variant) -> bool:
			if r == null or not alive(r) or bool(r.get_meta("formation_broken", false)): return false
			if battle.map.t_world(r.position) not in [level.T.REEDS, level.T.MARSH] and r.temp_speed >= 0.8: return false
			var team: Array = level._hook_team(battle, r)
			if team.size() < 2: return false
			var close_n: int = team.filter(func(h): return h.position.distance_to(r.position) <= h.atk_range + h.radius + r.radius + 8.0).size()
			# Exact level4 mirror is team>=2 & >=1 in melee range; a low rider
			# (<=35%) additionally needs >=2 hooks in range (no lethal-before-break).
			if r.hp <= r.max_hp * 0.35: return close_n >= 2
			return close_n >= 1
		var hold_cell: Vector2i = Vector2i(7, 30)
		for c in [Vector2i(7, 30), Vector2i(7, 32), Vector2i(7, 28), Vector2i(8, 34), Vector2i(8, 26), Vector2i(6, 31)]:
			if safe_cell.call(c, 64.0):
				hold_cell = c
				break
		# xu_ning is the only castable hero (Song is garrisoned); v20 lost him at
		# ~164s so skill_orders froze at 1. Pull him out when hurt.
		var retreat: Array = hooks.filter(func(h): return h.is_hero and h.hp < h.max_hp * 0.4)
		var pack: Array = hooks.filter(func(h): return h not in retreat)
		# Core = densest sub-group (members within 96px of the best anchor).
		var core: Array = []
		for anchor in pack:
			var group: Array = pack.filter(func(h): return h.position.distance_to(anchor.position) <= 96.0)
			if group.size() > core.size(): core = group
		var stragglers: Array = pack.filter(func(h): return h not in core)
		var core_center: Vector2 = Vector2.ZERO
		for h in core: core_center += h.position
		if not core.is_empty(): core_center /= float(core.size())
		var core_spread: float = 0.0
		for h in core: core_spread = maxf(core_spread, h.position.distance_to(core_center))
		var pack_limit: float = 48.0 if core.size() <= 3 else 72.0
		var pack_together: bool = core.size() >= 2 and core_spread <= pack_limit
		var ready_target: Variant = null
		if not may_attack:
			if break_ready.call(hook_target): ready_target = hook_target
			else:
				for rider in unbroken_north + unbroken_south:
					if rider.fog_visible and break_ready.call(rider):
						ready_target = rider
						break
		var south_phase: bool = unbroken_north.is_empty() and not unbroken_south.is_empty()
		var selected_before: Array = battle.selection.duplicate()
		# v21 stance: hooks PASSIVE for the whole unbroken phase (no auto-acquire
		# of unbroken riders); explicit coordinated target only when break_ready.
		for soldier in hooks:
			stance_command(soldier, soldier.STANCE_AGGRO if may_attack else soldier.STANCE_PASSIVE)
		# v11/v17: every non-hook passive for the whole unbroken phase.
		for soldier in nonhooks:
			stance_command(soldier, soldier.STANCE_PASSIVE if not may_attack else soldier.STANCE_AGGRO)
		battle.select_members(selected_before, false)
		if may_attack and lane == "counter":
			# ---- v22 counter-attack (lane == "counter"; hook phase is over) ----
			# Victory (level4 process): manor_fallen and lhm_killed>=12 -> b.win and
			# Hu resolve_story("retreated") => lhm_hu_fled is automatic. lhm_han_captured
			# is NOT automatic and the battle ends on manor fall, so Han must be captured
			# (han.defeat_outcome="captured" on hp<=0) BEFORE rams raze the manor.
			var rams: Array = army.filter(func(u): return u.key == "siege_ram")
			# v22 economy: home gold mines (2x2400, exclusive) run dry ~700s; staff
			# safe far mines with one worker each, and keep rams funded first.
			if battle._run_clock._next_tick >= int(get_meta("v22_econ_tick", 0)):
				set_meta("v22_econ_tick", battle._run_clock._next_tick + 150)
				var mines: Array = battle.units.filter(func(u): return is_instance_valid(u) and u.is_resource and u.res_kind == "gold" and u.res_left > 0.0)
				var home_gold: Array = mines.filter(func(m): return m.position.distance_to(level.hall.position) <= 520.0)
				var workers_all: Array = battle.units.filter(func(u): return alive(u) and u.faction == 0 and u.is_worker)
				if home_gold.is_empty() or home_gold.all(func(m): return m.res_left < 200.0):
					for m in mines:
						if m in home_gold: continue
						if battle.units.any(func(e): return alive(e) and e.faction == 1 and not e.is_building and e.position.distance_to(m.position) <= 200.0): continue
						if workers_all.any(func(w): return is_instance_valid(w._gather_node) and w._gather_node == m): continue
						var pick: Variant = null
						for w in workers_all:
							if w._state == 6: continue
							if is_instance_valid(w._gather_node) and w._gather_node.res_kind == "gold" and w._gather_node.res_left > 0.0: continue
							pick = w
							break
						if pick != null:
							battle.select_single(pick, false)
							battle._issue_order(battle.to_screen(m.position), false)
							policy.orders += 1
							record_action("gather", [pick], {"target_entity_id":str(m.entity_id), "purpose":"v22_far_gold"})
				var shop: Variant = null
				for bld in battle.units:
					if alive(bld) and bld.faction == 0 and bld.key == "siege_workshop" and not bld.is_constructing:
						shop = bld
						break
				if shop != null and alive(level.enemy_base) and shop._train_queue.is_empty() and rams.size() < 3 and battle.gold >= 70 and battle.wood >= 90:
					var g0: int = battle.gold
					var w0: int = battle.wood
					if battle.queue_train(shop, "siege_ram", false):
						record_action("train", [shop], {"key":"siege_ram", "gold_spent":g0-battle.gold, "wood_spent":w0-battle.wood, "purpose":"v22_ram_budget"})
			# Hall guards only while an enemy is actually near the hall.
			var hall_threat: Variant = null
			for e in battle.units:
				if not alive(e) or e.faction != 1 or e.is_building or not e.fog_visible: continue
				if e.position.distance_to(level.hall.position) > 420.0: continue
				if hall_threat == null or e.position.distance_to(level.hall.position) < hall_threat.position.distance_to(level.hall.position):
					hall_threat = e
			var guard: Array = []
			if hall_threat != null:
				var cands: Array = army.filter(func(u): return u.key != "siege_ram" and not u.is_hero)
				cands.sort_custom(func(a, z): return a.position.distance_to(level.hall.position) < z.position.distance_to(level.hall.position))
				for u in cands:
					if guard.size() >= 4: break
					guard.append(u)
				if not guard.is_empty(): policy.target(battle, guard, hall_threat, "v22_hall_guard")
			var strike: Array = army.filter(func(u): return u not in guard)
			var nonram: Array = strike.filter(func(u): return u.key != "siege_ram")
			var srams: Array = strike.filter(func(u): return u.key == "siege_ram")
			# v25: rally further west (>=18 cells from the enemy camp at (54,30)).
			var rally: Vector2i = Vector2i(28, 30)
			for c in [Vector2i(28, 30), Vector2i(27, 31), Vector2i(26, 29), Vector2i(25, 30), Vector2i(24, 31)]:
				var cw: Vector2 = battle.map.cell_to_world(c)
				if not battle.map.is_open_cell(c, "land"): continue
				if battle.units.any(func(e): return alive(e) and e.faction == 1 and not e.is_building and e.position.distance_to(cw) <= 160.0): continue
				if battle._enemy_at(battle.to_screen(cw)) != null: continue
				rally = c
				break
			var rally_w: Vector2 = battle.map.cell_to_world(rally)
			set_meta("v25_rally", rally)
			var base_alive: bool = alive(level.enemy_base)
			var han_captured: bool = battle.mission.has_event("lhm_han_captured")
			var wave: int = int(get_meta("v22_wave", 0))
			var launched: bool = bool(get_meta("v22_launched", false))
			var s_center: Vector2 = Vector2.ZERO
			for u in strike: s_center += u.position
			if not strike.is_empty(): s_center /= float(strike.size())
			# v24: any ram (incl. pre-placed) within building radius + ram reach + 60px
			var rams_at_manor: bool = base_alive and rams.any(func(r): return r.position.distance_to(level.enemy_base.position) <= level.enemy_base.radius + r.radius + r.atk_range + 60.0)
			if rams_at_manor and not bool(get_meta("v22_rams_reached", false)):
				set_meta("v22_rams_reached", true)
				set_meta("v22_log_rams", true)
			var finishing: bool = base_alive and han_captured and rams_at_manor and level.enemy_base.hp <= level.enemy_base.max_hp * 0.4
			var wave_info: Callable = func(ev: String, tgt: Variant) -> Dictionary:
				var comp: Dictionary = {}
				for u in strike: comp[u.key] = int(comp.get(u.key, 0)) + 1
				var han_s: String = "captured" if han_captured else (("alive_hp%d" % int(level.han.hp)) if alive(level.han) else (str(level.han.story_outcome) if is_instance_valid(level.han) else "gone"))
				var hu_s: String = ("alive_hp%d" % int(level.hu.hp)) if alive(level.hu) else (str(level.hu.story_outcome) if is_instance_valid(level.hu) else "gone")
				var ram_d: int = -1
				var ram_with: int = 0
				for r in srams:
					if not strike.is_empty() and r.position.distance_to(s_center) <= 420.0:
						ram_with += 1
					if base_alive:
						var d: int = int(r.position.distance_to(level.enemy_base.position))
						if ram_d < 0 or d < ram_d: ram_d = d
				return {"event":ev, "wave":int(get_meta("v22_wave", 0)), "elapsed":level.elapsed, "tick":battle._run_clock._next_tick,
					"strike":strike.size(), "composition":comp, "rams":srams.size(), "rams_reached_manor":bool(get_meta("v22_rams_reached", false)),
					"rams_with_strike":ram_with, "ram_d_manor":ram_d,
					"target":(str(tgt.key) + "#" + str(tgt.entity_id)) if (tgt != null and is_instance_valid(tgt)) else "",
					"han":han_s, "manor_hp":float(level.enemy_base.hp) if is_instance_valid(level.enemy_base) else 0.0, "manor_fallen":level.manor_fallen,
					"hu":hu_s, "guards":guard.size(), "army":army.size(), "rally":str(rally), "gold":battle.gold, "wood":battle.wood}
			if launched and strike.size() < 10 and not finishing:
				print("LIAN_COUNTER_WAVE ", wave_info.call("regroup", null))
				set_meta("v22_launched", false)
				launched = false
			var cur_target: Variant = null
			if not launched:
				if int(get_meta("v22_rally_since", -1)) < 0: set_meta("v22_rally_since", battle._run_clock._next_tick)
				var waited_s: float = float(battle._run_clock._next_tick - int(get_meta("v22_rally_since", 0))) / 60.0
				var rallied: Array = strike.filter(func(u): return u.position.distance_to(rally_w) <= 260.0)
				var stage_v: Variant = get_meta("v24_ram_stage") if has_meta("v24_ram_stage") else null
				var staged: Array = srams.filter(func(u): return stage_v != null and u.position.distance_to(battle.map.cell_to_world(stage_v)) <= 200.0)
				var rams_rallied: int = rallied.filter(func(u): return u.key == "siege_ram").size() + staged.size()
				var rams_ok: bool = rams_rallied >= 1 or not base_alive or (srams.is_empty() and (strike.size() >= 18 or waited_s >= 150.0))
				# v25: launch at >=18 rallied of a >=20 strike (or >=14 after 240s), never while Huyan Zhuo is near.
				if rams_ok and not bool(get_meta("v25_hu_near", false)) and ((rallied.size() >= 18 and strike.size() >= 20) or (rallied.size() >= 14 and waited_s >= 240.0)):
					wave += 1
					set_meta("v22_wave", wave)
					set_meta("v22_launched", true)
					set_meta("v22_rams_reached", false)
					set_meta("v22_rally_since", -1)
					launched = true
					print("LIAN_COUNTER_WAVE ", wave_info.call("launch", null))
				else:
					# One blob: plain move (group speed cap) to the validated rally.
					# v26: after the first launch, rams keep pressing the manor instead of walking back west.
					var press_rams: Array = []
					if base_alive and int(get_meta("v22_wave", 0)) >= 1 and not srams.is_empty():
						press_rams = srams
						policy.target(battle, press_rams, level.enemy_base, "v26_ram_manor")
					var off: Array = strike.filter(func(u): return u.position.distance_to(rally_w) > 96.0 and u not in staged and u not in press_rams)
					if not off.is_empty(): policy.move(battle, off, rally, false)
			if launched:
				var esc: Variant = null
				for e in battle.units:
					if not alive(e) or e.faction != 1 or e.is_building or not e.fog_visible: continue
					if e == level.han or e == level.hu or e in level.riders: continue
					if e.position.distance_to(s_center) > 320.0: continue
					if esc == null or e.position.distance_to(s_center) < esc.position.distance_to(s_center): esc = e
				var hu_close: bool = alive(level.hu) and level.hu.fog_visible and level.hu.position.distance_to(s_center) <= 110.0
				if esc != null:
					cur_target = esc
					policy.target(battle, nonram, esc, "v22_counter_escort")
				elif alive(level.han) and not han_captured:
					cur_target = level.han
					if level.han.fog_visible: policy.target(battle, nonram, level.han, "v22_counter_han_capture")
					else: policy.move(battle, nonram, battle.map.world_to_cell(level.han.position), true)
				elif hu_close:
					cur_target = level.hu
					policy.target(battle, nonram, level.hu, "v22_counter_hu_selfdefense")
				elif base_alive:
					cur_target = level.enemy_base
					policy.move(battle, nonram, level.ENEMY_CAMP, true)
				if not srams.is_empty():
					if base_alive:
						# v26: rams stay on the strike's eastward push and drive to the
						# manor immediately (do not wait for Han Tao's capture).
						policy.target(battle, srams, level.enemy_base, "v26_ram_manor")
					elif not strike.is_empty():
						var rc: Vector2i = battle.map.world_to_cell(s_center)
						if battle.map.is_open_cell(rc, "land") and battle._enemy_at(battle.to_screen(battle.map.cell_to_world(rc))) == null:
							policy.move(battle, srams, rc, false)
				if han_captured and not bool(get_meta("v22_log_han", false)):
					set_meta("v22_log_han", true)
					print("LIAN_COUNTER_WAVE ", wave_info.call("han_captured", cur_target))
			if bool(get_meta("v22_log_rams", false)):
				set_meta("v22_log_rams", false)
				print("LIAN_COUNTER_WAVE ", wave_info.call("rams_reached_manor", cur_target))
			if battle._run_clock._next_tick >= next_sample_tick:
				print("LIAN_COUNTER_WAVE ", wave_info.call("progress" if launched else "rally", cur_target))
		elif may_attack and level.lhm_killed < 12:
			# v28: every rider is already hook-broken (may_attack is true
			# because unbroken_north/south are empty) but at least one
			# broken rider is still alive, so lhm_killed has not reached
			# 12. lane stays off "counter"; the v21 elif may_attack body
			# would only attack-move to the south choke and leave a fogged
			# leftover uncounted (v27 batch 1: north #39). Victory and the
			# counter wave both require lhm_killed>=12, which only
			# increments in level4 on_unit_died. Hunt remaining living
			# riders (already formation_broken). Hooks may attack them.
			var leftovers: Array = level.riders.filter(func(u): return alive(u))
			var vis_left: Array = leftovers.filter(func(u): return u.fog_visible)
			var fin: Variant = null
			if not vis_left.is_empty():
				vis_left.sort_custom(func(a, z): return a.hp < z.hp)
				fin = vis_left[0]
			elif not leftovers.is_empty():
				leftovers.sort_custom(func(a, z): return a.hp < z.hp)
				fin = leftovers[0]
			if fin != null:
				if fin.fog_visible:
					policy.target(battle, army, fin, "v28_finish_broken_rider")
				else:
					policy.move(battle, army, battle.map.world_to_cell(fin.position), true)
				if battle._run_clock._next_tick >= next_sample_tick:
					print("LIAN_HOOK_PACK ", {"kind":"v28_finish_broken", "tick":battle._run_clock._next_tick, "elapsed":level.elapsed, "target":str(fin.entity_id), "visible":fin.fog_visible, "hp":int(fin.hp), "alive_left":leftovers.size(), "lhm_killed":level.lhm_killed, "hooks_broken":level.broken_count})
		elif may_attack:
			var strike: Array = army
			var guard: Array = []
			if assault_ready and not nonhooks.is_empty():
				for soldier in nonhooks:
					if guard.size() >= 4: break
					guard.append(soldier)
				strike = army.filter(func(u): return u not in guard)
			if strike.size() >= 6 or level.elapsed > 120.0:
				if alive(target) and target.fog_visible: policy.target(battle, strike, target)
				else: policy.move(battle, strike, cell, attack_move)
			if not guard.is_empty() and alive(level.hall):
				policy.move(battle, guard, battle.map.world_to_cell(level.hall.position), false)
		else:
			# v17 hard rule kept: nonhooks NEVER target unbroken riders.
			var escort_threat: Variant = null
			for enemy in battle.units:
				if not alive(enemy) or enemy.faction != 1 or not enemy.fog_visible: continue
				if enemy in level.riders and not bool(enemy.get_meta("formation_broken", false)): continue
				if enemy.position.distance_to(level.hall.position) > 360.0: continue
				if escort_threat == null or enemy.position.distance_to(level.hall.position) < escort_threat.position.distance_to(level.hall.position):
					escort_threat = enemy
			if not nonhooks.is_empty() and alive(level.hall):
				if escort_threat != null:
					policy.target(battle, nonhooks, escort_threat, "hall_escort_clear")
				else:
					policy.move(battle, nonhooks, battle.map.world_to_cell(level.hall.position), false)
			if not retreat.is_empty():
				policy.move(battle, retreat, hold_cell, false)
			if ready_target != null:
				# Break predicate already holds: the >=2 in-range hooks (+ core) strike
				# together; _rider_tick flips formation_broken on the next level tick.
				var team: Array = level._hook_team(battle, ready_target)
				var strikers: Array = pack.filter(func(h): return h in team or h in core)
				policy.target(battle, strikers, ready_target, "coordinated_hook_attack")
				var rest: Array = pack.filter(func(h): return h not in strikers)
				if not rest.is_empty():
					var rc: Vector2i = battle.map.world_to_cell(ready_target.position + (core_center - ready_target.position).normalized() * 64.0) if core_center.distance_to(ready_target.position) > 1.0 else hold_cell
					policy.move(battle, rest, rc if safe_cell.call(rc, 28.0) else hold_cell, false)
			elif pack.size() < 2:
				# Never send a single hook toward an unbroken rider: wait west of hall.
				if not pack.is_empty(): policy.move(battle, pack, hold_cell, false)
			elif not pack_together:
				# Gather: everyone to the core centroid (or all-hook centroid), safe only.
				var gather_from: Array = core if core.size() >= 2 else pack
				var gc: Vector2 = Vector2.ZERO
				for h in gather_from: gc += h.position
				gc /= float(gather_from.size())
				var gcell: Vector2i = battle.map.world_to_cell(gc)
				policy.move(battle, pack, gcell if safe_cell.call(gcell, 64.0) else hold_cell, false)
			else:
				if not stragglers.is_empty():
					var ccell: Vector2i = battle.map.world_to_cell(core_center)
					policy.move(battle, stragglers, ccell if safe_cell.call(ccell, 48.0) else hold_cell, false)
				var stage: Vector2i = Vector2i(-1, -1)
				var focus: Variant = hook_target if hook_target != null else (approach_rider if approach_in_pack else null)
				if focus != null:
					var dir: Vector2 = core_center - focus.position
					if dir.length() < 1.0: dir = level.hall.position - focus.position
					dir = dir.normalized()
					for d in [40.0, 52.0, 64.0, 80.0, 96.0]:
						var sc: Vector2i = battle.map.world_to_cell(focus.position + dir * d)
						if safe_cell.call(sc, 28.0):
							stage = sc
							break
				if hook_target != null:
					# Passive walk-up next to (never onto) the impeded rider; riders
					# engage passive hooks and close the gap themselves.
					if stage != Vector2i(-1, -1): policy.move(battle, core, stage, false)
					else: policy.move(battle, core, battle.map.world_to_cell(core_center), false)
				elif focus != null:
					# Unimpeded rider approaching: hold the reed choke as one pack.
					policy.move(battle, core, cell if safe_cell.call(cell, 48.0) else (stage if stage != Vector2i(-1, -1) else battle.map.world_to_cell(core_center)), false)
				else:
					policy.move(battle, core, cell if safe_cell.call(cell, 48.0) else battle.map.world_to_cell(core_center), false)
		# v21 slows: cast xu_ning slot 0 (line slow 0.5) at the rider the hook core
		# is engaging so temp_speed<0.8 feeds the break predicate. Never when any
		# unbroken rider nearby is low (<=35%) -> no lethal-before-break.
		if may_attack:
			policy._skills_lhm(battle, army)
		else:
			var slow_target: Variant = ready_target if ready_target != null else (hook_target if hook_target != null else approach_rider)
			if slow_target != null and alive(slow_target) and core.size() >= 2 and core_center.distance_to(slow_target.position) <= 160.0:
				for hero in army:
					if not hero.is_hero or hero._cast_t > 0 or hero.position.distance_to(slow_target.position) > 250.0: continue
					var low_near: bool = (unbroken_north + unbroken_south).any(func(r): return alive(r) and r.position.distance_to(hero.position) <= 340.0 and r.hp <= r.max_hp * 0.35)
					if low_near: continue
					if hero.slot_count() < 1 or not hero.slot_ready(0): continue
					battle.select_members([hero], false)
					battle._cast_ability_slot(0)
					if battle._ability_armed != "": battle._cast_armed_at(battle.to_screen(slow_target.position))
					policy.skill_orders += 1
					record_action("skill_command", [hero], {"slot":0, "target_entity_id":str(slow_target.entity_id), "purpose":"v21_rider_slow"})
					break
			# Re-recruit the instructor at the original hall if he fell (ordinary paid order).
			if not alive(level.xu) and alive(level.hall) and level.hall._train_queue.is_empty() and battle.gold >= 235 and battle.wood >= 36:
				var g0: int = battle.gold
				var w0: int = battle.wood
				if battle.queue_train(level.hall, "xu_ning", false):
					record_action("train", [level.hall], {"key":"xu_ning", "gold_spent":g0-battle.gold, "wood_spent":w0-battle.wood})
		if battle._run_clock._next_tick >= next_sample_tick:
			print("LIAN_HOOK_PACK ", {"tick":battle._run_clock._next_tick, "elapsed":level.elapsed, "hooks":hooks.size(), "core":core.size(),
				"spread":core_spread, "stragglers":stragglers.size(), "retreat":retreat.size(), "hook_target":str(hook_target.entity_id) if hook_target != null else "",
				"ready_target":str(ready_target.entity_id) if ready_target != null else "", "skill_orders":policy.skill_orders, "south_phase":south_phase})
		# ---- v24 (on v22): hall defense, per-rider stray lure, rams pre-placed after 12/12 ----
		# Runs after the byte-identical v21 hook block. v23's open-ground pack-approach is NOT
		# included. Non-hooks never get an explicit order on an unbroken rider except the
		# capped hall pull (2 units, rider >=75% hp, in the 500px hall-def zone).
		if not may_attack:
			var now_t: int = battle._run_clock._next_tick
			var unb_all: Array = unbroken_north + unbroken_south
			var seen: Dictionary = get_meta("v24_seen", {})
			for r in unb_all:
				var rid: String = str(r.entity_id)
				var g: int = int(r.get_meta("wave_group"))
				if r.fog_visible:
					seen[rid] = {"t": now_t, "pos": r.position}
				elif not seen.has(rid) and bool(level.waves[g].sent):
					seen[rid] = {"t": now_t, "pos": battle.map.cell_to_world(level.LANES[g])}
			set_meta("v24_seen", seen)
			var lure_id: String = str(get_meta("v24_lure_id", ""))
			# Keep defending a hall under fire while the hooks switch to the south.
			# Only riders already inside the defense circle qualify for a pull.
			var hall_riders: Array = []
			var hall_attackers: Array = []
			var hall_hp: float = level.hall.hp if alive(level.hall) else 0.0
			var hall_taking_damage: bool = alive(level.hall) and (hall_hp < previous_hall_hp or level.hall.recently_hit())
			previous_hall_hp = hall_hp
			var esc: Variant = null
			if alive(level.hall):
				hall_riders = unb_all.filter(func(r): return r.position.distance_to(level.hall.position) <= 500.0)
				if south_phase or not hall_riders.is_empty():
					for e in battle.units:
						if not alive(e) or e.faction != 1 or e.is_building or not e.fog_visible: continue
						if e in unb_all or e.position.distance_to(level.hall.position) > 500.0: continue
						if e._target == level.hall: hall_attackers.append(e)
						if esc == null or e.position.distance_to(level.hall.position) < esc.position.distance_to(level.hall.position): esc = e
			var handoff_defense: bool = south_phase and (hall_taking_damage or not hall_attackers.is_empty())
			var hall_def: bool = not hall_riders.is_empty() or handoff_defense
			var def_note: String = ""
			var hook_note: String = ""
			# A-click an exact visible unit. Right-click near the hall can
			# garrison the defenders before it considers the enemy.
			var focus_hall_target: Callable = func(group: Array, enemy: Variant, label: String) -> bool:
				if group.is_empty() or not alive(enemy) or not enemy.fog_visible: return false
				var point: Vector2 = battle.to_screen(enemy.position)
				if battle._enemy_at(point) != enemy: return false
				battle.select_members(group, false)
				battle._order_amove_at(point)
				policy.orders += 1
				record_action(label, group, {"target_entity_id":str(enemy.entity_id), "command":"attack_click"})
				return true
			if hall_def:
				hall_riders.sort_custom(func(a, z): return a.position.distance_to(level.hall.position) < z.position.distance_to(level.hall.position))
				var defenders: Array = nonhooks.filter(func(u): return u.key != "siege_ram" and str(u.entity_id) != lure_id)
				if handoff_defense:
					hall_attackers.sort_custom(func(a, z): return a.position.distance_to(level.hall.position) < z.position.distance_to(level.hall.position))
					if not hall_attackers.is_empty(): esc = hall_attackers[0]
					def_note = "handoff_watch"
					if hall_hp < level.hall.max_hp and now_t >= next_hall_repair_tick:
						next_hall_repair_tick = now_t + 360
						var workers: Array = battle.units.filter(func(u): return alive(u) and u.faction == 0 and u.is_worker and not u.garrisoned)
						var repairing: bool = workers.any(func(u): return u._state == u.ST_REPAIR and u._build_site == level.hall)
						if not repairing:
							var available: Array = workers.filter(func(u): return u._state != u.ST_BUILD and u._state != u.ST_REPAIR and u.position.distance_to(level.hall.position) <= 280.0)
							available.sort_custom(func(a, z): return a.position.distance_to(level.hall.position) < z.position.distance_to(level.hall.position))
							if not available.is_empty():
								battle.select_members([available[0]], false)
								battle.arm_repair()
								battle._order_repair_at(battle.to_screen(level.hall.position))
								battle.cancel_armed()
								if available[0]._state == available[0].ST_REPAIR and available[0]._build_site == level.hall:
									record_action("hall_repair_command_card", [available[0]], {"target_entity_id":str(level.hall.entity_id)})
				if not defenders.is_empty():
					# v29: skip injured riders; keep pulling visible,
					# unbroken, HP>=75% riders inside the 500px hall-def
					# zone. One injured rider no longer blocks the whole
					# circle (v28 circle-wide injured gate). The pull target is the closest
					# such rider, not merely the closest hall rider if that
					# one is injured. Do not pull or attack-move onto a
					# rider below 75% hp (lhm_direct_break). Caps unchanged:
					# 2 non-hook pullers. No new early intercept outside
					# the 500px zone.
					var pullers: Array = []
					var rest_d: Array = defenders
					var pull_cands: Array = hall_riders.filter(func(r): return r.fog_visible and r.hp >= r.max_hp * 0.75)
					var hr_pull: Variant = pull_cands[0] if not pull_cands.is_empty() else null
					var can_pull: bool = false
					if hr_pull != null:
						pullers = defenders.duplicate()
						pullers.sort_custom(func(a, z): return a.hp > z.hp)
						var pull_limit: int = 1 if handoff_defense and not hall_attackers.is_empty() else 2
						pullers = pullers.slice(0, pull_limit)
						can_pull = focus_hall_target.call(pullers, hr_pull, "v24_hall_rider_pull")
						if can_pull:
							rest_d = defenders.filter(func(u): return u not in pullers)
							def_note = "pull_" + str(hr_pull.entity_id)
					if not rest_d.is_empty():
						if focus_hall_target.call(rest_d, esc, "v24_hall_escort"):
							if def_note == "" or def_note == "handoff_watch":
								def_note = "escort_" + str(esc.entity_id)
							else:
								def_note += "+escort_" + str(esc.entity_id)
						elif handoff_defense:
							if safe_cell.call(hold_cell, 28.0): policy.move(battle, rest_d, hold_cell, false)
						elif not can_pull:
							policy.move(battle, rest_d, battle.map.world_to_cell(level.hall.position), false)
							def_note = "hold_hall"
						else:
							policy.move(battle, rest_d, battle.map.world_to_cell(level.hall.position), false)
			if not hall_riders.is_empty():
				var hr: Variant = hall_riders[0]
				# hooks: only if v21 has no break-ready strike this tick. Stage on the rider's
				# marsh-facing side when it is impeded or xu_ning's slow is ready; else hold.
				if ready_target == null and core.size() >= 2 and hr.fog_visible:
					var impeded: bool = battle.map.t_world(hr.position) in [level.T.REEDS, level.T.MARSH] or hr.temp_speed < 0.8
					var slow_hero: Variant = null
					for hero in hooks:
						if hero.is_hero and hero._cast_t <= 0 and hero.slot_count() >= 1 and hero.slot_ready(0) and hero.hp >= hero.max_hp * 0.4:
							slow_hero = hero
					if impeded or slow_hero != null:
						var lane_n: Vector2 = battle.map.cell_to_world(level.LANES[0])
						var lane_s: Vector2 = battle.map.cell_to_world(level.LANES[1])
						var marsh_w: Vector2 = lane_n if hr.position.distance_to(lane_n) <= hr.position.distance_to(lane_s) else lane_s
						var hdir: Vector2 = (marsh_w - hr.position).normalized()
						var hst: Vector2i = Vector2i(-1, -1)
						for d in [40.0, 52.0, 64.0, 80.0, 96.0]:
							var hc: Vector2i = battle.map.world_to_cell(hr.position + hdir * d)
							if safe_cell.call(hc, 28.0):
								hst = hc
								break
						if hst != Vector2i(-1, -1):
							policy.move(battle, core, hst, false)
							hook_note = "stage_" + str(hr.entity_id) + ("_impeded" if impeded else "_slow")
						else:
							policy.move(battle, core, hold_cell, false)
							hook_note = "hold_nostage"
						var low_near: bool = unb_all.any(func(r): return r.position.distance_to(hr.position) <= 340.0 and r.hp <= r.max_hp * 0.35)
						if not impeded and slow_hero != null and not low_near and core_center.distance_to(hr.position) <= 160.0 and slow_hero.position.distance_to(hr.position) <= 250.0:
							battle.select_members([slow_hero], false)
							battle._cast_ability_slot(0)
							if battle._ability_armed != "": battle._cast_armed_at(battle.to_screen(hr.position))
							policy.skill_orders += 1
							record_action("skill_command", [slow_hero], {"slot":0, "target_entity_id":str(hr.entity_id), "purpose":"v24_hall_rider_slow"})
							hook_note += "_cast"
					else:
						# v27: last remaining rider — do not hold_noslow the pack off
						# them. Stage on the marsh-facing side only when a safe cell
						# exists near the choke; never park hooks on open ground.
						if unb_all.size() == 1 and hr.position.distance_to(battle.map.cell_to_world(hold_cell)) <= 420.0:
							var lane_n2: Vector2 = battle.map.cell_to_world(level.LANES[0])
							var lane_s2: Vector2 = battle.map.cell_to_world(level.LANES[1])
							var marsh_w2: Vector2 = lane_n2 if hr.position.distance_to(lane_n2) <= hr.position.distance_to(lane_s2) else lane_s2
							var hdir2: Vector2 = (marsh_w2 - hr.position).normalized()
							var hst2: Vector2i = Vector2i(-1, -1)
							for d2 in [40.0, 52.0, 64.0, 80.0, 96.0]:
								var hc2: Vector2i = battle.map.world_to_cell(hr.position + hdir2 * d2)
								if safe_cell.call(hc2, 28.0):
									hst2 = hc2
									break
							if hst2 != Vector2i(-1, -1):
								policy.move(battle, core, hst2, false)
								hook_note = "stage_" + str(hr.entity_id) + "_last"
							else:
								hook_note = "hold_last"
						else:
							policy.move(battle, core, hold_cell, false)
							hook_note = "hold_noslow"
			var hd_note: String = (def_note + "|" + hook_note) if hall_def else ""
			if hd_note != str(get_meta("v24_hd_note", "")):
				set_meta("v24_hd_note", hd_note)
				print("LIAN_HOOK_PACK ", {"kind":"v24_hall_defense", "event":hd_note if hd_note != "" else "end", "tick":now_t, "elapsed":level.elapsed,
					"hall_hp":float(level.hall.hp) if alive(level.hall) else 0.0, "riders":hall_riders.map(func(r): return str(r.entity_id)), "core":core.size()})
			if handoff_defense and now_t >= next_hall_pressure_log:
				next_hall_pressure_log = now_t + 300
				print("LIAN_HALL_PRESSURE ", {"tick":now_t, "elapsed":level.elapsed, "hall_hp":hall_hp,
					"recent_damage":hall_taking_damage, "south_sent":bool(level.waves[1].sent), "orders":def_note,
					"attackers":hall_attackers.map(func(e): return {"id":str(e.entity_id), "key":e.key}),
					"unbroken_in_zone":hall_riders.map(func(r): return str(r.entity_id)), "nonhooks":nonhooks.size()})
			# (b) per-rider stray lure: a rider unseen >45s is lured even if others are visible.
			# v28: a last GROUP of unbroken riders stuck in the same pocket and
			# long unseen also walks lure_approach/lure_pull to the reed/marsh
			# choke (v27 only did this when unb_all.size()==1). lure_home still
			# requires the v27 break predicate (ready_target or impeded-at-choke).
			# Do not reintroduce the v26 loose lure_home cancel. Hooks stay at
			# the choke (no open-ground parking). Scattered (non-clustered)
			# multi-rider lure still uses the waypoint path.
			var last_left: bool = unb_all.size() == 1
			var unseen_need: int = 900 if last_left else 2700
			var stranded: Array = unb_all.filter(func(r): return not r.fog_visible and seen.has(str(r.entity_id)) and now_t - int(seen[str(r.entity_id)]["t"]) > unseen_need)
			if last_left:
				var lr: Variant = unb_all[0]
				var lr_at_choke: bool = lr.position.distance_to(battle.map.cell_to_world(hold_cell)) <= 160.0 or (core.size() >= 2 and lr.position.distance_to(core_center) <= 96.0)
				var lr_impeded: bool = battle.map.t_world(lr.position) in [level.T.REEDS, level.T.MARSH] or lr.temp_speed < 0.8
				var lr_breakable: bool = (ready_target == lr) or (lr_impeded and lr_at_choke)
				if not lr_breakable and lr not in stranded:
					stranded = [lr]
			var pocket_group: bool = false
			if not last_left and stranded.size() >= 2:
				var pocket_span: float = 0.0
				for a in stranded:
					for z in stranded:
						var dspan: float = a.position.distance_to(z.position)
						if dspan > pocket_span:
							pocket_span = dspan
				pocket_group = pocket_span <= 256.0
			var choke_lure: bool = last_left or pocket_group
			stranded.sort_custom(func(a, z): return int(seen.get(str(a.entity_id), {"t": 0})["t"]) < int(seen.get(str(z.entity_id), {"t": 0})["t"]))
			var lure: Variant = null
			for u in nonhooks:
				if str(u.entity_id) == lure_id:
					lure = u
			var lure_note: String = ""
			if lure == null and lure_id != "":
				set_meta("v24_lure_id", "")
				set_meta("v24_lure_next", now_t + (600 if choke_lure else 1800))
				set_meta("v26_lure_pull", false)
				lure_id = ""
				lure_note = "lure_lost"
			if lure == null and not hall_def and not stranded.is_empty() and now_t >= int(get_meta("v24_lure_next", 0)):
				var cand: Array = nonhooks.filter(func(u): return u.key != "siege_ram" and not u.is_hero)
				cand.sort_custom(func(a, z): return a.max_hp > z.max_hp)
				if not cand.is_empty():
					lure = cand[0]
					set_meta("v24_lure_id", str(lure.entity_id))
					set_meta("v24_lure_wp", 0)
					set_meta("v24_lure_target", str(stranded[0].entity_id))
					set_meta("v26_lure_pull", false)
					lure_note = "lure_out_" + str(stranded[0].entity_id)
			if lure != null:
				var tr: Variant = null
				for r in stranded:
					if str(r.entity_id) == str(get_meta("v24_lure_target", "")):
						tr = r
				if tr == null and choke_lure:
					if last_left:
						tr = unb_all[0]
					elif not stranded.is_empty():
						tr = stranded[0]
				var rider_breakable: bool = false
				if tr != null:
					var at_choke: bool = tr.position.distance_to(battle.map.cell_to_world(hold_cell)) <= 160.0 or (core.size() >= 2 and tr.position.distance_to(core_center) <= 96.0)
					var impeded_tr: bool = battle.map.t_world(tr.position) in [level.T.REEDS, level.T.MARSH] or tr.temp_speed < 0.8
					rider_breakable = (ready_target == tr) or (impeded_tr and at_choke)
				var go_back: bool = false
				if choke_lure:
					# Only walk home when the (last or pocket-group) target is
					# actually breakable at the choke, the lure is spent, or
					# the target was lost. hall_def does not cancel a choke
					# pull of this group. No loose proximity cancel.
					go_back = tr == null or lure.hp < lure.max_hp * 0.4 or rider_breakable
				else:
					go_back = tr == null or hall_def or lure.hp < lure.max_hp * 0.4
				if go_back:
					var home_c: Vector2i = battle.map.world_to_cell(core_center) if core.size() >= 2 else hold_cell
					if not safe_cell.call(home_c, 48.0):
						home_c = hold_cell
					policy.move(battle, [lure], home_c, false)
					var can_home: bool = lure.position.distance_to(battle.map.cell_to_world(home_c)) <= 96.0
					if choke_lure:
						can_home = can_home and (rider_breakable or tr == null or lure.hp < lure.max_hp * 0.4)
					if can_home:
						set_meta("v24_lure_id", "")
						set_meta("v24_lure_next", now_t + (300 if choke_lure else 900))
						set_meta("v26_lure_pull", false)
						lure_note = "lure_home"
					elif lure_note == "":
						lure_note = "lure_back"
				elif choke_lure:
					var g2l: int = int(tr.get_meta("wave_group"))
					var marsh_c: Vector2i = hold_cell
					if safe_cell.call(level.LANES[g2l], 48.0):
						marsh_c = level.LANES[g2l]
					var d_rider: float = lure.position.distance_to(tr.position)
					var pulling: bool = bool(get_meta("v26_lure_pull", false))
					if pulling and d_rider > 520.0:
						set_meta("v26_lure_pull", false)
						pulling = false
					if not pulling and d_rider <= 240.0:
						set_meta("v26_lure_pull", true)
						pulling = true
					if pulling:
						policy.move(battle, [lure], marsh_c, false)
						if lure_note == "":
							lure_note = "lure_pull_" + str(tr.entity_id)
					else:
						var goal_l: Vector2 = tr.position
						var toward_l: Vector2 = (lure.position - goal_l).normalized() if lure.position.distance_to(goal_l) > 1.0 else Vector2.LEFT
						var gcell_l: Vector2i = Vector2i(-1, -1)
						for k in range(8):
							var c2l: Vector2i = battle.map.world_to_cell(goal_l + toward_l * 32.0 * float(k))
							if safe_cell.call(c2l, 48.0):
								gcell_l = c2l
								break
						if gcell_l != Vector2i(-1, -1):
							policy.move(battle, [lure], gcell_l, false)
						if lure_note == "":
							lure_note = "lure_approach_" + str(tr.entity_id)
				else:
					var g2: int = int(tr.get_meta("wave_group"))
					var last_pos: Vector2 = seen[str(tr.entity_id)]["pos"]
					var post_w: Vector2 = battle.map.cell_to_world(level.RIDER_POSTS[g2] + Vector2i(-3, 0))
					var wps: Array = [last_pos, last_pos.lerp(post_w, 0.5), post_w]
					var wi: int = int(get_meta("v24_lure_wp", 0))
					if wi < wps.size() - 1 and lure.position.distance_to(wps[wi]) <= 80.0:
						wi += 1
						set_meta("v24_lure_wp", wi)
					var goal: Vector2 = wps[wi]
					var toward: Vector2 = (lure.position - goal).normalized() if lure.position.distance_to(goal) > 1.0 else Vector2.LEFT
					var gcell: Vector2i = Vector2i(-1, -1)
					for k in range(8):
						var c2: Vector2i = battle.map.world_to_cell(goal + toward * 32.0 * float(k))
						if safe_cell.call(c2, 48.0):
							gcell = c2
							break
					if gcell != Vector2i(-1, -1):
						policy.move(battle, [lure], gcell, false)
					if lure_note == "":
						lure_note = "lure_wp%d_%s" % [wi, str(tr.entity_id)]
			if lure_note != "" and lure_note != str(get_meta("v24_lure_note", "")):
				set_meta("v24_lure_note", lure_note)
				print("LIAN_HOOK_PACK ", {"kind":"v24_lure", "event":lure_note, "tick":now_t, "elapsed":level.elapsed,
					"lure":str(lure.entity_id) if (lure != null and is_instance_valid(lure)) else lure_id, "stranded":stranded.map(func(r): return str(r.entity_id))})
			if now_t >= next_sample_tick:
				var rlog: Array = []
				for r in unb_all:
					var sid: String = str(r.entity_id)
					rlog.append({"id":sid, "wave":int(r.get_meta("wave_group")), "state":str(r.get_meta("wave_state", "")),
						"cell":str(battle.map.world_to_cell(r.position)), "visible":r.fog_visible, "hp":int(r.hp),
						"unseen_s":(float(now_t - int(seen[sid]["t"])) / 60.0) if seen.has(sid) else -1.0})
				print("LIAN_HOOK_PACK ", {"kind":"unbroken_riders", "tick":now_t, "elapsed":level.elapsed, "riders":rlog,
					"lure":str(get_meta("v24_lure_id", "")), "hall_defense":hall_def, "hall_hp":float(level.hall.hp) if alive(level.hall) else 0.0})
		# ---- v25 (on v24b): west rally, Huyan Zhuo fallback, far-gold clearing, rally proximity/death log ----
		# Replaces v24 (c) stand-alone ram pre-placement: rams now rally with the strike group at the
		# west rally (>=18 cells from the enemy camp) and move with the wave.
		if may_attack and lane == "counter":
			var now25: int = battle._run_clock._next_tick
			var launched25: bool = bool(get_meta("v22_launched", false))
			var rally25: Vector2i = get_meta("v25_rally", Vector2i(28, 30))
			var rally_w25: Vector2 = battle.map.cell_to_world(rally25)
			var gcen25: Vector2 = Vector2.ZERO
			for u in army: gcen25 += u.position
			if not army.is_empty(): gcen25 /= float(army.size())
			var hu_ok: bool = alive(level.hu)
			var hu_pos: Vector2 = level.hu.position if hu_ok else Vector2(-99999.0, -99999.0)
			var hu_d_rally: float = hu_pos.distance_to(rally_w25)
			var hu_d_army: float = hu_pos.distance_to(gcen25) if not army.is_empty() else 99999.0
			var hu_at_hall: bool = hu_ok and alive(level.hall) and hu_pos.distance_to(level.hall.position) <= 500.0
			var hu_near: bool = hu_ok and not launched25 and not hu_at_hall and (hu_d_rally <= 400.0 or hu_d_army <= 400.0)
			set_meta("v25_hu_near", hu_near)
			var note25: String = ""
			if hu_near:
				var fb: Vector2i = Vector2i(16, 30)
				for c in [Vector2i(16, 30), Vector2i(15, 32), Vector2i(17, 28), Vector2i(14, 30)]:
					if battle.map.is_open_cell(c, "land"):
						fb = c
						break
				var mv: Array = army.filter(func(u): return u.position.distance_to(battle.map.cell_to_world(fb)) > 96.0)
				if not mv.is_empty(): policy.move(battle, mv, fb, false)
				note25 = "fallback_hu"
			# far gold: when home gold is nearly gone, clear the blockers of the nearest far mine
			var mines25: Array = battle.units.filter(func(u): return is_instance_valid(u) and u.is_resource and u.res_kind == "gold" and u.res_left > 0.0)
			var home_left: float = 0.0
			var far_info: Array = []
			var clear_mine: Variant = null
			var clear_blockers: Array = []
			for m in mines25:
				if alive(level.hall) and m.position.distance_to(level.hall.position) <= 520.0:
					home_left += float(m.res_left)
					continue
				var blk: Array = battle.units.filter(func(e): return alive(e) and e.faction == 1 and not e.is_building and e.position.distance_to(m.position) <= 260.0)
				var staffed: bool = battle.units.any(func(w): return alive(w) and w.faction == 0 and w.is_worker and is_instance_valid(w._gather_node) and w._gather_node == m)
				far_info.append({"cell":str(battle.map.world_to_cell(m.position)), "left":int(m.res_left), "blockers":blk.size(), "staffed":staffed})
				if not blk.is_empty() and hu_pos.distance_to(m.position) > 500.0:
					if clear_mine == null or m.position.distance_to(level.hall.position) < clear_mine.position.distance_to(level.hall.position):
						clear_mine = m
						clear_blockers = blk
			if not launched25 and not hu_near and home_left < 600.0 and clear_mine != null:
				var grp25: Array = army.filter(func(u): return u.key != "siege_ram")
				if grp25.size() >= 8:
					var vis_b: Array = clear_blockers.filter(func(e): return e.fog_visible)
					if not vis_b.is_empty():
						vis_b.sort_custom(func(a, z): return a.position.distance_to(gcen25) < z.position.distance_to(gcen25))
						policy.target(battle, grp25, vis_b[0], "v25_far_gold_clear")
					else:
						policy.move(battle, grp25, battle.map.world_to_cell(clear_mine.position), true)
					note25 = "clear_far_gold_" + str(battle.map.world_to_cell(clear_mine.position))
			if note25 != str(get_meta("v25_note", "")):
				set_meta("v25_note", note25)
				print("LIAN_RALLY_PROX ", {"kind":"state", "event":note25 if note25 != "" else "normal", "elapsed":level.elapsed, "tick":now25,
					"hu_cell":str(battle.map.world_to_cell(hu_pos)) if hu_ok else "gone", "hu_d_rally":hu_d_rally, "hu_d_army":hu_d_army, "army":army.size(), "launched":launched25})
			# per-death log: our combat units that vanished since last tick
			var prev25: Dictionary = get_meta("v25_alive", {})
			var cur25: Dictionary = {}
			for u in army:
				cur25[str(u.entity_id)] = {"key":u.key, "pos":u.position}
			for pid in prev25:
				if cur25.has(pid): continue
				var still: bool = battle.units.any(func(u): return alive(u) and str(u.entity_id) == pid)
				if still: continue
				var lp: Vector2 = prev25[pid]["pos"]
				var ne: Variant = null
				for e in battle.units:
					if not alive(e) or e.faction != 1 or e.is_building: continue
					if ne == null or e.position.distance_to(lp) < ne.position.distance_to(lp): ne = e
				print("LIAN_RALLY_DEATH ", {"elapsed":level.elapsed, "tick":now25, "id":pid, "key":prev25[pid]["key"], "cell":str(battle.map.world_to_cell(lp)),
					"d_rally":lp.distance_to(rally_w25), "near_rally":lp.distance_to(rally_w25) <= 500.0, "d_hu":lp.distance_to(hu_pos) if hu_ok else -1.0,
					"hu_cell":str(battle.map.world_to_cell(hu_pos)) if hu_ok else "gone",
					"nearest_enemy":(str(ne.key) + "#" + str(ne.entity_id)) if ne != null else "", "nearest_enemy_d":ne.position.distance_to(lp) if ne != null else -1.0,
					"launched":launched25, "wave":int(get_meta("v22_wave", 0))})
			set_meta("v25_alive", cur25)
			if now25 >= int(get_meta("v25_prox_tick", 0)):
				set_meta("v25_prox_tick", now25 + 300)
				var en400: int = battle.units.filter(func(e): return alive(e) and e.faction == 1 and not e.is_building and e.position.distance_to(rally_w25) <= 400.0).size()
				print("LIAN_RALLY_PROX ", {"kind":"sample", "elapsed":level.elapsed, "tick":now25, "rally":str(rally25), "launched":launched25, "wave":int(get_meta("v22_wave", 0)),
					"hu_cell":str(battle.map.world_to_cell(hu_pos)) if hu_ok else "gone", "hu_hp":int(level.hu.hp) if hu_ok else 0, "hu_visible":level.hu.fog_visible if hu_ok else false,
					"hu_d_rally":hu_d_rally, "hu_d_army":hu_d_army, "enemies_400_rally":en400, "army":army.size(), "hu_near":hu_near,
					"home_gold_left":int(home_left), "far_mines":far_info, "gold":battle.gold, "wood":battle.wood,
					"manor_hp":float(level.enemy_base.hp) if is_instance_valid(level.enemy_base) else 0.0})
		if battle._run_clock._next_tick >= next_sample_tick:
			next_sample_tick = battle._run_clock._next_tick + 1800
			var sample: Dictionary = {"tick":battle._run_clock._next_tick, "elapsed":level.elapsed, "lane":lane,
				"army":army.size(), "riders_defeated":level.lhm_killed, "hooks_broken":level.broken_count,
				"wave_index":wave_index, "unbroken_live_riders":unbroken.size(), "external_army_attack_enabled":may_attack,
				"gold":battle.gold, "wood":battle.wood, "hall_hp":level.hall.hp, "song_hp":level.song.hp}
			combat_samples.append(sample); print("LIAN_COMBAT ", sample)
		var next_tick: int = battle._run_clock._next_tick + 75
		await wait_live(func(): return battle._run_clock._next_tick >= next_tick, 8.0)
	observations["combat"] = {"samples":combat_samples, "initial_rider_ids":rider_ids,
		"buildings_started":policy.buildings_started, "units_queued":policy.units_queued,
		"units_queued_by_key":policy.units_queued_by_key, "orders":policy.orders, "skill_orders":policy.skill_orders}
	if not dump_kill_once:
		var dump_reason: String = "post_combat"
		if battle.mission.has_event("lhm_direct_break"):
			dump_reason = "lhm_direct_break"
		elif not alive(level.hall) or (is_instance_valid(level.hall) and float(level.hall.hp) < 50.0):
			dump_reason = "hall_collapse"
		dump_kill_once = true
		for rider in level.riders:
			if not is_instance_valid(rider): continue
			if bool(rider.get_meta("formation_broken", false)): continue
			if dump_reason != "hall_collapse" and alive(rider): continue
			var killer: Variant = rider._killer
			print("LIAN_DIRECT_KILL ", {
				"elapsed": level.elapsed,
				"tick": battle._run_clock._next_tick,
				"source": dump_reason,
				"victim_id": str(rider.entity_id),
				"victim_key": rider.key,
				"victim_wave": int(rider.get_meta("wave_group")),
				"victim_hp": rider.hp,
				"killer_valid": is_instance_valid(killer),
				"killer_id": str(killer.entity_id) if is_instance_valid(killer) else "",
				"killer_key": killer.key if is_instance_valid(killer) else "",
				"killer_faction": killer.faction if is_instance_valid(killer) else -1,
				"killer_source_id": rider._killer_source_id,
			})
	check(simulation_ok(), "natural battle preserves normal simulation and RNG health")
	check(battle.phase == B.Phase.END and battle.mission.has_event("lhm_victory"), "normal economy and combat reach actual victory within bounded route")
	check(level.hall == original_hall and level.song == original_song and alive(level.hall) and alive(level.song), "original camp and commander survive entire saved route")
	check(level.lhm_killed == 12 and level.manor_fallen and level.broken_count == 12 \
		and not battle.mission.has_event("lhm_direct_break"), "all twelve original riders are hook-broken before defeat and headquarters falls")
	check(battle.mission.has_event("lhm_han_captured") and battle.mission.has_event("lhm_hu_fled"), "Han Tao captured and Huyan Zhuo retreats through actual combat outcomes")
	check(policy.buildings_started >= 2 and policy.units_queued >= 8 and policy.skill_orders > 0, "ordinary building paid recruitment and skill commands support real combat")
	if not failures.is_empty(): return
	if not await await_terminal(): return
	if not check(battle.mission._result_frozen, "production terminal already froze the complete mission result"): return
	var full_result: Dictionary = battle.mission.result_snapshot(true)
	stage_completed = await verify_terminal(original_receipt, full_result)
