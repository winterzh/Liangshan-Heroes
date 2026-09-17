extends "res://tools/zhujiazhuang_rts_test.gd"
## Three-plan comparable replay for Level 3 (tool v2).
## RTS_TEST_ROUTE=plan_mine|plan_cut|plan_inside
## RTS_TEST_SEED=5088120|5088121|5088122
## RTS_TEST_SPEED=1 (official) — wall timeout via RTS_TEST_WALL_SEC (default 1200)
## Live orders, production, pathing and combat only. No resource inject, freeze, teleport, or victory write.
## Records: record_trust / plan_stage / outcome as separate fields.

const TOOL_VERSION := "three_plans_v2_20260914"
const WALL_SEC_DEFAULT := 2000.0

var plan := "plan_mine"
var run_seed := 5088120
var rng_identity := {}
var rng_configured := {}
var rng_initial := {}
var active_battle: Node = null
var ledger := {}
var events := {}
var camp_hp_min := 1e9
var camp_hp_start := 0.0
var route_flags := {}
var losses := {}
var summary := {}
var ledger_valid := true
var record_trust := true
var trust_notes := []
var route_ok := true
var route_notes := []
var death_counts := {"worker":0,"troop":0,"hero":0,"siege":0}
var _death_hooked := {}
var north_mine_world := Vector2.ZERO
var hang_reason := ""
var wall_limit := WALL_SEC_DEFAULT
var last_stage := ""
var last_clock := 0.0

func _start_plan() -> Variant:
	var c = root.get_node("Campaign")
	c.current = 2
	for key in ["skirmish","skirmish_ai","arena","scenario","custom_defense","scale_on","ai_friendly"]:
		c.set(key,false)
	root.get_node("Settings").auto_micro_level = 0
	seed(run_seed)
	var b = load("res://scenes/main.tscn").instantiate()
	var provider: Script = load("res://scripts/run_content_identity.gd")
	rng_identity = provider.new().resolve_runtime_identity()
	rng_configured = b.configure_new_gameplay_rng(rng_identity, run_seed)
	if rng_configured.get("ok") != true:
		b.free()
		return null
	rng_initial = b.capture_gameplay_rng()
	root.add_child(b)
	current_scene = b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b._on_start_battle()
	return b

func _reset_run_state() -> void:
	failures = []
	checks = 0
	orders = 0
	buildings_started = 0
	units_queued = 0
	units_queued_by_key = {}
	play_metrics = {}
	ledger = {
		"gold_start":0,"wood_start":0,"gold_end":0,"wood_end":0,
		"income_gold":0,"income_wood":0,
		"spend_gold":0,"spend_wood":0,
		"refund_gold":0,"refund_wood":0,
		"north_mine_gold":0,"north_mine_wood":0,
		"balance_ok_gold":false,"balance_ok_wood":false,
	}
	events = {}
	camp_hp_min = 1e9
	camp_hp_start = 0.0
	route_flags = {
		"took_north":false,"assigned_north_workers":false,"cut_outpost":false,
		"opened_inside":false,"unexpected_outpost_kill":false,"unexpected_north":false,
		"north_worker_ids":[],
	}
	losses = {"worker":0,"troop":0,"hero":0,"siege":0,"total_player":0}
	summary = {}
	ledger_valid = true
	record_trust = true
	trust_notes = []
	route_ok = true
	route_notes = []
	death_counts = {"worker":0,"troop":0,"hero":0,"siege":0}
	_death_hooked = {}
	_alive_seen = {}
	hang_reason = ""
	last_stage = ""
	last_clock = 0.0

func _on_resource_event(kind: String, g: int, w: int) -> void:
	match kind:
		"income":
			ledger.income_gold += g
			ledger.income_wood += w
			if g > 0 and route_flags.took_north and active_battle != null and _north_gather_active():
				ledger.north_mine_gold += g
				if not events.has("north_mine_gold_t"):
					events.north_mine_gold_t = active_battle.level.elapsed if active_battle.level else 0.0
			if w > 0 and route_flags.took_north and active_battle != null and _north_gather_active():
				ledger.north_mine_wood += w
		"spend":
			ledger.spend_gold += g
			ledger.spend_wood += w
		"refund":
			ledger.refund_gold += g
			ledger.refund_wood += w

func _north_gather_active() -> bool:
	if active_battle == null:
		return false
	for u in active_battle.units:
		if u == null or not is_instance_valid(u) or u.faction != 0 or not u.is_worker or not alive(u):
			continue
		if not is_instance_valid(u._gather_node):
			continue
		if u._gather_node.res_kind != "gold":
			continue
		if u._gather_node.position.distance_to(north_mine_world) > 320.0:
			continue
		return true
	return false

func _hook_player_deaths(_b) -> void:
	# Death accounting uses disappearance+was_alive only (died signal may not fire
	# on every campaign resolve path and would double-count if combined).
	pass

func _on_player_death(kind: String, _unit = null) -> void:
	_count_death(kind)

func _count_death(kind: String) -> void:
	match kind:
		"worker":
			death_counts.worker += 1
		"hero":
			death_counts.hero += 1
		"siege":
			death_counts.siege += 1
		_:
			death_counts.troop += 1

## Dual-track deaths: `died` signal plus disappearance. Units may resolve via
## story_outcome without emitting died, or free within one tick of spawn.
var _alive_seen := {}

func _track_deaths_dual(b) -> void:
	var current := {}
	for u in b.units:
		if u == null or not is_instance_valid(u) or u.faction != 0 or u.is_building:
			continue
		var id: int = u.get_instance_id()
		current[id] = true
		if not _alive_seen.has(id):
			var kind := "troop"
			if u.is_worker:
				kind = "worker"
			elif u.is_hero:
				kind = "hero"
			elif u.key in ["siege_ram","siege_cata"]:
				kind = "siege"
			_alive_seen[id] = {"kind": kind, "was_alive": alive(u), "counted": false}
		elif alive(u):
			_alive_seen[id]["was_alive"] = true
	for id in _alive_seen.keys():
		var rec: Dictionary = _alive_seen[id]
		if rec.counted or not rec.was_alive:
			continue
		if current.has(id):
			continue
		rec.counted = true
		_count_death(String(rec.kind))

func _snap_opening(b) -> void:
	var l = b.level
	ledger.gold_start = b.gold
	ledger.wood_start = b.wood
	north_mine_world = b.map.cell_to_world(l.EXPANSION)
	if alive(l.hall):
		camp_hp_start = l.hall.hp
		camp_hp_min = l.hall.hp
	summary = {
		"seed": run_seed,
		"plan": plan,
		"tool": TOOL_VERSION,
		"gold": b.gold,
		"wood": b.wood,
		"pop_used": b.used_pop(),
		"pop_cap": b.pop_cap,
		"age": b.current_age,
		"fog": b.fog,
		"economy": b.economy,
		"unit_count": b.units.size(),
		"gameplay_rng_ok": b.gameplay_rng_fault().is_empty(),
		"rng_config": rng_configured,
		"source": "level3_zhujiazhuang_rts",
		"auto_micro": 0,
		"speed": Engine.time_scale,
		"wall_limit_sec": wall_limit,
	}

func _reconcile_ledger(b) -> void:
	ledger.gold_end = b.gold
	ledger.wood_end = b.wood
	var expect_g: int = int(ledger.gold_start) + int(ledger.income_gold) + int(ledger.refund_gold) - int(ledger.spend_gold)
	var expect_w: int = int(ledger.wood_start) + int(ledger.income_wood) + int(ledger.refund_wood) - int(ledger.spend_wood)
	ledger.balance_ok_gold = expect_g == int(b.gold)
	ledger.balance_ok_wood = expect_w == int(b.wood)
	ledger_valid = bool(ledger.balance_ok_gold and ledger.balance_ok_wood)
	if not ledger_valid:
		trust_notes.append("ledger mismatch gold expect=%d actual=%d wood expect=%d actual=%d" % [expect_g, b.gold, expect_w, b.wood])

func _watch_flags(b) -> void:
	var l = b.level
	if l.expansion_secured and not events.has("mine_secured_t"):
		events.mine_secured_t = l.elapsed
		route_flags.took_north = true
	if l.supply_cut and not events.has("supply_cut_t"):
		events.supply_cut_t = l.elapsed
		route_flags.cut_outpost = true
	if l.inside_open and not events.has("inside_open_t"):
		events.inside_open_t = l.elapsed
		route_flags.opened_inside = true
	if l.manor_fallen and not events.has("manor_fallen_t"):
		events.manor_fallen_t = l.elapsed
	if l.prisoners_freed and not events.has("prisoners_freed_t"):
		events.prisoners_freed_t = l.elapsed
	if l.raids_sent > 0 and not events.has("first_raid_t"):
		events.first_raid_t = l.elapsed
	if l.sent_sun and not events.has("sun_sent_t"):
		events.sun_sent_t = l.elapsed
	if alive(l.hall):
		if l.hall.hp < camp_hp_min:
			camp_hp_min = l.hall.hp
		if camp_hp_start > 0.0 and l.hall.hp < camp_hp_start - 1.0 and not events.has("camp_hit_t"):
			events.camp_hit_t = l.elapsed
	if b.mission != null and b.mission.has_event("zhu_victory") and not events.has("victory_t"):
		events.victory_t = l.elapsed

func _force_north_mining(b) -> void:
	if not route_flags.took_north:
		return
	var workers: Array = b.units.filter(func(u): return alive(u) and u.faction == 0 and u.is_worker)
	var attached := 0
	for u in workers:
		if is_instance_valid(u._gather_node) and u._gather_node.res_kind == "gold" \
				and u._gather_node.position.distance_to(north_mine_world) < 320.0:
			attached += 1
			continue
		# Re-task anyone idle or still on a home-site gold node toward the north mine.
		if u._state == 0 or (is_instance_valid(u._gather_node) and u._gather_node.res_kind == "gold"):
			var node = b.nearest_free_gold(north_mine_world, null, u)
			if node == null:
				node = b.nearest_resource(north_mine_world, "gold")
			if node != null and node.position.distance_to(north_mine_world) < 360.0:
				if u.has_method("order_gather"):
					u.order_gather(node)
					orders += 1
	route_flags.north_worker_ids = []
	for u in workers:
		if is_instance_valid(u._gather_node) and u._gather_node.res_kind == "gold" \
				and u._gather_node.position.distance_to(north_mine_world) < 320.0:
			route_flags.north_worker_ids.append(u.get_instance_id())
	if route_flags.north_worker_ids.size() >= 1:
		route_flags.assigned_north_workers = true

func _recon(b) -> void:
	var l = b.level
	if b.mission != null and b.mission.actions.has("zhu_rts_recon") and not b.mission.actions["zhu_rts_recon"].get("done", false):
		_action(b, l.song, "zhu_rts_recon")

func _inside_contact(b) -> void:
	# Never re-issue a move click while the 5s inside action is active: a second
	# move order calls on_player_order and resets progress to 0.
	var l = b.level
	if l.inside_open or not alive(l.sun):
		return
	if b.mission == null or not b.mission.actions.has("zhu_rts_inside"):
		return
	var action: Dictionary = b.mission.actions["zhu_rts_inside"]
	if bool(action.get("done", false)):
		return
	if b.mission.active_action_id == "zhu_rts_inside":
		return
	_action(b, l.sun, "zhu_rts_inside")

func _mobilize(b) -> Array:
	var army: Array = b.units.filter(func(u): return alive(u) and u.faction == 0 and not u.is_worker and not u.is_building and not u.is_captive and not u.is_noncombat and u.key not in ["song_jiang","sun_li"])
	if army.size() < 6:
		# Retreat to camp only; caller must not overwrite with attack orders this tick.
		_click(b, army, Vector2i(50,32), true)
	return army

func _attack_gate(b, army: Array) -> void:
	var l = b.level
	if alive(l.gate) and l.gate.visible:
		b.select_members(army, false)
		b._issue_order(b.to_screen(l.gate.position), false)
		orders += 1
	else:
		_click(b, army, Vector2i(25,28), true)

func _clear_towers(b, army: Array, prefer_inside: bool) -> void:
	var tower_cells: Array = [Vector2i(17,20),Vector2i(17,30)] if prefer_inside else [Vector2i(17,30)]
	for cell in tower_cells:
		var towers = b.units.filter(func(u): return alive(u) and u.faction == 1 and u.key == "arrow_tower" and b.map.world_to_cell(u.position) == cell)
		if not towers.is_empty() and towers[0].visible:
			b.select_members(army, false)
			b._issue_order(b.to_screen(towers[0].position), false)
			orders += 1
			return
	_click(b, army, tower_cells[0], true)

func _siege_manor(b, army: Array) -> void:
	var l = b.level
	if alive(l.enemy_base) and l.enemy_base.visible:
		b.select_members(army, false)
		b._issue_order(b.to_screen(l.enemy_base.position), false)
		orders += 1
	else:
		_click(b, army, Vector2i(10,26), true)

func _rescue_return(b, army: Array, rescuer) -> Variant:
	var l = b.level
	if not l.prisoners_freed:
		if not alive(rescuer):
			var rescuers: Array = army.filter(func(u): return u.key in l.FIELD_ACTORS)
			if rescuers.is_empty():
				return null
			rescuer = rescuers[0]
		# Do not overwrite an in-progress rescue action with a fresh click.
		if b.mission == null or b.mission.active_action_id != "zhu_rts_rescue":
			_click(b, army.filter(func(u): return u != rescuer), Vector2i(14,31), true)
			_action(b, rescuer, "zhu_rts_rescue")
		return rescuer
	_click(b, army, Vector2i(23,28), true)
	_click(b, l.prisoners.filter(func(u): return alive(u)), l.CAMP+Vector2i(-4,0))
	if l._finish_ready():
		if b.mission == null or b.mission.active_action_id != "zhu_rts_finish":
			_action(b, l.song, "zhu_rts_finish")
	return rescuer

func _play_plan(b) -> void:
	var l = b.level
	var stage := ""
	var rescuer = null
	if plan == "plan_mine":
		stage = "north"
	elif plan == "plan_cut":
		stage = "outpost"
	else:
		stage = "recon"
	last_stage = stage
	var clock := 0.0
	var next_print := 0.0
	var wall_start := Time.get_ticks_msec()
	while l.elapsed < 1600.0 and b.phase != b.Phase.END:
		if float(Time.get_ticks_msec() - wall_start) / 1000.0 > wall_limit:
			hang_reason = "wall_timeout"
			break
		await _wait(2.0)
		clock = l.elapsed
		last_clock = clock
		last_stage = stage
		_economy(b)
		_watch_flags(b)
		_hook_player_deaths(b)
		_track_deaths_dual(b)
		var army: Array = b.units.filter(func(u): return alive(u) and u.faction == 0 and not u.is_worker and not u.is_building and not u.is_captive and not u.is_noncombat and u.key not in ["song_jiang","sun_li"])
		if clock >= next_print:
			next_print = clock+30.0
			print("[three-plans] t=",int(clock)," plan=",plan," seed=",run_seed," stage=",stage,
				" army=",army.size()," g=",b.gold," w=",b.wood," pop=",b.used_pop(),"/",b.pop_cap,
				" inside_open=",l.inside_open," sun_dist=",
				0 if not alive(l.sun) else int(l.sun.position.distance_to(b.map.cell_to_world(Vector2i(25,18)))),
				" act=",b.mission.active_action_id if b.mission != null else "",
				" deaths=",death_counts)
		# Thin armies only retreat this tick; never overwrite retreat with assault.
		if army.size() < 6 and stage not in ["rescue"]:
			continue
		if plan == "plan_mine":
			if stage == "north":
				_click(b, army, l.EXPANSION, true)
				if l.expansion_secured:
					_force_north_mining(b)
					stage = "gate"
			elif stage == "gate":
				_force_north_mining(b)
				if army.size() >= 10:
					_attack_gate(b, army)
				if l.main_breached:
					stage = "tower"
			elif stage == "tower":
				_clear_towers(b, army, false)
				if not b.units.any(func(u): return alive(u) and u.faction == 1 and u.key == "arrow_tower" and b.map.world_to_cell(u.position) == Vector2i(17,30)):
					stage = "manor"
			elif stage == "manor":
				_siege_manor(b, army)
				if l.manor_fallen:
					stage = "rescue"
			elif stage == "rescue":
				rescuer = _rescue_return(b, army, rescuer)
		elif plan == "plan_cut":
			if stage == "outpost":
				_click(b, army, l.OUTPOST, true)
				if l.supply_cut:
					stage = "gate"
			elif stage == "gate":
				if army.size() >= 10:
					_attack_gate(b, army)
				if l.main_breached:
					stage = "tower"
			elif stage == "tower":
				_clear_towers(b, army, false)
				if not b.units.any(func(u): return alive(u) and u.faction == 1 and u.key == "arrow_tower" and b.map.world_to_cell(u.position) == Vector2i(17,30)):
					stage = "manor"
			elif stage == "manor":
				_siege_manor(b, army)
				if l.manor_fallen:
					stage = "rescue"
			elif stage == "rescue":
				rescuer = _rescue_return(b, army, rescuer)
		else:
			if stage == "recon":
				_recon(b)
				if l.sent_sun:
					stage = "inside"
			elif stage == "inside":
				_inside_contact(b)
				# Army stages near side gate but must not touch Sun Li.
				_click(b, army, Vector2i(28,22), true)
				if l.inside_open:
					stage = "enter"
			elif stage == "enter":
				_click(b, army, Vector2i(22,18), true)
				if army.any(func(u): return b.map.world_to_cell(u.position).x < 19):
					stage = "tower"
			elif stage == "tower":
				_clear_towers(b, army, true)
				if not b.units.any(func(u): return alive(u) and u.faction == 1 and u.key == "arrow_tower" and b.map.world_to_cell(u.position) == Vector2i(17,20)):
					stage = "manor"
			elif stage == "manor":
				_siege_manor(b, army)
				if l.manor_fallen:
					stage = "rescue"
			elif stage == "rescue":
				rescuer = _rescue_return(b, army, rescuer)
	last_stage = stage
	if l.supply_cut and plan != "plan_cut":
		route_flags.unexpected_outpost_kill = true
		route_notes.append("outpost destroyed without plan_cut order")
	if l.expansion_secured and plan != "plan_mine":
		route_flags.unexpected_north = true
		route_notes.append("north expansion secured without plan_mine order")
	if plan == "plan_mine" and not l.expansion_secured:
		route_ok = false
		route_notes.append("plan_mine failed to secure north mine")
	if plan == "plan_cut" and not l.supply_cut:
		route_ok = false
		route_notes.append("plan_cut failed to cut south outpost")
	if plan == "plan_inside" and not l.inside_open:
		route_ok = false
		route_notes.append("plan_inside failed to open side gate")
	if hang_reason != "":
		record_trust = false
		trust_notes.append("run interrupted: "+hang_reason)
	_reconcile_ledger(b)
	losses.worker = death_counts.worker
	losses.troop = death_counts.troop
	losses.hero = death_counts.hero
	losses.siege = death_counts.siege
	losses.total_player = int(losses.worker)+int(losses.troop)+int(losses.hero)+int(losses.siege)
	play_metrics = {
		"tool": TOOL_VERSION,
		"plan": plan,
		"seed": run_seed,
		"game_seconds": l.elapsed,
		"stage_end": last_stage,
		"record_trust": record_trust,
		"trust_notes": trust_notes,
		"outcome": "victory" if (b.mission != null and b.mission.has_event("zhu_victory") and b.phase == b.Phase.END) \
			else ("timeout_game" if (l.elapsed >= 1600.0 and b.phase != b.Phase.END) \
			else ("hang" if hang_reason != "" else "defeat")),
		"hang_reason": hang_reason,
		"victory": b.mission != null and b.mission.has_event("zhu_victory") and b.phase == b.Phase.END,
		"defeat": b.phase == b.Phase.END and (b.mission == null or not b.mission.has_event("zhu_victory")) and hang_reason == "",
		"timeout": l.elapsed >= 1600.0 and b.phase != b.Phase.END and hang_reason == "",
		"events": events,
		"ledger": ledger,
		"ledger_valid": ledger_valid,
		"losses": losses,
		"orders": orders,
		"buildings_started": buildings_started,
		"units_queued": units_queued,
		"units_queued_by_key": units_queued_by_key,
		"ai_trained": l.ai_trained,
		"outpost_raids_total": l.raids_sent,
		"camp_hp_start": camp_hp_start,
		"camp_hp_min": camp_hp_min,
		"expansion_secured": l.expansion_secured,
		"supply_cut": l.supply_cut,
		"inside_open": l.inside_open,
		"main_breached": l.main_breached,
		"manor_fallen": l.manor_fallen,
		"prisoners_freed": l.prisoners_freed,
		"route_flags": route_flags,
		"route_ok": route_ok,
		"route_notes": route_notes,
		"summary_open": summary,
		"scope": "three-plan live replay tool v2; not human fun or optimal-strategy acceptance",
	}

func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var report := {
		"route": plan,
		"seed": run_seed,
		"tool": TOOL_VERSION,
		"passed": failures.is_empty() and record_trust and ledger_valid,
		"checks": checks,
		"failures": failures,
		"record_trust": record_trust,
		"metrics": play_metrics,
	}
	var fname := "%s_%d.json" % [plan, run_seed]
	if hang_reason != "":
		fname = "%s_%d_%s.json" % [plan, run_seed, hang_reason]
	var f = FileAccess.open(out_dir+"/"+fname, FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t")+"\n")
	f.close()
	print("[three-plans-result] ", JSON.stringify(report))

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	out_dir = "res://qa/zhujiazhuang_three_plans_20260914"
	if not OS.get_environment("RTS_TEST_OUT").is_empty():
		out_dir = OS.get_environment("RTS_TEST_OUT")
	var r = OS.get_environment("RTS_TEST_ROUTE")
	if r in ["plan_mine","plan_cut","plan_inside"]:
		plan = r
	else:
		plan = "plan_mine"
		print("[three-plans] unknown or empty RTS_TEST_ROUTE; defaulting to plan_mine")
	if not OS.get_environment("RTS_TEST_SEED").is_empty():
		run_seed = int(OS.get_environment("RTS_TEST_SEED"))
	if not OS.get_environment("RTS_TEST_WALL_SEC").is_empty():
		wall_limit = maxf(60.0, OS.get_environment("RTS_TEST_WALL_SEC").to_float())
	if not OS.get_environment("RTS_TEST_SPEED").is_empty():
		Engine.time_scale = maxf(1.0, OS.get_environment("RTS_TEST_SPEED").to_float())
		# 1600 game-seconds at this speed plus teardown buffer.
		var auto_wall := 1800.0 / Engine.time_scale + 120.0
		if OS.get_environment("RTS_TEST_WALL_SEC").is_empty():
			wall_limit = auto_wall
		else:
			wall_limit = maxf(wall_limit, auto_wall * 0.5)
	_reset_run_state()
	var b = await _start_plan()
	if b == null:
		failures.append("gameplay_rng_configure")
		record_trust = false
		trust_notes.append("failed to configure gameplay RNG")
		play_metrics = {"plan":plan,"seed":run_seed,"outcome":"start_fail","record_trust":false,"tool":TOOL_VERSION}
		_write_report()
		quit(1)
		return
	active_battle = b
	b.qa_resource_observer = _on_resource_event
	Engine.time_scale = 1.0
	if not OS.get_environment("RTS_TEST_SPEED").is_empty():
		Engine.time_scale = maxf(1.0, OS.get_environment("RTS_TEST_SPEED").to_float())
	_snap_opening(b)
	await _play_plan(b)
	# Write receipt BEFORE scene teardown so hang/crash still leaves evidence.
	check(rng_configured.get("ok") == true, "gameplay RNG fixed through production API")
	check(ledger_valid, "resource ledger reconciles income+refund-spend to balances")
	check(record_trust, "record trust retained")
	_write_report()
	await _dispose(b)
	active_battle = null
	Engine.time_scale = 1.0
	quit(0 if (failures.is_empty() and record_trust and ledger_valid) else 1)
