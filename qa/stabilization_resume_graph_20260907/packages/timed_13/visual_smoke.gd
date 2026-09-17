extends SceneTree
## Current creators -> real Unit graph + Fx graph + effect arrays -> JSON -> consumers.
## Battle stays off tree: no menu, level deployment, simulation scheduler or disk resume.
const CONTENT := "stable_remaining_visual_lifecycle_v1"
var checks: Array = []
var failures: Array = []
var owned: Array = []
var contexts: Array = []
var manifest: Dictionary = {}
var report_path := ""
var manifest_ready := false
var scripts: Dictionary = {}
var observations: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _check(label: String, pass_value: bool) -> bool:
	checks.append({"label": label, "passed": pass_value})
	if not pass_value: failures.append(label)
	return pass_value

func _ok(label: String, value: Dictionary) -> bool:
	checks.append({"label": label, "passed": value.get("ok") == true, "code": value.get("code", ""), "field": value.get("field", "")})
	if value.get("ok") != true:
		failures.append(label)
		return false
	return true

func _source_guard(label: String) -> void:
	for path: String in manifest.source_sha256:
		_check(label + " " + path, FileAccess.get_sha256(path) == manifest.source_sha256[path])

func _finish(aborted := false) -> void:
	for context: Variant in contexts: context.dispose()
	for node: Variant in owned:
		if is_instance_valid(node): node.free()
	if manifest_ready: _source_guard("source after")
	var result := {"suite": "remaining-effects-visual-candidate", "run_id": manifest.get("run_id", ""),
		"passed": failures.is_empty() and not aborted, "complete": not aborted, "failures": failures,
		"checks": checks, "check_count": checks.size(), "failed_count": failures.size(), "observations": observations,
		"process_id": OS.get_process_id(), "actual_user_dir": OS.get_user_data_dir(), "source_sha256": manifest.get("source_sha256", {}),
		"scope": "Current real creators, two-Unit full graph, remaining three arrays and five real visual classes survive JSON, paused attachment and fixed consumer/Fx timestep pairs. Off-tree Battles, real baked map, declared fixture placement and fixed timesteps. No whole root/world factory, 17-array visual coverage, full gameplay clock, menu, campaign, cross-process save or player slot."}
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file == null:
			quit(1)
			return
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
	print("[remaining-effects visual candidate QA] ", JSON.stringify(result))
	quit(0 if result.passed else 1)

func _run() -> void:
	var path := OS.get_environment("RUN_RESTORE_QA_MANIFEST")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if not path.is_empty() else null
	if typeof(data) != TYPE_DICTIONARY:
		_check("host manifest present", false)
		_finish(true)
		return
	manifest = data
	for key: String in ["run_id", "private_user", "report", "engine_binary_sha256"]:
		if typeof(manifest.get(key)) != TYPE_STRING or manifest[key].is_empty():
			_check("host manifest " + key, false)
			_finish(true)
			return
	if typeof(manifest.get("source_sha256")) != TYPE_DICTIONARY or manifest.source_sha256.is_empty():
		_check("host source manifest", false)
		_finish(true)
		return
	report_path = manifest.report
	if not report_path.is_absolute_path() or FileAccess.file_exists(report_path):
		_check("fresh absolute report path", false)
		report_path = ""
		_finish(true)
		return
	manifest_ready = true
	_check("private profile", OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower() == manifest.private_user.replace("\\", "/").simplify_path().to_lower())
	_source_guard("source before")
	if not failures.is_empty():
		_finish(true)
		return
	# No preload or game-class annotation in the CLI entry before autoload startup.
	for key: String in ["battle", "unit", "game_map", "hero_inventory", "run_state_value_codec", "run_unit_state", "run_unit_graph", "run_graph_identity", "run_remaining_effect_state", "run_visual_graph"]:
		scripts[key] = load("res://scripts/" + key + ".gd")
	paused = true
	root.get_node("Settings").show_damage = true
	for kind: String in ["bolt", "bolt_expired", "bolt_line", "bolt_line_expired", "hook_out", "hook_drag", "trap", "beast"]:
		if not await _case(kind):
			_finish(true)
			return
	_finish()

func _shell() -> Variant:
	var b: Variant = scripts.battle.new()
	owned.append(b)
	b.set_block_signals(true)
	b.process_mode = Node.PROCESS_MODE_DISABLED
	b.world = Node2D.new()
	b.add_child(b.world)
	b.map = scripts.game_map.new()
	b.map.init_map(64, 64, "marsh", scripts.game_map.T.GRASS)
	b.map.bake()
	b.world.add_child(b.map)
	b.units_root = Node2D.new()
	b.world.add_child(b.units_root)
	return b

func _stage() -> Node2D:
	var stage := Node2D.new()
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	stage.visible = false
	owned.append(stage)
	root.add_child(stage)
	return stage

func _unit(b: Variant, id: int, faction: int, at: Vector2) -> Variant:
	var u: Variant = scripts.unit.new()
	u.entity_id = id
	u.key = "fixture_" + str(id)
	u.display_name = u.key
	u.visible = false
	u.process_mode = Node.PROCESS_MODE_DISABLED
	u.battle = b
	u.map = b.map
	u.position = at
	u.faction = faction
	u.hp = 1000.0
	u.max_hp = 1000.0
	u.radius = 12.0
	u.base_speed = 120.0
	u._base_speed = 120.0
	u.stance = 3
	b.units_root.add_child(u)
	b.units.append(u)
	b.next_entity_id = id + 1
	return u

func _identity_call(identity: Variant, operation: String, value: Variant) -> Dictionary:
	return identity.call(operation, "_chase_last_id", value)

func _effects(identity: Variant, visuals: Variant) -> Variant:
	return scripts.run_remaining_effect_state.new(scripts.run_state_value_codec, scripts.battle, scripts.unit,
		func(v): return _identity_call(identity, "encode_identity", v),
		func(v): return _identity_call(identity, "validate_identity", v),
		func(v): return _identity_call(identity, "decode_identity", v),
		visuals.encode_token, visuals.validate_token, visuals.decode_token)

func _step(b: Variant, delta: float) -> void:
	# Exact existing consumers, with no SceneTree scheduler or movement claim.
	b._bolt_pass(delta)
	b._trap_pass(delta)
	b._zone_pass(delta)
	for fx: Variant in b.fx_root.get_children():
		if is_instance_valid(fx) and not fx.is_queued_for_deletion() and fx.has_method("_process"):
			fx._process(delta)

func _case(kind: String) -> bool:
	var source: Variant = _shell()
	var target: Variant = _shell()
	var stage: Node2D = _stage()
	var target_stage: Node2D = _stage()
	target_stage.transform = stage.transform
	_check(kind + " independent same-transform fixture parents", stage != target_stage and stage.global_transform == target_stage.global_transform)
	source.fx_root = Node2D.new()
	source.fx_root.name = "FxRoot"
	source.fx_root.z_index = 7
	source.fx_root.transform = Transform2D(Vector2(1.0, 0.13), Vector2(0.22, 0.8), Vector2(3.5, -2.25))
	stage.add_child(source.fx_root)
	var trusted := {"ok": true, "save_eligible": true, "content_version": CONTENT, "engine_binary_sha256": manifest.engine_binary_sha256}
	if not _ok(kind + " source RNG", source.configure_new_gameplay_rng(trusted, 631245)): return false
	var caster: Variant = _unit(source, 1, 0, Vector2(300, 300))
	var foe: Variant = _unit(source, 2, 1, Vector2(500, 300))
	var ad := {"color": Color(0.71, 0.53, 0.99)}
	var eff := {"dmg": 35.0, "stun": 0.3, "len": 400.0, "width": 30.0, "proj_speed": 200.0}
	if kind.begins_with("bolt_line"):
		source._spawn_bolt_line(caster, foe.position, ad, eff, 1.0, 1)
	elif kind.begins_with("bolt"):
		source._spawn_bolt(caster, foe, ad, eff, 1.0, 1)
	elif kind.begins_with("hook"):
		source._spawn_hook(caster, foe.position, ad, eff, 1.0, 1)
	elif kind == "trap":
		source._place_trap("trap_pit", foe.position, 0)
	elif kind == "beast":
		foe.position = Vector2(365, 300)
		source._do_beast_stampede(caster, {"dmg": 40.0, "len": 320.0, "width": 80.0, "push": 0.0, "slow": 0.7, "slow_dur": 2.0, "proj_speed_mult": 1.5}, 1.0, 1, Vector2(700, 300), 1)
	# Advance creators into unfinished states using their actual consumer bodies.
	var warm := 0.9 if kind == "hook_drag" else (0.375 if kind == "beast" else 0.125)
	source._bolt_pass(warm)
	source._trap_pass(warm)
	source._zone_pass(warm)
	for fx: Variant in source.fx_root.get_children():
		if fx.has_method("_process"): fx._process(0.025)
	await process_frame
	if kind == "hook_drag":
		if not _check("real hook enters drag before snapshot", not source._bolts.is_empty() and source._bolts[0].mode == "hook_drag"): return false
	if kind.ends_with("expired"):
		source.units.erase(caster)
		caster.free()
	var ids: Dictionary = {}
	for u: Variant in source.units_root.get_children(): ids[u] = str(u.entity_id)
	var graph: Variant = scripts.run_unit_graph.new(scripts.run_unit_state, scripts.run_graph_identity, scripts.run_state_value_codec, scripts.unit, scripts.hero_inventory, scripts.battle, scripts.game_map)
	var captured_units: Dictionary = graph.capture(source, ids, CONTENT)
	if not _ok(kind + " actual Unit graph capture", captured_units): return false
	contexts.append(captured_units.identity)
	var old_visual: Variant = scripts.run_visual_graph.new(scripts.run_state_value_codec, scripts.battle, scripts.unit)
	contexts.append(old_visual)
	var old_fx: Dictionary = old_visual.capture(source.fx_root, CONTENT, ids)
	if not _ok(kind + " complete supported visual capture", old_fx): return false
	var old_effect: Variant = _effects(captured_units.identity, old_visual)
	var old_arrays: Dictionary = old_effect.capture(source, CONTENT, ids)
	if not _ok(kind + " actual unfinished arrays capture", old_arrays): return false
	var unit_wire: Variant = JSON.parse_string(JSON.stringify(captured_units.value))
	var visual_wire: Variant = JSON.parse_string(JSON.stringify(old_fx.value))
	var effect_wire: Variant = JSON.parse_string(JSON.stringify(old_arrays.record))
	if kind == "bolt": _negative_visual_cases(visual_wire, ids, old_visual)
	var prepared: Dictionary = graph.prepare(unit_wire, CONTENT, target, target.map)
	if not _ok(kind + " full Unit fields prepare from JSON", prepared): return false
	contexts.append(prepared.identity)
	for unit: Variant in prepared.units_in_root_order: target.units_root.add_child(unit)
	target.units = prepared.active_units
	target.next_entity_id = prepared.pending_battle_fields.next_entity_id
	var restored_rng: Dictionary = source.capture_gameplay_rng()
	if not _ok(kind + " RNG snapshot", restored_rng): return false
	if not _ok(kind + " RNG restore", target.configure_restored_gameplay_rng(trusted, JSON.parse_string(JSON.stringify(restored_rng.record)))): return false
	var new_visual: Variant = scripts.run_visual_graph.new(scripts.run_state_value_codec, scripts.battle, scripts.unit)
	contexts.append(new_visual)
	var visual_prepared: Dictionary = new_visual.prepare(visual_wire, CONTENT, prepared.id_to_unit, prepared.identity.expired_unit())
	if not _ok(kind + " real visual nodes prepare from JSON", visual_prepared): return false
	target.fx_root = visual_prepared.root
	var new_effect: Variant = _effects(prepared.identity, new_visual)
	if not _ok(kind + " arrays bind same shared Fx and Unit graph", new_effect.bind(target, effect_wire, CONTENT, prepared.id_to_unit, prepared.identity.expired_unit())): return false
	if not source._bolts.is_empty():
		_check(kind + " consumer Fx reference belongs to reconstructed graph", target._bolts[0].fx == new_visual.decode_token(old_visual.encode_token(source._bolts[0].fx, "bolt").value, "bolt").value)
		if kind.begins_with("hook"):
			_check(kind + " chain reference binds exact restored caster", target._bolts[0].fx.chain_from == prepared.id_to_unit["1"])
	if kind == "trap":
		_check("trap consumer shares real marker and preserves arming state", target._traps[0].fx.get_script() == scripts.battle.TrapMarkerFx and target._traps[0].arm_t == source._traps[0].arm_t and target._traps[0].fx.armed == source._traps[0].fx.armed)
	prepared.identity.release_tombstones()
	new_visual.release_expired_fx()
	target_stage.add_child(target.fx_root)
	_check(kind + " distinct parents preserve exact FxRoot names", source.fx_root.get_parent() != target.fx_root.get_parent() and source.fx_root.name == &"FxRoot" and target.fx_root.name == &"FxRoot")
	if not _ok(kind + " activate exact paused visual graph", new_visual.activate()): return false
	var target_ids: Dictionary = {}
	for id: String in prepared.id_to_unit: target_ids[prepared.id_to_unit[id]] = id
	var after_ready: Dictionary = new_visual.capture(target.fx_root, CONTENT, target_ids)
	_check(kind + " attachment ready never resets time pack or seed", after_ready.ok and after_ready.value == old_fx.value)
	var target_foe: Variant = prepared.id_to_unit["2"]
	var health_before := float(target_foe.hp)
	var changes: Array = []
	var equivalent := true
	for step: int in range(1, 42):
		var hp_before := float(target_foe.hp)
		_step(source, 0.125)
		_step(target, 0.125)
		await process_frame
		if target_foe.hp != hp_before: changes.append(step)
		var old: Dictionary = old_effect.capture(source, CONTENT, ids)
		var now: Dictionary = new_effect.capture(target, CONTENT, target_ids)
		# Re-register visual tokens after each real deferred deletion/new impact.
		var ov: Dictionary = old_visual.capture(source.fx_root, CONTENT, ids)
		var nv: Dictionary = new_visual.capture(target.fx_root, CONTENT, target_ids)
		old = old_effect.capture(source, CONTENT, ids)
		now = new_effect.capture(target, CONTENT, target_ids)
		equivalent = equivalent and old.ok and now.ok and old.record == now.record and ov.ok and nv.ok and ov.value == nv.value and foe.hp == target_foe.hp and foe.position == target_foe.position and foe._stun_t == target_foe._stun_t and source.gameplay_rng_fault().is_empty() and target.gameplay_rng_fault().is_empty()
	_check(kind + " 41 consumer and visual lifecycle pairs stay equal", equivalent)
	_check(kind + " effect and visual finish without replay", target._bolts.is_empty() and target._traps.is_empty() and target._gong_lines.is_empty() and target.fx_root.get_child_count() == 0)
	_check(kind + " at most one future damage settlement", changes.size() <= 1)
	if kind != "beast" and kind != "trap": _check(kind + " future hit actually occurs", changes.size() == 1 and target_foe.hp == health_before - 35.0)
	if kind == "trap": _check("trap arms then actual stun occurs", target_foe._stun_t > 0.0)
	if kind == "beast": _check("already hit beast target is never hit twice", health_before == 960.0 and changes.is_empty() and target_foe.hp == 960.0)
	_check(kind + " RNG stream did not change in visual restore", source.capture_gameplay_rng().record == target.capture_gameplay_rng().record)
	observations[kind] = {"future_hit_steps": changes, "health_at_snapshot": health_before, "health_final": target_foe.hp, "visual_count_at_snapshot": old_fx.count, "visual_count_final": target.fx_root.get_child_count()}
	return true

func _negative_visual_cases(wire: Dictionary, ids: Dictionary, source_visual: Variant) -> void:
	var codec: Variant = scripts.run_state_value_codec.new()
	var raw: Array = codec.decode(wire.records).value
	var known: Dictionary = {}
	for id: String in ids.values(): known[id] = true
	for mutation: String in ["parent", "sibling", "unknown_kind", "trail", "extra", "ref"]:
		var rows: Array = raw.duplicate(true)
		match mutation:
			"parent": rows[1].parent = rows[1].id
			"sibling": rows[1].index = 7
			"unknown_kind": rows[1].kind = "arbitrary_script"
			"trail": rows[1].values._trail = [Vector2.INF]
			"extra": rows[1].values["extra_unknown"] = 1
			"ref": rows[1].references.chain_from = {"state": "entity", "id": "999"}
		var encoded: Dictionary = codec.encode(rows)
		if not encoded.ok:
			_check("nonfinite visual rejected before JSON " + mutation, mutation == "trail")
			continue
		var bad: Dictionary = wire.duplicate(true)
		bad.records = encoded.value
		var validator: Variant = scripts.run_visual_graph.new(scripts.run_state_value_codec, scripts.battle, scripts.unit)
		contexts.append(validator)
		_check("malformed visual graph rejects " + mutation, not validator.validate(bad, CONTENT, known).ok and validator._nodes.is_empty())
	_check("shared Fx token refuses wrong expected class", not source_visual.validate_token({"state": "node", "id": "2"}, "trap_marker").ok)
	var unsupported := Node2D.new()
	var actual_unsupported: Variant = scripts.battle.StompFx.new()
	unsupported.add_child(actual_unsupported)
	var unsupported_graph: Variant = scripts.run_visual_graph.new(scripts.run_state_value_codec, scripts.battle, scripts.unit)
	contexts.append(unsupported_graph)
	_check("unsupported real effect fails instead of disappearing", unsupported_graph.capture(unsupported, CONTENT, ids).get("code") == "UNSUPPORTED_VISUAL_SCRIPT")
	unsupported.free()
