extends "res://tools/yezhulin_short_test.gd"
## Real north route, saved while the party is still moving on the first rest order.

const HANDOFF := "user://pine_menu_handoff.json"
const CONTEXT := {"mode":"campaign","level_id":"level6","waves":0}
var stage: String
var flow: Node
var facts := {}

func _run() -> void:
	stage = OS.get_environment("YF_MENU_STAGE")
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
	print("YF_MENU_RESULT ",JSON.stringify({"stage":stage,"pid":OS.get_process_id(),
		"checks":checks,"failures":failures,"facts":facts}))
	if stage == "save" and failures.is_empty():
		return # SaveAndExit owns the successful quit.
	root.get_node("Sfx").shutdown()
	root.get_node("Music").shutdown()
	quit(0 if failures.is_empty() else 1)

func _click_button(owner: Node, name: String) -> bool:
	var button := owner.find_child(name,true,false) as Button
	var ready := button != null and button.is_visible_in_tree() and not button.disabled
	check(ready,"visible " + name + " button")
	if ready:
		button.pressed.emit()
	return ready

func _checkpoint(b) -> Dictionary:
	var l = b.level
	var events: Array = b.mission.events.keys()
	events.sort()
	var party: Array = []
	var rest_order: Array = []
	for u in l._escort_group():
		party.append({"id":u.entity_id,"name":u.key,"hp":u.hp,"x":u.position.x,"y":u.position.y,
			"serial":u._order_serial,"token":u.mission_order_token,"walking":u._path_i < u._path.size()})
		rest_order.append(int(l.escort_orders.get(u.entity_id,-1)))
	var target: Vector2 = l.escort_player_target
	return {"route":l.shadow_route,"clock":b.mission.total_game_seconds,"events":events,
		"party":party,"rest_order":rest_order,"order_token":l.escort_player_token,
		"target":[target.x,target.y],"active_action":b.mission.active_action_id}

func _save() -> void:
	var b = await _start("",5)
	var l = b.level
	Engine.time_scale = 4
	_click(b,[l.lu],Vector2i(34,16))
	var hunting := await _until(func(): return l.st == l.RESCUE or b.phase == b.Phase.END,30)
	check(hunting and l.st == l.RESCUE and l.shadow_route == "north_pines","north passage opens an actual hidden rescue")
	check(await _action_done(b,l.lu,"intercept",25),"ordinary player order intercepts the staff")
	var freed := await _until(func(): return l.st == l.ESCAPE or b.phase == b.Phase.END,12)
	check(freed and l.st == l.ESCAPE and l._escort_group().size() == 4,"original party survives untying and care")
	if not failures.is_empty():
		_finish()
		return
	_action(b,l.lin_freed,"rest_stop")
	var underway := await _until(func():
		return l.escort_orders.size() == 4 and l._escort_group().any(func(u): return u._path_i < u._path.size()),5)
	check(underway and l._escort_heading_to_rest(b) and not l.rest_reached
		and l._escort_arrival_at(b.map.cell_to_world(l.REST),96.0).arrived < 4,
		"one real rest order sends four originals walking before arrival")
	if not failures.is_empty():
		_finish()
		return
	Engine.time_scale = 1
	b._open_pause()
	flow.operation_finished.connect(_saved.bind(_checkpoint(b)),CONNECT_ONE_SHOT)
	if not _click_button(b.hud,"SaveAndExit"):
		_finish()

func _saved(result: Dictionary, state: Dictionary) -> void:
	facts["result_code"] = result.get("code","")
	check(result.get("ok",false),"pause menu commits the checkpoint")
	if result.get("ok",false):
		var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
		check(slot.get("ok",false) and slot.document.context == CONTEXT,"disk slot names the exact chapter")
		if slot.get("ok",false):
			var file := FileAccess.open(HANDOFF,FileAccess.WRITE)
			check(file != null,"handoff recorded")
			if file != null:
				file.store_string(JSON.stringify({"pid":OS.get_process_id(),"sha":slot.file_sha256,"state":state}))
				file.close()
				facts["checkpoint"] = state
	_finish()

func _resume() -> void:
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HANDOFF))
	var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
	check(slot.get("ok",false) and slot.file_sha256 == previous.sha and OS.get_process_id() != previous.pid,
		"independent process reads the original slot bytes")
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	flow.operation_finished.connect(_restored.bind(weakref(menu),previous),CONNECT_ONE_SHOT)
	if not _click_button(menu,"ContinueBattle"):
		_finish()

func _restored(result: Dictionary, menu: WeakRef, previous: Dictionary) -> void:
	facts["result_code"] = result.get("code","")
	check(result.get("ok",false) and menu.get_ref() == null,"main menu mounts the saved battle")
	if not result.get("ok",false):
		_finish()
		return
	var b = current_scene
	var l = b.level
	check(paused and b._official_context == CONTEXT and b.phase == b.Phase.FIGHT
		and l.st == l.ESCAPE and not l.rest_reached,"the resumed battle is paused before rest")
	var actual: Dictionary = JSON.parse_string(JSON.stringify(_checkpoint(b)))
	var expected: Dictionary = previous.state
	var mismatches: Array = expected.keys().filter(func(k): return expected[k] != actual[k])
	if not mismatches.is_empty():
		facts["checkpoint_mismatch"] = mismatches.map(func(k): return [k,expected[k],actual[k]])
	check(mismatches.is_empty(),"original people, motion, player order and mission time survive exactly")
	var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
	check(slot.get("ok",false) and slot.file_sha256 == previous.sha,"Continue leaves the saved bytes intact")
	if not failures.is_empty():
		_finish()
		return
	_play_restored.call_deferred(b)

func _play_restored(b) -> void:
	var l = b.level
	Engine.time_scale = 4
	b._close_pause()
	var rested := await _until(func(): return l.rest_reached or b.phase == b.Phase.END,50)
	check(rested and l.rest_reached and l._full_group_near(b.map.cell_to_world(l.REST),176)
		and b.mission.has_event("rest_stop") and orders == 0,
		"the original order completes rest with the whole party without a repeated command")
	facts["rest_without_new_order"] = rested and l.rest_reached and orders == 0
	facts["rest_seconds"] = b.mission.total_game_seconds
	if failures.is_empty():
		check(await _action_done(b,l.lin_freed,"leave_forest",90),"a new player order leads the party to the exit")
		await _until(func(): return b.phase == b.Phase.END,8)
		var result: Dictionary = b.mission.result_snapshot(l.victory)
		check(l.victory and b.mission.has_event("yezhulin_four_left") and result.story_done == 3,
			"the original four leave the forest and earn all three story goals")
		facts["story_done"] = result.story_done
		facts["finish_seconds"] = b.mission.total_game_seconds
	_finish()
