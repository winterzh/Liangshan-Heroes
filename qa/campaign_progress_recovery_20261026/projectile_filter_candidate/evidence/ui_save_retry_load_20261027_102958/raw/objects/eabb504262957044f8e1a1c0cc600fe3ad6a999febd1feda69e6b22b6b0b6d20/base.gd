extends Node
## Read-only observations and real visible Button/Viewport input; no production seam.
const MenuScene = preload("res://scenes/menu.tscn")
const BattleScript = preload("res://scripts/battle.gd")
const Classic = preload("res://scripts/levels/skirmish.gd")
const Slot = preload("res://scripts/run_slot_store.gd")
const LocalLifecycle = preload("res://scripts/run_local_lifecycle.gd")
const Provider = preload("res://scripts/run_content_identity.gd")
const Codec = preload("res://scripts/run_state_value_codec.gd")
const InflightObserver = preload("inflight.gd")
const SLOT_ROOT := "user://continue/v1"
const MODES := ["save_initial", "retry_save", "reject_then_resume"]
var mode := ""
var output := ""
var trusted: Dictionary = {}
var flow: Variant
var battle: Variant
var menu: Variant
var checks: Array = []
var actions: Array = []
var observations: Dictionary = {}
var operations: Array = []
var checkpoint: Dictionary = {}
var previous: Dictionary = {}
var result: Dictionary = {}
var received := false
var finished := false
var want_exit := false
var exit_reason := ""
var save_exit_observed := false
var captured_snapshot: Dictionary = {}
var captured_exact: Dictionary = {}
var capture_count := 0
var pending_session: RefCounted
var pending_store: RefCounted
var pending_ref: Dictionary = {}
var proposal_ref: Dictionary = {}
var record_ref: Dictionary = {}
var retained_pending: Dictionary = {}

func check(label: String, passed: bool, detail: Variant = null) -> bool:
	checks.append({"name":label,"passed":passed,"detail":detail})
	print("USR_CHECK " + ("PASS " if passed else "FAIL ") + label)
	return passed

func passed() -> bool:
	return not checks.is_empty() and checks.all(func(row: Dictionary) -> bool: return row.passed)

func read_json(path: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return null
	return parser.data

func write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value,"",true,true)); file.flush()
	var good: bool = file.get_error() == OK
	file.close()
	return good

func publish(name: String, value: Dictionary) -> bool:
	var path: String = output.path_join(name)
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".tmp"): return false
	return write_json(path + ".tmp",value) and DirAccess.rename_absolute(path + ".tmp",path) == OK

func profile_valid() -> bool:
	var profile: String = OS.get_environment("USR_PROFILE").replace("\\","/").trim_suffix("/")
	var run: String = OS.get_environment("USR_RUN").replace("\\","/").trim_suffix("/")
	var stage: String = output.replace("\\","/")
	if not profile.is_absolute_path() or not run.is_absolute_path() or not stage.begins_with(run + "/") or ".." in stage.split("/"): return false
	if not OS.has_feature("editor") or OS.get_environment("STEAM_DISABLED") != "1" or not OS.get_environment("CAMPAIGN_QA").is_empty(): return false
	if OS.get_environment("LSH_CONTINUE_FLOW_QA") != "1" or OS.get_environment("LSH_CONTINUE_FLOW_PROFILE") != OS.get_environment("USR_PROFILE"): return false
	if ProjectSettings.globalize_path("res://").replace("\\","/").trim_suffix("/") != OS.get_environment("USR_PROJECT").replace("\\","/").trim_suffix("/"): return false
	for key: String in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
		if OS.get_environment(key).replace("\\","/").trim_suffix("/") != profile.path_join(key.to_lower()): return false
	return OS.get_user_data_dir().replace("\\","/").begins_with(profile + "/") and LocalLifecycle._hex(OS.get_environment("USR_BATCH_NONCE"),32) and LocalLifecycle._hex(OS.get_environment("USR_PROCESS_NONCE"),32) and LocalLifecycle._hex(OS.get_environment("USR_MANIFEST"),64) and LocalLifecycle._hex(OS.get_environment("USR_SOURCES_SHA256"),64)

func named(parent: Node, name: String) -> Variant:
	return parent.find_child(name,true,false)

func text_button(parent: Node, text: String, prefix := false) -> Variant:
	var stack: Array = [parent]
	var found: Variant = null
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button and node.is_visible_in_tree() and (node.text.begins_with(text) if prefix else node.text == text):
			if found != null: return null
			found = node
		stack.append_array(node.get_children())
	return found

func press(button: Variant, purpose: String) -> bool:
	if not check("visible enabled original button " + purpose,is_instance_valid(button) and button is Button and button.is_visible_in_tree() and not button.disabled and not button.is_blocking_signals()): return false
	actions.append({"kind":"original_button_callback","purpose":purpose,"name":String(button.name),"text":button.text,"frame":str(Engine.get_process_frames()),"pid":OS.get_process_id()})
	button.pressed.emit()
	return true

func pause_world() -> bool:
	if get_tree().paused and battle.hud._pause_root.visible: return true
	var key := InputEventKey.new(); key.keycode = KEY_ESCAPE; key.pressed = true
	get_viewport().push_input(key)
	key = key.duplicate(); key.pressed = false; get_viewport().push_input(key)
	actions.append({"kind":"viewport_key","key":"Escape","desktop_os_input":false})
	await get_tree().process_frame
	return check("actual viewport Escape pauses original HUD",get_tree().paused and battle.hud._pause_root.visible and battle._save_barrier.state == battle._save_barrier.State.IDLE)

func on_operation(value: Dictionary) -> void:
	result = value.duplicate(true); received = true
	operations.append({"result":value.duplicate(true),"frame":str(Engine.get_process_frames()),"phase":int(flow.phase),"pid":OS.get_process_id()})
	if want_exit and value.get("ok",false): finalize_saved(value)

func wait_operation() -> bool:
	var deadline: int = Time.get_ticks_msec() + 90000
	while not received and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	return check("original Flow operation returned",received)

func gate(phase: String, detail: Dictionary) -> bool:
	var request := {"schema":"ui_save_retry_gate_v1","mode":mode,"phase":phase,"pid":OS.get_process_id(),"batch_nonce":OS.get_environment("USR_BATCH_NONCE"),"process_nonce":OS.get_environment("USR_PROCESS_NONCE"),"profile":OS.get_environment("USR_PROFILE"),"content_version":trusted.content_version,"engine_sha256":trusted.engine_binary_sha256,"detail":detail}
	var request_name: String = phase + ".request.json"
	if not check("publish unique host gate " + phase,publish(request_name,request)): return false
	var digest: String = FileAccess.get_sha256(output.path_join(request_name))
	var path: String = output.path_join(phase + ".ack.json")
	var deadline: int = Time.get_ticks_msec() + 90000
	while not FileAccess.file_exists(path) and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	var ack: Variant = read_json(path)
	var keys := ["schema","mode","phase","pid","batch_nonce","process_nonce","profile","content_version","engine_sha256","request_sha256","ok"]
	var good: bool = typeof(ack) == TYPE_DICTIONARY and ack.size() == keys.size() and ack.has_all(keys)
	if good:
		good = ack.schema == "ui_save_retry_ack_v1" and typeof(ack.ok) == TYPE_BOOL and ack.ok and ack.request_sha256 == digest
		good = good and typeof(ack.pid) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(ack.pid)) and float(ack.pid) == float(OS.get_process_id())
		for key: String in ["mode","phase","batch_nonce","process_nonce","profile","content_version","engine_sha256"]:
			good = good and typeof(ack[key]) == TYPE_STRING and ack[key] == request[key]
	observations["gate_" + phase] = {"request_sha256":digest,"ack":ack}
	return check("exact native host acknowledgment " + phase,good)

func entity_instances() -> Dictionary:
	var ids: Dictionary = {}
	for unit: Variant in battle.units:
		if is_instance_valid(unit): ids[str(unit.entity_id)] = str(unit.get_instance_id())
	return ids

func unit_id(unit: Variant) -> String:
	return str(unit.entity_id) if is_instance_valid(unit) else ""

func snapshot(held := false) -> Dictionary:
	var inflight: Dictionary = InflightObserver.new().capture(battle,held)
	check("paused native in-flight observation",inflight.get("ok",false),inflight.get("code",""))
	var units: Array = []
	for u: Variant in battle.units:
		if not is_instance_valid(u): continue
		units.append({"id":str(u.entity_id),"key":u.key,"faction":u.faction,"hp":u.hp,"max_hp":u.max_hp,
			"position":[u.position.x,u.position.y],"state":u._state,"construction":u.is_constructing,
			"build_progress":u.build_progress,"queue":u._train_queue.duplicate(),"train_t":u._train_t,
			"carry":[u._carry_kind,u._carry_amt,u._gather_t],"resource_left":u.res_left,
			"hero":[u.hero_level,u.hero_xp,u.skill_points],"abilities":u.ability_slots.duplicate(true),
			"research":[u._research_key,u._research_t],"target":unit_id(u._target),"gather":unit_id(u._gather_node),"builder_target":unit_id(u._build_site)})
	units.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.id) < int(b.id))
	return {"gold":battle.gold,"wood":battle.wood,"kills":battle.kills,"valid_kills":battle._steam_valid_kills,
		"auto_micro_level":get_node("/root/Settings").auto_micro_level,"inflight":inflight.get("value",{}),"inflight_witness":inflight.get("witness",{}),
		"next_entity_id":str(battle.next_entity_id),"clock_next":str(battle._run_clock._next_tick),
		"level":{"wave":battle.level._wave,"timer":battle.level._wave_t,"started":battle.level._started,"spawned":battle.level._wave_spawned},
		"units":units,"hero_progress":battle.hero_progress.duplicate(true),"hero_combat_stats":battle.hero_combat_stats.duplicate(true),
		"pending_cast_count":battle._pending_casts.size(),"walk_cast_count":battle._walk_casts.size(),"fx_count":battle.fx_root.get_child_count()}

func exact(value: Variant) -> Variant:
	var encoded: Dictionary = Codec.new().encode(value)
	check("native lossless Codec observation",encoded.get("ok",false),encoded.get("code",""))
	return encoded.get("value",{})

func lifecycle_row(binding: Dictionary) -> Dictionary:
	var local := LocalLifecycle.new(String(binding.token),SLOT_ROOT)
	var head: Dictionary = local.open_head()
	if not check("original classic active lifecycle",head.get("ok",false) and head.get("revision") == 1 and head.get("file_sha256") == binding.receipt_sha256 and head.get("document",{}).get("state") == "active"): return {}
	return {"directory":local.directory,"revision":head.revision,"file_sha256":head.file_sha256,"document":head.document,"inventory":local.inventory()}

func disk_row() -> Dictionary:
	var store := Slot.new(SLOT_ROOT)
	var head: Dictionary = store.read_slot()
	if not check("real complete classic slot is readable",head.get("ok",false),head.get("code","")): return {}
	var packet: Dictionary = head.document
	if not check("exact classic profile installed source and uncredited binding",packet.schema == Slot.SCHEMA and packet.context == Slot.CONTEXT and packet.world.content_version == trusted.content_version and packet.world.engine_sha256 == trusted.engine_binary_sha256 and LocalLifecycle.validate_binding(packet.binding).ok): return {}
	return {"generation":head.revision,"file_sha256":head.file_sha256,"binding":packet.binding,"slot_directory":store.directory,"record_path":store.directory.path_join("record_%010d.json" % int(head.revision)),"slot_inventory":store.inventory(),"lifecycle":lifecycle_row(packet.binding)}

func load_previous(expected_mode: String) -> bool:
	var path: String = OS.get_environment("USR_PREVIOUS")
	if not check("previous report exact SHA",FileAccess.get_sha256(path) == OS.get_environment("USR_PREVIOUS_SHA")): return false
	var value: Variant = read_json(path)
	if not check("previous report actual successful independent process",typeof(value) == TYPE_DICTIONARY and value.get("schema") == "ui_save_retry_three_process_v1" and value.get("mode") == expected_mode and value.get("passed",false) and value.get("stage_completed",false) and value.get("pid") != OS.get_process_id() and value.get("profile") == OS.get_environment("USR_PROFILE") and value.get("batch_nonce") == OS.get_environment("USR_BATCH_NONCE") and value.get("process_nonce") != OS.get_environment("USR_PROCESS_NONCE") and value.get("sources_sha256") == OS.get_environment("USR_SOURCES_SHA256") and value.get("candidate_manifest_sha256") == OS.get_environment("USR_MANIFEST")): return false
	previous = value
	return check("predecessor source and engine identity",previous.identity == identity_row())

func previous_disk() -> Dictionary:
	var decoded: Dictionary = Codec.new().decode(previous.get("checkpoint",{}).get("exact_disk",{}))
	if not check("predecessor disk metadata decodes losslessly",decoded.get("ok",false) and typeof(decoded.get("value")) == TYPE_DICTIONARY): return {}
	return decoded.value

func identity_row() -> Dictionary:
	return {"content_version":trusted.get("content_version",""),"engine_sha256":trusted.get("engine_binary_sha256",""),"source_mode":trusted.get("source_mode",false)}

func verify_restored(expected: Dictionary) -> bool:
	battle = get_tree().current_scene
	if not check("real independently restored paused classic world",is_instance_valid(battle) and battle.get_script() == BattleScript and battle.level.get_script() == Classic and get_tree().paused and battle.hud._pause_root.visible and battle._save_barrier.state == battle._save_barrier.State.IDLE): return false
	var current: Dictionary = disk_row()
	var actual: Dictionary = snapshot()
	observations["restored"] = actual
	check("complete paused typed world checkpoint survives without replay",exact(actual) == expected.exact_snapshot)
	check("restore leaves original slot and lifecycle bytes",current.generation == expected.generation and current.file_sha256 == expected.file_sha256 and current.binding == expected.binding and current.slot_inventory == expected.slot_inventory and exact(current) == expected.exact_disk)
	check("same actual local token installed",battle._continue_receipt != null and battle._continue_receipt.get_script() == LocalLifecycle and battle._continue_receipt.token == expected.binding.token and battle._steam_run_id == 0)
	return passed()

func arm_capture() -> bool:
	if not check("observer starts before original Flow capture",capture_count == 0 and not battle._save_barrier.capture_ready.is_connected(capture_witness) and not battle._save_barrier.capture_ready.is_connected(Callable(flow,"_capture_ready"))): return false
	battle._save_barrier.capture_ready.connect(capture_witness,CONNECT_ONE_SHOT)
	return true

func capture_witness(_clock: Dictionary) -> void:
	capture_count += 1
	if battle._save_barrier.capture_ready.is_connected(capture_witness): battle._save_barrier.capture_ready.disconnect(capture_witness)
	check("one read-only HELD observer before original save Session",capture_count == 1 and flow._session == null and battle._save_barrier.state == battle._save_barrier.State.HELD and battle._save_barrier.health().ok and not Engine.is_in_physics_frame())
	captured_snapshot = snapshot(true)
	captured_exact = exact(captured_snapshot)
	observations["capture_observer"] = {"calls":capture_count,"held":battle._save_barrier.state == battle._save_barrier.State.HELD,"session_absent":flow._session == null,"clock_next":str(battle._run_clock._next_tick),"disconnected":not battle._save_barrier.capture_ready.is_connected(capture_witness),"frame":str(Engine.get_process_frames())}

func finalize_saved(value: Dictionary) -> void:
	checkpoint = disk_row()
	var expected_generation: int = 1 if mode == "save_initial" else 2
	check("exact one new generation returned by production",checkpoint.get("generation") == expected_generation and value.get("generation") == expected_generation and checkpoint.get("file_sha256") == value.get("file_sha256"))
	check("saved world still exact second HELD capture",capture_count == 1 and exact(snapshot(true)) == captured_exact)
	checkpoint["exact_disk"] = exact(checkpoint.duplicate(true))
	checkpoint["snapshot"] = captured_snapshot
	checkpoint["exact_snapshot"] = captured_exact
	if mode == "retry_save":
		check("successful owned retry preserved original token and LC",value.get("owned_retry",false) and checkpoint.binding == previous.checkpoint.binding and exact(checkpoint.lifecycle) == exact(previous_disk().get("lifecycle",{})))
	await get_tree().process_frame
	save_exit_observed = get_node("/root/AppLifecycle").quit_started() and get_node("/root/AppLifecycle").quit_reason() == "continue_saved"
	check("production owns actual continue_saved exit",save_exit_observed and flow.phase == flow.Phase.EXITING and flow._session == null)
	exit_reason = "continue_saved"
	finished = true
	report()

func report() -> void:
	var data := {"schema":"ui_save_retry_three_process_v1","mode":mode,"pid":OS.get_process_id(),"batch_nonce":OS.get_environment("USR_BATCH_NONCE"),"process_nonce":OS.get_environment("USR_PROCESS_NONCE"),"profile":OS.get_environment("USR_PROFILE"),"slot_root":SLOT_ROOT,"identity":identity_row(),"context":Slot.CONTEXT,"candidate_manifest_sha256":OS.get_environment("USR_MANIFEST"),"sources_sha256":OS.get_environment("USR_SOURCES_SHA256"),"checks":checks,"failures":checks.filter(func(row: Dictionary) -> bool: return not row.passed),"passed":passed(),"stage_completed":finished and passed(),"checkpoint":checkpoint,"observations":observations,"actions":actions,"actual_operations":operations,"exit_reason":exit_reason,"save_exit_observed":save_exit_observed,"simulation_time_scale":Engine.time_scale,"physics_hz":Engine.physics_ticks_per_second,"no_gameplay_state_injection":true,"initial_private_gate_used":true,"source_private_ui_save_retry_qualified":false,"public_continue_qualified":false,"native_sdk_qualified":false,"native_release_tested":false,"desktop_os_input":false,"human_acceptance":false,"full_campaign_qualified":false,"full_61_qualified":false,"published":false}
	if not write_json(output.path_join("report.json"),data): push_error("UI_SAVE_RETRY_REPORT_WRITE")

func finish_failure(reason: String) -> void:
	if finished: return
	check("stage completion " + reason,false)
	finished = true; exit_reason = reason
	report()
	for name: String in ["Sfx","Music"]:
		var node: Node = get_node_or_null("/root/" + name)
		if node != null and node.has_method("shutdown"): node.shutdown()
	get_tree().quit(1)

func finish_verified() -> void:
	if finished: return
	check("test exit cannot create another save",flow.phase == flow.Phase.IDLE and not flow.busy() and not get_node("/root/AppLifecycle").quit_started())
	finished = true; exit_reason = "ui_save_retry_verified"
	report()
	for name: String in ["Sfx","Music"]:
		var node: Node = get_node_or_null("/root/" + name)
		if node != null and node.has_method("shutdown"): node.shutdown()
	get_tree().quit(0 if passed() else 1)
