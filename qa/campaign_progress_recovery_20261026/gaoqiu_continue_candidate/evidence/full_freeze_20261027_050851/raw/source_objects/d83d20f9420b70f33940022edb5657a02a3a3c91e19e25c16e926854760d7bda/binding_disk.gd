extends Node
## Synthetic model identity, real private filesystem. No SDK, Battle outcome,
## public Flow, reward, natural victory or real-account qualification.
const Lifecycle = preload("res://scripts/run_campaign_local_lifecycle.gd")
const Intent = preload("res://scripts/run_campaign_progress_intent.gd")
const Identity = preload("res://scripts/run_content_identity.gd")
const OWNER := "76561198000000001"
const OTHER_OWNER := "76561198000000002"
const CONTEXT := {"mode":"campaign", "level_id":"level4", "waves":0}
var checks: Array = []
var evidence: Dictionary = {}
var trusted: Dictionary = {}
var nonce := ""
var output := ""
var root_path := ""
var expected := ""

func _ready() -> void:
	run.call_deferred()

func check(value: bool, label: String, category: String = "fixed_regression") -> bool:
	checks.append({"label":label,"passed":value,"category":category})
	return value

func fresh(token: String, context: Dictionary = CONTEXT, identity: Dictionary = {}, owner: String = OWNER) -> RefCounted:
	return Lifecycle.new(token,root_path,context,trusted if identity.is_empty() else identity,owner)

func inventory(store: RefCounted) -> Dictionary:
	return store.inventory()

func fixture_intent(token: String) -> Dictionary:
	# Claimed Steam credit is synthetic validator input, not a real ledger proof.
	return {"schema":"campaign_progress_intent_v2","token":token,"context":CONTEXT.duplicate(),
		"profile_id":"campaign_level4_v1","owner":OWNER,"content_version":trusted.content_version,
		"engine_sha256":trusted.engine_binary_sha256,"victory":false,
		"credit":{"kind":"steam","binding":{"kind":"steam","owner":OWNER,"token":token,
			"credited_kills":0,"generation":1,"receipt_sha256":"b".repeat(64)},"correction_epoch":0},
		"result":{"core_cleared":false,"story_complete":false,"story_done":0,"story_total":4,
			"done_ids":[],"contract_version":2}}

func exercise() -> void:
	var token: String = (nonce + "active").sha256_text().substr(0,32)
	var created: RefCounted = fresh(token)
	var begun: Dictionary = created.begin()
	if not check(begun.ok,"normal Lifecycle.begin writes real gen1","baseline_reproduction"): return
	var before: Dictionary = inventory(created)
	evidence.gen1_inventory = before
	evidence.gen1_head = created.open_head()
	var cold: RefCounted = fresh(token)
	var original: Dictionary = cold.binding()
	evidence.original_cold_binding = original
	if not check(not original.ok and original.code == "LOCAL_TOKEN_EXISTS",
		"fresh object without explicit adoption demonstrates original cold-binding failure","baseline_reproduction"): return
	if not check(inventory(created) == before,"original refusal does not modify gen1 files","baseline_reproduction"): return
	if expected == "baseline": return
	if not check(cold.has_method("prepare_credited_resume"),"candidate explicit adoption API exists"): return
	var restored: Dictionary = cold.prepare_credited_resume(token,OWNER)
	evidence.restored = restored
	if not check(restored.ok and not restored.absent and restored.read_only,"existing credited sidejournal is adopted read-only"): return
	var bound: Dictionary = cold.binding()
	if not check(bound.ok and bound.binding == begun.binding,
		"binding uses actual local gen1 SHA and original token, not synthetic Steam digest"): return
	if not check(bound.binding.receipt_sha256 != "b".repeat(64),"Steam receipt digest was not installed as local binding"): return
	check(inventory(created) == before,"adoption and repeated binding preserve every original file SHA")
	check(cold.prepare_credited_resume(token,OWNER) == restored,"second mount-time check has the same marker")
	check(not cold.prepare_credited_resume("f".repeat(32),OWNER).ok,"different credited token rejected")
	check(not cold.prepare_credited_resume(token,OTHER_OWNER).ok,"different credited account rejected")
	var wrong_context: Dictionary = CONTEXT.duplicate(); wrong_context.level_id = "level3"
	check(not fresh(token,wrong_context).prepare_credited_resume(token,OWNER).ok,"on-disk context mismatch rejected")
	check(not fresh(token,CONTEXT,{},OTHER_OWNER).prepare_credited_resume(token,OTHER_OWNER).ok,"on-disk profile owner mismatch rejected")
	var wrong_content: Dictionary = trusted.duplicate(true); wrong_content.content_version += "-changed"
	check(not fresh(token,CONTEXT,wrong_content).prepare_credited_resume(token,OWNER).ok,"on-disk content identity mismatch rejected")
	var wrong_engine: Dictionary = trusted.duplicate(true); wrong_engine.engine_binary_sha256 = "d".repeat(64)
	check(not fresh(token,CONTEXT,wrong_engine).prepare_credited_resume(token,OWNER).ok,"on-disk engine identity mismatch rejected")
	check(inventory(created) == before,"all scope refusals preserve original journal bytes")
	var legacy_token: String = (nonce + "legacy").sha256_text().substr(0,32)
	var legacy: RefCounted = fresh(legacy_token)
	var absent: Dictionary = legacy.prepare_credited_resume(legacy_token,OWNER)
	check(absent.ok and absent.absent and legacy._binding.is_empty() and not DirAccess.dir_exists_absolute(legacy.directory),
		"legacy absence is accepted without directory creation or local binding fabrication")
	check(legacy.prepare_credited_resume(legacy_token,OWNER) == absent,"unchanged legacy absence passes mount-time check")
	var appeared: RefCounted = fresh(legacy_token)
	if not check(appeared.begin().ok,"separate normal writer creates a real marker after absence observation"): return
	var appeared_inventory: Dictionary = inventory(appeared)
	var changed: Dictionary = legacy.prepare_credited_resume(legacy_token,OWNER)
	check(not changed.ok and changed.code == "LOCAL_CAMPAIGN_MARKER_CHANGED" and legacy._binding.is_empty(),
		"absence-to-present race rejected without silently adopting the new marker")
	check(inventory(appeared) == appeared_inventory,"marker race refusal preserves the other writer's journal")
	var empty_token: String = (nonce + "empty").sha256_text().substr(0,32)
	var empty: RefCounted = fresh(empty_token)
	if not check(empty.initialize_directory().ok,"explicit fixture creates an existing empty journal directory"): return
	check(not empty.prepare_credited_resume(empty_token,OWNER).ok,"empty directory is not a valid active marker or legacy absence")
	var intent: Dictionary = fixture_intent(token)
	var checked: Dictionary = Intent.validate(intent,token,Intent.scope(CONTEXT,trusted,OWNER))
	if not check(checked.ok,"synthetic terminal-intent data validates without SDK evidence"): return
	# Only the local LC transaction is exercised. No Coordinator, ACK service,
	# reward function, metrics or real battle callback is invoked.
	var terminal: Dictionary = cold.terminal_with_intent(false,checked.intent)
	evidence.terminal_model = terminal
	if not check(terminal.ok and terminal.local_terminal_committed,"adopted gen1 reaches real local gen2 through terminal API"): return
	var gen2: Dictionary = cold.open_head()
	var gen2_inventory: Dictionary = inventory(cold)
	var refused: Dictionary = fresh(token).prepare_credited_resume(token,OWNER)
	check(not refused.ok and refused.code == "LOCAL_RUN_TERMINAL","new object rejects terminal gen2")
	check(not cold.prepare_credited_resume(token,OWNER).ok,"same retained object cannot reopen terminal gen2")
	check(inventory(cold) == gen2_inventory,"terminal gen2 refusals preserve the whole journal")
	# A separate synthetic *data fixture* tests the gen3 refusal boundary. This
	# direct Store transaction is NOT proof that ack_progress/Steam handoff ran.
	var applied: Dictionary = gen2.document.duplicate(true)
	applied.generation = 3; applied.progress_state = "applied"
	var descriptor: Dictionary = Intent.handoff_descriptor(applied.intent)
	var proof := {"schema":"campaign_steam_handoff_proof_v1","owner":OWNER,"token":token,
		"context":CONTEXT.duplicate(),"intent_sha256":JSON.stringify(applied.intent).sha256_text(),
		"descriptor_sha256":JSON.stringify(descriptor).sha256_text(),"correction_epoch":0,
		"ledger_document_generation":2,"ledger_file_sha256":"c".repeat(64)}
	applied.progress_receipt = {"schema":"campaign_progress_ack_v2","code":"CAMPAIGN_PROGRESS_NOT_REQUIRED",
		"persisted":false,"suppressed":false,"file_sha256":"","steam_handoff":proof}
	var fixture: RefCounted = fresh(token)
	var locked: Dictionary = fixture.acquire()
	if not check(locked.ok and locked.file_sha256 == gen2.file_sha256,"synthetic gen3 fixture acquires exact gen2 CAS"): return
	var saved: Dictionary = fixture.commit_locked(locked.revision,locked.file_sha256,
		{"record":applied,"sha256":JSON.stringify(applied).sha256_text()})
	if not check(saved.ok,"strict synthetic gen3 validator fixture persists through real Store"): return
	if not check(fixture.release().ok,"synthetic gen3 fixture releases its own lock"): return
	var gen3_inventory: Dictionary = inventory(fixture)
	var rejected: Dictionary = fresh(token).prepare_credited_resume(token,OWNER)
	check(not rejected.ok and rejected.code == "LOCAL_RUN_TERMINAL","new object rejects terminal gen3 fixture")
	check(inventory(fixture) == gen3_inventory,"gen3 refusal preserves every fixture byte")
	evidence.gen1_inventory = before
	evidence.gen2_inventory = gen2_inventory
	evidence.gen3_fixture_inventory = gen3_inventory
	evidence.synthetic_gen3_ack_only = true

func run() -> void:
	nonce = OS.get_environment("CB_NONCE"); output = OS.get_environment("CB_OUTPUT")
	expected = OS.get_environment("CB_EXPECT")
	var profile: String = OS.get_environment("CB_PROFILE").replace("\\","/").trim_suffix("/")
	var safe: bool = profile.is_absolute_path() and Intent.hex(nonce,32) and output.is_absolute_path() \
		and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA").is_empty()
	for key in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
		safe = safe and OS.get_environment(key).replace("\\","/").to_lower() == profile.path_join(key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(profile.to_lower() + "/")
	if not check(safe and expected in ["baseline","fixed"],"explicit private profile, nonce, mode and SDK-off scope","fixture_precondition"): finish(); return
	trusted = Identity.new().resolve_runtime_identity()
	if not check(trusted.get("ok",false) and trusted.get("source_mode",false),"actual frozen source identity","fixture_precondition"): finish(); return
	root_path = "user://continue_binding_probe/" + nonce
	for frame in range(4):
		if not Engine.is_in_physics_frame(): break
		await get_tree().process_frame
	if not check(not Engine.is_in_physics_frame(),"real disk operations outside physics frame","fixture_precondition"): finish(); return
	await get_tree().process_frame
	exercise()
	finish()

func finish() -> void:
	var failures: Array = checks.filter(func(row): return not row.passed)
	var fixed_checks: Array = checks.filter(func(row): return row.category == "fixed_regression")
	var report := {"schema":"continue_binding_disk_fixture_v1","passed":failures.is_empty(),"expected":expected,
		"baseline_defect_reproduced":expected == "baseline" and failures.is_empty(),
		"fixed_regression_count":fixed_checks.size(),
		"fixed_lifecycle_model_passed":expected == "fixed" and not fixed_checks.is_empty() and failures.is_empty(),
		"pid":OS.get_process_id(),"nonce":nonce,"identity":trusted,"root_path":root_path,
		"profile":OS.get_environment("CB_PROFILE"),"user_directory":OS.get_user_data_dir(),
		"checks":checks,"failures":failures,"evidence":evidence,"synthetic_account_credit_and_terminal":true,
		"sdk_qualified":false,"natural_battle_qualified":false,"public_flow_qualified":false,"production_qualified":false}
	var path: String = output.path_join("report.json")
	if FileAccess.file_exists(path): get_tree().quit(2); return
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(report)); file.flush()
	var saved: bool = file.get_error() == OK
	file.close()
	get_tree().quit(0 if saved and failures.is_empty() else 1)
