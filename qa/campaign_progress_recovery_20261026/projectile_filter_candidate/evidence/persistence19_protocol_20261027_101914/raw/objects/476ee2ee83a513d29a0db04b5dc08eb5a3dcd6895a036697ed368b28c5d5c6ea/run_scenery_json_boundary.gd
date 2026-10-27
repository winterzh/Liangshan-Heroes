extends RefCounted
## Fixed serialized Map/Scenery ownership boundary only. No scene/resource factory,
## node assignment, callback, runtime tick, gameplay restore or script selection.
## Native source validation and JSON numeric normalization are separate entry points.
const SceneryState := preload("res://scripts/run_scenery_state.gd")
const MAP_FIELDS := ["schema", "content_version", "sections"]
const MAP_SECTIONS := ["header", "grid", "base_solid", "block_count", "height", "metadata", "display",
	"astar", "astar_guan", "astar_water", "astar_static", "astar_static_guan"]
const DISPLAY_FIELDS := ["schema", "content_version", "kind", "nodes", "material", "reed"]
const SCHEMAS := {
	"level1": "level1_scenery_state_v1", "level2": "level2_scenery_state_v1",
	"level3": "level3_scenery_state_v2", "level4": "level4_scenery_state_v1",
	"level5": "level5_native_scenery_state_v2", "level6": "level6_scenery_state_v1",
	"level7": "level7_scenery_state_v1", "level8": "level8_scenery_state_v1"}
const GAO_LISTS := ["trees", "sprites", "guard_posts", "gate_parts", "side_gate_parts", "wall_parts", "dock_parts"]
const DAMING_LISTS := ["walls", "sprites", "trees"]
const MAX_NODES := 4096

static func _bad(code: String, path: String = "") -> Dictionary:
	return {"ok": false, "code": code, "path": path, "source_changed": false}

static func _fields(value: Variant, names: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != names.size(): return false
	for key: Variant in value:
		if typeof(key) != TYPE_STRING or key not in names: return false
	return true

static func _select(map_record: Variant, version: String, context: Dictionary) -> Dictionary:
	if version.is_empty() or not _fields(map_record, MAP_FIELDS) or typeof(map_record.schema) != TYPE_STRING or map_record.schema != "game_map_v2" \
			or typeof(map_record.content_version) != TYPE_STRING or map_record.content_version != version \
			or not _fields(map_record.sections, MAP_SECTIONS): return _bad("SLOT_MAP_BOUNDARY_SCHEMA")
	if not _fields(context, ["mode", "level_id", "waves"]) or typeof(context.mode) != TYPE_STRING \
			or typeof(context.level_id) != TYPE_STRING or typeof(context.waves) != TYPE_INT:
		return _bad("SLOT_MAP_BOUNDARY_CONTEXT")
	var chapter: String = ""
	var scenery_context: Dictionary = {}
	if context.mode == "campaign" and context.level_id in SCHEMAS and context.waves == 0:
		chapter = context.level_id
		scenery_context = context.duplicate(true)
	elif context.mode != "defense" or context.level_id != "" or context.waves != 30:
		return _bad("SLOT_MAP_BOUNDARY_CONTEXT")
	var display: Variant = map_record.sections.display
	if typeof(display) != TYPE_DICTIONARY: return _bad("SLOT_MAP_DISPLAY_SCHEMA")
	for key: String in ["schema", "kind", "content_version"]:
		if typeof(display.get(key)) != TYPE_STRING: return _bad("SLOT_MAP_DISPLAY_SCHEMA", key)
	var adapter: RefCounted = SceneryState.new(version, scenery_context)
	if chapter == "" and _fields(display, ["schema", "content_version", "kind"]) \
			and display.schema == "scenery_state_v2" and display.content_version == version and display.kind == "none":
		return {"ok": true, "adapter": adapter, "display": display, "chapter": chapter, "node_count": 0, "lists": []}
	var expected_fields: Array = DISPLAY_FIELDS.duplicate()
	if chapter != "": expected_fields.append("context")
	if chapter in ["level5", "level8"]: expected_fields.append("ownership")
	if chapter == "level8": expected_fields.append("lighting")
	var expected_schema: String = "scenery_state_v2" if chapter == "" else SCHEMAS[chapter]
	var expected_kind: String = "liangshan" if chapter == "" else "campaign_" + chapter
	if not _fields(display, expected_fields) or display.schema != expected_schema or display.kind != expected_kind \
			or typeof(display.content_version) != TYPE_STRING or display.content_version != version:
		return _bad("SLOT_MAP_DISPLAY_SCHEMA")
	if chapter != "" and (not _fields(display.context, ["mode", "level_id"]) \
			or typeof(display.context.mode) != TYPE_STRING or typeof(display.context.level_id) != TYPE_STRING \
			or display.context.mode != "campaign" or display.context.level_id != chapter):
		return _bad("SLOT_MAP_DISPLAY_CONTEXT")
	if typeof(display.nodes) != TYPE_ARRAY or display.nodes.is_empty() or display.nodes.size() > MAX_NODES:
		return _bad("SLOT_MAP_DISPLAY_NODE_COUNT")
	var lists: Array = []
	if chapter == "level5":
		lists = GAO_LISTS
		if not _fields(display.ownership, ["entrance"] + GAO_LISTS): return _bad("SLOT_MAP_OWNER_SCHEMA")
	elif chapter == "level8":
		lists = DAMING_LISTS
		if not _fields(display.ownership, DAMING_LISTS + ["ground_shadows"]): return _bad("SLOT_MAP_OWNER_SCHEMA")
	return {"ok": true, "adapter": adapter, "display": display, "chapter": chapter,
		"node_count": display.nodes.size(), "lists": lists}

static func _native_index(value: Variant, node_count: int, path: String) -> Dictionary:
	if typeof(value) != TYPE_INT or value < 1 or value >= node_count:
		return _bad("SLOT_MAP_NATIVE_OWNER_INTEGER", path)
	return {"ok": true, "value": value}

static func _json_index(value: Variant, node_count: int, path: String) -> Dictionary:
	# Small bounded traversal IDs only: range/integrality checks precede int().
	# Bool/String/Nil, non-finite/fractional/out-of-range numbers never qualify.
	if typeof(value) == TYPE_INT: return _native_index(value, node_count, path)
	if typeof(value) != TYPE_FLOAT or not is_finite(value) or value < 1.0 \
			or value >= float(node_count) or floor(value) != value:
		return _bad("SLOT_MAP_JSON_OWNER_INTEGER", path)
	return {"ok": true, "value": int(value)}

static func validate_source(map_record: Variant, version: String, context: Dictionary) -> Dictionary:
	var selected: Dictionary = _select(map_record, version, context)
	if not selected.ok: return selected
	var display: Dictionary = selected.display
	if selected.chapter == "level5":
		var entrance: Dictionary = _native_index(display.ownership.entrance, selected.node_count, "ownership/entrance")
		if not entrance.ok: return entrance
	for field: String in selected.lists:
		var values: Variant = display.ownership[field]
		if typeof(values) != TYPE_ARRAY or values.size() > selected.node_count: return _bad("SLOT_MAP_OWNER_LIST", field)
		for index: int in range(values.size()):
			var checked: Dictionary = _native_index(values[index], selected.node_count, "ownership/" + field + "/" + str(index))
			if not checked.ok: return checked
	# Existing complete type, topology, partition, texture, material, reed,
	# lighting and membership checks remain authoritative and unchanged.
	var validated: Dictionary = selected.adapter.validate(display)
	if not validated.ok: return validated
	return {"ok": true, "source_changed": false}

static func normalize_json(map_record: Variant, version: String, context: Dictionary) -> Dictionary:
	var selected: Dictionary = _select(map_record, version, context)
	if not selected.ok: return selected
	var original_display: Dictionary = selected.display
	var output: Dictionary = map_record
	var changed_paths: Array = []
	if selected.chapter in ["level5", "level8"]:
		# Copy only the Map/display wrappers and designated ownership fields.
		# All Codec payloads and unrelated values retain their exact original data.
		output = map_record.duplicate(false)
		output.sections = map_record.sections.duplicate(false)
		var display: Dictionary = original_display.duplicate(false)
		display.ownership = original_display.ownership.duplicate(false)
		if selected.chapter == "level5":
			var entrance: Dictionary = _json_index(original_display.ownership.entrance, selected.node_count, "ownership/entrance")
			if not entrance.ok: return entrance
			display.ownership.entrance = entrance.value
			if typeof(original_display.ownership.entrance) == TYPE_FLOAT: changed_paths.append("ownership/entrance")
		for field: String in selected.lists:
			var values: Variant = original_display.ownership[field]
			if typeof(values) != TYPE_ARRAY or values.size() > selected.node_count: return _bad("SLOT_MAP_OWNER_LIST", field)
			var indexes: Array = []
			for index: int in range(values.size()):
				var path: String = "ownership/" + field + "/" + str(index)
				var checked: Dictionary = _json_index(values[index], selected.node_count, path)
				if not checked.ok: return checked
				indexes.append(checked.value)
				if typeof(values[index]) == TYPE_FLOAT: changed_paths.append(path)
			display.ownership[field] = indexes
		output.sections.display = display
	# Six older chapter schemas and both standard display forms are exact no-ops.
	# Original validator still rejects ownership injection or cross-chapter data.
	var validated: Dictionary = selected.adapter.validate(output.sections.display)
	if not validated.ok: return validated
	return {"ok": true, "value": output, "changed_paths": changed_paths, "source_changed": false}
