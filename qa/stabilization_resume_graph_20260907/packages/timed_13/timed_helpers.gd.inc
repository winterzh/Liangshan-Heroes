## Explicit additions: no arbitrary property enumeration, class construction or resource loading.
func _timed_check(v: Dictionary, kind: String) -> Dictionary:
	if kind not in TIMED_KINDS: return {"ok": true}
	for key: String in ["dur", "t"] + TIMED_FLOATS[kind]:
		if typeof(v[key]) != TYPE_FLOAT or not is_finite(v[key]): return _failure("TIMED_FLOAT", key)
	if v.dur <= 0.0 or v.t <= 0.0 or v.t > v.dur: return _failure("TIMED_LIFETIME", kind)
	if kind != "building_collapse":
		if typeof(v.col) != TYPE_COLOR: return _failure("TIMED_COLOR")
		for part: float in [v.col.r, v.col.g, v.col.b, v.col.a]:
			if not is_finite(part): return _failure("TIMED_COLOR")
	if kind in ["meteor", "ground_fire", "ward", "arrow_rain", "flameburst", "ability"] and (v.rad < 0.0 or v.rad > 8192.0): return _failure("TIMED_RADIUS")
	if kind in ["meteor", "ground_fire", "ward"] and (v.life <= 0.0 or v.dur != v.life): return _failure("TIMED_LIFE")
	if kind in ["ground_fire", "ward"] and typeof(v.lite) != TYPE_BOOL: return _failure("TIMED_LITE")
	match kind:
		"meteor":
			for key: String in ["start_w", "end_w"]:
				if typeof(v[key]) != TYPE_VECTOR2 or not v[key].is_finite(): return _failure("METEOR_POINT", key)
			return _particle_rows(v._embers, 14, [], ["a", "d", "sp", "ph"], "meteor.embers")
		"ground_fire":
			var n: int = (5 + int(v.rad / 20.0)) if v.lite else (10 + int(v.rad / 10.0))
			var e: int = (3 + int(v.rad / 18.0)) if v.lite else (int(v.rad / 8.0) + 6)
			var flames: Dictionary = _particle_rows(v._flames, n, ["p"], ["h", "w", "ph", "rate"], "ground_fire.flames")
			if not flames.ok: return flames
			return _particle_rows(v._embers, e, ["p"], ["ph", "spd", "drift"], "ground_fire.embers")
		"ward":
			if typeof(v.style) != TYPE_STRING or v.style not in ["heal", "death", "poison", "attack", "banner"]: return _failure("WARD_STYLE")
			if typeof(v.banner_kind) != TYPE_STRING or v.banner_kind not in ["", "loyalty", "righteous"]: return _failure("WARD_BANNER")
			var current: Dictionary = _ward_signature(v.style)
			if not current.ok: return current
			if current.value != v.ward_visual: return _failure("WARD_TEXTURE_CHANGED")
		"arrow_shot":
			if typeof(v.pin) != TYPE_BOOL or typeof(v.big) != TYPE_BOOL or v.travel <= 0.0 or v.travel >= v.dur: return _failure("ARROW_SHOT_TRAVEL")
			for key: String in ["end_w", "_E"]:
				if typeof(v[key]) != TYPE_VECTOR2 or not v[key].is_finite(): return _failure("ARROW_SHOT_POINT", key)
		"arrow_rain":
			return _particle_rows(v._arrows, 18, ["p"], ["delay"], "arrow_rain.arrows")
		"flameburst":
			var flames: Dictionary = _particle_rows(v._flames, 9 + int(v.rad / 14.0), ["p"], ["delay", "h", "w", "ph"], "flameburst.flames")
			if not flames.ok: return flames
			return _particle_rows(v._embers, 12, ["p"], ["delay", "spd", "drift"], "flameburst.embers")
		"ability":
			if typeof(v._seed) != TYPE_INT: return _failure("ABILITY_SEED")
		"building_collapse":
			if v.s <= 0.0 or v.s > 8192.0: return _failure("COLLAPSE_SIZE")
			return _texture_check(v.tex)
	return {"ok": true}

func _particle_rows(value: Variant, count: int, vectors: Array, floats: Array, path: String) -> Dictionary:
	if typeof(value) != TYPE_ARRAY or count > LIMIT or value.size() != count: return _failure("PARTICLE_COUNT", path)
	for row: Variant in value:
		if typeof(row) != TYPE_DICTIONARY or not _fields(row, vectors + floats): return _failure("PARTICLE_FIELDS", path)
		for key: String in vectors:
			if typeof(row[key]) != TYPE_VECTOR2 or not row[key].is_finite(): return _failure("PARTICLE_POINT", path + "." + key)
		for key: String in floats:
			if typeof(row[key]) != TYPE_FLOAT or not is_finite(row[key]): return _failure("PARTICLE_FLOAT", path + "." + key)
		for key: String in ["delay", "d"]:
			if row.has(key) and row[key] < 0.0: return _failure("PARTICLE_NEGATIVE", path + "." + key)
		for key: String in ["h", "w", "rate", "spd", "sp"]:
			if row.has(key) and row[key] <= 0.0: return _failure("PARTICLE_NONPOSITIVE", path + "." + key)
	return {"ok": true}

func _texture_signature(texture: Variant, depth: int = 0) -> Dictionary:
	if depth > 3 or not texture is Texture2D or texture.get_script() != null: return _failure("TRUSTED_TEXTURE_TYPE")
	if texture.get_width() <= 0 or texture.get_height() <= 0: return _failure("TRUSTED_TEXTURE_SIZE")
	if texture is AtlasTexture:
		var base: Dictionary = _texture_signature(texture.atlas, depth + 1)
		if not base.ok: return base
		return {"ok": true, "value": {"kind": "atlas", "base": base.value, "region_position": texture.region.position, "region_size": texture.region.size,
			"margin_position": texture.margin.position, "margin_size": texture.margin.size, "filter_clip": texture.filter_clip,
			"width": texture.get_width(), "height": texture.get_height()}}
	if texture.get_class() != "CompressedTexture2D" or not (texture.resource_path.begins_with("res://assets/") or texture.resource_path.begins_with("res://content/art/")) or not ResourceLoader.exists(texture.resource_path): return _failure("TRUSTED_TEXTURE_RESOURCE")
	return {"ok": true, "value": {"kind": "resource", "path": String(texture.resource_path), "width": texture.get_width(), "height": texture.get_height()}}

func _texture_token(texture: Variant) -> Dictionary:
	if texture == null: return {"ok": true, "value": {"state": "none"}}
	for key: Variant in _textures:
		if typeof(key) != TYPE_STRING or key.is_empty() or key.length() > 128 or "/" in key or "\\" in key: return _failure("TRUSTED_TEXTURE_KEY")
		if is_same(texture, _textures[key]):
			var signature: Dictionary = _texture_signature(texture)
			if not signature.ok: return signature
			return {"ok": true, "value": {"state": "trusted", "key": key, "signature": signature.value}}
	return _failure("COLLAPSE_TEXTURE_UNREGISTERED")

func _texture_check(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or typeof(value.get("state")) != TYPE_STRING: return _failure("TEXTURE_TOKEN")
	if value.state == "none":
		return {"ok": true} if _fields(value, ["state"]) else _failure("TEXTURE_TOKEN")
	if value.state != "trusted" or not _fields(value, ["state", "key", "signature"]) or typeof(value.key) != TYPE_STRING or not _textures.has(value.key): return _failure("TEXTURE_TOKEN_KEY")
	var current: Dictionary = _texture_token(_textures[value.key])
	if not current.ok: return current
	if current.value != value: return _failure("TRUSTED_TEXTURE_CHANGED")
	return {"ok": true}

func _timed_node_supported(node: Node2D, kind: String) -> Dictionary:
	if kind not in TIMED_KINDS: return {"ok": true}
	# The actual eight creators use these inherited defaults. Reject overrides.
	if node.material != null or node.use_parent_material or node.texture_filter != CanvasItem.TEXTURE_FILTER_PARENT_NODE or node.texture_repeat != CanvasItem.TEXTURE_REPEAT_PARENT_NODE or node.light_mask != 1 or node.visibility_layer != 1 or node.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED: return _failure("TIMED_RENDER_OVERRIDE", kind)
	if kind == "building_collapse":
		var texture: Dictionary = _texture_token(node.tex)
		if not texture.ok: return texture
	if kind == "ward":
		var texture: Dictionary = _ward_signature(node.style)
		if not texture.ok: return texture
	if not node.is_node_ready() or node.has_meta("_run_restore_prepared"): return _failure("TIMED_READY_BARRIER", kind)
	return {"ok": true}

func _ward_signature(style: String) -> Dictionary:
	var tree: Variant = Engine.get_main_loop()
	if not tree is SceneTree: return _failure("WARD_ART_REQUIRED")
	var art: Variant = tree.root.get_node_or_null("Art")
	if art == null or art.get_script() == null or art.get_script().resource_path != "res://scripts/art_db.gd": return _failure("WARD_ART_REQUIRED")
	var texture: Texture2D = art.ward_texture(style)
	if texture == null: return {"ok": true, "value": {"state": "none"}}
	var signature: Dictionary = _texture_signature(texture)
	if not signature.ok: return signature
	return {"ok": true, "value": {"state": "content", "signature": signature.value}}

func _ground_count(rows: Array) -> int:
	var count := 0
	for row: Dictionary in rows:
		if row.kind == "ground_fire": count += 1
	return count

func _capture_ground_owner(root: Node2D, rows: Array) -> Dictionary:
	var count: int = _ground_count(rows)
	if count == 0 and _owner == null: return {"ok": true}
	if not is_instance_valid(_owner) or _owner.get_script() != _battle or _owner.fx_root != root or _owner._ground_fire_visuals != count: return _failure("GROUND_FIRE_OWNER_COUNT")
	var expected := Callable(_owner, "_on_ground_fire_visual_exited")
	for object: Node2D in _objects:
		if _kind(object) != "ground_fire": continue
		var connections: Array = object.get_signal_connection_list("tree_exited")
		if connections.size() != 1 or connections[0].callable != expected or int(connections[0].flags) != 0: return _failure("GROUND_FIRE_EXIT_CONNECTION")
	return {"ok": true}

func bind_ground_fire_owner(owner: Variant, expected_count: int) -> Dictionary:
	if _committed or _ground_bound or not is_instance_valid(_root) or _root.is_inside_tree(): return _failure("GROUND_FIRE_BIND_PHASE")
	if typeof(owner) != TYPE_OBJECT or not is_instance_valid(owner) or owner.get_script() != _battle or owner.is_inside_tree() or owner.is_queued_for_deletion() or owner.fx_root != _root: return _failure("GROUND_FIRE_BIND_OWNER")
	var count: int = _ground_count(_records.values())
	if expected_count != count or owner._ground_fire_visuals != count: return _failure("GROUND_FIRE_OWNER_COUNT")
	for node: Node2D in _nodes.values():
		if _kind(node) == "ground_fire" and not node.get_signal_connection_list("tree_exited").is_empty(): return _failure("GROUND_FIRE_ALREADY_CONNECTED")
	_owner = owner
	for node: Node2D in _nodes.values():
		if _kind(node) == "ground_fire": node.tree_exited.connect(Callable(owner, "_on_ground_fire_visual_exited"))
	_ground_bound = true
	return {"ok": true, "count": count}
