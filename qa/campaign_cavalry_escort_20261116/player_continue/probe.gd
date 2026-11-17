extends "res://tools/lianhuanma_escort_qa.gd"
## Real defense route with one save boundary. No placed units or injected victory.

const HANDOFF := "user://lian_player_qa.json"
const LEAF := {"mode":"campaign","level_id":"level4","waves":0}
var stage := ""
var facts := {}
var flow: Node
var capture_sent := false

func _run() -> void:
	stage = OS.get_environment("LIAN_PLAYER_STAGE")
	var area := OS.get_environment("APPDATA").replace("\\","/")
	if OS.get_environment("STEAM_DISABLED") != "1" or not area.contains("/lian-player-") \
			or not OS.get_user_data_dir().replace("\\","/").begins_with(area + "/"):
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").game_speed = 1.0
	flow = root.get_node("ContinueFlow")
	var deadline := Time.get_ticks_msec() + 60000
	while flow.busy() and flow.phase != flow.Phase.ERROR and Time.get_ticks_msec() < deadline:
		await process_frame
	check(flow.last_result.get("startup_checked",false) and flow.can_launch(), "current startup completes")
	if not failures.is_empty():
		facts["startup"] = flow.last_result
		_finish()
		return
	facts["identity"] = flow._startup_identity.get("content_version","")
	flow.set_script(load("res://qa/campaign_siege_20261116/player_continue/platform_entry.gd"))
	check(not flow._private_qa_enabled(),"actual player admission policy in the isolation profile")
	route = "defend"
	build_cells = [Vector2i(5,28),Vector2i(5,35),Vector2i(12,36),Vector2i(17,36),
		Vector2i(12,23),Vector2i(16,24),Vector2i(9,43),Vector2i(20,34)]
	if stage == "save":
		var b = await _start("",3)
		check(b._official_context == LEAF and b.phase == b.Phase.FIGHT,"actual Lianhuanma battle is running")
		Engine.time_scale = 4
		await _play_lhm(b)
		Engine.time_scale = 1
		if capture_sent: return
		check(false,"north-wave checkpoint was reached before the route ended")
		_finish()
	elif stage in ["resume","reject"]:
		var menu = load("res://scenes/menu.tscn").instantiate()
		root.add_child(menu)
		current_scene = menu
		await process_frame
		var continuation := _after_restore if stage == "resume" else _after_reject
		flow.operation_finished.connect(continuation,CONNECT_ONE_SHOT)
		if not _click_button(menu,"ContinueBattle"): _finish()
	else:
		check(false,"known stage")
		_finish()

func _click_button(owner: Node, id: String) -> bool:
	var button := owner.find_child(id,true,false) as Button
	var available := button != null and button.is_visible_in_tree() and not button.disabled
	check(available,"visible " + id)
	if available: button.pressed.emit()
	return available

func _wave_signature(b) -> String:
	var l = b.level
	return JSON.stringify({"elapsed":l.elapsed,"hall":l.hall.entity_id,"gold":b.gold,"wood":b.wood,
		"riders":l.riders.map(func(u): return [u.entity_id,u.position.x,u.position.y,u.hp] if is_instance_valid(u) else []),
		"escorts":l.escorts.map(func(u): return [u.entity_id,u._order_serial,u._state] if is_instance_valid(u) else []),
		"waves":l.waves.map(func(w): return [w.sent,w.time]),"down":l.lhm_killed,"broken":l.broken_count})

func _stop_lhm_route(b) -> bool:
	if stage != "save" or capture_sent: return false
	var l = b.level
	if not l.waves[0].sent or l.waves[1].sent or l.lhm_killed == 12: return false
	capture_sent = true
	Engine.time_scale = 1
	b._open_pause()
	var data := {"wave":_wave_signature(b),"queued":units_queued,"built":buildings_started}
	facts["checkpoint"] = {"elapsed":l.elapsed,"north_sent":l.waves[0].sent,"south_sent":l.waves[1].sent,
		"original_live_riders":l.riders.filter(func(u): return alive(u)).size(),"retained_escorts":l.escorts.size()}
	flow.operation_finished.connect(_saved.bind(data),CONNECT_ONE_SHOT)
	if not _click_button(b.hud,"SaveAndExit"): _finish()
	return true

func _saved(result: Dictionary, data: Dictionary) -> void:
	facts["save_code"] = result.get("code","")
	var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
	check(result.ok and slot.ok and slot.document.context == LEAF,"player pause menu commits the active chapter")
	if slot.ok:
		data["slot_sha"] = slot.file_sha256
		var file := FileAccess.open(HANDOFF,FileAccess.WRITE)
		check(file != null,"persist witness for next process")
		if file != null:
			file.store_string(JSON.stringify(data))
			file.close()
	_finish()

func _counter_uses_flank() -> bool:
	return stage == "resume"

func _after_restore(result: Dictionary) -> void:
	facts["resume_code"] = result.get("code","")
	check(result.ok and current_scene._official_context == LEAF and paused,"player main menu restores Lianhuanma paused")
	if not failures.is_empty():
		_finish()
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HANDOFF))
	var b = current_scene
	check(_wave_signature(b) == data.wave,"restored cavalry, escorts, order serials, hall and economy match")
	check(b.hud.find_child("SaveAndExit",true,false) != null,"restored chapter retains the player save button")
	if not failures.is_empty():
		_finish()
		return
	units_queued = int(data.queued)
	buildings_started = int(data.built)
	paused = false
	Engine.time_scale = 4
	await _play_lhm(b)
	Engine.time_scale = 1
	var deadline := Time.get_ticks_msec() + 60000
	while flow.busy() and flow.phase != flow.Phase.ERROR and Time.get_ticks_msec() < deadline:
		await process_frame
	var campaign = root.get_node("Campaign")
	var victory: Dictionary = campaign.level_record("level4")
	check(flow.last_result.get("terminal_completed",false) and victory.cleared,
		"natural victory is committed by the real settlement coordinator")
	facts["play"] = play_metrics
	facts["progress_sha"] = FileAccess.get_sha256("user://campaign.cfg")
	_finish()

func _after_reject(result: Dictionary) -> void:
	facts["terminal_code"] = result.get("code","")
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HANDOFF))
	var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
	var campaign = root.get_node("Campaign")
	check(not result.ok and facts.terminal_code == "LOCAL_RUN_TERMINAL","old slot is rejected after natural victory")
	check(slot.ok and slot.file_sha256 == expected.slot_sha and campaign.level_record("level4").cleared,
		"old slot bytes and existing chapter progress are preserved")
	facts["progress_sha"] = FileAccess.get_sha256("user://campaign.cfg")
	_click_button(flow._overlay,"CloseError")
	_finish()

func _finish() -> void:
	print("LIAN_PLAYER_RESULT ",JSON.stringify({"stage":stage,"pid":OS.get_process_id(),
		"checks":checks,"failures":failures,"facts":facts}))
	if failures.is_empty():
		if stage != "save": root.get_node("AppLifecycle").request_quit("lian_player_fixture")
	else:
		root.get_node("Sfx").shutdown()
		root.get_node("Music").shutdown()
		quit.call_deferred(1)
