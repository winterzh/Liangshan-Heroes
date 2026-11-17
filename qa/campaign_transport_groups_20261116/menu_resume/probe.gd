extends "res://tools/huangnigang_short_test.gd"
## Save an actual force-route relay with the original cart loaded.

const HANDOFF := "user://hg_menu_handoff.json"
const CONTEXT := {"mode":"campaign","level_id":"level1","waves":0}
var facts := {}
var stage: String
var flow: Node
var reached := false

func _run() -> void:
	stage = OS.get_environment("HG_MENU_STAGE")
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
	print("HG_MENU_RESULT ",JSON.stringify({"stage":stage,"pid":OS.get_process_id(),
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

func _checkpoint(b, index: int) -> Dictionary:
	var l = b.level
	var events: Array = b.mission.events.keys()
	events.sort()
	var carrier = l.cargo.get(index)
	return {"index":index,"carrier":_entity_id(carrier),"cart":_entity_id(l.bundles[index]),
		"loaded":l.cargo_ready.get(index,false),"attempt":l.force_attempts.get(index,0),
		"load_count":l.delivered,"delivered_indices":l._delivered_cart_indices(b),"cargo_reports":b.mission.report.duplicate(),
		"actors":l.actors.map(_entity_id),"events":events,"clock":b.mission.total_game_seconds}

func _save() -> void:
	await _live("relay",_save_loaded)
	if not reached:
		check(false,"the real assault must reach a loaded relay")
		_finish()

func _save_loaded(b, index: int, carrier) -> void:
	reached = true
	var l = b.level
	check(b.phase == b.Phase.FIGHT and b._official_context == CONTEXT and l.force_started,"normal force-route battle reaches the checkpoint")
	check(l.cargo.get(index) == carrier and l.cargo_ready.get(index,false)
		and carrier.key != l.Transport.owner(index) and index not in l._delivered_cart_indices(b)
		and is_instance_valid(l.bundles[index]),"a surviving successor is carrying one original loaded but undelivered cart")
	if not failures.is_empty():
		_finish()
		return
	Engine.time_scale = 1
	b._open_pause()
	flow.operation_finished.connect(_saved.bind(_checkpoint(b,index)),CONNECT_ONE_SHOT)
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
					"orders":orders}))
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
	var state: Dictionary = JSON.parse_string(JSON.stringify(_checkpoint(b,int(previous.state.index))))
	var expected: Dictionary = previous.state.duplicate()
	check(is_equal_approx(float(state.clock),float(expected.clock)),"battle clock restored on the same checkpoint")
	state.erase("clock")
	expected.erase("clock")
	var mismatched: Array = expected.keys().filter(func(key): return state[key] != expected[key])
	if not mismatched.is_empty():
		facts["checkpoint_mismatch"] = mismatched.map(func(key): return [key,expected[key],state[key]])
	check(mismatched.is_empty(),"original cart, loaded successor, delivery progress, reports and events survive exactly")
	var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
	check(slot.get("ok",false) and slot.file_sha256 == previous.sha,"reading preserves the slot bytes")
	_play_restored.call_deferred(b,previous.state,int(previous.orders))

func _play_restored(b, state: Dictionary, previous_orders: int) -> void:
	b._close_pause()
	Engine.time_scale = 4
	orders = previous_orders
	var l = b.level
	var index := int(state.index)
	var carrier = l.cargo.get(index)
	var buttons: Array = b.mission._buttons.get_children().filter(func(node):
		return node.get_meta(b.mission.PRESENTATION_META,{}).get("button_id","") == "hg_loaded_carts")
	check(not paused and alive(carrier) and buttons.size() == 1,"restored loaded-carrier command is usable")
	if alive(carrier) and buttons.size() == 1:
		var serial: int = carrier._order_serial
		buttons[0].pressed.emit()
		check(b.selection == [carrier] and carrier._order_serial == serial,"loaded-cart shortcut selects the restored successor without moving")
	var attempt: int = l.force_attempts.get(index,0)
	check(await action(b,carrier,"force_deliver_%d_%d"%[index,attempt],80)
		and index in l._delivered_cart_indices(b) and _entity_id(l.bundles[index]) == state.cart
		and l.delivered == int(state.load_count) + l.Transport.weight(index),"one normal exit order delivers the same restored cart once")
	if not failures.is_empty():
		_finish()
		return
	for next_index in range(l.Transport.CART_COUNT):
		if next_index in l._delivered_cart_indices(b): continue
		var candidates: Array = l._transport_candidates(b,next_index)
		if candidates.is_empty():
			check(false,"an eligible survivor takes each remaining cart")
			_finish()
			return
		var successor = b.find_unit(candidates[0])
		var suffix := "%d_%d"%[next_index,int(l.force_attempts.get(next_index,0))]
		if not await action(b,successor,"force_take_"+suffix,55) or not await action(b,successor,"force_load_"+suffix,75) or not await action(b,successor,"force_deliver_"+suffix,80):
			check(false,"remaining carts travel through their actual orders")
			_finish()
			return
	check(l.st == l.WITHDRAW and l.delivered == 11 and l._delivered_cart_indices(b).size() == 7
		and l.cargo.is_empty() and l.empty_cargo.is_empty(),"seven original carts deliver exactly eleven loads")
	_click(b,l.actors.filter(func(u): return alive(u)),l.GATE_W)
	check(await until(func(): return l.victory or b.phase==b.Phase.END,30) and l.victory,
		"a separate player order assembles the survivors for victory")
	var result: Dictionary = b.mission.result_snapshot(l.victory)
	check(result.core_cleared and not result.story_complete and not b.mission.has_event("huangnigang_all_safe"),
		"conclusion awards core victory and preserves actual casualties")
	facts["orders"] = orders
	facts["game_seconds_at_result"] = b.mission.total_game_seconds
	facts["delivered"] = l.delivered
	facts["delivered_indices"] = l._delivered_cart_indices(b)
	facts["result"] = result
	_finish()
