extends Node
## Derived from the verified natural-training worker, without reusing its results.
## CR_MODE: save_training -> resume_complete -> verify_resave, one CR_PROFILE/CR_NONCE.
## Runner binds CR_PROJECT, CR_WORKERS, CR_WORKER_SHA256, CR_REPORT and predecessor SHA.
## STEAM_DISABLED=1 and CAMPAIGN_QA empty; all four private profile roots are required.
## One ordinary recruitment order, three OS processes, fixed user://continue/v1.
## No production progress, Unit positions, resources, HP or completion state is assigned.
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Provider := preload("res://scripts/run_content_identity.gd")
const Factory := preload("res://scripts/run_level4_world_factory.gd")
const Session := preload("res://scripts/run_world_session.gd")
const Store := preload("res://scripts/run_slot_store.gd")
const Lifecycle := preload("res://scripts/run_campaign_local_lifecycle.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const B := preload("res://scripts/battle.gd")
const SLOT := "user://continue/v1"
const MODES := ["save_training", "resume_complete", "verify_resave"]
var mode := ""
var checks: Array = []
var failures: Array = []
var observations: Dictionary = {}
var trusted: Dictionary = {}
var runtime: Dictionary = {}
var prior: Dictionary = {}
var battle: Variant
var producer: Variant
var training: Dictionary = {}
var checkpoint: Dictionary = {}
var commands := 0
var held := false
var hold_error := ""
var retained_session: Variant
var watch_completion := false
var completion_tick := -1

func check(ok: bool, label: String) -> bool:
	checks.append({"label": label, "passed": ok})
	if not ok: failures.append(label)
	print("CAMPAIGN_TRAINING ", "PASS " if ok else "FAIL ", label)
	return ok

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Observe after ordinary Unit production, before the barrier closes this step.
	# An idle/render frame can contain several physics steps; it is not an exact
	# timestamp for training completion.
	process_physics_priority = 2147483646
	run.call_deferred()

func _physics_process(_delta: float) -> void:
	if watch_completion and completion_tick < 0 and not get_tree().paused and healthy() and producer._train_queue.is_empty():
		completion_tick = battle._run_clock._tick + 1
		observations["completion_physics_tick"] = completion_tick
		observations["new_ids_at_completion"] = new_ids()

func run() -> void:
	mode = OS.get_environment("CR_MODE")
	var profile := OS.get_environment("CR_PROFILE").replace("\\", "/").simplify_path()
	var project := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var safe: bool = profile.is_absolute_path() and mode in MODES and OS.get_environment("STEAM_DISABLED") == "1" \
		and OS.get_environment("CAMPAIGN_QA").is_empty()
	for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		safe = safe and OS.get_environment(key).replace("\\", "/").simplify_path().to_lower() == profile.path_join(key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(profile.path_join("appdata").to_lower() + "/")
	safe = safe and project.to_lower() == OS.get_environment("CR_PROJECT").replace("\\", "/").to_lower()
	if not check(safe, "fresh private candidate, four profile roots, Steam disabled and CAMPAIGN_QA empty"): finish(); return
	trusted = Provider.new().resolve_runtime_identity()
	if not check(trusted.get("ok", false) and trusted.get("save_eligible", false) and trusted.get("source_mode", false), "actual installed source identity"): finish(); return
	var pack: Dictionary = Factory.prepare_runtime(trusted)
	if not check(pack.get("ok", false) and not pack.get("deploy_or_start_called", true), "actual installed Level4 runtime"): finish(); return
	runtime = pack.runtime
	var startup_ready: bool = await wait_for_startup()
	if not startup_ready: finish(); return
	var rejected: Dictionary = Profiles.select_context({"mode": "campaign", "level_id": "level4", "waves": 1}, trusted)
	check(not rejected.ok and rejected.get("code") == "OFFICIAL_CONTEXT_NOT_SUPPORTED", "invalid Level4 wave count refused; implemented Gao is not a negative fixture")
	get_node("/root/Settings").game_speed = 1.0
	get_node("/root/Settings").auto_micro_level = 0
	if mode == "save_training":
		await first_process()
	else:
		if read_predecessor():
			var restored: bool = await restore_same_slot()
			if restored:
				if mode == "resume_complete": await second_process()
				else: await third_process()
	finish()

func wait_for_startup() -> bool:
	# Let the candidate perform its own scan/recovery and Campaign._load before
	# selecting Level4 or restoring its slot; do not set the startup gate ourselves.
	var flow: Node = get_node("/root/ContinueFlow")
	if not check(flow.has_method("can_launch"), "candidate startup launch gate exists"): return false
	for frame in range(240):
		if flow.can_launch(): break
		await get_tree().process_frame
	var ready: bool = bool(flow.can_launch())
	observations["startup_result"] = flow.last_result.duplicate(true)
	return check(ready, "actual candidate startup recovery permits launch before chapter selection or restore")

func identity_row() -> Dictionary:
	return {"content_version": trusted.get("content_version", ""),
		"engine_sha256": trusted.get("engine_binary_sha256", ""), "source_mode": trusted.get("source_mode", false)}

func unit_ids() -> Array:
	var ids: Array = []
	for unit in battle.units:
		if is_instance_valid(unit) and unit.key == "gou_lian" and unit.faction == 0 and unit.hp > 0:
			ids.append(str(unit.entity_id))
	ids.sort()
	return ids

func state_row() -> Dictionary:
	return {"producer_entity_id": str(producer.entity_id), "queue_keys": producer._train_queue.duplicate(),
		"remaining_seconds": producer._train_t, "production_blocked": producer.production_blocked,
		"tick": battle._run_clock._next_tick, "gold": battle.gold, "wood": battle.wood,
		"population": battle.population_summary(), "hook_unit_ids": unit_ids(),
		"phase": int(battle.phase), "time_scale": Engine.time_scale, "physics_hz": Engine.physics_ticks_per_second}

func healthy() -> bool:
	return is_instance_valid(battle) and is_instance_valid(producer) and battle.phase == B.Phase.FIGHT \
		and battle.gameplay_rng_fault().is_empty() and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60

func wait_until(predicate: Callable, deadline_seconds: float) -> bool:
	var limit := Time.get_ticks_msec() + int(deadline_seconds * 1000.0)
	while not predicate.call() and Time.get_ticks_msec() < limit and healthy():
		await get_tree().process_frame
	return bool(predicate.call()) and healthy()

func first_process() -> void:
	var initial: Dictionary = Store.new(SLOT).inspect_slot()
	if not check(initial.ok and not initial.exists and initial.revision == 0, "first process starts with no prior slot"): return
	var campaign := get_node("/root/Campaign")
	for key in Profiles.LIAN_FLAGS: campaign.set(key, Profiles.LIAN_FLAGS[key])
	campaign.ai_friendly = false
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	menu._launch()
	for frame in range(240):
		await get_tree().process_frame
		if is_instance_valid(get_tree().current_scene) and get_tree().current_scene.get_script() == B: break
	battle = get_tree().current_scene
	if not check(is_instance_valid(battle) and battle.get_script() == B and battle.level.id() == "level4", "normal menu launches actual Level4"): return
	# Use the authored buttons; do not assign phase or invoke chapter callbacks.
	for line in range(16):
		if not battle.hud._intro_root.visible: break
		battle.hud._intro_btn.pressed.emit()
	if battle.phase == B.Phase.DEPLOY: battle.hud.start_btn.pressed.emit()
	await get_tree().process_frame
	var buildings: Array = battle.units.filter(func(u): return is_instance_valid(u) and u.key == "barracks" and u.faction == 0 and u.hp > 0)
	if not check(buildings.size() == 1, "one original Liang barracks"): return
	producer = buildings[0]
	if not check(healthy() and battle._official_context == Profiles.LIAN_CONTEXT and battle._steam_run_id == 0, "normal speed actual uncredited campaign context"): return
	var before := state_row()
	if not check(before.queue_keys.is_empty() and before.population.queued == 0, "ordinary empty training queue"): return
	var cost: Dictionary = battle._defs.gou_lian
	check(int(cost.cost_gold) == 36 and int(cost.cost_wood) == 24 and int(cost.pop) == 2 and battle.train_time_for("gou_lian") == 20.0, "installed recruitment costs 36 gold 24 wood 2 population and 20 seconds")
	if not failures.is_empty(): return
	var accepted: bool = battle.queue_train(producer, "gou_lian")
	commands += 1
	var after := state_row()
	check(accepted and before.gold - after.gold == 36 and before.wood - after.wood == 24, "one ordinary training command charges exact real resources")
	check(after.population.active == before.population.active and after.population.queued == before.population.queued + 2 and after.population.cap == before.population.cap, "two population reserved without premature unit creation")
	check(after.queue_keys == ["gou_lian"] and after.remaining_seconds == 20.0 and after.hook_unit_ids == before.hook_unit_ids, "real queue starts once at 20 seconds")
	training = {"before": before, "after_order": after,
		"queue_identity": {"producer_entity_id": after.producer_entity_id, "queue_index": 0, "key": "gou_lian", "order_tick": after.tick},
		"native_queue_job_id_exists": false, "command": "Battle.queue_train(original_barracks, gou_lian)", "order_count": 1}
	if not failures.is_empty(): return
	check(await wait_until(func(): return producer._train_t <= 15.0, 30.0), "ordinary simulation advances at least five training seconds")
	if not check(producer._train_queue == ["gou_lian"] and producer._train_t > 0.0 and unit_ids() == before.hook_unit_ids, "save point remains genuinely in progress"): return
	await save_same_slot(1)

func read_predecessor() -> bool:
	var path := OS.get_environment("CR_PREVIOUS")
	if not check(FileAccess.get_sha256(path) == OS.get_environment("CR_PREVIOUS_SHA256"), "exact predecessor report bytes"): return false
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(typeof(value) == TYPE_DICTIONARY, "predecessor report object"): return false
	prior = value
	var wanted := "save_training" if mode == "resume_complete" else "resume_complete"
	check(prior.get("schema") == "campaign_training_resume_v1" and prior.get("passed", false) and prior.get("mode") == wanted and prior.get("batch_nonce") == OS.get_environment("CR_NONCE"), "correct successful same-batch predecessor")
	check(int(prior.get("pid", 0)) > 0 and int(prior.pid) != OS.get_process_id(), "independent native OS process")
	check(prior.get("identity", {}) == identity_row(), "same executed content and engine identity")
	check(prior.get("profile") == OS.get_environment("CR_PROFILE") and prior.get("slot_root") == SLOT, "predecessor uses the same private profile and fixed continue slot")
	# Plain JSON converts integer Variants to floats and rounds displayed doubles.
	# Compare the original exact typed checkpoint, not its human-readable rendering.
	var exact: Dictionary = Codec.new().decode(prior.get("exact_checkpoint", {}))
	if not check(exact.ok and typeof(exact.get("value")) == TYPE_DICTIONARY, "predecessor checkpoint retains exact numeric types and float bits"): return false
	prior.checkpoint = exact.value
	training = prior.get("training", {}).duplicate(true)
	return failures.is_empty()

func restore_same_slot() -> bool:
	var expected: Dictionary = prior.checkpoint
	var store := Store.new(SLOT)
	var saved: Dictionary = store.read_slot()
	if not check(saved.ok, "previous process slot is readable without conversion"): return false
	check(saved.file_sha256 == expected.file_sha256 and int(saved.revision) == int(expected.generation), "exact previous slot hash and generation")
	check(store.directory == expected.directory and saved.document.schema == Store.CAMPAIGN_SCHEMA and saved.document.context == Profiles.LIAN_CONTEXT and saved.document.binding == expected.binding, "same physical campaign slot, actual Level4 context and exact lifecycle binding")
	if not failures.is_empty(): return false
	get_tree().paused = true
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	retained_session = Session.new(trusted, runtime, SLOT)
	var prepared: Dictionary = retained_session.prepare_restore(menu)
	if not check(prepared.ok, "actual Session prepares same saved campaign"): observations["prepare_failure"] = prepared; return false
	var installed: Dictionary = await retained_session.commit_restore_async()
	if not check(installed.ok, "actual Session installs paused world"): observations["install_failure"] = installed; return false
	battle = installed.battle
	var buildings: Array = battle.units.filter(func(u): return is_instance_valid(u) and str(u.entity_id) == training.queue_identity.producer_entity_id)
	if not check(buildings.size() == 1 and buildings[0].key == "barracks" and buildings[0].faction == 0, "same original producer identity after restore"): return false
	producer = buildings[0]
	check(get_tree().paused and healthy() and battle._official_context == Profiles.LIAN_CONTEXT, "restore does not advance or change chapter")
	var restored := state_row()
	observations["restored"] = restored
	check(restored == expected.state, "exact queue timer resources population entity IDs and simulation tick restored")
	check(battle._continue_receipt != null and battle._continue_receipt.token == expected.binding.token, "Session reattaches the original lifecycle token")
	check(lifecycle_row() == expected.lifecycle, "same actual lifecycle journal schema context generation and hash")
	check(store.read_slot().file_sha256 == expected.file_sha256, "restore leaves committed slot unchanged")
	retained_session.dispose(); retained_session = null
	return failures.is_empty()

func new_ids() -> Array:
	return unit_ids().filter(func(id): return id not in training.before.hook_unit_ids)

func second_process() -> void:
	check(producer._train_queue == ["gou_lian"] and producer._train_t > 0.0 and producer._train_t < 20.0, "restored queue is already paid and part complete")
	var receipt_before: Variant = battle._continue_receipt
	if not failures.is_empty(): return
	watch_completion = true
	get_tree().paused = false
	check(await wait_until(func(): return completion_tick >= 0, 45.0), "remaining real training completes without submitting another order")
	watch_completion = false
	var completed := state_row()
	var elapsed := float(completion_tick - int(training.after_order.tick)) / 60.0
	check(absf(elapsed - 20.0) <= 2.0 / 60.0, "completion uses the original normal 20 seconds across processes (at most two physics ticks rounding)")
	check(new_ids().size() == 1 and completed.hook_unit_ids.size() == training.before.hook_unit_ids.size() + 1, "exactly one new hook soldier produced")
	check(completed.population.active == training.before.population.active + 2 and completed.population.queued == training.before.population.queued and completed.population.cap == training.before.population.cap, "reserved population becomes exactly one active two-population unit")
	check(completed.remaining_seconds == 0.0 and not completed.production_blocked, "completed queue has no pending retry or remaining timer")
	observations["completion"] = completed
	observations["elapsed_training_simulation_seconds"] = elapsed
	training["new_unit_id"] = new_ids()[0] if new_ids().size() == 1 else ""
	if not failures.is_empty(): return
	await save_same_slot(2)
	check(battle._continue_receipt == receipt_before, "second save retains the restored lifecycle object without clearing or replacement")

func third_process() -> void:
	check(producer._train_queue.is_empty() and new_ids() == [training.new_unit_id], "third process restores completed queue and exact single new unit")
	if not failures.is_empty(): return
	var start_tick: int = battle._run_clock._next_tick
	get_tree().paused = false
	# Longer than one full recruitment duration: a hidden/replayed order must fail.
	check(await wait_until(func(): return battle._run_clock._next_tick >= start_tick + 21 * 60, 60.0), "third process advances 21 normal seconds")
	check(producer._train_queue.is_empty() and producer._train_t == 0.0 and new_ids() == [training.new_unit_id], "no replayed queue or duplicate soldier after another complete training interval")
	check(battle.population_summary().active == training.before.population.active + 2 and battle.population_summary().queued == 0, "no duplicate population reservation or active population")
	var still_saved: Dictionary = Store.new(SLOT).read_slot()
	check(still_saved.ok and still_saved.get("file_sha256") == prior.checkpoint.file_sha256, "read-only third process does not resave or mutate the slot")
	check(lifecycle_row() == prior.checkpoint.lifecycle, "third process retains original active lifecycle journal")
	observations["after_duplicate_watch"] = state_row()
	checkpoint = prior.checkpoint.duplicate(true)

func lifecycle_row() -> Dictionary:
	if not check(battle._continue_receipt != null, "actual campaign lifecycle receipt exists"): return {}
	var receipt: Variant = battle._continue_receipt
	if not check(receipt.get_script() == Lifecycle, "actual receipt uses the new campaign lifecycle script"): return {}
	var head: Dictionary = receipt.open_head()
	if not check(head.ok, "actual campaign lifecycle journal reads"): return {}
	var document: Dictionary = head.document
	var actual_owner: String = get_node("/root/Campaign").cloud_owner
	var expected_scope: Dictionary = {"owner": actual_owner, "content_version": trusted.content_version,
		"engine_sha256": trusted.engine_binary_sha256}
	check(document.schema == Lifecycle.CAMPAIGN_SCHEMA and document.context == Profiles.LIAN_CONTEXT
		and receipt.expected_context() == Profiles.LIAN_CONTEXT, "campaign lifecycle schema and actual Level4 context are bound")
	check(actual_owner.is_empty() and document.scope == expected_scope
		and receipt.matches_scope(Profiles.LIAN_CONTEXT, trusted, actual_owner), "campaign lifecycle binds the actual offline owner and installed content and engine")
	check(int(head.revision) == 1 and int(document.generation) == 1 and document.token == receipt.token
		and document.state == "active" and document.progress_state == "none" and not document.victory
		and document.intent.is_empty() and document.progress_receipt.is_empty(), "campaign lifecycle stays active at gen1 without a terminal intent or progress acknowledgement")
	if not failures.is_empty(): return {}
	return {"directory": receipt.directory, "token": receipt.token, "file_sha256": head.file_sha256,
		"generation": int(head.revision), "document": document.duplicate(true)}

func save_same_slot(generation: int) -> void:
	get_tree().paused = true
	# The candidate Battle must configure its own actual campaign boundary.
	# Verify that wiring; never repair it in this test or overwrite its context.
	if not check(battle._official_context == Profiles.LIAN_CONTEXT, "capture uses actual chapter context"): return
	if not check(battle._save_barrier.world == battle and battle._save_barrier.clock == battle._run_clock
		and battle._save_barrier._capture_context == Profiles.LIAN_CONTEXT and battle._save_barrier._context_error.is_empty(), "candidate configured its own Level4 capture boundary"): return
	held = false; hold_error = ""
	battle._save_barrier.capture_ready.connect(func(_clock): held = true, CONNECT_ONE_SHOT)
	battle._save_barrier.capture_rejected.connect(func(code): hold_error = str(code), CONNECT_ONE_SHOT)
	var requested: Dictionary = battle._save_barrier.request_capture()
	if not check(requested.ok, "ordinary complete-step capture requested"): return
	for frame in range(240):
		await get_tree().process_frame
		if held or not hold_error.is_empty(): break
	if not check(held and hold_error.is_empty() and battle._save_barrier.health().ok, "actual barrier held after draining"): return
	var store := Store.new(SLOT)
	var inspected: Dictionary = store.inspect_slot()
	if not check(inspected.ok and int(inspected.revision) == generation - 1, "same slot has expected prior generation"): return
	if generation == 2:
		check(inspected.file_sha256 == prior.checkpoint.file_sha256 and battle._continue_receipt.token == prior.checkpoint.binding.token, "second write is bound to exact prior slot and lifecycle")
	if not failures.is_empty(): return
	retained_session = Session.new(trusted, runtime, SLOT)
	var saved: Dictionary = retained_session.save_held(battle, null, {"revision": int(inspected.revision), "file_sha256": inspected.file_sha256})
	if not check(saved.ok, "real Session commits with expected-slot compare-and-swap"):
		observations["save_failure"] = saved
		# Retain a pending Session until process exit; never discard an owned write.
		return
	var read: Dictionary = store.read_slot()
	if not check(read.ok, "committed same slot reads independently"): return
	var life := lifecycle_row()
	if life.is_empty(): return
	check(int(read.revision) == generation and read.document.schema == Store.CAMPAIGN_SCHEMA and read.document.context == Profiles.LIAN_CONTEXT, "fixed campaign slot generation advances exactly once in actual Level4")
	check(read.document.binding.kind == "uncredited" and read.document.binding.token == life.token and read.document.binding.receipt_sha256 == life.file_sha256, "slot binding names the actual retained lifecycle receipt")
	check(life.document.schema == Lifecycle.CAMPAIGN_SCHEMA and life.document.context == Profiles.LIAN_CONTEXT and life.document.state == "active" and life.generation == 1, "actual Level4 campaign lifecycle remains active at gen1")
	if generation == 2:
		check(read.document.binding == prior.checkpoint.binding and life == prior.checkpoint.lifecycle, "resave preserves exact binding and lifecycle bytes")
	checkpoint = {"slot_root": SLOT, "directory": store.directory, "generation": int(read.revision),
		"file_sha256": read.file_sha256, "binding": read.document.binding.duplicate(true),
		"lifecycle": life, "state": state_row(), "context": read.document.context.duplicate(true)}
	check(battle._save_barrier.release_capture().ok, "snapshot barrier released without running gameplay")
	retained_session.dispose(); retained_session = null

func finish() -> void:
	var exact: Dictionary = Codec.new().encode(checkpoint)
	check(exact.ok, "checkpoint report uses the lossless production value codec")
	var report := {"schema": "campaign_training_resume_v1", "passed": not checks.is_empty() and failures.is_empty(),
		"mode": mode, "batch_nonce": OS.get_environment("CR_NONCE"), "pid": OS.get_process_id(),
		"identity": identity_row(), "checks": checks, "failures": failures, "training_commands_this_process": commands,
		"training": training, "checkpoint": checkpoint, "exact_checkpoint": exact.get("value"), "observations": observations,
		"slot_root": SLOT, "profile": OS.get_environment("CR_PROFILE"), "user_directory": OS.get_user_data_dir(),
		"coordinates_resources_damage_or_progress_injected": false, "receipt_reset_or_alternate_slot_used": false,
		"scope": "Natural Level4 recruitment and context-bound campaign gen1 same-token resave at fixed continue slot only",
		"driver_environment_contract": "CR_v1; STEAM_DISABLED=1; CAMPAIGN_QA empty; isolated APPDATA/LOCALAPPDATA/TEMP/TMP",
		"campaign_context_bound_lifecycle_qualified": not checkpoint.is_empty() and failures.is_empty(),
		"campaign_lifecycle_scope": "active gen1 only", "campaign_terminal_cfg_qualified": false,
		"full_lianhuanma_route_qualified": false, "public_continue_qualified": false, "native_sdk_qualified": false}
	var file := FileAccess.open(OS.get_environment("CR_REPORT"), FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(report, "\t")); file.close()
	get_node("/root/Sfx").shutdown(); get_node("/root/Music").shutdown()
	get_tree().quit(0 if report.passed else 1)
