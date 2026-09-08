extends RefCounted
## Internal preparation and paused mounting. Never starts or saves a Battle.
## Display/UI/Steam installation remains a required outer phase; root clock binds there.
const SCHEMA := "classic_world_core_preparation_v7"
const SECTIONS := ["map", "fog", "units", "level", "visual", "root", "rng", "items", "continuous", "zones", "meteor", "remaining", "casts", "item_casts", "death_remains", "world_display", "camera", "hud_messages", "hud", "environment"]
const EnvironmentState := preload("res://scripts/run_environment_state.gd")
const HudState := preload("res://scripts/run_hud_state.gd")
const HudMessages := preload("res://scripts/run_hud_messages_state.gd")
const CameraState := preload("res://scripts/run_camera_state.gd")
const WorldDisplay := preload("res://scripts/run_world_display_state.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const B := preload("res://scripts/battle.gd")
const U := preload("res://scripts/unit.gd")
const M := preload("res://scripts/game_map.gd")
const L := preload("res://scripts/levels/skirmish.gd")
const Inventory := preload("res://scripts/hero_inventory.gd")
const UnitState := preload("res://scripts/run_unit_state.gd")
const UnitGraph := preload("res://scripts/run_unit_graph.gd")
const Identity := preload("res://scripts/run_graph_identity.gd")
const MapState := preload("res://scripts/run_map_state.gd")
const FogState := preload("res://scripts/run_fog_state.gd")
const LevelState := preload("res://scripts/run_defense_level_state.gd")
const RootState := preload("res://scripts/run_battle_root_state.gd")
const Visual := preload("res://scripts/run_visual_graph.gd")
const ProjectileState := preload("res://scripts/run_projectile_state.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const AxesState := preload("res://scripts/run_li_brawn_axes_state.gd")
const ItemState := preload("res://scripts/run_item_id_state.gd")
const Continuous := preload("res://scripts/run_continuous_effect_state.gd")
const Zones := preload("res://scripts/run_zone_effects_state.gd")
const Meteor := preload("res://scripts/run_meteor_wards_state.gd")
const Remaining := preload("res://scripts/run_remaining_effect_state.gd")
const Casts := preload("res://scripts/run_cast_flow_state.gd")
const ItemCasts := preload("res://scripts/run_item_cast_flow_state.gd")
var _unit_checker: Variant = UnitState.new(Codec, U, Inventory)
var _trusted: Dictionary
var _runtime: Dictionary
var _textures: Dictionary
var _axe_texture: Texture2D
var _battle: Variant = null
var _identity: Variant = null
var _visual: Variant = null
var _unit_plan: Dictionary = {}
var _display: Variant = null
var _camera_module: Variant = null
var _pending_root: Dictionary = {}
var _hud_module: Variant = null
var _mount_frame: Dictionary = {}
var _environment: Variant = null
var _fog_module: Variant = null
var _fog_plan: Dictionary = {}
var _activated := false
var _owns_world := true

func _init(trusted_identity: Dictionary, trusted_runtime: Dictionary, textures: Dictionary = {}, axe_texture: Texture2D = null) -> void:
	_trusted = trusted_identity.duplicate(true)
	_runtime = trusted_runtime.duplicate(true)
	_textures = textures.duplicate()
	_axe_texture = axe_texture
	_register_visual_textures()

func _bad(code: String, section: String = "") -> Dictionary:
	return {"ok": false, "code": code, "section": section, "complete_world": false}

func _context() -> bool:
	return _trusted.get("ok") == true and _trusted.get("save_eligible") == true and typeof(_trusted.get("content_version")) == TYPE_STRING and not _trusted.content_version.is_empty() and typeof(_trusted.get("engine_binary_sha256")) == TYPE_STRING and _trusted.engine_binary_sha256.length() == 64 and _runtime.has("defs") and _runtime.has("abilities") and _runtime.has("items")

func _graph() -> Variant:
	return UnitGraph.new(UnitState, Identity, Codec, U, Inventory, B, M)

func _visuals(owner: Variant) -> Variant:
	return Visual.new(Codec, B, U, owner, _textures, ProjectileState.new(Codec, ProjectileScript, U), AxesState.new(Codec, B.LiBrawnAxesFx, U, _axe_texture))

func _root_state(identity: Variant) -> Variant:
	return RootState.new(Codec, B, U, L, _unit_checker._check_inventory, identity.encode_identity, identity.validate_identity, identity.decode_identity)

func _effects(identity: Variant, visual: Variant) -> Dictionary:
	var encode := func(value): return identity.encode_identity("_chase_last_id", value)
	var validate := func(value): return identity.validate_identity("_chase_last_id", value)
	var decode := func(value): return identity.decode_identity("_chase_last_id", value)
	return {"continuous": Continuous.new(Codec, B, U), "zones": Zones.new(Codec, B, U), "meteor": Meteor.new(Codec, B, U, encode, validate, decode), "remaining": Remaining.new(Codec, B, U, encode, validate, decode, visual.encode_token, visual.validate_token, visual.decode_token), "casts": Casts.new(Codec, B, U), "item_casts": ItemCasts.new(Codec, B, U)}

func _item_max(units: Array, progress: Dictionary, queue_max: int) -> Dictionary:
	var maximum: int = queue_max
	var physical: Dictionary = {}
	for unit: Variant in units:
		if unit.inventory == null: continue
		for item: Variant in unit.inventory.slots:
			if item.is_empty(): continue
			if physical.has(item.uid): return _bad("DUPLICATE_LIVE_ITEM_UID")
			physical[item.uid] = {"hero": unit.key, "item_id": item.id}
			maximum = maxi(maximum, item.uid)
		for key: String in unit.inventory.proc_cooldowns: maximum = maxi(maximum, key.left(key.find(":")).to_int())
	var retired: Dictionary = {}
	for hero: String in progress:
		var inv: Dictionary = progress[hero]
		for item: Variant in inv.slots:
			if item.is_empty(): continue
			var owner := {"hero": hero, "item_id": item.id}
			if (physical.has(item.uid) and physical[item.uid] != owner) or (retired.has(item.uid) and retired[item.uid] != owner): return _bad("RETIRED_ITEM_UID_CONFLICT")
			retired[item.uid] = owner
			maximum = maxi(maximum, item.uid)
		for key: String in inv.proc_cooldowns: maximum = maxi(maximum, key.left(key.find(":")).to_int())
	return {"ok": true, "maximum": maximum}

func capture(source: Variant, retained_identity: Variant = null) -> Dictionary:
	if not _context(): return _bad("TRUSTED_CONTEXT_REQUIRED")
	if not is_instance_valid(source) or source.get_script() != B or not source.is_inside_tree() or not source.get_tree().paused or source._save_barrier == null or source._save_barrier.state != source._save_barrier.State.HELD: return _bad("ACTUAL_HELD_BARRIER_REQUIRED")
	var version: String = _trusted.content_version
	var ids: Dictionary = {}
	for unit: Variant in source.units_root.get_children(true):
		if not is_instance_valid(unit) or unit.get_script() != U: return _bad("UNKNOWN_UNIT_ROOT_CHILD")
		ids[unit] = str(unit.entity_id)
	var units: Dictionary = _graph().capture(source, ids, version, retained_identity)
	if not units.ok: return units
	var identity: Variant = units.identity
	var visual: Variant = _visuals(source)
	var modules: Dictionary = _effects(identity, visual)
	var sections: Dictionary = {"units": units.value}
	var results := {"map": MapState.new(version).capture(source.map), "fog": FogState.new(_trusted, B, M, Codec, B.FogLayer).capture(source, {"quiescent": true}), "level": LevelState.new(Codec, L, U).capture(source.level, version, ids, source.next_entity_id), "visual": visual.capture(source.fx_root, version, ids), "root": _root_state(identity).capture(source, version, ids, {"quiescent": true, "input_released": true}), "rng": source.capture_gameplay_rng()}
	for key: String in results:
		if not results[key].ok:
			if retained_identity == null: identity.dispose()
			return {"ok": false, "code": results[key].get("code", "SECTION_CAPTURE"), "section": key, "cause": results[key], "complete_world": false}
		sections[key] = results[key].value if key in ["map", "visual"] else results[key].record
	for key: String in modules:
		var captured: Dictionary = modules[key].capture(source, version, ids)
		if not captured.ok:
			if retained_identity == null: identity.dispose()
			return {"ok": false, "code": captured.get("code", "EFFECT_CAPTURE"), "section": key, "cause": captured, "complete_world": false}
		sections[key] = captured.record
	var remains: Dictionary = visual.capture_remains_owner()
	if not remains.ok:
		if retained_identity == null: identity.dispose()
		return remains
	sections["death_remains"] = remains.value
	var display: Dictionary = WorldDisplay.new().capture(source, ids)
	if not display.ok:
		if retained_identity == null: identity.dispose()
		return display
	sections["world_display"] = display.value
	var camera_state: Dictionary = CameraState.new().capture(source)
	if not camera_state.ok:
		if retained_identity == null: identity.dispose()
		return camera_state
	sections["camera"] = camera_state.value
	var hud_messages: Dictionary = HudMessages.new().capture(source)
	if not hud_messages.ok:
		if retained_identity == null: identity.dispose()
		return hud_messages
	sections["hud_messages"] = hud_messages.value
	var hud_state: Dictionary = HudState.new().capture(source, ids)
	if not hud_state.ok:
		if retained_identity == null: identity.dispose()
		return hud_state
	sections["hud"] = hud_state.value
	var environment: Dictionary = EnvironmentState.new().capture(source)
	if not environment.ok:
		if retained_identity == null: identity.dispose()
		return environment
	sections["environment"] = environment.value
	var known: Dictionary = {}
	for id: String in units.value.root_order: known[id] = true
	var queue: Dictionary = modules.item_casts.validate(sections.item_casts, version, known)
	if not queue.ok:
		if retained_identity == null: identity.dispose()
		return queue
	var maximum: Dictionary = _item_max(source.units_root.get_children(), source.hero_item_progress, queue.item_uid_alias_max)
	if not maximum.ok:
		if retained_identity == null: identity.dispose()
		return maximum
	var counter: Dictionary = ItemState.new(Codec, B).capture(source, version, maximum.maximum)
	if not counter.ok:
		if retained_identity == null: identity.dispose()
		return counter
	sections["items"] = counter.value
	return {"ok": true, "record": {"schema": SCHEMA, "content_version": version, "engine_sha256": _trusted.engine_binary_sha256, "sections": sections}, "identity": identity, "complete_world": false, "display_ui_and_steam_pending": true}

func _abort(result: Dictionary, section: String) -> Dictionary:
	dispose()
	return _bad(String(result.get("code", "SECTION_PREPARE")), section)

func prepare(record: Variant) -> Dictionary:
	if is_instance_valid(_battle): return _bad("ALREADY_PREPARED")
	if not _context(): return _bad("TRUSTED_CONTEXT_REQUIRED")
	var tree: Variant = Engine.get_main_loop()
	if not tree is SceneTree or not tree.paused or Engine.is_in_physics_frame(): return _bad("PAUSED_PREPARATION_REQUIRED")
	if typeof(record) != TYPE_DICTIONARY or record.size() != 4 or not record.has_all(["schema", "content_version", "engine_sha256", "sections"]) or record.schema != SCHEMA or record.content_version != _trusted.content_version or record.engine_sha256 != _trusted.engine_binary_sha256: return _bad("WORLD_CORE_IDENTITY")
	if typeof(record.sections) != TYPE_DICTIONARY or record.sections.size() != SECTIONS.size() or not record.sections.has_all(SECTIONS): return _bad("WORLD_CORE_SECTIONS")
	if JSON.stringify(record).to_utf8_buffer().size() > 67108864: return _bad("WORLD_CORE_LIMIT")
	var s: Dictionary = record.sections
	var version: String = _trusted.content_version
	var map_state: Variant = MapState.new(version)
	var checked: Dictionary = map_state.validate(s.map)
	if not checked.ok: return checked
	if not checked.requirements.is_empty(): return _bad("MAP_DISPLAY_UNSUPPORTED")
	_battle = B.new()
	_battle._cursor_resources_released = true # No global cursor is owned until final installation.
	_battle.scene_file_path = "res://scenes/main.tscn" # Trusted restart route, never a saved path.
	_battle.process_mode = Node.PROCESS_MODE_DISABLED
	_battle.set_block_signals(true)
	_battle._defs = _runtime.defs.duplicate(true)
	_battle._abilities = _runtime.abilities.duplicate(true)
	_battle._items = _runtime.items.duplicate(true)
	_battle.world = Node2D.new()
	_battle.world.transform = M.ISO
	_battle.add_child(_battle.world)
	_battle.map = M.new()
	_battle.world.add_child(_battle.map)
	checked = map_state.stage_map_values(_battle.map, s.map)
	if not checked.ok: return _abort(checked, "map")
	_unit_plan = _graph().prepare(s.units, version, _battle, _battle.map)
	if not _unit_plan.ok: return _abort(_unit_plan, "units")
	_identity = _unit_plan.identity
	_battle.units_root = Node2D.new()
	_battle.world.add_child(_battle.units_root)
	for unit: Variant in _unit_plan.units_in_root_order: _battle.units_root.add_child(unit)
	_battle.units = _unit_plan.active_units
	_battle.next_entity_id = _unit_plan.pending_battle_fields.next_entity_id
	var ids: Dictionary = _unit_plan.id_to_unit
	checked = LevelState.new(Codec, L, U).restore(s.level, version, ids, _battle.next_entity_id)
	if not checked.ok: return _abort(checked, "level")
	_battle.level = checked.level
	_battle.level.bind_gameplay_rng_owner(_battle)
	checked = _battle.configure_restored_gameplay_rng(_trusted, s.rng)
	if not checked.ok: return _abort(checked, "rng")
	var fog: Variant = FogState.new(_trusted, B, M, Codec, B.FogLayer)
	var fog_plan: Dictionary = fog.bind(_battle, s.fog)
	_fog_module = fog
	_fog_plan = fog_plan
	if not fog_plan.ok: return _abort(fog_plan, "fog")
	if fog_plan.layer != null: _battle.world.add_child(fog_plan.layer)
	checked = map_state.finish_display(_battle.map, s.map)
	if not checked.ok: return _abort(checked, "map_display")
	var known: Dictionary = {}
	for id: String in ids: known[id] = true
	var root: Dictionary = _root_state(_identity).validate(s.root, version, known)
	if not root.ok: return _abort(root, "root")
	if root.value.values.next_entity_id != _battle.next_entity_id: return _abort(_bad("ROOT_ENTITY_COUNTER_MISMATCH"), "root")
	# Effect factories require the already validated monotonic root counter.
	# This private shell stays detached/disabled; clock and remaining root state
	# are still bound only in the final whole-world installation transaction.
	_battle._ward_serial = root.value.values._ward_serial
	_visual = _visuals(_battle)
	checked = _visual.prepare(s.visual, version, ids, _unit_plan.expired_unit)
	if not checked.ok: return _abort(checked, "visual")
	var ground_count := 0
	for node: Variant in checked.nodes.values():
		if node.get_script() == B.GroundFireFx: ground_count += 1
	_battle.fx_root = checked.root
	_battle.world.add_child(_battle.fx_root)
	checked = _visual.bind_remains_owner(s.death_remains)
	if not checked.ok: return _abort(checked, "death_remains")
	var modules: Dictionary = _effects(_identity, _visual)
	for key: String in modules:
		checked = modules[key].bind(_battle, s[key], version, ids, _unit_plan.expired_unit)
		if not checked.ok: return _abort(checked, key)
	if root.value.values._ground_fire_visuals != ground_count: return _abort(_bad("ROOT_GROUND_FIRE_COUNT_MISMATCH"), "root")
	var queues: Dictionary = modules.item_casts.validate(s.item_casts, version, known)
	if not queues.ok: return _abort(queues, "item_casts")
	var maximum: Dictionary = _item_max(_unit_plan.units_in_root_order, root.value.values.hero_item_progress, queues.item_uid_alias_max)
	if not maximum.ok: return _abort(maximum, "item_audit")
	var counter: Dictionary = ItemState.new(Codec, B).restore(_battle, s.items, version, maximum.maximum)
	if not counter.ok: return _abort(counter, "items")
	_display = WorldDisplay.new()
	checked = _display.bind(_battle, s.world_display, ids)
	if not checked.ok: return _abort(checked, "world_display")
	_camera_module = CameraState.new()
	checked = _camera_module.bind(_battle, s.camera)
	if not checked.ok: return _abort(checked, "camera")
	checked = HudMessages.new().decode(s.hud_messages)
	if not checked.ok: return _abort(checked, "hud_messages")
	_hud_module = HudState.new()
	checked = _hud_module.bind(_battle, s.hud, s.hud_messages, ids, _unit_plan.expired_unit)
	if not checked.ok: return _abort(checked, "hud")
	_environment = EnvironmentState.new()
	checked = _environment.bind(_battle, s.environment)
	if not checked.ok: return _abort(checked, "environment")
	_pending_root = s.root.duplicate(true)
	_battle.set_meta("_run_core_prepared", true)
	# Root values, UI/camera, Unit signals, clock, Steam and activation
	# must be installed together by the final whole-world transaction, never here.
	return {"ok": true, "battle": _battle, "identity": _identity, "unit_plan": _unit_plan, "visual": _visual, "fog_module": fog, "fog_plan": fog_plan, "pending_root": _pending_root, "pending_ground_fire_count": ground_count, "world_display": _display, "camera_module": _camera_module, "pending_hud_messages": s.hud_messages.duplicate(true), "hud_module": _hud_module, "environment_module": _environment, "complete_world": false, "mounted": false, "activated": false}

func dispose() -> void:
	if _visual != null: _visual.dispose()
	_visual = null
	if _identity != null: _identity.dispose()
	_identity = null
	if _owns_world and is_instance_valid(_battle): _battle.free()
	_battle = null
	_unit_plan.clear()
	_pending_root.clear()
	_display = null
	_camera_module = null
	_hud_module = null
	_mount_frame.clear()
	_environment = null
	_fog_module = null
	_fog_plan.clear()


func mount_disabled(parent: Node) -> Dictionary:
	if not is_instance_valid(_battle) or _battle.get_parent() != null or _battle.is_inside_tree() or not _mount_frame.is_empty() or not is_instance_valid(parent) or not parent.is_inside_tree() or not parent.get_tree().paused or Engine.is_in_physics_frame(): return _bad("PAUSED_WORLD_MOUNT_REQUIRED")
	var bound: Dictionary = _root_state(_identity).bind(_battle, _pending_root, _trusted.content_version, _unit_plan.id_to_unit, _unit_plan.expired_unit, {"quiescent": true, "input_released": true})
	if not bound.ok: return _abort(bound, "root_install")
	var ground: Dictionary = _visual.bind_ground_fire_owner(_battle, _battle._ground_fire_visuals)
	if not ground.ok: return _abort(ground, "ground_fire_install")
	_mount_frame = {"clock": _battle._run_clock, "physics": bound.bound_physics_frame, "process": bound.bound_process_frame}
	_battle.set_meta("_run_core_clock_bound", _mount_frame.duplicate())
	parent.add_child(_battle)
	if not _battle.gameplay_rng_fault().is_empty(): return _abort(_bad("PREPARED_READY_FAULT"), "mount")
	var hud: Dictionary = _hud_module.finish()
	if not hud.ok: return _abort(hud, "hud_finish")
	if not _battle._prepared_clock_entry_valid(): return _abort(_bad("INSTALL_FRAME_CHANGED"), "mount")
	return {"ok": true, "battle": _battle, "hud_module": _hud_module, "bound_physics_frame": bound.bound_physics_frame, "bound_process_frame": bound.bound_process_frame, "requires_same_turn_install_and_activate": true, "complete_world": false, "gameplay_activated": false}

func _register_visual_textures() -> void:
	# Current installed Art owns these resources. Saved tokens never select a loader.
	var tree: Variant = Engine.get_main_loop()
	if not tree is SceneTree: return
	var art: Variant = tree.root.get_node_or_null("Art")
	if art == null or art.get_script() != preload("res://scripts/art_db.gd"): return
	for style: String in art.ITEM_CELLS:
		_add_visual_texture("item:" + style, art.item_texture(style))
	for style: String in art.ABILITY_PROJECTILE_CELLS:
		_add_visual_texture("projectile:" + style, art.ability_projectile_texture(style))
	for style: String in art.ABILITY_IMPACT_CELLS:
		_add_visual_texture("impact:" + style, art.ability_impact_texture(style))
	for key: String in _runtime.get("defs", {}):
		if _runtime.defs[key].get("building", false) != true: continue
		var texture: Texture2D = art.building_texture(key)
		if texture == null: texture = art.terrain_texture(key)
		_add_visual_texture("building:" + key, texture)
	if _axe_texture == null:
		_axe_texture = art.item_texture("axe")
		if _axe_texture == null: _axe_texture = art.ability_projectile_texture("axe")

func _add_visual_texture(key: String, texture: Texture2D) -> void:
	# Explicit caller entries keep their identity, including conflicting symbolic keys.
	if texture != null and not _textures.has(key): _textures[key] = texture

func activate_components(root_node: Dictionary) -> Dictionary:
	# Internal final phase. The caller retains the old HELD world until success.
	if _activated or not is_instance_valid(_battle) or not _battle.is_inside_tree() or not _battle.get_tree().paused or Engine.is_in_physics_frame() or not _battle._prepared_clock_entry_valid() or _battle._save_barrier != null: return _bad("WORLD_ACTIVATION_PHASE")
	var checked: Dictionary = _visual._check_node(root_node)
	if not checked.ok: return checked
	for row: Dictionary in _unit_plan.activation_plan:
		var unit: Variant = row.unit
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or not unit.is_node_ready() or unit.get_parent() != _battle.units_root or unit.battle != _battle or str(unit.entity_id) != row.entity_id or not unit.is_blocking_signals() or unit.process_mode != Node.PROCESS_MODE_DISABLED: return _bad("PREPARED_UNIT_CHANGED")
		for signal_name: String in ["died", "story_resolved"]:
			if not unit.get_signal_connection_list(signal_name).is_empty(): return _bad("PREPARED_UNIT_SIGNAL_CHANGED")
	_identity.release_tombstones(); _visual.release_expired_fx()
	for row: Dictionary in _unit_plan.activation_plan:
		row.unit.died.connect(Callable(_battle, "_on_unit_died"))
		row.unit.story_resolved.connect(Callable(_battle, "_on_unit_story_resolved"))
		checked = _unit_checker.activate(row.unit, row.activation)
		if not checked.ok: return checked
	checked = _visual.activate()
	if not checked.ok: return checked
	checked = _fog_module.activate(_battle, _fog_plan.activation)
	if not checked.ok: return checked
	checked = _display.activate()
	if not checked.ok: return checked
	checked = _camera_module.activate()
	if not checked.ok: return checked
	checked = _environment.activate()
	if not checked.ok: return checked
	checked = _hud_module.activate()
	if not checked.ok: return checked
	# Environment order is checked before adding the new clock edge controller.
	_battle._save_barrier = preload("res://scripts/run_battle_barrier.gd").new()
	_battle._save_barrier.configure(_battle, _battle._run_clock)
	_battle.add_child(_battle._save_barrier)
	checked = _battle._run_clock.activate_restored(Engine.get_physics_frames())
	if not checked.ok: return checked
	_visual._assign_node(_battle, root_node)
	var a: Dictionary = root_node.activation
	_battle.process_priority = a.priority; _battle.process_physics_priority = a.physics_priority
	_battle.set_process(a.process); _battle.set_physics_process(a.physics); _battle.set_process_input(a.input)
	_battle.set_process_shortcut_input(a.shortcut); _battle.set_process_unhandled_input(a.unhandled_input); _battle.set_process_unhandled_key_input(a.unhandled_key)
	_battle.set_block_signals(a.signals_blocked); _battle.process_mode = a.mode
	_battle.remove_meta("_run_core_prepared"); _battle.remove_meta("_run_core_clock_bound")
	_activated = true
	return {"ok": true, "battle": _battle, "tree_still_paused": true}

func handoff_world() -> Dictionary:
	if not _activated or not _owns_world or not is_instance_valid(_battle): return _bad("WORLD_HANDOFF_PHASE")
	_owns_world = false
	var identity: Variant = _identity; _identity = null
	return {"ok": true, "battle": _battle, "identity": identity}
