extends "source_driver.gd"
## C alone adds real terminal persistence faults; inherited A/B/D are unchanged.
const ConfigTransaction := preload("res://scripts/run_campaign_cfg_transaction.gd")
const ProgressCoordinator := preload("res://scripts/run_campaign_progress_coordinator.gd")
const ConfigValues := preload("res://scripts/run_campaign_cfg_values.gd")
const CANDIDATE_PARENT := "user://campaign_cfg_candidates"
var terminal_operations: Array = []
var terminal_gates: Array = []
var retry_observation: Dictionary = {}
var retained_coordinator: RefCounted
var retained_writer: RefCounted
var retained_frozen: ConfigFile
var retained_active: Dictionary = {}
var retained_intent: Dictionary = {}
var retained_gate_scope: Dictionary = {}
var retained_pending: Dictionary = {}

func retry_exact(value: Variant) -> Variant:
	var encoded: Dictionary = Codec.new().encode(value)
	if not check(encoded.get("ok", false), "terminal retry evidence retains production typed Codec"): return null
	return encoded.value

func active_observation(value: Dictionary) -> Dictionary:
	# QA evidence only: preserve actual String/StringName keys without changing
	# the writer dictionary or broadening the production Codec accepted domain.
	var expected: Array = ["request","original_sha256","original_owner","transaction","stage","semantics_sha256"]
	var keys: Array = value.keys()
	if not check(keys.size() == expected.size(), "staging active observation has exactly six original keys"): return {}
	var seen: Dictionary = {}
	var entries: Array = []
	for index: int in range(keys.size()):
		var original_key: Variant = keys[index]
		var key_type: int = typeof(original_key)
		if not check(key_type in [TYPE_STRING,TYPE_STRING_NAME], "staging active key retains String or StringName type"): return {}
		var key_text: String = String(original_key)
		if not check(key_text in expected and not seen.has(key_text), "staging active key text is expected and unique"): return {}
		var encoded: Dictionary = Codec.new().encode(value[original_key])
		if not check(encoded.get("ok",false), "staging active original value retains production typed Codec"): return {}
		seen[key_text] = true
		entries.append({"index":index,"key_type":key_type,"key_text":key_text,"value":encoded.value})
	if not check(seen.size() == expected.size() and seen.has_all(expected), "staging active observation covers all six original fields"): return {}
	return {"schema":"qa_cfg_staging_active_observation_v1","entries":entries}

func retry_file(path: String) -> Dictionary:
	var absolute: String = ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()
	if not FileAccess.file_exists(absolute): return {"path":absolute,"exists":false,"bytes":0,"sha256":ConfigTransaction.ZERO}
	var file: FileAccess = FileAccess.open(absolute, FileAccess.READ)
	if not check(file != null, "terminal retry read-only file opens"): return {}
	var size: int = file.get_length()
	file.close()
	var digest: String = FileAccess.get_sha256(absolute)
	if not check(Intent.hex(digest,64), "terminal retry native file SHA exists"): return {}
	return {"path":absolute,"exists":true,"bytes":size,"sha256":digest}

func retry_publish(name: String, value: Dictionary) -> bool:
	var folder: String = OS.get_environment("UTR_GATE_DIR").replace("\\", "/").simplify_path()
	if not check(folder.is_absolute_path() and DirAccess.dir_exists_absolute(folder) and name.get_file() == name,
		"terminal retry evidence stays in existing private host directory"): return false
	var path: String = folder.path_join(name)
	if not check(not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path), "terminal retry evidence is not overwritten " + name): return false
	var temporary: String = path + ".partial"
	if FileAccess.file_exists(temporary) or DirAccess.dir_exists_absolute(temporary): return check(false, "terminal retry partial already exists")
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return check(false, "terminal retry evidence opens for exclusive fresh path")
	file.store_string(JSON.stringify(value,"\t")); file.flush()
	var good: bool = file.get_error() == OK
	file.close()
	return check(good and DirAccess.rename_absolute(temporary,path) == OK, "terminal retry evidence publishes " + name)

func retry_gate(phase: String, detail: Dictionary) -> bool:
	var request: Dictionary = {"schema":"ui_terminal_retry_gate_v1","mode":mode,"phase":phase,"pid":OS.get_process_id(),
		"batch_nonce":OS.get_environment("GVT_NONCE"),"process_nonce":OS.get_environment("GVT_PROCESS_NONCE"),
		"profile":OS.get_environment("GVT_PROFILE"),"content_version":trusted.content_version,
		"engine_sha256":trusted.engine_binary_sha256,"detail":detail}
	var name: String = phase + ".request.json"
	if not retry_publish(name,request): return false
	var folder: String = OS.get_environment("UTR_GATE_DIR")
	var digest: String = FileAccess.get_sha256(folder.path_join(name))
	var ack_path: String = folder.path_join(phase + ".ack.json")
	var limit: int = Time.get_ticks_msec() + 90000
	while not FileAccess.file_exists(ack_path) and Time.get_ticks_msec() < limit: await get_tree().process_frame
	var ack: Variant = JSON.parse_string(FileAccess.get_file_as_string(ack_path)) if FileAccess.file_exists(ack_path) else null
	var keys: Array = ["schema","mode","phase","pid","batch_nonce","process_nonce","profile","content_version","engine_sha256","request_sha256","ok"]
	var good: bool = typeof(ack) == TYPE_DICTIONARY and ack.size() == keys.size() and ack.has_all(keys)
	if good:
		good = ack.schema == "ui_terminal_retry_ack_v1" and typeof(ack.ok) == TYPE_BOOL and ack.ok and ack.request_sha256 == digest \
			and typeof(ack.pid) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(ack.pid)) and float(ack.pid) == float(OS.get_process_id())
		for key: String in ["mode","phase","batch_nonce","process_nonce","profile","content_version","engine_sha256"]:
			good = good and typeof(ack[key]) == TYPE_STRING and ack[key] == request[key]
	terminal_gates.append({"phase":phase,"request_sha256":digest,"ack":ack})
	return check(good, "terminal retry exact own host ACK " + phase)

func retry_on_operation(value: Dictionary) -> void:
	terminal_operations.append({"result":value.duplicate(true),"phase":int(flow.phase),"frame":str(Engine.get_process_frames())})

func retry_wait_operation(count: int) -> bool:
	var limit: int = Time.get_ticks_msec() + 90000
	while (terminal_operations.size() < count or Engine.is_in_physics_frame()) and Time.get_ticks_msec() < limit:
		await get_tree().process_frame
	return check(terminal_operations.size() == count and not Engine.is_in_physics_frame(), "terminal retry receives exactly operation " + str(count))

func retry_failure_valid() -> bool:
	if not check(flow.phase == flow.Phase.ERROR and not flow.last_result.get("ok",true)
		and flow.last_result.get("code") == "CFG_STAGE_PARENT" and flow.last_result.get("terminal_pending",false)
		and flow.last_result.get("battle_held",false) and flow._source == battle and flow._campaign_terminal != null,
		"actual terminal failure is CFG_STAGE_PARENT on retained natural END"): return false
	var coordinator: RefCounted = flow._campaign_terminal
	if not check(coordinator.get_script() == ProgressCoordinator and coordinator._stage == "progress"
		and coordinator._live and coordinator._battle.get_ref() == battle and coordinator._life == battle._continue_receipt
		and coordinator._cfg != null and coordinator._cfg.get_script() == ConfigTransaction,
		"actual live coordinator owns the original lifecycle and CFG writer"): return false
	var writer: RefCounted = coordinator._cfg
	return check(writer.busy() and writer._frozen_cfg != null and writer._active.get("stage") == "staging"
		and writer._pending_record.is_empty() and writer._locked and writer._lock_created
		and battle.phase == B.Phase.END and get_tree().paused and not battle.hud._end_root.visible
		and not battle.mission._metrics_closed and battle.mission._result_frozen
		and battle._save_barrier.state == battle._save_barrier.State.IDLE and not battle._run_clock.in_step()
		and flow.find_child("RetryTerminal",true,false) != null and Campaign._cfg_writer == null,
		"terminal holds END and presentation without borrowing save-capture HELD or Campaign preference writer")

func retry_pending_observation() -> Dictionary:
	var writer: RefCounted = retained_writer
	var coordinator: RefCounted = retained_coordinator
	var head: Dictionary = writer._chain()
	var semantics: Dictionary = ConfigValues.semantics(writer._frozen_cfg)
	var life: Dictionary = life_capture(coordinator._life)
	var owner_path: String = writer.directory.path_join("writing/owner.json")
	var slot: Dictionary = Store.new(SLOT).read_slot()
	check(head.get("ok",false) and semantics.get("ok",false) and slot.get("ok",false), "read-only pending journal semantics and original slot remain valid")
	return {"coordinator_instance_id":str(coordinator.get_instance_id()),"writer_instance_id":str(writer.get_instance_id()),
		"frozen_cfg_instance_id":str(writer._frozen_cfg.get_instance_id()),"lifecycle_instance_id":str(coordinator._life.get_instance_id()),
		"coordinator_stage":coordinator._stage,"live":coordinator._live,"presentation_consumed":coordinator._presentation_consumed,
		"transaction":writer._active.transaction,"stage":writer._active.stage,"directory":writer.directory,
		"owner_path":owner_path,"owner_raw":writer._lock_raw,"owner_file":retry_file(owner_path),
		"locked":writer._locked,"lock_created":writer._lock_created,"head_ok":head.get("ok",false),
		"head_revision":head.get("revision",-1),"head_sha256":head.get("file_sha256","") ,
		"original_sha256":writer._active.original_sha256,"exact_active":active_observation(writer._active),
		"exact_intent":retry_exact(coordinator._intent),"intent_sha256":JSON.stringify(coordinator._intent).sha256_text(),
		"exact_gate_scope":retry_exact(coordinator._gate_scope),"exact_expected":retry_exact(coordinator._expected),
		"exact_frozen_semantics":retry_exact(semantics),"frozen_text_sha256":writer._frozen_cfg.encode_to_text().sha256_text(),
		"frozen_semantics_sha256":JSON.stringify(semantics.get("sections",{})).sha256_text(),
		"pending_record_empty":writer._pending_record.is_empty(),"inventory":writer.inventory(),
		"cfg":retry_file(ConfigTransaction.CFG_PATH),"blocker":retry_file(CANDIDATE_PARENT),
		"lifecycle":life,"exact_lifecycle":retry_exact(life),"slot_sha256":slot.get("file_sha256",""),
		"slot_revision":slot.get("revision",-1),"exact_slot_binding":retry_exact(slot.get("document",{}).get("binding",{})),
		"tree_paused":get_tree().paused,"flow_phase":int(flow.phase),"battle_phase":int(battle.phase),
		"barrier_state":int(battle._save_barrier.state),"clock_next":str(battle._run_clock._next_tick),
		"exact_state":retry_exact(state_row()),"exact_result":retry_exact(battle.mission._result_cache),
		"metrics_closed":battle.mission._metrics_closed,"exact_metrics":retry_exact(battle.mission.stage_metrics),
		"exact_report":retry_exact(battle.mission.report),"end_hud_visible":battle.hud._end_root.visible,
		"campaign_memory":{"records":Campaign.records.duplicate(true),"unlocked":Campaign.unlocked,"owner":Campaign.cloud_owner},
		"exact_rewards":retry_exact(rewards_snapshot())}

func retry_retain() -> void:
	retained_coordinator = flow._campaign_terminal
	retained_writer = retained_coordinator._cfg
	retained_frozen = retained_writer._frozen_cfg
	retained_active = retained_writer._active
	retained_intent = retained_coordinator._intent
	retained_gate_scope = retained_coordinator._gate_scope
	retained_pending = retry_pending_observation()

func retry_same(include_blocker := true) -> bool:
	if not check(flow._campaign_terminal == retained_coordinator and retained_coordinator._cfg == retained_writer
		and retained_writer._frozen_cfg == retained_frozen and is_same(retained_writer._active,retained_active)
		and is_same(retained_coordinator._intent,retained_intent) and is_same(retained_coordinator._gate_scope,retained_gate_scope)
		and retained_coordinator._life == battle._continue_receipt,
		"RetryTerminal retains same coordinator writer frozen ConfigFile Dictionary aliases and lifecycle"): return false
	var current: Dictionary = retry_pending_observation()
	var expected: Dictionary = retained_pending.duplicate(true)
	if not include_blocker: current.erase("blocker"); expected.erase("blocker")
	return check(current == expected, "terminal retry preserves exact pending world clock bytes owner CAS and proposal")

func retry_verify_pending_contract(before: Dictionary, metrics_before: Array) -> bool:
	var row: Dictionary = retained_pending
	var life: Dictionary = row.lifecycle
	var intent: Dictionary = retained_coordinator._intent
	check(life.generation == 2 and life.document.generation == 2 and life.document.state == "terminal"
		and life.document.progress_state == "pending" and life.document.victory and life.document.progress_receipt.is_empty()
		and life.document.intent == intent and life.token == checkpoint.binding.token
		and intent.schema == "campaign_progress_intent_v2" and intent.context == Profiles.GAO_CONTEXT
		and intent.credit == {"kind":"uncredited"} and intent.token == checkpoint.binding.token,
		"natural END durably freezes original LCgen2 Intentv2 before blocked CFG commit")
	check(row.head_ok and row.head_revision == 0 and row.head_sha256 == ConfigTransaction.ZERO
		and row.original_sha256 == ConfigTransaction.ZERO and row.cfg == before.cfg and not row.cfg.exists
		and row.inventory.get("ok",false) and row.inventory.get("items",{}).size() == 2
		and row.inventory.items.has_all(["writing/","writing/owner.json"])
		and row.owner_file.sha256 == row.owner_raw.sha256_text()
		and retained_writer._active.request == {"operation":"progress","run_token":life.token,
			"intent_sha256":row.intent_sha256,"target_owner":"","content_version":trusted.content_version,"engine_sha256":trusted.engine_binary_sha256}
		and row.frozen_semantics_sha256 == retained_writer._active.semantics_sha256,
		"real CFG staging failure has original zero CAS owned lock frozen semantics and no prepared record")
	check(Intent.cfg_dominates(retained_frozen,intent) and row.exact_rewards == retry_exact(opening.baseline.rewards)
		and row.campaign_memory == before.campaign_memory and battle.mission.stage_metrics == metrics_before
		and row.slot_revision == 2 and row.slot_sha256 == checkpoint.file_sha256
		and row.exact_slot_binding == retry_exact(checkpoint.binding),
		"frozen CFG is natural projected result while actual CFG memory metrics rewards and slot remain uncommitted")
	for key: String in Intent.RESULT_FIELDS:
		check(intent.result[key] == battle.mission._result_cache[key], "durable terminal Intent retains naturally frozen result " + key)
	return failures.is_empty()

func retry_final_journal() -> Dictionary:
	var head: Dictionary = retained_writer.open_head()
	var prepared: Dictionary = retained_writer._verified("record_0000000001.json")
	var applied: Dictionary = retained_writer._verified("record_0000000002.json")
	if not check(head.get("ok",false) and prepared.get("ok",false) and applied.get("ok",false)
		and head.revision == 2 and prepared.revision == 1 and applied.revision == 2
		and prepared.previous == ConfigTransaction.ZERO and applied.previous == prepared.file_sha256
		and head.file_sha256 == applied.file_sha256 and prepared.document.state == "prepared" and applied.document.state == "applied",
		"one real terminal CFG transaction closes prepared1 and applied2"): return {}
	for key: String in ConfigTransaction.RECORD_FIELDS:
		if key not in ["generation","state"]: check(prepared.document[key] == applied.document[key], "same terminal CFG journal field " + key)
	var record: Dictionary = applied.document
	check(record.transaction == retained_pending.transaction and record.operation == "progress"
		and record.run_token == checkpoint.binding.token and record.intent_sha256 == retained_pending.intent_sha256
		and record.original_sha256 == ConfigTransaction.ZERO and record.semantics_sha256 == retained_pending.frozen_semantics_sha256
		and record.candidate_sha256 == FileAccess.get_sha256(ConfigTransaction.CFG_PATH)
		and record.target_owner.is_empty() and record.content_version == trusted.content_version
		and record.engine_sha256 == trusted.engine_binary_sha256,
		"installed CFG binds original retained transaction scope semantics and natural intent")
	var inventory: Dictionary = retained_writer.inventory()
	check(inventory.get("ok",false) and inventory.get("items",{}).size() == 2
		and inventory.items.has_all(["record_0000000001.json","record_0000000002.json"]), "terminal CFG has exactly two records and no active lock or pending file")
	return {"head":head,"prepared":prepared,"applied":applied,"inventory":inventory,"exact":retry_exact({"head":head,"prepared":prepared,"applied":applied,"inventory":inventory})}

func finish_restored_core() -> void:
	var level: Variant = battle.level
	if not check(checkpoint.generation == 2 and core_ready() and level.waves.all(func(row): return row.sent)
		and level.flagship.story_outcome == "subdued" and str(level.flagship.entity_id) == opening.flagship_entity_id,
		"third process restores original completed core, all dispatched waves and subdued flagship"): return
	var button: Variant = level.end_button
	var entries: Array = battle.mission._buttons.get_children().filter(func(node): return node is Button and node.get_meta(battle.mission.PRESENTATION_META, {}).get("kind", "") == "level" and node.get_meta(battle.mission.PRESENTATION_META, {}).get("button_id", "") == "gao_end")
	var connections: Array = button.pressed.get_connections()
	var original_callbacks: Array = connections.filter(func(row): return row.callable.get_object() == battle.mission and row.callable.get_method() == "_activate_level_button" and row.callable.get_bound_arguments() == ["gao_end"])
	if not check(entries == [button] and button.get_parent() == battle.mission._buttons and original_callbacks.size() == 1
		and not button.disabled, "exact one rebuilt Mission-owned gao_end retains original installed dispatch binding"): return
	observations["restored_end_button"] = {"same_level_mission_node":entries == [button], "original_callback_count":original_callbacks.size(),
		"presentation":button.get_meta(battle.mission.PRESENTATION_META).duplicate(true), "instance_id":str(button.get_instance_id()), "process_id":OS.get_process_id()}
	var receipt: Variant = battle._continue_receipt
	var metrics_before: Array = battle.mission.stage_metrics.duplicate(true)
	var stage_parent: String = ProjectSettings.globalize_path(CANDIDATE_PARENT).replace("\\","/")
	var cfg_path: String = ProjectSettings.globalize_path(ConfigTransaction.CFG_PATH).replace("\\","/")
	var journal_directory: String = ConfigTransaction.new().directory
	var before: Dictionary = {"cfg":retry_file(cfg_path),"lifecycle":life_capture(receipt),"slot_sha256":checkpoint.file_sha256,
		"campaign_memory":{"records":Campaign.records.duplicate(true),"unlocked":Campaign.unlocked,"owner":Campaign.cloud_owner},
		"paused":get_tree().paused,"clock_next":str(battle._run_clock._next_tick),"barrier_state":int(battle._save_barrier.state),
		"exact_state":retry_exact(state_row()),"exact_metrics":retry_exact(metrics_before),"rewards":rewards_snapshot()}
	retry_observation = {"schema":"ui_terminal_retry_observation_v1","before":before,"operations":terminal_operations,"gates":terminal_gates,
		"desktop_os_input":false,"initial_private_gate_used":true,"public_continue_qualified":false,"native_sdk_qualified":false,
		"full_campaign_qualified":false,"full_61_qualified":false,"published":false}
	observations["terminal_retry"] = retry_observation
	if not check(get_tree().paused and battle.hud._pause_root.visible and battle._save_barrier.state == battle._save_barrier.State.IDLE
		and before.lifecycle.generation == 1 and not battle.mission._result_frozen and not battle.mission._metrics_closed
		and flow._campaign_terminal == null and not before.cfg.exists and not FileAccess.file_exists(stage_parent)
		and not DirAccess.dir_exists_absolute(stage_parent) and not DirAccess.dir_exists_absolute(journal_directory),
		"third-process gate begins on real paused active lifecycle before natural result or CFG work"): return
	flow.operation_finished.connect(retry_on_operation)
	if not await retry_gate("arm_terminal_stage_parent",{"stage_parent":stage_parent,"cfg_path":cfg_path,"journal_directory":journal_directory,
		"lifecycle_directory":receipt.directory,"token":receipt.token,"slot_sha256":checkpoint.file_sha256}): return
	if not check(FileAccess.file_exists(stage_parent) and not DirAccess.dir_exists_absolute(stage_parent)
		and retry_file(cfg_path) == before.cfg and life_capture(receipt) == before.lifecycle and retry_exact(state_row()) == before.exact_state
		and get_tree().paused and not battle.mission._result_frozen and flow._campaign_terminal == null,
		"host only installs regular parent blocker while actual restored world stays paused"): return
	if not press_button(battle.hud._pause_resume_button, "resume restored core-ready battle"): return
	await get_tree().process_frame
	if not battle.mission._expanded:
		if not await click_mission_toggle_via_viewport(battle.mission._toggle): return
		await get_tree().process_frame
	if not await reveal_button(button) or not press_button(button, "actual restored gao_end core victory"): return
	if not await retry_wait_operation(1) or not retry_failure_valid(): return
	retry_retain()
	retry_observation["first_failure"] = retained_pending.duplicate(true)
	if not retry_verify_pending_contract(before,metrics_before) or not retry_same(): return
	for frame: int in range(3): await get_tree().process_frame
	if not retry_same(): return
	if not press_button(flow.find_child("RetryTerminal",true,false), "actual RetryTerminal under same parent fault"): return
	if not await retry_wait_operation(2) or not retry_failure_valid() or not retry_same(): return
	retry_observation["blocked_retry"] = retry_pending_observation()
	if not check(retry_observation.first_failure == retry_observation.blocked_retry,
		"blocked RetryTerminal returns a fresh failure signal with identical retained transaction"): return
	if not retry_publish("blocked_pending.json",{"schema":"ui_terminal_retry_blocked_v1","mode":mode,"pid":OS.get_process_id(),
		"batch_nonce":OS.get_environment("GVT_NONCE"),"process_nonce":OS.get_environment("GVT_PROCESS_NONCE"),
		"profile":OS.get_environment("GVT_PROFILE"),"identity":identity_row(),"candidate_manifest_sha256":OS.get_environment("GVT_CANDIDATE_SHA256"),
		"sources_sha256":OS.get_environment("GVT_SOURCES_SHA256"),"observation":retry_observation}): return
	if not await retry_gate("release_terminal_stage_parent",{"stage_parent":stage_parent,"cfg_path":cfg_path,"journal_directory":journal_directory,
		"lifecycle_directory":receipt.directory,"token":receipt.token,"transaction":retained_pending.transaction,"expected_code":"CFG_STAGE_PARENT"}): return
	if not check(not FileAccess.file_exists(stage_parent) and not DirAccess.dir_exists_absolute(stage_parent), "host releases only its original parent blocker"): return
	if not retry_same(false): return
	if not press_button(flow.find_child("RetryTerminal",true,false), "actual RetryTerminal after own blocker removed"): return
	if not await retry_wait_operation(3) or not await await_terminal(): return
	if not check(battle.mission._result_frozen, "original end flow froze complete actual victory result"): return
	if not check(flow._campaign_terminal == null and retained_coordinator._stage == "done" and retained_coordinator._presentation_consumed
		and retained_coordinator._cfg == retained_writer and retained_writer._active.is_empty() and retained_writer._frozen_cfg == null
		and not retained_writer.busy() and retained_coordinator._life == receipt and flow._overlay == null
		and terminal_operations.size() == 3 and terminal_operations[2].result.get("terminal_completed",false),
		"successful original RetryTerminal consumes live presentation once and releases same CFG writer"): return
	var journal: Dictionary = retry_final_journal()
	if journal.is_empty() or not failures.is_empty(): return
	retry_observation["success"] = {"journal":journal,"cfg":retry_file(cfg_path),"operation":flow.last_result.duplicate(true),
		"coordinator_instance_id":str(retained_coordinator.get_instance_id()),"writer_instance_id":str(retained_writer.get_instance_id()),
		"transaction":retained_pending.transaction,"intent_sha256":retained_pending.intent_sha256}
	stage_completed = await verify_terminal(receipt, battle.mission.result_snapshot(true), metrics_before)
	check(retry_exact(retained_writer.inventory()) == retry_exact(journal.inventory) and retained_writer.open_head().get("file_sha256") == journal.head.file_sha256
		and terminal_operations.size() == 3, "completed terminal does not write a second CFG transaction or repeat completion")
	stage_completed = stage_completed and failures.is_empty()
	if flow.operation_finished.is_connected(retry_on_operation): flow.operation_finished.disconnect(retry_on_operation)
