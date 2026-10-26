extends Node
## Read-only production Store calls. No recover(), claim, method replacement,
## synthetic clock, timeout override, or world/receipt creation.
const Slot = preload("res://scripts/run_slot_store.gd")
const Manager = preload("res://scripts/run_process_liveness_manager.gd")
const Identity = preload("res://scripts/run_content_identity.gd")
var checks: Array = []
var timings: Array = []
var providers: Dictionary = {}
var expected: Dictionary = {}
var slot: RefCounted
var business := ""
var output := ""
var healthy := true
var inspection: Dictionary = {}
var preclaim: Dictionary = {}
var whole_preclaim: Dictionary = {}
var trusted: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks.append({"passed":value,"label":label})
	healthy = healthy and value
	return value

func walk(path: String, prefix: String, files: Dictionary, directories: Array) -> bool:
	var folder := DirAccess.open(path)
	if folder == null: return false
	directories.append("." if prefix.is_empty() else prefix)
	for name: String in folder.get_files():
		if folder.is_link(name): return false
		var absolute: String = path.path_join(name)
		var file := FileAccess.open(absolute, FileAccess.READ)
		if file == null: return false
		var size: int = file.get_length()
		file.close()
		var digest: String = FileAccess.get_sha256(absolute)
		if digest.length() != 64: return false
		files[name if prefix.is_empty() else prefix.path_join(name)] = {"sha256":digest,"bytes":size}
	for name: String in folder.get_directories():
		if folder.is_link(name) or not walk(path.path_join(name),name if prefix.is_empty() else prefix.path_join(name),files,directories): return false
	return true

func inventory() -> Dictionary:
	var files: Dictionary = {}
	var directories: Array = []
	if not walk(business,"",files,directories): return {"exists":false}
	directories.sort()
	return {"exists":true,"files":files,"directories":directories}

func same_business() -> bool:
	# JSON numeric normalization is limited to known file lengths; file bytes
	# and directory set are compared in full, never Schema-normalized away.
	var current: Dictionary = inventory()
	if current.get("exists") != true or current.directories != expected.directories or current.files.size() != expected.files.size(): return false
	for key: String in expected.files:
		if not current.files.has(key) or current.files[key].sha256 != expected.files[key].sha256 \
			or current.files[key].bytes != int(expected.files[key].bytes): return false
	return true

func scope_state() -> Dictionary:
	var now: int = Time.get_ticks_msec()
	var id: int = slot._liveness_scope_id
	var row := {"at_ms":now,"scope_id":id,"depth":slot._liveness_scope_depth,"budget_ms":Manager.BUDGET_MS}
	if id > 0 and get_tree().root.has_meta(Manager.META_KEY):
		var manager: RefCounted = get_tree().root.get_meta(Manager.META_KEY)
		if manager._scopes.has(id):
			row.deadline_ms = int(manager._scopes[id].deadline_ms)
			row.remaining_ms = int(row.deadline_ms) - now
	return row

func collect_provider() -> void:
	if not get_tree().root.has_meta(Manager.META_KEY): return
	var manager: RefCounted = get_tree().root.get_meta(Manager.META_KEY)
	if manager._oracle == null or manager._oracle._result.is_empty(): return
	retain_provider(manager._oracle._result,manager._oracle._nonce)

func retain_provider(value: Dictionary, nonce: String) -> void:
	var observation: Dictionary = value.duplicate(true)
	var pid: int = int(observation.get("provider_pid",0))
	var directory: String = observation.get("probe_directory","")
	if pid <= 0 or directory.is_empty() or providers.has(directory): return
	# These are this very process's Oracle-created children, not foreign writers.
	# Retain the first terminal sample; later observations cannot overwrite it.
	providers[directory] = {"observation":observation,"provider_pid":pid,"request_nonce":nonce,
		"own_child_exit_code":OS.get_process_exit_code(pid),"own_child_running":OS.is_process_running(pid)}

func collect_scope_providers() -> void:
	if not get_tree().root.has_meta(Manager.META_KEY): return
	var manager: RefCounted = get_tree().root.get_meta(Manager.META_KEY)
	if not manager._scopes.has(slot._liveness_scope_id): return
	for result: Dictionary in manager._scopes[slot._liveness_scope_id].results.values():
		var observation: Dictionary = result.get("observation",result.get("liveness_detail",{}))
		if not observation.is_empty():
			# Oracle.begin binds its fresh nonce to this exact directory basename.
			retain_provider(observation,String(observation.get("probe_directory","")).get_file())
	collect_provider()

func summarize(value: Dictionary) -> Dictionary:
	if value.get("ok") != true: return value.duplicate(true)
	var out := {"ok":true}
	for key: String in ["code","revision","file_sha256","previous","action","head_revision","head_sha256","dead_pid","inventory","items"]:
		if value.has(key): out[key] = value[key]
	if value.has("raw"):
		out.raw_bytes = String(value.raw).to_utf8_buffer().size()
		out.raw_sha256 = String(value.raw).sha256_text()
	if value.has("document"):
		out.document_schema = value.document.get("schema","")
		out.document_generation = value.document.get("generation",0)
	return out

func measured(label: String, operation: Callable) -> Dictionary:
	var scope_before: Dictionary = scope_state()
	var begin_us: int = Time.get_ticks_usec()
	var value: Dictionary = operation.call()
	var end_us: int = Time.get_ticks_usec()
	var scope_after: Dictionary = scope_state()
	var guard_begin: int = Time.get_ticks_usec()
	var unchanged: bool = same_business()
	var guard_us: int = Time.get_ticks_usec() - guard_begin
	var sample_begin: int = Time.get_ticks_usec()
	collect_provider()
	var sample_us: int = Time.get_ticks_usec() - sample_begin
	var summary_begin: int = Time.get_ticks_usec()
	var result_summary: Dictionary = summarize(value)
	var summary_us: int = Time.get_ticks_usec() - summary_begin
	var observer_us: int = Time.get_ticks_usec() - end_us
	timings.append({"label":label,"begin_us":begin_us,"end_us":end_us,"elapsed_us":end_us-begin_us,
		"scope_before":scope_before,"scope_after":scope_after,"inventory_guard_us":guard_us,
		"provider_sampling_us":sample_us,"summary_us":summary_us,"observer_after_call_us":observer_us,
		"business_unchanged":unchanged,"result":result_summary})
	check(unchanged,"same-byte business inventory after " + label)
	return value

func preclaim_sequence(plan: Dictionary) -> Dictionary:
	# Same private call order as _recover_base through its last budget check.
	# Deliberately never call _recover_base/recover: the next production line mkdirs.
	if slot._locked: return slot.bad("REENTRANT_RECOVERY")
	var fresh: Dictionary = measured("preclaim.fresh.inspect_recovery",func(): return slot.inspect_recovery())
	if not healthy or not fresh.get("ok",false): return fresh
	if fresh != plan: return slot.bad("RECOVERY_PLAN_CHANGED")
	var before: Dictionary = measured("preclaim.before._base_recovery_readback",func(): return slot._base_recovery_readback(plan))
	if not healthy or not before.get("ok",false): return before
	var observed: Dictionary = measured("preclaim.claim._confirmed_dead",func(): return slot._confirmed_dead([int(plan.dead_pid)],slot._base_recovery_binding(plan,before.raw),"claim"))
	if not healthy or not observed.get("ok",false): return observed
	var last: Dictionary = measured("preclaim.last._base_recovery_readback",func(): return slot._base_recovery_readback(plan))
	if not healthy or not last.get("ok",false): return last
	if last.raw != before.raw: return slot.bad("RECOVERY_CAS_CHANGED")
	return measured("preclaim.final.check_budget",func(): return Manager.check_budget(slot._liveness_scope_id))

func whole_readonly_preclaim(plan: Dictionary) -> Dictionary:
	# Exact original admission order, with no observer/guard between these calls.
	# The boundary is unchanged: return before the production mkdir line.
	if slot._locked: return slot.bad("REENTRANT_RECOVERY")
	var fresh: Dictionary = slot.inspect_recovery()
	if not fresh.ok: return fresh
	if fresh != plan: return slot.bad("RECOVERY_PLAN_CHANGED")
	var before: Dictionary = slot._base_recovery_readback(plan)
	if not before.ok: return before
	var observed: Dictionary = slot._confirmed_dead([int(plan.dead_pid)],slot._base_recovery_binding(plan,before.raw),"claim")
	if not observed.ok: return observed
	var last: Dictionary = slot._base_recovery_readback(plan)
	if not last.ok: return last
	if last.raw != before.raw: return slot.bad("RECOVERY_CAS_CHANGED")
	return Manager.check_budget(slot._liveness_scope_id)

func measure_whole_preclaim(plan: Dictionary) -> void:
	if not check(same_business(),"same-byte business before whole admission timing"): return
	var begin_us: int = Time.get_ticks_usec()
	var entered: Dictionary = slot._enter_recovery_scope()
	whole_preclaim = whole_readonly_preclaim(plan) if entered.ok else entered
	var end_us: int = Time.get_ticks_usec()
	# Sampling and full-tree guards occur only after the final result above.
	var terminal_scope: Dictionary = scope_state()
	if entered.ok:
		collect_scope_providers()
		slot._leave_recovery_scope()
	var guard_begin: int = Time.get_ticks_usec()
	var unchanged: bool = same_business()
	var guard_us: int = Time.get_ticks_usec() - guard_begin
	timings.append({"label":"whole_preclaim.no_intercall_observers","begin_us":begin_us,"end_us":end_us,
		"elapsed_us":end_us-begin_us,"terminal_scope":terminal_scope,"inventory_guard_us":guard_us,
		"observer_after_sequence_us":Time.get_ticks_usec()-end_us,"business_unchanged":unchanged,
		"result":summarize(whole_preclaim)})
	check(unchanged,"same-byte business after whole admission timing")

func run() -> void:
	# Deferred callbacks can also be flushed by physics. No scope or timed call
	# exists yet; wait for the actual nonphysics process frame first.
	while Engine.is_in_physics_frame(): await get_tree().process_frame
	output = OS.get_environment("CT_OUTPUT")
	var profile: String = OS.get_environment("CT_PROFILE").replace("\\","/")
	if not check(output.is_absolute_path() and profile.is_absolute_path() and OS.get_environment("STEAM_DISABLED") == "1" \
		and OS.get_environment("CAMPAIGN_QA").is_empty() and not Engine.is_in_physics_frame(),"isolated nonphysics diagnostic scope"): finish(); return
	if not check(OS.get_user_data_dir().replace("\\","/").begins_with(profile + "/"),"fresh private userdata"): finish(); return
	var expected_path: String = OS.get_environment("CT_INVENTORY")
	if not check(FileAccess.get_sha256(expected_path) == OS.get_environment("CT_INVENTORY_SHA"),"original inventory binding"): finish(); return
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(expected_path))
	if not check(typeof(decoded) == TYPE_DICTIONARY and decoded.get("exists") == true,"original inventory shape"): finish(); return
	expected = decoded
	business = ProjectSettings.globalize_path("user://continue/v1").replace("\\","/")
	if not check(business == OS.get_environment("CT_CLONE_BUSINESS").replace("\\","/"),"exact clone business path"): finish(); return
	if not check(same_business(),"clone exact before normal startup completion"): finish(); return
	var flow: Node = get_node("/root/ContinueFlow")
	var limit: int = Time.get_ticks_msec() + 30000
	while not flow.can_launch() and Time.get_ticks_msec() < limit:
		if flow.phase == flow.Phase.ERROR: break
		await get_tree().process_frame
	if not check(flow.can_launch() and flow.last_result.get("startup_checked",false) and same_business(),"normal startup complete without business mutation"): finish(); return
	trusted = Identity.new().resolve_runtime_identity()
	if not check(trusted.get("ok",false) and trusted.get("source_mode",false) \
		and trusted.content_version == OS.get_environment("CT_CONTENT") and trusted.engine_binary_sha256 == OS.get_environment("CT_ENGINE"),"bound d7 installation and engine"): finish(); return
	slot = Slot.new()
	measured("independent.inventory",func(): return slot.inventory())
	if not healthy: finish(); return
	measured("independent._chain",func(): return slot._chain())
	if not healthy: finish(); return
	measured("independent._verified.record1",func(): return slot._verified("record_0000000001.json"))
	if not healthy: finish(); return
	inspection = measured("initial.inspect_recovery",func(): return slot.inspect_recovery())
	if healthy and inspection.get("ok",false):
		var entered: Dictionary = measured("preclaim._enter_recovery_scope",func(): return slot._enter_recovery_scope())
		if entered.get("ok",false):
			preclaim = preclaim_sequence(inspection) if healthy else {"ok":false,"code":"DIAGNOSTIC_INVENTORY_CHANGED"}
			slot._leave_recovery_scope()
		else: preclaim = entered
		if healthy: measure_whole_preclaim(inspection)
	finish()

func finish() -> void:
	collect_provider()
	if not business.is_empty(): check(same_business(),"final full clone business inventory unchanged")
	var all_terminal := true
	for directory: String in providers:
		var row: Dictionary = providers[directory]
		var path: String = directory.path_join("result.json")
		row.raw_report_path = path
		row.raw_report_sha256 = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
		row.raw_report = ""
		if FileAccess.file_exists(path):
			var raw_file := FileAccess.open(path,FileAccess.READ)
			if raw_file == null:
				check(false,"original provider report readable")
			else:
				var length: int = raw_file.get_length()
				if check(length > 0 and length <= Manager.Oracle.MAX_REPORT,"bounded original provider report"):
					row.raw_report = raw_file.get_buffer(length).get_string_from_ascii()
				raw_file.close()
		all_terminal = all_terminal and row.own_child_exit_code >= 0 and not row.own_child_running \
			and row.observation.get("helper_cleanup_confirmed",false) and not row.observation.get("pending",true)
	check(all_terminal,"every actual Oracle-owned provider terminal")
	var report := {"schema":"classic_recovery_timing_v1","diagnostic_complete":healthy,"checks":checks,
		"pid":OS.get_process_id(),"nonce":OS.get_environment("CT_NONCE"),"profile":OS.get_environment("CT_PROFILE"),
		"content_version":trusted.get("content_version",""),"engine_sha256":trusted.get("engine_binary_sha256",""),
		"same_byte_isolated_copy":true,"original_profile_used_by_engine":false,"recovery_called":false,
		"claim_created":false,"recovery_qualified":false,"production_qualified":false,"budget_ms":Manager.BUDGET_MS,
		"initial_inspection":summarize(inspection),"preclaim_attempted":not preclaim.is_empty(),"preclaim_result":summarize(preclaim),
		"whole_preclaim_result":summarize(whole_preclaim),
		"timings":timings,"providers":providers,"providers_terminal":all_terminal,
		"instrumentation_note":"Instrumented per-call guards/sampling consume the real scope and are measured separately. Whole admission has no intercall observer and uses a separate fresh original scope; its full-tree guards occur outside the measured sequence. Earlier reads may warm filesystem caches. No deadline is adjusted."}
	var file := FileAccess.open(output.path_join("report.json.tmp"),FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(report)); file.flush(); file.close()
	if DirAccess.rename_absolute(output.path_join("report.json.tmp"),output.path_join("report.json")) != OK: get_tree().quit(2); return
	get_tree().quit(0 if healthy else 1)
