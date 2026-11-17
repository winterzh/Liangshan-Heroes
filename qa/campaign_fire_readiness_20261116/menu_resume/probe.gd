extends "res://tools/gao_rts_play.gd"
## Pause at live ignition and continue withdrawal through the private campaign menu.

const HANDOFF := "user://gao_menu_handoff.json"
const CONTEXT := {"mode":"campaign","level_id":"level5","waves":0}
var facts := {}
var stage: String
var flow: Node
var returned_liu := ""

func _run() -> void:
	stage = OS.get_environment("GAO_MENU_STAGE")
	flow = root.get_node("ContinueFlow")
	if not flow._private_qa_enabled() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false
	route = "story"
	root.size = Vector2i(1440,900)
	build_cells = GAO_BUILD_CELLS.duplicate()
	match stage:
		"save": await _save()
		"resume": await _resume()
		_:
			check(false,"known stage")
			_finish()

func _finish() -> void:
	print("GAO_MENU_RESULT ",JSON.stringify({"stage":stage,"pid":OS.get_process_id(),
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
	var flames: Array = []
	for dot: Dictionary in b._ground_dots:
		if dot.ability_id != "gao_fireboat": continue
		flames.append({"caster":_entity_id(dot.caster),"remaining":dot.t,"tick":dot.tick_t,
			"pos":[dot.pos.x,dot.pos.y],"radius":dot.r})
	return {"ignited":l.fire_lit,"abandoned":l.fire_abandoned,"waves":l.waves.duplicate(true),
		"liu":_entity_id(l.embarked_liu),"carrier":_entity_id(l.liu_carrier),"fireboat":_entity_id(l.fireboat),
		"fireboat_outcome":l.fireboat.story_outcome,"liu_outcome":l.embarked_liu.story_outcome,
		"carried_person":l.liu_carrier.get_meta("carried_story_person",""),"flames":flames,
		"events":events,"gold":b.gold,"wood":b.wood,"clock":l.elapsed}

func _save() -> void:
	var b = await _start("",4)
	check(b.phase == b.Phase.FIGHT and b._official_context == CONTEXT,"normal Gao Qiu battle starts")
	var original_liu := _entity_id(b.find_unit("liu_tang"))
	var original_carrier := _entity_id(b.find_unit("ruan_xiaoer_boat"))
	Engine.time_scale = 4
	await _play_gao(b,func(): return b.level.fire_lit)
	var l = b.level
	check(b.phase == b.Phase.FIGHT and l.fire_lit and not l.fire_abandoned
		and b.mission.has_event("gao_fire_lit") and not b.mission.has_event("fire_escort_safe"),
		"actual ignition happens before withdrawal")
	if not failures.is_empty():
		_finish()
		return
	Engine.time_scale = 1
	b._open_pause()
	var state := _checkpoint(b)
	check(state.liu == original_liu and state.carrier == original_carrier and state.fireboat_outcome == "retreated"
		and state.liu_outcome == "embarked" and state.flames.size() == 1,
		"the fire is still burning and the original Liu Tang is aboard the original rescue boat")
	if not failures.is_empty():
		_finish()
		return
	flow.operation_finished.connect(_saved.bind(state),CONNECT_ONE_SHOT)
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
	check(mismatched.is_empty(),"live fire timing, original carrier, expedition state, economy and events survive exactly")
	var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
	check(slot.get("ok",false) and slot.file_sha256 == previous.sha,"reading preserves the slot bytes")
	_play_restored.call_deferred(b,previous.driver,previous.state.liu)

func _story(b,time: float) -> void:
	if b.mission.has_event("gao_liu_returned"):
		returned_liu = _entity_id(b.find_unit("liu_tang"))
		story_phase = "finished_fire"
		route = "assault"
		return
	super._story(b,time)

func _play_restored(b, driver: Dictionary, original_liu: String) -> void:
	check(b.mission.actions.has("gao_fire_withdraw") and b.mission.actions.has("gao_liu_return"),
		"the withdrawal and return actions are present after restoring")
	b._close_pause()
	buildings_started = driver.buildings
	units_queued = driver.units
	units_queued_by_key = driver.queue
	orders = driver.orders
	skill_orders = driver.skills
	story_phase = "withdraw"
	Engine.time_scale = 4
	await _play_gao(b,Callable(),true)
	check(returned_liu == original_liu and b.mission.has_event("fire_escort_safe")
		and not b.level.fire_abandoned,"both original rescue boats withdraw and Liu Tang disembarks from his carrier")
	check(b.mission.has_event("gao_basic_victory") and "gao_fire" in play_metrics.result.done_ids,
		"ordinary victory preserves the fire-and-withdrawal story goal")
	facts["returned_liu"] = returned_liu
	facts["game_seconds_at_result"] = b.level.elapsed
	facts["live"] = play_metrics
	_finish()
