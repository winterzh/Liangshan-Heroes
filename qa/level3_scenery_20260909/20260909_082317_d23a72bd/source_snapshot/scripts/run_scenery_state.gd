extends RefCounted
## Standard Liangshan plus an explicitly trusted Level3-only factory. The factory is the fixed production
## Scenery.setup, audited to write its own descendants, map.material and one
## map metadata value only. Its RNG instances have fixed local seeds; it never
## calls paint/bake/deploy, registers footprints, or changes Battle gameplay.
## Restore runs synchronously on a detached Battle/world/map tree. No _process
## executes. Rebuilt structure and fixed values must match before runtime values
## are applied. The campaign branch keeps a separate schema, strict Level3
## context and a retained disabled activation plan; it is not world acceptance.
const Codec := preload("res://scripts/run_state_value_codec.gd")
const Scenery := preload("res://scripts/liangshan_scenery.gd")
const CampaignScenery := preload("res://scripts/campaign_scenery.gd")
const Level3 := preload("res://scripts/levels/level3_zhujiazhuang_rts.gd")
const BattleScript := preload("res://scripts/battle.gd")
const CAMPAIGN_CONTEXT := {"mode": "campaign", "level_id": "level3", "waves": 0}
const CAMPAIGN_SCHEMA := "level3_scenery_state_v1"
const CAMPAIGN_KINDS := ["campaign_scenery", "story_sign", "ground_overlay", "sprite", "stockade", "flag", "art"]
const CAMPAIGN_META := ["campaign_object", "campaign_environment_state", "campaign_environment_fallback_key"]
const LEVEL3_WALLS := [[Vector2(20, 0), Vector2(20, 16)], [Vector2(20, 20), Vector2(20, 26)], [Vector2(20, 30), Vector2(20, 55)]]
const NAV_NAMES := ["astar", "astar_guan", "astar_water", "astar_static", "astar_static_guan"]
const Entrance := preload("res://scripts/liangshan_entrance.gd")
const Gate := preload("res://scripts/liangshan_gate.gd")
const Stockade := preload("res://scripts/liangshan_stockade.gd")
const Flag := preload("res://scripts/campaign_flag_overlay.gd")
const ArtEvent := preload("res://scripts/campaign_art_event.gd")
const CoastShader := preload("res://scripts/liangshan_coast.gdshader")
const MAX_NODES := 4096
const MAX_BINARY_BYTES := 8388608
const CHUNK_BYTES := 16384
const NODE_META := ["fog_clearance_px", "render_height", "campaign_environment_route", "campaign_environment_static_flag"]
const FIXED_FIELDS := {
	"scenery": [], "campaign_scenery": ["_style"], "story_sign": ["size", "label"], "ground_overlay": ["size"],
	"entrance": ["_gate_cell", "_east_gate_cell", "_rts_layout"],
	"sprite": ["size", "foot", "is_tree"],
	"gate": ["lintel", "facing", "simple", "plaque_text", "replacement_owner", "replacement_size",
		"replacement_foot", "replacement_text_rect", "closed_leaf_end"],
	"stockade": ["end_local", "salt", "height_scale", "campaign_route", "campaign_visible_bbox"],
	"flag": ["_static_marker", "_visual_size", "_foot", "_static_level_id", "_static_decor_key", "_static_rect_override", "_static_text_only"],
	"art": ["size", "foot", "duration"]}
const RUNTIME_FIELDS := {"scenery": ["_visibility_tick"], "campaign_scenery": ["_visibility_tick"], "story_sign": [], "ground_overlay": [], "entrance": ["_tick"], "sprite": [],
	"gate": ["sealed"], "stockade": [], "flag": [], "art": ["life"]}
const TEX_FIELDS := {"scenery": [], "campaign_scenery": [], "story_sign": [], "ground_overlay": ["tex"], "entrance": ["_stockade_texture", "_dock_straight_texture", "_dock_head_texture"],
	"sprite": ["tex"], "gate": ["replacement_texture"], "stockade": ["campaign_texture"], "flag": [], "art": ["texture"]}
const UNIFORMS := ["land_mask", "surface_weights", "terrain_atlas", "terrain_atlas2", "surface_forest_texture",
	"surface_dry_texture", "surface_wet_texture", "surface_hard_texture", "surface_field_texture",
	"use_surface_forest_texture", "use_surface_dry_texture", "use_surface_wet_texture", "use_surface_hard_texture",
	"use_surface_field_texture", "map_size", "water_region", "shore_region", "grass_region", "road_region",
	"dry_region", "field_region", "grass_tint", "dry_tint", "wet_tint", "hard_tint", "field_tint",
	"height_map", "height_enabled", "coast_enabled", "natural_surface_enabled", "elevation_scale",
	"natural_blend_min_px", "natural_blend_max_px", "natural_warp_px", "natural_seed", "scene_tint"]
## Host QA provenance enumeration only. Runtime compatibility uses the trusted
## constructor version and fixed ResourceLoader/preload identities, including
## exports where original .gd source files are unavailable.
const SOURCE_PATHS := ["res://scripts/liangshan_scenery.gd", "res://scripts/liangshan_entrance.gd",
	"res://scripts/liangshan_gate.gd", "res://scripts/liangshan_stockade.gd", "res://scripts/campaign_flag_overlay.gd",
	"res://scripts/campaign_art_event.gd", "res://scripts/liangshan_coast.gdshader", "res://scripts/liangshan_layout.gd",
	"res://scripts/campaign_scenery.gd", "res://scripts/campaign_environment.gd", "res://scripts/campaign_environment_art.gd",
	"res://scripts/campaign_height.gd", "res://scripts/campaign_art.gd", "res://scripts/levels/level3_zhujiazhuang_rts.gd"]
var _content_version: String = ""
var _trusted_context: Dictionary = {}
var _campaign_owner: GameMap = null
var _campaign_visual: Node2D = null
var _campaign_activation: Dictionary = {}
var _campaign_record: Dictionary = {}
var _campaign_order: Array = []
var _campaign_activated := false
var _campaign_used := false


func _init(content_version: String, trusted_context: Dictionary = {}) -> void:
	# The root transaction supplies the installed content identity. A snapshot
	# must never choose it; an empty/invalid identity disables this adapter.
	if not content_version.strip_edges().is_empty() and content_version.length() <= 256:
		_content_version = content_version
	_trusted_context = trusted_context.duplicate(true)


func capture(game_map: GameMap) -> Dictionary:
	if _content_version.is_empty(): return _fail("CONTENT_VERSION_REQUIRED", "$/display/content_version")
	var campaign: bool = _campaign_enabled()
	if not _trusted_context.is_empty() and not campaign: return _fail("TRUSTED_CAMPAIGN_CONTEXT_UNSUPPORTED")
	if campaign:
		var context_check: Dictionary = _campaign_map(game_map)
		if not context_check.ok: return context_check
		if game_map.sample_scenery == null: return _fail("CAMPAIGN_SCENERY_REQUIRED")
	if game_map.sample_scenery == null:
		if game_map.get_child_count(true) != 0 or game_map.material != null: return _fail("UNSUPPORTED_PLAIN_MAP_DISPLAY")
		return {"ok": true, "value": {"schema": "scenery_state_v2", "content_version": _content_version, "kind": "none"}}
	if game_map.sample_scenery.get_script() != (CampaignScenery if campaign else Scenery):
		return _fail("CAMPAIGN_SCENERY_REQUIRED" if campaign else "STANDARD_SCENERY_REQUIRED")
	if campaign:
		var ownership: Dictionary = _campaign_arrays(game_map.sample_scenery, game_map)
		if not ownership.ok: return ownership
	if game_map.get_child_count(true) != 1 or game_map.sample_scenery.get_parent() != game_map:
		return _fail("SCENERY_OWNERSHIP")
	if not game_map.material is ShaderMaterial or game_map.material.shader != CoastShader:
		return _fail("COAST_MATERIAL_REQUIRED")
	var records: Array = []
	var walked: Dictionary = _capture_nodes(game_map.sample_scenery, -1, records)
	if not walked.ok: return walked
	var parameters: Dictionary = _capture_material(game_map.material, game_map.height_field)
	if not parameters.ok: return parameters
	var reed: Dictionary = _capture_reed(game_map.sample_scenery)
	if not reed.ok: return reed
	var snapshot := {"schema": CAMPAIGN_SCHEMA if campaign else "scenery_state_v2", "content_version": _content_version, "kind": "campaign_level3" if campaign else "liangshan", "nodes": records,
		"material": parameters.value, "reed": reed.value}
	if campaign: snapshot["context"] = _trusted_context.duplicate(true)
	var checked: Dictionary = validate(snapshot)
	if not checked.ok: return checked
	return {"ok": true, "value": snapshot}


func validate(snapshot: Variant) -> Dictionary:
	if _content_version.is_empty(): return _fail("CONTENT_VERSION_REQUIRED", "$/display/content_version")
	var campaign: bool = _campaign_enabled()
	if not _trusted_context.is_empty() and not campaign: return _fail("TRUSTED_CAMPAIGN_CONTEXT_UNSUPPORTED")
	if typeof(snapshot) != TYPE_DICTIONARY or snapshot.get("schema") != (CAMPAIGN_SCHEMA if campaign else "scenery_state_v2"):
		return _fail("SCENERY_SCHEMA")
	if typeof(snapshot.get("content_version")) != TYPE_STRING or snapshot.content_version != _content_version:
		return _fail("CONTENT_VERSION_MISMATCH", "$/display/content_version")
	if not campaign and _fields(snapshot, ["schema", "content_version", "kind"]) and snapshot.kind == "none": return {"ok": true}
	var envelope: Array = ["schema", "content_version", "kind", "nodes", "material", "reed"]
	if campaign: envelope.append("context")
	if campaign and not _saved_campaign_context_valid(snapshot.get("context")): return _fail("CAMPAIGN_CONTEXT_MISMATCH")
	if not _fields(snapshot, envelope) or snapshot.kind != ("campaign_level3" if campaign else "liangshan"):
		return _fail("SCENERY_SCHEMA")
	if typeof(snapshot.nodes) != TYPE_ARRAY or snapshot.nodes.is_empty() or snapshot.nodes.size() > MAX_NODES:
		return _fail("SCENERY_NODE_COUNT")
	var codec := Codec.new()
	for i in range(snapshot.nodes.size()):
		var decoded: Dictionary = codec.decode(snapshot.nodes[i])
		if not decoded.ok: return _fail("SCENERY_NODE_CODEC", str(i))
		var record: Variant = decoded.value
		if not _fields(record, ["parent", "kind", "fixed", "runtime", "textures", "metadata"]): return _fail("SCENERY_NODE_FIELDS", str(i))
		if typeof(record.parent) != TYPE_INT or record.parent < -1 or record.parent >= i \
				or (i == 0 and record.parent != -1) or (i > 0 and record.parent == -1) \
				or typeof(record.kind) != TYPE_STRING or record.kind not in FIXED_FIELDS:
			return _fail("SCENERY_NODE_IDENTITY", str(i))
		if campaign and record.kind not in CAMPAIGN_KINDS: return _fail("CAMPAIGN_NODE_KIND", str(i))
		if not campaign and record.kind in ["campaign_scenery", "story_sign", "ground_overlay"]: return _fail("CAMPAIGN_CONTEXT_REQUIRED")
		if i == 0 and record.kind != ("campaign_scenery" if campaign else "scenery"): return _fail("SCENERY_ROOT")
		if campaign and i > 0 and record.parent != 0: return _fail("CAMPAIGN_DIRECT_CHILD_REQUIRED", str(i))
		var fixed_names: Array = ["transform", "z_index", "z_as_relative", "self_modulate", "texture_filter", "texture_repeat"]
		fixed_names.append_array(FIXED_FIELDS[record.kind])
		var runtime_names: Array = ["visible", "modulate", "processing", "physics_processing", "process_mode", "process_priority"]
		runtime_names.append_array(RUNTIME_FIELDS[record.kind])
		if not _fields(record.fixed, fixed_names) or not _fields(record.runtime, runtime_names) \
				or not _fields(record.textures, TEX_FIELDS[record.kind]) or typeof(record.metadata) != TYPE_DICTIONARY:
			return _fail("SCENERY_NODE_SCHEMA", str(i))
		if not _canvas_valid(record.fixed, record.runtime): return _fail("SCENERY_CANVAS_VALUE", str(i))
		if not _fixed_values_valid(record.kind, record.fixed): return _fail("SCENERY_FIXED_VALUE", str(i))
		for key in record.metadata:
			if typeof(key) != TYPE_STRING or not _meta_allowed(String(key)): return _fail("SCENERY_META", str(i))
			if key in ["fog_clearance_px", "render_height"]:
				if not _finite_number(record.metadata[key]): return _fail("SCENERY_META_NUMBER", str(i))
			elif typeof(record.metadata[key]) != TYPE_STRING or record.metadata[key].length() > 256:
				return _fail("SCENERY_META_TEXT", str(i))
		for key in RUNTIME_FIELDS[record.kind]:
			var value: Variant = record.runtime[key]
			if key == "sealed":
				if typeof(value) != TYPE_BOOL: return _fail("SCENERY_SEALED", str(i))
			elif typeof(value) != TYPE_FLOAT or not is_finite(value): return _fail("SCENERY_TIME", str(i))
		if record.kind == "art" and (typeof(record.fixed.duration) != TYPE_FLOAT or record.fixed.duration >= 0.0):
			return _fail("SCENERY_EVENT_NOT_STATIC", str(i))
		for key in record.textures:
			if not _texture_descriptor_valid(record.textures[key]): return _fail("SCENERY_TEXTURE", str(i))
	if not _fields(snapshot.material, UNIFORMS): return _fail("COAST_UNIFORMS")
	for key in UNIFORMS:
		var decoded: Dictionary = codec.decode(snapshot.material[key])
		if not decoded.ok or not _parameter_valid(decoded.value) or not _parameter_matches_uniform(key, decoded.value):
			return _fail("COAST_PARAMETER", key)
	return _validate_reed(snapshot.reed)


func restore_into(game_map: GameMap, snapshot: Variant) -> Dictionary:
	var checked: Dictionary = validate(snapshot)
	if not checked.ok: return checked
	if snapshot.kind == "none": return {"ok": true, "complete": true}
	var campaign: bool = _campaign_enabled()
	if not _trusted_context.is_empty() and not campaign: return _fail("TRUSTED_CAMPAIGN_CONTEXT_UNSUPPORTED")
	if campaign:
		if _campaign_used: return _fail("CAMPAIGN_ADAPTER_ALREADY_USED")
		var context_check: Dictionary = _campaign_map(game_map)
		if not context_check.ok: return context_check
	if game_map.is_inside_tree() or game_map.sample_scenery != null or game_map.get_child_count(true) != 0:
		return _fail("PRIVATE_EMPTY_SCENERY_REQUIRED")
	var world: Node = game_map.get_parent()
	if world == null or world.get_parent() == null or world.get_parent().is_inside_tree(): return _fail("PRIVATE_BATTLE_WORLD_BINDING_REQUIRED")
	var battle: Node = world.get_parent()
	if battle.get("map") != game_map or typeof(battle.get("fog")) != TYPE_BOOL \
			or not battle.has_method("is_explored_world") or typeof(battle.get("_vision")) != TYPE_PACKED_BYTE_ARRAY:
		return _fail("PRIVATE_BATTLE_BINDINGS")
	var prior_contract: Variant = game_map.get_meta("natural_surface_contract") if game_map.has_meta("natural_surface_contract") else null
	var prior_gameplay: Dictionary = {}
	if campaign:
		prior_gameplay = _campaign_gameplay_guard(game_map)
		if not prior_gameplay.ok: return prior_gameplay
		# An allocated transaction is single-use, including rollback after failure.
		_campaign_used = true
	var visual: Node2D = CampaignScenery.new() if campaign else Scenery.new()
	game_map.sample_scenery = visual
	game_map.add_child(visual)
	visual.setup(game_map)
	if campaign:
		if _campaign_gameplay_guard(game_map) != prior_gameplay:
			return _discard(game_map, visual, "CAMPAIGN_FACTORY_CHANGED_GAMEPLAY")
		var ownership: Dictionary = _campaign_arrays(visual, game_map)
		if not ownership.ok: return _discard(game_map, visual, ownership.code)
		# Source signs gain this derived height on their first scenery process.
		# It changes only metadata/CanvasItem placement, not logical position.
		for child: Node in visual.get_children(): game_map.sync_render_position(child)
	# setup's only metadata write must reproduce the recorded static contract.
	# Actual scalar/material overrides are restored separately below.
	if prior_contract != null and (not game_map.has_meta("natural_surface_contract") or game_map.get_meta("natural_surface_contract") != prior_contract):
		return _discard(game_map, visual, "NATURAL_SURFACE_CONTRACT_CHANGED")
	var rebuilt_records: Array = []
	var rebuilt_result: Dictionary = _capture_nodes(visual, -1, rebuilt_records)
	if not rebuilt_result.ok: return _discard(game_map, visual, rebuilt_result.code)
	if rebuilt_records.size() != snapshot.nodes.size(): return _discard(game_map, visual, "SCENERY_STRUCTURE_CHANGED")
	var codec := Codec.new()
	var nodes: Array = []
	_walk_nodes(visual, nodes)
	var saved_records: Array = []
	for i in range(nodes.size()):
		var saved: Dictionary = codec.decode(snapshot.nodes[i]).value
		var rebuilt: Dictionary = codec.decode(rebuilt_records[i]).value
		if saved.parent != rebuilt.parent or saved.kind != rebuilt.kind or saved.fixed != rebuilt.fixed \
				or saved.textures != rebuilt.textures or (campaign and saved.metadata != rebuilt.metadata):
			return _discard(game_map, visual, "SCENERY_FIXED_STATE_CHANGED", str(i))
		saved_records.append(saved)
	var material_result: Dictionary = _restore_material(game_map.material, snapshot.material, game_map.height_field)
	if not material_result.ok: return _discard(game_map, visual, material_result.code)
	for i in range(nodes.size()):
		var node: Node2D = nodes[i]
		var saved: Dictionary = saved_records[i]
		for key in node.get_meta_list(): node.remove_meta(key)
		for key in saved.metadata: node.set_meta(key, saved.metadata[key])
		node.visible = saved.runtime.visible
		node.modulate = saved.runtime.modulate
		node.set_process(saved.runtime.processing)
		node.set_physics_process(saved.runtime.physics_processing)
		node.process_mode = saved.runtime.process_mode
		node.process_priority = saved.runtime.process_priority
		for key in RUNTIME_FIELDS[saved.kind]: node.set(key, saved.runtime[key])
		if campaign:
			_campaign_activation[node] = saved.runtime.duplicate(true)
			node.process_mode = Node.PROCESS_MODE_DISABLED
			node.set_block_signals(true)
		# Local position remains logical, while the CanvasItem keeps saved height.
		var transform: Transform2D = node.transform
		transform.origin -= Vector2.ONE * float(saved.metadata.get("render_height", 0.0))
		RenderingServer.canvas_item_set_transform(node.get_canvas_item(), transform)
		node.queue_redraw()
	_restore_reed(visual, snapshot.reed)
	if campaign:
		if _campaign_gameplay_guard(game_map) != prior_gameplay:
			return _discard(game_map, visual, "CAMPAIGN_RESTORE_CHANGED_GAMEPLAY")
		_campaign_owner = game_map; _campaign_visual = visual
		_campaign_record = snapshot.duplicate(true); _campaign_order = nodes.duplicate()
		return {"ok": true, "complete": false, "complete_world": false,
			"restored_nodes": nodes.size(), "factory": "fixed_level3_visual_only",
			"requires_activation": true, "adapter": self}
	return {"ok": true, "complete": true, "restored_nodes": nodes.size(), "factory": "fixed_liangshan_visual_only"}


func _capture_nodes(node: Node2D, parent: int, records: Array) -> Dictionary:
	if records.size() >= MAX_NODES: return _fail("SCENERY_NODE_COUNT")
	var kind: String = _kind(node)
	if kind.is_empty(): return _fail("SCENERY_NODE_UNSUPPORTED")
	if _campaign_enabled():
		var boundary: Dictionary = _campaign_node_boundary(node, kind)
		if not boundary.ok: return boundary
	var fixed := {"transform": [node.transform.x, node.transform.y, node.transform.origin], "z_index": node.z_index,
		"z_as_relative": node.z_as_relative, "self_modulate": node.self_modulate,
		"texture_filter": node.texture_filter, "texture_repeat": node.texture_repeat}
	var runtime := {"visible": node.visible, "modulate": node.modulate, "processing": node.is_processing(),
		"physics_processing": node.is_physics_processing(), "process_mode": node.process_mode, "process_priority": node.process_priority}
	for key in FIXED_FIELDS[kind]: fixed[key] = node.get(key)
	for key in RUNTIME_FIELDS[kind]: runtime[key] = node.get(key)
	if _campaign_activation.has(node): runtime.process_mode = _campaign_activation[node].process_mode
	var textures: Dictionary = {}
	for key in TEX_FIELDS[kind]: textures[key] = _texture_descriptor(node.get(key))
	var metadata: Dictionary = {}
	for key in node.get_meta_list():
		if not _meta_allowed(String(key)): return _fail("SCENERY_META_UNSUPPORTED", String(key))
		metadata[String(key)] = node.get_meta(key)
	var encoded: Dictionary = Codec.new().encode({"parent": parent, "kind": kind, "fixed": fixed,
		"runtime": runtime, "textures": textures, "metadata": metadata})
	if not encoded.ok: return _fail("SCENERY_NODE_CODEC", String(encoded.get("path", "")))
	var index: int = records.size()
	records.append(encoded.value)
	for child in node.get_children(true):
		if not child is Node2D: return _fail("SCENERY_CHILD_UNSUPPORTED")
		var result: Dictionary = _capture_nodes(child, index, records)
		if not result.ok: return result
	return {"ok": true}


func _kind(node: Node2D) -> String:
	if _campaign_enabled():
		if node.get_script() == CampaignScenery: return "campaign_scenery"
		if node.get_script() == CampaignScenery.StorySign: return "story_sign"
		if node.get_script() == CampaignScenery.CampaignGroundOverlay: return "ground_overlay"
		if node is Scenery.ScenerySprite and node.get_script() != Scenery.ScenerySprite: return ""
	if node.get_script() == Scenery: return "scenery"
	if node.get_script() == Entrance: return "entrance"
	if node is Scenery.ScenerySprite: return "sprite"
	if node.get_script() == Gate: return "gate"
	if node.get_script() == Stockade: return "stockade"
	if node.get_script() == Flag: return "flag"
	if node.get_script() == ArtEvent: return "art"
	return ""


func _walk_nodes(node: Node2D, nodes: Array) -> void:
	nodes.append(node)
	for child in node.get_children(true): _walk_nodes(child, nodes)


func _capture_material(material: ShaderMaterial, height: RefCounted) -> Dictionary:
	var parameters: Dictionary = {}
	for name in UNIFORMS:
		var value: Variant = material.get_shader_parameter(name)
		var parameter: Dictionary
		if value is Texture2D:
			if name == "height_map":
				if height == null or value != height.texture: return _fail("COAST_HEIGHT_BINDING")
				parameter = {"kind": "height"}
			elif name in ["land_mask", "surface_weights"]:
				var img: Image = value.get_image()
				if img == null or img.get_format() != Image.FORMAT_RGBA8 or img.has_mipmaps(): return _fail("COAST_IMAGE_FORMAT", name)
				parameter = {"kind": "image", "width": img.get_width(), "height": img.get_height(), "hex": img.get_data().hex_encode()}
			else: parameter = {"kind": "texture", "identity": _texture_descriptor(value)}
		elif typeof(value) == TYPE_VECTOR4:
			parameter = {"kind": "vector4", "value": [value.x, value.y, value.z, value.w]}
		else: parameter = {"kind": "value", "value": value}
		var encoded: Dictionary = Codec.new().encode(parameter)
		if not encoded.ok: return _fail("COAST_PARAMETER_CODEC", name)
		parameters[name] = encoded.value
	return {"ok": true, "value": parameters}


func _restore_material(material: ShaderMaterial, parameters: Dictionary, height: RefCounted) -> Dictionary:
	if material == null or material.shader != CoastShader: return _fail("COAST_MATERIAL_REQUIRED")
	var values: Dictionary = {}
	for name in UNIFORMS:
		var parameter: Dictionary = Codec.new().decode(parameters[name]).value
		match parameter.kind:
			"height":
				if height == null: return _fail("COAST_HEIGHT_BINDING")
				values[name] = height.texture
			"texture":
				var texture: Variant = material.get_shader_parameter(name)
				if _texture_descriptor(texture) != parameter.identity: return _fail("COAST_TEXTURE_CHANGED", name)
				values[name] = texture
			"image":
				var img := Image.create_from_data(parameter.width, parameter.height, false, Image.FORMAT_RGBA8, parameter.hex.hex_decode())
				if img == null or img.is_empty(): return _fail("COAST_IMAGE_CREATE", name)
				values[name] = ImageTexture.create_from_image(img)
			"vector4": values[name] = Vector4(parameter.value[0], parameter.value[1], parameter.value[2], parameter.value[3])
			"value": values[name] = parameter.value
	for name in UNIFORMS: material.set_shader_parameter(name, values[name])
	return {"ok": true}


func _texture_descriptor(texture: Variant) -> Dictionary:
	if texture == null: return {"kind": "none"}
	if texture is AtlasTexture:
		return {"kind": "atlas", "atlas": _texture_descriptor(texture.atlas), "region": [texture.region.position, texture.region.size],
			"margin": [texture.margin.position, texture.margin.size], "filter_clip": texture.filter_clip}
	if texture is Texture2D and not texture.resource_path.is_empty():
		return {"kind": "resource", "path": texture.resource_path, "size": texture.get_size()}
	return {"kind": "unsupported"}


func _texture_descriptor_valid(value: Variant, depth := 0) -> bool:
	if _fields(value, ["kind"]) and value.kind == "none": return true
	if depth > 2 or typeof(value) != TYPE_DICTIONARY or not value.has("kind"): return false
	if value.kind == "resource":
		return _fields(value, ["kind", "path", "size"]) and typeof(value.path) == TYPE_STRING \
			and value.path.begins_with("res://") and value.path.length() <= 1024 and typeof(value.size) == TYPE_VECTOR2 and value.size.is_finite()
	if value.kind == "atlas":
		if not _fields(value, ["kind", "atlas", "region", "margin", "filter_clip"]) or typeof(value.filter_clip) != TYPE_BOOL: return false
		for pair in [value.region, value.margin]:
			if typeof(pair) != TYPE_ARRAY or pair.size() != 2: return false
			for vector in pair:
				if typeof(vector) != TYPE_VECTOR2 or not vector.is_finite(): return false
		return _texture_descriptor_valid(value.atlas, depth + 1)
	return false


func _capture_reed(visual: Node2D) -> Dictionary:
	var state := {"info": {}, "vertices": [], "colors": []}
	var vertex_count := 0
	if visual._reed_mesh != null:
		if visual._reed_mesh.get_surface_count() != 1 or visual._reed_mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_LINES:
			return _fail("REED_MESH_FORMAT")
		var arrays: Array = visual._reed_mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		vertex_count = vertices.size()
		state.vertices = _binary_chunks(vertices.to_byte_array())
		state.colors = _binary_chunks(colors.to_byte_array())
	state.info = Codec.new().encode({"signature": visual._reed_visibility_signature, "vertex_count": vertex_count}).value
	return {"ok": true, "value": state}


func _validate_reed(value: Variant) -> Dictionary:
	if not _fields(value, ["info", "vertices", "colors"]): return _fail("REED_SCHEMA")
	var decoded: Dictionary = Codec.new().decode(value.info)
	if not decoded.ok or not _fields(decoded.value, ["signature", "vertex_count"]): return _fail("REED_SCHEMA")
	var info: Dictionary = decoded.value
	if typeof(info.signature) != TYPE_INT or info.signature < -1 or info.signature > 2147483629 \
			or typeof(info.vertex_count) != TYPE_INT or info.vertex_count < 0 or info.vertex_count > 262144:
		return _fail("REED_SCHEMA")
	var vertices: Dictionary = _decode_chunks(value.vertices, info.vertex_count * 12)
	var colors: Dictionary = _decode_chunks(value.colors, info.vertex_count * 16)
	if not vertices.ok or not colors.ok: return _fail("REED_BINARY")
	for offset in range(0, vertices.value.size(), 4):
		if not is_finite(vertices.value.decode_float(offset)): return _fail("REED_VERTEX_NON_FINITE")
	for offset in range(0, colors.value.size(), 4):
		if not is_finite(colors.value.decode_float(offset)): return _fail("REED_COLOR_NON_FINITE")
	return {"ok": true}


func _restore_reed(visual: Node2D, state: Dictionary) -> void:
	var info: Dictionary = Codec.new().decode(state.info).value
	visual._reed_visibility_signature = info.signature
	visual._reed_mesh = null
	if info.vertex_count == 0: return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _decode_chunks(state.vertices, info.vertex_count * 12).value.to_vector3_array()
	arrays[Mesh.ARRAY_COLOR] = _decode_chunks(state.colors, info.vertex_count * 16).value.to_color_array()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	visual._reed_mesh = mesh


func _binary_chunks(bytes: PackedByteArray) -> Array:
	var chunks: Array = []
	for start in range(0, bytes.size(), CHUNK_BYTES):
		chunks.append(Codec.new().encode(bytes.slice(start, mini(start + CHUNK_BYTES, bytes.size())).hex_encode()).value)
	return chunks


func _decode_chunks(chunks: Variant, expected: int) -> Dictionary:
	if typeof(chunks) != TYPE_ARRAY or expected > MAX_BINARY_BYTES or chunks.size() != ceili(float(expected) / CHUNK_BYTES):
		return _fail("BINARY_CHUNKS")
	var result := PackedByteArray()
	for i in range(chunks.size()):
		var decoded: Dictionary = Codec.new().decode(chunks[i])
		if not decoded.ok or not _hex(decoded.value, mini(CHUNK_BYTES, expected - i * CHUNK_BYTES) * 2): return _fail("BINARY_CHUNK")
		result.append_array(decoded.value.hex_decode())
	return {"ok": true, "value": result}


func _parameter_valid(parameter: Variant) -> bool:
	if typeof(parameter) != TYPE_DICTIONARY or not parameter.has("kind"): return false
	match parameter.kind:
		"height": return _fields(parameter, ["kind"])
		"texture": return _fields(parameter, ["kind", "identity"]) and _texture_descriptor_valid(parameter.identity)
		"value": return _fields(parameter, ["kind", "value"]) and typeof(parameter.value) in [TYPE_NIL, TYPE_BOOL, TYPE_FLOAT, TYPE_VECTOR2, TYPE_COLOR]
		"vector4":
			if not _fields(parameter, ["kind", "value"]) or typeof(parameter.value) != TYPE_ARRAY or parameter.value.size() != 4: return false
			for scalar in parameter.value:
				if typeof(scalar) != TYPE_FLOAT or not is_finite(scalar): return false
			return true
		"image":
			return _fields(parameter, ["kind", "width", "height", "hex"]) and typeof(parameter.width) == TYPE_INT and typeof(parameter.height) == TYPE_INT \
				and parameter.width > 0 and parameter.height > 0 and parameter.width <= 512 and parameter.height <= 512 \
				and parameter.width * parameter.height <= 8192 and _hex(parameter.hex, parameter.width * parameter.height * 8)
	return false


func _canvas_valid(fixed: Dictionary, runtime: Dictionary) -> bool:
	if typeof(fixed.transform) != TYPE_ARRAY or fixed.transform.size() != 3: return false
	for vector in fixed.transform:
		if typeof(vector) != TYPE_VECTOR2 or not vector.is_finite(): return false
	if typeof(fixed.z_index) != TYPE_INT or fixed.z_index < -4096 or fixed.z_index > 4096 \
			or typeof(fixed.z_as_relative) != TYPE_BOOL or typeof(fixed.self_modulate) != TYPE_COLOR \
			or typeof(fixed.texture_filter) != TYPE_INT or fixed.texture_filter < 0 or fixed.texture_filter > 6 \
			or typeof(fixed.texture_repeat) != TYPE_INT or fixed.texture_repeat < 0 or fixed.texture_repeat > 3: return false
	for key in ["visible", "processing", "physics_processing"]:
		if typeof(runtime[key]) != TYPE_BOOL: return false
	return typeof(runtime.modulate) == TYPE_COLOR and typeof(runtime.process_mode) == TYPE_INT \
		and runtime.process_mode >= 0 and runtime.process_mode <= 4 and typeof(runtime.process_priority) == TYPE_INT


func _fixed_values_valid(kind: String, value: Dictionary) -> bool:
	var bools: Array = []
	var texts: Array = []
	var numbers: Array = []
	match kind:
		"campaign_scenery":
			if typeof(value._style) != TYPE_STRING or value._style != "level3": return false
		"story_sign":
			texts = ["label"]; numbers = ["size"]
			if typeof(value.label) != TYPE_STRING or value.label not in ["李家庄", "扈家庄", "祝家庄"]: return false
		"ground_overlay": numbers = ["size"]
		"entrance":
			if typeof(value._gate_cell) != TYPE_VECTOR2I or typeof(value._east_gate_cell) != TYPE_VECTOR2I: return false
			bools = ["_rts_layout"]
		"sprite":
			numbers = ["size", "foot"]
			bools = ["is_tree"]
		"gate":
			bools = ["lintel", "simple", "replacement_owner"]
			texts = ["plaque_text"]
			numbers = ["facing", "replacement_size", "replacement_foot"]
			if typeof(value.closed_leaf_end) != TYPE_VECTOR2 or not value.closed_leaf_end.is_finite() \
					or not _rect_array(value.replacement_text_rect): return false
		"stockade":
			if typeof(value.end_local) != TYPE_VECTOR2 or not value.end_local.is_finite() \
					or typeof(value.salt) != TYPE_INT or value.salt < 0 or not _rect_array(value.campaign_visible_bbox): return false
			texts = ["campaign_route"]
			numbers = ["height_scale"]
		"flag":
			texts = ["_static_marker", "_static_level_id", "_static_decor_key"]
			numbers = ["_visual_size", "_foot"]
			bools = ["_static_text_only"]
			if not _rect_array(value._static_rect_override): return false
		"art": numbers = ["size", "foot", "duration"]
	for key in bools:
		if typeof(value[key]) != TYPE_BOOL: return false
	for key in texts:
		if typeof(value[key]) != TYPE_STRING or value[key].length() > 256: return false
	for key in numbers:
		if not _finite_number(value[key]): return false
	return true


func _parameter_matches_uniform(name: String, value: Dictionary) -> bool:
	# A null override means the fixed shader's declared default. Preserve that
	# absence rather than inventing a typed scalar/default in the save adapter.
	if value.kind == "value" and value.value == null: return name not in ["land_mask", "surface_weights", "map_size"]
	if name == "height_map": return value.kind == "height" or (value.kind == "value" and value.value == null)
	if name in ["land_mask", "surface_weights"]: return value.kind == "image"
	if name in ["terrain_atlas", "terrain_atlas2", "surface_forest_texture", "surface_dry_texture", "surface_wet_texture",
		"surface_hard_texture", "surface_field_texture"]:
		return value.kind == "texture" or (value.kind == "value" and value.value == null)
	if name.begins_with("use_surface_") or name.ends_with("_enabled"):
		return value.kind == "value" and typeof(value.value) == TYPE_BOOL
	if name == "map_size": return value.kind == "value" and typeof(value.value) == TYPE_VECTOR2
	if name.ends_with("_region"): return value.kind == "vector4"
	if name.ends_with("_tint"): return (value.kind == "value" and typeof(value.value) == TYPE_COLOR) or value.kind == "vector4"
	return value.kind == "value" and typeof(value.value) == TYPE_FLOAT


func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


func _rect_array(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY or value.size() not in [0, 4]: return false
	for component in value:
		if not _finite_number(component): return false
	return true


func _discard(game_map: GameMap, visual: Node2D, code: String, path := "") -> Dictionary:
	var owned: bool = game_map.sample_scenery == visual
	if visual.get_parent() != null: visual.get_parent().remove_child(visual)
	visual.free()
	if owned:
		game_map.sample_scenery = null
		game_map.material = null
	_campaign_activation.clear(); _campaign_record.clear(); _campaign_order.clear()
	_campaign_owner = null; _campaign_visual = null
	return {"ok": false, "code": code, "path": path, "discard_private_transaction": true}


func _fields(value: Variant, names: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != names.size(): return false
	for key in value:
		if typeof(key) != TYPE_STRING or key not in names: return false
	return true


func _hex(value: Variant, length: int) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != length: return false
	for i in range(length):
		var c: int = value.unicode_at(i)
		if not (c >= 48 and c <= 57) and not (c >= 97 and c <= 102): return false
	return true


func _fail(code: String, path := "") -> Dictionary:
	return {"ok": false, "code": code, "path": path, "target_changed": false}


## Campaign support is selected only by the installed caller's explicit context.
## Invalid/other contexts do not cause a snapshot to select a campaign factory.
func _campaign_enabled() -> bool:
	return _fields(_trusted_context, ["mode", "level_id", "waves"]) \
		and typeof(_trusted_context.mode) == TYPE_STRING and _trusted_context.mode == "campaign" \
		and typeof(_trusted_context.level_id) == TYPE_STRING and _trusted_context.level_id == "level3" \
		and typeof(_trusted_context.waves) == TYPE_INT and _trusted_context.waves == 0

func _saved_campaign_context_valid(value: Variant) -> bool:
	# JSON numbers may decode as floats; only the canonical zero is accepted.
	return _fields(value, ["mode", "level_id", "waves"]) \
		and typeof(value.mode) == TYPE_STRING and value.mode == "campaign" \
		and typeof(value.level_id) == TYPE_STRING and value.level_id == "level3" \
		and typeof(value.waves) in [TYPE_INT, TYPE_FLOAT] and value.waves == 0

func _meta_allowed(key: String) -> bool:
	return key in NODE_META or (_campaign_enabled() and key in CAMPAIGN_META)

func _campaign_map(game_map: GameMap) -> Dictionary:
	if not _campaign_enabled() or not is_instance_valid(game_map) or game_map.get_script() != preload("res://scripts/game_map.gd"): return _fail("CAMPAIGN_CONTEXT_REQUIRED")
	if game_map.environment_style != "level3" or game_map.w != 64 or game_map.h != 56 or not game_map.has_meta("campaign_wall_segments") or game_map.get_meta("campaign_wall_segments") != LEVEL3_WALLS: return _fail("LEVEL3_MAP_IDENTITY")
	var world: Node = game_map.get_parent()
	var battle: Node = null if world == null else world.get_parent()
	if battle == null or battle.get_script() != BattleScript or battle.get("map") != game_map or not is_instance_valid(battle.get("level")) or battle.get("level").get_script() != Level3 or battle.get("level").id() != "level3": return _fail("LEVEL3_BATTLE_IDENTITY")
	return {"ok": true}

func _campaign_arrays(visual: Node2D, game_map: GameMap) -> Dictionary:
	if visual.get_script() != CampaignScenery or visual._map != game_map or visual._battle != game_map.get_parent().get_parent() or visual._style != "level3": return _fail("CAMPAIGN_SCENERY_BINDINGS")
	if visual._entrance != null or not visual._guard_posts.is_empty() or visual._lantern_texture != null or visual._cuiyun_light != null: return _fail("CAMPAIGN_UNSUPPORTED_OWNER_STATE")
	var walls: Array = []; var sprites: Array = []
	for child: Node in visual.get_children(true):
		if not child is Node2D: return _fail("CAMPAIGN_CHILD_KIND")
		if child.get_script() == Stockade: walls.append(child)
		else: sprites.append(child)
	if visual._walls != walls or visual._sprites != sprites: return _fail("CAMPAIGN_OWNER_ARRAYS")
	var trees: Array = []
	for child: Node in sprites:
		# setup records grove sprites and non-excluded old/scoped props in _trees.
		if child.get_script() != Scenery.ScenerySprite: continue
		var key: String = str(child.get_meta("campaign_object", ""))
		if child.is_tree or (not key.is_empty() and key not in ["boat", "dock", "bridge", "banner", "rocks", "zhujiazhuang_hall"]): trees.append(child)
	if visual._trees != trees: return _fail("CAMPAIGN_TREE_BINDINGS")
	return {"ok": true}

func _campaign_node_boundary(node: Node2D, kind: String) -> Dictionary:
	if kind not in CAMPAIGN_KINDS or node.is_queued_for_deletion() or (kind != "campaign_scenery" and node.get_child_count(true) != 0): return _fail("CAMPAIGN_NODE_BOUNDARY")
	if node.material != null or node.use_parent_material or node.top_level or node.light_mask != 1 or node.visibility_layer != 1 or node.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED or node.process_thread_group != Node.PROCESS_THREAD_GROUP_INHERIT: return _fail("CAMPAIGN_NODE_OVERRIDE")
	if node.is_processing_input() or node.is_processing_shortcut_input() or node.is_processing_unhandled_input() or node.is_processing_unhandled_key_input() or node.process_physics_priority != 0 or not node.get_groups().is_empty(): return _fail("CAMPAIGN_NODE_INPUT")
	if node.is_blocking_signals() and not _campaign_activation.has(node): return _fail("CAMPAIGN_SIGNAL_GATE")
	for info: Dictionary in node.get_signal_list():
		for row: Dictionary in node.get_signal_connection_list(info.name):
			var callback: Callable = row.callable
			if info.name != &"child_order_changed" or not node.is_inside_tree() or row.flags != CONNECT_REFERENCE_COUNTED or callback.get_object() != node.get_viewport(): return _fail("CAMPAIGN_EXTRA_SIGNAL")
			if callback.get_method() == &"Viewport::canvas_parent_mark_dirty" and callback.get_bound_arguments() == [node]: continue
			if callback.get_method() == &"Viewport::gui_set_root_order_dirty" and callback.get_bound_arguments().is_empty(): continue
			return _fail("CAMPAIGN_EXTRA_SIGNAL")
	var language_count := 0
	for row: Dictionary in node.get_incoming_connections():
		var source_signal: Signal = row.signal
		if kind != "story_sign" or source_signal.get_object() != Localize or source_signal.get_name() != &"language_changed" or row.callable != Callable(node, "_on_language_changed") or row.flags != 0: return _fail("CAMPAIGN_FOREIGN_INCOMING_SIGNAL")
	for row: Dictionary in Localize.language_changed.get_connections():
		var callback: Callable = row.callable
		if callback.get_object() != node: continue
		if kind != "story_sign" or callback != Callable(node, "_on_language_changed") or row.flags != 0 or not callback.get_bound_arguments().is_empty(): return _fail("CAMPAIGN_LANGUAGE_SIGNAL")
		language_count += 1
	if language_count != (1 if kind == "story_sign" and node.is_inside_tree() else 0): return _fail("CAMPAIGN_LANGUAGE_SIGNAL_COUNT")
	return {"ok": true}

## Read-only in-memory guard; values never enter the save envelope. Keep material,
## its image caches and natural_surface_contract out: the existing display factory
## is explicitly allowed to rebuild those. A prior natural contract is checked by
## restore_into above. All gameplay map/nav/height/resources remain byte-exact.
func _campaign_gameplay_guard(game_map: GameMap) -> Dictionary:
	var result: Dictionary = {"ok": true, "map": {}, "nav": {}, "height": {}, "battle": {}, "meta": {}}
	for key: String in ["w", "h", "theme", "base_fill", "environment_style", "natural_surface_enabled", "_navigation_revision", "decor"]: result.map[key] = game_map.get(key)
	result.map["grid"] = game_map.grid.to_byte_array().hex_encode()
	result.map["base_solid"] = game_map._base_solid.hex_encode()
	result.map["block_count"] = game_map._block_count.to_byte_array().hex_encode()
	for key: StringName in game_map.get_meta_list():
		if key != &"natural_surface_contract": result.meta[str(key)] = game_map.get_meta(key)
	for key: String in NAV_NAMES:
		var nav: AStarGrid2D = game_map.get(key)
		if nav == null or nav.is_dirty() or nav.region != Rect2i(0, 0, game_map.w, game_map.h): return _fail("CAMPAIGN_NAV_NOT_STAGED", key)
		var values: Dictionary = {}; var solid := PackedByteArray(); var weights := PackedByteArray()
		solid.resize(game_map.w * game_map.h); weights.resize(game_map.w * game_map.h * 8)
		for field: String in ["region", "cell_size", "offset", "cell_shape", "default_compute_heuristic", "default_estimate_heuristic", "diagonal_mode", "jumping_enabled"]: values[field] = nav.get(field)
		for y: int in range(game_map.h):
			for x: int in range(game_map.w):
				var index: int = y * game_map.w + x; var cell := Vector2i(x, y)
				solid[index] = 1 if nav.is_point_solid(cell) else 0
				weights.encode_double(index * 8, nav.get_point_weight_scale(cell))
		values["solid"] = solid; values["weights"] = weights; result.nav[key] = values
	if game_map.height_field != null:
		var height: RefCounted = game_map.height_field
		if height.get_script() != preload("res://scripts/campaign_height.gd"): return _fail("CAMPAIGN_HEIGHT_SCRIPT")
		result.height = {"width": height.width, "height": height.height, "samples": height.samples.to_byte_array().hex_encode(), "style": height.style}
		if height.texture != null:
			var image: Image = height.texture.get_image()
			if image == null: return _fail("CAMPAIGN_HEIGHT_IMAGE")
			result.height["image"] = image.get_data().hex_encode()
	var battle: Node = game_map.get_parent().get_parent()
	for key: String in ["gold", "wood", "pop_cap", "current_age", "faction_res", "faction_gather_mult", "_tech_done", "next_entity_id", "next_item_uid", "kills", "_steam_valid_kills", "_defs", "_abilities", "_items"]: result.battle[key] = battle.get(key)
	result.battle["gameplay_rng"] = battle.capture_gameplay_rng()
	var ids: Array = []
	for unit: Variant in battle.get("units"): ids.append(unit.get_instance_id())
	result.battle["units"] = ids
	return result.duplicate(true)

## Call only while the final world transaction is still paused, immediately
## before its synchronous activation. The adapter must remain alive until then.
func activate_campaign() -> Dictionary:
	if _campaign_activated or not is_instance_valid(_campaign_owner) or not _campaign_owner.is_inside_tree() or not _campaign_owner.get_tree().paused or Engine.is_in_physics_frame(): return _fail("CAMPAIGN_ACTIVATION_PHASE")
	if not is_instance_valid(_campaign_visual) or _campaign_visual.get_parent() != _campaign_owner or _campaign_owner.sample_scenery != _campaign_visual: return _fail("CAMPAIGN_ACTIVATION_OWNER")
	var context_check: Dictionary = _campaign_map(_campaign_owner)
	if not context_check.ok: return context_check
	var battle: Node = _campaign_owner.get_parent().get_parent()
	if battle.process_mode != Node.PROCESS_MODE_DISABLED or not battle.is_blocking_signals(): return _fail("CAMPAIGN_ACTIVATION_OWNER_GATE")
	var nodes: Array = []; _walk_nodes(_campaign_visual, nodes)
	if nodes != _campaign_order: return _fail("CAMPAIGN_ACTIVATION_TOPOLOGY")
	for node: Node in nodes:
		if not node.is_node_ready() or not node.is_blocking_signals() or node.process_mode != Node.PROCESS_MODE_DISABLED: return _fail("CAMPAIGN_ACTIVATION_GATE")
	var captured: Dictionary = capture(_campaign_owner)
	if not captured.ok: return captured
	if captured.value != _campaign_record: return _fail("CAMPAIGN_PREPARED_STATE_CHANGED")
	for node: Node in nodes:
		var flags: Dictionary = _campaign_activation[node]
		node.set_process(flags.processing); node.set_physics_process(flags.physics_processing)
		node.process_priority = flags.process_priority; node.process_mode = flags.process_mode
		node.set_block_signals(false)
	_campaign_activation.clear(); _campaign_activated = true
	return {"ok": true, "complete_world": false}

func dispose_campaign() -> void:
	# Full world rollback still owns/frees the map and Battle. This helper only
	# removes its own scenery and the StorySign global hooks before that happens.
	if is_instance_valid(_campaign_visual):
		for node: Node in _campaign_order:
			if is_instance_valid(node) and node.get_script() == CampaignScenery.StorySign and Localize.language_changed.is_connected(Callable(node, "_on_language_changed")): Localize.language_changed.disconnect(Callable(node, "_on_language_changed"))
		if is_instance_valid(_campaign_owner):
			_discard(_campaign_owner, _campaign_visual, "CAMPAIGN_DISPOSED")
		else:
			if _campaign_visual.get_parent() != null: _campaign_visual.get_parent().remove_child(_campaign_visual)
			_campaign_visual.free()
	_campaign_activation.clear(); _campaign_record.clear(); _campaign_order.clear()
	_campaign_owner = null; _campaign_visual = null
