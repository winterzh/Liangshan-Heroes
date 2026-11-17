extends "res://tools/daming_rts_test.gd"
## A live signal-route checkpoint through the private campaign menu.

const HANDOFF := "user://daming_menu_handoff.json"
const CONTEXT := {"mode":"campaign","level_id":"level8","waves":0}
var facts := {}
var stage: String
var flow: Node

func _run() -> void:
	stage = OS.get_environment("DAMING_MENU_STAGE")
	flow = root.get_node("ContinueFlow")
	if not flow._private_qa_enabled() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false
	route = "signal"
	build_cells = DAMING_BUILD_CELLS.duplicate()
	match stage:
		"save": await _save()
		"resume": await _resume()
		_:
			check(false,"known stage")
			_finish()

func _finish() -> void:
	print("DAMING_MENU_RESULT ",JSON.stringify({"stage":stage,"pid":OS.get_process_id(),
		"checks":checks,"failures":failures,"facts":facts}))
	if stage == "save" and failures.is_empty():
		return # SaveAndExit owns the successful application exit.
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
	return {"gate_open":l.gate_open,"prison_open":l.prison_open,"rescued":l.rescued,"signaled":l.signaled,
		"pursuit_warned":l.pursuit_warned,"pursuit_sent":l.pursuit_sent,"pursuit_left":l.pursuit_t,
		"pursuers":l.pursuit.map(_entity_id),"enemy_recruits":l.ai_trained,"hall":_entity_id(l.hall),
		"prisoners":[_entity_id(l.lu),_entity_id(l.shi)],"events":events,
		"gold":b.gold,"wood":b.wood,"clock":l.elapsed}

func _save() -> void:
	var b = await _start("",7)
	check(b.phase == b.Phase.FIGHT and b._official_context == CONTEXT,"normal Daming battle starts")
	Engine.time_scale = 4
	await _play_dm(b,true)
	var l = b.level
	check(b.phase == b.Phase.FIGHT and l.gate_open and l.prison_open and l.rescued and l.signaled
		and l.pursuit_warned and not l.pursuit_sent and l.pursuit_t > 0 and l.pursuit.any(alive)
		and not b.mission.has_event("daming_victory"),
		"actual signal, gate and rescue reach a live pursuit countdown before victory")
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
					"driver":{"buildings":buildings_started,"units":units_queued,"queue":units_queued_by_key,
						"orders":orders,"skills":skill_orders}}))
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
	check(is_equal_approx(float(state.clock),float(expected.clock)),"battle clock restored on the same checkpoint")
	state.erase("clock")
	expected.erase("clock")
	var mismatched: Array = expected.keys().filter(func(key): return state[key] != expected[key])
	if not mismatched.is_empty():
		facts["checkpoint_mismatch"] = mismatched.map(func(key): return [key,expected[key],state[key]])
	check(mismatched.is_empty(),"gate, original units, active pursuit countdown, economy and events survive exactly")
	var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
	check(slot.get("ok",false) and slot.file_sha256 == previous.sha,"reading preserves the slot bytes")
	_play_restored.call_deferred(b,previous.driver)

func _play_restored(b, driver: Dictionary) -> void:
	b._close_pause()
	var l = b.level
	var buttons: Array = b.mission._buttons.get_children().filter(func(node):
		return node.get_meta(b.mission.PRESENTATION_META,{}).get("button_id","") == "daming_select_wounded")
	check(not paused and buttons.size() == 1,"one wounded-prisoner button is available after closing pause")
	if buttons.size() == 1:
		var wounded: Array = l._wounded_group(b)
		var serials: Array = wounded.map(func(unit): return unit._order_serial)
		buttons[0].pressed.emit()
		check(not wounded.is_empty() and b.selection.size() == wounded.size()
			and wounded.all(func(unit): return unit in b.selection)
			and wounded.map(func(unit): return unit._order_serial) == serials,
			"restored locator selects the original wounded allies and issues no orders")
	buildings_started = driver.buildings
	units_queued = driver.units
	units_queued_by_key = driver.queue
	orders = driver.orders
	skill_orders = driver.skills
	Engine.time_scale = 4
	await _play_dm(b)
	facts["game_seconds_at_result"] = l.elapsed
	facts["pursuit_sent_before_result"] = l.pursuit_sent
	facts["live"] = play_metrics
	_finish()
