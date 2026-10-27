extends Node
## Derived from the verified natural-training worker, without reusing its results.
## LT_MODE: save_training -> resume_training -> resume_victory -> reject_terminal.
## Runner binds external worker SHA manifest, LT_REPORT and predecessor SHA.
## STEAM_DISABLED=1 and CAMPAIGN_QA empty; all four private profile roots are required.
## One ordinary recruitment order, four OS processes, fixed user://continue/v1.
## No production progress, Unit positions, resources, HP or completion state is assigned.
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Provider := preload("res://scripts/run_content_identity.gd")
const Factory := preload("res://scripts/run_level4_world_factory.gd")
const Store := preload("res://scripts/run_slot_store.gd")
const Lifecycle := preload("res://scripts/run_campaign_local_lifecycle.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const B := preload("res://scripts/battle.gd")
const SLOT := "user://continue/v1"
const MODES := ["save_training", "resume_training", "resume_victory", "reject_terminal"]
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
var watch_completion := false
var completion_tick := -1
var flow: Variant
var flow_received := false
var flow_result: Dictionary = {}
var save_generation := 0
var save_report_ready := false
var save_exit_owned := false
var receipt_before_save: Variant
var selected_chapter_title: Variant

const Intent := preload("res://scripts/run_campaign_progress_intent.gd")
const Startup := preload("res://scripts/run_campaign_startup_scan.gd")
var terminal_checkpoint: Dictionary = {}
var stage_completed := false
var startup_observation: Dictionary = {}
var action_evidence: Array = []

func check(ok: bool, label: String) -> bool:
	checks.append({"label": label, "passed": ok})
	if not ok: failures.append(label)
	print("LIANHUANMA_TERMINAL ", "PASS " if ok else "FAIL ", label)
	return ok

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Observe after ordinary Unit production, before the barrier closes this step.
	# An idle/render frame can contain several physics steps; it is not an exact
	# timestamp for training completion.
	process_physics_priority = 2147483646
	call_deferred("run")

func button_visible(button: Variant) -> bool:
	if not is_instance_valid(button) or not button is Button or button.disabled or not button.is_visible_in_tree(): return false
	return control_visible(button)

func control_visible(control: Control) -> bool:
	if not control.is_visible_in_tree(): return false
	var rect: Rect2 = control.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not get_viewport().get_visible_rect().grow(1.0).encloses(rect): return false
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is Control and parent.clip_contents and not parent.get_global_rect().grow(1.0).encloses(rect): return false
		parent = parent.get_parent()
	return true

func reveal_button(button: Variant, anchor: Variant = null) -> bool:
	if not is_instance_valid(button) or not button is Button: return check(false, "requested menu button exists")
	var target: Control = button if anchor == null else anchor
	for attempt: int in range(6):
		await get_tree().process_frame
		var parent: Node = button.get_parent()
		while parent != null:
			if parent is ScrollContainer: parent.ensure_control_visible(target)
			parent = parent.get_parent()
		await get_tree().process_frame
		if button_visible(button): return true
	observations["unrevealed_button"] = {"name":str(button.name), "text":button.text,
		"rect":str(button.get_global_rect()), "viewport":str(get_viewport().get_visible_rect()), "disabled":button.disabled}
	return check(button_visible(button), "normal scroll exposes requested enabled button within clipping bounds")

func press_button(button: Variant, purpose: String) -> bool:
	if not check(button_visible(button), "visible enabled button: " + purpose): return false
	action_evidence.append({"kind":"ui_button", "purpose":purpose, "name":str(button.name), "text":button.text})
	button.pressed.emit()
	return true

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

func chapter_button(menu: Node) -> Variant:
	var index: int = level4_index()
	if index < 0: return null
	var title: String = get_node("/root/Campaign").LEVELS[index].title
	var cards: Node = menu.find_child("CampaignCardsScroll", true, false)
	if cards == null: return null
	var stack: Array = [cards]
	var found: Variant = null
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Label and node.text == title:
			var candidate: Variant = text_button(node.get_parent(), "出 征")
			if candidate != null:
				if found != null: return null
				found = candidate
				selected_chapter_title = node
		stack.append_array(node.get_children())
	return found

func level4_index() -> int:
	var levels: Array = get_node("/root/Campaign").LEVELS
	for index: int in range(levels.size()):
		if levels[index].id == "level4": return index
	return -1

func wait_flow() -> bool:
	var limit: int = Time.get_ticks_msec() + 60000
	while not flow_received and Time.get_ticks_msec() < limit: await get_tree().process_frame
	return check(flow_received, "actual ContinueFlow returns within 60 seconds")

func on_flow_operation(value: Dictionary) -> void:
	flow_result = value.duplicate(true)
	flow_received = true
	if save_generation == 0: return
	if not check(value.get("ok", false), "actual SaveAndExit operation succeeds"):
		observations["save_failure"] = value.duplicate(true)
		return
	save_exit_owned = true
	observe_saved_slot(value)
	# The production callback invokes AppLifecycle after this signal returns.
	# It owns exit and keeps three release frames; never replace its quit path.
	await get_tree().process_frame
	var lifecycle: Node = get_node("/root/AppLifecycle")
	check(lifecycle.quit_started() and lifecycle.quit_reason() == "continue_saved", "production SaveAndExit requests actual continue_saved exit")
	observations["save_exit"] = {"started":lifecycle.quit_started(), "reason":lifecycle.quit_reason(), "generation":save_generation}
	stage_completed = failures.is_empty() and not checkpoint.is_empty() and checkpoint.generation == save_generation
	save_report_ready = true
	call("finish", false)

func _physics_process(_delta: float) -> void:
	if watch_completion and completion_tick < 0 and not get_tree().paused and healthy() and producer._train_queue.is_empty():
		completion_tick = battle._run_clock._tick + 1
		observations["completion_physics_tick"] = completion_tick
		observations["new_ids_at_completion"] = new_ids()

func wait_for_startup() -> bool:
	# Let the candidate perform its own scan/recovery and Campaign._load before
	# selecting Level4 or restoring its slot; do not set the startup gate ourselves.
	var startup_flow: Node = get_node("/root/ContinueFlow")
	if not check(startup_flow.has_method("can_launch"), "candidate startup launch gate exists"): return false
	for frame in range(240):
		if startup_flow.can_launch(): break
		await get_tree().process_frame
	var ready: bool = bool(startup_flow.can_launch())
	observations["startup_result"] = startup_flow.last_result.duplicate(true)
	startup_observation = startup_flow.last_result.duplicate(true)
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
	check(level4_index() >= 0 and campaign.unlocked == 1 and campaign.records.is_empty() and campaign.is_unlocked(level4_index()),
		"fresh profile has no fabricated progress and actual menu permits implemented Level4")
	if not failures.is_empty(): return
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	var story: Variant = text_button(menu, "📜  剧情模式", true)
	if not await reveal_button(story) or not press_button(story, "open actual story module"): return
	await get_tree().process_frame
	var launch: Variant = chapter_button(menu)
	if not check(is_instance_valid(launch) and is_instance_valid(selected_chapter_title), "one actual Level4 card and departure button"): return
	if not await reveal_button(launch, selected_chapter_title.get_parent().get_parent()): check(false, "actual Level4 card scrolls into view"); return
	if not check(is_instance_valid(selected_chapter_title) and control_visible(selected_chapter_title), "selected Level4 title is visible inside all clipping ancestors"): return
	if not press_button(launch, "actual Level4 campaign card departure"): return
	for frame in range(240):
		await get_tree().process_frame
		if is_instance_valid(get_tree().current_scene) and get_tree().current_scene.get_script() == B: break
	battle = get_tree().current_scene
	if not check(is_instance_valid(battle) and battle.get_script() == B and battle.level.id() == "level4", "normal menu launches actual Level4"): return
	# Use the authored buttons; do not assign phase or invoke chapter callbacks.
	for line in range(16):
		if not battle.hud._intro_root.visible: break
		if not press_button(battle.hud._intro_btn, "advance original Level4 introduction"): return
		if battle.hud._intro_root.visible: await get_tree().process_frame
	if battle.phase == B.Phase.DEPLOY:
		if not press_button(battle.hud.start_btn, "start authored Level4 battle"): return
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
	var path := OS.get_environment("LT_PREVIOUS")
	if not check(FileAccess.get_sha256(path) == OS.get_environment("LT_PREVIOUS_SHA256"), "exact predecessor report bytes"): return false
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(typeof(value) == TYPE_DICTIONARY, "predecessor report object"): return false
	prior = value
	var wanted: String = MODES[MODES.find(mode) - 1]
	check(prior.get("schema") == "campaign_lianhuanma_terminal_v2" and prior.get("passed", false) and prior.get("mode") == wanted and prior.get("batch_nonce") == OS.get_environment("LT_NONCE"), "correct successful same-batch predecessor")
	check(int(prior.get("pid", 0)) > 0 and int(prior.pid) != OS.get_process_id(), "independent native OS process")
	check(prior.get("process_nonce") != OS.get_environment("LT_PROCESS_NONCE"), "independent process nonce")
	check(prior.get("identity", {}) == identity_row(), "same executed content and engine identity")
	check(prior.get("profile") == OS.get_environment("LT_PROFILE") and prior.get("slot_root") == SLOT, "predecessor uses the same private profile and fixed continue slot")
	# Plain JSON converts integer Variants to floats and rounds displayed doubles.
	# Compare the original exact typed checkpoint, not its human-readable rendering.
	var exact: Dictionary = Codec.new().decode(prior.get("exact_checkpoint", {}))
	if not check(exact.ok and typeof(exact.get("value")) == TYPE_DICTIONARY, "predecessor checkpoint retains exact numeric types and float bits"): return false
	prior.checkpoint = exact.value
	var exact_training: Dictionary = Codec.new().decode(prior.get("exact_training", {}))
	if not check(exact_training.ok and typeof(exact_training.get("value")) == TYPE_DICTIONARY, "training handoff retains exact original values"): return false
	training = exact_training.value
	if mode in ["resume_training", "resume_victory"]:
		check(prior.get("exit_reason") == "continue_saved" and prior.get("save_exit_observed", false), "predecessor exited through production SaveAndExit")
	if mode == "reject_terminal":
		var terminal: Dictionary = Codec.new().decode(prior.get("exact_terminal", {}))
		if not check(terminal.ok and typeof(terminal.get("value")) == TYPE_DICTIONARY, "terminal handoff retains exact typed values"): return false
		terminal_checkpoint = terminal.value
	return failures.is_empty()

func restore_same_slot() -> bool:
	var expected: Dictionary = prior.checkpoint
	var store := Store.new(SLOT)
	var saved: Dictionary = store.read_slot()
	if not check(saved.ok, "previous process slot is readable without conversion"): return false
	check(saved.file_sha256 == expected.file_sha256 and int(saved.revision) == int(expected.generation), "exact previous slot hash and generation")
	check(store.directory == expected.directory and saved.document.schema == Store.CAMPAIGN_SCHEMA and saved.document.context == Profiles.LIAN_CONTEXT and saved.document.binding == expected.binding, "same physical campaign slot, actual Level4 context and exact lifecycle binding")
	if not failures.is_empty(): return false
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	flow_received = false
	var entry: Variant = menu.find_child("ContinueBattle", true, false)
	if not await reveal_button(entry) or not press_button(entry, "continue original saved Level4"): return false
	if not await wait_flow(): return false
	observations["restore_flow"] = flow_result.duplicate(true)
	if not check(flow_result.get("ok", false) and flow_result.get("generation") == expected.generation,
		"actual ContinueFlow installs original slot generation"): return false
	battle = get_tree().current_scene
	if not check(is_instance_valid(battle) and battle.get_script() == B and battle.level.id() == "level4",
		"menu Continue installs actual Level4 Battle"): return false
	var buildings: Array = battle.units.filter(func(u): return is_instance_valid(u) and str(u.entity_id) == training.queue_identity.producer_entity_id)
	if not check(buildings.size() == 1 and buildings[0].key == "barracks" and buildings[0].faction == 0, "same original producer identity after restore"): return false
	producer = buildings[0]
	check(get_tree().paused and battle.hud._pause_root.visible and healthy() and battle._official_context == Profiles.LIAN_CONTEXT,
		"actual Continue restores visible pause menu without advancing or changing chapter")
	var restored := state_row()
	observations["restored"] = restored
	check(restored == expected.state, "exact queue timer resources population entity IDs and simulation tick restored")
	check(battle._continue_receipt != null and battle._continue_receipt.token == expected.binding.token, "Session reattaches the original lifecycle token")
	check(lifecycle_row() == expected.lifecycle, "same actual lifecycle journal schema context generation and hash")
	check(store.read_slot().file_sha256 == expected.file_sha256, "restore leaves committed slot unchanged")
	checkpoint = expected.duplicate(true)
	return failures.is_empty()

func new_ids() -> Array:
	return unit_ids().filter(func(id): return id not in training.before.hook_unit_ids)

func complete_training() -> void:
	check(producer._train_queue == ["gou_lian"] and producer._train_t > 0.0 and producer._train_t < 20.0, "restored queue is already paid and part complete")
	var receipt_before: Variant = battle._continue_receipt
	if not failures.is_empty(): return
	watch_completion = true
	if not press_button(battle.hud._pause_resume_button, "resume saved in-progress training"): return
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
	var finished_tick: int = battle._run_clock._next_tick
	check(await wait_until(func(): return battle._run_clock._next_tick >= finished_tick + 21 * 60, 60.0), "another 21 normal seconds pass before new economy recruitment")
	check(producer._train_queue.is_empty() and producer._train_t == 0.0 and new_ids() == [training.new_unit_id], "original paid order cannot replay or create a duplicate soldier")
	check(battle.population_summary().active == training.before.population.active + 2 and battle.population_summary().queued == 0, "no duplicate active or reserved population")
	if not failures.is_empty(): return
	check(battle._continue_receipt == receipt_before, "completed training retains restored lifecycle object")
	await save_same_slot(2)

func lifecycle_row() -> Dictionary:
	if not check(Lifecycle.CAMPAIGN_SCHEMA == "local_campaign_continue_lifecycle_v3" and battle._continue_receipt != null, "actual current v3 campaign lifecycle receipt exists"): return {}
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
	if not check(battle._official_context == Profiles.LIAN_CONTEXT, "actual Flow capture uses Level4 context"): return
	if not check(battle._save_barrier.world == battle and battle._save_barrier.clock == battle._run_clock
		and battle._save_barrier._capture_context == Profiles.LIAN_CONTEXT and battle._save_barrier._context_error.is_empty(),
		"candidate configured its own Level4 capture boundary"): return
	var store := Store.new(SLOT)
	var inspected: Dictionary = store.inspect_slot()
	if not check(inspected.ok and int(inspected.revision) == generation - 1, "same slot has expected prior generation"): return
	if generation == 2:
		check(inspected.file_sha256 == prior.checkpoint.file_sha256 and battle._continue_receipt.token == prior.checkpoint.binding.token,
			"second Flow write retains exact prior slot and lifecycle")
	if not failures.is_empty(): return
	receipt_before_save = battle._continue_receipt
	save_generation = generation
	flow_received = false
	# Let actual viewport Esc open the normal pause menu. No pause/HUD assignment.
	for attempt: int in range(3):
		if get_tree().paused and battle.hud._pause_root.visible: break
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.pressed = true
		action_evidence.append({"kind":"viewport_key", "key":"Escape", "purpose":"open actual pause menu", "attempt":attempt})
		get_viewport().push_input(key)
		key = key.duplicate()
		key.pressed = false
		get_viewport().push_input(key)
		await get_tree().process_frame
	if not check(get_tree().paused and battle.hud._pause_root.visible, "viewport Escape opens real pause menu"): return
	var save_button: Variant = battle.hud.find_child("SaveAndExit", true, false)
	if not press_button(save_button, "save and exit actual Level4"): return
	if generation == 2:
		if not check(flow.phase == flow.Phase.CONFIRM, "second save requests actual overwrite confirmation"): return
		await get_tree().process_frame
		if not press_button(flow.find_child("ConfirmSave", true, false), "confirm same-slot overwrite"): return
	elif not check(flow.phase in [flow.Phase.SAVING, flow.Phase.EXITING], "first save starts without fabricated overwrite confirmation"):
		return
	if not await wait_flow(): return
	var deadline: int = Time.get_ticks_msec() + 10000
	while save_exit_owned and not save_report_ready and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not save_exit_owned:
		check(false, "save did not reach production-owned exit")

func observe_saved_slot(operation: Dictionary) -> void:
	var store := Store.new(SLOT)
	var read: Dictionary = store.read_slot()
	if not check(read.ok, "Flow-committed same slot reads independently"): return
	var life: Dictionary = lifecycle_row()
	if life.is_empty(): return
	check(operation.get("file_sha256") == read.file_sha256 and flow.phase == flow.Phase.EXITING,
		"operation receipt matches durable slot before production exit")
	check(int(read.revision) == save_generation and read.document.schema == Store.CAMPAIGN_SCHEMA
		and read.document.context == Profiles.LIAN_CONTEXT, "fixed campaign slot advances exactly once in actual Level4")
	check(read.document.binding.kind == "uncredited" and read.document.binding.token == life.token
		and read.document.binding.receipt_sha256 == life.file_sha256, "slot binding names actual retained lifecycle receipt")
	check(life.document.schema == Lifecycle.CAMPAIGN_SCHEMA and life.document.context == Profiles.LIAN_CONTEXT
		and life.document.state == "active" and life.generation == 1, "actual lifecycle remains active gen1 across saves")
	if save_generation == 2:
		check(read.document.binding == prior.checkpoint.binding and life == prior.checkpoint.lifecycle
			and battle._continue_receipt == receipt_before_save, "resave preserves original lifecycle object binding and bytes")
	var actual: Dictionary = state_row()
	check(get_tree().paused and battle.hud._pause_root.visible, "saved world retains actual visible pause intent")
	if save_generation == 1:
		check(actual.queue_keys == ["gou_lian"] and actual.remaining_seconds > 0.0
			and actual.hook_unit_ids == training.before.hook_unit_ids, "actual held boundary retains unfinished original training")
	else:
		check(actual.queue_keys.is_empty() and actual.remaining_seconds == 0.0
			and new_ids() == [training.new_unit_id], "actual held resave boundary retains exactly one completed paid soldier")
	checkpoint = {"slot_root":SLOT, "directory":store.directory, "generation":int(read.revision),
		"file_sha256":read.file_sha256, "binding":read.document.binding.duplicate(true),
		"lifecycle":life, "state":actual, "context":read.document.context.duplicate(true)}
	observations["save_flow"] = operation.duplicate(true)
