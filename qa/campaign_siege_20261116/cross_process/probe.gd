extends "res://tools/zhujiazhuang_rts_test.gd"
## Real orders around the installed save/restore transaction, in a private QA profile.

const CONTEXT := {"mode":"campaign", "level_id":"level3", "waves":0}
const HANDOFF := "user://zhu_evacuation_handoff.json"
var trusted: Dictionary
var runtime: Dictionary
var stage: String
var facts := {}

func _run() -> void:
	stage = OS.get_environment("ZHU_EVACUATION_STAGE")
	var sandbox := OS.get_environment("APPDATA").replace("\\", "/").simplify_path().to_lower()
	var data := OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower()
	if OS.get_environment("STEAM_DISABLED") != "1" or not sandbox.contains("/zhu-evacuation-") \
			or not data.begins_with(sandbox + "/"):
		quit(2)
		return
	if not check_gate(DisplayServer.get_name() != "headless", "native renderer available for fog capture"):
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false
	trusted = load("res://scripts/run_content_identity.gd").new().resolve_runtime_identity()
	if check_gate(trusted.get("ok",false) and trusted.get("save_eligible",false), "installed runtime identity"):
		facts["identity"] = trusted.content_version
		var prepared: Dictionary = load("res://scripts/run_level3_world_factory.gd").prepare_runtime(trusted)
		if check_gate(prepared.get("ok",false), "installed restore factory"):
			runtime = prepared.runtime
			match stage:
				"save": await _play_to_save()
				"resume": await _continue_evacuation(false)
				"victory": await _continue_evacuation(true)
				"reject": await _reject_finished_slot()
				_: check(false, "recognized stage")
	print("ZHU_EVACUATION_RESULT ",JSON.stringify({"stage":stage,"pid":OS.get_process_id(),
		"checks":checks,"failures":failures,"facts":facts}))
	root.get_node("Sfx").shutdown()
	root.get_node("Music").shutdown()
	quit(0 if failures.is_empty() else 1)

func check_gate(ok: bool, label: String) -> bool:
	check(ok,label)
	return ok

func _play_to_save() -> void:
	route = "inside"
	var b = await _start()
	await physics_frame
	await process_frame
	var fog_image: Image = b._fog_tex.get_image() if b._fog_tex != null else null
	if not check_gate(fog_image != null and fog_image.get_size() == b._vision_img.get_size(),
			"renderer provides the live fog texture"):
		await _dispose(b)
		return
	Engine.time_scale = 4.0
	await _play(b,true)
	if check_gate(b.level.supply_cut and b.level.inside_open and b.level.prisoners_freed \
			and b.level.manor_fallen and b.phase == b.Phase.FIGHT,
			"real attack cut support, opened the side gate, broke the manor and rescued the prisoners"):
		facts["orders"] = orders
		facts["units_queued"] = units_queued
		facts["buildings_started"] = buildings_started
		await _save_battle(b)
	await _dispose(b)

func _snapshot(b) -> Dictionary:
	var l = b.level
	var flights: Array = b.fx_root.get_children().filter(func(node):
		return node.get_script() != null and node.get_script().resource_path == "res://scripts/projectile.gd")
	return {"pid":OS.get_process_id(),"flags":[l.supply_cut,l.inside_open,l.prisoners_freed,l.manor_fallen,l.main_breached],
		"prisoners":l.prisoners.map(func(u): return str(u.entity_id) if alive(u) else ""),
		"gold":b.gold,"wood":b.wood,"elapsed":l.elapsed,"in_flight":flights.size()}

func _save_battle(b) -> void:
	Engine.time_scale = 1.0
	paused = true
	b._save_barrier.configure(b,b._run_clock,CONTEXT)
	var request: Dictionary = b._save_barrier.request_capture()
	if not check_gate(request.get("ok",false), "request capture"):
		facts["capture_error"] = request
		return
	for tick in range(240):
		if b._save_barrier.state == b._save_barrier.State.HELD: break
		await process_frame
	if not check_gate(b._save_barrier.state == b._save_barrier.State.HELD, "capture barrier held"): return
	var session = load("res://scripts/run_world_session.gd").new(trusted,runtime)
	var saved: Dictionary = session.save_held(b)
	if not check_gate(saved.get("ok",false), "installed transaction saved the living battle"):
		facts["save_error"] = saved
		return
	var store = load("res://scripts/run_slot_store.gd").new()
	var read: Dictionary = store.read_slot()
	if not check_gate(read.get("ok",false), "saved slot is readable"): return
	var handoff := _snapshot(b)
	handoff["slot_sha256"] = read.file_sha256
	handoff["generation"] = read.document.generation
	var file := FileAccess.open(HANDOFF,FileAccess.WRITE)
	if not check_gate(file != null, "handoff record opened"): return
	file.store_string(JSON.stringify(handoff))
	file.close()
	facts["checkpoint"] = handoff

func _prepare_session() -> Dictionary:
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	paused = true
	var session = load("res://scripts/run_world_session.gd").new(trusted,runtime)
	return {"session":session,"result":session.prepare_restore(menu)}

func _continue_evacuation(finish: bool) -> void:
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HANDOFF))
	var store = load("res://scripts/run_slot_store.gd").new()
	var read: Dictionary = store.read_slot()
	if not check_gate(previous.pid != OS.get_process_id() and read.get("ok",false) \
			and read.file_sha256 == previous.slot_sha256,"previous process and exact saved slot"): return
	var prepared := await _prepare_session()
	if not check_gate(prepared.result.get("ok",false),"independent restore prepared"):
		facts["restore_error"] = prepared.result
		return
	var restored: Dictionary = await prepared.session.commit_restore_async()
	if not check_gate(restored.get("ok",false),"independent restore committed"):
		facts["restore_error"] = restored
		return
	var b = restored.battle
	var l = b.level
	var before := _snapshot(b)
	check(before.flags == previous.flags and before.prisoners == previous.prisoners
		and before.gold == previous.gold and before.wood == previous.wood
		and is_equal_approx(before.elapsed,previous.elapsed),"route flags, original prisoners, economy and clock preserved")
	check(before.in_flight == previous.in_flight, "projectiles in flight preserved")
	check(l.prisoners.all(func(u): return not alive(u) or (u.faction == 0 and not u.is_captive)),
		"surviving prisoners still friendly and uncaged")
	check(b.mission.has_event("zhu_gate_opened") and b.mission.has_event("zhu_prisoners_freed")
		and b.mission.has_event("zhu_supply_cut"),"completed mission events preserved")

	var buttons := {}
	for child in b.mission._buttons.get_children():
		var info: Dictionary = child.get_meta("campaign_presentation_v1",{})
		if info.has("button_id"): buttons[info.button_id] = child
	if not check_gate(buttons.has_all(["zhu_select_shi_qian","zhu_select_rescued","zhu_find_camp_gold"]),
			"rescue and new camp gold buttons restored"):
		await _dispose(b)
		return
	paused = false
	Engine.time_scale = 4.0
	var deadline: float = l.elapsed + (150.0 if finish else 5.0)
	while l.elapsed < deadline and b.phase == b.Phase.FIGHT:
		var escort: Array = b.units.filter(func(u): return alive(u) and u.faction == 0 \
			and not u.is_worker and not u.is_building and not u.is_noncombat and u != l.song and u != l.sun)
		_click(b,escort,Vector2i(23,18),true)
		buttons.zhu_select_rescued.pressed.emit()
		_click(b,b.selection,l.CAMP+Vector2i(-4,0))
		if finish and l._finish_ready() and l.prisoners.all(func(u): return not alive(u) \
				or u.position.distance_to(l.hall.position) < 190.0):
			_action(b,l.song,"zhu_rts_finish")
		await _wait(2.0)
	if finish:
		check(b.phase == b.Phase.END and b.mission.has_event("zhu_victory"),"Song Jiang finishes after ordinary evacuation commands")
		var flow = root.get_node("ContinueFlow")
		check(flow.last_result.get("terminal_completed",false),"battle durably closes the local run")
		facts["result"] = b.mission.result_snapshot(true)
		facts["game_seconds"] = l.elapsed
	else:
		check(l.elapsed > previous.elapsed and orders > 0,"actual evacuation begins after first resume")
		await _save_battle(b)
	await _dispose(b)

func _reject_finished_slot() -> void:
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HANDOFF))
	var store = load("res://scripts/run_slot_store.gd").new()
	var before: Dictionary = store.read_slot()
	var attempt := await _prepare_session()
	var refusal: Dictionary = attempt.result
	facts["terminal_code"] = refusal.get("code","")
	check(not refusal.get("ok",false) and refusal.get("code","") == "LOCAL_RUN_TERMINAL",
		"an independent process rejects the old terminal slot")
	attempt.session.dispose()
	var after: Dictionary = store.read_slot()
	check(before.get("file_sha256","") == previous.slot_sha256 \
		and after.get("file_sha256","") == previous.slot_sha256,"refusal leaves the old slot bytes intact")
