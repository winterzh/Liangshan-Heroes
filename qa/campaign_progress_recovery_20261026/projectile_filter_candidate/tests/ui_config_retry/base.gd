extends Node
## Real menu and settings callbacks; file/object observers are read-only.
const MenuScene = preload("res://scenes/menu.tscn")
const PanelScript = preload("res://scripts/settings_panel.gd")
const ConfigTransaction = preload("res://scripts/run_campaign_cfg_transaction.gd")
const Values = preload("res://scripts/run_campaign_cfg_values.gd")
const Provider = preload("res://scripts/run_content_identity.gd")
const Codec = preload("res://scripts/run_state_value_codec.gd")
const CANDIDATE_PARENT := "user://campaign_cfg_candidates"
const MODES := ["save_retry","readback"]
const ZERO := "0000000000000000000000000000000000000000000000000000000000000000"
var mode := ""
var output := ""
var trusted: Dictionary = {}
var flow: Variant
var menu: Variant
var checks: Array = []
var actions: Array = []
var observations: Dictionary = {}
var operations: Array = []
var checkpoint: Dictionary = {}
var previous: Dictionary = {}
var finished := false
var exit_reason := ""
var retained_writer: RefCounted
var retained_cfg: ConfigFile
var retained_active: Dictionary = {}
var retained_scope: Dictionary = {}
var retained_pending: Dictionary = {}

func check(label: String, good: bool, detail: Variant = null) -> bool:
	checks.append({"name":label,"passed":good,"detail":detail})
	print("UCR_CHECK " + ("PASS " if good else "FAIL ") + label)
	return good

func passed() -> bool:
	return not checks.is_empty() and checks.all(func(row: Dictionary) -> bool: return row.passed)

func read_json(path: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(FileAccess.get_file_as_string(path)) == OK else null

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

func hex_string(value: String, length: int) -> bool:
	if value.length() != length: return false
	for byte in value.to_utf8_buffer():
		if not (byte >= 48 and byte <= 57) and not (byte >= 97 and byte <= 102): return false
	return true

func profile_valid() -> bool:
	var profile: String = OS.get_environment("UCR_PROFILE").replace("\\","/").trim_suffix("/")
	var run: String = OS.get_environment("UCR_RUN").replace("\\","/").trim_suffix("/")
	if not profile.is_absolute_path() or not run.is_absolute_path() or not output.replace("\\","/").begins_with(run + "/"): return false
	if not OS.has_feature("editor") or OS.get_environment("STEAM_DISABLED") != "1" or not OS.get_environment("CAMPAIGN_QA").is_empty(): return false
	for key: String in ["LSH_CONTINUE_FLOW_QA","LSH_CONTINUE_FLOW_PROFILE","LEVEL","SKIRMISH","SMOKE_TEST","SCREENSHOT_DIR","SKIRMISH_AI"]:
		if not OS.get_environment(key).is_empty(): return false
	if ProjectSettings.globalize_path("res://").replace("\\","/").trim_suffix("/") != OS.get_environment("UCR_PROJECT").replace("\\","/").trim_suffix("/"): return false
	for key: String in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
		if OS.get_environment(key).replace("\\","/").trim_suffix("/") != profile.path_join(key.to_lower()): return false
	return OS.get_user_data_dir().replace("\\","/").begins_with(profile + "/") and hex_string(OS.get_environment("UCR_BATCH_NONCE"),32) and hex_string(OS.get_environment("UCR_PROCESS_NONCE"),32) and hex_string(OS.get_environment("UCR_MANIFEST"),64) and hex_string(OS.get_environment("UCR_SOURCES_SHA256"),64)

func exact(value: Variant) -> Variant:
	var encoded: Dictionary = Codec.new().encode(value)
	check("native typed Codec observation",encoded.get("ok",false),encoded.get("code",""))
	return encoded.get("value",{})

func identity_row() -> Dictionary:
	return {"content_version":trusted.get("content_version",""),"engine_sha256":trusted.get("engine_binary_sha256",""),"source_mode":trusted.get("source_mode",false)}

func file_row(path: String) -> Dictionary:
	var exists: bool = FileAccess.file_exists(path)
	var size := 0
	if exists:
		var file := FileAccess.open(path,FileAccess.READ)
		if not check("observed file opens read-only",file != null,path): return {}
		size = file.get_length(); file.close()
	return {"path":path,"exists":exists,"bytes":size,"sha256":FileAccess.get_sha256(path) if exists else ZERO}

func tree_row(path: String) -> Dictionary:
	if FileAccess.file_exists(path): return {"kind":"file","file":file_row(path)}
	if not DirAccess.dir_exists_absolute(path): return {"kind":"absent","files":{},"directories":[]}
	var files: Dictionary = {}
	var directories: Array[String] = []
	var pending: Array[String] = [""]
	while not pending.is_empty():
		var relative: String = pending.pop_front()
		var folder := DirAccess.open(path.path_join(relative))
		if not check("observed directory opens without mutation",folder != null,path.path_join(relative)): return {}
		for leaf: String in folder.get_files():
			if not check("observed business file is not a link",not folder.is_link(leaf)): return {}
			var key: String = relative.path_join(leaf) if not relative.is_empty() else leaf
			files[key] = FileAccess.get_sha256(path.path_join(key))
		for leaf: String in folder.get_directories():
			if not check("observed business directory is not a link",not folder.is_link(leaf)): return {}
			var key: String = relative.path_join(leaf) if not relative.is_empty() else leaf
			directories.append(key); pending.append(key)
		if not check("bounded settings transaction tree",files.size() < 32 and directories.size() < 16): return {}
	directories.sort()
	return {"kind":"directory","files":files,"directories":directories}

func disk_row() -> Dictionary:
	return {"cfg":file_row(ProjectSettings.globalize_path(ConfigTransaction.CFG_PATH)),"settings":file_row(ProjectSettings.globalize_path(Settings.PATH)),"journal_inventory":tree_row(ProjectSettings.globalize_path("user://campaign_cfg_transactions/v1")),"candidate_inventory":tree_row(ProjectSettings.globalize_path(CANDIDATE_PARENT))}

func prefs_row() -> Dictionary:
	var prefs: Dictionary = {}
	for key: String in ["ai_difficulty","victory_mode","scale_on","enemy_mult","hero_mult","hero_mult_touched","defense_rand_waves","defense_interval"]: prefs[key] = Campaign.get(key)
	return {"campaign":prefs,"settings_formation":Settings.formation_mode,"settings_memory_sha256":Settings._settings_config().encode_to_text().sha256_text(),"unlocked":Campaign.unlocked,"records":Campaign.records.duplicate(true),"cloud_owner":Campaign.cloud_owner}

func no_world() -> bool:
	return get_tree().current_scene == menu and get_tree().root.get_children().all(func(n: Node) -> bool: return n.get_script() == null or n.get_script().resource_path != "res://scripts/battle.gd")

func text_button(parent: Node, text: String, prefix := false) -> Variant:
	var found: Variant = null
	var pending: Array = [parent]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Button and node.is_visible_in_tree() and (node.text.begins_with(text) if prefix else node.text == text):
			if found != null: return null
			found = node
		pending.append_array(node.get_children())
	return found

func show_control(control: Control) -> bool:
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await get_tree().process_frame
	await get_tree().process_frame
	var rect: Rect2 = control.get_global_rect()
	var visible: bool = control.is_visible_in_tree() and get_viewport().get_visible_rect().encloses(rect)
	parent = control.get_parent()
	while parent != null:
		if parent is ScrollContainer: visible = visible and parent.get_global_rect().encloses(rect)
		parent = parent.get_parent()
	return check("actual settings control lies inside visible viewport and scroll",visible)

func press(button: Variant, label: String) -> bool:
	if not check("visible enabled original button " + label,is_instance_valid(button) and button is Button and button.is_visible_in_tree() and not button.disabled and not button.is_blocking_signals() and not button.pressed.get_connections().is_empty()): return false
	actions.append({"kind":"original_button_callback","purpose":label,"text":button.text,"frame":str(Engine.get_process_frames()),"connections":button.pressed.get_connections().size()})
	button.pressed.emit()
	return true

func on_operation(value: Dictionary) -> void:
	operations.append({"result":value.duplicate(true),"phase":int(flow.phase),"frame":str(Engine.get_process_frames())})

func gate(phase: String, detail: Dictionary) -> bool:
	var request := {"schema":"ui_config_retry_gate_v1","mode":mode,"phase":phase,"pid":OS.get_process_id(),"batch_nonce":OS.get_environment("UCR_BATCH_NONCE"),"process_nonce":OS.get_environment("UCR_PROCESS_NONCE"),"profile":OS.get_environment("UCR_PROFILE"),"content_version":trusted.content_version,"engine_sha256":trusted.engine_binary_sha256,"detail":detail}
	var name: String = phase + ".request.json"
	if not check("publish unique fault gate " + phase,publish(name,request)): return false
	var digest: String = FileAccess.get_sha256(output.path_join(name))
	var path: String = output.path_join(phase + ".ack.json")
	var deadline: int = Time.get_ticks_msec() + 90000
	while not FileAccess.file_exists(path) and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	var ack: Variant = read_json(path)
	var keys := ["schema","mode","phase","pid","batch_nonce","process_nonce","profile","content_version","engine_sha256","request_sha256","ok"]
	var good: bool = typeof(ack) == TYPE_DICTIONARY and ack.size() == keys.size() and ack.has_all(keys)
	if good:
		good = ack.schema == "ui_config_retry_ack_v1" and typeof(ack.ok) == TYPE_BOOL and ack.ok and ack.request_sha256 == digest and typeof(ack.pid) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(ack.pid)) and float(ack.pid) == float(OS.get_process_id())
		for key: String in ["mode","phase","batch_nonce","process_nonce","profile","content_version","engine_sha256"]: good = good and typeof(ack[key]) == TYPE_STRING and ack[key] == request[key]
	observations["gate_" + phase] = {"request_sha256":digest,"ack":ack}
	return check("exact original host gate acknowledgment " + phase,good)

func wait_changed_result(original: Dictionary) -> bool:
	var deadline: int = Time.get_ticks_msec() + 90000
	while (is_same(flow.last_result,original) or Engine.is_in_physics_frame()) and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	return check("original deferred config callback returned a new result",not is_same(flow.last_result,original) and not Engine.is_in_physics_frame())

func pending_observation() -> Dictionary:
	var writer: RefCounted = Campaign._cfg_writer
	var head: Dictionary = writer._chain()
	var semantics: Dictionary = Values.semantics(writer._frozen_cfg)
	var owner_path: String = writer.directory.path_join("writing/owner.json")
	return {"writer_instance_id":str(writer.get_instance_id()),"frozen_cfg_instance_id":str(writer._frozen_cfg.get_instance_id()),"transaction":writer._active.transaction,"stage":writer._active.stage,"directory":writer.directory,"owner_path":owner_path,"owner_raw":writer._lock_raw,"owner_sha256":FileAccess.get_sha256(owner_path),"locked":writer._locked,"lock_created":writer._lock_created,"head_ok":head.get("ok",false),"head_revision":head.get("revision",-1),"head_sha256":head.get("file_sha256",""),"original_sha256":writer._active.original_sha256,"exact_active":exact(writer._active),"exact_request_scope":exact(Campaign._cfg_writer_scope),"exact_frozen_semantics":exact(semantics),"exact_failed_prefs":exact(Campaign._prefs_failed),"exact_failed_scope":exact(Campaign._prefs_failed_scope),"frozen_text_sha256":writer._frozen_cfg.encode_to_text().sha256_text(),"pending_record_empty":writer._pending_record.is_empty(),"inventory":writer.inventory(),"disk":disk_row(),"tree_paused":get_tree().paused,"flow_phase":int(flow.phase)}

func failure_valid() -> bool:
	return check("actual settings failure is retained CFG_STAGE_PARENT",flow.phase == flow.Phase.ERROR and flow.last_result.get("code") == "CFG_STAGE_PARENT" and not flow.last_result.get("ok",true) and flow.last_result.get("config_pending",false) and Campaign._cfg_writer != null and Campaign._cfg_writer.busy() and Campaign._cfg_writer._frozen_cfg != null and Campaign._cfg_writer._active.get("stage") == "staging" and get_tree().paused and flow.find_child("RetryCampaignConfig",true,false) != null and no_world(),flow.last_result)

func retain_writer() -> void:
	retained_writer = Campaign._cfg_writer
	retained_cfg = retained_writer._frozen_cfg
	retained_active = retained_writer._active
	retained_scope = Campaign._cfg_writer_scope
	retained_pending = pending_observation()

func same_writer(compare_disk := true) -> bool:
	if not check("same original Campaign writer frozen ConfigFile active and request objects",Campaign._cfg_writer == retained_writer and retained_writer._frozen_cfg == retained_cfg and is_same(retained_active,retained_writer._active) and is_same(retained_scope,Campaign._cfg_writer_scope)): return false
	var current: Dictionary = pending_observation()
	var expected: Dictionary = retained_pending.duplicate(true)
	if not compare_disk:
		current.erase("disk"); expected.erase("disk")
	return check("original transaction CAS owner frozen proposal and held lock preserved",current == expected and current.head_ok and current.head_revision == 0 and current.head_sha256 == ZERO and current.original_sha256 == ZERO and current.pending_record_empty and current.locked and current.lock_created)

func journal_row() -> Dictionary:
	var store := ConfigTransaction.new()
	var head: Dictionary = store.open_head()
	if not check("real closed configuration journal reads without recovery",head.get("ok",false),head): return {}
	var prepared: Dictionary = store._verified("record_0000000001.json")
	var applied: Dictionary = store._verified("record_0000000002.json")
	if not check("one actual transaction has prepared1 then applied2",prepared.get("ok",false) and applied.get("ok",false) and head.revision == 2 and prepared.revision == 1 and applied.revision == 2 and prepared.document.state == "prepared" and applied.document.state == "applied" and applied.previous == prepared.file_sha256 and head.file_sha256 == applied.file_sha256): return {}
	for key: String in ConfigTransaction.RECORD_FIELDS:
		if key not in ["generation","state"]: check("prepared applied field retained " + key,prepared.document[key] == applied.document[key])
	check("actual journal scope contains only this preference write",applied.document.operation == "prefs" and applied.document.run_token.is_empty() and applied.document.intent_sha256.is_empty() and applied.document.original_sha256 == ZERO and applied.document.original_owner.is_empty() and applied.document.target_owner.is_empty() and applied.document.content_version == trusted.content_version and applied.document.engine_sha256 == trusted.engine_binary_sha256)
	return {"generation":head.revision,"file_sha256":head.file_sha256,"transaction":applied.document.transaction,"prepared":prepared,"applied":applied,"inventory":store.inventory()}

func save_checkpoint() -> void:
	var disk: Dictionary = disk_row()
	var prefs: Dictionary = prefs_row()
	var journal: Dictionary = journal_row()
	checkpoint = {"disk":disk,"exact_disk":exact(disk),"prefs":prefs,"exact_prefs":exact(prefs),"journal":journal,"exact_journal":exact(journal)}

func report() -> void:
	var data := {"schema":"ui_config_retry_two_process_v1","mode":mode,"pid":OS.get_process_id(),"batch_nonce":OS.get_environment("UCR_BATCH_NONCE"),"process_nonce":OS.get_environment("UCR_PROCESS_NONCE"),"profile":OS.get_environment("UCR_PROFILE"),"identity":identity_row(),"candidate_manifest_sha256":OS.get_environment("UCR_MANIFEST"),"sources_sha256":OS.get_environment("UCR_SOURCES_SHA256"),"checks":checks,"failures":checks.filter(func(row: Dictionary) -> bool: return not row.passed),"passed":passed(),"stage_completed":finished and passed(),"checkpoint":checkpoint,"observations":observations,"actions":actions,"actual_operations":operations,"exit_reason":exit_reason,"simulation_time_scale":Engine.time_scale,"physics_hz":Engine.physics_ticks_per_second,"no_gameplay_state_injection":true,"initial_private_gate_used":false,"source_private_ui_config_retry_qualified":false,"public_continue_qualified":false,"native_sdk_qualified":false,"native_release_tested":false,"desktop_os_input":false,"human_acceptance":false,"full_campaign_qualified":false,"full_61_qualified":false,"published":false}
	if not write_json(output.path_join("report.json"),data): push_error("UI_CONFIG_RETRY_REPORT_WRITE")

func finish(reason := "ui_config_retry_verified") -> void:
	if finished: return
	if reason != "ui_config_retry_verified": check("stage completion " + reason,false)
	else: check("test exit has no pending config or world",no_world() and flow.phase == flow.Phase.IDLE and not Campaign.persistence_busy() and not get_tree().paused and not get_node("/root/AppLifecycle").quit_started())
	finished = true; exit_reason = reason
	report()
	for name: String in ["Sfx","Music"]:
		var node: Node = get_node_or_null("/root/" + name)
		if node != null and node.has_method("shutdown"): node.shutdown()
	get_tree().quit(0 if passed() else 1)
