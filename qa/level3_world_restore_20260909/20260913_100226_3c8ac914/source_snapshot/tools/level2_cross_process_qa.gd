extends Node
## Natural paid RTS rescue across seven independent processes.
## Uses actual movement, screen attacks, skills and queue_train; no teleport,
## stage mutation, fixture damage, direct victory call or accelerated clock.
const B := preload("res://scripts/battle.gd")
const Jiang := preload("res://scripts/levels/level2_jiangzhou_rts.gd")
const U := preload("res://scripts/unit.gd")
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Factory := preload("res://scripts/run_level2_world_factory.gd")
const Provider := preload("res://scripts/run_content_identity.gd")
const Session := preload("res://scripts/run_world_session.gd")
const Store := preload("res://scripts/run_slot_store.gd")
const SceneryState := preload("res://scripts/run_scenery_state.gd")
const CASES := ["level2_cross_save", "level2_cross_alarm", "level2_cross_rescue",
	"level2_cross_escort", "level2_cross_board", "level2_cross_finish", "level2_terminal_reject"]
const HANDOFF := "user://level2_handoff.json"
const SLOT_ROOT := "user://level2_continue/v1"

var checks: Array = []
var trusted: Dictionary = {}
var runtime: Dictionary = {}
var mode := ""
var report_path := ""
var nonce := ""
var handoff: Dictionary = {}
var lineage: Dictionary = {}
var observations: Array = []
var orders := 0
var held := false
var rejected := ""
var restored_session: RefCounted
const route := "story"
var phase := "approach"
var recruited := 0
var skill_orders := 0
var route_index := 0
var max_troops := 0
var resting := {}
var controller_seconds := 0.0
var next_log := 0.0

func check(label: String, passed: bool) -> bool:
	checks.append({"label": label, "passed": passed})
	if not passed: print("FAIL ", label)
	return passed

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var profile := OS.get_environment("LSH_LEVEL3_RESTORE_PROFILE").replace("\\", "/").simplify_path()
	var safe := profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path()
		safe = safe and path.to_lower() == (profile + "/" + key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(profile.to_lower() + "/appdata/")
	if not safe or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("CAMPAIGN_QA") != "1":
		print("LEVEL2_RESTORE_QA PRIVATE_PROFILE_REQUIRED")
		get_tree().quit(2)
		return
	report_path = OS.get_environment("LSH_LEVEL2_STATE")
	if report_path.is_empty(): report_path = OS.get_environment("LSH_LEVEL3_RESTORE_REPORT")
	mode = OS.get_environment("LSH_LEVEL2_CASE")
	nonce = OS.get_environment("LSH_LEVEL2_NONCE")
	run.call_deferred()

func run() -> void:
	print("JIANG_PROCESS_START ", mode, " pid=", OS.get_process_id())
	if not check("known process case and nonempty nonce", mode in CASES and not nonce.is_empty() and not report_path.is_empty()): finish(); return
	if not check("natural route uses normal time scale", is_equal_approx(Engine.time_scale, 1.0)): finish(); return
	trusted = Provider.new().resolve_runtime_identity()
	if not check("trusted runtime identity", trusted.get("ok", false) and trusted.get("save_eligible", false)): finish(); return
	var pack: Dictionary = Factory.prepare_runtime(trusted)
	if not check("Jiangzhou runtime prepared", pack.get("ok", false)): print(pack); finish(); return
	runtime = pack.runtime
	if mode == CASES[0]:
		var battle: Node = await _launch()
		if not check("real Jiangzhou battle launched", is_instance_valid(battle)): finish(); return
		await _initial(battle)
	else:
		var battle: Node = await _restore()
		if mode == CASES[6] or not is_instance_valid(battle): finish(); return
		get_tree().paused = false
		match mode:
			"level2_cross_alarm": await _alarm(battle)
			"level2_cross_rescue": await _rescue(battle)
			"level2_cross_escort": await _escort(battle)
			"level2_cross_board": await _board(battle)
			"level2_cross_finish": await _victory(battle)
	finish()

func _launch() -> Node:
	var campaign := get_node("/root/Campaign")
	var flags: Dictionary = Profiles.install_flags(Profiles.JIANG_ID)
	if not check("installed Jiangzhou launch flags", flags.get("ok", false)): return null
	for key: String in flags.flags: campaign.set(key, flags.flags[key])
	campaign.ai_friendly = false
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	menu._launch()
	for frame in range(180):
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene.get_script() == B: break
	var b: Node = get_tree().current_scene
	if b == null or b.get_script() != B or b.level.get_script() != Jiang: return null
	b.hud._intro_root.hide(); b.hud.intro_done.emit()
	if b.phase == B.Phase.DEPLOY: b.hud.start_battle.emit()
	for frame in range(12): await get_tree().physics_frame
	await get_tree().process_frame
	b._official_context = Profiles.JIANG_CONTEXT.duplicate(true)
	b._save_barrier.configure(b, b._run_clock, Profiles.JIANG_CONTEXT)
	return b

func _id(unit) -> String:
	return str(unit.entity_id) if is_instance_valid(unit) else ""

func _vec(value: Vector2) -> Variant:
	return [value.x, value.y] if value.is_finite() else "none"

func _state(b: Node) -> Dictionary:
	var value := {"level": {}, "mission": {}, "roles": {}, "units": [], "active": [], "selection": [],
		"gold": b.gold, "wood": b.wood, "kills": b.kills, "next_entity_id": str(b.next_entity_id), "next_tick": b._run_clock._next_tick}
	value.faction_res = b.faction_res.duplicate(true)
	for key in ["enemy_produced", "enemy_spent_gold", "enemy_spent_wood", "cache_taken", "alarm", "execution_halted", "pursuit_sent", "first_rescued", "meeting", "rally", "victory", "exec_left", "elapsed", "strategy_t", "train_left", "pursuit_left"]:
		var member = b.level.get(key)
		value.level[key] = member.duplicate(true) if member is Array or member is Dictionary else member
	for key in ["stage_id", "events", "active_action_id", "_progress", "_retry", "_generation"]:
		var member = b.mission.get(key)
		value.mission[key] = member.duplicate(true) if member is Dictionary or member is Array else member
	value.mission.actions = {}
	for key in b.mission.actions:
		var action: Dictionary = b.mission.actions[key]
		value.mission.actions[key] = {"done": action.done, "duration": action.duration, "cell": [action.cell.x, action.cell.y]}
	for key in ["post", "scaffold", "temple", "song_bound", "dai_bound", "song_freed", "dai_freed"]: value.roles[key] = _id(b.level.get(key))
	for key in ["camps", "caches", "executioners", "city_guards", "pursuit", "blockers", "towers", "reinforcements"]: value.roles[key] = b.level.get(key).map(func(u): return _id(u))
	value.roles.named_units = {}
	for key in b.level.named_units: value.roles.named_units[key] = _id(b.level.named_units[key])
	value.roles.departure_button = b.level.depart_button.get_meta("campaign_presentation_v1", {}) if is_instance_valid(b.level.depart_button) else null
	for unit in b.units_root.get_children():
		var row := {"id": _id(unit), "key": unit.key, "position": _vec(unit.position), "hp": unit.hp, "max_hp": unit.max_hp,
			"faction": unit.faction, "outcome": unit.story_outcome, "variant": unit.art_variant, "visible": unit.visible,
			"passive": unit.passive, "noncombat": unit.is_noncombat, "state": unit._state, "serial": unit._order_serial,
			"path_index": unit._path_i, "path": [], "intent_active": unit.mission_order_active,
			"intent_token": unit.mission_order_token, "intent_target": _vec(unit.mission_order_target),
			"manual_active": unit.manual_order_active, "manual_time": unit.manual_order_t,
			"pose": unit.get_meta("story_pose", ""), "pose_time": unit._story_pose_t, "stun_time": unit._stun_t,
			"speed_multiplier": unit.temp_speed, "speed_duration": unit._temp_speed_t,
			"assist_partner": _id(unit.story_assist_partner), "assist_owner": _id(unit.story_assist_owner)}
		row.queue = unit._train_queue.duplicate()
		row.train_time = unit._train_t
		row.rally = _vec(unit.rally); row.has_rally = unit.has_rally
		row.dying = unit._dying; row.death_time = unit._death_t; row.target = _id(unit._target)
		row.summon = unit.is_summon; row.summon_kind = unit.summon_kind; row.summon_ttl = unit._summon_ttl
		row.abilities = unit.ability_slots.duplicate(true)
		row.hero = unit.is_hero; row.attack = unit.atk
		for point in unit._path: row.path.append(_vec(point))
		value.units.append(row)
	for unit in b.units: value.active.append(_id(unit))
	for unit in b.selection: value.selection.append(_id(unit))
	return JSON.parse_string(JSON.stringify(value))

func _controller() -> Dictionary:
	return {"phase": phase, "recruited": recruited, "skill_orders": skill_orders, "route_index": route_index, "max_troops": max_troops, "resting": resting, "seconds": controller_seconds}

func _restore_controller(value: Dictionary) -> void:
	phase = value.phase; recruited = int(value.recruited); skill_orders = int(value.skill_orders)
	route_index = int(value.route_index); max_troops = int(value.max_troops)
	resting = value.resting.duplicate(true); controller_seconds = value.seconds

func _audit_roles(b: Node) -> void:
	var l: Variant = b.level
	var ids: Array = b.units_root.get_children().map(func(u): return _id(u))
	var unique := {}
	for id in ids: unique[id] = true
	check("every root entity has one unique identity", ids.size() == unique.size())
	check("original paid camps retained", l.camps.map(func(u): return _id(u)) == lineage.camps)
	check("original named heroes survive with original identities", l.NAMED.all(func(key): return is_instance_valid(l.named_units.get(key)) and l.named_units[key].hp > 0 and _id(l.named_units[key]) == lineage.named_units[key]))
	for name in ["song", "dai"]:
		var bound: Variant = l.get(name + "_bound")
		var freed: Variant = l.get(name + "_freed")
		if is_instance_valid(freed):
			check(name + " original bound entity replaced exactly once", not is_instance_valid(bound) and not ids.has(lineage[name + "_bound"]) and _id(freed) == lineage[name + "_freed"] and _id(freed) != lineage[name + "_bound"])
			check(name + " freed identity remains unarmed", freed.is_noncombat and not freed.is_hero and freed.atk == 0 and freed.art_variant == freed.key + "_rescued")
		else: check(name + " original captive retained", _id(bound) == lineage[name + "_bound"])
	check("paid enemy production finite and role count conserved", l.enemy_produced <= 8 and l.reinforcements.size() == l.enemy_produced and l.enemy_spent_gold >= 0 and l.enemy_spent_wood >= 0)
	check("natural route retains optional named story goals", not b.mission.has_event("jiangzhou_other_first") and not b.mission.has_event("jiangzhou_named_lost"))

func _on_held(_clock: Dictionary) -> void: held = true
func _on_rejected(code: String) -> void: rejected = code

func _save_next(b: Node) -> void:
	if not b._save_barrier.capture_ready.is_connected(_on_held): b._save_barrier.capture_ready.connect(_on_held)
	if not b._save_barrier.capture_rejected.is_connected(_on_rejected): b._save_barrier.capture_rejected.connect(_on_rejected)
	held = false; rejected = ""
	get_tree().paused = true
	var requested: Dictionary = b._save_barrier.request_capture()
	if not check("real pause capture requested", requested.get("ok", false)): print(requested); return
	for frame in range(180):
		await get_tree().process_frame
		if held or not rejected.is_empty(): break
	if not check("save barrier held healthy", held and rejected.is_empty() and b._save_barrier.state == b._save_barrier.State.HELD and b._save_barrier.health().ok):
		print("JIANG_BARRIER_FAILED ", rejected, " ", b._save_barrier.health()); return
	var saver := Session.new(trusted, runtime, SLOT_ROOT)
	var saved: Dictionary = saver.save_held(b)
	if not check("full Session save succeeds", saved.get("ok", false)): print("JIANG_SAVE_FAILED ", saved); return
	var display: Dictionary = SceneryState.new(trusted.content_version, Profiles.JIANG_CONTEXT).capture(b.map)
	if not check("trusted Jiangzhou scenery captured", display.get("ok", false)): print(display); return
	check("chapter-specific scenery schema", display.value.schema == "level2_scenery_state_v1")
	check("Huang adapter rejects Jiangzhou scenery", not SceneryState.new(trusted.content_version, Profiles.HG_CONTEXT).validate(display.value).ok)
	_audit_roles(b)
	var state := _state(b)
	observations.append({"saved": state})
	var file := FileAccess.open(HANDOFF, FileAccess.WRITE)
	if not check("handoff writable", file != null): return
	file.store_string(JSON.stringify({"pid": OS.get_process_id(), "nonce": nonce, "mode": mode,
		"sha256": saved.file_sha256, "state": state, "display": display.value, "lineage": lineage,
		"content_version": trusted.content_version, "controller": _controller()})); file.close()
	await _shot(b, "_saved")
	b.queue_free(); await get_tree().process_frame

func _restore() -> Node:
	var file := FileAccess.open(HANDOFF, FileAccess.READ)
	if not check("previous process handoff exists", file != null): return null
	var decoded = JSON.parse_string(file.get_as_text()); file.close()
	if not check("handoff fields valid", decoded is Dictionary and decoded.has_all(["pid", "nonce", "mode", "sha256", "state", "display", "lineage", "content_version", "controller"])): return null
	handoff = decoded
	lineage = handoff.lineage.duplicate(true)
	_restore_controller(handoff.controller)
	if not check("distinct process identity and nonce", handoff.pid != OS.get_process_id() and handoff.nonce != nonce and not String(handoff.nonce).is_empty()): return null
	var preceding: String = CASES[4] if mode == CASES[6] else CASES[CASES.find(mode) - 1]
	if not check("correct preceding checkpoint", handoff.mode == preceding): return null
	if not check("same frozen production version", handoff.content_version == trusted.content_version): return null
	var slot: Dictionary = Store.new(SLOT_ROOT).read_slot()
	if not check("same saved slot bytes", slot.get("ok", false) and slot.file_sha256 == handoff.sha256): return null
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	get_tree().paused = true
	restored_session = Session.new(trusted, runtime, SLOT_ROOT)
	var prepared: Dictionary = restored_session.prepare_restore(menu)
	if mode == CASES[6]:
		check("victory rejects pre-terminal slot specifically", not prepared.ok and prepared.get("code", "") == "LOCAL_RUN_TERMINAL")
		check("menu retained after terminal refusal", get_tree().current_scene == menu and is_instance_valid(menu))
		observations.append({"terminal_refusal": prepared})
		restored_session.dispose(); return null
	if not check("Session prepare succeeds", prepared.get("ok", false)): print("JIANG_PREPARE_FAILED ", prepared); restored_session.dispose(); return null
	var installed: Dictionary = await restored_session.commit_restore_async()
	if not check("Session commit succeeds", installed.get("ok", false)): print("JIANG_COMMIT_FAILED ", installed); restored_session.dispose(); return null
	var b: Node = installed.battle
	check("restored paused without advancing", get_tree().paused and b.phase == B.Phase.FIGHT and b.level.get_script() == Jiang)
	var actual := _state(b)
	for key in handoff.state:
		if not check("restored " + key + " matches disk", actual.get(key) == handoff.state[key]):
			print("JIANG_STATE_MISMATCH ", key, " saved=", handoff.state[key], " actual=", actual.get(key))
	var display: Dictionary = SceneryState.new(trusted.content_version, Profiles.JIANG_CONTEXT).capture(b.map)
	check("scenery nodes and materials match disk", display.get("ok", false) and display.value == handoff.display)
	check("restored scenery activated", not b.map.sample_scenery.is_blocking_signals())
	_audit_roles(b)
	observations.append({"restored": actual})
	await _shot(b, "_restored")
	return b

func alive(unit) -> bool:
	return is_instance_valid(unit) and unit.hp > 0 and unit.story_outcome == ""

func _click(b, members: Array, cell: Vector2i, attack_move := false) -> void:
	var live: Array = members.filter(func(u): return alive(u))
	if live.is_empty(): return
	b.select_members(live, false); b.minimap_order(b.map.cell_to_world(cell), attack_move)
	orders += 1

func _action(b, actor, action_id: String) -> void:
	if not alive(actor) or not b.mission.actions.has(action_id): return
	if b.mission.actions[action_id].done or b.mission.active_action_id == action_id: return
	_click(b, [actor], b.mission.actions[action_id].cell)

func _reinforce(b) -> void:
	for camp in b.level.camps:
		if not alive(camp) or not camp._train_queue.is_empty(): continue
		var key: String=["liang_qiang","liang_gong","liang_dao"][recruited%3]
		_click(b,[camp],Vector2i(22,28) if phase in ["approach","cache","fight","rescue"] else Vector2i(20,38))
		if b.queue_train(camp,key,false): recruited+=1
	for u in b.units:
		if alive(u) and u.faction==0 and u.is_hero:
			for slot in range(4):
				if u.can_learn(slot): u.learn(slot)
func _attack(b,army: Array,foe,cell: Vector2i) -> void:
	if army.is_empty(): return
	if alive(foe) and b.is_visible_world(foe.position):
		b.select_members(army,false); b._issue_order(b.to_screen(foe.position),false); orders+=1
	else: _click(b,army,cell,true)
func _skills(b,army: Array) -> void:
	for u in army:
		if not u.is_hero or u._cast_t>0: continue
		var foes: Array=b.units.filter(func(v): return alive(v) and v.faction==1 and not v.is_building and b.is_visible_world(v.position) and u.position.distance_to(v.position)<200)
		if foes.is_empty(): continue
		for slot in [0,1,3]:
			if slot>=u.slot_count() or not u.slot_ready(slot): continue
			b.select_members([u],false); b._cast_ability_slot(slot)
			if b._ability_armed!="": b._cast_armed_at(b.to_screen(foes[0].position))
			skill_orders+=1; break
func _drive_step(b: Node) -> void:
	var l: Variant = b.level
	_reinforce(b)
	var army: Array=b.units.filter(func(u): return alive(u) and u.faction==0 and not u.is_building and not u.is_worker and not u.is_noncombat)
	max_troops=maxi(max_troops,army.filter(func(u): return u.key in ["liang_dao","liang_qiang","liang_gong","liang_ma"]).size())
	if phase in ["approach","cache","fight","rescue"]: army=army.filter(func(u): return u.key not in ["zhang_shun","zhang_heng"])
	if route=="story" and phase in ["fight","rescue"]:
		for u in army.duplicate():
			if u.key not in l.NAMED or u.is_summon: continue
			var retreat_at: float=0.85 if u.key=="li_kui" else (0.65 if u.key=="hua_rong" else 0.5)
			if u.hp<u.max_hp*retreat_at: resting[u.key]=true
			if u.hp>u.max_hp*0.95: resting.erase(u.key)
			if resting.has(u.key):
				army.erase(u); _click(b,[u],Vector2i(21,28))
	if phase=="approach":
		var staging: Array=army.filter(func(u): return route!="story" or u.key not in ["li_kui","yan_shun"])
		_click(b,staging,Vector2i(22,28))
		var ready: bool=army.filter(func(u): return u.key in ["liang_dao","liang_qiang","liang_gong","liang_ma"]).size()>=(12 if route=="story" else 10)
		if route=="story":
			_click(b,[l.named_units.get("hua_rong")],Vector2i(20,28))
			_action(b,l.named_units.get("li_kui"),"west_street")
			_action(b,l.named_units.get("yan_shun"),"south_lane")
			if ready and b.mission.actions.has("first_axes"):
				var li=l.named_units.get("li_kui")
				var western: Array=l.city_guards.filter(func(u): return alive(u) and u.position.distance_to(l.caches[0].position)<230)
				western.sort_custom(func(a,z): return li.position.distance_to(a.position)<li.position.distance_to(z.position))
				if not western.is_empty(): _attack(b,[li],western[0],b.map.world_to_cell(western[0].position))
			if l.alarm: phase="cache"
		elif ready: phase="cache"
	if phase=="cache":
		if route=="story":
			var yan=l.named_units.get("yan_shun")
			army.erase(yan)
			if alive(yan): _click(b,[yan],Vector2i(21,28)) # Leave the cavalry lane as soon as the signal is given.
		var cache_foes: Array=b.units.filter(func(u): return alive(u) and u.faction==1 and not u.is_building and u.position.distance_to(l.caches[0].position)<230)
		if not cache_foes.is_empty():
			_attack(b,army,cache_foes[0],b.map.world_to_cell(cache_foes[0].position))
			_skills(b,army)
		else:
			var collector=l.named_units.get("chao_gai")
			_click(b,army.filter(func(u): return u!=collector),Vector2i(21,28))
			_action(b,collector,"cache_0")
		if l.cache_taken[0]: phase="fight"
	if phase=="fight":
		var foes: Array=l.executioners.filter(func(u): return alive(u))
		if not foes.is_empty(): _attack(b,army,foes[0],l.SCAFFOLD)
		_skills(b,army)
		if l.execution_halted: phase="rescue"
	if phase=="rescue":
		if route=="story" and alive(l.towers[0]):
			var guards: Array=b.units.filter(func(u): return alive(u) and u.faction==1 and not u.is_building and u.position.distance_to(b.map.cell_to_world(Vector2i(29,23)))<270)
			guards.sort_custom(func(a,z): return a.position.distance_to(b.map.cell_to_world(Vector2i(29,25)))<z.position.distance_to(b.map.cell_to_world(Vector2i(29,25))))
			if not guards.is_empty():
				_attack(b,army,guards[0],b.map.world_to_cell(guards[0].position)); _skills(b,army)
				return
		# Stop execution first, then clear the actual arrow fire covering
		# the scaffold before exposing the unarmed prisoners.
		if alive(l.towers[0]):
			_attack(b,army,l.towers[0],b.map.world_to_cell(l.towers[0].position))
			_skills(b,army)
			return
		var rescuer=l.named_units.get("chao_gai")
		if not alive(rescuer) or rescuer not in army: rescuer=army[0] if not army.is_empty() else null
		if alive(rescuer):
			army.erase(rescuer)
			_action(b,rescuer,"free_song" if l.song_freed==null else "free_dai")
		var foes: Array=b.units.filter(func(u): return alive(u) and u.faction==1 and not u.is_building)
		foes.sort_custom(func(a,z): return a.position.distance_to(b.map.cell_to_world(l.SCAFFOLD))<z.position.distance_to(b.map.cell_to_world(l.SCAFFOLD)))
		_attack(b,army,foes[0] if not foes.is_empty() else null,l.SCAFFOLD+Vector2i(0,3))
		_skills(b,army)
		if alive(l.song_freed) and alive(l.dai_freed):
			phase="escape"
	if phase=="escape":
		if route=="story":
			var boatmen: Array=[l.named_units.zhang_shun,l.named_units.zhang_heng].filter(func(u): return alive(u))
			for u in boatmen: army.erase(u)
			_click(b,boatmen,l.BAILONG)
		var points: Array=l.WEST_ROUTE if route=="story" else l.SOUTH_ROUTE
		var dest: Vector2i=points[mini(route_index,points.size()-1)]
		var pair: Array=[l.song_freed,l.dai_freed].filter(func(u): return alive(u))
		if pair.size() != 2: return
		var center: Vector2=b.map.cell_to_world(dest)
		var close: Array=b.units.filter(func(u): return alive(u) and u.faction==1 and (not u.is_building or u.atk>0) and (u.position.distance_to(center)<240 or pair.any(func(p): return p.position.distance_to(u.position)<220)))
		var rear_threats: Array=close.filter(func(u): return pair.any(func(p): return p.position.distance_to(u.position)<220))
		rear_threats.sort_custom(func(a,z): return a.position.distance_to(pair[0].position)<z.position.distance_to(pair[0].position))
		close.sort_custom(func(a,z): return a.position.distance_to(center)<z.position.distance_to(center))
		if not rear_threats.is_empty():
			_attack(b,army,rear_threats[0],b.map.world_to_cell(rear_threats[0].position))
		else: _attack(b,army,close[0] if not close.is_empty() else null,dest)
		_skills(b,army)
		if close.is_empty():
			_click(b,pair,dest)
			if pair.size()==2 and pair.all(func(u): return u.position.distance_to(center)<90): route_index+=1
		else:
			b.select_members(pair,false); b._order_stop()
		if route_index>=points.size():
			if route=="story" and not l.meeting and alive(l.named_units.zhang_shun) and alive(l.named_units.zhang_heng):
				_click(b,[l.named_units.get("zhang_shun"),l.named_units.get("zhang_heng")].filter(func(u): return alive(u)),l.BAILONG)
			else:
				phase="boarding"
	if phase=="boarding":
		# Keep the passenger landing clear. Real guards form a rear line;
		# named heroes withdraw only after the player orders collection.
		var named: Array=army.filter(func(u): return u==l.named_units.get(u.key))
		_click(b,army.filter(func(u): return u not in named),Vector2i(15,46))
		for u in named: _click(b,[u],l.DOCK+Vector2i(0,-2))
		if route=="story":
			var leader=l.named_units.get("chao_gai")
			if not alive(leader): leader=army[0] if not army.is_empty() else null
			_action(b,leader,"rally_dock")
		_action(b,l.song_freed,"board_song")
		if mode == "level2_cross_finish": _action(b,l.dai_freed,"board_dai")
		if mode == "level2_cross_finish" and is_instance_valid(l.depart_button):
			var all_safe: bool=l.NAMED.all(func(key):
				var u=l.named_units.get(key)
				return u!=null and u.story_outcome=="embarked")
			if all_safe: l.depart_button.pressed.emit()

func _drive(b: Node, predicate: Callable, seconds: float) -> bool:
	var start_tick: int = b._run_clock._next_tick
	var deadline: int = Time.get_ticks_msec() + 390000
	while not predicate.call() and b.phase == B.Phase.FIGHT and (b._run_clock._next_tick - start_tick) / 60.0 < seconds and Time.get_ticks_msec() < deadline:
		_drive_step(b)
		if predicate.call(): break
		var tick: int = b._run_clock._next_tick
		while b.phase == B.Phase.FIGHT and b._run_clock._next_tick - tick < 60 and not predicate.call() and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		controller_seconds += (b._run_clock._next_tick - tick) / 60.0
		if controller_seconds >= next_log:
			print("JIANG_ROUTE ", mode, " seconds=", controller_seconds, " phase=", phase, " exec=", b.level.exec_left, " gold/wood=", [b.gold, b.wood], " recruits=", recruited, " active_action=", b.mission.active_action_id, " pair=", [b.level.song_freed,b.level.dai_freed].map(func(u): return [u.hp,b.map.world_to_cell(u.position),u.story_outcome] if is_instance_valid(u) else []))
			next_log = controller_seconds + 20.0
	return bool(predicate.call())

func _initial(b: Node) -> void:
	var l: Variant = b.level
	lineage = {"camps": l.camps.map(func(u): return _id(u)), "named_units": {}, "song_bound": _id(l.song_bound), "dai_bound": _id(l.dai_bound), "song_freed": "", "dai_freed": ""}
	for key in l.named_units: lineage.named_units[key] = _id(l.named_units[key])
	if not check("actual finite-economy rescue launched", b.economy and not b._smoke and not l.alarm and b.gold == 190 and b.wood == 120): return
	var li_origin: Vector2 = l.named_units.li_kui.position
	if not check("real paid queues and actual approach travel begin", await _drive(b, func(): return recruited >= 2 and l.camps.any(func(u): return not u._train_queue.is_empty() and u._train_t > 0) and l.named_units.li_kui.position.distance_to(li_origin) > 35, 6)): await _failure(b, "initial_training"); return
	check("initial checkpoint retains bound prisoners and deadline", not l.alarm and not l.execution_halted and l.exec_left > 0 and l.exec_left < l.DEADLINE and not l.first_rescued)
	check("two camps spent actual shared funds", b.gold < 190 and b.wood < 120)
	await _save_next(b)

func _alarm(b: Node) -> void:
	var l: Variant = b.level
	if not check("real two-route uprising and first supply completed", await _drive(b, func(): return l.alarm and l.cache_taken[0], 145)): await _failure(b, "uprising_cache"); return
	check("Li Kui actually led both signalled approaches", b.mission.has_event("west_street") and b.mission.has_event("south_lane") and b.mission.has_event("jiangzhou_li_first"))
	check("only first cache claimed and prisoners remain bound", l.cache_taken == [true, false] and not l.first_rescued and is_instance_valid(l.song_bound) and is_instance_valid(l.dai_bound))
	check("ordinary troops were paid and fielded", recruited >= 6 and max_troops >= 12)
	await _save_next(b)

func _rescue(b: Node) -> void:
	var l: Variant = b.level
	if not check("real combat stops execution and first separate unbinding", await _drive(b, func(): return alive(l.song_freed), 165)): await _failure(b, "first_rescue"); return
	lineage.song_freed = _id(l.song_freed)
	check("one real replacement before second rescue and pursuit release", l.execution_halted and not is_instance_valid(l.song_bound) and is_instance_valid(l.dai_bound) and not is_instance_valid(l.dai_freed) and l.first_rescued and not l.pursuit_sent and l.pursuit_left > 0)
	check("scaffold arrow tower cleared by real attacks", not alive(l.towers[0]))
	await _save_next(b)

func _escort(b: Node) -> void:
	var l: Variant = b.level
	if not check("second unbinding and real westward escorted travel", await _drive(b, func(): return alive(l.dai_freed) and l.pursuit_sent and phase == "escape" and not l.meeting and l.song_freed.position.distance_to(b.map.cell_to_world(l.SCAFFOLD)) > 100 and l.dai_freed.position.distance_to(b.map.cell_to_world(l.SCAFFOLD)) > 100, 130)): await _failure(b, "westward_escort"); return
	lineage.dai_freed = _id(l.dai_freed)
	check("north reserve released by actual warning", l.pursuit_sent and b.mission.has_event("jiangzhou_rear_pursuit"))
	# The enemy pool receives normal gold bounty from player-unit deaths, so
	# its net gold can return to the initial 160 after actual paid production.
	# Validate cumulative purchases and wood (which has no bounty) instead.
	# Reinforcement roles retain dead slots; living count is not purchase count.
	var archers: int = floori(float(l.enemy_produced) / 3.0)
	var swords: int = l.enemy_produced - archers
	var expected_gold: int = swords * int(b._defs.liang_dao.cost_gold) + archers * int(b._defs.liang_gong.cost_gold)
	var expected_wood: int = swords * int(b._defs.liang_dao.cost_wood) + archers * int(b._defs.liang_gong.cost_wood)
	check("paid finite patrol reinforcements existed during rescue", l.enemy_produced > 0 and l.enemy_produced <= 8 and l.reinforcements.size() == l.enemy_produced and l.enemy_spent_gold == expected_gold and l.enemy_spent_wood == expected_wood and b.faction_wood(1) == 100.0 - expected_wood)
	check("both free goals earned while neither is boarded", b.mission.has_event("free_song") and b.mission.has_event("free_dai") and l.song_freed.story_outcome == "" and l.dai_freed.story_outcome == "")
	await _save_next(b)

func _board(b: Node) -> void:
	var l: Variant = b.level
	if not check("real Bailong meeting then first passenger boarding", await _drive(b, func(): return is_instance_valid(l.song_freed) and l.song_freed.story_outcome == "embarked", 210)): await _failure(b, "first_boarding"); return
	check("both prisoners met both boatmen before boarding", l.meeting and b.mission.has_event("bailong"))
	check("first passenger hidden but retained and second awaits boarding", b.units.has(l.song_freed) and not l.song_freed.visible and l.song_freed.get_parent() == b.units_root and alive(l.dai_freed) and b.units.has(l.dai_freed) and not is_instance_valid(l.depart_button))
	await _save_next(b)

func _victory(b: Node) -> void:
	var l: Variant = b.level
	if not check("second passenger and named heroes board before real departure button", await _drive(b, func(): return l.victory, 150)): await _failure(b, "actual_departure"); return
	for frame in range(180):
		if b._continue_receipt != null and b._continue_receipt._committed_terminal and b.hud._end_root.visible: break
		await get_tree().process_frame
	check("durable terminal lifecycle precedes real result panel", b._continue_receipt != null and b._continue_receipt._committed_terminal and b.hud._end_root.visible)
	check("eight actual survivors embarked", [l.song_freed,l.dai_freed].all(func(u): return is_instance_valid(u) and u.hp > 0 and u.story_outcome == "embarked") and l.NAMED.all(func(key): return is_instance_valid(l.named_units.get(key)) and l.named_units[key].hp > 0 and l.named_units[key].story_outcome == "embarked"))
	check("actual all-embarked events and terminal phase", b.phase == B.Phase.END and b.mission.has_event("all_embarked") and b.mission.has_event("jiangzhou_named_survive"))
	_audit_roles(b)
	var result: Dictionary = b.mission.result_snapshot(true)
	check("all four story goals earned through real player route", result.story_complete and result.story_done == 4 and result.story_total == 4)
	observations.append({"victory": _state(b), "result": result, "controller": _controller()})
	await _shot(b, "_victory")
	# Keep process five's slot unchanged for process seven's terminal rejection.
	b.queue_free(); await get_tree().process_frame

func _failure(b: Node, label: String) -> void:
	observations.append({"failure": label, "state": _state(b)})
	print("JIANG_ROUTE_FAILED ", label, " state=", _state(b))
	await _shot(b, "_failure")

func _shot(b: Node, suffix: String) -> void:
	var patient: Node = b.level.song_freed if is_instance_valid(b.level.song_freed) else b.level.song_bound
	if is_instance_valid(patient): b.center_camera_cell(b.map.world_to_cell(patient.position))
	b.camera.force_update_scroll()
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	if b.phase == B.Phase.FIGHT:
		check("selection controls restored command panel", b.hud._bottom_collapsed == b.selection.is_empty())
		if b.hud.msg_box.visible: check("paused message stays above command panel", b.hud.msg_box.get_global_rect().end.y <= b.hud._bottom_panel.get_global_rect().position.y - 6.0)
	check("native viewport screenshot " + suffix, get_viewport().get_texture().get_image().save_png(report_path.get_basename() + suffix + ".png") == OK)

func finish() -> void:
	var passed := not checks.is_empty() and checks.all(func(c): return c.passed)
	var report := {"passed": passed, "checks": checks, "pid": OS.get_process_id(), "mode": mode,
		"chapter": "level2", "full_world": true, "observations": observations, "orders": orders,
		"actor_teleports": 0, "stage_injections": 0, "clock_acceleration": false,
		"previous_pid": handoff.get("pid", 0), "process_nonce": nonce, "lineage": lineage, "controller": _controller(),
		"scope": "real paid RTS reinforcement, uprising, separate prisoner replacements, west-road Bailong meeting and eight survivors boarding; no fixture combat or direct victory call"}
	var file := FileAccess.open(report_path, FileAccess.WRITE) if not report_path.is_empty() else null
	if file == null:
		print("JIANG_REPORT_WRITE_FAILED ", report_path)
		passed = false
	else:
		file.store_string(JSON.stringify(report, "\t")); file.close()
	print("LEVEL2_CROSS_PROCESS_QA_COMPLETE ", mode, " ", checks.size(), " ", passed)
	get_node("/root/Sfx").shutdown(); get_node("/root/Music").shutdown()
	get_tree().quit(0 if passed else 1)
