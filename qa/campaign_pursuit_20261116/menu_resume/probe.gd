extends "res://tools/jiangzhou_rts_play.gd"
## Play the actual story route and resume through the private campaign menu.

const HANDOFF := "user://jiangzhou_menu_handoff.json"
const CONTEXT := {"mode":"campaign","level_id":"level2","waves":0}
var facts := {}
var stage: String
var flow: Node

func _run() -> void:
	stage = OS.get_environment("JIANG_MENU_STAGE")
	flow = root.get_node("ContinueFlow")
	if not flow._private_qa_enabled() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false
	route = "story"
	match stage:
		"save": await _save()
		"resume": await _resume()
		_:
			check(false,"known stage")
			_finish()

func _finish() -> void:
	print("JIANG_MENU_RESULT ",JSON.stringify({"stage":stage,"pid":OS.get_process_id(),
		"checks":checks,"failures":failures,"facts":facts}))
	if stage == "save" and failures.is_empty():
		return # The SaveAndExit action owns the normal application exit.
	root.get_node("Sfx").shutdown()
	root.get_node("Music").shutdown()
	quit(0 if failures.is_empty() else 1)

func _clicked(owner: Node, name: String) -> bool:
	var button := owner.find_child(name,true,false) as Button
	var ready := button != null and button.is_visible_in_tree() and not button.disabled
	check(ready,"visible " + name + " button")
	if ready:
		button.pressed.emit()
	return ready

func _entity_id(unit) -> String:
	return str(unit.entity_id) if is_instance_valid(unit) else ""

func _checkpoint(b) -> Dictionary:
	var l = b.level
	var events: Array = b.mission.events.keys()
	events.sort()
	return {"meeting":l.meeting,"pursuit_sent":l.pursuit_sent,"rally":l.rally,
		"search_steps":l.pursuit_steps.duplicate(),"rear_contacts":l.pursuit_contacts.duplicate(),
		"pursuers":l.pursuit.map(_entity_id),"enemy_recruits":l.enemy_produced,
		"rescuees":[_entity_id(l.song_freed),_entity_id(l.dai_freed)],
		"crew":l.NAMED.map(func(key): return _entity_id(l.named_units.get(key))),
		"events":events,"gold":b.gold,"wood":b.wood,"clock":l.elapsed}

func _save() -> void:
	var b = await _start("",1)
	check(b.phase == b.Phase.FIGHT and b._official_context == CONTEXT,"normal Jiangzhou battle starts")
	Engine.time_scale = 4
	await _play_rescue(b,true)
	check(b.phase == b.Phase.FIGHT and b.level.meeting and b.level.pursuit_sent
		and b.mission.has_event("bailong") and b.mission.has_event("jiangzhou_rear_pursuit")
		and alive(b.level.song_freed) and alive(b.level.dai_freed) and not b.level.rally,
		"actual battle reaches the meeting after the pursuit starts and before any boarding")
	if not failures.is_empty():
		_finish()
		return
	Engine.time_scale = 1
	b._open_pause()
	flow.operation_finished.connect(_saved.bind(_checkpoint(b)),CONNECT_ONE_SHOT)
	if not _clicked(b.hud,"SaveAndExit"):
		_finish()

func _saved(result: Dictionary, state: Dictionary) -> void:
	facts["result_code"] = result.get("code","")
	check(result.get("ok",false),"pause-menu action commits a saved slot")
	if result.get("ok",false):
		var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
		check(slot.get("ok",false) and slot.document.context == CONTEXT,"disk slot stores the exact chapter context")
		if slot.get("ok",false):
			var file := FileAccess.open(HANDOFF,FileAccess.WRITE)
			check(file != null,"handoff created")
			if file != null:
				file.store_string(JSON.stringify({"pid":OS.get_process_id(),"state":state,"sha":slot.file_sha256,
					"driver":{"phase":phase,"route_index":route_index,"recruited":recruited,
						"max_troops":max_troops,"orders":orders,"skills":skill_orders}}))
				file.close()
				facts["generation"] = slot.document.generation
				facts["checkpoint"] = state
	_finish()

func _resume() -> void:
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HANDOFF))
	var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
	check(slot.get("ok",false) and slot.file_sha256 == previous.sha and OS.get_process_id() != previous.pid,
		"second process reads the exact checkpoint from disk")
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	flow.operation_finished.connect(_restored.bind(weakref(menu),previous),CONNECT_ONE_SHOT)
	if not _clicked(menu,"ContinueBattle"):
		_finish()

func _restored(result: Dictionary, menu: WeakRef, previous: Dictionary) -> void:
	facts["result_code"] = result.get("code","")
	check(result.get("ok",false) and menu.get_ref() == null,"main-menu action mounts the saved campaign")
	if not result.get("ok",false):
		_finish()
		return
	var b = current_scene
	check(b._official_context == CONTEXT and b.phase == b.Phase.FIGHT and paused,"restored chapter retains the paused battle")
	var state: Dictionary = JSON.parse_string(JSON.stringify(_checkpoint(b)))
	var expected: Dictionary = previous.state.duplicate()
	check(is_equal_approx(float(state.clock),float(expected.clock)),
		"battle clock restored on the same checkpoint")
	state.erase("clock")
	expected.erase("clock")
	var mismatched: Array = expected.keys().filter(func(key): return state[key] != expected[key])
	if not mismatched.is_empty():
		facts["checkpoint_mismatch"] = mismatched.map(func(key): return [key,expected[key],state[key]])
	check(mismatched.is_empty(),"meeting, pursuit, units, economy and events survive exactly")
	var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
	check(slot.get("ok",false) and slot.file_sha256 == previous.sha,"reading preserves the slot bytes")
	_play_restored.call_deferred(b,previous.driver)

func _play_restored(b, driver: Dictionary) -> void:
	b._close_pause()
	var buttons: Array = b.mission._buttons.get_children().filter(func(node):
		return node.get_meta(b.mission.PRESENTATION_META,{}).get("button_id","") == "jiang_bailong_meeting")
	check(not paused and buttons.size() == 1,"one White Dragon Temple button is available after closing pause")
	if buttons.size() == 1:
		var boatman = b.level.named_units.zhang_shun
		var serial: int = boatman._order_serial
		buttons[0].pressed.emit()
		check("会合已完成" in b.mission._status.text and boatman._order_serial == serial,
			"restored temple button reports completion without issuing an order")
	phase = driver.phase
	route_index = driver.route_index
	recruited = driver.recruited
	max_troops = driver.max_troops
	orders = driver.orders
	skill_orders = driver.skills
	Engine.time_scale = 4
	# Regroup any outlying ally through the west lane before telling them to board.
	for key in b.level.NAMED:
		var ally = b.level.named_units.get(key)
		if not alive(ally) or b.map.world_to_cell(ally.position).x <= 22: continue
		_click(b,[ally],b.level.WEST_ROUTE[1])
		for attempt in range(8):
			if not alive(ally) or b.map.world_to_cell(ally.position).x <= 21: break
			await _wait(1)
	await _play_rescue(b)
	facts["crew_outcomes"] = b.level.NAMED.map(func(key):
		var ally = b.level.named_units.get(key)
		return [key,str(ally.story_outcome) if is_instance_valid(ally) else "lost"])
	check(b.mission.has_event("all_embarked") and b.mission.has_event("jiangzhou_named_survive"),
		"continued combat evacuates both prisoners and all six named allies")
	facts["live"] = play_metrics
	_finish()
