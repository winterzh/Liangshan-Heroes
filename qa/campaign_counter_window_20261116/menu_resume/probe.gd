extends "res://tools/kuaihuolin_short_test.gd"
## Save a real opening after completing the footwork for the counter.

const HANDOFF := "user://kh_menu_handoff.json"
const CONTEXT := {"mode":"campaign","level_id":"level7","waves":0}
var facts := {}
var stage: String
var flow: Node
var reached := false

func _run() -> void:
	stage = OS.get_environment("KH_MENU_STAGE")
	flow = root.get_node("ContinueFlow")
	if not flow._private_qa_enabled() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false
	match stage:
		"save": await _save()
		"resume": await _resume()
		_:
			check(false,"known stage")
			_finish()

func _finish() -> void:
	print("KH_MENU_RESULT ",JSON.stringify({"stage":stage,"pid":OS.get_process_id(),
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

func _start(mode := "", index := 2):
	var b = await super._start(mode,index)
	Engine.time_scale = execution_speed
	return b

func _checkpoint(b) -> Dictionary:
	var l = b.level
	var events: Array = b.mission.events.keys()
	events.sort()
	var window: Dictionary = l.counter_window_state(b)
	window.erase("position")
	return {"wu":_entity_id(l.wu),"shi":_entity_id(l.shi),"menshen":_entity_id(l.menshen),
		"drunk":l.drunk,"steady_left":l.steady_left,"speed_band":[l.wu._drunk_lo,l.wu._drunk_hi],
		"opening_serial":l.opening_serial,"step_serial":l.step_serial,"counter_hits":l.counter_hits,
		"hp":[l.wu.hp,l.shi.hp,l.menshen.hp],"window":window,"events":events,"clock":b.mission.total_game_seconds}

func _save() -> void:
	await _live("wine",_save_opening)
	if not reached:
		check(false,"the wine route must reach a live counter opening")
		_finish()

func _save_opening(b) -> void:
	reached = true
	var l = b.level
	check(b.phase == b.Phase.FIGHT and b._official_context == CONTEXT and l.drunk == 4
		and l.heavy_dodges + l.rush_dodges > 0,"wine and an actual missed attack create a live counter opening")
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
					"driver":{"orders":orders,"cast_counts":cast_counts,"charge_travel":charge_travel,"min_hp":min_hp}}))
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
	check(mismatched.is_empty(),"wine state, footwork, opening timer, participants and events survive exactly")
	var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
	check(slot.get("ok",false) and slot.file_sha256 == previous.sha,"reading preserves the slot bytes")
	_play_restored.call_deferred(b,previous.state,previous.driver)

func _play_restored(b, state: Dictionary, driver: Dictionary) -> void:
	b._close_pause()
	Engine.time_scale = execution_speed
	orders = int(driver.orders)
	cast_counts.clear()
	for slot in driver.cast_counts:
		cast_counts[int(slot)] = int(driver.cast_counts[slot])
	charge_travel = float(driver.charge_travel)
	min_hp = float(driver.min_hp)
	var l = b.level
	var window: Dictionary = l.counter_window_state(b)
	check(not paused and not window.is_empty() and window.footwork and window.in_range,"the restored opening remains playable immediately")
	check(window.get("kick_cooldown",-1) == 0.0 and l.wu.slot_ready(2)
		and "鸳鸯脚已就绪" in l.unit_tactical_hint(b,l.wu),
		"the inspector says the available kick is ready instead of showing its base cooldown")
	var used := await _cast(b,2)
	var hit := await _until(func(): return l.counter_hits > int(state.counter_hits),1.0)
	check(used and hit and l.opening_serial == int(state.opening_serial) and b.mission.has_event("mengzhou_signature"),
		"a normal kick lands in the same opening and earns the footwork signature")
	var cooldown: float = l.counter_window_state(b).get("kick_cooldown",0.0)
	check(cooldown > 0.0 and is_equal_approx(cooldown,float(l.wu.ability_slots[2].cd_t))
		and "鸳鸯脚冷却" in l.unit_tactical_hint(b,l.wu),
		"the inspector reports the live remaining cooldown after the kick")
	facts["kick_cooldown_after_hit"] = cooldown
	facts["first_resumed_hit"] = hit
	if failures.is_empty():
		await _duel(b,"wine")
		if not cases.is_empty():
			facts["live"] = cases.back()
	_finish()
