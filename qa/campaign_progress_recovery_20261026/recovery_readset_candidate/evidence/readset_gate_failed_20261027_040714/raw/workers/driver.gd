extends Node
## Synthetic storage fixtures and a byte-identical historical Slot clone.
## No world mount, Flow request, fake liveness, clock change or method override.
const Slot = preload("res://scripts/run_slot_store.gd")
const CFG = preload("res://scripts/run_campaign_cfg_transaction.gd")
const Identity = preload("res://scripts/run_content_identity.gd")
const Manager = preload("res://scripts/run_process_liveness_manager.gd")
const CASES: Array[String] = ["aba", "file_content", "pending_changed", "file_rename",
	"directory_set", "owner_replace", "scope_expiry", "forged_plan", "record",
	"pending", "derived_fallback", "cfg_fallback"]
const ZERO := "0000000000000000000000000000000000000000000000000000000000000000"
var checks: Array = []
var results: Array = []
var providers: Dictionary = {}
var retained: Array[RefCounted] = []
var trusted: Dictionary = {}
var prepared: Dictionary = {}
var fixtures: Script
var output := ""
var mode := ""
var healthy := true
var helpers_terminal := true
var root_path := "user://readset_test/v1"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func check(value: bool, label: String, detail: Variant = null) -> bool:
	checks.append({"passed":value,"label":label,"detail":detail})
	healthy = healthy and value
	return value

func scope_fields() -> Dictionary:
	return {"pid":OS.get_process_id(),"nonce":OS.get_environment("RS_NONCE"),
		"process_nonce":OS.get_environment("RS_PROCESS_NONCE"),"profile":OS.get_environment("RS_PROFILE"),
		"content_version":trusted.get("content_version",""),
		"engine_sha256":trusted.get("engine_binary_sha256","")}

func read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func write_new(path: String, raw: String) -> bool:
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".tmp"):
		return check(false,"exclusive worker output exists",path)
	var file: FileAccess = FileAccess.open(path + ".tmp",FileAccess.WRITE)
	if file == null: return check(false,"worker output open",path)
	file.store_string(raw)
	file.flush()
	var code: Error = file.get_error()
	file.close()
	if code != OK or FileAccess.file_exists(path):
		return check(false,"worker output flush",path)
	return check(DirAccess.rename_absolute(path + ".tmp",path) == OK,"worker output publish",path)

func write_json(name: String, value: Dictionary) -> bool:
	return write_new(output.path_join(name),JSON.stringify(value))

func nonphysics() -> bool:
	for attempt: int in range(4):
		if not Engine.is_in_physics_frame(): return true
		await get_tree().process_frame
	return check(false,"ordinary process frame required")

func gate(index: int, kind: String, case_name: String, directory: String) -> bool:
	var request: Dictionary = scope_fields()
	request.merge({"schema":"readset_gate_v1","kind":kind,"index":index,
		"case":case_name,"directory":directory})
	var request_name: String = "gate_request.json" if kind == "producer_pending" else "request_%02d.json" % index
	var ack_name: String = "gate_ack.json" if kind == "producer_pending" else "ack_%02d.json" % index
	if not write_json(request_name,request): return false
	var until: int = Time.get_ticks_msec() + 60000
	var path: String = output.path_join(ack_name)
	while not FileAccess.file_exists(path) and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	var ack: Dictionary = read_json(path)
	if not check(ack == {"pid":OS.get_process_id(),"nonce":OS.get_environment("RS_NONCE"),
		"process_nonce":OS.get_environment("RS_PROCESS_NONCE"),"index":index},"exact host gate",case_name): return false
	return await nonphysics()

func tree_inventory(path: String, prefix: String = "", files: Dictionary = {}, dirs: Array = []) -> Dictionary:
	var folder: DirAccess = DirAccess.open(path)
	if folder == null: return {"ok":false,"code":"INVENTORY_DIRECTORY"}
	dirs.append("." if prefix.is_empty() else prefix)
	for name: String in folder.get_files():
		if folder.is_link(name): return {"ok":false,"code":"INVENTORY_LINK"}
		var absolute: String = path.path_join(name)
		var file: FileAccess = FileAccess.open(absolute,FileAccess.READ)
		if file == null: return {"ok":false,"code":"INVENTORY_OPEN"}
		var count: int = file.get_length()
		file.close()
		var digest: String = FileAccess.get_sha256(absolute)
		if digest.length() != 64: return {"ok":false,"code":"INVENTORY_HASH"}
		files[name if prefix.is_empty() else prefix.path_join(name)] = {"sha256":digest,"bytes":count}
	for name: String in folder.get_directories():
		if folder.is_link(name): return {"ok":false,"code":"INVENTORY_LINK"}
		var sub: Dictionary = tree_inventory(path.path_join(name),
			name if prefix.is_empty() else prefix.path_join(name),files,dirs)
		if not sub.ok: return sub
	dirs.sort()
	return {"ok":true,"exists":true,"files":files,"directories":dirs}

func comparable_inventory(path: String) -> Dictionary:
	var value: Dictionary = tree_inventory(path,"",{},[])
	value.erase("ok")
	return value

func normalized_inventory(value: Dictionary) -> Dictionary:
	if not check(value.size() == 3 and value.has_all(["exists","files","directories"]) \
		and value.exists == true and typeof(value.files) == TYPE_DICTIONARY \
		and typeof(value.directories) == TYPE_ARRAY,"inventory JSON fixed schema"): return {}
	var normalized: Dictionary = value.duplicate(true)
	for key: Variant in normalized.files:
		var row: Variant = normalized.files[key]
		if not check(typeof(key) == TYPE_STRING and typeof(row) == TYPE_DICTIONARY \
			and row.size() == 2 and row.has_all(["sha256","bytes"]) \
			and typeof(row.sha256) == TYPE_STRING and row.sha256.length() == 64 \
			and typeof(row.bytes) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(row.bytes)) \
			and row.bytes >= 0 and row.bytes <= 134217728 and floor(float(row.bytes)) == row.bytes,
			"inventory JSON exact file metadata"): return {}
		row.bytes = int(row.bytes)
	for directory: Variant in normalized.directories:
		if not check(typeof(directory) == TYPE_STRING,"inventory JSON directory string"): return {}
	return normalized

func cleared(store: RefCounted, label: String) -> bool:
	return check(store._liveness_scope_depth == 0 and store._liveness_scope_id == 0 \
		and store._readset_certificate.is_empty() and store._readset_reads.is_empty() \
		and store._readset_inventory.is_empty() and not store._readset_collecting,
		"outer scope clears proof and collector: " + label)

func small_result(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	result.erase("document")
	return result

func store_for(case_name: String, derived: bool = false) -> RefCounted:
	var path: String = root_path.path_join(case_name)
	if derived:
		var derived_script: Variant = fixtures.get_script_constant_map()["DerivedSlot"]
		return derived_script.new(path)
	return Slot.new(path)

func proposal(document: Dictionary) -> Dictionary:
	return {"record":document,"sha256":JSON.stringify(document).sha256_text()}

func prepare_fixture() -> void:
	var seed_path: String = OS.get_environment("RS_SEED_PATH")
	if not check(FileAccess.get_sha256(seed_path) == OS.get_environment("RS_SEED_SHA"),"original seed SHA"): return
	var seed: String = FileAccess.get_file_as_string(seed_path)
	var variants: Dictionary = fixtures.slot_variants(Slot.new(),seed)
	if not check(variants.get("ok",false),"exact Slot validates synthetic reduced documents",small_result(variants)): return
	var variant_paths: Dictionary = {}
	for key: String in ["a","b","h"]:
		var path: String = output.path_join("fixture_" + key + ".json")
		if not write_new(path,String(variants[key].raw)): return
		variant_paths[key] = {"path":path,"sha256":variants[key].sha256}
	var cases: Dictionary = {}
	for case_name: String in CASES:
		if case_name == "cfg_fallback": continue
		var store: RefCounted = store_for(case_name)
		if not check(store.initialize_directory().ok,"initialize synthetic case",case_name): return
		var first: Dictionary = store.acquire()
		if not check(first.ok and first.revision == 0,"real empty acquisition",case_name): return
		var saved_b: Dictionary = store.commit_locked(0,ZERO,proposal(variants.b.document))
		if not check(saved_b.ok and saved_b.file_sha256 == variants.b.sha256,"real first closed commit",case_name): return
		if not check(store.release().ok,"first owner release",case_name): return
		var second: Dictionary = store.acquire()
		if not check(second.ok and second.file_sha256 == variants.b.sha256,"second exact CAS",case_name): return
		var saved_h: Dictionary = store.commit_locked(1,String(variants.b.sha256),proposal(variants.h.document))
		if not check(saved_h.ok and saved_h.file_sha256 == variants.h.sha256,"real second closed commit",case_name): return
		if not check(store.release().ok,"second owner release",case_name): return
		var held: Dictionary = store.acquire()
		if not check(held.ok and held.file_sha256 == variants.h.sha256,"actual producer retains original owner",case_name): return
		retained.append(store)
		cases[case_name] = {"directory":store.directory,"b_sha256":variants.b.sha256,
			"h_sha256":variants.h.sha256,"owner_pid":OS.get_process_id()}
	var cfg: RefCounted = CFG.new()
	var cfg_bad: Dictionary = fixtures.cfg_bad_genesis(cfg,String(trusted.content_version),
		String(trusted.engine_binary_sha256),OS.get_environment("RS_NONCE").substr(0,32))
	if not check(cfg_bad.ok,"individually valid CFG data fixture",small_result(cfg_bad)): return
	var cfg_path: String = output.path_join("fixture_cfg_bad.json")
	if not write_new(cfg_path,String(cfg_bad.raw)): return
	# Do not place an invalid CFG journal in the next process's startup path.
	# The reader creates this negative fixture only after normal startup.
	cases.cfg_fallback = {"directory":cfg.directory,"record_sha256":cfg_bad.sha256,
		"raw_path":cfg_path,"created_after_reader_startup":true}
	var pending_store: RefCounted = retained[CASES.find("pending")]
	var pending_document: Dictionary = variants.h.document.duplicate(true)
	pending_document.generation = 3
	var pending_envelope: Dictionary = fixtures._checked_envelope(pending_store,pending_document,String(variants.h.sha256))
	if not check(pending_envelope.ok,"pending generation3 data validates"): return
	var pending_path: String = output.path_join("fixture_pending.json")
	if not write_new(pending_path,String(pending_envelope.raw)): return
	prepared = scope_fields()
	prepared.merge({"schema":"readset_prepared_v1","passed":healthy,"checks":checks.duplicate(true),
		"cases":cases,"variants":variant_paths,"pending_target":{"raw_path":pending_path,"sha256":pending_envelope.sha256},
		"synthetic":true,"world_mount_qualified":false,"flow_qualified":false,"source_seed_sha256":variants.source_sha256})
	if not write_json("prepared.json",prepared): return
	if not await gate(0,"producer_pending","pending",String(pending_store.directory)): return
	# The host stops the original process at the original pending_verified line.
	var unexpected: Dictionary = pending_store.commit_locked(2,String(variants.h.sha256),proposal(pending_document))
	check(false,"producer must stop at real closed pending before this return",small_result(unexpected))

func collect_providers() -> void:
	var directory: String = ProjectSettings.globalize_path("user://process_liveness/v2")
	var folder: DirAccess = DirAccess.open(directory)
	if folder == null: return
	for name: String in folder.get_directories():
		if folder.is_link(name):
			helpers_terminal = false
			check(false,"provider directory link")
			continue
		var path: String = directory.path_join(name).path_join("result.json")
		if providers.has(path): continue
		var file: FileAccess = FileAccess.open(path,FileAccess.READ)
		if file == null:
			helpers_terminal = false
			check(false,"provider result exists")
			continue
		var count: int = file.get_length()
		if count < 1 or count > Manager.Oracle.MAX_REPORT:
			helpers_terminal = false
			file.close()
			check(false,"bounded native provider report")
			continue
		var raw: String = file.get_buffer(count).get_string_from_ascii()
		file.close()
		var value: Variant = JSON.parse_string(raw)
		if not check(typeof(value) == TYPE_DICTIONARY and value.get("schema") == "windows_process_liveness_v1" \
			and value.get("nonce") == name and typeof(value.get("provider_pid")) == TYPE_STRING \
			and value.provider_pid.is_valid_int(),"native provider identity"):
			helpers_terminal = false
			continue
		var pid: int = int(value.provider_pid)
		var exit_code: int = OS.get_process_exit_code(pid)
		var running: bool = OS.is_process_running(pid)
		helpers_terminal = helpers_terminal and pid > 0 and exit_code == 0 and not running
		check(pid > 0 and exit_code == 0 and not running,"actual own helper terminal",{"pid":pid,"exit":exit_code,"running":running})
		providers[path] = {"provider_pid":pid,"raw_report_path":path,"raw_report":raw,
			"raw_report_sha256":raw.sha256_text(),"evidence":value,"own_child_exit_code":exit_code,"own_child_running":running}
	if get_tree().root.has_meta(Manager.META_KEY):
		var manager: RefCounted = get_tree().root.get_meta(Manager.META_KEY)
		helpers_terminal = helpers_terminal and manager._quarantine.is_empty()
		check(manager._quarantine.is_empty(),"no unconfirmed helper quarantine")
		if manager._oracle != null:
			var oracle: RefCounted = manager._oracle
			helpers_terminal = helpers_terminal and not oracle._pending and oracle._cleanup_confirmed
			check(not oracle._pending and oracle._cleanup_confirmed,"last actual oracle child cleanup confirmed")

func forged_plans(store: RefCounted) -> Dictionary:
	var before: Dictionary = comparable_inventory(String(store.directory))
	var plan: Dictionary = store.inspect_recovery()
	if not check(plan.get("ok",false),"original plan for forged-plan refusals",small_result(plan)): return plan
	cleared(store,"initial public inspect")
	var variants: Array = [{},plan.duplicate(true),plan.duplicate(true),plan.duplicate(true),plan.duplicate(true)]
	variants[1].action = "forward_pending"
	variants[2].head_sha256 = "f".repeat(64)
	variants[3].dead_pid = OS.get_process_id()
	variants[4].inventory["record_0000000001.json"] = "e".repeat(64)
	for index: int in range(variants.size()):
		var rejected: Dictionary = store.recover(variants[index])
		if not check(not rejected.get("ok",false) and rejected.get("code") == "RECOVERY_PLAN_CHANGED",
			"forged plan rejected by fresh original inspection",{"index":index,"result":small_result(rejected)}): return rejected
		check(comparable_inventory(String(store.directory)) == before,"forged-plan refusal changes no file",index)
		cleared(store,"forged recover")
		collect_providers()
	# Observe a genuinely created proof in its original live scope, then pass a
	# changed data plan to the original readback. Never assign private state.
	var entered: Dictionary = store._enter_recovery_scope()
	if not check(entered.ok,"real outer scope for proof mismatch diagnostic"): return entered
	var scoped_plan: Dictionary = store.inspect_recovery()
	var proof_present: bool = not store._readset_certificate.is_empty()
	check(scoped_plan.get("ok",false) and proof_present,"exact Slot genuinely seals proof in live scope")
	if healthy:
		var altered: Dictionary = scoped_plan.duplicate(true)
		altered.head_sha256 = "a".repeat(64)
		var mismatch: Dictionary = store._base_recovery_readback(altered)
		check(not mismatch.get("ok",false) and mismatch.get("code") == "RECOVERY_READSET_SCOPE" \
			and store._readset_certificate.is_empty(),"changed plan cannot use actual live proof",small_result(mismatch))
		check(comparable_inventory(String(store.directory)) == before,"proof-scope refusal leaves business bytes unchanged")
	store._leave_recovery_scope()
	cleared(store,"proof mismatch outer close")
	collect_providers()
	if not healthy: return {"ok":false,"code":"QA_PROOF_MISMATCH_FAILED"}
	# Actual metadata negatives, closed fixture writes only, never fake dead results.
	var owner_path: String = String(store.directory).path_join("writing/owner.json")
	var original_raw: String = FileAccess.get_file_as_string(owner_path)
	var owner: Dictionary = read_json(owner_path)
	for invalid: String in ["0","-1","01","not-a-pid","2147483648",str(OS.get_process_id())]:
		var changed: Dictionary = owner.duplicate(true)
		changed.pid = invalid
		var file: FileAccess = FileAccess.open(owner_path,FileAccess.WRITE)
		if not check(file != null,"explicit invalid-PID fixture write"): return {"ok":false}
		file.store_string(JSON.stringify(changed)); file.flush(); file.close()
		var changed_inventory: Dictionary = comparable_inventory(String(store.directory))
		var rejection: Dictionary = store.inspect_recovery()
		var wanted: String = "PROCESS_LIVENESS_QUERY_SCOPE" if invalid == "2147483648" else "LOCK_METADATA"
		if invalid == str(OS.get_process_id()): wanted = "WRITER_ALIVE"
		check(not rejection.get("ok",false) and rejection.get("code") == wanted,
			"invalid PID never authorizes recovery",{"pid":invalid,"result":small_result(rejection)})
		if wanted == "WRITER_ALIVE":
			var observation: Dictionary = rejection.get("liveness_detail",{})
			check(observation.get("state") == "alive" and int(observation.get("target_pid",0)) == OS.get_process_id() \
				and observation.get("evidence",{}).get("code") == "HANDLE_NONSIGNALED",
				"real helper confirms current reader owner alive",observation)
		check(comparable_inventory(String(store.directory)) == changed_inventory,
			"owner refusal preserves every byte after explicit fixture replacement",invalid)
		check(not DirAccess.dir_exists_absolute(String(store.directory).path_join("recovering")),"invalid PID creates no claim")
		cleared(store,"invalid PID")
		collect_providers()
		file = FileAccess.open(owner_path,FileAccess.WRITE)
		if not check(file != null,"restore own synthetic metadata fixture"): return {"ok":false}
		file.store_string(original_raw); file.flush(); file.close()
	check(comparable_inventory(String(store.directory)) == before,"all synthetic owner metadata restored byte-identically")
	# A legitimate copied data plan remains valid because recover re-inspects it.
	var recovered: Dictionary = store.recover(plan.duplicate(true))
	check(recovered.get("ok",false),"valid copied plan after failures still recovers",small_result(recovered))
	return recovered

func attack_reader() -> void:
	var prepared_path: String = OS.get_environment("RS_PREPARED_PATH")
	if not check(FileAccess.get_sha256(prepared_path) == OS.get_environment("RS_PREPARED_SHA"),"prepared predecessor SHA"): return
	prepared = read_json(prepared_path)
	if not check(prepared.get("schema") == "readset_prepared_v1" and prepared.get("passed",false) \
		and prepared.get("nonce") == OS.get_environment("RS_NONCE") and prepared.get("profile") == OS.get_environment("RS_PROFILE") \
		and prepared.get("content_version") == trusted.content_version and prepared.get("engine_sha256") == trusted.engine_binary_sha256 \
		and int(prepared.get("pid",0)) != OS.get_process_id(),"actual different producer binding"): return
	for index: int in range(CASES.size()):
		var case_name: String = CASES[index]
		var store: RefCounted = CFG.new() if case_name == "cfg_fallback" else store_for(case_name,case_name == "derived_fallback")
		if not check(store.directory == prepared.cases[case_name].directory,"exact private case directory",case_name): return
		if case_name == "cfg_fallback":
			var cfg_row: Dictionary = prepared.cases.cfg_fallback
			if not check(FileAccess.get_sha256(String(cfg_row.raw_path)) == cfg_row.record_sha256,
				"prepared CFG negative raw binding"): return
			if not check(store.initialize_directory().ok and store.acquire().ok,
				"CFG fixture acquires this real reader owner after startup"): return
			if not check(store._write_new(String(store.directory).path_join("record_0000000001.json"),
				FileAccess.get_file_as_string(String(cfg_row.raw_path))).ok,"closed CFG negative fixture"): return
			retained.append(store)
		if not await gate(index,"attack_case",case_name,String(store.directory)): return
		var before: Dictionary = comparable_inventory(String(store.directory))
		var began: int = Time.get_ticks_usec()
		var result: Dictionary = {}
		if case_name == "forged_plan":
			result = forged_plans(store)
		elif case_name == "derived_fallback":
			var entered: Dictionary = store._enter_recovery_scope()
			if check(entered.ok,"real outer scope for derived fallback"):
				result = store.inspect_recovery()
				check(store.get_script() != Slot and store._readset_certificate.is_empty() \
					and store._readset_script == null and not store._readset_collecting,
					"derived Slot does not receive an exact-Slot proof")
				store._leave_recovery_scope()
			else: result = entered
		else:
			result = store.inspect_recovery()
			if case_name in ["record","pending"]:
				if check(result.get("ok",false),"positive public inspect",{"case":case_name,"result":small_result(result)}):
					cleared(store,"positive inspect before actual recover")
					result = store.recover(result)
		var elapsed: int = Time.get_ticks_usec() - began
		var after: Dictionary = comparable_inventory(String(store.directory))
		var wanted: String = "RECOVERY_READSET_CHANGED" if case_name == "aba" else "RECOVERY_CAS_CHANGED"
		if case_name == "scope_expiry": wanted = "PROCESS_LIVENESS_TIMEOUT"
		if case_name == "cfg_fallback": wanted = "CFG_PREPARED_GENESIS_REQUIRED"
		if case_name in ["record","pending","forged_plan"]:
			var revision: int = 3 if case_name == "pending" else 2
			var digest: String = prepared.pending_target.sha256 if case_name == "pending" else prepared.cases[case_name].h_sha256
			check(result.get("ok",false) and int(result.get("revision",0)) == revision and result.get("file_sha256") == digest,
				"real recovery exact head",{"case":case_name,"result":small_result(result)})
			check(not DirAccess.dir_exists_absolute(String(store.directory).path_join("writing")) \
				and not DirAccess.dir_exists_absolute(String(store.directory).path_join("recovering")) \
				and not FileAccess.file_exists(String(store.directory).path_join("receipt.pending")),"successful recovery clears only transaction residue",case_name)
		elif case_name == "derived_fallback":
			check(result.get("ok",false) and before == after,"real derived Slot fallback inspect succeeds read-only",small_result(result))
		else:
			check(not result.get("ok",false) and result.get("code") == wanted,"specific refusal, not unrelated timeout",
				{"case":case_name,"wanted":wanted,"result":small_result(result)})
			if case_name in ["aba","scope_expiry","cfg_fallback"]:
				check(before == after,"refusal preserves exact pre-operation bytes",case_name)
			if case_name == "scope_expiry":
				check(elapsed >= 3000000 and Manager.BUDGET_MS == 3000,"real original scope elapsed without clock or budget override",elapsed)
		cleared(store,case_name)
		collect_providers()
		var row: Dictionary = scope_fields()
		row.merge({"schema":"readset_case_v1","index":index,"case":case_name,"result":small_result(result),
			"elapsed_us":elapsed,"before":before,"after":after,"passed":healthy,"checks":checks.duplicate(true),
			"synthetic":true,"world_mount_qualified":false,"flow_qualified":false})
		results.append(row)
		if not write_json("case_%02d.json" % index,row): return
		if not healthy: return

func clone_record() -> void:
	var path: String = OS.get_environment("RS_EXPECTED_INVENTORY")
	if not check(FileAccess.get_sha256(path) == OS.get_environment("RS_EXPECTED_INVENTORY_SHA"),"old clone inventory SHA"): return
	var expected: Dictionary = normalized_inventory(read_json(path))
	if expected.is_empty(): return
	var business: String = ProjectSettings.globalize_path("user://continue/v1").replace("\\","/")
	if not check(business == OS.get_environment("RS_CLONE_BUSINESS").replace("\\","/"),"exact isolated original clone"): return
	var before: Dictionary = comparable_inventory(business)
	if not check(before == expected,"old entire tree is byte-identical before Store recovery"): return
	var store: RefCounted = Slot.new()
	var began: int = Time.get_ticks_usec()
	var plan: Dictionary = store.inspect_recovery()
	var inspected_us: int = Time.get_ticks_usec() - began
	check(plan.get("ok",false),"old full Slot clone initial inspect succeeds",small_result(plan))
	cleared(store,"old clone initial inspect")
	collect_providers()
	var recovered: Dictionary = {}
	var recovery_us: int = 0
	if healthy:
		began = Time.get_ticks_usec()
		recovered = store.recover(plan)
		recovery_us = Time.get_ticks_usec() - began
		check(recovered.get("ok",false) and int(recovered.get("revision",0)) == 1 \
			and recovered.get("file_sha256") == expected.files["5088120/1/record_0000000001.json"].sha256,
			"actual original 4MB Store recovery retains original record hash",small_result(recovered))
		cleared(store,"old clone actual recovery")
	collect_providers()
	var after: Dictionary = comparable_inventory(business)
	var allowed: Dictionary = expected.duplicate(true)
	allowed.files.erase("5088120/1/writing/owner.json")
	allowed.directories.erase("5088120/1/writing")
	check(after == allowed,"only dead writing owner and directory removed; old record and LC bytes unchanged")
	results.append({"case":"original_record_clone","before":before,"after":after,
		"inspect_result":small_result(plan),"recover_result":small_result(recovered),
		"inspect_us":inspected_us,"recover_us":recovery_us,"store_recovery_only":true,
		"old_content_not_rewritten":true,"flow_qualified":false,"world_mount_qualified":false})

func run() -> void:
	output = OS.get_environment("RS_OUTPUT").replace("\\","/")
	mode = OS.get_environment("RS_MODE")
	if not await nonphysics(): finish(); return
	if not check(mode in ["producer","attack_reader","clone_record"] and output.is_absolute_path() \
		and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA").is_empty(),"private mode scope"): finish(); return
	var userdata: String = ProjectSettings.globalize_path("user://").replace("\\","/")
	if not check(userdata.begins_with(OS.get_environment("RS_PROFILE").replace("\\","/") + "/"),"fresh private userdata"): finish(); return
	fixtures = load(OS.get_environment("RS_WORKERS").replace("\\","/").path_join("fixtures.gd"))
	if not check(fixtures != null,"pinned fixture script loaded"): finish(); return
	var flow: Node = get_node("/root/ContinueFlow")
	var limit: int = Time.get_ticks_msec() + 30000
	while not flow.can_launch() and Time.get_ticks_msec() < limit:
		if flow.phase == flow.Phase.ERROR: break
		await get_tree().process_frame
	if not check(flow.can_launch() and flow.last_result.get("startup_checked",false),"real normal startup ready"): finish(); return
	if not await nonphysics(): finish(); return
	trusted = Identity.new().resolve_runtime_identity()
	if not check(trusted.get("ok",false) and trusted.get("source_mode",false) \
		and trusted.content_version == OS.get_environment("RS_CONTENT") \
		and trusted.engine_binary_sha256 == OS.get_environment("RS_ENGINE"),"actual new full source and engine identity"): finish(); return
	if mode == "producer": await prepare_fixture()
	elif mode == "attack_reader": await attack_reader()
	else: clone_record()
	finish()

func finish() -> void:
	if not output.is_absolute_path():
		get_tree().quit(2)
		return
	collect_providers()
	var report: Dictionary = scope_fields()
	report.merge({"schema":"readset_driver_v1","mode":mode,"passed":healthy,"checks":checks,
		"results":results,"providers":providers,"providers_terminal":helpers_terminal,
		"budget_ms":Manager.BUDGET_MS,"production_method_overrides":0,
		"original_profile_used_by_engine":false,"public_entry_qualified":false,
		"flow_qualified":false,"sdk_qualified":false,"original_release_qualified":false,
		"os_input":false,"human_acceptance":false,"production_qualified":false})
	write_json("report.json",report)
	get_tree().quit(0 if healthy else 1)
