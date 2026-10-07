extends RefCounted
## Installed Level8 lighting subcomponent, not a complete scenery/world adapter.
## Factory owns node creation and sharing; only its Cuiyun energy is mutable.
const Codec := preload("res://scripts/run_state_value_codec.gd")
const Scenery := preload("res://scripts/campaign_scenery.gd")
const Level8 := preload("res://scripts/levels/level8_daming_rts.gd")
const BattleScript := preload("res://scripts/battle.gd")
const CONTEXT := {"mode": "campaign", "level_id": "level8", "waves": 0}
const MARKET_CELLS := [Vector2i(27, 12), Vector2i(33, 20), Vector2i(27, 27), Vector2i(34, 33)]
var _content_version := ""
var _context: Dictionary = {}

func _init(content_version: String, trusted_context: Dictionary) -> void:
	if not content_version.strip_edges().is_empty() and content_version.length() <= 256:
		_content_version = content_version
	_context = trusted_context.duplicate(true)

func capture(visual: Node2D) -> Dictionary:
	var trusted: Dictionary = _trusted()
	if not trusted.ok: return trusted
	var owned: Dictionary = _owners(visual)
	if not owned.ok: return owned
	var gradient: Dictionary = _gradient(visual._lantern_texture)
	if not gradient.ok: return gradient
	var energies: Array = []
	for index: int in owned.value.lamps:
		energies.append(visual.get_child(index - 1, true).energy)
	var encoded: Dictionary = Codec.new().encode({"ownership": owned.value, "gradient": gradient.value, "energies": energies})
	if not encoded.ok: return _bad("DAMING_LIGHT_CODEC")
	var snapshot := {"schema": "daming_lighting_v1", "content_version": _content_version,
		"context": {"mode": "campaign", "level_id": "level8"}, "payload": encoded.value}
	var checked: Dictionary = validate(snapshot)
	if not checked.ok: return checked
	return {"ok": true, "value": snapshot, "complete_world": false}

func validate(snapshot: Variant) -> Dictionary:
	var trusted: Dictionary = _trusted()
	if not trusted.ok: return trusted
	if not _fields(snapshot, ["schema", "content_version", "context", "payload"]) \
			or snapshot.schema != "daming_lighting_v1" or typeof(snapshot.content_version) != TYPE_STRING \
			or snapshot.content_version != _content_version: return _bad("DAMING_LIGHT_SCHEMA")
	if not _fields(snapshot.context, ["mode", "level_id"]) or typeof(snapshot.context.mode) != TYPE_STRING \
			or snapshot.context.mode != "campaign" or typeof(snapshot.context.level_id) != TYPE_STRING \
			or snapshot.context.level_id != "level8": return _bad("DAMING_LIGHT_CONTEXT")
	var decoded: Dictionary = Codec.new().decode(snapshot.payload)
	if not decoded.ok: return _bad("DAMING_LIGHT_CODEC")
	var value: Variant = decoded.value
	if not _fields(value, ["ownership", "gradient", "energies"]) \
			or not _fields(value.ownership, ["night", "lamps", "cuiyun"]) \
			or typeof(value.ownership.lamps) != TYPE_ARRAY or value.ownership.lamps.size() != 5 \
			or typeof(value.energies) != TYPE_ARRAY or value.energies.size() != 5: return _bad("DAMING_LIGHT_PAYLOAD")
	var seen := {}
	for index: Variant in value.ownership.lamps:
		if typeof(index) != TYPE_INT or index < 2 or index > 4095 or seen.has(index): return _bad("DAMING_LIGHT_OWNER")
		seen[index] = true
	if typeof(value.ownership.night) != TYPE_INT or value.ownership.night != 1 \
			or typeof(value.ownership.cuiyun) != TYPE_INT or value.ownership.cuiyun != value.ownership.lamps[4]: return _bad("DAMING_LIGHT_OWNER")
	var canonical: Dictionary = _gradient(_canonical_gradient())
	if not canonical.ok or value.gradient != canonical.value: return _bad("DAMING_LIGHT_GRADIENT")
	for i: int in range(5):
		var energy: Variant = value.energies[i]
		if typeof(energy) != TYPE_FLOAT or not is_finite(energy): return _bad("DAMING_LIGHT_ENERGY")
		if i < 4 and energy != _energy(0.55): return _bad("DAMING_MARKET_ENERGY")
		if i == 4 and energy not in [_energy(0.45), _energy(1.15)]: return _bad("DAMING_CUIYUN_ENERGY")
	return {"ok": true, "value": value}

func apply_into(visual: Node2D, snapshot: Variant) -> Dictionary:
	# All input and factory checks precede mutation. No saved path selects a resource.
	var checked: Dictionary = validate(snapshot)
	if not checked.ok: return checked
	if not is_instance_valid(visual) or visual.is_inside_tree(): return _bad("PRIVATE_DAMING_LIGHT_FACTORY_REQUIRED")
	var current: Dictionary = capture(visual)
	if not current.ok: return current
	var original: Dictionary = validate(current.value)
	if not original.ok: return original
	if original.value.ownership != checked.value.ownership or original.value.gradient != checked.value.gradient:
		return _bad("DAMING_LIGHT_FACTORY_CHANGED")
	for i: int in range(5):
		visual.get_child(checked.value.ownership.lamps[i] - 1, true).energy = checked.value.energies[i]
	return {"ok": true, "complete_world": false, "factory_resources_reused": true}

func _trusted() -> Dictionary:
	if _content_version.is_empty(): return _bad("CONTENT_VERSION_REQUIRED")
	if not _fields(_context, ["mode", "level_id", "waves"]) or _context != CONTEXT \
			or typeof(_context.mode) != TYPE_STRING or typeof(_context.level_id) != TYPE_STRING \
			or typeof(_context.waves) != TYPE_INT: return _bad("TRUSTED_DAMING_LIGHT_CONTEXT_REQUIRED")
	return {"ok": true}

func _owners(visual: Node2D) -> Dictionary:
	if not is_instance_valid(visual) or visual.get_script() != Scenery or visual._style != "level8": return _bad("DAMING_LIGHT_SCENERY")
	var map = visual._map
	if not is_instance_valid(map) or map.get_script() != preload("res://scripts/game_map.gd") \
			or map.w != 60 or map.h != 66 or map.theme != "town" or map.environment_style != "level8" \
			or typeof(map.get_meta("campaign_city_wicket_sealed", null)) != TYPE_BOOL \
			or map.get_meta("campaign_city_wicket_sealed") != true or visual.get_parent() != map \
			or map.sample_scenery != visual: return _bad("DAMING_LIGHT_MAP")
	var world: Node = map.get_parent()
	var battle: Node = null if world == null else world.get_parent()
	if battle == null or battle.get_script() != BattleScript or visual._battle != battle \
			or battle.get("map") != map or not is_instance_valid(battle.get("level")) \
			or battle.get("level").get_script() != Level8: return _bad("DAMING_LIGHT_BATTLE")
	var owners := {"night": -1, "lamps": [], "cuiyun": -1}
	var cells: Array = MARKET_CELLS.duplicate()
	cells.append(Vector2i(37, 15))
	for i: int in range(visual.get_child_count(true)):
		var node: Node = visual.get_child(i, true)
		if node is CanvasModulate:
			if owners.night != -1 or i != 0 or node.get_script() != null or node.name != &"LanternNight" \
					or node.color != Color(0.62, 0.67, 0.79) or node.get_child_count(true) != 0: return _bad("DAMING_NIGHT_FACTORY")
			owners.night = i + 1
		elif node is PointLight2D:
			var slot: int = owners.lamps.size()
			if slot >= 5 or node.get_script() != null or node.get_child_count(true) != 0 \
					or node.position != map.cell_to_world(cells[slot]) or node.texture != visual._lantern_texture \
					or node.color != Color(1.0, 0.68, 0.32) or node.shadow_enabled: return _bad("DAMING_LAMP_FACTORY")
			var probe := PointLight2D.new()
			probe.texture_scale = 1.8
			probe.color = Color(1.0, 0.68, 0.32)
			probe.shadow_enabled = false
			var scale_matches := true
			# Check all Light2D/PointLight2D settings, including defaults. Generic
			# node flags/transforms remain the outer scenery adapter's responsibility.
			for property: Dictionary in probe.get_property_list():
				var key: String = String(property.name)
				if not (int(property.usage) & PROPERTY_USAGE_STORAGE): continue
				if key.begins_with("range_") or key.begins_with("shadow_") \
						or key in ["enabled", "blend_mode", "height", "offset", "texture_scale", "color"]:
					if node.get(key) != probe.get(key): scale_matches = false
			probe.free()
			if not scale_matches: return _bad("DAMING_LAMP_SETTINGS")
			owners.lamps.append(i + 1)
			if slot == 4:
				if node != visual._cuiyun_light: return _bad("DAMING_CUIYUN_OWNER")
				owners.cuiyun = i + 1
	if owners.night != 1 or owners.lamps.size() != 5: return _bad("DAMING_LIGHT_COUNT")
	return {"ok": true, "value": owners}

func _canonical_gradient() -> GradientTexture2D:
	# Mirrors the fixed production constructor. Stored defaults are inspected too,
	# so an alternate interpolation/offset/HDR/repeat mode cannot pass silently.
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(0, 0, 0, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128; texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5); texture.fill_to = Vector2(0.5, 1.0)
	return texture

func _gradient(texture: Variant) -> Dictionary:
	if not texture is GradientTexture2D or not texture.gradient is Gradient: return _bad("DAMING_LIGHT_GRADIENT_TYPE")
	var actual := {"texture": {}, "gradient": {}}
	var expected := {"texture": {}, "gradient": {}}
	var canonical := _canonical_gradient()
	for key: String in ["texture", "gradient"]:
		var source: Resource = texture if key == "texture" else texture.gradient
		var reference: Resource = canonical if key == "texture" else canonical.gradient
		if source.get_script() != null or not source.resource_path.is_empty() or not source.get_meta_list().is_empty(): return _bad("DAMING_LIGHT_FOREIGN_RESOURCE")
		for property: Dictionary in reference.get_property_list():
			var name: String = String(property.name)
			if not (int(property.usage) & PROPERTY_USAGE_STORAGE) or name in ["script", "gradient"]: continue
			var a: Variant = source.get(name); var b: Variant = reference.get(name)
			if typeof(a) != typeof(b): return _bad("DAMING_LIGHT_GRADIENT_PROPERTY", name)
			if typeof(a) in [TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_COLOR_ARRAY]:
				a = Array(a); b = Array(b)
			actual[key][name] = a; expected[key][name] = b
	if actual != expected: return _bad("DAMING_LIGHT_GRADIENT_CHANGED")
	return {"ok": true, "value": actual}

func _energy(value: float) -> float:
	var node := PointLight2D.new()
	node.energy = value
	var result: float = node.energy
	node.free()
	return result

func _fields(value: Variant, names: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != names.size(): return false
	for name: String in names:
		if not value.has(name): return false
	return true

func _bad(code: String, field := "") -> Dictionary:
	return {"ok": false, "code": code, "field": field}

func default_light_settings() -> Dictionary:
	var probe := PointLight2D.new()
	probe.texture_scale = 1.8; probe.color = Color(1.0, 0.68, 0.32); probe.shadow_enabled = false
	var value: Dictionary = _light_settings_values(probe)
	probe.free()
	return value

func light_settings(node: PointLight2D) -> Dictionary:
	var value: Dictionary = _light_settings_values(node)
	if value != default_light_settings(): return _bad("DAMING_LAMP_SETTINGS")
	return {"ok": true, "value": value}

func _light_settings_values(node: PointLight2D) -> Dictionary:
	var base := Node2D.new(); var inherited := {}
	for property: Dictionary in base.get_property_list(): inherited[String(property.name)] = true
	base.free()
	var result := {}
	for property: Dictionary in node.get_property_list():
		var name: String = String(property.name)
		if not (int(property.usage) & PROPERTY_USAGE_STORAGE) or inherited.has(name) or name in ["texture", "energy"]: continue
		result[name] = node.get(name)
	return result
