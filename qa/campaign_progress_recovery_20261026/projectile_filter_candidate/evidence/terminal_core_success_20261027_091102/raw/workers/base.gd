extends Node
## Derived UI/Flow helpers; no previous result qualifies this Gao route.
## GVT_MODE: save_after_wave1 -> resume_core_save -> resume_finish -> reject_terminal.
## Runner binds external worker SHA manifest, GVT_REPORT and predecessor SHA.
## STEAM_DISABLED=1 and CAMPAIGN_QA empty; all four private profile roots are required.
## Actual menu, two SaveAndExit operations, restored core-ready button and refusal.
## No production progress, Unit positions, resources, HP or completion state is assigned.
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Provider := preload("res://scripts/run_content_identity.gd")
const Factory := preload("res://scripts/run_level5_world_factory.gd")
const Store := preload("res://scripts/run_slot_store.gd")
const Lifecycle := preload("res://scripts/run_campaign_local_lifecycle.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const B := preload("res://scripts/battle.gd")
const SLOT := "user://continue/v1"
const MODES := ["save_after_wave1", "resume_core_save", "resume_finish", "reject_terminal"]
var mode := ""
var checks: Array = []
var failures: Array = []
var observations: Dictionary = {}
var trusted: Dictionary = {}
var runtime: Dictionary = {}
var prior: Dictionary = {}
var battle: Variant
var opening: Dictionary = {}
var checkpoint: Dictionary = {}
var flow: Variant
var flow_received := false
var flow_result: Dictionary = {}
var save_generation := 0
var save_report_ready := false
var save_exit_owned := false
var selected_chapter_title: Variant
var receipt_before_save: Variant

const Intent := preload("res://scripts/run_campaign_progress_intent.gd")
const Startup := preload("res://scripts/run_campaign_startup_scan.gd")
var terminal_checkpoint: Dictionary = {}
var stage_completed := false
var startup_observation: Dictionary = {}
var action_evidence: Array = []

func check(ok: bool, label: String) -> bool:
	checks.append({"label": label, "passed": ok})
	if not ok: failures.append(label)
	print("GAOQIU_TERMINAL ", "PASS " if ok else "FAIL ", label)
	return ok

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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

func control_diagnostic(control: Control) -> Dictionary:
	var rows: Array = []
	var node: Node = control
	while node != null:
		if node is Control:
			var row: Dictionary = {"path":str(node.get_path()), "class":node.get_class(),
				"visible":node.visible, "visible_in_tree":node.is_visible_in_tree(),
				"rect":str(node.get_global_rect()), "clip_contents":node.clip_contents,
				"mouse_filter":node.mouse_filter, "signals_blocked":node.is_blocking_signals()}
			if node is ScrollContainer:
				var vertical: VScrollBar = node.get_v_scroll_bar()
				var horizontal: HScrollBar = node.get_h_scroll_bar()
				row["scroll"] = {"vertical":node.scroll_vertical, "horizontal":node.scroll_horizontal,
					"v_min":vertical.min_value, "v_max":vertical.max_value, "v_page":vertical.page,
					"h_min":horizontal.min_value, "h_max":horizontal.max_value, "h_page":horizontal.page}
			rows.append(row)
		node = node.get_parent()
	return {"viewport":str(get_viewport().get_visible_rect()), "control_and_ancestors":rows}

func mission_toggle_diagnostic(button: Button) -> Dictionary:
	var connections: Array = button.toggled.get_connections()
	var original: Array = connections.filter(func(row): return row.callable == Callable(battle.mission, "_set_expanded"))
	return {"button_pressed":button.button_pressed, "toggle_mode":button.toggle_mode,
		"expanded":battle.mission._expanded, "details_visible":battle.mission._details.is_visible_in_tree(),
		"scroll_visible":battle.mission._detail_scroll.is_visible_in_tree(),
		"original_toggled_callbacks":original.size(), "geometry":control_diagnostic(button)}

func click_mission_toggle_via_viewport(button: Button) -> bool:
	# Internal Window dispatch exercises BaseButton's own press/release/toggle path.
	# This is not desktop OS input and does not set gameplay or panel state.
	if not check(button_visible(button) and button == battle.mission._toggle and button.toggle_mode
		and not button.button_pressed and not battle.mission._expanded,
		"visible original mission toggle begins unpressed and collapsed"): return false
	var before: Dictionary = mission_toggle_diagnostic(button)
	if not check(before.original_toggled_callbacks == 1 and not button.is_blocking_signals(),
		"original mission toggled callback is connected and enabled"): return false
	var seen: Dictionary = {"pressed":0, "toggled":[]}
	var on_pressed: Callable = func(): seen.pressed += 1
	var on_toggled: Callable = func(value: bool): seen.toggled.append(value)
	button.pressed.connect(on_pressed)
	button.toggled.connect(on_toggled)
	var point: Vector2 = button.get_global_rect().get_center()
	var window: Window = get_tree().root
	var motion := InputEventMouseMotion.new()
	motion.position = point; motion.global_position = point
	window.push_input(motion, true)
	await get_tree().process_frame
	var events: Array = []
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point; event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		window.push_input(event, true)
		events.append({"pressed":pressed, "button_index":event.button_index, "button_mask":event.button_mask,
			"position":[point.x,point.y], "process_frame":Engine.get_process_frames(), "paused":get_tree().paused,
			"pid":OS.get_process_id(), "process_nonce":OS.get_environment("GVT_PROCESS_NONCE")})
		await get_tree().process_frame
	if is_instance_valid(button):
		if button.pressed.is_connected(on_pressed): button.pressed.disconnect(on_pressed)
		if button.toggled.is_connected(on_toggled): button.toggled.disconnect(on_toggled)
	var after: Dictionary = mission_toggle_diagnostic(button) if is_instance_valid(button) else {"freed":true}
	observations["mission_toggle_viewport_input"] = {"route":"Window.push_input", "desktop_os_input":false,
		"before":before, "after":after, "events":events, "pressed_count":seen.pressed, "toggled_values":seen.toggled}
	action_evidence.append({"kind":"viewport_mouse_toggle", "purpose":"expand actual mission panel",
		"route":"Window.push_input", "desktop_os_input":false, "events":events})
	return check(seen.pressed == 1 and seen.toggled == [true] and after.get("button_pressed") == true
		and after.get("expanded") == true and after.get("details_visible") == true
		and after.get("scroll_visible") == true and after.get("original_toggled_callbacks") == 1,
		"native viewport click toggles original mission once and exposes real details")

func reveal_button(button: Variant, anchor: Variant = null) -> bool:
	if not is_instance_valid(button) or not button is Button: return check(false, "requested menu button exists")
	var target: Control = button if anchor == null else anchor
	var attempts: Array = []
	for attempt: int in range(6):
		await get_tree().process_frame
		var parent: Node = button.get_parent()
		while parent != null:
			if parent is ScrollContainer: parent.ensure_control_visible(target)
			parent = parent.get_parent()
		await get_tree().process_frame
		if button_visible(button): return true
		attempts.append({"attempt":attempt, "button_visible_in_tree":button.is_visible_in_tree(), "geometry":control_diagnostic(button)})
	observations["unrevealed_button"] = {"name":str(button.name), "text":button.text,
		"rect":str(button.get_global_rect()), "viewport":str(get_viewport().get_visible_rect()), "disabled":button.disabled,
		"visible_in_tree":button.is_visible_in_tree(), "attempts":attempts, "geometry":control_diagnostic(button)}
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
	var index: int = level5_index()
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

func level5_index() -> int:
	var levels: Array = get_node("/root/Campaign").LEVELS
	for index: int in range(levels.size()):
		if levels[index].id == "level5": return index
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

func wait_for_startup() -> bool:
	# Let the candidate perform its own scan/recovery and Campaign._load before
	# selecting Level5 or restoring its slot; do not set the startup gate ourselves.
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
	for unit: Variant in battle.units:
		if is_instance_valid(unit) and unit.faction == 0 and unit.hp > 0.0 and not unit.is_resource: ids.append(str(unit.entity_id))
	ids.sort()
	return ids

func actor_row(unit: Variant) -> Dictionary:
	if not is_instance_valid(unit): return {"present":false}
	return {"present":true, "entity_id":str(unit.entity_id), "key":unit.key, "faction":unit.faction,
		"position":unit.position, "hp":unit.hp, "max_hp":unit.max_hp, "stance":unit.stance,
		"garrisoned":unit.garrisoned, "holder":str(unit.garrison_holder.entity_id) if is_instance_valid(unit.garrison_holder) else "",
		"story_outcome":unit.story_outcome, "queue":unit._train_queue.duplicate(), "train_t":unit._train_t,
		"production_blocked":unit.production_blocked, "is_constructing":unit.is_constructing,
		"build_progress":unit.build_progress, "build_time":unit.build_time, "order_serial":unit._order_serial}

func state_row() -> Dictionary:
	var rows: Array = []
	for unit: Variant in battle.units:
		if is_instance_valid(unit): rows.append(actor_row(unit))
	rows.sort_custom(func(a, z): return int(a.entity_id) < int(z.entity_id))
	var level: Variant = battle.level
	var button: Dictionary = {"exists":is_instance_valid(level.end_button)}
	if button.exists:
		button["presentation"] = level.end_button.get_meta(battle.mission.PRESENTATION_META, {}).duplicate(true)
		button["disabled"] = level.end_button.disabled
	return {"song":actor_row(level.song), "hall":actor_row(level.hall), "units":rows,
		"tick":battle._run_clock._next_tick, "gold":battle.gold, "wood":battle.wood,
		"population":battle.population_summary(), "player_entity_ids":unit_ids(),
		"level_elapsed":level.elapsed, "waves":level.waves.duplicate(true),
		"strategy_t":level.strategy_t, "production_t":level.production_t.duplicate(), "produced":level.produced.duplicate(),
		"ai_spent_gold":level.ai_spent_gold, "ai_spent_wood":level.ai_spent_wood,
		"land_groups":level.land_groups.map(func(group): return group.map(actor_row)),
		"water_groups":level.water_groups.map(func(group): return group.map(actor_row)),
		"flagship":actor_row(level.flagship), "core_ready":level.core_ready, "flagship_disabled":level.flagship_disabled,
		"end_button":button, "mission_events":battle.mission.events.duplicate(true),
		"story_goals":battle.mission.story_goals.duplicate(true),
		"phase":int(battle.phase), "time_scale":Engine.time_scale, "physics_hz":Engine.physics_ticks_per_second}

func healthy() -> bool:
	return is_instance_valid(battle) and battle.phase == B.Phase.FIGHT and battle.gameplay_rng_fault().is_empty() \
		and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60

func start_from_menu() -> void:
	var initial: Dictionary = Store.new(SLOT).inspect_slot()
	if not check(initial.ok and not initial.exists and initial.revision == 0, "first process starts with no prior slot"): return
	var campaign := get_node("/root/Campaign")
	check(level5_index() >= 0 and campaign.unlocked == 1 and campaign.records.is_empty() and campaign.is_unlocked(level5_index()),
		"fresh profile has no fabricated progress and actual menu permits implemented Level5")
	if not failures.is_empty(): return
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	var story: Variant = text_button(menu, "📜  剧情模式", true)
	if not await reveal_button(story) or not press_button(story, "open actual story module"): return
	await get_tree().process_frame
	var launch: Variant = chapter_button(menu)
	if not check(is_instance_valid(launch) and is_instance_valid(selected_chapter_title), "one actual Level5 card and departure button"): return
	if not await reveal_button(launch, selected_chapter_title.get_parent().get_parent()): check(false, "actual Level5 card scrolls into view"); return
	if not check(is_instance_valid(selected_chapter_title) and control_visible(selected_chapter_title), "selected Level5 title is visible inside all clipping ancestors"): return
	if not press_button(launch, "actual Level5 campaign card departure"): return
	for frame in range(240):
		await get_tree().process_frame
		if is_instance_valid(get_tree().current_scene) and get_tree().current_scene.get_script() == B: break
	battle = get_tree().current_scene
	if not check(is_instance_valid(battle) and battle.get_script() == B and battle.level.id() == "level5", "normal menu launches actual Level5"): return
	# Use the authored buttons; do not assign phase or invoke chapter callbacks.
	for line in range(16):
		if not battle.hud._intro_root.visible: break
		if not press_button(battle.hud._intro_btn, "advance original Level5 introduction"): return
		if battle.hud._intro_root.visible: await get_tree().process_frame
	if battle.phase == B.Phase.DEPLOY:
		if not press_button(battle.hud.start_btn, "start authored Level5 battle"): return
	await get_tree().process_frame
	if not check(healthy() and battle._official_context == Profiles.GAO_CONTEXT and battle._steam_run_id == 0,
		"normal 1x/60Hz actual uncredited Gao context"): return
	if not check(is_instance_valid(battle.level.song) and battle.level.song.hp > 0.0 and not battle.level.song.garrisoned
		and is_instance_valid(battle.level.hall) and battle.level.hall.hp > 0.0, "original commander and hall begin alive outside any fixture"): return
	var land_ids: Array = []
	for group: Array in battle.level.land_groups:
		for enemy: Variant in group:
			if is_instance_valid(enemy) and enemy.faction == 1: land_ids.append(str(enemy.entity_id))
	opening = {"song_entity_id":str(battle.level.song.entity_id), "hall_entity_id":str(battle.level.hall.entity_id),
		"initial_state":state_row(), "original_land_enemy_ids":land_ids}
	check(land_ids.size() == 18 and battle.level.waves.all(func(row): return not row.sent),
		"three original predeployed land groups exist before normal wave timers fire")
	if not failures.is_empty(): return

func read_predecessor() -> bool:
	var path := OS.get_environment("GVT_PREVIOUS")
	if not check(FileAccess.get_sha256(path) == OS.get_environment("GVT_PREVIOUS_SHA256"), "exact predecessor report bytes"): return false
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(typeof(value) == TYPE_DICTIONARY, "predecessor report object"): return false
	prior = value
	var wanted: String = MODES[MODES.find(mode) - 1]
	check(prior.get("schema") == "campaign_gaoqiu_terminal_v1" and prior.get("passed", false) and prior.get("mode") == wanted and prior.get("batch_nonce") == OS.get_environment("GVT_NONCE"), "correct successful same-batch predecessor")
	check(int(prior.get("pid", 0)) > 0 and int(prior.pid) != OS.get_process_id(), "independent native OS process")
	check(prior.get("process_nonce") != OS.get_environment("GVT_PROCESS_NONCE"), "independent process nonce")
	check(prior.get("identity", {}) == identity_row(), "same executed content and engine identity")
	check(prior.get("profile") == OS.get_environment("GVT_PROFILE") and prior.get("slot_root") == SLOT, "predecessor uses the same private profile and fixed continue slot")
	# Plain JSON converts integer Variants to floats and rounds displayed doubles.
	# Compare the original exact typed checkpoint, not its human-readable rendering.
	var exact: Dictionary = Codec.new().decode(prior.get("exact_checkpoint", {}))
	if not check(exact.ok and typeof(exact.get("value")) == TYPE_DICTIONARY, "predecessor checkpoint retains exact numeric types and float bits"): return false
	prior.checkpoint = exact.value
	var exact_opening: Dictionary = Codec.new().decode(prior.get("exact_opening", {}))
	if not check(exact_opening.ok and typeof(exact_opening.get("value")) == TYPE_DICTIONARY, "opening handoff retains exact original actor and wave values"): return false
	opening = exact_opening.value
	if mode in ["resume_core_save", "resume_finish"]:
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
	check(store.directory == expected.directory and saved.document.schema == Store.CAMPAIGN_SCHEMA and saved.document.context == Profiles.GAO_CONTEXT and saved.document.binding == expected.binding, "same physical campaign slot, actual Level5 context and exact lifecycle binding")
	if not failures.is_empty(): return false
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	flow_received = false
	var entry: Variant = menu.find_child("ContinueBattle", true, false)
	if not await reveal_button(entry) or not press_button(entry, "continue original saved Level5"): return false
	if not await wait_flow(): return false
	observations["restore_flow"] = flow_result.duplicate(true)
	if not check(flow_result.get("ok", false) and flow_result.get("generation") == expected.generation,
		"actual ContinueFlow installs original slot generation"): return false
	battle = get_tree().current_scene
	if not check(is_instance_valid(battle) and battle.get_script() == B and battle.level.id() == "level5",
		"menu Continue installs actual Level5 Battle"): return false
	if not check(str(battle.level.song.entity_id) == opening.song_entity_id
		and str(battle.level.hall.entity_id) == opening.hall_entity_id,
		"independent Continue preserves original commander and hall entity identities"): return false
	check(get_tree().paused and battle.hud._pause_root.visible and healthy() and battle._official_context == Profiles.GAO_CONTEXT,
		"actual Continue restores visible pause menu without advancing or changing chapter")
	var restored := state_row()
	observations["restored"] = restored
	check(restored == expected.state, "exact commander hall resources population wave state and simulation tick restored")
	check(battle._continue_receipt != null and battle._continue_receipt.token == expected.binding.token, "Session reattaches the original lifecycle token")
	check(lifecycle_row() == expected.lifecycle, "same actual lifecycle journal schema context generation and hash")
	check(store.read_slot().file_sha256 == expected.file_sha256, "restore leaves committed slot unchanged")
	checkpoint = expected.duplicate(true)
	return failures.is_empty()

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
	check(document.schema == Lifecycle.CAMPAIGN_SCHEMA and document.context == Profiles.GAO_CONTEXT
		and receipt.expected_context() == Profiles.GAO_CONTEXT, "campaign lifecycle schema and actual Level5 context are bound")
	check(actual_owner.is_empty() and document.scope == expected_scope
		and receipt.matches_scope(Profiles.GAO_CONTEXT, trusted, actual_owner), "campaign lifecycle binds the actual offline owner and installed content and engine")
	check(int(head.revision) == 1 and int(document.generation) == 1 and document.token == receipt.token
		and document.state == "active" and document.progress_state == "none" and not document.victory
		and document.intent.is_empty() and document.progress_receipt.is_empty(), "campaign lifecycle stays active at gen1 without a terminal intent or progress acknowledgement")
	if not failures.is_empty(): return {}
	return {"directory": receipt.directory, "token": receipt.token, "file_sha256": head.file_sha256,
		"generation": int(head.revision), "document": document.duplicate(true)}

func save_same_slot(generation: int) -> void:
	if not check(battle._official_context == Profiles.GAO_CONTEXT, "actual Flow capture uses Level5 context"): return
	if not check(battle._save_barrier.world == battle and battle._save_barrier.clock == battle._run_clock
		and battle._save_barrier._capture_context == Profiles.GAO_CONTEXT and battle._save_barrier._context_error.is_empty(),
		"candidate configured its own Level5 capture boundary"): return
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
	if not press_button(save_button, "save and exit actual Level5"): return
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
		and read.document.context == Profiles.GAO_CONTEXT, "fixed campaign slot advances exactly once in actual Level5")
	check(read.document.binding.kind == "uncredited" and read.document.binding.token == life.token
		and read.document.binding.receipt_sha256 == life.file_sha256, "slot binding names actual retained lifecycle receipt")
	check(life.document.schema == Lifecycle.CAMPAIGN_SCHEMA and life.document.context == Profiles.GAO_CONTEXT
		and life.document.state == "active" and life.generation == 1, "actual lifecycle remains active gen1 across saves")
	if save_generation == 2:
		check(read.document.binding == prior.checkpoint.binding and life == prior.checkpoint.lifecycle
			and battle._continue_receipt == receipt_before_save, "resave preserves original lifecycle object binding and bytes")
	var actual: Dictionary = state_row()
	check(get_tree().paused and battle.hud._pause_root.visible, "saved world retains actual visible pause intent")
	check(actual.song.entity_id == opening.song_entity_id and actual.hall.entity_id == opening.hall_entity_id
		and actual.song.hp > 0.0 and actual.hall.hp > 0.0 and actual.song.garrisoned,
		"actual held save retains original living commander garrisoned in original hall")
	if save_generation == 1:
		check(actual.waves[0].sent and not actual.waves[1].sent and not actual.waves[2].sent
			and battle.level._count(battle.level.land_groups[0]) == 0 and battle.level._count(battle.level.water_groups[0]) == 0
			and not actual.core_ready, "first held save follows natural first-wave clearance before later waves")
	else:
		check(actual.waves.all(func(row): return row.sent) and actual.core_ready and actual.flagship_disabled
			and battle.level._core_threats_clear() and actual.end_button.exists, "second held save preserves naturally completed core and actual end button")
	checkpoint = {"slot_root":SLOT, "directory":store.directory, "generation":int(read.revision),
		"file_sha256":read.file_sha256, "binding":read.document.binding.duplicate(true),
		"lifecycle":life, "state":actual, "context":read.document.context.duplicate(true)}
	observations["save_flow"] = operation.duplicate(true)
