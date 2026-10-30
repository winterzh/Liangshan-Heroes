extends Node
## Command driver only. All gameplay, Unit, map, clock and serializers are the
## actual installed resources; no substitutes or injected content identities.
var checks: Array = []
var failures: Array = []
var orders := 0
var trusted: Dictionary = {}
var execution_kind := "unresolved"
var root: Window:
	get: return get_tree().root
var current_scene: Node:
	get: return get_tree().current_scene
	set(value): get_tree().current_scene = value

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var profile := OS.get_environment("ART_QA_PROFILE").replace("\\", "/").simplify_path()
	var safe: bool = profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		safe = safe and OS.get_environment(key).replace("\\", "/").simplify_path().to_lower() == (profile + "/" + key.to_lower()).to_lower()
	if not safe or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("CAMPAIGN_QA") != "1":
		push_error("HG_FOUR_PRIVATE_ROOTS_REQUIRED"); quit(2); return
	_run.call_deferred()

func _run() -> void:
	push_error("HG_WORKER_NOT_IMPLEMENTED"); quit(2)

func quit(code := 0) -> void:
	get_tree().quit(code)

func check(ok: bool, label: String) -> void:
	checks.append({"label": label, "passed": ok})
	if not ok: failures.append(label)
	print("HG ", "PASS " if ok else "FAIL ", label)

func alive(unit: Variant) -> bool:
	return is_instance_valid(unit) and unit.hp > 0.0 and unit.story_outcome == ""

func identity(expected_source_mode := true) -> bool:
	execution_kind = "source_project" if expected_source_mode else OS.get_environment("HG_EXECUTION_KIND")
	trusted = load("res://scripts/run_content_identity.gd").new().resolve_runtime_identity()
	check(trusted.get("ok", false) and trusted.get("save_eligible", false) and trusted.get("source_mode", not expected_source_mode) == expected_source_mode,
		"real executed identity resolves in requested source/package mode")
	if not trusted.get("ok", false):
		print("IDENTITY ", trusted); return false
	if not expected_source_mode:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("HG_EXPECTED_IDENTITY")))
		var script: Script = load("res://scripts/run_build_identity.gd")
		var actual: Dictionary = script.get_script_constant_map().IDENTITY
		check(not script.has_source_code(), "build identity is actual exported bytecode")
		check(JSON.parse_string(JSON.stringify(actual)) == expected, "full compiled input manifest matches frozen exporter output")
		check(trusted.content_version == "source-v1:" + expected.source_sha256, "Provider uses actual exported source identity")
		check(trusted.engine_binary_sha256 == OS.get_environment("HG_EXPECTED_EXE_SHA"), "executed compiled-PCK loader matches its pinned original editor binary")
		check(execution_kind == "compiled_pck_editor_loader" and OS.has_feature("editor"),
			"explicit compiled_pck_editor_loader executes actual exported bytecode on the editor engine")
	return failures.is_empty()

func _start(mode := "", index := 0) -> Node:
	var campaign: Variant = root.get_node("Campaign")
	campaign.current = index
	for key in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(key, false)
	if mode != "": campaign.set(mode, true)
	root.get_node("Settings").auto_micro_level = 0
	seed(5088120)
	var battle: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle); current_scene = battle
	await get_tree().process_frame
	if await _show_start_intro(battle):
		# A display audit can consume the real intro buttons exactly once.
		# Its final button emits intro_done and makes the normal start UI visible.
		if battle.phase == battle.Phase.DEPLOY:
			battle.hud.start_btn.pressed.emit()
	else:
		battle.hud._intro_root.hide()
		battle._on_intro_done()
		battle._on_start_battle()
	return battle

func _show_start_intro(_battle: Variant) -> bool:
	return false

func _dispose(battle: Node) -> void:
	battle.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _click(battle: Variant, units: Array, cell: Vector2i, amove := false) -> void:
	battle.select_members(units, false)
	battle.minimap_order(battle.map.cell_to_world(cell), amove)
	orders += 1

func _action(battle: Variant, unit: Variant, action_id: String) -> void:
	if not alive(unit) or not battle.mission.actions.has(action_id): return
	if battle.mission.actions[action_id].done or battle.mission.active_action_id == action_id: return
	_click(battle, [unit], battle.mission.actions[action_id].cell)

func report(extra: Dictionary = {}) -> void:
	var value := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"orders": orders, "trusted_identity": trusted, "pid": OS.get_process_id(),
		"native_steam_account_tested": false, "ordinary_player_continue_entry_tested": false, "simulation_time_scale": Engine.time_scale}
	value.merge(extra, true)
	# External workers qualify source or compiled PCK behavior. The original
	# release template has a separate normal-startup receipt and no worker hook.
	value["execution_kind"] = execution_kind
	value["native_release_tested"] = false
	var file := FileAccess.open(OS.get_environment("HG_REPORT"), FileAccess.WRITE)
	if file == null:
		push_error("HG_REPORT_UNWRITABLE"); quit(2); return
	file.store_string(JSON.stringify(value, "\t")); file.close()
	quit(0 if value.passed else 1)

func dump_fixture_slot(slot_name: String, destination: String) -> Array:
	# Only this task's explicit fixture slot, after a successful complete commit.
	if slot_name not in ["hg_legacy3", "hg_transport_world"] or not destination.is_absolute_path(): return []
	var output_root := OS.get_environment("HG_OUTPUT_ROOT").replace("\\", "/").simplify_path()
	var resolved_destination := destination.replace("\\", "/").simplify_path()
	if not output_root.is_absolute_path() or not resolved_destination.to_lower().begins_with(output_root.to_lower() + "/"): return []
	if DirAccess.dir_exists_absolute(resolved_destination) or FileAccess.file_exists(resolved_destination): return []
	var source := OS.get_user_data_dir().path_join(slot_name)
	var profile := OS.get_environment("ART_QA_PROFILE").replace("\\", "/").simplify_path()
	if not source.replace("\\", "/").to_lower().begins_with(profile.to_lower() + "/"): return []
	var pending: Array[String] = [""]
	var copied: Array = []
	while not pending.is_empty():
		var relative: String = pending.pop_back()
		var directory := DirAccess.open(source.path_join(relative))
		if directory == null: return []
		for name in directory.get_directories():
			if name == "writing" or name == "recovering": return []
			pending.append(relative.path_join(name))
		for name in directory.get_files():
			if name.get_extension() != "json": return []
			var item := relative.path_join(name)
			var target := destination.path_join(item)
			if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK: return []
			var data := FileAccess.get_file_as_bytes(source.path_join(item))
			var file := FileAccess.open(target, FileAccess.WRITE)
			if file == null: return []
			file.store_buffer(data); file.close()
			var before := FileAccess.get_sha256(source.path_join(item))
			var after := FileAccess.get_sha256(target)
			if before != after: return []
			copied.append({"path": item, "bytes": data.size(), "sha256": before})
	return copied

var checkpoint: Dictionary = {}
var empty_checkpoint: Dictionary = {}
var hold_ready := false
var hold_error := ""

func saved_cart_bindings(world: Dictionary, battle: Variant, label: String) -> Dictionary:
	# JujubeCart is Node2D, not Unit. Its persisted identity is the actual
	# Level/Visual external token; OS instance IDs are never a restart identity.
	var codec: Variant = load("res://scripts/run_state_value_codec.gd").new()
	var level_record: Dictionary = codec.decode(world.sections.level.payload)
	var visual_record: Dictionary = codec.decode(world.sections.visual.records)
	check(level_record.get("ok", false) and visual_record.get("ok", false), label + ": actual saved Level and Visual records decode")
	if not level_record.get("ok", false) or not visual_record.get("ok", false): return {}
	var persisted_tokens: Array = level_record.value.external.jujube_carts
	var canonical: Array = range(7).map(func(i): return "ext:level1:jujube_carts:%d" % i)
	check(persisted_tokens == canonical and battle.level.jujube_carts.size() == 7, label + ": saved Level binds all seven canonical cart tokens")
	if persisted_tokens != canonical or battle.level.jujube_carts.size() != 7: return {}
	var visual_carts: Dictionary = {}
	for row: Dictionary in visual_record.value:
		if row.kind != "hg_cart": continue
		var token: String = row.values.token
		check(not visual_carts.has(token), label + ": visual cart token is unique " + token)
		visual_carts[token] = row
	check(visual_carts.size() == 7, label + ": saved Visual graph contains exactly seven original cart props")
	var actual_tokens: Dictionary = load("res://scripts/run_level1_visual_state.gd").tokens(battle.level)
	var states: Array = []
	for i in range(7):
		var token: String = canonical[i]
		var cart: Variant = battle.level.jujube_carts[i]
		check(is_instance_valid(cart) and actual_tokens.get(cart, "") == token and visual_carts.has(token), label + ": actual cart object is bound to saved token " + token)
		if not is_instance_valid(cart) or not visual_carts.has(token): return {}
		var saved: Dictionary = visual_carts[token]
		var saved_position: Vector2 = saved.node.position
		check(cart.position.distance_to(saved_position) < 0.001 and cart.visible == saved.node.visible and int(cart.get_meta("jujube_cart_index", -1)) == i and saved.values.metadata.get("jujube_cart_index", -1) == i, label + ": token retains actual saved position, visibility and cart index " + token)
		states.append({"token": token, "position": [saved_position.x, saved_position.y], "visible": saved.node.visible, "cart_index": i})
	return {"cart_tokens": persisted_tokens.duplicate(), "cart_states": states}

func checkpoint_save(battle: Variant, label: String, freeze_copy := false) -> bool:
	var profiles: Script = load("res://scripts/run_official_restore_profile.gd")
	var runtime: Dictionary = load("res://scripts/run_level1_world_factory.gd").prepare_runtime(trusted)
	check(runtime.get("ok", false), label + ": real production runtime prepared")
	if not runtime.get("ok", false): print("RUNTIME ", runtime); return false
	check(battle._official_context == profiles.HG_CONTEXT and battle._steam_run_id == 0, label + ": actual uncredited Huangnigang context")
	if not failures.is_empty(): return false
	var was_paused: bool = get_tree().paused
	get_tree().paused = true
	battle._save_barrier.configure(battle, battle._run_clock, profiles.HG_CONTEXT)
	hold_ready = false; hold_error = ""
	battle._save_barrier.capture_ready.connect(func(_context): hold_ready = true, CONNECT_ONE_SHOT)
	battle._save_barrier.capture_rejected.connect(func(code): hold_error = String(code), CONNECT_ONE_SHOT)
	var requested: Dictionary = battle._save_barrier.request_capture()
	check(requested.get("ok", false), label + ": internal capture requested")
	if not requested.get("ok", false): print("REQUEST ", requested); return false
	for i in range(240):
		await get_tree().process_frame
		if hold_ready or hold_error != "": break
	check(hold_ready and hold_error == "" and battle._save_barrier.health().ok, label + ": real barrier drained and held")
	if not hold_ready or hold_error != "": print("HOLD ", hold_error, battle._save_barrier.health()); return false
	var session: Variant = load("res://scripts/run_world_session.gd").new(trusted, runtime.runtime, "user://hg_transport_world/v1")
	var saved: Dictionary = session.save_held(battle)
	check(saved.get("ok", false), label + ": complete world written by real Session")
	if not saved.get("ok", false): print("SAVE ", saved); return false
	var slot: Dictionary = load("res://scripts/run_slot_store.gd").new("user://hg_transport_world/v1").read_slot()
	check(slot.get("ok", false) and slot.document.world.profile.id == profiles.HG_ID, label + ": saved v2 slot independently reads")
	if not slot.get("ok", false): print("READ ", slot); return false
	var cart_bindings: Dictionary = saved_cart_bindings(slot.document.world, battle, label)
	if cart_bindings.is_empty(): return false
	var carried: Dictionary = {}
	var positions: Dictionary = {}
	for index in battle.level.cargo:
		carried[str(index)] = battle.level.cargo[index].entity_id
		var point: Vector2 = battle.level.cargo[index].position
		positions[str(index)] = [point.x, point.y]
	checkpoint = {"label": label, "saved_sha256": slot.file_sha256, "generation": slot.document.generation,
		"eleven_entity_ids": battle.level.bundles.map(func(u): return u.entity_id), "carried": carried,
		"positions": positions, "delivered_loads": battle.level.delivered, "stage": battle.level.st,
		"profile": slot.document.world.profile.id, "writer_pid": OS.get_process_id(),
		"content_version": trusted.content_version, "copied_fixture_files": [],
		"empty_carried": {}, "cart_tokens": cart_bindings.cart_tokens, "cart_states": cart_bindings.cart_states}
	for index in battle.level.empty_cargo: checkpoint.empty_carried[str(index)] = battle.level.empty_cargo[index].entity_id
	if freeze_copy:
		var copied := dump_fixture_slot("hg_transport_world", OS.get_environment("HG_EMPTY_COPY" if label == "seventh_empty_cart_in_transit" else "HG_CARRIED_COPY"))
		check(copied.size() >= 2, label + ": committed slot journal and lifecycle frozen before gameplay continues")
		checkpoint.copied_fixture_files = copied
	var released: Dictionary = battle._save_barrier.release_capture()
	check(released.get("ok", false), label + ": capture released")
	get_tree().paused = was_paused
	session.dispose()
	return failures.is_empty()

var producer_report: Dictionary = {}
var source_checkpoint: Dictionary = {}

func restore_checkpoint(kind := "loaded") -> Variant:
	producer_report = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("HG_COLD_EXPECTED")))
	source_checkpoint = producer_report.get("empty_checkpoint" if kind == "empty" else "checkpoint", {})
	var wanted_label: String = "seventh_empty_cart_in_transit" if kind == "empty" else "seventh_cart_in_transit"
	check(producer_report.get("passed", false) and source_checkpoint.get("label", "") == wanted_label, "producer passed natural wine route and retained requested in-transit checkpoint")
	check(int(producer_report.get("pid", 0)) > 0 and OS.get_process_id() != int(producer_report.get("pid", 0)), "consumer is an independent OS process")
	check(producer_report.get("trusted_identity", {}).get("content_version", "") == trusted.content_version, "consumer runs same real source or package identity")
	if not failures.is_empty(): return null
	var runtime: Dictionary = load("res://scripts/run_level1_world_factory.gd").prepare_runtime(trusted)
	check(runtime.get("ok", false), "cold actual production runtime prepares")
	if not runtime.get("ok", false): print("RUNTIME ", runtime); return null
	var store: Variant = load("res://scripts/run_slot_store.gd").new("user://hg_transport_world/v1")
	var slot: Dictionary = store.read_slot()
	check(slot.get("ok", false), "cold reader accepts writer slot without conversion")
	if not slot.get("ok", false): print("READ ", slot); return null
	check(slot.file_sha256 == source_checkpoint.saved_sha256, "cold slot bytes match frozen writer checkpoint")
	if not failures.is_empty(): return null
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu); current_scene = menu
	await get_tree().process_frame
	get_tree().paused = true
	var session: Variant = load("res://scripts/run_world_session.gd").new(trusted, runtime.runtime, "user://hg_transport_world/v1")
	var prepared: Dictionary = session.prepare_restore(menu)
	check(prepared.get("ok", false), "cold Session prepares actual in-transit world")
	if not prepared.get("ok", false): print("PREPARE ", prepared); session.dispose(); return null
	var committed: Dictionary = await session.commit_restore_async()
	check(committed.get("ok", false), "cold Session installs actual in-transit world")
	if not committed.get("ok", false): print("INSTALL ", committed); session.dispose(); return null
	var battle: Variant = committed.battle
	var level: Variant = battle.level
	var ids: Array = source_checkpoint.get("eleven_entity_ids", [])
	var integral: bool = ids.size() == 11 and ids.all(func(v): return typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)) and float(v) == floor(float(v)) and v > 0 and v < 2147483647)
	check(integral and ids.map(func(v): return str(int(v))) == level.bundles.map(func(u): return str(u.entity_id)), "cold world retains eleven exact original entity IDs")
	check(level.delivered == 0 and level.st == level.CARRY and get_tree().paused, "cold world restores zero delivered, paused carry stage")
	var actor_book: Dictionary = level.empty_cargo if kind == "empty" else level.cargo
	var expected_book: Dictionary = source_checkpoint.empty_carried if kind == "empty" else source_checkpoint.carried
	var meta_key: String = "pushing_empty_tribute" if kind == "empty" else "carrying_tribute"
	check(actor_book.size() == 7, "cold world restores seven distinct cart owners")
	for i in range(7):
		var actor: Variant = actor_book.get(i)
		var value: Variant = expected_book.get(str(i), null)
		var valid: bool = typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and value > 0 and value < 2147483647
		check(valid and is_instance_valid(actor) and actor.entity_id == int(value) and actor.get_meta(meta_key, -1) == i, "cold cart %d retains its exact carrier and metadata" % i)
	var restored_carts: Dictionary = saved_cart_bindings(slot.document.world, battle, "cold restored cart binding")
	check(not restored_carts.is_empty() and restored_carts.get("cart_tokens", []) == source_checkpoint.get("cart_tokens", []), "cold world retains writer's actual seven external cart tokens")
	var writer_states: Array = source_checkpoint.get("cart_states", [])
	check(writer_states.size() == 7, "writer retained all seven cart token states")
	if writer_states.size() == 7:
		for i in range(7):
			var state: Dictionary = writer_states[i]
			var cart: Variant = level.jujube_carts[i]
			var position: Vector2 = Vector2(float(state.position[0]), float(state.position[1]))
			check(state.token == "ext:level1:jujube_carts:%d" % i and cart.position.distance_to(position) < 0.001 and cart.visible == state.visible, "cold token %d retains writer position and visibility" % i)
	if kind == "empty":
		check(level.cargo.is_empty() and level.cargo_ready.is_empty(), "empty transit restoration fabricates no loaded cargo")
		check(level.bundles.all(func(u): return battle.units.has(u) and u.visible and u.get_parent() == battle.units_root), "all eleven unladen loads remain in actual world")
		check(level.jujube_carts.all(func(u): return u.visible), "all seven original empty carts remain visible")
	else:
		check(level.empty_cargo.is_empty(), "loaded restoration fabricates no extra empty-cart bindings")
		check(level.bundles.all(func(u): return not battle.units.has(u) and not u.visible and u.get_parent() == battle.units_root and u.process_mode == Node.PROCESS_MODE_DISABLED), "all eleven restored loads are stowed, scene-owned, and disabled")
		check(level.jujube_carts.size() == 7 and level.jujube_carts.all(func(u): return not u.visible), "restoration creates no duplicate empty carts")
	check(store.read_slot().file_sha256 == source_checkpoint.saved_sha256, "read and installation preserve original slot bytes")
	session.dispose()
	if not failures.is_empty(): return null
	return battle

func wait_until(predicate: Callable, seconds: float) -> bool:
	var elapsed := 0.0
	while not predicate.call() and elapsed < seconds:
		await _wait(0.1); elapsed += 0.1
	return bool(predicate.call())
