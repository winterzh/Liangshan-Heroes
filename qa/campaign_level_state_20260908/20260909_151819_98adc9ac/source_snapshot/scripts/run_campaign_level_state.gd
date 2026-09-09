extends RefCounted
## Level component only. Mission, visuals, Unit metadata, RNG and Battle remain
## externally owned. Never calls deploy/on_start or activates a world.
const Codec := preload("res://scripts/run_state_value_codec.gd")
const U := preload("res://scripts/unit.gd")
const SCHEMA := "campaign_level_component_v1"
const SCRIPTS := {
	"level1": preload("res://scripts/levels/level1_huangnigang_short.gd"),
	"level2": preload("res://scripts/levels/level2_jiangzhou_rts.gd"),
	"level3": preload("res://scripts/levels/level3_zhujiazhuang_rts.gd"),
	"level4": preload("res://scripts/levels/level4_lianhuanma_rts.gd"),
	"level5": preload("res://scripts/levels/level5_gao_rts.gd"),
	"level6": preload("res://scripts/levels/level6_yezhulin.gd"),
	"level7": preload("res://scripts/levels/level7_kuaihuolin_short.gd"),
	"level8": preload("res://scripts/levels/level8_daming_rts.gd")}
# Explicit declarations, including inherited fields. Reflection never selects data.
const FIELDS := {
	"level1": {
		"int": "st core_dead delivered distraction_serial controls_generation",
		"bool": "drug_done attention_missed clean_trial scoop_prepared sale_drugged suspicion_seen cover_restored force_started victory depart_requested",
		"float": "rest_t exposure smoke_t attention_left team_t convoy_entry_t",
		"text": "cargo_plan cargo_objective_cache wine_step", "strings": "suspicious_keys",
		"index_text": "cargo_assignments", "index_bool": "cargo_ready", "index_int": "force_attempts",
		"unit": "cart yang", "units": "convoy bundles actors", "index_unit": "cargo",
		"external": "good_sign sale_sign suspicion_sign", "externals": "field_signs jujube_carts"},
	"level2": {
		"int": "enemy_produced enemy_spent_gold enemy_spent_wood", "bools": "cache_taken",
		"bool": "alarm execution_halted pursuit_sent first_rescued meeting rally victory",
		"float": "exec_left elapsed strategy_t train_left pursuit_left",
		"unit": "post scaffold temple song_bound dai_bound song_freed dai_freed",
		"units": "camps caches executioners city_guards pursuit blockers towers reinforcements",
		"named_units": "named_units", "external": "depart_button"},
	"level3": {
		"int": "ai_trained ai_spent_gold ai_spent_wood raids_sent",
		"bool": "expansion_secured supply_cut inside_open prisoners_freed manor_fallen sent_sun main_breached",
		"float": "elapsed train_clock raid_clock strategic_clock", "text": "stage",
		"unit": "hall song gate side_gate enemy_base outpost hu sun",
		"units": "prisoners workers enemy_workers enemy_nodes reserve trained resource_guards"},
	"level4": {
		"int": "ai_trained ai_spent_gold ai_spent_wood broken_count lhm_killed",
		"bool": "manor_fallen drill_entered drill_withdrew drill_coordinated drill_complete",
		"float": "elapsed strategy_t escort_t", "vec": "drill_lure_origin", "text": "phase_title", "waves": "waves",
		"unit": "hall song xu hu han enemy_base dummy drill_lure",
		"units": "riders posts workers enemy_workers enemy_nodes escorts"},
	"level5": {
		"int": "ai_spent_gold ai_spent_wood", "ints": "produced", "floats": "production_t",
		"bool": "lure_started fire_prepared fire_lit port_sealed flagship_disabled recovered landed capture_lost core_ready escort_warning",
		"float": "elapsed strategy_t", "cell": "lure_cell", "waves": "waves",
		"unit": "hall song flagship fireboat embarked_liu liu_carrier prisoner carrier",
		"units": "workers posts support", "groups": "water_groups land_groups", "external": "end_button"},
	"level6": {
		"int": "st wave_n escort_player_token", "bool": "rescued alarm tracking_done treated shadow_cautioned shadow_warning rest_reached player_control_guard_fired victory",
		"float": "exec_timer wave_t smoke_t shadow_attention care_t help_t", "text": "shadow_route",
		"target": "escort_player_target", "orders": "escort_orders", "unit": "lin_bound lin_freed lu", "units": "escorts"},
	"level7": {
		"int": "drunk st special_index heavy_dodges rush_dodges controls_generation opening_serial step_serial counter_hits",
		"bool": "boss_on dodged story_step_primed charge_running victory",
		"float": "smoke_t fist_cd fist_windup steady_left exposed_left", "text": "special_kind",
		"vec": "fist_at drill_origin rush_from rush_end step_origin",
		"unit": "wu shi sign menshen", "taverns": "taverns", "external": "fist_marker drill_marker"},
	"level8": {
		"int": "ai_trained ai_spent_gold ai_spent_wood",
		"bool": "gate_open prison_open rescued signaled reserve_returned pursuit_warned pursuit_sent",
		"float": "signal_left elapsed strategy_t train_t pursuit_t", "text": "phase_title",
		"unit": "hall strategist scout chai yue gate lu shi enemy_hq",
		"units": "posts towers spies workers enemy_workers reserve pursuit escorts"}}
const MAX_REFERENCES := 4096
# These pools retain their slots after a death; nullable entries are legal,
# deleting a slot is not. Only arrays with fixed production consumers/layouts
# are listed. Trained troops, reserves, support and similar pools stay variable.
const REFERENCE_SHAPES := {
	"level1": {"bundles": 3},
	"level2": {"caches": 2, "executioners": 2},
	"level3": {"prisoners": 7},
	"level4": {"posts": 2, "riders": 12},
	"level5": {"posts": 2, "water_groups": [3, 5, 6], "land_groups": [4, 6, 8]},
	"level6": {"escorts": 2},
	"level7": {"taverns": 4},
	"level8": {"posts": 2}}
var _codec := Codec.new()

func _bad(code: String, field := "") -> Dictionary:
	return {"ok": false, "code": code, "field": field, "complete_world": false}

func _fields(v: Variant, names: Array) -> bool:
	return typeof(v) == TYPE_DICTIONARY and v.size() == names.size() and v.has_all(names)

func _id(v: Variant) -> bool:
	if typeof(v) != TYPE_STRING or v.is_empty() or v.length() > 19 or v[0] == "0": return false
	for c in v:
		if c < "0" or c > "9": return false
	return v.length() < 19 or v <= "9223372036854775806"

func _token(v: Variant) -> bool:
	return typeof(v) == TYPE_STRING and not v.is_empty() and v.length() <= 256

func _names(level_id: String) -> Dictionary:
	var result := {}
	for kind: String in FIELDS[level_id]:
		for field: String in String(FIELDS[level_id][kind]).split(" ", false): result[field] = kind
	return result

func audit_declarations(level_id: String) -> Dictionary:
	if not SCRIPTS.has(level_id): return _bad("OFFICIAL_LEVEL_REQUIRED")
	var expected := _names(level_id)
	var found := {}
	var script: Script = SCRIPTS[level_id]
	while script != null:
		for p: Dictionary in script.get_script_property_list():
			if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: found[String(p.name)] = true
		script = script.get_base_script()
	for field: String in found:
		if not expected.has(field): return _bad("UNCLASSIFIED_DECLARATION", field)
	for field: String in expected:
		if not found.has(field): return _bad("MISSING_DECLARATION", field)
	return {"ok": true, "fields": expected.size()}

func _prepared(node: Node) -> bool:
	# The caller assembles a private graph first. Binding an already mounted
	# world is intentionally unsupported even if its SceneTree is paused.
	return not node.is_inside_tree() and node.process_mode == Node.PROCESS_MODE_DISABLED and node.is_blocking_signals()

func _registry(ids: Dictionary, next_id: int, prepared := false) -> Dictionary:
	if ids.size() > MAX_REFERENCES or next_id < 1: return _bad("REGISTRY_LIMIT")
	var inverse := {}
	for id: Variant in ids:
		var u: Variant = ids[id]
		if not _id(id) or String(id).to_int() >= next_id or not is_instance_valid(u) or u.get_script() != U or u.is_queued_for_deletion() or str(u.entity_id) != id or inverse.has(u): return _bad("REGISTRY")
		if prepared and not _prepared(u): return _bad("DETACHED_DISABLED_UNIT_REQUIRED")
		inverse[u] = id
	return {"ok": true, "inverse": inverse}

# Single nullable references retain absent slots. A freed reference is explicitly
# absent; an extant but unregistered/queued object is rejected, never dropped.
func _encode_ref(v: Variant, ids: Dictionary, external := false) -> Dictionary:
	if v == null or (typeof(v) == TYPE_OBJECT and not is_instance_valid(v)): return {"ok": true, "value": null}
	if typeof(v) != TYPE_OBJECT or not is_instance_valid(v) or not ids.has(v): return _bad("UNBOUND_EXTERNAL" if external else "UNBOUND_UNIT")
	if external:
		if not v is Node or v.is_queued_for_deletion() or not _token(ids[v]): return _bad("EXTERNAL_BINDING")
	elif v.get_script() != U or v.is_queued_for_deletion() or not _id(ids[v]): return _bad("UNIT_BINDING")
	return {"ok": true, "value": ids[v]}

func _map_refs(v: Variant, kind: String, ids: Dictionary, encode: bool) -> Dictionary:
	if kind in ["unit", "external"]:
		if encode: return _encode_ref(v, ids, kind == "external")
		if v == null: return {"ok": true, "value": null}
		if (not _token(v) if kind == "external" else not _id(v)) or not ids.has(v): return _bad("UNBOUND_EXTERNAL" if kind == "external" else "UNBOUND_UNIT")
		return {"ok": true, "value": ids[v]}
	if kind in ["units", "externals", "groups", "taverns"]:
		if typeof(v) != TYPE_ARRAY or v.size() > MAX_REFERENCES: return _bad("REFERENCE_ARRAY")
		var rows: Array = []
		for item: Variant in v:
			var child_kind := "units" if kind == "groups" else "external" if kind == "externals" else "unit"
			if kind == "taverns" and (not _fields(item, ["u", "drunk"]) or typeof(item.drunk) != TYPE_BOOL): return _bad("TAVERN_ROW")
			var row := _map_refs(item.u if kind == "taverns" else item, child_kind, ids, encode)
			if not row.ok: return row
			rows.append({"u": row.value, "drunk": item.drunk} if kind == "taverns" else row.value)
		return {"ok": true, "value": rows}
	if typeof(v) != TYPE_DICTIONARY or v.size() > MAX_REFERENCES: return _bad("REFERENCE_MAP")
	var mapped := {}
	for key: Variant in v:
		if kind == "index_unit":
			if typeof(key) != TYPE_INT or key < 0 or key > 2: return _bad("CARGO_INDEX")
		elif not _token(key): return _bad("NAMED_UNIT_KEY")
		var row := _map_refs(v[key], "unit", ids, encode)
		if not row.ok: return row
		mapped[key] = row.value
	return {"ok": true, "value": mapped}

func _value(v: Variant, kind: String, field: String, next_id: int) -> bool:
	match kind:
		"bool": return typeof(v) == TYPE_BOOL
		"int": return typeof(v) == TYPE_INT and v >= -1 and v <= 9223372036854775806
		"float": return typeof(v) == TYPE_FLOAT and is_finite(v)
		"text": return typeof(v) == TYPE_STRING and v.length() <= 4096
		"vec": return typeof(v) == TYPE_VECTOR2 and v.is_finite()
		"cell": return typeof(v) == TYPE_VECTOR2I
		"target": return typeof(v) == TYPE_VECTOR2 and (v.is_finite() or v == Vector2.INF)
		"strings", "bools", "ints", "floats", "waves":
			if typeof(v) != TYPE_ARRAY or v.size() > MAX_REFERENCES: return false
			for row: Variant in v:
				if kind == "waves":
					if not _fields(row, ["time", "sent", "warned"]) or typeof(row.time) != TYPE_FLOAT or not is_finite(row.time) or row.time < 0 or typeof(row.sent) != TYPE_BOOL or typeof(row.warned) != TYPE_BOOL: return false
				elif not _value(row, {"strings":"text", "bools":"bool", "ints":"int", "floats":"float"}[kind], field, next_id): return false
			return true
		"index_text", "index_bool", "index_int", "orders":
			if typeof(v) != TYPE_DICTIONARY or v.size() > MAX_REFERENCES: return false
			for key: Variant in v:
				if typeof(key) != TYPE_INT or (key <= 0 or key >= next_id if kind == "orders" else key < 0 or key > 2): return false
				if not _value(v[key], "int" if kind in ["index_int", "orders"] else "bool" if kind == "index_bool" else "text", field, next_id): return false
			return true
	return false

func _checks(level_id: String, values: Dictionary) -> bool:
	if values.has("victory") and values.victory: return false
	if level_id in ["level1", "level6", "level7"] and (values.st < 0 or values.st > (7 if level_id == "level1" else 3)): return false
	if level_id == "level2" and values.cache_taken.size() != 2: return false
	if level_id == "level3" and values.stage not in ["scout", "contest", "siege"]: return false
	if level_id in ["level4", "level5"] and values.waves.size() != (2 if level_id == "level4" else 3): return false
	if level_id == "level5" and (values.production_t.size() != 2 or values.produced.size() != 2): return false
	if level_id == "level1" and (values.delivered < 0 or values.delivered > 3): return false
	if level_id == "level4" and (values.broken_count < 0 or values.broken_count > 12 or values.lhm_killed < 0 or values.lhm_killed > 12): return false
	if level_id == "level7" and values.special_kind not in ["heavy", "rush"]: return false
	return true

func _reference_shapes(level_id: String, references: Dictionary) -> Dictionary:
	for field: String in REFERENCE_SHAPES[level_id]:
		var expected: Variant = REFERENCE_SHAPES[level_id][field]
		var rows: Variant = references.get(field)
		if typeof(rows) != TYPE_ARRAY: return _bad("REFERENCE_DIMENSION", field)
		if typeof(expected) == TYPE_INT:
			if rows.size() != expected: return _bad("REFERENCE_DIMENSION", field)
			# A destroyed tribute bundle immediately loses level1; a resumable
			# chapter cannot have holes because marching/carrying dereferences it.
			if level_id == "level1" and field == "bundles" and rows.has(null): return _bad("REQUIRED_BUNDLE_REFERENCE", field)
		else:
			if rows.size() != expected.size(): return _bad("REFERENCE_DIMENSION", field)
			for index in range(expected.size()):
				if typeof(rows[index]) != TYPE_ARRAY or rows[index].size() != expected[index]: return _bad("REFERENCE_DIMENSION", field)
	return {"ok": true}

func _external_types(field: String, value: Variant) -> bool:
	if value == null or (typeof(value) == TYPE_OBJECT and not is_instance_valid(value)): return true
	if field in ["field_signs", "jujube_carts"]:
		if typeof(value) != TYPE_ARRAY: return false
		for item: Variant in value:
			if item != null and is_instance_valid(item) and not item is Node2D: return false
		return true
	return value is Button if field in ["depart_button", "end_button"] else value is Node2D

func capture(level: Variant, level_id: String, content_version: String, id_to_unit: Dictionary,
		next_entity_id: int, external_to_token: Dictionary, boundary: Dictionary) -> Dictionary:
	if not SCRIPTS.has(level_id) or not is_instance_valid(level) or level.get_script() != SCRIPTS[level_id]: return _bad("OFFICIAL_LEVEL_REQUIRED")
	if not _token(content_version): return _bad("CONTENT_VERSION")
	if not _fields(boundary, ["mission_token", "deferred_drained"]) or not _token(boundary.mission_token) or boundary.deferred_drained != true: return _bad("EXTERNAL_BOUNDARY_REQUIRED")
	var audit := audit_declarations(level_id)
	if not audit.ok: return audit
	var registry := _registry(id_to_unit, next_entity_id)
	if not registry.ok: return registry
	var seen := {}
	for object: Variant in external_to_token:
		var token: Variant = external_to_token[object]
		if not _token(token) or seen.has(token): return _bad("EXTERNAL_TOKEN_ALIAS")
		seen[token] = true
	var values := {}; var refs := {}; var external := {}
	var names := _names(level_id)
	for field: String in names:
		var kind: String = names[field]
		var v: Variant = level.get(field)
		if kind in ["unit", "units", "groups", "index_unit", "named_units", "taverns", "external", "externals"]:
			var is_external := kind in ["external", "externals"]
			if is_external and not _external_types(field, v): return _bad("EXTERNAL_TYPE", field)
			var mapped := _map_refs(v, kind, external_to_token if is_external else registry.inverse, true)
			if not mapped.ok: return _bad(mapped.code, field)
			if is_external: external[field] = mapped.value
			else: refs[field] = mapped.value
		else:
			if not _value(v, kind, field, next_entity_id): return _bad("VALUE_TYPE", field)
			values[field] = {"none": true} if kind == "target" and v == Vector2.INF else v
	if not _checks(level_id, values): return _bad("LEVEL_INVARIANT")
	var dimensions := _reference_shapes(level_id, refs)
	if not dimensions.ok: return dimensions
	var packed := _codec.encode({"values": values, "references": refs, "external": external})
	if not packed.ok: return packed
	return {"ok": true, "record": {"schema": SCHEMA, "level_id": level_id, "content_version": content_version, "mission_token": boundary.mission_token, "payload": packed.value}, "complete_world": false}

func validate(record: Variant, level_id: String, content_version: String, known_unit_ids: Dictionary,
		next_entity_id: int, external_tokens: Dictionary, mission_token: String) -> Dictionary:
	if not SCRIPTS.has(level_id) or not _token(content_version) or not _token(mission_token): return _bad("TRUSTED_CONTEXT")
	var audit := audit_declarations(level_id)
	if not audit.ok: return audit
	if not _fields(record, ["schema", "level_id", "content_version", "mission_token", "payload"]): return _bad("RECORD_IDENTITY")
	# Decoded files can carry any Variant. Reject identity types before comparing
	# them with trusted strings; invalid Variant comparisons can abort restoration.
	for field: String in ["schema", "level_id", "content_version", "mission_token"]:
		if typeof(record[field]) != TYPE_STRING: return _bad("RECORD_IDENTITY", field)
	if record.schema != SCHEMA or record.level_id != level_id or record.content_version != content_version or record.mission_token != mission_token: return _bad("RECORD_IDENTITY")
	if next_entity_id < 1 or known_unit_ids.size() > MAX_REFERENCES: return _bad("REGISTRY_LIMIT")
	for id: Variant in known_unit_ids:
		if not _id(id) or String(id).to_int() >= next_entity_id: return _bad("REGISTRY")
	var decoded := _codec.decode(record.payload)
	if not decoded.ok: return decoded
	if not _fields(decoded.value, ["values", "references", "external"]): return _bad("PAYLOAD_FIELDS")
	var data: Dictionary = decoded.value
	for section: String in data:
		if typeof(data[section]) != TYPE_DICTIONARY: return _bad("SECTION_TYPE")
	var names := _names(level_id)
	var count := 0
	for field: String in names:
		var kind: String = names[field]
		var section := "external" if kind in ["external", "externals"] else "references" if kind in ["unit", "units", "groups", "index_unit", "named_units", "taverns"] else "values"
		if not data[section].has(field): return _bad("MISSING_FIELD", field)
		count += 1
		var v: Variant = data[section][field]
		if section == "values":
			if kind == "target" and _fields(v, ["none"]) and v.none == true: v = Vector2.INF
			if not _value(v, kind, field, next_entity_id): return _bad("VALUE_TYPE", field)
			data.values[field] = v
		else:
			var mapped := _map_refs(v, kind, external_tokens if section == "external" else known_unit_ids, false)
			if not mapped.ok: return _bad(mapped.code, field)
	if count != data.values.size() + data.references.size() + data.external.size(): return _bad("UNKNOWN_FIELD")
	if not _checks(level_id, data.values): return _bad("LEVEL_INVARIANT")
	var dimensions := _reference_shapes(level_id, data.references)
	if not dimensions.ok: return dimensions
	return {"ok": true, "value": data, "complete_world": false, "mission_and_visuals_owned_by_caller": true}

func restore(record: Variant, level_id: String, content_version: String, id_to_unit: Dictionary,
		next_entity_id: int, token_to_external: Dictionary, mission_token: String) -> Dictionary:
	var registry := _registry(id_to_unit, next_entity_id, true)
	if not registry.ok: return registry
	var seen := {}
	for token: Variant in token_to_external:
		var node: Variant = token_to_external[token]
		if not _token(token) or not is_instance_valid(node) or not node is Node or node.is_queued_for_deletion() or seen.has(node): return _bad("EXTERNAL_BINDING")
		if not _prepared(node): return _bad("DETACHED_DISABLED_EXTERNAL_REQUIRED")
		seen[node] = true
	var checked := validate(record, level_id, content_version, id_to_unit, next_entity_id, token_to_external, mission_token)
	if not checked.ok: return checked
	var level: Variant = SCRIPTS[level_id].new()
	var names := _names(level_id)
	for field: String in names:
		var kind: String = names[field]
		var v: Variant
		if checked.value.values.has(field): v = checked.value.values[field]
		else:
			var external := kind in ["external", "externals"]
			var source: Dictionary = checked.value.external if external else checked.value.references
			v = _map_refs(source[field], kind, token_to_external if external else id_to_unit, false).value
			if external and not _external_types(field, v): return _bad("EXTERNAL_TYPE", field)
		# Typed Array[Unit]/Array[String] fields retain the declared container type.
		var current: Variant = level.get(field)
		if typeof(current) == TYPE_ARRAY and current.is_typed(): current.assign(v); level.set(field, current)
		else: level.set(field, v)
	return {"ok": true, "level": level, "complete_world": false, "deploy_or_start_called": false,
		"mission_and_visuals_owned_by_caller": true, "requires_external_same_frame_install": true}
