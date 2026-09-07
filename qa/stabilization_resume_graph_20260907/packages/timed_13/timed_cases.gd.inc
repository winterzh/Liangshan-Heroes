func _meteor_state(identity: Variant) -> Variant:
	return scripts.run_meteor_wards_state.new(scripts.run_state_value_codec, scripts.battle, scripts.unit,
		func(v): return _identity_call(identity, "encode_identity", v),
		func(v): return _identity_call(identity, "validate_identity", v),
		func(v): return _identity_call(identity, "decode_identity", v))

func _step(b: Variant, delta: float) -> void:
	b._zone_pass(delta)
	b._ground_dot_pass(delta)
	b._ward_pass(delta)
	for fx: Variant in b.fx_root.get_children():
		if is_instance_valid(fx) and not fx.is_queued_for_deletion() and fx.has_method("_process"): fx._process(delta)

func _case(kind: String) -> bool:
	var source: Variant = _shell()
	var target: Variant = _shell()
	var stage: Node2D = _stage()
	var target_stage: Node2D = _stage()
	target_stage.transform = stage.transform
	_check(kind + " independent same-transform fixture parents", stage != target_stage and stage.global_transform == target_stage.global_transform)
	source.fx_root = Node2D.new()
	source.fx_root.name = "FxRoot"
	source.fx_root.transform = Transform2D(Vector2(1.0, 0.13), Vector2(0.22, 0.8), Vector2(3.5, -2.25))
	stage.add_child(source.fx_root)
	var trusted := {"ok": true, "save_eligible": true, "content_version": CONTENT, "engine_binary_sha256": manifest.engine_binary_sha256}
	if not _ok(kind + " source gameplay RNG", source.configure_new_gameplay_rng(trusted, 5088120)): return false
	var caster: Variant = _unit(source, 1, 0, Vector2(300, 300))
	var foe: Variant = _unit(source, 2, 1, Vector2(450, 300))
	caster.hp = 500.0
	var ad := {"color": Color(0.71, 0.53, 0.99), "radius": 75.0}
	var textures: Dictionary = {}
	seed(173010)
	match kind:
		"meteor":
			source._do_meteor(caster, {"impact_ranks": [35.0], "dps_ranks": [12.0], "len": 240.0, "roll_speed": 120.0, "width": 64.0, "dot_dur": 1.0}, 1, Vector2(700, 300), 1)
		"ground_fire", "ground_fire_lite":
			source._lite_fx = kind.ends_with("lite")
			source._spawn_ground_fire(foe.position, 68.0, 48.0, 2.0, caster, 1)
		"ward_heal", "ward_loyalty", "ward_righteous", "ward_attack_boundary":
			var eff := {"ward_mode": "heal", "ward_dur": 2.0, "ward_radius": 200.0, "pulse": 0.5, "heal": 11.0, "dmg": 13.0}
			if kind in ["ward_loyalty", "ward_righteous"]:
				eff["ward_mode"] = "banner"
				eff["banner_variants"] = ["loyalty" if kind == "ward_loyalty" else "righteous"]
				eff["troop_reduction_ranks"] = [0.15]
				eff["atkspeed_ranks"] = [1.2]
			if kind == "ward_attack_boundary": eff["ward_mode"] = "attack"
			source._do_ward(caster, eff, 1, caster.position, 0, 1, ad)
		"arrow_shot_flight", "arrow_shot_impact":
			source._spawn_hero_skill_fx("hua_shot", caster, foe.position, ad)
		"arrow_rain": source._spawn_hero_skill_fx("hua_rain", caster, foe.position, ad)
		"flameburst":
			_check("actual smite selects flameburst", source._spawn_smite_variant_fx(foe.position, 75.0, {"dot_total": 40.0}, ad))
		"ability": source._spawn_ability_fx(foe.position, 75.0, ad.color)
		"building_collapse":
			# Actual death creator. Only unrelated empty-selection HUD fields are fixture nodes.
			source.phase = scripts.battle.Phase.DEPLOY
			source.hud = scripts.hud.new()
			source.hud.battle = source
			source.add_child(source.hud)
			for field: String in ["_info_name", "_info_hp", "_info_stats", "_port_char"]:
				var label := Label.new()
				source.hud.add_child(label)
				source.hud.set(field, label)
			source.hud._port_tex = TextureRect.new()
			source.hud.add_child(source.hud._port_tex)
			var building: Variant = _unit(source, 3, 0, Vector2(600, 300))
			building.key = "barracks"
			building.is_building = true
			building.hp = 0.0
			var texture: Texture2D = root.get_node("Art").building_texture("barracks")
			if not _check("actual building has trusted native art", texture != null): return false
			textures["building:barracks"] = texture
			source._on_unit_died(building)
			if not _check("actual building creator queues victim", building.is_queued_for_deletion()): return false
	# Warm actual visuals, then selected gameplay consumers. Attack remains before first pulse.
	var warm := 0.30 if kind == "arrow_shot_impact" else 0.08
	for fx: Variant in source.fx_root.get_children():
		if fx.has_method("_process"): fx._process(warm)
	if kind == "meteor":
		source._zone_pass(0.125)
		for fx: Variant in source.fx_root.get_children():
			if fx.has_method("_process"): fx._process(0.025)
	if kind in ["ground_fire", "ground_fire_lite"]: source._ground_dot_pass(0.125)
	await process_frame
	var ids: Dictionary = {}
	for u: Variant in source.units_root.get_children(): ids[u] = str(u.entity_id)
	var graph: Variant = scripts.run_unit_graph.new(scripts.run_unit_state, scripts.run_graph_identity, scripts.run_state_value_codec, scripts.unit, scripts.hero_inventory, scripts.battle, scripts.game_map)
	var uc: Dictionary = graph.capture(source, ids, CONTENT)
	if not _ok(kind + " actual Unit graph", uc): return false
	contexts.append(uc.identity)
	var old_visual: Variant = scripts.run_visual_graph.new(scripts.run_state_value_codec, scripts.battle, scripts.unit, source, textures)
	contexts.append(old_visual)
	var vc: Dictionary = old_visual.capture(source.fx_root, CONTENT, ids)
	if not _ok(kind + " actual midlife visual graph", vc): return false
	var expected_class: String = {"meteor": "meteor", "ground_fire": "ground_fire", "ground_fire_lite": "ground_fire", "ward_heal": "ward", "ward_loyalty": "ward", "ward_righteous": "ward", "ward_attack_boundary": "ward", "arrow_shot_flight": "arrow_shot", "arrow_shot_impact": "arrow_shot", "arrow_rain": "arrow_rain", "flameburst": "flameburst", "ability": "ability", "building_collapse": "building_collapse"}[kind]
	var expected_present := false
	for fx: Variant in source.fx_root.get_children(): expected_present = expected_present or old_visual._kind(fx) == expected_class
	if not _check(kind + " actual requested class is present before JSON", expected_present): return false
	var old_meteor: Variant = _meteor_state(uc.identity)
	var old_ground: Variant = scripts.run_continuous_effect_state.new(scripts.run_state_value_codec, scripts.battle, scripts.unit)
	var mc: Dictionary = old_meteor.capture(source, CONTENT, ids)
	var gc: Dictionary = old_ground.capture(source, CONTENT, ids)
	if not _ok(kind + " meteor wards authority", mc) or not _ok(kind + " ground authority", gc): return false
	var wire: Dictionary = JSON.parse_string(JSON.stringify(vc.value))
	_timed_negatives(kind, wire, textures, old_visual, ids)
	var up: Dictionary = graph.prepare(JSON.parse_string(JSON.stringify(uc.value)), CONTENT, target, target.map)
	if not _ok(kind + " Unit JSON prepare", up): return false
	contexts.append(up.identity)
	for u: Variant in up.units_in_root_order: target.units_root.add_child(u)
	target.units = up.active_units
	target.next_entity_id = up.pending_battle_fields.next_entity_id
	target._ward_serial = source._ward_serial
	target._ground_fire_visuals = source._ground_fire_visuals
	target._lite_fx = source._lite_fx
	if not _ok(kind + " gameplay RNG restore", target.configure_restored_gameplay_rng(trusted, JSON.parse_string(JSON.stringify(source.capture_gameplay_rng().record)))): return false
	var new_visual: Variant = scripts.run_visual_graph.new(scripts.run_state_value_codec, scripts.battle, scripts.unit, null, textures)
	contexts.append(new_visual)
	seed(940133)
	var expected_global_next: int = randi()
	seed(940133)
	var vp: Dictionary = new_visual.prepare(wire, CONTENT, up.id_to_unit, up.identity.expired_unit())
	if not _ok(kind + " real timed Fx JSON prepare", vp): return false
	target.fx_root = vp.root
	_check(kind + " wrong owner count rejects before connection", not new_visual.bind_ground_fire_owner(target, target._ground_fire_visuals + 1).ok)
	if not _ok(kind + " explicit ground owner signal bind including empty graph", new_visual.bind_ground_fire_owner(target, target._ground_fire_visuals)): return false
	_check(kind + " second bind refuses duplicate callback", not new_visual.bind_ground_fire_owner(target, target._ground_fire_visuals).ok)
	var new_meteor: Variant = _meteor_state(up.identity)
	var new_ground: Variant = scripts.run_continuous_effect_state.new(scripts.run_state_value_codec, scripts.battle, scripts.unit)
	if not _ok(kind + " meteor wards bind exact restored units", new_meteor.bind(target, JSON.parse_string(JSON.stringify(mc.record)), CONTENT, up.id_to_unit, up.identity.expired_unit())): return false
	if not _ok(kind + " ground bind exact restored units", new_ground.bind(target, JSON.parse_string(JSON.stringify(gc.record)), CONTENT, up.id_to_unit, up.identity.expired_unit())): return false
	up.identity.release_tombstones()
	new_visual.release_expired_fx()
	target_stage.add_child(target.fx_root)
	_check(kind + " distinct parents preserve exact FxRoot names", source.fx_root.get_parent() != target.fx_root.get_parent() and source.fx_root.name == &"FxRoot" and target.fx_root.name == &"FxRoot")
	if not _ok(kind + " paused visual activation", new_visual.activate()): return false
	_check(kind + " restore ready consumes no global visual RNG", randi() == expected_global_next)
	var target_ids: Dictionary = {}
	for id: String in up.id_to_unit: target_ids[up.id_to_unit[id]] = id
	var reread: Dictionary = new_visual.capture(target.fx_root, CONTENT, target_ids)
	_check(kind + " ready preserves all prior phase particles and texture", reread.ok and reread.value == vc.value)
	if kind == "building_collapse":
		_check("collapse restores same trusted Art AtlasTexture", is_same(target.fx_root.get_child(0).tex, textures["building:barracks"]))
	if kind == "ward_attack_boundary":
		# Actual attack consumer creates BlinkShotFx, deliberately outside these eight.
		var hp_before: float = up.id_to_unit["2"].hp
		target._ward_pass(0.5)
		var has_blink := false
		for fx: Variant in target.fx_root.get_children(): has_blink = has_blink or fx.get_script() == scripts.battle.BlinkShotFx
		_check("attack ward consumes damage then creates real unsupported BlinkShotFx", up.id_to_unit["2"].hp == hp_before - 13.0 and has_blink)
		_check("future unsupported attack visual refuses whole snapshot", new_visual.capture(target.fx_root, CONTENT, target_ids).get("code") == "UNSUPPORTED_VISUAL_SCRIPT")
		observations[kind] = {"boundary": "Next snapshot after attack pulse requires BlinkShotFx factory; no node omitted."}
		return true
	var equal := true
	var disappearance_steps: Array = []
	var last_count: int = target.fx_root.get_child_count()
	for step: int in range(1, 66):
		# Future creation uses the same declared test-only global visual seed per pair.
		# This does not claim the engine's global visual RNG is a saved gameplay stream.
		seed(770000 + step)
		_step(source, 0.125)
		seed(770000 + step)
		_step(target, 0.125)
		await process_frame
		var ov: Dictionary = old_visual.capture(source.fx_root, CONTENT, ids)
		var nv: Dictionary = new_visual.capture(target.fx_root, CONTENT, target_ids)
		var om: Dictionary = old_meteor.capture(source, CONTENT, ids)
		var nm: Dictionary = new_meteor.capture(target, CONTENT, target_ids)
		var og: Dictionary = old_ground.capture(source, CONTENT, ids)
		var ng: Dictionary = new_ground.capture(target, CONTENT, target_ids)
		equal = equal and ov.ok and nv.ok and ov.value == nv.value and om.ok and nm.ok and om.record == nm.record and og.ok and ng.ok and og.record == ng.record
		equal = equal and caster.hp == up.id_to_unit["1"].hp and foe.hp == up.id_to_unit["2"].hp and source._ground_fire_visuals == target._ground_fire_visuals and source.capture_gameplay_rng().record == target.capture_gameplay_rng().record
		if target.fx_root.get_child_count() < last_count: disappearance_steps.append(step)
		last_count = target.fx_root.get_child_count()
	_check(kind + " 65 paired actual consumer and visual steps remain equal", equal)
	_check(kind + " all timed nodes authority and ground count expire", target.fx_root.get_child_count() == 0 and target._ground_fire_visuals == 0 and target._meteor_zones.is_empty() and target._wards.is_empty() and target._ground_dots.is_empty())
	_check(kind + " real disappearance observed", not disappearance_steps.is_empty())
	_check(kind + " no gameplay RNG fault", source.gameplay_rng_fault().is_empty() and target.gameplay_rng_fault().is_empty())
	if kind == "meteor" or kind.begins_with("ground_fire"):
		_check(kind + " actual future damage consumed", foe.hp < 1000.0)
	if kind in ["ward_heal", "ward_loyalty"]: _check(kind + " actual future healing consumed", caster.hp > 500.0)
	observations[kind] = {"snapshot_nodes": vc.count, "disappearance_steps": disappearance_steps, "caster_hp": caster.hp, "foe_hp": foe.hp,
		"final_ground_count": target._ground_fire_visuals, "future_visual_randomness": "paired explicit test seeds; not full global RNG save"}
	return true

func _timed_negatives(kind: String, wire: Dictionary, textures: Dictionary, old_visual: Variant, ids: Dictionary) -> void:
	var codec: Variant = scripts.run_state_value_codec.new()
	var raw: Array = codec.decode(wire.records).value
	var known: Dictionary = {}
	for id: String in ids.values(): known[id] = true
	for mutation: String in ["unknown", "extra", "expired", "nonfinite", "particle", "texture", "texture_geometry", "ward_texture"]:
		var rows: Array = raw.duplicate(true)
		var row: Dictionary = rows[1]
		match mutation:
			"unknown": row.kind = "res://arbitrary.gd"
			"extra": row.values["surprise"] = 1
			"expired": row.values.t = 0.0
			"nonfinite": row.values.t = INF
			"particle":
				if row.values.has("_embers"): row.values._embers.pop_back()
				elif row.values.has("_arrows"): row.values._arrows[0]["missing_shape"] = 0.0
				else: continue
			"texture":
				if kind != "building_collapse": continue
				row.values.tex = {"state": "trusted", "key": "user://escape.png", "signature": {}}
			"texture_geometry":
				if kind != "building_collapse": continue
				row.values.tex.signature.width += 1
			"ward_texture":
				if row.kind != "ward": continue
				row.values.ward_visual = {"state": "missing_or_changed"}
		var enc: Dictionary = codec.encode(rows)
		if not enc.ok:
			_check(kind + " nonfinite rejected by unchanged codec", mutation == "nonfinite")
			continue
		var bad: Dictionary = wire.duplicate(true)
		bad.records = enc.value
		var validator: Variant = scripts.run_visual_graph.new(scripts.run_state_value_codec, scripts.battle, scripts.unit, null, textures)
		contexts.append(validator)
		_check(kind + " malformed timed graph rejects before allocation " + mutation, not validator.prepare(bad, CONTENT, {}).ok and validator._nodes.is_empty())
	_check(kind + " StringName still rejected by value codec", not codec.encode({&"chain_from": {"state": "none"}}).ok)
	if kind == "building_collapse":
		var missing: Variant = scripts.run_visual_graph.new(scripts.run_state_value_codec, scripts.battle, scripts.unit)
		contexts.append(missing)
		_check("missing trusted collapse texture rejects allocation", not missing.prepare(wire, CONTENT, {}).ok and missing._nodes.is_empty())
		var fake_root := Node2D.new()
		var fake: Variant = scripts.battle.BuildingCollapseFx.new()
		fake.tex = GradientTexture2D.new()
		fake_root.add_child(fake)
		_check("runtime generated unregistered texture is refused", old_visual.capture(fake_root, CONTENT, ids).get("code") == "COLLAPSE_TEXTURE_UNREGISTERED")
		fake_root.free()
	if kind == "ability":
		var root_with_child := Node2D.new()
		var fx: Variant = scripts.battle.AbilityFx.new()
		root_with_child.add_child(fx)
		fx.add_child(Node2D.new(), false, Node.INTERNAL_MODE_FRONT)
		_check("internal child cannot disappear from timed snapshot", old_visual.capture(root_with_child, CONTENT, ids).get("code") == "UNSUPPORTED_INTERNAL_VISUAL")
		root_with_child.free()
