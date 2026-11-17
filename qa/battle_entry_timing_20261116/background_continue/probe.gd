extends "res://tools/zhujiazhuang_rts_test.gd"
## Two processes in one private profile, including background restore rendering.

const HANDOFF := "user://zhu_menu_handoff.json"
const ZHU := {"mode":"campaign","level_id":"level3","waves":0}
var facts := {}
var stage: String
var flow: Node
var painted_while_scanning := 0
var continue_started_at := 0

func _run() -> void:
	stage = OS.get_environment("ZHU_MENU_STAGE")
	flow = root.get_node("ContinueFlow")
	if not flow._private_qa_enabled() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false
	if stage == "save":
		await _save()
	elif stage == "resume":
		await _resume()
	else:
		check(false,"known stage")
		_finish()

func _finish() -> void:
	print("ZHU_MENU_RESULT ",JSON.stringify({"stage":stage,"pid":OS.get_process_id(),
		"checks":checks,"failures":failures,"facts":facts}))
	if stage == "save" and failures.is_empty():
		return # AppLifecycle owns the successful SaveAndExit quit.
	root.get_node("Sfx").shutdown()
	root.get_node("Music").shutdown()
	quit(0 if failures.is_empty() else 1)

func _clicked(owner: Node, name: String) -> bool:
	var button := owner.find_child(name,true,false) as Button
	check(button != null and button.is_visible_in_tree() and not button.disabled,"visible " + name + " button")
	if button == null or not button.is_visible_in_tree() or button.disabled:
		return false
	button.pressed.emit()
	return true

func _save() -> void:
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	var no_slot_at := Time.get_ticks_usec()
	if not _clicked(menu,"ContinueBattle"):
		_finish()
		return
	while flow.phase == flow.Phase.RESTORING:
		await process_frame
	facts["no_slot_ms"] = float(Time.get_ticks_usec()-no_slot_at)/1000.0
	check(flow.last_result.get("code","") == "NO_SLOT" and flow._restore_scan == null
		and current_scene == menu,"empty profile returns to its original menu without a scan")
	flow.dismiss_error()
	menu.queue_free()
	await process_frame
	var b = await _start()
	await physics_frame
	await process_frame
	check(b.phase == b.Phase.FIGHT and b._official_context == ZHU,"normal Zhu Manor battle starts")
	b._open_pause()
	var state := {"gold":int(b.gold),"wood":int(b.wood),"hall":str(b.level.hall.entity_id),
		"mission":String(b.mission.stage_id),"clock":float(b.level.elapsed)}
	flow.operation_finished.connect(_saved.bind(state),CONNECT_ONE_SHOT)
	if not _clicked(b.hud,"SaveAndExit"):
		_finish()

func _saved(result: Dictionary, state: Dictionary) -> void:
	facts["result_code"] = result.get("code","")
	check(result.get("ok",false),"pause-menu action commits a saved slot")
	if result.get("ok",false):
		var store = load("res://scripts/run_slot_store.gd").new()
		var slot: Dictionary = store.read_slot()
		check(slot.get("ok",false) and slot.document.context == ZHU,"disk slot has the exact campaign context")
		if slot.get("ok",false):
			var file := FileAccess.open(HANDOFF,FileAccess.WRITE)
			check(file != null,"handoff created")
			if file != null:
				file.store_string(JSON.stringify({"pid":OS.get_process_id(),"state":state,"sha":slot.file_sha256}))
				file.close()
				facts["generation"] = slot.document.generation
				facts["identity"] = slot.document.world.content_version
	_finish()

func _resume() -> void:
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HANDOFF))
	var store = load("res://scripts/run_slot_store.gd").new()
	var slot: Dictionary = store.read_slot()
	check(slot.get("ok",false) and slot.file_sha256 == previous.sha and OS.get_process_id() != previous.pid,
		"second process reads the exact saved bytes")
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	paused = true
	var session_script: Script = load("res://scripts/run_world_session.gd")
	var public_session = session_script.new({}, {})
	var rejected: Dictionary = public_session.prepare_restore(menu,session_script.RestoreEntry.PLAYER_MENU)
	check(not rejected.get("ok",false) and rejected.get("code","") == "CLASSIC_30_REQUIRED"
		and current_scene == menu,"release menu policy refuses the campaign slot")
	public_session.dispose()
	paused = false
	menu._begin_battle_scan(true)
	var original_scan: RefCounted = menu._entry_scan
	check(original_scan != null,"menu has an actual background identity scan")
	RenderingServer.frame_post_draw.connect(func():
		if flow.phase == flow.Phase.RESTORING and flow._restore_scan != null and flow._restore_scan.runtime_identity_scan_pending():
			painted_while_scanning += 1)
	flow.operation_finished.connect(_restored.bind(weakref(menu),previous),CONNECT_ONE_SHOT)
	continue_started_at = Time.get_ticks_usec()
	if not _clicked(menu,"ContinueBattle"):
		_finish()
		return
	check(flow._restore_scan == original_scan and menu._entry_scan == null,"continue transfers the existing worker without starting another one")
	check(flow.request_continue(menu).get("code","") == "OPERATION_BUSY","duplicate continue is refused before the scan ends")

func _restored(result: Dictionary, menu: WeakRef, previous: Dictionary) -> void:
	facts["rendered_while_scanning"] = painted_while_scanning
	facts["continue_ms"] = float(Time.get_ticks_usec()-continue_started_at)/1000.0
	check(painted_while_scanning > 1 and flow._restore_scan == null,"restore overlay continued rendering and the worker was released")
	facts["result_code"] = result.get("code","")
	check(result.get("ok",false) and menu.get_ref() == null,"main-menu action mounts the saved campaign")
	if not result.get("ok",false):
		_finish()
		return
	var b = current_scene
	var data: Dictionary = previous.state
	check(b._official_context == ZHU and b.phase == b.Phase.FIGHT,"restored official campaign is fighting")
	check(b.gold == data.gold and b.wood == data.wood and is_equal_approx(b.level.elapsed,data.clock)
		and b.mission.stage_id == data.mission and str(b.level.hall.entity_id) == data.hall,
		"economy, hall, clock and mission carry over without deploying again")
	check(paused and b.hud.find_child("SaveAndExit",true,false) != null,"pause and save-button state preserved")
	var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
	check(slot.get("ok",false) and slot.file_sha256 == previous.sha,"restoring leaves the slot bytes intact")
	_finish()
