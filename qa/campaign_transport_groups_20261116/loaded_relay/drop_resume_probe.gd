extends "res://qa/campaign_transport_groups_20261116/loaded_relay/natural_probe.gd"
## Pause-menu save of the naturally dropped loaded cart, then independent Continue.

const HANDOFF := "user://hg_drop_handoff.json"
const CONTEXT := {"mode":"campaign","level_id":"level1","waves":0}
var stage: String
var flow: Node

func _run() -> void:
	stage = OS.get_environment("HG_DROP_STAGE")
	flow = root.get_node("ContinueFlow")
	if not flow._private_qa_enabled() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false
	match stage:
		"save": await _save_drop()
		"resume": await _resume()
		_:
			check(false,"known stage")
			_finish()

func _finish() -> void:
	print("HG_DROP_RESULT ",JSON.stringify({"stage":stage,"pid":OS.get_process_id(),
		"checks":checks,"failures":failures,"orders":orders,"facts":facts}))
	if stage == "save" and failures.is_empty(): return
	root.get_node("Sfx").shutdown()
	root.get_node("Music").shutdown()
	quit(0 if failures.is_empty() else 1)

func _click_button(owner: Node, name: String) -> bool:
	var button := owner.find_child(name,true,false) as Button
	var ready := button != null and button.is_visible_in_tree() and not button.disabled
	check(ready,"visible " + name + " button")
	if ready: button.pressed.emit()
	return ready

func _actor_state(unit) -> Array:
	if not is_instance_valid(unit): return []
	return [unit.entity_id, unit.key, unit.hp, unit.story_outcome, unit.position.x, unit.position.y]

func _checkpoint(b,index: int) -> Dictionary:
	var l = b.level
	var cart = l.bundles[index]
	var take_id := "force_take_%d_1" % index
	var take: Dictionary = b.mission.actions[take_id]
	var events: Array = b.mission.events.keys()
	events.sort()
	return {"index":index,"clock":b.mission.total_game_seconds,"cart":_actor_state(cart),
		"cart_wheel":cart._tribute_wheel_angle,"cart_in_world":b.units.has(cart),
		"eligible":take.actors.duplicate(),"marker":[take.cell.x,take.cell.y],"take_done":take.done,
		"loaded":l.cargo_ready.get(index,false),"assigned":l.cargo.has(index),
		"attempt":l.force_attempts.get(index,0),"delivered":l.delivered,"events":events,
		"reports":b.mission.report.duplicate(),"actors":l.actors.map(_actor_state),
		"convoy":l.convoy.map(_actor_state)}

func _save_drop() -> void:
	var dropped := await _reach_drop()
	if dropped.is_empty():
		_finish()
		return
	var b = dropped.battle
	check(b._official_context == CONTEXT and b.phase == b.Phase.FIGHT
		and b.level.convoy.any(func(unit): return alive(unit)),
		"the naturally dropped loaded cart is saved while the original convoy is still fighting")
	if not failures.is_empty():
		_finish()
		return
	Engine.time_scale = 1
	b._open_pause()
	flow.operation_finished.connect(_saved.bind(_checkpoint(b,dropped.index)),CONNECT_ONE_SHOT)
	if not _click_button(b.hud,"SaveAndExit"): _finish()

func _saved(result: Dictionary,state: Dictionary) -> void:
	facts["result_code"] = result.get("code","")
	check(result.get("ok",false),"pause menu commits the dropped-cart checkpoint")
	if result.get("ok",false):
		var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
		check(slot.get("ok",false) and slot.document.context == CONTEXT,"saved slot names the exact chapter")
		if slot.get("ok",false):
			var file := FileAccess.open(HANDOFF,FileAccess.WRITE)
			check(file != null,"handoff recorded")
			if file != null:
				file.store_string(JSON.stringify({"pid":OS.get_process_id(),"state":state,"sha":slot.file_sha256,"orders":orders}))
				file.close()
				facts["generation"] = slot.document.generation
				facts["checkpoint"] = state
	_finish()

func _resume() -> void:
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HANDOFF))
	var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
	check(slot.get("ok",false) and slot.file_sha256 == previous.sha and OS.get_process_id() != previous.pid,
		"independent process reads the original dropped-cart slot")
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	flow.operation_finished.connect(_restored.bind(weakref(menu),previous),CONNECT_ONE_SHOT)
	if not _click_button(menu,"ContinueBattle"): _finish()

func _restored(result: Dictionary, menu: WeakRef, previous: Dictionary) -> void:
	facts["result_code"] = result.get("code","")
	check(result.get("ok",false) and menu.get_ref() == null,"Continue opens the actual saved battle")
	if not result.get("ok",false):
		_finish()
		return
	var b = current_scene
	var saved: Dictionary = previous.state
	var index := int(saved.index)
	check(paused and b._official_context == CONTEXT and b.phase == b.Phase.FIGHT and b.level.st == b.level.FORCE,
		"the force route resumes at the paused battle")
	var actual: Dictionary = JSON.parse_string(JSON.stringify(_checkpoint(b,index)))
	# The unit codec deliberately rebuilds the cosmetic wheel rotation.
	facts["wheel_before"] = saved.cart_wheel
	facts["wheel_after"] = actual.cart_wheel
	check(is_zero_approx(float(actual.cart_wheel)),"the cosmetic wheel angle resets by the unit restore contract")
	var mismatches: Array = saved.keys().filter(func(key): return key != "cart_wheel" and saved[key] != actual[key])
	if not mismatches.is_empty():
		facts["checkpoint_mismatch"] = mismatches.map(func(key): return [key,saved[key],actual[key]])
	check(mismatches.is_empty(),"cart, marker, original convoy, pending relay and reports survive exactly")
	check(b.level.top_status(b).contains("待接重车1辆"),"the restored HUD counts the still-grounded loaded cart")
	var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
	check(slot.get("ok",false) and slot.file_sha256 == previous.sha,"reading preserves the original bytes")
	if not failures.is_empty():
		_finish()
		return
	_play_checkpoint.call_deferred(b,index,int(saved.cart[0]),int(previous.orders))

func _play_checkpoint(b,index: int,cart_id: int,previous_orders: int) -> void:
	orders = previous_orders
	b._close_pause()
	Engine.time_scale = 4
	await _recover(b,index,cart_id)
	_finish()
