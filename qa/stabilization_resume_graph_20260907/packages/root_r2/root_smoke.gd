extends SceneTree
## Real root-only transaction. One real new game is the capture fixture;
## every destination stays detached. Map and Unit local restoration are external.
const Factory := preload("res://scripts/run_battle_root_state.gd")
const FROZEN_DECLARED_NAMES := ["level", "mission", "_official_context", "_steam_run_id", "_gameplay_rng", "_gameplay_rng_issue", "_gameplay_rng_start_kind", "_gameplay_content_identity", "_defs", "_abilities", "_items", "next_item_uid", "next_entity_id", "world", "map", "hud", "camera", "units_root", "fx_root", "overlay", "ai_friendly", "_autocam_enabled", "_autocam_active", "_autocam_dwell", "_autocam_target_pos", "_autocam_target_zoom", "_autocam_focus", "_autocam_review_idx", "_autocam_review_unit", "_ai_spawn_serial", "_ai_tick_frame", "_eco_t", "_eco_last_wood", "_eco_wood_stall", "_eco_trap_cd", "_eco_trap_lane", "_eco_lane_cache_bucket", "_eco_lane_cache", "_last_hb", "units", "_grid", "_mob_grid", "_body_grid_liang", "_body_grid_guan", "_focus_counts", "_res_block_cache", "_res_block_frame", "_blocker_cache", "_blocker_cache_revision", "_blocker_query_budget", "_lite_fx", "_mob_count", "_sep_phase", "_impact_fx_frame", "_damage_fx_frame", "_ground_fire_visuals", "_unit_draw_rect", "_death_remains", "_death_remains_atlas", "_death_remains_atlas_checked", "_death_remains_serial", "_no_opt", "_stealth_acc", "_ecast_acc", "_prof_on", "_prof", "_prof_frames", "_prof_print_acc", "_unit_proc_us", "selection", "phase", "kills", "hero_kills", "track_hero_combat_stats", "hero_combat_stats", "_ability_owner_cache", "_active_ability_cache", "_hero_active_ability_cache", "hero_progress", "hero_item_progress", "lit_cells", "economy", "gold", "wood", "pop_cap", "current_age", "faction_res", "faction_gather_mult", "_tech_done", "tech_atk", "tech_hp", "hero_tech_atk", "hero_tech_hp", "tech_gather", "fog", "_vision", "_sight_now", "_reveal_t", "_vision_img", "_fog_tex", "_fog_layer", "_fog_t", "_dragging", "_drag_from", "_click_fx_pos", "_click_fx_t", "_click_fx_attack", "_amove_armed", "_patrol_armed", "_repair_armed", "_garrison_armed", "_ability_armed", "_ability_caster", "_ground_dots", "_hua_snipe_dots", "_lin_duels", "_chrono_zones", "_orbit_zones", "_meteor_zones", "_gong_lines", "_ice_walls", "_wards", "_ward_serial", "_fire_trails", "_bolts", "_walk_casts", "_channels", "_pending_casts", "_ability_slot", "_item_armed", "_item_caster", "_item_slot", "_pending_item_casts", "_walk_item_casts", "_build_armed", "_trap_armed", "_worker_cat", "_hall_page", "_hall_cat", "_traps", "_active", "_inspect_unit", "_demolish_armed_t", "_alert_t", "_alert_pos", "_idle_i", "_groups", "_last_group_key", "_last_group_time", "_camera_locs", "_smoke", "_smoke_t", "_touch_mode", "_allow_touch", "_press_ms", "_box_mode", "_panning", "_drag_cur", "_last_tap_ms", "_last_tap_pos", "_target_cursor", "_cur_attack", "_cur_gather_wood", "_cur_gather_gold", "_cur_repair", "_cur_select", "_cur_garrison", "_hover_kind", "_cursor_resources_released", "_mission_order_token_seq"]
const FROZEN_ROOT_NAMES := ["ai_friendly", "_autocam_enabled", "_autocam_active", "_lite_fx", "_no_opt", "track_hero_combat_stats", "economy", "_click_fx_attack", "_amove_armed", "_patrol_armed", "_repair_armed", "_garrison_armed", "_touch_mode", "_dragging", "_box_mode", "_panning", "next_entity_id", "_autocam_review_idx", "_ai_spawn_serial", "_ai_tick_frame", "_eco_last_wood", "_eco_trap_lane", "_blocker_cache_revision", "_blocker_query_budget", "_mob_count", "_sep_phase", "_impact_fx_frame", "_damage_fx_frame", "_ground_fire_visuals", "_death_remains_serial", "phase", "kills", "gold", "wood", "pop_cap", "current_age", "_ward_serial", "_ability_slot", "_item_slot", "_hall_page", "_idle_i", "_last_group_key", "_mission_order_token_seq", "_autocam_dwell", "_autocam_target_zoom", "_eco_t", "_eco_wood_stall", "_eco_trap_cd", "_last_hb", "_stealth_acc", "_ecast_acc", "tech_atk", "tech_hp", "hero_tech_atk", "hero_tech_hp", "tech_gather", "_click_fx_t", "_demolish_armed_t", "_alert_t", "_autocam_target_pos", "_drag_from", "_click_fx_pos", "_alert_pos", "_drag_cur", "_last_tap_pos", "_unit_draw_rect", "_ability_armed", "_item_armed", "_build_armed", "_trap_armed", "_worker_cat", "_hall_cat", "hero_kills", "hero_combat_stats", "_ability_owner_cache", "_active_ability_cache", "_hero_active_ability_cache", "hero_progress", "hero_item_progress", "lit_cells", "faction_res", "faction_gather_mult", "_tech_done", "_camera_locs", "_autocam_review_unit", "_ability_caster", "_item_caster", "_active", "_inspect_unit", "selection", "_groups", "_grid", "_mob_grid", "_body_grid_liang", "_body_grid_guan", "_focus_counts", "_res_block_cache", "_blocker_cache", "_eco_lane_cache", "_res_block_frame", "_eco_lane_cache_bucket", "_last_group_time", "_press_ms", "_last_tap_ms", "_autocam_focus"]
const BARRIER := {"quiescent": true, "input_released": true}
var checks: Array = []
var field_audit: Array = []
var root_names: Array = []
var manifest: Dictionary = {}
var manifest_ready := false
var report_path := ""
var runtime_identity: Dictionary = {}
var battle: Variant
var codec: Variant
var source_factory: Variant
var restore_factory: Variant
var source_identity: Variant
var restored_identity: Variant
var unit_checker: Variant
var battle_script: Script
var unit_script: Script
var object_to_id: Dictionary = {}
var id_to_unit: Dictionary = {}
var restored_units: Dictionary = {}
var known_ids: Dictionary = {}
var owned_detached: Array = []
var records: Dictionary = {}
var viewport_rect := Rect2()
var completed_cases: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _check(label: String, passed: bool) -> bool:
	checks.append({"label": label, "passed": passed})
	return passed

func _ok(label: String, result: Dictionary) -> bool:
	checks.append({"label": label, "passed": result.get("ok") == true,
		"code": String(result.get("code", "")), "field": String(result.get("field", ""))})
	return result.get("ok") == true

func _source_guard(label: String) -> bool:
	var result := true
	for path in manifest.source_sha256:
		result = _check(label + " " + String(path), FileAccess.get_sha256(String(path)) == manifest.source_sha256[path]) and result
	return result

func _finish(aborted := false) -> void:
	if source_identity != null: source_identity.dispose()
	if restored_identity != null: restored_identity.dispose()
	for object: Variant in owned_detached:
		if is_instance_valid(object): object.free()
	if is_instance_valid(battle):
		battle.free()
	await process_frame
	await process_frame
	paused = false
	if manifest_ready: _source_guard("source after")
	var failures: Array = []
	for row: Dictionary in checks:
		if not row.passed: failures.append(row.label)
	var report: Dictionary = {"suite": "battle-root-v2-native", "run_id": manifest.get("run_id", ""),
		"complete": not aborted, "passed": not aborted and failures.is_empty(), "checks": checks,
		"check_count": checks.size(), "failed_count": failures.size(), "failures": failures, "process_id": OS.get_process_id(),
		"actual_user_dir": OS.get_user_data_dir(), "source_sha256": manifest.get("source_sha256", {}),
		"engine_binary_sha256": manifest.get("engine_binary_sha256", ""),
		"rendering_method": RenderingServer.get_current_rendering_method(), "runtime_identity": runtime_identity,
		"declarations": Factory.ALL_DECLARATIONS.size(), "root_fields": root_names,
		"external_fields": Factory.EXTERNAL_FIELDS, "field_capture_audit": field_audit,
		"completed_cases": completed_cases,
		"actual_viewport_rect": {"position": [viewport_rect.position.x, viewport_rect.position.y],
			"size": [viewport_rect.size.x, viewport_rect.size.y]},
		"battle_resume_tested": false, "scope": "One true paused standard Battle capture; real codec JSON; 105 root fields bound into detached blocked Battle. Original viewport/visual consumer; shared identity maps to fresh real Unit shells. Map projection shared read-only, not restored. No whole graph, activation, cross-process or PCK claim."}
	if not report_path.is_empty():
		var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
		if file == null:
			quit(1); return
		file.store_string(JSON.stringify(report, "\t")); file.close()
	print("[battle-root-v2 native QA] ", JSON.stringify(report))
	quit(0 if report.passed else 1)

func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b): return false
	if typeof(a) == TYPE_OBJECT:
		# The root contract preserves expired versus none, not the old address of
		# an already freed Object. Never dereference or compare freed operands.
		if not is_instance_valid(a): return not is_instance_valid(b)
		return is_instance_valid(b) and a == b
	if typeof(a) == TYPE_ARRAY:
		if a.size() != b.size(): return false
		for i in range(a.size()):
			if not _same(a[i], b[i]): return false
		return true
	if typeof(a) == TYPE_DICTIONARY:
		if not _same(a.keys(), b.keys()): return false
		for key: Variant in a:
			if not _same(a[key], b[key]): return false
		return true
	return a == b

func _root_values(node: Variant) -> Dictionary:
	var values: Dictionary = {}
	for name: String in root_names:
		var value: Variant = node.get(name)
		values[name] = value.duplicate(true) if typeof(value) in [TYPE_ARRAY, TYPE_DICTIONARY] else value
	return values

func _wire_value(name: String, value: Variant) -> Variant:
	if name == "_unit_draw_rect" and typeof(value) == TYPE_RECT2:
		return {"position": value.position, "size": value.size}
	return value

func _audit_values(label: String) -> void:
	# Probe every declared ordinary field independently, including empty values.
	# The single explicit Rect2 transport is the production candidate's contract.
	# Unsupported nested values stay failures; no replacement/defaulting occurs.
	for name: String in Factory.VALUE_TYPES:
		var value: Variant = battle.get(name)
		var encoded: Dictionary = codec.encode(_wire_value(name, value))
		field_audit.append({"case": label, "field": name, "native_type": typeof(value),
			"declared_type": Factory.VALUE_TYPES[name], "supported": encoded.get("ok") == true,
			"code": String(encoded.get("code", "")), "rect_wire_only": name == "_unit_draw_rect"})
		_check(label + " field encodable " + name, encoded.get("ok") == true and typeof(value) == Factory.VALUE_TYPES[name])

func _shell() -> Variant:
	var target: Variant = battle_script.new()
	target.process_mode = Node.PROCESS_MODE_DISABLED
	target.set_block_signals(true)
	# Projection only: this is deliberately not a second map or Map restore.
	target.map = battle.map
	owned_detached.append(target)
	return target

func _reference(tag: Dictionary, tombstone: Variant) -> Variant:
	if tag.state == "none": return null
	if tag.state == "expired": return tombstone
	return restored_units[tag.id]

func _reference_list(tags: Array, tombstone: Variant) -> Array:
	var result: Array = []
	for tag: Dictionary in tags: result.append(_reference(tag, tombstone))
	return result

func _reference_map(rows: Dictionary, tombstone: Variant, single := false) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in rows:
		result[key] = _reference(rows[key], tombstone) if single else _reference_list(rows[key], tombstone)
	return result

func _identities(rows: Array) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in rows: result[String(row.id).to_int()] = row.value
	return result

func _compare_fields(label: String, target: Variant, checked: Dictionary, bound: Dictionary,
		tombstone: Variant, before_msec: int, after_msec: int) -> void:
	var raw: Dictionary = checked.value
	var expected: Dictionary = raw.values.duplicate(true)
	for name: String in Factory.ROOT_REFERENCE: expected[name] = _reference(raw.references[name], tombstone)
	expected["selection"] = _reference_list(raw.selection, tombstone)
	expected["_groups"] = _reference_map(raw.groups, tombstone)
	expected["_blocker_cache"] = _reference_map(raw.blockers, tombstone, true)
	for name: String in Factory.ROOT_SPATIAL_GRID: expected[name] = _reference_map(raw.grids[name], tombstone)
	for name: String in Factory.ROOT_STABLE_IDENTITY_MAP: expected[name] = _identities(raw.identities[name])
	var eco: Dictionary = raw.eco.duplicate(true)
	if not eco.is_empty():
		eco["heroes"] = _reference_list(raw.eco.heroes, tombstone)
		eco["assignments"] = _identities(raw.eco.assignments)
	expected["_eco_lane_cache"] = eco
	expected["_autocam_focus"] = Vector2.INF if raw.focus.kind == "none" else raw.focus.value
	var old_frame: int = raw.clocks.physics
	var new_frame: int = bound.bound_physics_frame
	var old_bucket: int = raw.clock_values._eco_lane_cache_bucket
	var old_res: int = raw.clock_values._res_block_frame
	expected["_eco_lane_cache_bucket"] = -1 if old_bucket == -1 else new_frame / 16 - (old_frame / 16 - old_bucket)
	expected["_res_block_frame"] = -1 if old_res == -1 else new_frame - (old_frame - old_res)
	var translated_origins: Array = []
	for name: String in root_names:
		if name in Factory.ROOT_INPUT_CLOCK:
			var age: int = int(raw.clocks.msec) - int(raw.clock_values[name])
			var actual: Variant = target.get(name)
			var origin: int = int(actual) + age
			translated_origins.append(origin)
			_check(label + " root field " + name, typeof(actual) == TYPE_INT and origin >= before_msec and origin <= after_msec)
		else:
			_check(label + " root field " + name, expected.has(name) and _same(expected[name], target.get(name)))
	_check(label + " common input time origin", translated_origins.size() == 3 and translated_origins[0] == translated_origins[1] and translated_origins[1] == translated_origins[2])
	_check(label + " same frame detached install", bound.bound_physics_frame == Engine.get_physics_frames() and bound.bound_process_frame == Engine.get_process_frames() and target.get_parent() == null and not target.is_inside_tree() and target.process_mode == Node.PROCESS_MODE_DISABLED and target.is_blocking_signals())
	_check(label + " external factory untouched", target.map == battle.map and target.level == null and target.world == null and target.hud == null and target.units.is_empty() and target._gameplay_rng == null)

func _roundtrip(label: String, visual := false) -> bool:
	_audit_values(label)
	var before: Dictionary = _root_values(battle)
	var rng_before: Dictionary = battle._gameplay_rng.capture()
	var captured: Dictionary = source_factory.capture(battle, runtime_identity.content_version, object_to_id, BARRIER)
	if not _ok(label + " capture", captured): return false
	_check(label + " capture source unchanged", _same(before, _root_values(battle)))
	_check(label + " capture draws no native RNG", _same(rng_before, battle._gameplay_rng.capture()))
	var record: Variant = JSON.parse_string(JSON.stringify(captured.record))
	if not _check(label + " JSON record", typeof(record) == TYPE_DICTIONARY): return false
	records[label] = record
	var decoded: Dictionary = codec.decode(record.payload)
	if not _ok(label + " actual codec decode", decoded): return false
	var wire: Variant = decoded.value.values._unit_draw_rect
	_check(label + " Rect2 wire exact keys and Vector2", typeof(wire) == TYPE_DICTIONARY and wire.keys() == ["position", "size"] and typeof(wire.position) == TYPE_VECTOR2 and typeof(wire.size) == TYPE_VECTOR2)
	var checked: Dictionary = restore_factory.validate(record, runtime_identity.content_version, known_ids)
	if not _ok(label + " validate", checked): return false
	_check(label + " retired UID aliases exact", _same(captured.item_uid_aliases, checked.item_uid_aliases))
	var target: Variant = _shell()
	var tombstone: Variant = restored_identity.expired_unit()
	var before_msec: int = Time.get_ticks_msec()
	var bound: Dictionary = restore_factory.bind(target, record, runtime_identity.content_version, restored_units, tombstone, BARRIER)
	var after_msec: int = Time.get_ticks_msec()
	if not _ok(label + " bind", bound): return false
	_compare_fields(label, target, checked, bound, tombstone, before_msec, after_msec)
	_check(label + " no whole Battle claim", captured.complete_battle == false and checked.complete_battle == false and bound.complete_battle == false)
	if visual:
		var rect: Rect2 = battle._unit_draw_rect
		var inside: Vector2 = battle.to_logic(rect.get_center())
		var outside: Vector2 = battle.to_logic(rect.end + Vector2(240.0, 240.0))
		_check("original viewport consumer distinguishes inside outside", battle._lite_fx and battle.unit_visual_active(inside) and not battle.unit_visual_active(outside))
		_check("restored original consumer preserves inside outside", target.unit_visual_active(inside) == battle.unit_visual_active(inside) and target.unit_visual_active(outside) == battle.unit_visual_active(outside))
		_check("actual viewport Rect2 preserved", target._unit_draw_rect == viewport_rect)
		_check("nonempty blocker budget preserved", target._blocker_query_budget == 3 and not target._blocker_cache.is_empty())
		_check("nonempty economic cache preserved", not target._eco_lane_cache.is_empty() and target._eco_lane_cache.heroes.size() == 4)
		_check("stable cache key survives fresh real Unit identity", target._focus_counts.has(restored_units["1"].entity_id) and restored_units["1"].entity_id == id_to_unit["1"].entity_id and restored_units["1"].get_instance_id() != id_to_unit["1"].get_instance_id())
	completed_cases.append(label)
	return true

func _negative_rects() -> bool:
	var valid: Dictionary = records.viewport
	var cases: Array = [
		{"name": "scalar", "wire": 7, "code": "RECT2_FIELDS"},
		{"name": "missing_size", "wire": {"position": Vector2.ZERO}, "code": "RECT2_FIELDS"},
		{"name": "extra_key", "wire": {"position": Vector2.ZERO, "size": Vector2.ONE, "extra": true}, "code": "RECT2_FIELDS"},
		{"name": "integer_component", "wire": {"position": Vector2.ZERO, "size": 2}, "code": "RECT2_COMPONENT_TYPE"},
		{"name": "vector2i_component", "wire": {"position": Vector2i.ZERO, "size": Vector2.ONE}, "code": "RECT2_COMPONENT_TYPE"},
		{"name": "missing_field", "wire": null, "code": "VALUE_FIELDS"}]
	for item: Dictionary in cases:
		var decoded: Dictionary = codec.decode(valid.payload)
		if not _ok("negative source decode " + item.name, decoded): return false
		if item.name == "missing_field": decoded.value.values.erase("_unit_draw_rect")
		else: decoded.value.values["_unit_draw_rect"] = item.wire
		var encoded: Dictionary = codec.encode(decoded.value)
		if not _ok("negative encodable envelope " + item.name, encoded): return false
		var bad: Dictionary = valid.duplicate(true)
		bad["payload"] = encoded.value
		bad = JSON.parse_string(JSON.stringify(bad))
		var checked: Dictionary = restore_factory.validate(bad, runtime_identity.content_version, known_ids)
		_check("malformed " + item.name + " validate rejects", checked.get("ok") == false and checked.get("code") == item.code)
		var target: Variant = _shell()
		var before: Dictionary = _root_values(target)
		var bound: Dictionary = restore_factory.bind(target, bad, runtime_identity.content_version, restored_units, restored_identity.expired_unit(), BARRIER)
		_check("malformed " + item.name + " bind rejects", bound.get("ok") == false and bound.get("code") == item.code)
		_check("malformed " + item.name + " all 105 untouched", _same(before, _root_values(target)))
	# Audit an actual unsupported nested object, then restore the original source
	# field. It must be reported/rejected, never erased or defaulted for capture.
	var old_cache: Dictionary = battle._camera_locs.duplicate(true)
	var unsupported := RefCounted.new()
	battle._camera_locs[2] = unsupported
	var unsupported_codec: Dictionary = codec.encode(battle._camera_locs)
	var rejected: Dictionary = source_factory.capture(battle, runtime_identity.content_version, object_to_id, BARRIER)
	_check("unsupported actual field is exposed", unsupported_codec.get("ok") == false and rejected.get("ok") == false and rejected.get("code") == "CAMERA_LOCATIONS")
	field_audit.append({"case": "unsupported_negative", "field": "_camera_locs", "supported": false,
		"expected_rejection": true, "codec_code": unsupported_codec.get("code"), "capture_code": rejected.get("code")})
	_check("unsupported capture does not silently zero field", battle._camera_locs[2] == unsupported)
	battle._camera_locs = old_cache
	return true

func _configure_standard() -> void:
	var campaign: Node = root.get_node("Campaign")
	for key: String in ["skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly", "defense_random"]:
		campaign.set(key, false)
	campaign.set("skirmish", true); campaign.set("defense_waves", 30); campaign.set("defense_hero_cap", 4)
	root.get_node("Settings").set("auto_micro_level", 0)
	root.get_node("Settings").set("game_speed", 1.0)
	AudioServer.set_bus_mute(0, true)

func _run() -> void:
	var path: String = OS.get_environment("RUN_RESTORE_QA_MANIFEST")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if not path.is_empty() else null
	if typeof(data) != TYPE_DICTIONARY:
		_check("host manifest", false); await _finish(true); return
	manifest = data
	for key: String in ["run_id", "private_user", "report", "engine_binary_sha256"]:
		if typeof(manifest.get(key)) != TYPE_STRING or manifest[key].is_empty():
			_check("host manifest " + key, false); await _finish(true); return
	if typeof(manifest.get("source_sha256")) != TYPE_DICTIONARY or manifest.source_sha256.is_empty():
		_check("host sources", false); await _finish(true); return
	report_path = manifest.report
	if not report_path.is_absolute_path() or FileAccess.file_exists(report_path):
		report_path = ""; _check("fresh report", false); await _finish(true); return
	manifest_ready = true
	if not _check("private user directory", OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower() == manifest.private_user.replace("\\", "/").simplify_path().to_lower()):
		await _finish(true); return
	if not _source_guard("source before"):
		await _finish(true); return
	var provider_script: Script = load("res://scripts/run_content_identity.gd")
	var identity: Dictionary = provider_script.new().resolve_runtime_identity()
	if not _ok("actual trusted provider", identity):
		await _finish(true); return
	if not _check("actual provider save eligible and native engine", identity.get("save_eligible") == true and identity.get("engine_binary_sha256") == manifest.engine_binary_sha256):
		await _finish(true); return
	runtime_identity = {"content_version": identity.content_version, "source_mode": identity.source_mode,
		"identity_scope": identity.identity_scope, "engine_binary_sha256": identity.engine_binary_sha256}
	battle_script = load("res://scripts/battle.gd")
	unit_script = load("res://scripts/unit.gd")
	var level_script: Script = load("res://scripts/levels/skirmish.gd")
	var codec_script: Script = load("res://scripts/run_state_value_codec.gd")
	var inventory_script: Script = load("res://scripts/hero_inventory.gd")
	var checker_script: Script = load("res://scripts/run_unit_state.gd")
	var graph_script: Script = load("res://scripts/run_graph_identity.gd")
	codec = codec_script.new()
	unit_checker = checker_script.new(codec_script, unit_script, inventory_script)
	root_names = Factory.VALUE_TYPES.keys()
	for group: Array in [Factory.ROOT_REFERENCE, Factory.ROOT_REFERENCE_LIST, Factory.ROOT_GROUPS, Factory.ROOT_SPATIAL_GRID,
		Factory.ROOT_STABLE_IDENTITY_MAP, Factory.ROOT_BLOCKER_CACHE, Factory.ROOT_ECO_CACHE,
		Factory.ROOT_ENGINE_CLOCK, Factory.ROOT_INPUT_CLOCK, Factory.ROOT_INFINITY_SENTINEL]: root_names.append_array(group)
	var all_names: Array = root_names + Factory.EXTERNAL_FIELDS
	var unique: Dictionary = {}
	for name: String in all_names: unique[name] = true
	_check("170 declarations 105 root 65 external exact", Factory.ALL_DECLARATIONS.size() == 170 and root_names.size() == 105 and Factory.EXTERNAL_FIELDS.size() == 65 and unique.size() == 170 and unique.size() == Factory.ALL_DECLARATIONS.size())
	var complete_names := true
	for name: String in Factory.ALL_DECLARATIONS: complete_names = complete_names and unique.has(name)
	_check("classification matches frozen declaration table", complete_names and Factory.ALL_DECLARATIONS == FROZEN_DECLARED_NAMES and root_names == FROZEN_ROOT_NAMES)
	_configure_standard()
	paused = true
	var scene: PackedScene = load("res://scenes/main.tscn")
	battle = scene.instantiate()
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(battle); current_scene = battle
	await process_frame
	battle.hud._intro_root.hide()
	battle._on_intro_done()
	await process_frame
	await process_frame
	_check("real standard Battle paused and started once", paused and not Engine.is_in_physics_frame() and battle.phase == 2 and battle.economy and battle.level.get_script() == level_script and battle.level._started and battle.level._wave_t == 120.0 and battle.level._wavelist_cache.size() == 30 and battle.gameplay_rng_fault().is_empty())
	_check("Battle uses actual trusted provider", battle._gameplay_content_identity.get("content_version") == runtime_identity.content_version and battle._gameplay_rng_start_kind == "new")
	_check("default Rect2 retained before real grid build", battle._unit_draw_rect == Rect2())
	var index := 0
	for unit: Variant in battle.units_root.get_children():
		if not _check("complete live Unit fixture " + str(index), is_instance_valid(unit) and unit.get_script() == unit_script and not unit.is_queued_for_deletion()):
			await _finish(true); return
		var stable: String = str(unit.entity_id)
		object_to_id[unit] = stable; id_to_unit[stable] = unit; known_ids[stable] = true
		index += 1
	if not _check("nonempty actual complete Unit registry", index > 1):
		await _finish(true); return
	source_identity = graph_script.new(unit_script)
	restored_identity = graph_script.new(unit_script)
	if not _ok("source shared identity configure", source_identity.configure(id_to_unit, id_to_unit.values())):
		await _finish(true); return
	if not _ok("fresh shared identity declares known IDs", restored_identity.declare_entities(known_ids)):
		await _finish(true); return
	for stable: String in known_ids:
		var unit: Variant = unit_script.new()
		unit.entity_id = stable.to_int()
		unit.process_mode = Node.PROCESS_MODE_DISABLED; unit.set_block_signals(true)
		restored_units[stable] = unit; owned_detached.append(unit)
	if not _ok("fresh real Unit shells shared identity configure", restored_identity.configure(restored_units, restored_units.values())):
		await _finish(true); return
	source_factory = Factory.new(codec_script, battle_script, unit_script, level_script, unit_checker._check_inventory,
		source_identity.encode_identity, source_identity.validate_identity, source_identity.decode_identity)
	restore_factory = Factory.new(codec_script, battle_script, unit_script, level_script, unit_checker._check_inventory,
		restored_identity.encode_identity, restored_identity.validate_identity, restored_identity.decode_identity)
	if not _roundtrip("default"):
		await _finish(true); return
	# Original actual viewport/grid path; no mirrored view calculation.
	battle._grid_build()
	viewport_rect = battle._unit_draw_rect
	_check("real viewport produces nonzero Rect2", viewport_rect.size.x > 240.0 and viewport_rect.size.y > 240.0 and battle.get_viewport().get_visible_rect().size.x > 0.0)
	# Explicit root authority fixtures exercise nonempty caches/aliases. No
	# commands, damage, inventory restore or fake Unit/Map implementation.
	battle._lite_fx = true
	var first: Variant = id_to_unit["1"]
	var expired: Variant = unit_script.new()
	battle._inspect_unit = expired
	battle.selection = [first, null, first, expired]
	battle._groups = {1: [first, null, first, expired]}
	battle._blocker_cache = {"1,1|2,2|0": first, "3,3|4,4|0": null}
	battle._blocker_query_budget = 3
	battle._focus_counts = {first.entity_id: 2}
	battle._res_block_cache = {first.entity_id: true}
	battle._res_block_frame = Engine.get_physics_frames()
	battle._eco_lane_cache_bucket = Engine.get_physics_frames() / 16
	battle._eco_lane_cache = {"lanes": [Vector2(10.25, 20.5)], "pressure": [1.25],
		"heroes": [first, null, first, expired], "assignments": {first.entity_id: 0}}
	battle._camera_locs = {1: Vector2(13.25, -9.5)}
	# Populate one valid four-value retirement snapshot with an int64 UID above
	# JSON's exact numeric range. The real pure Unit inventory checker validates it.
	var slots: Array = []
	for slot in range(6): slots.append({})
	# Defs.ITEMS is deliberately empty. This is a structural UID/alias fixture,
	# not an installed or usable gameplay item and never a provider identity.
	var item_id: String = "qa_root_retired_uid"
	_check("retired UID fixture has no production item definition", battle._items.is_empty() and battle.item_def(item_id).is_empty())
	slots[0] = {"id": item_id, "count": 2, "uid": 9007199254740993}
	battle.hero_item_progress = {"song_jiang": {"slots": slots, "cooldowns": {item_id: 2.25},
		"proc_cooldowns": {"9007199254740993:on_hit": 1.5}, "uid_seq": 7}}
	battle.hero_progress = {"song_jiang": {"level": 3, "xp": 7.125, "sp": 2, "ranks": [1, 2, 0, 0]}}
	battle.hero_kills = {"song_jiang": {"name": "Song Jiang", "key": "song_jiang", "n": 3}}
	var actual_stat: Dictionary = battle._ensure_hero_combat_stat("song_jiang", "Song Jiang")
	actual_stat.skill_damage["rally"] = 1.25
	actual_stat.item_stats["qa_root_retired_uid"] = {"name": "QA item", "damage": 2.25, "healing": 1.5, "kills": 1}
	_check("actual stat producer retains hero and item definition keys", battle.hero_combat_stats.has("song_jiang") and actual_stat.item_stats.has("qa_root_retired_uid"))
	expired.free()
	if not _roundtrip("viewport", true):
		await _finish(true); return
	if not _negative_rects():
		await _finish(true); return
	battle._unit_draw_rect = Rect2(Vector2(-17.125, 8.5), Vector2(-9.25, 0.0625))
	if not _roundtrip("fractional_negative"):
		await _finish(true); return
	# Shared tombstones remain live through ALL root binds, then one release.
	var last: Variant = owned_detached.back()
	_check("expired is live tombstone until all root binds", is_instance_valid(last._inspect_unit) and last._inspect_unit == restored_identity.expired_unit())
	restored_identity.release_tombstones()
	_check("expired preserved as freed object not null", typeof(last._inspect_unit) == TYPE_OBJECT and not is_instance_valid(last._inspect_unit))
	await _finish()
