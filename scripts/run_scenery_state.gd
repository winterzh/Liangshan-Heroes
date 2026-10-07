extends RefCounted
## Standard Liangshan plus explicitly trusted chapter factories. The factory is the fixed production
## Scenery.setup, audited to write its own descendants, map.material and one
## map metadata value only. Its RNG instances have fixed local seeds; it never
## calls paint/bake/deploy, registers footprints, or changes Battle gameplay.
## Restore runs synchronously on a detached Battle/world/map tree. No _process
## executes. Rebuilt structure and fixed values must match before runtime values
## are applied. Each campaign keeps a separate schema, strict installed chapter
## context and a retained disabled activation plan; it is not world acceptance.
const Codec := preload("res://scripts/run_state_value_codec.gd")
const Scenery := preload("res://scripts/liangshan_scenery.gd")
const CampaignScenery := preload("res://scripts/campaign_scenery.gd")
const Level3 := preload("res://scripts/levels/level3_zhujiazhuang_rts.gd")
const Level1 := preload("res://scripts/levels/level1_huangnigang_short.gd")
const Level6 := preload("res://scripts/levels/level6_yezhulin.gd")
const Level2 := preload("res://scripts/levels/level2_jiangzhou_rts.gd")
const Level4 := preload("res://scripts/levels/level4_lianhuanma_rts.gd")
const Level7 := preload("res://scripts/levels/level7_kuaihuolin_short.gd")
const Level8 := preload("res://scripts/levels/level8_daming_rts.gd")
const DamingLighting := preload("res://scripts/run_daming_lighting_state.gd")
const CityWall := preload("res://scripts/campaign_city_wall.gd")
const Passage := preload("res://scripts/campaign_passage.gd")
const DAMING_KINDS := ["night", "lantern", "city_wall", "passage"]
const Level5 := preload("res://scripts/levels/level5_gao_rts.gd")
const NativeLayoutSource := preload("res://scripts/levels/skirmish.gd")
const NATIVE_CAMPAIGN_KINDS := ["scenery", "entrance", "sprite", "gate", "stockade", "flag", "art"]
const MengzhouGate := preload("res://scripts/campaign_mengzhou_gate.gd")
const BattleScript := preload("res://scripts/battle.gd")
const CAMPAIGN_CONTEXT := {"mode": "campaign", "level_id": "level3", "waves": 0}
const CAMPAIGN_DISPLAY_CONTEXT := {"mode": "campaign", "level_id": "level3"}
const CAMPAIGN_SCHEMA := "level3_scenery_state_v2"
const CAMPAIGN_KINDS := ["campaign_scenery", "story_sign", "story_crowd", "story_stall", "mengzhou_gate", "mengzhou_shadow", "ground_overlay", "sprite", "stockade", "flag", "art"]
const KUAI_KINDS := ["story_stall", "mengzhou_gate", "mengzhou_shadow"]
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
	"night": ["name", "color"], "lantern": ["settings"], "city_wall": ["end_local", "salt", "height_scale"], "passage": ["caption", "object_key"],
	"story_stall": ["size", "kind"], "mengzhou_gate": [], "mengzhou_shadow": ["name"],
	"scenery": [], "campaign_scenery": ["_style"], "story_sign": ["size", "label"], "story_crowd": ["variant", "_direction_override"], "ground_overlay": ["size"],
	"entrance": ["_gate_cell", "_east_gate_cell", "_rts_layout"],
	"sprite": ["size", "foot", "is_tree"],
	"gate": ["lintel", "facing", "simple", "plaque_text", "replacement_owner", "replacement_size",
		"replacement_foot", "replacement_text_rect", "closed_leaf_end"],
	"stockade": ["end_local", "salt", "height_scale", "campaign_route", "campaign_visible_bbox"],
	"flag": ["_static_marker", "_visual_size", "_foot", "_static_level_id", "_static_decor_key", "_static_rect_override", "_static_text_only"],
	"art": ["size", "foot", "duration"]}
const RUNTIME_FIELDS := {"night": [], "lantern": ["energy"], "city_wall": [], "passage": ["_open"], "story_stall": [], "mengzhou_gate": [], "mengzhou_shadow": [], "scenery": ["_visibility_tick"], "campaign_scenery": ["_visibility_tick"], "story_sign": [], "story_crowd": [], "ground_overlay": [], "entrance": ["_tick"], "sprite": [],
	"gate": ["sealed"], "stockade": [], "flag": [], "art": ["life"]}
const TEX_FIELDS := {"night": [], "lantern": ["texture"], "city_wall": [], "passage": [], "story_stall": [], "mengzhou_gate": ["tex"], "mengzhou_shadow": [], "scenery": [], "campaign_scenery": [], "story_sign": [], "story_crowd": ["_idle_texture"], "ground_overlay": ["tex"], "entrance": ["_stockade_texture", "_dock_straight_texture", "_dock_head_texture"],
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
	"res://scripts/campaign_height.gd", "res://scripts/campaign_art.gd", "res://scripts/levels/level3_zhujiazhuang_rts.gd",
	"res://scripts/levels/level1_huangnigang.gd", "res://scripts/levels/level1_huangnigang_short.gd",
	"res://scripts/levels/level6_yezhulin.gd", "res://scripts/levels/level2_jiangzhou_rts.gd", "res://scripts/levels/level2_jiangzhou.gd",
	"res://scripts/campaign_mengzhou_gate.gd", "res://scripts/levels/level7_kuaihuolin.gd", "res://scripts/levels/level7_kuaihuolin_short.gd",
	"res://scripts/levels/skirmish.gd", "res://scripts/levels/level5_gao_rts.gd",
	"res://scripts/levels/level8_daming_rts.gd", "res://scripts/levels/level8_dongchangfu.gd",
	"res://scripts/campaign_city_wall.gd", "res://scripts/campaign_passage.gd", "res://scripts/run_daming_lighting_state.gd"]
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
	if game_map.sample_scenery.get_script() != (Scenery if _native_campaign() else CampaignScenery if campaign else Scenery):
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
	var snapshot := {"schema": _campaign_schema() if campaign else "scenery_state_v2", "content_version": _content_version, "kind": _campaign_kind() if campaign else "liangshan", "nodes": records,
		"material": parameters.value, "reed": reed.value}
	if campaign: snapshot["context"] = {"mode": "campaign", "level_id": _trusted_context.level_id}
	if _native_campaign():
		var owners: Dictionary = _native_ownership(game_map.sample_scenery)
		if not owners.ok: return owners
		snapshot["ownership"] = owners.value
	if _daming_campaign():
		var owners: Dictionary = _daming_ownership(game_map.sample_scenery)
		if not owners.ok: return owners
		var lights: Dictionary = DamingLighting.new(_content_version, _trusted_context).capture(game_map.sample_scenery)
		if not lights.ok: return lights
		snapshot["ownership"] = owners.value; snapshot["lighting"] = lights.value
	var checked: Dictionary = validate(snapshot)
	if not checked.ok: return checked
	return {"ok": true, "value": snapshot}


func validate(snapshot: Variant) -> Dictionary:
	if _content_version.is_empty(): return _fail("CONTENT_VERSION_REQUIRED", "$/display/content_version")
	var campaign: bool = _campaign_enabled()
	if not _trusted_context.is_empty() and not campaign: return _fail("TRUSTED_CAMPAIGN_CONTEXT_UNSUPPORTED")
	if typeof(snapshot) != TYPE_DICTIONARY or snapshot.get("schema") != (_campaign_schema() if campaign else "scenery_state_v2"):
		return _fail("SCENERY_SCHEMA")
	if typeof(snapshot.get("content_version")) != TYPE_STRING or snapshot.content_version != _content_version:
		return _fail("CONTENT_VERSION_MISMATCH", "$/display/content_version")
	if not campaign and _fields(snapshot, ["schema", "content_version", "kind"]) and snapshot.kind == "none": return {"ok": true}
	var envelope: Array = ["schema", "content_version", "kind", "nodes", "material", "reed"]
	if campaign: envelope.append("context")
	if _native_campaign() or _daming_campaign(): envelope.append("ownership")
	if _daming_campaign(): envelope.append("lighting")
	if campaign and not _saved_campaign_context_valid(snapshot.get("context")): return _fail("CAMPAIGN_CONTEXT_MISMATCH")
	if not _fields(snapshot, envelope) or snapshot.kind != (_campaign_kind() if campaign else "liangshan"):
		return _fail("SCENERY_SCHEMA")
	if typeof(snapshot.nodes) != TYPE_ARRAY or snapshot.nodes.is_empty() or snapshot.nodes.size() > MAX_NODES:
		return _fail("SCENERY_NODE_COUNT")
	var codec := Codec.new()
	var kuai_gate_index := -1
	var kuai_shadow_count := 0
	var kuai_stall_count := 0
	for i in range(snapshot.nodes.size()):
		var decoded: Dictionary = codec.decode(snapshot.nodes[i])
		if not decoded.ok: return _fail("SCENERY_NODE_CODEC", str(i))
		var record: Variant = decoded.value
		if not _fields(record, ["parent", "kind", "fixed", "runtime", "textures", "metadata"]): return _fail("SCENERY_NODE_FIELDS", str(i))
		if typeof(record.parent) != TYPE_INT or record.parent < -1 or record.parent >= i \
				or (i == 0 and record.parent != -1) or (i > 0 and record.parent == -1) \
				or typeof(record.kind) != TYPE_STRING or record.kind not in FIXED_FIELDS:
			return _fail("SCENERY_NODE_IDENTITY", str(i))
		if campaign and record.kind not in _allowed_campaign_kinds(): return _fail("CAMPAIGN_NODE_KIND", str(i))
		if not campaign and record.kind in ["campaign_scenery", "story_sign", "story_crowd", "ground_overlay"]: return _fail("CAMPAIGN_CONTEXT_REQUIRED")
		if record.kind == "story_crowd" and _trusted_context.get("level_id") not in ["level2", "level8"]: return _fail("LEVEL2_CROWD_CONTEXT_REQUIRED")
		if record.kind in KUAI_KINDS and _trusted_context.get("level_id") != "level7" and not (_daming_campaign() and record.kind == "story_stall"): return _fail("LEVEL7_SCENERY_CONTEXT_REQUIRED")
		if i == 0 and record.kind != ("campaign_scenery" if campaign and not _native_campaign() else "scenery"): return _fail("SCENERY_ROOT")
		if record.kind == "mengzhou_shadow":
			if kuai_gate_index < 1 or record.parent != kuai_gate_index or i != kuai_gate_index + 1 or kuai_shadow_count != 0: return _fail("LEVEL7_SHADOW_PARENT", str(i))
			kuai_shadow_count += 1
		elif campaign and not _native_campaign() and i > 0 and record.parent != 0: return _fail("CAMPAIGN_DIRECT_CHILD_REQUIRED", str(i))
		if record.kind == "mengzhou_gate":
			if kuai_gate_index >= 0: return _fail("LEVEL7_DUPLICATE_GATE")
			kuai_gate_index = i
		if record.kind == "story_stall": kuai_stall_count += 1
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
			if key in ["sealed", "_open"]:
				if typeof(value) != TYPE_BOOL: return _fail("SCENERY_SEALED", str(i))
			elif typeof(value) != TYPE_FLOAT or not is_finite(value): return _fail("SCENERY_TIME", str(i))
		if record.kind == "art" and (typeof(record.fixed.duration) != TYPE_FLOAT or record.fixed.duration >= 0.0):
			return _fail("SCENERY_EVENT_NOT_STATIC", str(i))
		for key in record.textures:
			if not _texture_descriptor_valid(record.textures[key]): return _fail("SCENERY_TEXTURE", str(i))
	if _trusted_context.get("level_id") == "level7" and (kuai_gate_index < 1 or kuai_shadow_count != 1 or kuai_stall_count != 6): return _fail("LEVEL7_SCENERY_COUNTS")
	if _native_campaign():
		var owner_check: Dictionary = _validate_native_ownership(snapshot.ownership, snapshot.nodes)
		if not owner_check.ok: return owner_check
	if _daming_campaign():
		var owner_check: Dictionary = _validate_daming_ownership(snapshot)
		if not owner_check.ok: return owner_check
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
	var visual: Node2D = Scenery.new() if _native_campaign() else CampaignScenery.new() if campaign else Scenery.new()
	game_map.sample_scenery = visual
	game_map.add_child(visual)
	if _native_campaign():
		var original_decor: Array = NativeLayoutSource.liangshan_visual_decor()
		if game_map.decor != original_decor.filter(func(d: Array) -> bool: return d[0] != "boat"): return _discard(game_map, visual, "LEVEL5_DECOR_IDENTITY")
		visual.setup_original_decor(game_map, original_decor)
		# Original native scenery's first process syncs these owned entrance
		# members. Replay only that pure visual elevation on fresh descendants;
		# never touch bound Units/FX through _sync_elevated_nodes itself.
		for part: Node2D in visual._entrance._gate_parts + visual._entrance._side_gate_parts + visual._entrance._wall_parts: game_map.sync_render_position(part)
	else:
		visual.setup(game_map)
	if _daming_campaign():
		var tower_state: String = _daming_tower_state(snapshot.nodes)
		visual.set_story_object_state("cuiyun_tower", tower_state)
		var light_restore: Dictionary = DamingLighting.new(_content_version, _trusted_context).apply_into(visual, snapshot.lighting)
		if not light_restore.ok: return _discard(game_map, visual, String(light_restore.code))
	if campaign and _trusted_context.get("level_id") == "level7":
		# Source _ready creates the same child. Prepare it before the detached
		# fixed-structure comparison, and let the idempotent _ready keep it.
		for child: Node in visual.get_children(true):
			if child.get_script() == MengzhouGate and not child.prepare_visual(): return _discard(game_map, visual, "LEVEL7_SHADOW_FACTORY")
	if campaign:
		if _campaign_gameplay_guard(game_map) != prior_gameplay:
			return _discard(game_map, visual, "CAMPAIGN_FACTORY_CHANGED_GAMEPLAY")
		var ownership: Dictionary = _campaign_arrays(visual, game_map)
		if not ownership.ok: return _discard(game_map, visual, ownership.code)
		# Source signs gain this derived height on their first scenery process.
		# It changes only metadata/CanvasItem placement, not logical position.
		if not _native_campaign():
			for child: Node in visual.get_children():
				if not (_daming_campaign() and (child is PointLight2D or child is CanvasModulate)): game_map.sync_render_position(child)
	# setup's only metadata write must reproduce the recorded static contract.
	# Actual scalar/material overrides are restored separately below.
	if prior_contract != null and (not game_map.has_meta("natural_surface_contract") or game_map.get_meta("natural_surface_contract") != prior_contract):
		return _discard(game_map, visual, "NATURAL_SURFACE_CONTRACT_CHANGED")
	if _native_campaign():
		var owners: Dictionary = _native_ownership(visual)
		if not owners.ok: return _discard(game_map, visual, String(owners.code), String(owners.get("path", "")))
		if owners.value != snapshot.ownership:
			for field: String in ["entrance", "trees", "sprites", "guard_posts", "gate_parts", "side_gate_parts", "wall_parts", "dock_parts"]:
				if owners.value[field] != snapshot.ownership[field]: return _discard(game_map, visual, "LEVEL5_OWNER_STRUCTURE_CHANGED", field + ":saved=" + str(snapshot.ownership[field]) + ":rebuilt=" + str(owners.value[field]))
			return _discard(game_map, visual, "LEVEL5_OWNER_STRUCTURE_CHANGED")
	if _daming_campaign():
		var owners: Dictionary = _daming_ownership(visual)
		if not owners.ok: return _discard(game_map, visual, String(owners.code))
		if owners.value != snapshot.ownership: return _discard(game_map, visual, "DAMING_OWNER_STRUCTURE_CHANGED")
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
			return _discard(game_map, visual, "SCENERY_FIXED_STATE_CHANGED", str(i) + "/" + _fixed_difference(saved, rebuilt))
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
		if node is Node2D:
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
			"restored_nodes": nodes.size(), "factory": "fixed_" + _trusted_context.level_id + "_visual_only",
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
	for key in FIXED_FIELDS[kind]:
		if key == "settings" and kind == "lantern":
			var settings: Dictionary = DamingLighting.new(_content_version, _trusted_context).light_settings(node)
			if not settings.ok: return settings
			fixed[key] = settings.value
		else: fixed[key] = String(node.name) if key == "name" else node.get(key)
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
	if _daming_campaign():
		if node.get_script() == CityWall: return "city_wall"
		if node.get_script() == Passage: return "passage"
		if node is CanvasModulate and node.get_script() == null: return "night"
		if node is PointLight2D and node.get_script() == null: return "lantern"
		if node.get_script() == CampaignScenery.StoryStall: return "story_stall"
	if _campaign_enabled():
		if _trusted_context.get("level_id") == "level7":
			if node.get_script() == CampaignScenery.StoryStall: return "story_stall"
			if node.get_script() == MengzhouGate: return "mengzhou_gate"
			if node.get_script() == MengzhouGate.GroundShadow: return "mengzhou_shadow"
		if node.get_script() == CampaignScenery: return "campaign_scenery"
		if node.get_script() == CampaignScenery.StorySign: return "story_sign"
		if _trusted_context.get("level_id") in ["level2", "level8"] and node.get_script() == CampaignScenery.StoryCrowd: return "story_crowd"
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
	if _daming_campaign() and texture is GradientTexture2D:
		var descriptor: Dictionary = DamingLighting.new(_content_version, _trusted_context)._gradient(texture)
		return {"kind": "daming_lantern_v1"} if descriptor.ok else {"kind": "unsupported"}
	if texture is AtlasTexture:
		return {"kind": "atlas", "atlas": _texture_descriptor(texture.atlas), "region": [texture.region.position, texture.region.size],
			"margin": [texture.margin.position, texture.margin.size], "filter_clip": texture.filter_clip}
	if texture is Texture2D and not texture.resource_path.is_empty():
		return {"kind": "resource", "path": texture.resource_path, "size": texture.get_size()}
	return {"kind": "unsupported"}


func _texture_descriptor_valid(value: Variant, depth := 0) -> bool:
	if _fields(value, ["kind"]) and value.kind == "none": return true
	if _daming_campaign() and _fields(value, ["kind"]) and value.kind == "daming_lantern_v1": return true
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
		"night":
			if not _daming_campaign() or typeof(value.name) != TYPE_STRING or value.name != "LanternNight" or typeof(value.color) != TYPE_COLOR or value.color != Color(0.62, 0.67, 0.79): return false
		"lantern":
			if not _daming_campaign() or value.settings != DamingLighting.new(_content_version, _trusted_context).default_light_settings(): return false
		"city_wall":
			if not _daming_campaign() or typeof(value.end_local) != TYPE_VECTOR2 or not value.end_local.is_finite() or typeof(value.salt) != TYPE_INT or value.salt != 0 or typeof(value.height_scale) != TYPE_FLOAT or value.height_scale not in [62.0, 108.0]: return false
		"passage":
			if not _daming_campaign() or typeof(value.caption) != TYPE_STRING or value.caption != "牢门" or typeof(value.object_key) != TYPE_STRING or value.object_key != "prison_gate": return false
		"story_stall":
			if _trusted_context.get("level_id") not in ["level7", "level8"] or typeof(value.kind) != TYPE_STRING or value.kind not in (["lantern"] if _daming_campaign() else ["inn", "wine", "goods", "dice", "money"]) or typeof(value.size) != TYPE_FLOAT or value.size != 64.0: return false
		"mengzhou_gate":
			if _trusted_context.get("level_id") != "level7" or value.z_as_relative: return false
		"mengzhou_shadow":
			if _trusted_context.get("level_id") != "level7" or typeof(value.name) != TYPE_STRING or value.name != "AlignedGroundShadow" or value.z_as_relative or value.z_index != 0: return false
			if value.transform != [Vector2.RIGHT, Vector2.DOWN, Vector2.ZERO]: return false
		"campaign_scenery":
			if typeof(value._style) != TYPE_STRING or value._style != _trusted_context.get("level_id", ""): return false
		"story_sign":
			texts = ["label"]; numbers = ["size"]
			var labels: Array = ["蔡福家", "接应地", "大名府"] if _daming_campaign() else ["西街接应营", "江边接应营", "巡防营", "西巷", "南巷"] if _trusted_context.get("level_id") == "level2" else ["李家庄", "扈家庄", "祝家庄"]
			if typeof(value.label) != TYPE_STRING or value.label not in labels: return false
		"story_crowd":
			if _trusted_context.get("level_id") not in ["level2", "level8"] or typeof(value.variant) != TYPE_INT or value.variant < 0 or value.variant > 120: return false
			if _daming_campaign() and value.variant not in [12, 20, 27, 33]: return false
			if typeof(value._direction_override) != TYPE_STRING or value._direction_override not in ([""] if _daming_campaign() else ["se", "sw", "ne", "nw"]): return false
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
		and typeof(_trusted_context.level_id) == TYPE_STRING and _trusted_context.level_id in ["level1", "level2", "level3", "level6", "level7", "level4", "level5", "level8"] \
		and typeof(_trusted_context.waves) == TYPE_INT and _trusted_context.waves == 0

func _native_campaign() -> bool:
	return _campaign_enabled() and _trusted_context.level_id == "level5"

func _campaign_schema() -> String:
	if _daming_campaign(): return "level8_scenery_state_v1"
	if _native_campaign(): return "level5_native_scenery_state_v2"
	if _trusted_context.get("level_id") == "level4": return "level4_scenery_state_v1"
	if _trusted_context.get("level_id") == "level7": return "level7_scenery_state_v1"
	if _trusted_context.get("level_id") == "level2": return "level2_scenery_state_v1"
	if _trusted_context.get("level_id") == "level6": return "level6_scenery_state_v1"
	return "level1_scenery_state_v1" if _trusted_context.get("level_id") == "level1" else CAMPAIGN_SCHEMA

func _campaign_kind() -> String:
	return "campaign_" + String(_trusted_context.get("level_id", ""))

func _saved_campaign_context_valid(value: Variant) -> bool:
	# The display envelope identifies a chapter, which has no wave count. Keep
	# its identity JSON-stable; the installed caller still requires integer zero
	# in _campaign_enabled, and no field is normalized or dropped on read.
	return _fields(value, ["mode", "level_id"]) \
		and typeof(value.mode) == TYPE_STRING and value.mode == "campaign" \
		and typeof(value.level_id) == TYPE_STRING and value.level_id == _trusted_context.get("level_id")

func _meta_allowed(key: String) -> bool:
	return key in NODE_META or (_campaign_enabled() and key in CAMPAIGN_META)

func _campaign_map(game_map: GameMap) -> Dictionary:
	if not _campaign_enabled() or not is_instance_valid(game_map) or game_map.get_script() != preload("res://scripts/game_map.gd"): return _fail("CAMPAIGN_CONTEXT_REQUIRED")
	var level_id: String = _trusted_context.level_id
	var level_script: Script = Level1 if level_id == "level1" else Level3
	if level_id == "level4": level_script = Level4
	if level_id == "level5": level_script = Level5
	if level_id == "level6": level_script = Level6
	if level_id == "level2": level_script = Level2
	if level_id == "level7": level_script = Level7
	if level_id == "level8": level_script = Level8
	if level_id == "level1":
		if game_map.environment_style != "level1" or game_map.w != 48 or game_map.h != 40 or game_map.theme != "hills" or game_map.has_meta("campaign_wall_segments"): return _fail("LEVEL1_MAP_IDENTITY")
	elif level_id == "level5":
		if game_map.environment_style != "" or game_map.w != 60 or game_map.h != 60 or game_map.theme != "marsh" or game_map.has_meta("campaign_wall_segments") or typeof(game_map.get_meta("liangshan_hall_cell", null)) != TYPE_VECTOR2I or game_map.get_meta("liangshan_hall_cell") != Level5.HALL: return _fail("LEVEL5_MAP_IDENTITY")
		if typeof(game_map.get_meta("liangshan_rts_court", null)) != TYPE_BOOL or game_map.get_meta("liangshan_rts_court") != true: return _fail("LEVEL5_COURT_IDENTITY")
		if typeof(game_map.get_meta("liangshan_art_level_id", null)) != TYPE_STRING or game_map.get_meta("liangshan_art_level_id") != "level5": return _fail("LEVEL5_ART_IDENTITY")
		if typeof(game_map.get_meta("zhongyi_hall_facing_cardinal", null)) != TYPE_STRING or game_map.get_meta("zhongyi_hall_facing_cardinal") != "south": return _fail("LEVEL5_HALL_FACING_IDENTITY")
		if typeof(game_map.get_meta("zhongyi_hall_front_vector", null)) != TYPE_VECTOR2I or game_map.get_meta("zhongyi_hall_front_vector") != Vector2i(0, 1) or typeof(game_map.get_meta("liangshan_hall_cell", null)) != TYPE_VECTOR2I: return _fail("LEVEL5_HALL_FRONT_IDENTITY")
	elif level_id == "level8":
		if game_map.environment_style != "level8" or game_map.w != 60 or game_map.h != 66 or game_map.theme != "town" or game_map.has_meta("campaign_wall_segments"): return _fail("LEVEL8_MAP_IDENTITY")
		if typeof(game_map.get_meta("campaign_city_wicket_sealed", null)) != TYPE_BOOL or game_map.get_meta("campaign_city_wicket_sealed") != true: return _fail("LEVEL8_WICKET_IDENTITY")
		if typeof(game_map.get_meta("campaign_city_sign_cell", null)) != TYPE_VECTOR2I or game_map.get_meta("campaign_city_sign_cell") != Vector2i(26, 43): return _fail("LEVEL8_SIGN_IDENTITY")
	elif level_id == "level4":
		if game_map.environment_style != "level4" or game_map.w != 64 or game_map.h != 60 or game_map.theme != "plain" or game_map.has_meta("campaign_wall_segments"): return _fail("LEVEL4_MAP_IDENTITY")
	elif level_id == "level6":
		if game_map.environment_style != "level6" or game_map.w != 52 or game_map.h != 40 or game_map.theme != "marsh" or game_map.has_meta("campaign_wall_segments"): return _fail("LEVEL6_MAP_IDENTITY")
	elif level_id == "level2":
		if game_map.environment_style != "level2" or game_map.w != 60 or game_map.h != 58 or game_map.theme != "town" or game_map.has_meta("campaign_wall_segments"): return _fail("LEVEL2_MAP_IDENTITY")
	elif level_id == "level7":
		if game_map.environment_style != "level7" or game_map.w != 60 or game_map.h != 38 or game_map.theme != "town" or game_map.has_meta("campaign_wall_segments"): return _fail("LEVEL7_MAP_IDENTITY")
	elif game_map.environment_style != "level3" or game_map.w != 64 or game_map.h != 56 or not game_map.has_meta("campaign_wall_segments") or game_map.get_meta("campaign_wall_segments") != LEVEL3_WALLS: return _fail("LEVEL3_MAP_IDENTITY")
	var world: Node = game_map.get_parent()
	var battle: Node = null if world == null else world.get_parent()
	if battle == null or battle.get_script() != BattleScript or battle.get("map") != game_map or not is_instance_valid(battle.get("level")) or battle.get("level").get_script() != level_script or battle.get("level").id() != level_id: return _fail(level_id.to_upper() + "_BATTLE_IDENTITY")
	return {"ok": true}

func _campaign_arrays(visual: Node2D, game_map: GameMap) -> Dictionary:
	if _daming_campaign(): return _daming_ownership(visual)
	if _native_campaign():
		if visual.get_script() != Scenery or visual._map != game_map or visual._battle != game_map.get_parent().get_parent(): return _fail("LEVEL5_SCENERY_BINDINGS")
		return _native_ownership(visual)
	if visual.get_script() != CampaignScenery or visual._map != game_map or visual._battle != game_map.get_parent().get_parent() or visual._style != _trusted_context.level_id: return _fail("CAMPAIGN_SCENERY_BINDINGS")
	if visual._entrance != null or not visual._guard_posts.is_empty() or visual._lantern_texture != null or visual._cuiyun_light != null: return _fail("CAMPAIGN_UNSUPPORTED_OWNER_STATE")
	var walls: Array = []; var sprites: Array = []
	for child: Node in visual.get_children(true):
		if not child is Node2D: return _fail("CAMPAIGN_CHILD_KIND")
		if _trusted_context.get("level_id") == "level7" and child.get_script() == MengzhouGate:
			walls.append(child); sprites.append(child)
		elif child.get_script() == Stockade: walls.append(child)
		else: sprites.append(child)
	if visual._walls != walls or visual._sprites != sprites: return _fail("CAMPAIGN_OWNER_ARRAYS")
	var trees: Array = []
	for child: Node in sprites:
		# setup records grove sprites and non-excluded old/scoped props in _trees.
		if child.get_script() != Scenery.ScenerySprite: continue
		var key: String = str(child.get_meta("campaign_object", ""))
		if child.is_tree or (not child.has_meta("campaign_environment_route") and not key.is_empty() and key not in ["boat", "dock", "bridge", "banner", "rocks"]): trees.append(child)
	if visual._trees != trees: return _fail("CAMPAIGN_TREE_BINDINGS")
	return {"ok": true}

func _campaign_node_boundary(node: Node2D, kind: String) -> Dictionary:
	if kind not in _allowed_campaign_kinds() or node.is_queued_for_deletion(): return _fail("CAMPAIGN_NODE_BOUNDARY")
	if kind == "mengzhou_gate":
		if _trusted_context.get("level_id") != "level7" or node.get_child_count(true) != 1: return _fail("LEVEL7_GATE_CHILD")
		var shadow: Node = node.get_child(0, true)
		if shadow.get_script() != MengzhouGate.GroundShadow or shadow.name != &"AlignedGroundShadow" or not is_same(shadow.gate, node): return _fail("LEVEL7_SHADOW_OWNER")
	elif kind not in (["scenery", "entrance"] if _native_campaign() else ["campaign_scenery"]) and node.get_child_count(true) != 0: return _fail("CAMPAIGN_NODE_BOUNDARY")
	if kind == "mengzhou_shadow":
		var gate: Node = node.get_parent()
		if gate == null or gate.get_script() != MengzhouGate or not is_same(node.gate, gate) or gate.get_child_count(true) != 1: return _fail("LEVEL7_SHADOW_OWNER")
	if node.material != null or node.use_parent_material or node.top_level or node.light_mask != 1 or node.visibility_layer != 1 or node.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED or node.process_thread_group != Node.PROCESS_THREAD_GROUP_INHERIT: return _fail("CAMPAIGN_NODE_OVERRIDE")
	if node.is_processing_input() or node.is_processing_shortcut_input() or node.is_processing_unhandled_input() or node.is_processing_unhandled_key_input() or node.process_physics_priority != 0: return _fail("CAMPAIGN_NODE_INPUT", kind + ":" + String(node.name))
	var expected_groups: Array = []
	# Godot 4.6.3 CanvasModulate registers precisely its current canvas group
	# while visible in the tree; the detached factory has no such membership.
	# Preserve that native lifecycle without admitting arbitrary user groups.
	if kind == "night" and node.is_inside_tree() and node.is_visible_in_tree(): expected_groups.append(StringName("_canvas_modulate_" + str(node.get_canvas().get_id())))
	if node.get_groups() != expected_groups: return _fail("CAMPAIGN_NODE_GROUP", kind + ":" + str(node.get_groups()))
	if kind == "city_wall" and not _city_wall_mesh_valid(node): return _fail("DAMING_WALL_MESH")
	if kind == "passage" and (node.map != _campaign_binding_map(node) or node.position != node.map.cell_to_world(Vector2i(19, 20))): return _fail("DAMING_PASSAGE_MAP")
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
		if height.get_script() != (preload("res://scripts/liangshan_height.gd") if _native_campaign() else preload("res://scripts/campaign_height.gd")): return _fail("CAMPAIGN_HEIGHT_SCRIPT")
		result.height = {"width": height.width, "height": height.height, "samples": height.samples.to_byte_array().hex_encode()}
		if not _native_campaign(): result.height["style"] = height.style
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
	if _native_campaign():
		var static_flags: Dictionary = _restore_native_static_enter_flags()
		if not static_flags.ok: return static_flags
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

## Entering the tree enables a scripted _process even when it was disabled
## on a detached node. Only the two fixed, permanently static dock overlays
## have that original saved state. Check the complete snapshot before any
## flag write; no life/time callback or gameplay process is invoked.
func _restore_native_static_enter_flags() -> Dictionary:
	if not _native_campaign() or _campaign_activated or not is_instance_valid(_campaign_owner) or not _campaign_owner.is_inside_tree() or not _campaign_owner.get_tree().paused or Engine.is_in_physics_frame(): return _fail("LEVEL5_STATIC_ENTER_PHASE")
	var context_check: Dictionary = _campaign_map(_campaign_owner)
	if not context_check.ok: return context_check
	var battle: Node = _campaign_owner.get_parent().get_parent()
	if battle.process_mode != Node.PROCESS_MODE_DISABLED or not battle.is_blocking_signals(): return _fail("LEVEL5_STATIC_ENTER_OWNER")
	var nodes: Array = []; _walk_nodes(_campaign_visual, nodes)
	if nodes != _campaign_order: return _fail("LEVEL5_STATIC_ENTER_TOPOLOGY")
	for node: Node in nodes:
		if not node.is_node_ready() or not node.is_blocking_signals() or node.process_mode != Node.PROCESS_MODE_DISABLED: return _fail("LEVEL5_STATIC_ENTER_GATE")
	var current: Dictionary = capture(_campaign_owner)
	if not current.ok: return current
	if current.value == _campaign_record: return {"ok": true, "changed_flags": 0}
	var normalized: Dictionary = current.value.duplicate(true)
	var pending: Array[Node] = []
	var codec := Codec.new()
	for index: int in _campaign_record.ownership.dock_parts:
		var node: Node = nodes[index]
		var saved: Dictionary = codec.decode(_campaign_record.nodes[index]).value
		var mounted: Dictionary = codec.decode(normalized.nodes[index]).value
		if node.get_script() != ArtEvent or saved.kind != "art" or mounted.kind != "art": return _fail("LEVEL5_STATIC_ENTER_SCRIPT")
		if saved.fixed.duration != -1.0 or saved.runtime.life != -1.0 or mounted.fixed.duration != -1.0 or mounted.runtime.life != -1.0: return _fail("LEVEL5_STATIC_ENTER_LIFETIME")
		if saved.runtime.processing == false and mounted.runtime.processing == true:
			mounted.runtime.processing = false
			normalized.nodes[index] = codec.encode(mounted).value
			pending.append(node)
	# Every other value, owner, node, shader, reed and flag must still be exact.
	if normalized != _campaign_record: return _fail("CAMPAIGN_PREPARED_STATE_CHANGED")
	for node: Node in pending: node.set_process(false)
	return {"ok": true, "changed_flags": pending.size()}

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


## Native Liangshan scene ownership uses saved traversal IDs, never old Nodes.
## Geometry/resources remain the qualified fixed factory's responsibility.
func _native_ownership(visual: Node2D) -> Dictionary:
	if visual.get_script() != Scenery: return _fail("LEVEL5_SCENERY_ROOT")
	var nodes: Array = []; _walk_nodes(visual, nodes)
	var owners := {"entrance": nodes.find(visual._entrance), "trees": [], "sprites": [], "guard_posts": [], "gate_parts": [], "side_gate_parts": [], "wall_parts": [], "dock_parts": []}
	if owners.entrance < 1 or visual._entrance.get_script() != Entrance or visual._entrance.get_parent() != visual: return _fail("LEVEL5_ENTRANCE_OWNER")
	var entrance: Node2D = visual._entrance
	if entrance._map != visual._map or entrance._rts_layout != Entrance.Layout.is_rts_layout(visual._map) or entrance._gate_cell != Entrance.Layout.gate_for(visual._map) or entrance._east_gate_cell != Entrance.Layout.east_gate_for(visual._map) or entrance._bank_ridges != Entrance.Layout.bank_ridges_for(visual._map): return _fail("LEVEL5_ENTRANCE_MAP_BINDING")
	if entrance._stockade_metrics != preload("res://scripts/campaign_environment_art.gd").calibrated_visual_metrics("object", "level5", "stockade_segment"): return _fail("LEVEL5_ENTRANCE_METRICS")
	var owned_parts := {}
	for field: String in ["gate_parts", "side_gate_parts", "wall_parts"]:
		for node: Node in entrance.get("_" + field):
			if not is_instance_valid(node) or node.get_parent() != entrance or node.get_script() != (Stockade if field == "wall_parts" else Gate) or nodes.find(node) < 1 or owned_parts.has(node): return _fail("LEVEL5_ENTRANCE_PART_OWNER", field)
			owned_parts[node] = true; owners[field].append(nodes.find(node))
	for child: Node in entrance.get_children(true):
		if child.get_script() == ArtEvent and child.get_meta("campaign_environment_route", "") in ["dock_straight", "dock_head_t"]:
			if owned_parts.has(child): return _fail("LEVEL5_ENTRANCE_PART_OWNER", "dock_parts")
			owned_parts[child] = true; owners.dock_parts.append(nodes.find(child))
		elif not owned_parts.has(child): return _fail("LEVEL5_ENTRANCE_PART_MISSING")
	if owners.gate_parts.size() != 3 or owners.side_gate_parts.size() != 3 or owners.wall_parts.is_empty() or owners.dock_parts.size() != 2: return _fail("LEVEL5_ENTRANCE_PART_COUNT")
	for field: String in ["trees", "sprites", "guard_posts"]:
		for node: Node in visual.get("_" + field):
			if not is_instance_valid(node) or node.get_parent() != visual or node.get_script() not in ([Scenery.ScenerySprite, Flag] if field == "sprites" else [Scenery.ScenerySprite]) or nodes.find(node) < 1 or owners[field].has(nodes.find(node)): return _fail("LEVEL5_OWNER_ARRAY", field)
			owners[field].append(nodes.find(node))
	for index: int in owners.trees:
		if not owners.sprites.has(index) or not nodes[index].is_tree: return _fail("LEVEL5_TREE_OWNER")
	for index: int in owners.guard_posts:
		if not owners.sprites.has(index) or nodes[index].is_tree: return _fail("LEVEL5_POST_OWNER")
	for node: Node in visual.get_children(true):
		if node.get_script() in [Scenery.ScenerySprite, Flag] and not owners.sprites.has(nodes.find(node)): return _fail("LEVEL5_SPRITE_OWNER")
		if node.get_script() == Scenery.ScenerySprite and node.is_tree and not owners.trees.has(nodes.find(node)): return _fail("LEVEL5_TREE_OWNER")
	return {"ok": true, "value": owners}

func _validate_native_ownership(value: Variant, records: Array) -> Dictionary:
	if not _fields(value, ["entrance", "trees", "sprites", "guard_posts", "gate_parts", "side_gate_parts", "wall_parts", "dock_parts"]): return _fail("LEVEL5_OWNER_SCHEMA")
	if typeof(value.entrance) != TYPE_INT or value.entrance < 1 or value.entrance >= records.size(): return _fail("LEVEL5_ENTRANCE_ID")
	for field: String in ["trees", "sprites", "guard_posts"]:
		if typeof(value[field]) != TYPE_ARRAY or value[field].size() > records.size(): return _fail("LEVEL5_OWNER_SCHEMA", field)
	for field: String in ["gate_parts", "side_gate_parts", "wall_parts", "dock_parts"]:
		if typeof(value[field]) != TYPE_ARRAY or value[field].size() > records.size(): return _fail("LEVEL5_ENTRANCE_PART_SCHEMA", field)
	var decoded: Array = []
	for record: Variant in records: decoded.append(Codec.new().decode(record).value)
	if decoded[value.entrance].kind != "entrance" or decoded[value.entrance].parent != 0: return _fail("LEVEL5_ENTRANCE_ID")
	var owned_parts := {}
	for field: String in ["gate_parts", "side_gate_parts", "wall_parts", "dock_parts"]:
		var expected_kind := "stockade" if field == "wall_parts" else "art" if field == "dock_parts" else "gate"
		for index: Variant in value[field]:
			if typeof(index) != TYPE_INT or index < 1 or index >= decoded.size() or owned_parts.has(index) or decoded[index].parent != value.entrance or decoded[index].kind != expected_kind: return _fail("LEVEL5_ENTRANCE_PART_ID", field)
			owned_parts[index] = true
			if field == "dock_parts" and decoded[index].metadata.get("campaign_environment_route", "") not in ["dock_straight", "dock_head_t"]: return _fail("LEVEL5_DOCK_PART_ID")
	for index: int in range(decoded.size()):
		if decoded[index].parent == value.entrance and not owned_parts.has(index): return _fail("LEVEL5_ENTRANCE_PART_MISSING")
	if value.gate_parts.size() != 3 or value.side_gate_parts.size() != 3 or value.wall_parts.is_empty() or value.dock_parts.size() != 2: return _fail("LEVEL5_ENTRANCE_PART_COUNT")

	for field: String in ["trees", "sprites", "guard_posts"]:
		if typeof(value[field]) != TYPE_ARRAY or value[field].size() > records.size(): return _fail("LEVEL5_OWNER_SCHEMA", field)
		var seen := {}
		for index: Variant in value[field]:
			if typeof(index) != TYPE_INT or index < 1 or index >= records.size() or seen.has(index) or decoded[index].kind not in (["sprite", "flag"] if field == "sprites" else ["sprite"]) or decoded[index].parent != 0: return _fail("LEVEL5_OWNER_ID", field)
			seen[index] = true
			if field != "sprites" and not value.sprites.has(index): return _fail("LEVEL5_OWNER_MEMBERSHIP", field)
			if field == "trees" and not decoded[index].fixed.is_tree: return _fail("LEVEL5_TREE_OWNER")
			if field == "guard_posts" and decoded[index].fixed.is_tree: return _fail("LEVEL5_POST_OWNER")
	for index: int in range(decoded.size()):
		if decoded[index].kind in ["sprite", "flag"] and decoded[index].parent == 0 and not value.sprites.has(index): return _fail("LEVEL5_OWNER_MEMBERSHIP", "sprites")
		if decoded[index].kind == "sprite" and decoded[index].parent == 0 and decoded[index].fixed.is_tree and not value.trees.has(index): return _fail("LEVEL5_TREE_OWNER")
	return {"ok": true}

func _daming_campaign() -> bool:
	return _campaign_enabled() and _trusted_context.level_id == "level8"

func _allowed_campaign_kinds() -> Array:
	return NATIVE_CAMPAIGN_KINDS if _native_campaign() else CAMPAIGN_KINDS + DAMING_KINDS if _daming_campaign() else CAMPAIGN_KINDS

func _campaign_binding_map(node: Node) -> Node:
	var visual: Node = node.get_parent()
	return null if visual == null or visual.get_script() != CampaignScenery else visual._map

func _city_wall_mesh_valid(node: Node2D) -> bool:
	if node._mesh == null: return true
	if not node._mesh is ArrayMesh: return false
	var probe = CityWall.new()
	probe.end_local = node.end_local; probe.height_scale = node.height_scale; probe.salt = node.salt
	probe._build_mesh()
	var same: bool = node._mesh.get_surface_count() == probe._mesh.get_surface_count()
	if same:
		for i: int in range(node._mesh.get_surface_count()):
			if node._mesh.surface_get_format(i) != probe._mesh.surface_get_format(i) or node._mesh.surface_get_primitive_type(i) != probe._mesh.surface_get_primitive_type(i) or node._mesh.surface_get_arrays(i) != probe._mesh.surface_get_arrays(i): same = false
	probe.free()
	return same

func _daming_ownership(visual: Node2D) -> Dictionary:
	var lights: Dictionary = DamingLighting.new(_content_version, _trusted_context).capture(visual)
	if not lights.ok: return lights
	if visual._entrance != null or not visual._guard_posts.is_empty(): return _fail("DAMING_EXTRA_NATIVE_OWNER")
	var nodes: Array = []; _walk_nodes(visual, nodes)
	var owners := {"walls": [], "sprites": [], "trees": [], "ground_shadows": []}
	var walls: Array = []; var sprites: Array = []; var trees: Array = []
	for child: Node in visual.get_children(true):
		if child.get_script() in [CityWall, Passage]: walls.append(child)
		elif child is CanvasModulate or child is PointLight2D: continue
		else: sprites.append(child)
	for child: Node in sprites:
		if child.get_script() != Scenery.ScenerySprite: continue
		var key: String = str(child.get_meta("campaign_object", ""))
		if child.is_tree or (not child.has_meta("campaign_environment_route") and not key.is_empty() and key not in ["boat", "dock", "bridge", "banner", "rocks"]): trees.append(child)
	for field: String in ["walls", "sprites", "trees"]:
		var expected: Array = walls if field == "walls" else sprites if field == "sprites" else trees
		if visual.get("_" + field) != expected: return _fail("DAMING_OWNER_ARRAY", field)
		for child: Node in expected:
			var index: int = nodes.find(child)
			if index < 1 or owners[field].has(index): return _fail("DAMING_OWNER_ID", field)
			owners[field].append(index)
	for shadow: Variant in visual._ground_shadows:
		if not _fields(shadow, ["p", "tex", "s", "foot", "alpha"]): return _fail("DAMING_SHADOW_FIELDS")
		var encoded: Dictionary = Codec.new().encode({"p": shadow.p, "tex": _texture_descriptor(shadow.tex), "s": shadow.s, "foot": shadow.foot, "alpha": shadow.alpha})
		if not encoded.ok: return _fail("DAMING_SHADOW_CODEC")
		owners.ground_shadows.append(encoded.value)
	return {"ok": true, "value": owners}

func _daming_tower_state(records: Array) -> String:
	for record: Variant in records:
		var node: Dictionary = Codec.new().decode(record).value
		if node.metadata.get("campaign_object", "") == "cuiyun_tower": return String(node.metadata.get("campaign_environment_state", ""))
	return ""

func _validate_daming_ownership(snapshot: Dictionary) -> Dictionary:
	var light_adapter = DamingLighting.new(_content_version, _trusted_context)
	var lights: Dictionary = light_adapter.validate(snapshot.lighting)
	if not lights.ok: return lights
	var owners: Variant = snapshot.ownership
	if not _fields(owners, ["walls", "sprites", "trees", "ground_shadows"]): return _fail("DAMING_OWNER_SCHEMA")
	var nodes: Array = []
	for record: Variant in snapshot.nodes: nodes.append(Codec.new().decode(record).value)
	var expected := {"walls": [], "sprites": [], "trees": []}
	var lamps: Array = []; var walls := 0; var passages := 0; var nights := 0; var towers := 0
	for i: int in range(1, nodes.size()):
		var node: Dictionary = nodes[i]
		if node.parent != 0: return _fail("DAMING_DIRECT_CHILD_REQUIRED", str(i))
		match node.kind:
			"night":
				nights += 1
				if i != lights.value.ownership.night: return _fail("DAMING_NIGHT_OWNER")
			"lantern":
				lamps.append(i)
				if node.textures.texture != {"kind": "daming_lantern_v1"}: return _fail("DAMING_LANTERN_TEXTURE")
			"city_wall": walls += 1; expected.walls.append(i)
			"passage": passages += 1; expected.walls.append(i)
			_:
				expected.sprites.append(i)
				if node.kind == "sprite":
					var key: String = str(node.metadata.get("campaign_object", ""))
					if node.fixed.is_tree or (not node.metadata.has("campaign_environment_route") and not key.is_empty() and key not in ["boat", "dock", "bridge", "banner", "rocks"]): expected.trees.append(i)
		if node.metadata.get("campaign_object", "") == "cuiyun_tower": towers += 1
	if nights != 1 or walls != 113 or passages != 1 or lamps != lights.value.ownership.lamps or towers != 1: return _fail("DAMING_FIXED_COUNTS")
	for field: String in ["walls", "sprites", "trees"]:
		if typeof(owners[field]) != TYPE_ARRAY or owners[field] != expected[field]: return _fail("DAMING_OWNER_MEMBERSHIP", field)
	for i: int in range(lamps.size()):
		if nodes[lamps[i]].runtime.energy != lights.value.energies[i]: return _fail("DAMING_LIGHT_ENVELOPE_STATE")
	var state: String = _daming_tower_state(snapshot.nodes)
	if state not in ["default", "signal"] or lights.value.energies[4] != light_adapter._energy(1.15 if state == "signal" else 0.45): return _fail("DAMING_SIGNAL_VISUAL_CONSISTENCY")
	if typeof(owners.ground_shadows) != TYPE_ARRAY or owners.ground_shadows.size() > MAX_NODES: return _fail("DAMING_SHADOW_COUNT")
	for record: Variant in owners.ground_shadows:
		var decoded: Dictionary = Codec.new().decode(record)
		if not decoded.ok or not _fields(decoded.value, ["p", "tex", "s", "foot", "alpha"]): return _fail("DAMING_SHADOW_CODEC")
		var value: Dictionary = decoded.value
		if typeof(value.p) != TYPE_VECTOR2 or not value.p.is_finite() or not _texture_descriptor_valid(value.tex) or not _finite_number(value.s) or not _finite_number(value.foot) or not _finite_number(value.alpha): return _fail("DAMING_SHADOW_VALUE")
	return {"ok": true}

func _fixed_difference(saved: Dictionary, rebuilt: Dictionary) -> String:
	for field: String in ["parent", "kind", "fixed", "textures", "metadata"]:
		var delta: String = _value_difference(saved[field], rebuilt[field], field)
		if not delta.is_empty(): return delta
	return "unresolved"

func _value_difference(a: Variant, b: Variant, path: String) -> String:
	if typeof(a) != typeof(b): return path + ":types=" + str(typeof(a)) + "/" + str(typeof(b))
	if typeof(a) == TYPE_DICTIONARY:
		if a.size() != b.size(): return path + ":field_counts=" + str(a.size()) + "/" + str(b.size()) + ":saved=" + str(a) + ":rebuilt=" + str(b)
		for key: Variant in a:
			if not b.has(key): return path + "/missing=" + str(key)
			var delta: String = _value_difference(a[key], b[key], path + "/" + str(key))
			if not delta.is_empty(): return delta
		return ""
	if typeof(a) == TYPE_ARRAY:
		if a.size() != b.size(): return path + ":lengths=" + str(a.size()) + "/" + str(b.size())
		for i: int in range(a.size()):
			var delta: String = _value_difference(a[i], b[i], path + "/" + str(i))
			if not delta.is_empty(): return delta
		return ""
	return "" if a == b else path + ":saved=" + str(a) + ":rebuilt=" + str(b)

func prepared_capture_ready(game_map: GameMap, content_version: String, context: Dictionary) -> bool:
	if not _campaign_used or _campaign_activated or _content_version != content_version or _trusted_context != context or typeof(context.get("waves")) != TYPE_INT: return false
	if not is_instance_valid(_campaign_owner) or _campaign_owner != game_map or not is_instance_valid(_campaign_visual) or game_map.sample_scenery != _campaign_visual or _campaign_visual.get_parent() != game_map: return false
	if _campaign_activation.size() != _campaign_order.size() or _campaign_order.is_empty(): return false
	if _campaign_order[0] != _campaign_visual: return false
	var world: Node = game_map.get_parent()
	if not is_instance_valid(world): return false
	var owner: Node = world.get_parent()
	if not is_instance_valid(owner) or owner.get_script() != BattleScript or owner.get("map") != game_map: return false
	if owner.process_mode != Node.PROCESS_MODE_DISABLED or not owner.is_blocking_signals() or (owner.is_inside_tree() and not owner.get_tree().paused): return false
	var children := {}
	for node: Node in _campaign_order:
		if not is_instance_valid(node) or not _campaign_activation.has(node) or not node.is_blocking_signals() or node.process_mode != Node.PROCESS_MODE_DISABLED: return false
		children[node] = []
	for node: Node in _campaign_order:
		if node == _campaign_visual: continue
		if not children.has(node.get_parent()): return false
		children[node.get_parent()].append(node)
	for node: Node in _campaign_order:
		if node.get_children(true) != children[node]: return false
	return _campaign_map(game_map).ok
