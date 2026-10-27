extends Node
## Explicit permanent-clock-fault model. Only inject_fault_once calls a mutating
## simulation API; every other helper observes or invokes real visible UI input.
const MenuScene = preload("res://scenes/menu.tscn")
const BattleScript = preload("res://scripts/battle.gd")
const Classic = preload("res://scripts/levels/skirmish.gd")
const Slot = preload("res://scripts/run_slot_store.gd")
const LocalLifecycle = preload("res://scripts/run_local_lifecycle.gd")
const Provider = preload("res://scripts/run_content_identity.gd")
const Codec = preload("res://scripts/run_state_value_codec.gd")
const SLOT_ROOT := "user://continue/v1"
const FAULT := "QA_INJECTED_CLOCK_FAULT"
const MODES := ["fault_exit","restart_no_slot"]
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
var exit_reason := ""
var release_exit_observed := false
var capture_count := 0
var fault_call_count := 0
var registration_observed := false
var original_battle: Variant
var original_clock: RefCounted
var original_barrier: Node
var retained_scope: Dictionary = {}
var held_before_fault: Dictionary = {}

func check(label: String, good: bool, detail: Variant = null) -> bool:
	checks.append({"name":label,"passed":good,"detail":detail})
	print("URF_CHECK " + ("PASS " if good else "FAIL ") + label)
	return good

func passed() -> bool:
	return not checks.is_empty() and checks.all(func(row: Dictionary) -> bool: return row.passed)

func exact(value: Variant) -> Variant:
	var encoded: Dictionary = Codec.new().encode(value)
	if not check("read-only evidence retains actual typed Codec",encoded.get("ok",false),{"code":encoded.get("code",""),"path":encoded.get("path","")}): return null
	return encoded.value

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

func profile_valid() -> bool:
	var profile: String = OS.get_environment("URF_PROFILE").replace("\\","/").trim_suffix("/")
	var run_root: String = OS.get_environment("URF_RUN").replace("\\","/").trim_suffix("/")
	var stage: String = output.replace("\\","/")
	if not profile.is_absolute_path() or not run_root.is_absolute_path() or not stage.begins_with(run_root + "/") or ".." in stage.split("/"): return false
	if not DirAccess.dir_exists_absolute(output) or not OS.has_feature("editor") or OS.get_environment("STEAM_DISABLED") != "1" or not OS.get_environment("CAMPAIGN_QA").is_empty(): return false
	if OS.get_environment("LSH_CONTINUE_FLOW_QA") != "1" or OS.get_environment("LSH_CONTINUE_FLOW_PROFILE") != OS.get_environment("URF_PROFILE"): return false
	if ProjectSettings.globalize_path("res://").replace("\\","/").trim_suffix("/") != OS.get_environment("URF_PROJECT").replace("\\","/").trim_suffix("/"): return false
	for key: String in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
		if OS.get_environment(key).replace("\\","/").trim_suffix("/") != profile.path_join(key.to_lower()): return false
	return OS.get_user_data_dir().replace("\\","/").begins_with(profile + "/") and LocalLifecycle._hex(OS.get_environment("URF_BATCH_NONCE"),32) and LocalLifecycle._hex(OS.get_environment("URF_PROCESS_NONCE"),32) and LocalLifecycle._hex(OS.get_environment("URF_MANIFEST"),64) and LocalLifecycle._hex(OS.get_environment("URF_SOURCES_SHA256"),64)

func identity_row() -> Dictionary:
	return {"content_version":trusted.get("content_version",""),"engine_sha256":trusted.get("engine_binary_sha256",""),"source_mode":trusted.get("source_mode",false)}

func named(parent: Node, name: String) -> Variant:
	return parent.find_child(name,true,false)

func text_button(parent: Node, text: String, prefix := false) -> Variant:
	var pending: Array = [parent]
	var found: Variant = null
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Button and node.is_visible_in_tree() and (node.text.begins_with(text) if prefix else node.text == text):
			if found != null: return null
			found = node
		pending.append_array(node.get_children())
	return found

func press(button: Variant, purpose: String) -> bool:
	if not check("visible enabled original button " + purpose,is_instance_valid(button) and button is Button and button.is_visible_in_tree() and not button.disabled and not button.is_blocking_signals() and not button.pressed.get_connections().is_empty()): return false
	actions.append({"kind":"original_button_callback","purpose":purpose,"name":String(button.name),"text":button.text,"connections":button.pressed.get_connections().size(),"frame":str(Engine.get_process_frames()),"pid":OS.get_process_id()})
	button.pressed.emit()
	return true

func escape_viewport() -> void:
	var key := InputEventKey.new(); key.keycode = KEY_ESCAPE; key.pressed = true
	get_viewport().push_input(key)
	key = key.duplicate(); key.pressed = false; get_viewport().push_input(key)
	actions.append({"kind":"viewport_key","key":"Escape","desktop_os_input":false})

func pause_world() -> bool:
	if not check("classic world runs before actual Escape",not get_tree().paused and not battle.hud._pause_root.visible): return false
	escape_viewport()
	await get_tree().process_frame
	return check("actual viewport Escape pauses original HUD",get_tree().paused and battle.hud._pause_root.visible and battle._save_barrier.state == battle._save_barrier.State.IDLE)

func on_operation(value: Dictionary) -> void:
	result = value.duplicate(true); received = true
	operations.append({"result":value.duplicate(true),"frame":str(Engine.get_process_frames()),"phase":int(flow.phase),"pid":OS.get_process_id()})

func wait_operation() -> bool:
	var deadline: int = Time.get_ticks_msec() + 90000
	while (not received or Engine.is_in_physics_frame()) and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	return check("original Flow operation returned outside physics",received and not Engine.is_in_physics_frame())

func file_row(path: String) -> Dictionary:
	var absolute: String = ProjectSettings.globalize_path(path).replace("\\","/")
	if not FileAccess.file_exists(absolute): return {"path":absolute,"exists":false,"bytes":0,"sha256":Slot.ZERO}
	var file := FileAccess.open(absolute,FileAccess.READ)
	if not check("business evidence file opens read-only",file != null,absolute): return {}
	var size: int = file.get_length(); file.close()
	var digest: String = FileAccess.get_sha256(absolute)
	if not check("business evidence hash is complete",LocalLifecycle._hex(digest,64),absolute): return {}
	return {"path":absolute,"exists":true,"bytes":size,"sha256":digest}

func tree_row(path: String) -> Dictionary:
	var absolute: String = ProjectSettings.globalize_path(path).replace("\\","/")
	if FileAccess.file_exists(absolute): return {"path":absolute,"kind":"file","file":file_row(absolute)}
	if not DirAccess.dir_exists_absolute(absolute): return {"path":absolute,"kind":"absent","files":{},"directories":[]}
	var files: Dictionary = {}
	var directories: Array[String] = []
	var pending: Array[String] = [""]
	while not pending.is_empty():
		var relative: String = pending.pop_front()
		var folder := DirAccess.open(absolute.path_join(relative))
		if not check("business inventory opens without mutation",folder != null): return {}
		for leaf: String in folder.get_files():
			if not check("business inventory rejects file links",not folder.is_link(leaf)): return {}
			var key: String = relative.path_join(leaf) if not relative.is_empty() else leaf
			var digest: String = FileAccess.get_sha256(absolute.path_join(key))
			if not check("business inventory contains complete hashes",LocalLifecycle._hex(digest,64)): return {}
			files[key] = digest
		for leaf: String in folder.get_directories():
			if not check("business inventory rejects directory links",not folder.is_link(leaf)): return {}
			var key: String = relative.path_join(leaf) if not relative.is_empty() else leaf
			directories.append(key); pending.append(key)
		if not check("business inventory remains bounded",files.size() < 64 and directories.size() < 32): return {}
	directories.sort()
	return {"path":absolute,"kind":"directory","files":files,"directories":directories}

func business_row() -> Dictionary:
	return {"continue":tree_row(SLOT_ROOT),"cfg":file_row(Campaign.SAVE_PATH),"cfg_journal":tree_row("user://campaign_cfg_transactions/v1"),"cfg_candidates":tree_row("user://campaign_cfg_candidates"),"steam_receipts":tree_row("user://steam_receipts/v1")}

func progress_row() -> Dictionary:
	var service: Node = get_node("/root/SteamService")
	check("Steam-disabled process has no credited run or native ledger",not service.available and not service.stats_ready and service._active_run == 0 and service._run_counter == 0 and service._local_runs == null)
	return {"records":Campaign.records.duplicate(true),"unlocked":Campaign.unlocked,"owner":Campaign.cloud_owner,"stats":service.state.stats.duplicate(true),"achievements":service.state.unlocked.duplicate(true),"settled":service.state.settled.duplicate(true),"active_run":service._active_run,"run_counter":service._run_counter}

func world_row() -> Dictionary:
	var units: Array = []
	for unit: Variant in battle.units:
		if not is_instance_valid(unit): continue
		units.append({"id":str(unit.entity_id),"instance_id":str(unit.get_instance_id()),"key":unit.key,"faction":unit.faction,"hp":unit.hp,"position":unit.position,"state":unit._state,"home":unit._home,"queue":unit._train_queue.duplicate(true),"train_t":unit._train_t,"build_progress":unit.build_progress})
	units.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.id) < int(b.id))
	return {"phase":int(battle.phase),"gold":battle.gold,"wood":battle.wood,"kills":battle.kills,"valid_kills":battle._steam_valid_kills,"next_entity_id":str(battle.next_entity_id),"pop_cap":battle.pop_cap,"level":{"wave":battle.level._wave,"timer":battle.level._wave_t,"started":battle.level._started,"spawned":battle.level._wave_spawned},"units":units}

func clock_row() -> Dictionary:
	var clock: RefCounted = battle._run_clock
	return {"tick":str(clock._tick),"next_tick":str(clock._next_tick),"cache_frame":str(clock._cache_frame),"engine_anchor":str(clock._engine_anchor),"initialized":clock._initialized,"completed":clock._completed,"held":clock._held,"in_step":clock.in_step(),"fault":clock.fault()}

func held_scope() -> Dictionary:
	var service: Node = get_node("/root/SteamService")
	return {"battle_instance_id":str(battle.get_instance_id()),"clock_instance_id":str(battle._run_clock.get_instance_id()),"barrier_instance_id":str(battle._save_barrier.get_instance_id()),"tree_paused":get_tree().paused,"barrier_state":int(battle._save_barrier.state),"barrier_held_clock":battle._save_barrier._held_clock,"input_closed":battle._save_barrier.input_closed(),"clock":clock_row(),"exact_world":exact(world_row()),"exact_expected":exact(flow._expected),"local_receipt_absent":battle._continue_receipt == null,"steam_run_id":battle._steam_run_id,"exact_lease":exact({"active":service._active_run,"counter":service._run_counter,"account":service.account,"available":service.available,"ready":service.stats_ready,"context":service._context.duplicate(true),"local_absent":service._local_runs == null})}

func connection_rows() -> Array:
	var rows: Array = []
	var connections: Array = battle._save_barrier.capture_ready.get_connections()
	for index: int in range(connections.size()):
		var entry: Dictionary = connections[index]
		var callable: Callable = entry.callable
		rows.append({"index":index,"valid":callable.is_valid(),"observer":callable == Callable(self,"inject_fault_once"),"flow":callable == Callable(flow,"_capture_ready"),"method":String(callable.get_method()),"object_id":str(callable.get_object_id()),"flags":int(entry.flags)})
	return rows

func arm_fault() -> bool:
	var rows: Array = connection_rows()
	if not check("model observer registered before original Flow callback",capture_count == 0 and fault_call_count == 0 and not battle._save_barrier.capture_ready.is_connected(inject_fault_once) and not battle._save_barrier.capture_ready.is_connected(Callable(flow,"_capture_ready"))): return false
	original_battle = battle; original_clock = battle._run_clock; original_barrier = battle._save_barrier
	battle._save_barrier.capture_ready.connect(inject_fault_once,CONNECT_ONE_SHOT)
	observations["connections_before_save"] = connection_rows()
	return check("only observer is registered before SaveAndExit",rows.is_empty() and observations.connections_before_save.size() == 1)

func observe_registration() -> bool:
	var rows: Array = connection_rows()
	var observers := 0
	var callbacks := 0
	var valid := true
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		valid = valid and row.index == index and row.valid and row.observer != row.flow and (row.flags & CONNECT_ONE_SHOT) != 0
		if row.observer:
			observers += 1; valid = valid and row.object_id == str(get_instance_id()) and row.method == "inject_fault_once"
		if row.flow:
			callbacks += 1; valid = valid and row.object_id == str(flow.get_instance_id()) and row.method == "_capture_ready"
	registration_observed = rows.size() == 2 and observers == 1 and callbacks == 1 and valid and capture_count == 0 and fault_call_count == 0 and flow._session == null and flow.phase == flow.Phase.SAVING and battle._save_barrier.state == battle._save_barrier.State.REQUESTED
	observations["requested_registration"] = {"connections":rows,"frame":str(Engine.get_process_frames()),"phase":int(flow.phase),"barrier_state":int(battle._save_barrier.state),"session_absent":flow._session == null,"calls":capture_count,"fault_calls":fault_call_count}
	return check("same synchronous request registers both callbacks before any capture",registration_observed)

func inject_fault_once(record: Dictionary) -> void:
	capture_count += 1
	if battle._save_barrier.capture_ready.is_connected(inject_fault_once): battle._save_barrier.capture_ready.disconnect(inject_fault_once)
	var healthy: Dictionary = battle._save_barrier.health()
	var captured: Dictionary = battle._run_clock.capture()
	var eligible: bool = registration_observed and capture_count == 1 and fault_call_count == 0 and flow.phase == flow.Phase.SAVING and flow._session == null and get_tree().paused and not Engine.is_in_physics_frame() and battle == original_battle and battle._run_clock == original_clock and battle._save_barrier == original_barrier and battle._save_barrier.state == battle._save_barrier.State.HELD and battle._save_barrier._held_clock and battle._run_clock._held and not battle._run_clock.in_step() and healthy.get("ok",false) and captured.get("ok",false) and captured.get("record",{}) == record
	observations["capture_observer"] = {"calls":capture_count,"registration_observed":registration_observed,"healthy":healthy,"clock_capture":captured,"signal_clock":record.duplicate(true),"outside_physics":not Engine.is_in_physics_frame(),"session_absent":flow._session == null,"held":battle._save_barrier.state == battle._save_barrier.State.HELD,"disconnected":not battle._save_barrier.capture_ready.is_connected(inject_fault_once),"flow_callback_connected_at_emit":battle._save_barrier.capture_ready.is_connected(Callable(flow,"_capture_ready")),"frame":str(Engine.get_process_frames())}
	if not check("healthy real HELD observer precedes actual Session and is eligible once",eligible): return
	held_before_fault = held_scope()
	if not passed(): return
	fault_call_count += 1
	# Sole fault injection; never clear _fault, replace a clock, or install Session.
	battle._run_clock.abort_step(FAULT)
	actions.append({"kind":"explicit_permanent_fault_injection","api":"run_battle_clock.abort_step","code":FAULT,"count":fault_call_count,"frame":str(Engine.get_process_frames()),"natural_fault_reproduced":false})
	retained_scope = held_scope()
	var expected: Dictionary = held_before_fault.duplicate(true)
	expected.clock["fault"] = FAULT
	check("abort changes only permanent fault in the healthy held observation",retained_scope == expected and fault_call_count == 1)
	observations["held_before_fault"] = held_before_fault
	observations["held_after_fault"] = retained_scope.duplicate(true)

func same_held(label: String) -> bool:
	var same: bool = get_tree().current_scene == original_battle and battle == original_battle and battle._run_clock == original_clock and battle._save_barrier == original_barrier and flow._source == battle and flow._session == null
	if not check(label + " retains real Battle clock barrier; nonpending Session is disposed",same): return false
	if not check(label + " preserves exact held clock world lease and zero-slot CAS",held_scope() == retained_scope): return false
	return check(label + " cannot clear the permanent fault",fault_call_count == 1 and battle._run_clock.fault() == FAULT and not battle._save_barrier.health().get("ok",true) and battle._save_barrier.health().get("code") == FAULT)

func unchanged_business(label: String) -> bool:
	var current: Dictionary = business_row()
	var progress: Dictionary = progress_row()
	return check(label + " preserves all durable business bytes and rewards",exact(current) == checkpoint.exact_business and exact(progress) == checkpoint.exact_progress)

func load_previous() -> bool:
	var path: String = OS.get_environment("URF_PREVIOUS")
	if not check("previous actual report hash matches",FileAccess.get_sha256(path) == OS.get_environment("URF_PREVIOUS_SHA")): return false
	var value: Variant = read_json(path)
	if not check("previous actual fault-model process completed",typeof(value) == TYPE_DICTIONARY and value.get("schema") == "ui_release_fault_model_v1" and value.get("mode") == "fault_exit" and value.get("passed",false) and value.get("stage_completed",false) and value.get("fault_call_count") == 1 and value.get("release_exit_observed",false) and value.get("exit_reason") == "continue_failed" and value.get("pid") != OS.get_process_id()): return false
	previous = value
	for key: String in ["profile","batch_nonce","sources_sha256","candidate_manifest_sha256"]:
		var expected: String = OS.get_environment({"profile":"URF_PROFILE","batch_nonce":"URF_BATCH_NONCE","sources_sha256":"URF_SOURCES_SHA256","candidate_manifest_sha256":"URF_MANIFEST"}[key])
		if not check("predecessor exact scope " + key,previous.get(key) == expected): return false
	if not check("predecessor has independent nonce and same installed identity",previous.get("process_nonce") != OS.get_environment("URF_PROCESS_NONCE") and previous.get("identity") == identity_row()): return false
	checkpoint = previous.checkpoint.duplicate(true)
	var disk: Dictionary = Codec.new().decode(checkpoint.get("exact_business",{}))
	var progress: Dictionary = Codec.new().decode(checkpoint.get("exact_progress",{}))
	return check("predecessor business and progress checkpoints decode losslessly",disk.get("ok",false) and typeof(disk.get("value")) == TYPE_DICTIONARY and progress.get("ok",false) and typeof(progress.get("value")) == TYPE_DICTIONARY)

func no_world() -> bool:
	return is_instance_valid(menu) and get_tree().current_scene == menu and get_tree().root.get_children().all(func(node: Node) -> bool: return node.get_script() != BattleScript)

func report() -> void:
	var data: Dictionary = {"schema":"ui_release_fault_model_v1","mode":mode,"pid":OS.get_process_id(),"batch_nonce":OS.get_environment("URF_BATCH_NONCE"),"process_nonce":OS.get_environment("URF_PROCESS_NONCE"),"profile":OS.get_environment("URF_PROFILE"),"identity":identity_row(),"context":Slot.CONTEXT,"candidate_manifest_sha256":OS.get_environment("URF_MANIFEST"),"sources_sha256":OS.get_environment("URF_SOURCES_SHA256"),"checks":checks,"failures":checks.filter(func(row: Dictionary) -> bool: return not row.passed),"passed":passed(),"stage_completed":finished and passed(),"checkpoint":checkpoint,"observations":observations,"actions":actions,"actual_operations":operations,"exit_reason":exit_reason,"release_exit_observed":release_exit_observed,"capture_count":capture_count,"fault_call_count":fault_call_count,"simulation_time_scale":Engine.time_scale,"physics_hz":Engine.physics_ticks_per_second,"fault_model":true,"fault_model_code":FAULT,"natural_fault_reproduced":false,"no_gameplay_state_injection":false,"no_hp_position_resource_injection":true,"production_method_overrides":0,"initial_private_gate_used":true,"source_private_ui_release_fault_model_qualified":false,"public_continue_qualified":false,"native_sdk_qualified":false,"native_release_tested":false,"desktop_os_input":false,"human_acceptance":false,"full_campaign_qualified":false,"full_61_qualified":false,"published":false}
	if not write_json(output.path_join("report.json"),data): push_error("UI_RELEASE_FAULT_REPORT_WRITE")

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
	check("test restart exit has no saved Battle or production quit",no_world() and flow.phase == flow.Phase.IDLE and not flow.busy() and not get_node("/root/AppLifecycle").quit_started())
	finished = true; exit_reason = "ui_release_fault_model_verified"
	report()
	for name: String in ["Sfx","Music"]:
		var node: Node = get_node_or_null("/root/" + name)
		if node != null and node.has_method("shutdown"): node.shutdown()
	get_tree().quit(0 if passed() else 1)
