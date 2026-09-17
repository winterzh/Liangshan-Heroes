extends Node
## Native installed-map/scenery component QA; no Core, Session or player resume.
const B := preload("res://scripts/battle.gd")
const U := preload("res://scripts/unit.gd")
const M := preload("res://scripts/game_map.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Factory := preload("res://scripts/run_level3_world_factory.gd")
const Provider := preload("res://scripts/run_content_identity.gd")
const MapState := preload("res://scripts/run_map_state.gd")
const SceneryState := preload("res://scripts/run_scenery_state.gd")
const Scenery := preload("res://scripts/campaign_scenery.gd")
const EnvironmentConfig := preload("res://scripts/campaign_environment.gd")
const EnvironmentArt := preload("res://scripts/campaign_environment_art.gd")
const Stockade := preload("res://scripts/liangshan_stockade.gd")
const UnitState := preload("res://scripts/run_unit_state.gd")
const UnitGraph := preload("res://scripts/run_unit_graph.gd")
const Identity := preload("res://scripts/run_graph_identity.gd")
const Inventory := preload("res://scripts/hero_inventory.gd")
const LevelState := preload("res://scripts/run_campaign_level_state.gd")
const FogState := preload("res://scripts/run_fog_state.gd")
const CameraState := preload("res://scripts/run_camera_state.gd")
const Classic := preload("res://scripts/levels/skirmish.gd")
const TOKEN := "mission:level3:scenery_qa"
const BATTLE_FIELDS := ["gold", "wood", "pop_cap", "current_age", "faction_res", "faction_gather_mult", "_tech_done", "next_item_uid", "kills", "_steam_valid_kills"]
var checks: Array = []
var images: Array = []
var source: Variant = null
var held := false
var rejected := ""
var trusted: Dictionary = {}
var codec := Codec.new()
var targets: Array = []
var details: Dictionary = {}
var phase := ""
var late_ui: Dictionary = {}

class PhysicsActivation extends Node:
	var adapter: RefCounted
	var result: Dictionary = {}
	var physics_seen := false
	func _physics_process(_delta: float) -> void:
		physics_seen = Engine.is_in_physics_frame()
		result = adapter.activate_campaign()
		set_physics_process(false)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var profile := OS.get_environment("LSH_LEVEL3_SCENERY_PROFILE").replace("\\", "/").simplify_path()
	var safe := profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path()
		safe = safe and path.to_lower() == (profile + "/" + key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower().begins_with((profile + "/appdata/").to_lower())
	if not safe or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("CAMPAIGN_QA") != "1":
		print("LEVEL3_SCENERY_QA PRIVATE_PROFILE_REQUIRED"); get_tree().quit(2); return
	run.call_deferred()

func check(matrix: String, label: String, passed: bool) -> bool:
	checks.append({"matrix": matrix, "label": label, "passed": passed})
	if not passed: print("FAIL ", matrix, " ", label)
	return passed

func graph() -> RefCounted:
	return UnitGraph.new(UnitState, Identity, Codec, U, Inventory, B, M, Profiles.ZHU_CONTEXT)

func map_state() -> RefCounted: return MapState.new(trusted.content_version, Profiles.ZHU_CONTEXT)
func scenery_state() -> RefCounted: return SceneryState.new(trusted.content_version, Profiles.ZHU_CONTEXT)
func fog_state() -> RefCounted: return FogState.new(trusted, B, M, Codec, B.FogLayer)

func _on_held(_clock: Dictionary) -> void: held = true
func _on_rejected(code: String) -> void: rejected = code

func _queue_late_ui() -> void:
	# Registered after the production barrier's process_frame handler. This
	# schedules real task construction into its paused deferred drain window.
	_create_late_ui.call_deferred()

func _create_late_ui() -> void:
	late_ui["state_at_creation"] = int(source._save_barrier.state)
	late_ui["paused_at_creation"] = get_tree().paused
	late_ui["physics_at_creation"] = Engine.is_in_physics_frame()
	late_ui["old_ui_count"] = source._save_barrier._saved_ui.size()
	source.level._introduce_sun(source)
	if not source.mission.actions.has("zhu_rts_inside"): return
	var action: Dictionary = source.mission.actions.zhu_rts_inside
	var originals: Array = []
	for button: Button in [action.button, action.actor_button]:
		originals.append({"node": button, "blocked": button.is_blocking_signals(), "mode": button.process_mode})
	late_ui["originals"] = originals
	late_ui["created"] = true

func _late_ui_state() -> Dictionary:
	var mission: Variant = source.mission
	return {"selection": source.selection.duplicate(), "camera": source.camera.position,
		"events": mission.events.duplicate(true), "active": mission.active_action_id,
		"actor": mission._actor, "progress": mission._progress, "retry": mission._retry,
		"commands": mission._stage_commands, "stage": mission.stage_id, "status": mission._status.text,
		"done": mission.actions.zhu_rts_inside.done}

func late_ui_capture_regression() -> void:
	# Run after the main fixture is closed and round-tripped. This controlled
	# production callback cannot change the cross-process scenery fixture.
	if not check("B01", "late UI fixture has not introduced Sun naturally", not source.level.sent_sun and not source.mission.actions.has("zhu_rts_inside")): return
	if not check("B01", "late UI regression releases previous capture", source._save_barrier.release_capture().ok): return
	held = false; rejected = ""; late_ui.clear()
	if not check("B01", "late UI regression requests a fresh production capture", source._save_barrier.request_capture().ok): return
	get_tree().process_frame.connect(_queue_late_ui, CONNECT_ONE_SHOT)
	for _i in range(180):
		await get_tree().process_frame
		if held or rejected != "": break
	if not check("B01", "controlled real task callback ran in paused deferred DRAINING", late_ui.get("created", false) and late_ui.get("state_at_creation", -1) == source._save_barrier.State.DRAINING and late_ui.get("paused_at_creation", false) and not late_ui.get("physics_at_creation", true)):
		print("LATE_UI_BOUNDARY ", late_ui); return
	if not check("B01", "capture holds after late task controls are created", held and rejected == "" and source._save_barrier.health().ok): print("LATE_UI_HEALTH ", rejected, " ", source._save_barrier.health()); return
	check("B01", "late callback created actual Sun action and actor locator", is_instance_valid(source.level.sun) and source.level.sun.key == "sun_li" and late_ui.originals.size() == 2)
	for original: Dictionary in late_ui.originals:
		var matching: Array = source._save_barrier._saved_ui.filter(func(row): return row.node == original.node)
		check("B01", "new control registered once with its original flags", matching.size() == 1 and matching[0].blocked == original.blocked and matching[0].mode == original.mode)
		check("B01", "new control gated while HELD", original.node.is_blocking_signals() and original.node.process_mode == Node.PROCESS_MODE_DISABLED)
	var before: Dictionary = _late_ui_state()
	for original: Dictionary in late_ui.originals: original.node.pressed.emit()
	check("B01", "HELD direct presses cannot change selection camera or mission", _late_ui_state() == before)
	var probe: Button = late_ui.originals[0].node
	probe.set_block_signals(false)
	check("B01", "health refuses one late control signal gate being opened", not source._save_barrier.health().ok)
	probe.set_block_signals(true)
	check("B01", "health recovers when signal gate restored", source._save_barrier.health().ok)
	probe.process_mode = Node.PROCESS_MODE_INHERIT
	check("B01", "health refuses one late control process gate being opened", not source._save_barrier.health().ok)
	probe.process_mode = Node.PROCESS_MODE_DISABLED
	check("B01", "health recovers when process gate restored", source._save_barrier.health().ok)
	if not check("B01", "late UI capture releases normally", source._save_barrier.release_capture().ok): return
	for original: Dictionary in late_ui.originals:
		check("B01", "release restores exact late control original flags", original.node.is_blocking_signals() == original.blocked and original.node.process_mode == original.mode)
	var action: Dictionary = source.mission.actions.zhu_rts_inside
	action.button.pressed.emit()
	check("B01", "released action locator really moves the camera", source.camera.position == source.to_screen(source.map.cell_to_world(action.cell)))
	action.actor_button.pressed.emit()
	check("B01", "released actor locator really selects Sun", source.selection == [source.level.sun] and source.mission.active_action_id == before.active and not action.done)
	details["late_ui_regression"] = {"controlled_real_level_callback": "Level3._introduce_sun", "natural_task_progression": false,
		"trigger": "process_frame then call_deferred during DRAINING", "new_buttons": late_ui.originals.size(),
		"original_flags": late_ui.originals.map(func(row): return {"blocked": row.blocked, "mode": row.mode}),
		"main_fixture_written_before_trigger": true}

func start_source() -> bool:
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	check("S02", "normal menu keeps unreleased continue entry hidden", menu.find_child("ContinueBattle", true, false) == null)
	var campaign: Node = get_node("/root/Campaign")
	for key: String in Profiles.ZHU_FLAGS: campaign.set(key, Profiles.ZHU_FLAGS[key])
	campaign.ai_friendly = false
	menu._launch()
	for _i in range(180):
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene.get_script() == B: break
	source = get_tree().current_scene
	if not check("S02", "normal menu launched exact Battle and installed Level3", source != null and source.get_script() == B and source.level.get_script() == Profiles.level_script(Profiles.ZHU_ID)): return false
	source.hud._intro_root.hide(); source.hud.intro_done.emit()
	if source.phase == B.Phase.DEPLOY: source.hud.start_battle.emit()
	for _i in range(12): await get_tree().physics_frame
	await get_tree().process_frame
	if not check("S02", "actual chapter is fighting without RNG failure", source.phase == B.Phase.FIGHT and source.mission != null and source.gameplay_rng_fault().is_empty()): return false
	check("S02", "normal Battle resolved current installed content", source._gameplay_content_identity.content_version == trusted.content_version)
	check("S02", "default production barrier still refuses chapter", not source._save_barrier.request_capture().ok)
	for context: Dictionary in [{"mode": "campaign", "level_id": "level8", "waves": 0}, {"mode": "custom", "level_id": "level3", "waves": 0}]:
		source._save_barrier.configure(source, source._run_clock, context)
		check("N02", "unsupported explicit barrier context refused " + str(context), not source._save_barrier.request_capture().ok)
	source._save_barrier.configure(source, source._run_clock, Profiles.ZHU_CONTEXT)
	var original_level: Variant = source.level; source.level = Classic.new()
	check("N03", "production chapter barrier rejects changed Level script", not source._save_barrier.request_capture().ok)
	source.level = original_level
	var original_mission: Variant = source.mission; source.mission = null
	check("N03", "production chapter barrier rejects missing Mission", not source._save_barrier.request_capture().ok)
	source.mission = original_mission
	var original_context: Dictionary = source._official_context.duplicate(); source._official_context = Profiles.CLASSIC_CONTEXT.duplicate()
	check("N03", "production chapter barrier rejects changed official context", not source._save_barrier.request_capture().ok)
	source._official_context = original_context
	source._save_barrier.capture_ready.connect(_on_held)
	source._save_barrier.capture_rejected.connect(_on_rejected)
	if not check("S02", "explicit trusted production barrier accepts chapter request", source._save_barrier.request_capture().ok): return false
	for _i in range(180):
		await get_tree().process_frame
		if held or rejected != "": break
	if not check("S02", "production drain reaches real HELD boundary", held and rejected == "" and source._save_barrier.state == source._save_barrier.State.HELD and source._save_barrier.health().ok):
		print("BARRIER ", rejected, " ", source._save_barrier.health()); return false
	return true

func object_registry(owner: Variant) -> Dictionary:
	var result := {}
	for unit: Node in owner.units_root.get_children(true): result[unit] = str(unit.entity_id)
	return result

func live_inventory(owner: Variant) -> Dictionary:
	var visual: Variant = owner.map.sample_scenery
	var kinds := {}; var labels: Array = []; var nodes: Array = []; var arrays := {}
	for node: Node in [visual] + visual.get_children(true):
		var kind: String = scenery_state()._kind(node)
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		if kind == "story_sign": labels.append(node.label)
		nodes.append({"kind": kind, "index": node.get_index(), "parent_index": -1 if node == visual else 0, "route": str(node.get_meta("campaign_environment_route", ""))})
	for field: String in ["_sprites", "_trees", "_walls"]:
		var entries: Array = []
		for node: Node in visual.get(field): entries.append(node.get_index())
		arrays[field] = entries
	return {"kinds": kinds, "labels": labels, "nodes": nodes, "owner_arrays": arrays, "wall_segments": codec.encode(owner.map.get_meta("campaign_wall_segments")).value}

func overlay_branch(owner: Variant, inventory: Dictionary) -> Dictionary:
	# The installed config declares anchors even when their source images have
	# not shipped. The real factory then skips the node; zero is a valid branch.
	var configured: Array = []; var available: Array = []; var actual: Array = []
	for decor: Array in owner.map.decor:
		if decor.size() < 4 or decor[0] != EnvironmentConfig.SCOPED_OVERLAY_MARKER: continue
		var route: String = decor[3]
		var path: String = EnvironmentArt.route_path("overlay", "level3", route)
		var texture: Texture2D = EnvironmentArt.overlay("level3", route)
		configured.append({"route": route, "path": path, "resource_exists": not path.is_empty() and ResourceLoader.exists(path), "texture_resolved": texture != null})
		if texture != null: available.append(route)
	for node: Dictionary in inventory.nodes:
		if node.kind == "ground_overlay": actual.append(node.route)
	return {"configured": configured, "available_routes": available, "actual_routes": actual,
		"observed_nodes": actual.size(), "nonempty_overlay_branch_exercised": not actual.is_empty()}

func nonzero_state() -> bool:
	var visual: Variant = source.map.sample_scenery
	if not check("S06", "real source has mutable wall and canopy fixtures", visual != null and not visual._walls.is_empty() and not visual._trees.is_empty()): return false
	# Controlled native state fixture: preserve authored geometry/resources while
	# exercising non-default mutable display values at the held boundary.
	visual._visibility_tick = 0.037
	visual._walls[0].modulate.a = 0.45
	visual._trees[0].modulate.a = 0.40
	check("S06", "nonzero visibility timer and faded wall/canopy fixture installed", visual._visibility_tick == 0.037 and is_equal_approx(visual._walls[0].modulate.a, 0.45) and is_equal_approx(visual._trees[0].modulate.a, 0.40))
	details["dynamic_fixture"] = {"controlled_display_value_injection": true, "natural_overlap_trigger_tested": false, "visibility_tick": 0.037, "wall_alpha": 0.45, "tree_alpha": 0.40}
	return true

func capture_source() -> Dictionary:
	var version: String = trusted.content_version
	var maps: Dictionary = map_state().capture(source.map)
	if not check("S02", "real Level3 Map/Scenery capture", maps.ok): print(maps); diagnostics(source.map); return {}
	var units: Dictionary = graph().capture(source, object_registry(source), version, null, {"mission_token": TOKEN, "deferred_drained": true})
	if not check("S03", "real UnitGraph and Level references captured", units.ok): print(units); return {}
	var fog: Dictionary = fog_state().capture(source, {"quiescent": true})
	var camera: Dictionary = CameraState.new().capture(source)
	var rng: Dictionary = source.capture_gameplay_rng()
	var success := check("S03", "source real fog pixels, camera and RNG captured", fog.ok and camera.ok and rng.ok)
	if not success: print(fog, " ", camera, " ", rng); units.identity.dispose(); return {}
	var values := {}
	for field: String in BATTLE_FIELDS: values[field] = source.get(field)
	var result := {"schema": "level3_scenery_qa_fixture_v1", "producer_pid": OS.get_process_id(), "synthetic_fixture": true,
		"content_version": version, "engine_sha256": trusted.engine_binary_sha256, "map": maps.value, "units": units.value, "level": units.level_record,
		"fog": fog.record, "camera": camera.value, "rng": rng.record, "battle_values": codec.encode(values).value}
	units.identity.dispose()
	details["source_inventory"] = live_inventory(source)
	var inventory: Dictionary = details.source_inventory
	check("S02", "actual three source-language signs", inventory.labels == ["李家庄", "扈家庄", "祝家庄"])
	var overlays: Dictionary = overlay_branch(source, inventory)
	details["ground_overlay_branch"] = overlays
	result["ground_overlay_branch"] = overlays.duplicate(true)
	check("S02", "ground overlay nodes match actually loadable installed routes", overlays.actual_routes == overlays.available_routes and int(inventory.kinds.get("ground_overlay", 0)) == overlays.observed_nodes)
	check("S02", "map has exactly three installed wall segments", source.map.get_meta("campaign_wall_segments") == SceneryState.LEVEL3_WALLS)
	var expected_panels := 0
	for segment: Array in SceneryState.LEVEL3_WALLS:
		var span: Vector2 = source.map.project((segment[1] + Vector2(0.5, 0.5)) * 32.0) - source.map.project((segment[0] + Vector2(0.5, 0.5)) * 32.0)
		expected_panels += Stockade.panel_count(span, 52.0)
	check("S02", "three segments produced exact stockade panel count", source.map.sample_scenery._walls.size() == expected_panels)
	check("S08", "actual installed height retained as observed", source.map.height_field == null or source.map.height_field.get_script() == preload("res://scripts/campaign_height.gd"))
	return result

func diagnostics(game_map: M) -> void:
	if game_map.sample_scenery == null: return
	var module: RefCounted = scenery_state()
	for node: Node in [game_map.sample_scenery] + game_map.sample_scenery.get_children(true):
		var kind: String = module._kind(node)
		var status: Dictionary = module._campaign_node_boundary(node, kind)
		if status.ok: continue
		var signals: Array = []
		for info: Dictionary in node.get_signal_list():
			for connection: Dictionary in node.get_signal_connection_list(info.name): signals.append(str(connection))
		print("SCENERY_BOUNDARY ", kind, " index=", node.get_index(), " ", status, " outgoing=", signals, " incoming=", node.get_incoming_connections(), " metadata=", node.get_meta_list())

func prepare_target(saved: Dictionary) -> Dictionary:
	var owner := B.new(); owner.process_mode = Node.PROCESS_MODE_DISABLED; owner.set_block_signals(true)
	owner._cursor_resources_released = true
	owner.world = Node2D.new(); owner.world.transform = M.ISO; owner.add_child(owner.world)
	owner.map = M.new(); owner.world.add_child(owner.map)
	var entry := {"owner": owner, "identity": null, "adapter": null, "camera": null, "fog": null, "fog_plan": {}}
	targets.append(entry)
	var maps: RefCounted = map_state()
	var staged: Dictionary = maps.stage_map_values(owner.map, saved.map)
	if not staged.ok: return {"ok": false, "entry": entry, "stage": "map", "failure": staged}
	var runtime: Dictionary = Factory.prepare_runtime(trusted)
	if not runtime.ok: return {"ok": false, "entry": entry, "stage": "runtime", "failure": runtime}
	owner._defs = runtime.runtime.defs; owner._abilities = runtime.runtime.abilities; owner._items = runtime.runtime.items
	owner._official_context = Profiles.ZHU_CONTEXT.duplicate(); owner.phase = B.Phase.FIGHT; owner.economy = true
	var decoded: Dictionary = codec.decode(saved.battle_values)
	if not decoded.ok: return {"ok": false, "entry": entry, "stage": "battle_values", "failure": decoded}
	for field: String in BATTLE_FIELDS: owner.set(field, decoded.value[field])
	var units: Dictionary = graph().prepare(saved.units, trusted.content_version, owner, owner.map, saved.level, TOKEN)
	if not units.ok: return {"ok": false, "entry": entry, "stage": "units", "failure": units}
	entry.identity = units.identity
	owner.units_root = Node2D.new(); owner.world.add_child(owner.units_root)
	for unit: Node in units.units_in_root_order: owner.units_root.add_child(unit)
	owner.units.assign(units.active_units); owner.next_entity_id = units.pending_battle_fields.next_entity_id
	var level: Dictionary = LevelState.new().restore(saved.level, "level3", trusted.content_version, units.id_to_unit, owner.next_entity_id, {}, TOKEN)
	if not level.ok: return {"ok": false, "entry": entry, "stage": "level", "failure": level}
	owner.level = level.level
	var rng: Dictionary = owner.configure_restored_gameplay_rng(trusted, saved.rng)
	if not rng.ok: return {"ok": false, "entry": entry, "stage": "rng", "failure": rng}
	entry.fog = fog_state(); entry.fog_plan = entry.fog.bind(owner, saved.fog)
	if not entry.fog_plan.ok: return {"ok": false, "entry": entry, "stage": "fog", "failure": entry.fog_plan}
	if entry.fog_plan.layer != null: owner.world.add_child(entry.fog_plan.layer)
	entry.camera = CameraState.new()
	var camera: Dictionary = entry.camera.bind(owner, saved.camera)
	if not camera.ok: return {"ok": false, "entry": entry, "stage": "camera", "failure": camera}
	var guard_before: Dictionary = scenery_state()._campaign_gameplay_guard(owner.map)
	var display: Dictionary = maps.finish_display(owner.map, saved.map)
	if not display.ok: return {"ok": false, "entry": entry, "stage": "display", "failure": display}
	entry.adapter = display.display_adapter
	var guard_after: Dictionary = entry.adapter._campaign_gameplay_guard(owner.map)
	check("S03", "fixed display factory preserves map/nav/height/resources/RNG", guard_before.ok and guard_before == guard_after)
	check("N18", "Map completion explicitly retains pending scenery adapter", not display.complete and display.display_requires_activation and entry.adapter != null)
	check("S03", "target Level, unit count and RNG are restored without deployment", owner.level.get_script() == Profiles.level_script(Profiles.ZHU_ID) and owner.units.size() == saved.units.active_order.size() and owner.capture_gameplay_rng().record == saved.rng and owner.mission == null)
	owner.set_meta("_run_core_prepared", true) # Existing Battle shell guard only; no Core invoked.
	entry["guard"] = guard_after
	return {"ok": true, "entry": entry}

func dispose_entry(entry: Dictionary, label: String) -> void:
	var owner: Variant = entry.owner
	if not is_instance_valid(owner): return
	var signs: Array = []
	if owner.map.sample_scenery != null:
		for node: Node in owner.map.sample_scenery.get_children(true):
			if node.get_script() == Scenery.StorySign: signs.append(node)
	if entry.adapter != null: entry.adapter.dispose_campaign(); entry.adapter.dispose_campaign()
	var disconnected := true
	for connection: Dictionary in Localize.language_changed.get_connections():
		if connection.callable.get_object() in signs: disconnected = false
	check("N17", label + " owns no surviving sign language hooks", disconnected)
	if entry.adapter != null:
		check("N17", label + " own visual released and repeated dispose harmless", owner.map.sample_scenery == null and signs.all(func(n): return not is_instance_valid(n)))
	if entry.identity != null: entry.identity.dispose()
	if owner.is_inside_tree(): owner.get_parent().remove_child(owner)
	owner.free()
	check("N17", label + " private Battle released", not is_instance_valid(owner))

func successful_roundtrip(saved: Dictionary, prefix: String, screenshots := false) -> bool:
	var prepared: Dictionary = prepare_target(saved)
	if not check("S03", prefix + " target component preparation", prepared.ok): print(prepared); return false
	var entry: Dictionary = prepared.entry
	var owner: Variant = entry.owner
	check("N16", prefix + " detached activation refused", not entry.adapter.activate_campaign().ok)
	var initial: Dictionary = entry.adapter.capture(owner.map)
	check("S03", prefix + " detached exact scenery values", initial.ok and initial.value == saved.map.sections.display)
	get_tree().root.add_child(owner)
	if not check("S04", prefix + " prepared Battle mounts without normal initialization", owner.gameplay_rng_fault().is_empty() and owner.process_mode == Node.PROCESS_MODE_DISABLED and owner.is_blocking_signals() and owner._run_clock == null and owner._save_barrier == null): return false
	for _i in range(3): await get_tree().process_frame
	var held_record: Dictionary = entry.adapter.capture(owner.map)
	check("S04", prefix + " three paused process frames preserve every scenery value", held_record.ok and held_record.value == saved.map.sections.display)
	check("S04", prefix + " paused frames preserve map/nav/resources/RNG", entry.adapter._campaign_gameplay_guard(owner.map) == entry.guard)
	check("S04", prefix + " each real sign ready with exactly one language binding", sign_hooks(owner) == 3)
	get_tree().paused = false
	var unpaused: Dictionary = entry.adapter.activate_campaign()
	get_tree().paused = true
	check("N16", prefix + " unpaused activation refused synchronously", not unpaused.ok)
	var probe := PhysicsActivation.new(); probe.process_mode = Node.PROCESS_MODE_ALWAYS; probe.adapter = entry.adapter; add_child(probe)
	for _i in range(20):
		await get_tree().process_frame
		if not probe.result.is_empty(): break
	check("N16", prefix + " actual physics callback activation refused", probe.physics_seen and not probe.result.get("ok", true))
	probe.free()
	var activated: Dictionary = entry.adapter.activate_campaign()
	check("S04", prefix + " explicit scenery activation succeeds", activated.ok and not activated.get("complete_world", true))
	if not activated.ok: print(activated); diagnostics(owner.map); return false
	var final_map: Dictionary = map_state().capture(owner.map)
	check("S07", prefix + " full Map/nav/height/display recapture equals source", final_map.ok and final_map.value == saved.map)
	if final_map.ok and final_map.value != saved.map:
		for key: String in saved.map.sections:
			if saved.map.sections[key] != final_map.value.sections[key]: print("MAP_SECTION_DIFFERENCE ", key)
	check("S04", prefix + " activation changes no gameplay values", entry.adapter._campaign_gameplay_guard(owner.map) == entry.guard)
	check("N16", prefix + " duplicate activation refused", not entry.adapter.activate_campaign().ok)
	check("S06", prefix + " nonzero timer and fades retained", owner.map.sample_scenery._visibility_tick == 0.037 and is_equal_approx(owner.map.sample_scenery._walls[0].modulate.a, 0.45) and is_equal_approx(owner.map.sample_scenery._trees[0].modulate.a, 0.40))
	if screenshots:
		check("S05", prefix + " trusted camera explicitly activated", entry.camera.activate().ok)
		check("S05", prefix + " trusted fog layer explicitly activated", entry.fog.activate(owner, entry.fog_plan.activation).ok)
		if is_instance_valid(source): source.visible = false; source.hud.visible = false
		var fog_before: Dictionary = entry.fog.capture(owner, {"quiescent": true})
		check("S05", prefix + " restored fog available before rendering checks", fog_before.ok)
		await capture_images(owner, prefix)
		var localized: Dictionary = map_state().capture(owner.map)
		check("S05", prefix + " four languages preserve source-label records", localized.ok and localized.value == saved.map)
		var fog_after: Dictionary = entry.fog.capture(owner, {"quiescent": true})
		check("S05", prefix + " rendering probes restore exact fog state", fog_before.ok and fog_after == fog_before)
	dispose_entry(entry, prefix + " after activation")
	return true

func sign_hooks(owner: Variant) -> int:
	var count := 0
	for node: Node in owner.map.sample_scenery.get_children(true):
		if node.get_script() != Scenery.StorySign: continue
		for row: Dictionary in Localize.language_changed.get_connections():
			if row.callable == Callable(node, "_on_language_changed"): count += 1
	return count

func capture_images(owner: Variant, stem: String) -> void:
	var original: String = Localize.locale
	var folder := OS.get_environment("LSH_LEVEL3_SCENERY_SNAPSHOT").get_base_dir().path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(folder)
	var signs: Array = []
	for node: Node in owner.map.sample_scenery.get_children(true):
		if node.get_script() == Scenery.StorySign: signs.append(node)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var panorama := folder.path_join(stem + "_unaltered_restored_view.png")
	var panorama_saved: bool = get_viewport().get_texture().get_image().save_png(panorama) == OK
	check("S05", stem + " unaltered restored view screenshot saved", panorama_saved)
	images.append({"file": panorama.get_file(), "kind": "unaltered_restored_view", "presentation_only_override": false, "saved": panorama_saved, "human_reviewed": false})
	# The real initial view does not reveal all three sign locations. These
	# explicitly labelled drawing samples temporarily expose the sign only;
	# restore the original visibility and fog layer before recapturing state.
	var fog_visible: bool = owner._fog_layer.visible if owner._fog_layer != null else false
	if owner._fog_layer != null: owner._fog_layer.hide()
	for language: String in ["zh_CN", "zh_TW", "en", "ja"]:
		Localize.set_language(language, false)
		for index: int in range(signs.size()):
			var was_visible: bool = signs[index].visible
			signs[index].show()
			owner.camera.position = owner.map.project(signs[index].position); owner.camera.zoom = Vector2.ONE * 1.1; owner.camera.force_update_scroll()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var path := folder.path_join(stem + "_" + language + "_sign" + str(index + 1) + ".png")
			var success: bool = get_viewport().get_texture().get_image().save_png(path) == OK
			check("S05", "screenshot saved " + language + " sign " + str(index + 1), success)
			images.append({"file": path.get_file(), "kind": "controlled_localization_drawing", "language": language, "source_label": signs[index].label, "presentation_only_override": true, "normal_visibility_acceptance": false, "saved": success, "human_reviewed": false})
			signs[index].visible = was_visible
	if owner._fog_layer != null: owner._fog_layer.visible = fog_visible
	Localize.set_language(original, false)
	details["screenshot_scope"] = "One untouched restored view per process; sign drawing samples temporarily show that sign and hide only the fog drawing layer. Map/Fog recapture after restoration is checked; no normal visibility or human approval claim."

func changed_node(saved: Dictionary, kind: String, section: String, field: String, value: Variant) -> Dictionary:
	var result: Dictionary = saved.duplicate(true)
	for index: int in range(result.map.sections.display.nodes.size()):
		var row: Dictionary = codec.decode(result.map.sections.display.nodes[index]).value
		if row.kind != kind: continue
		row[section][field] = value
		result.map.sections.display.nodes[index] = codec.encode(row).value
		break
	return result

func reject_prepare(saved: Dictionary, label: String) -> void:
	var prepared: Dictionary = prepare_target(saved)
	check("N05", label + " failed before delivery", not prepared.ok)
	if not prepared.ok: print("EXPECTED_REJECTION ", label, " ", prepared.stage, " ", prepared.failure)
	check("N17", label + " no private scenery remains after rejected factory", prepared.entry.owner.map.sample_scenery == null)
	dispose_entry(prepared.entry, label)

func negatives(saved: Dictionary) -> void:
	var display: Dictionary = saved.map.sections.display
	check("N01", "default classic adapter refuses chapter envelope", not SceneryState.new(trusted.content_version).validate(display).ok)
	check("N02", "unsupported chapter adapter refuses envelope", not SceneryState.new(trusted.content_version, {"mode": "campaign", "level_id": "level1", "waves": 0}).validate(display).ok)
	check("N08", "wrong installed content version refused", not SceneryState.new("wrong-content", Profiles.ZHU_CONTEXT).validate(display).ok)
	var corrupt: Dictionary = saved.duplicate(true); corrupt.map.content_version = "wrong"
	reject_prepare(corrupt, "wrong map content")
	corrupt = saved.duplicate(true); corrupt.map.sections.display.nodes.remove_at(1)
	reject_prepare(corrupt, "deleted fixed scenery node")
	reject_prepare(changed_node(saved, "story_sign", "fixed", "label", "English replacement"), "translated sign substituted for source label")
	var visual: Variant = source.map.sample_scenery
	var unknown := Node2D.new(); visual.add_child(unknown)
	check("N05", "unknown actual source object refused", not scenery_state().capture(source.map).ok)
	visual.remove_child(unknown); unknown.free()
	var walls: Variant = source.map.get_meta("campaign_wall_segments")
	source.map.set_meta("campaign_wall_segments", [[Vector2.ZERO, Vector2.ONE]])
	check("N04", "changed installed wall segments refused", not scenery_state().capture(source.map).ok)
	source.map.set_meta("campaign_wall_segments", walls)
	var metadata_before: Dictionary = {}
	for key: StringName in source.map.get_meta_list(): metadata_before[key] = source.map.get_meta(key)
	source.map.remove_meta("campaign_wall_segments")
	var missing_walls: Dictionary = scenery_state().capture(source.map)
	check("N04", "missing installed wall metadata returns controlled rejection", not missing_walls.ok and missing_walls.get("code", "") == "LEVEL3_MAP_IDENTITY")
	# The codec preserves dictionary entry order. Reinserting only the removed
	# key would move it after natural_surface_contract and alter the wire record.
	for key: StringName in source.map.get_meta_list(): source.map.remove_meta(key)
	for key: StringName in metadata_before: source.map.set_meta(key, metadata_before[key])
	var sign: Node2D
	for node: Node in visual.get_children(true):
		if node.get_script() == Scenery.StorySign: sign = node; break
	var callback := func() -> void: pass
	sign.visibility_changed.connect(callback)
	check("N09", "foreign live signal callback refused", not scenery_state().capture(source.map).ok)
	sign.visibility_changed.disconnect(callback)
	sign.add_to_group("unsupported_scenery_qa")
	check("N10", "unexpected live group refused", not scenery_state().capture(source.map).ok)
	sign.remove_from_group("unsupported_scenery_qa")
	var source_again: Dictionary = map_state().capture(source.map)
	check("N17", "source remains byte-exact after fault probes", source_again.ok and source_again.value == saved.map)
	for mutation: String in ["runtime", "topology", "gate"]:
		var prepared: Dictionary = prepare_target(saved)
		if not check("N14", "fault fixture prepares " + mutation, prepared.ok): print(prepared); continue
		var entry: Dictionary = prepared.entry
		get_tree().root.add_child(entry.owner)
		for _i in range(3): await get_tree().process_frame
		var root_visual: Variant = entry.owner.map.sample_scenery
		if mutation == "runtime": root_visual._visibility_tick += 0.01
		elif mutation == "topology": root_visual.add_child(Node2D.new())
		else: root_visual.set_block_signals(false)
		check("N14" if mutation == "runtime" else "N15", "prepared alteration refuses activation " + mutation, not entry.adapter.activate_campaign().ok)
		dispose_entry(entry, "mounted failure " + mutation)
	var private_only: Dictionary = prepare_target(saved)
	if check("N17", "detached cleanup fixture prepares", private_only.ok): dispose_entry(private_only.entry, "before mounting")

func write_fixture(saved: Dictionary) -> void:
	var file := FileAccess.open(OS.get_environment("LSH_LEVEL3_SCENERY_SNAPSHOT"), FileAccess.WRITE)
	check("S09", "synthetic component fixture file opened", file != null)
	if file != null: file.store_string(JSON.stringify(saved)); file.close()

func run() -> void:
	phase = OS.get_environment("LSH_LEVEL3_SCENERY_PHASE")
	Settings.game_speed = 1.0; AudioServer.set_bus_mute(0, true)
	trusted = Provider.new().resolve_runtime_identity()
	if not check("S02", "installed content and engine identity are save eligible", trusted.get("ok", false) and trusted.get("save_eligible", false)): print(trusted); finish(); return
	var saved: Dictionary = {}
	if phase == "component":
		var started: bool = await start_source()
		if not started: finish(); return
		if not nonzero_state(): finish(); return
		saved = capture_source()
		if saved.is_empty(): finish(); return
		write_fixture(saved)
		await negatives(saved)
		await successful_roundtrip(saved, "component", true)
		await late_ui_capture_regression()
	else:
		get_tree().paused = true
		# Startup call_deferred may still execute in a physics drain. A paused
		# flag alone is not the idle installation boundary required by Fog.bind.
		await get_tree().process_frame
		if not check("S09", "restart preparation begins paused outside physics", get_tree().paused and not Engine.is_in_physics_frame()): finish(); return
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("LSH_LEVEL3_SCENERY_SNAPSHOT")))
		if not check("S09", "restart fixture is scalar document from other native process", typeof(value) == TYPE_DICTIONARY and typeof(value.get("producer_pid")) in [TYPE_INT, TYPE_FLOAT] and int(value.producer_pid) != OS.get_process_id()): finish(); return
		saved = value
		details["ground_overlay_branch"] = saved.get("ground_overlay_branch", {}).duplicate(true)
		var selected: Dictionary = Profiles.select_saved(Profiles.ZHU_CONTEXT, saved.content_version, saved.engine_sha256, trusted)
		if not check("S09", "restart uses same current installed content and engine", selected.ok): finish(); return
		await successful_roundtrip(saved, "restart", true)
	finish()

func finish() -> void:
	for entry: Dictionary in targets:
		if is_instance_valid(entry.owner): dispose_entry(entry, "final cleanup")
	if is_instance_valid(source):
		source.visible = true
		if is_instance_valid(source.hud): source.hud.visible = true
	var path := OS.get_environment("LSH_LEVEL3_SCENERY_SNAPSHOT")
	var snapshot_sha := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	var producer := 0
	if FileAccess.file_exists(path):
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(value) == TYPE_DICTIONARY and typeof(value.get("producer_pid")) in [TYPE_INT, TYPE_FLOAT]: producer = int(value.producer_pid)
	var passed: bool = not checks.is_empty() and checks.all(func(row): return row.passed)
	var report := {"passed": passed, "phase": phase, "checks": checks, "pid": OS.get_process_id(), "snapshot_sha256": snapshot_sha, "snapshot_producer_pid": producer,
		"component_only": true, "full_world": false, "real_steam": false, "screenshots": images, "human_visual_review": false, "details": details,
		"matrix_scope": "Only listed executed assertions; no blanket PASS for the 28-row proposal.",
		"not_executed": ["S01 full classic regression", "S08 separate flat-height profile", "N07 all other chapter node kinds", "N12 injected factory gameplay mutations", "N19 full classic negative matrix", "natural gameplay overlap trigger for S06", "manual visual review", "complete chapter/world resume"]}
	if not details.get("ground_overlay_branch", {}).get("nonempty_overlay_branch_exercised", false):
		report.not_executed.append("GroundOverlay nonempty branch: current installed overlay textures are unavailable, so no overlay nodes exist or are restored")
	var file := FileAccess.open(OS.get_environment("LSH_LEVEL3_SCENERY_REPORT"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
	print("LEVEL3_SCENERY_QA ", phase, " checks=", checks.size(), " passed=", passed)
	get_node("/root/Sfx").shutdown(); get_node("/root/Music").shutdown()
	get_tree().quit(0 if passed and file != null else 1)
