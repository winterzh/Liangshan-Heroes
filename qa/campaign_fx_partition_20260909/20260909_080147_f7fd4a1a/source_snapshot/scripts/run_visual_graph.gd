extends RefCounted
## Explicit shared visual graph subset. Real current Battle Fx scripts, no skill replay.
## Outer factory owns the paused barrier, Unit graph/tombstones and final activation.
## Unknown scripts/children fail the snapshot; they are never omitted or placeholders.
const SCHEMA := "defense_visual_graph_subset_v1"
const CAMPAIGN_SCHEMA := "level3_visual_graph_partition_v1"
const EXTERNAL_MARKER := "mission_marker"
const Presentation := preload("res://scripts/run_campaign_presentation_state.gd")
const MissionState := preload("res://scripts/run_campaign_mission_state.gd")
const Mission := preload("res://scripts/campaign_mission.gd")
const Linked := preload("res://scripts/run_linked_fx_state.gd")
const Procedural := preload("res://scripts/run_procedural_fx_state.gd")
const RemainsState := preload("res://scripts/run_death_remains_state.gd")
const LIMIT := 4096
const TEX := "res://assets/vfx/gong_beast_charge_run.png"
const FIELDS := {
	"container": [],
	"hua_snipe_aim": ["dur", "t", "life", "col"],
	"hua_snipe_mark": ["dur", "t", "life"],
	"hua_lock_mark": ["col", "pulse"],
	"lin_guard": ["dur", "t", "life", "col"],
	"lin_spear_stack": ["dur", "t", "stacks", "proc"],
	"lin_duel": ["dur", "t", "life", "col"],
	"ability_projectile": ["dur", "t", "end_w", "col", "lob", "_E", "_ang", "tex", "impact_tex"],
	"ability_impact": ["dur", "t", "rad", "col", "mode", "tex"],
	"orbit_axes": ["dur", "t", "rad", "col", "life", "_spin", "tex"],
	"black_rain": ["dur", "t", "rad", "col", "life", "lite", "_drops"],
	"firefly": ["dur", "t", "life", "col", "_motes"],
	"fading_mark": ["t"],
	"hua_target_arrow": ["dur", "t", "end_w", "col", "snipe", "lock_shots", "travel", "_E"],
	"lin_counter": ["dur", "t", "end_w", "col", "_end"],
	"lin_duel_resolve": ["dur", "t"],
	"lightning": ["dur", "t", "rad", "col", "_segs", "_branches"],
	"rally": ["dur", "t", "rad", "col", "_motes"],
	"haste": ["dur", "t", "rad", "col"],
	"slash_arc": ["dur", "t", "rad", "col", "_a0"],
	"iron_staff_sweep": ["dur", "t", "rad", "col", "_a0"],
	"water_splash": ["dur", "t", "rad", "col", "_drops"],
	"poison_cloud": ["dur", "t", "rad", "col", "_blobs", "_bubbles"],
	"stone": ["dur", "t", "end_w", "col", "travel", "_E", "_ang"],
	"stomp": ["dur", "t", "rad", "col", "_cracks", "_debris"],
	"whirl": ["dur", "t", "rad", "col", "_spin"],
	"blood": ["dur", "t", "rad", "col", "_drops", "_a0"],
	"charge": ["dur", "t", "rad", "col", "dir"],
	"pin": ["dur", "t", "rad", "col", "_stakes"],
	"ability_beam": ["dur", "t", "start_w", "end_w", "col", "chain", "dash", "_S", "_E"],
	"ability_sweep": ["dur", "t", "end_w", "rad", "col", "_E", "_ang"],
	"spear_sweep": ["dur", "t", "rad", "col", "_a0", "_dir"],
	"thrust": ["dur", "t", "end_w", "col", "_E", "_ang"],
	"chrono": ["dur", "t", "rad", "col", "life", "lite", "_spin"],
	"ice_wall": ["dur", "t", "dir", "half_len", "col", "life", "_shards"],
	"earth_crack": ["dur", "t", "dir", "length", "col", "life", "_pts", "_rub"],
	"echo_slam": ["dur", "t", "rad", "col"],
	"split_mirror": ["dur", "t", "col", "from_w"],
	"fire_line": ["dur", "t", "dir", "length", "col"],
	"shadow_wave": ["dur", "t", "col", "heal"],
	"amp_cast": ["dur", "t", "rad", "col"],
	"silence": ["dur", "t", "rad", "col", "_talismans"],
	"armor_crack": ["dur", "t", "rad", "col", "_shards", "_cracks"],
	"death_remains": ["state"],
	"projectile": ["state"],
	"li_brawn_axes": ["state"],
	"blink_shot": ["dur", "t", "start_w", "end_w", "col", "_S", "_E"],
	"hit_spark": ["dur", "t", "heavy", "_seed"],
	"float_label": ["amount", "crit", "on_player", "t"],
	"bolt": ["col", "chain", "art", "_trail", "_t"],
	"trap_marker": ["key", "col", "rad", "armed", "_t"],
	"beast_stampede": ["dur", "t", "dir", "length", "travel_speed", "count", "_pack"],
	"meteor": ["dur", "t", "start_w", "end_w", "rad", "life", "col", "_roll", "_embers"],
	"ground_fire": ["dur", "t", "rad", "col", "life", "lite", "_flames", "_embers"],
	"ward": ["dur", "t", "rad", "col", "life", "style", "banner_kind", "lite", "_ph", "ward_visual"],
	"arrow_shot": ["dur", "t", "end_w", "col", "pin", "big", "travel", "_E", "_ang"],
	"arrow_rain": ["dur", "t", "rad", "col", "_arrows"],
	"flameburst": ["dur", "t", "rad", "col", "_flames", "_embers"],
	"ability": ["dur", "t", "rad", "col", "_seed"],
	"building_collapse": ["dur", "t", "tex", "s"]}
const TIMED_KINDS := ["blink_shot", "meteor", "ground_fire", "ward", "arrow_shot", "arrow_rain", "flameburst", "ability", "building_collapse"]
const TIMED_FLOATS := {"blink_shot": [], "meteor": ["rad", "life", "_roll"], "ground_fire": ["rad", "life"], "ward": ["rad", "life", "_ph"], "arrow_shot": ["travel", "_ang"], "arrow_rain": ["rad"], "flameburst": ["rad"], "ability": ["rad"], "building_collapse": ["s"]}
const NODE_FIELDS := ["name", "position", "modulate", "basis_x", "basis_y", "visible", "self_modulate", "z_index", "z_as_relative", "show_behind_parent", "top_level", "y_sort_enabled", "activation"]
const ACTIVATION_FIELDS := ["mode", "priority", "physics_priority", "process", "physics", "input", "shortcut", "unhandled_input", "unhandled_key", "signals_blocked"]
const AUTHORITY_KINDS := ["projectile", "li_brawn_axes"]
var _projectile_adapter: Variant
var _axes_adapter: Variant
var _unit_tombstone: Variant = null
var _reference_bindings: Dictionary = {}
var _codec: Variant
var _battle: Script
var _unit: Script
var _objects: Dictionary = {}
var _records: Dictionary = {}
var _nodes: Dictionary = {}
var _expired: Dictionary = {}
var _root: Node2D
var _activation: Dictionary = {}
var _committed := false
var _owner: Variant = null
var _textures: Dictionary = {}
var _ground_bound := false
var _linked: Variant
var _procedural: Variant
var _remains: Variant
var _remains_owner_record: Dictionary = {}
var _partition_error := ""
var _presentation_context: Dictionary = {}
var _presentation_record: Dictionary = {}
var _presentation_raw: Dictionary = {}
var _mission_raw: Dictionary = {}
var _marker_rows: Dictionary = {}
var _partition_known: Dictionary = {}
var _partition_units: Dictionary = {}
var _partition_next_id := 1
var _partition_stage_start: Variant = null
var _source_markers: Dictionary = {}
var _external_nodes: Dictionary = {}
var _presentation_adapter: Variant = null

func _init(codec: Script, battle: Script, unit: Script, owner: Variant = null, trusted_textures: Dictionary = {}, projectile_adapter: Variant = null, axes_adapter: Variant = null) -> void:
	_codec = codec.new()
	_procedural = Procedural.new(battle)
	_linked = Linked.new(battle)
	_remains = RemainsState.new(battle, _texture_signature)
	_battle = battle
	_unit = unit
	_owner = owner
	_textures = trusted_textures.duplicate()
	_projectile_adapter = projectile_adapter
	_axes_adapter = axes_adapter

func _failure(code: String, field: String = "") -> Dictionary:
	return {"ok": false, "code": code, "field": field}

func configure_presentation(presentation_record: Variant, mission_record: Variant,
		context: Dictionary, known: Dictionary, next_id: int) -> Dictionary:
	# Explicit opt-in, with fixed shipped validators. A caller never supplies a
	# skip list, script path, node-kind override or an asserted validation result.
	if not _presentation_context.is_empty() or not _records.is_empty() or not _nodes.is_empty() or is_instance_valid(_root): return _failure("PARTITION_CONFIGURATION_PHASE")
	_partition_error = "PARTITION_CONFIGURATION_REQUIRED"
	if _battle != preload("res://scripts/battle.gd") or _unit != preload("res://scripts/unit.gd") or _codec.get_script() != preload("res://scripts/run_state_value_codec.gd"): return _failure("PARTITION_INSTALLED_SCRIPTS")
	if not MissionState.new()._context(context): return _failure("PARTITION_CONTEXT")
	for key: String in ["level_id", "content_version", "mission_token", "presentation_token"]:
		if typeof(context[key]) != TYPE_STRING: return _failure("PARTITION_CONTEXT")
	if context.level_id != "level3": return _failure("PARTITION_OFFICIAL_LEVEL_REQUIRED")
	for record: Variant in [presentation_record, mission_record]:
		if typeof(record) != TYPE_DICTIONARY or not _fields(record, ["schema", "context", "payload"]) or typeof(record.schema) != TYPE_STRING or typeof(record.context) != TYPE_DICTIONARY: return _failure("PARTITION_COMPONENT_ENVELOPE")
	var checked: Dictionary = Presentation.new().validate(presentation_record, context)
	if not checked.ok: return checked
	var mission: Dictionary = MissionState.new().validate(mission_record, context, known, next_id, checked.tokens)
	if not mission.ok: return mission
	if checked.value.scroll != mission.value.scroll: return _failure("PARTITION_SCROLL_PAIR")
	var pending: Dictionary = {}
	if checked.value.markers.size() != mission.value.marker_order.size(): return _failure("PARTITION_MARKER_COUNT")
	for index: int in checked.value.markers.size():
		var row: Dictionary = checked.value.markers[index]
		var token := "marker:" + str(index)
		if row.token != token or mission.value.marker_order[index] != token or not mission.actions.has(row.descriptor.action_id) or mission.actions[row.descriptor.action_id].marker != token: return _failure("PARTITION_MARKER_ACTION", token)
		pending[token] = row.duplicate(true)
	_presentation_context = context.duplicate(true)
	_presentation_record = presentation_record.duplicate(true)
	_presentation_raw = checked.value.duplicate(true)
	_mission_raw = mission.value.duplicate(true)
	_marker_rows = pending
	_partition_next_id = next_id
	for id: Variant in known: _partition_known[id] = true
	_partition_error = ""
	return {"ok": true, "marker_count": _marker_rows.size(), "complete_world": false}

func _partition_registry_matches(version: String, known: Dictionary) -> bool:
	if _presentation_context.is_empty(): return true
	if version != _presentation_context.content_version or known.size() != _partition_known.size(): return false
	for id: Variant in known:
		if not _partition_known.has(id): return false
	return true

func _marker_objects(mission: Variant, root: Node2D) -> Dictionary:
	if not is_instance_valid(_owner) or _owner.get_script() != _battle or _owner.fx_root != root or not is_instance_valid(mission) or mission.get_script() != Mission or mission.battle != _owner or _owner.mission != mission: return _failure("PARTITION_MISSION_OWNER")
	if not is_instance_valid(_owner.level) or _owner.level.get_script() != preload("res://scripts/levels/level3_zhujiazhuang_rts.gd"): return _failure("PARTITION_INSTALLED_LEVEL")
	if mission._markers.size() != _marker_rows.size(): return _failure("PARTITION_MARKER_COUNT")
	var objects: Dictionary = {}
	for index: int in mission._markers.size():
		var node: Variant = mission._markers[index]
		var token := "marker:" + str(index)
		if not is_instance_valid(node) or node.get_script() != Mission.MissionMarker or node.is_queued_for_deletion() or node.get_parent() != root or not root.get_children().has(node) or node.get_child_count(true) != 0 or objects.has(node): return _failure("PARTITION_MARKER_OWNER", token)
		var descriptor: Dictionary = _marker_rows[token].descriptor
		var live_descriptor: Variant = node.get_meta(Mission.PRESENTATION_META, null)
		if typeof(live_descriptor) != TYPE_DICTIONARY or live_descriptor != descriptor or not mission.actions.has(descriptor.action_id) or mission.actions[descriptor.action_id].marker != node: return _failure("PARTITION_MARKER_BINDING", token)
		objects[node] = token
	return {"ok": true, "objects": objects}

func _capture_partition(root: Node2D) -> Dictionary:
	var objects: Dictionary = _marker_objects(_owner.mission if is_instance_valid(_owner) else null, root)
	if not objects.ok: return objects
	var held: Array = []
	var barrier: Variant = _owner._save_barrier
	if is_instance_valid(barrier):
		if barrier.get_script() != preload("res://scripts/run_battle_barrier.gd") or barrier.world != _owner or barrier.state != barrier.State.HELD: return _failure("PARTITION_CAPTURE_BARRIER")
		held = barrier._saved_ui
	# Recheck actual presentation behavior; valid scalar records alone cannot
	# authorize hiding an arbitrary live node from the Visual traversal.
	var captured: Dictionary = Presentation.new().capture(_owner.mission, _presentation_context, held)
	if not captured.ok: return captured
	if captured.record != _presentation_record: return _failure("PARTITION_SOURCE_PRESENTATION_CHANGED")
	var mission_check: Dictionary = _audit_mission(_owner.mission, captured.external_to_token, true)
	if not mission_check.ok: return mission_check
	_source_markers = objects.objects
	return {"ok": true}

func _audit_mission(mission: Variant, external_to_token: Dictionary, layout_done: bool) -> Dictionary:
	if typeof(mission._stage_started_ms) != TYPE_INT: return _failure("PARTITION_MISSION_CLOCK")
	if _partition_stage_start != null and mission._stage_started_ms != _partition_stage_start: return _failure("PARTITION_MISSION_CLOCK_CHANGED")
	# Stage age is clock-relative and belongs to the outer transaction. This
	# component verifies every stable field and freezes the mounted start anchor;
	# it never infers a restore clock or certifies the caller's age rebasing.
	var now: int = maxi(0, mission._stage_started_ms)
	var captured: Dictionary = MissionState.new().capture(mission, _presentation_context, _partition_units,
		_partition_next_id, external_to_token, now, {"deferred_drained": true, "presentation_captured": true})
	if not captured.ok: return captured
	var raw: Dictionary = _codec.decode(captured.record.payload).value
	raw.values.stage_age_ms = _mission_raw.values.stage_age_ms
	# PP applies the paired scroll only after its native containers have laid out.
	if not layout_done: raw.scroll = _mission_raw.scroll.duplicate(true)
	if raw != _mission_raw: return _failure("PARTITION_MISSION_CHANGED")
	return {"ok": true, "stage_age_requires_outer_clock": true}

func _external_state(node: Node, token: String) -> Dictionary:
	if not is_instance_valid(node) or node.is_queued_for_deletion() or node.get_script() != Mission.MissionMarker or node.get_parent() != _root or node.get_child_count(true) != 0 or node.process_mode != Node.PROCESS_MODE_DISABLED or not node.is_blocking_signals(): return _failure("PARTITION_EXTERNAL_STATE", token)
	var row: Dictionary = _marker_rows[token]
	for field: String in row.values:
		var value: Variant = node.transform.x if field == "x" else node.transform.y if field == "y" else node.transform.origin if field == "origin" else node.get(field)
		if typeof(value) != typeof(row.values[field]) or value != row.values[field]: return _failure("PARTITION_EXTERNAL_CHANGED", token + ":" + field)
	var height: Variant = node.get_meta("render_height", null)
	if typeof(height) != typeof(row.render_height) or height != row.render_height: return _failure("PARTITION_EXTERNAL_HEIGHT", token)
	return {"ok": true}

func _check_presentation_adapter(adapter: Variant, require_layout: bool) -> Dictionary:
	if not is_instance_valid(adapter) or adapter.get_script() != Presentation or adapter._owner != _owner or not adapter._used or adapter._active or adapter._raw != _presentation_raw or (require_layout and not adapter._layout_done): return _failure("PARTITION_PRESENTATION_ADAPTER")
	var objects: Dictionary = _marker_objects(adapter.mission, _root)
	if not objects.ok: return objects
	var held: Array = []
	for node: Node in adapter.activation_plan:
		var flags: Dictionary = adapter.activation_plan[node]
		if not adapter._flags_valid(flags): return _failure("PARTITION_PRESENTATION_FLAGS")
		held.append({"node": node, "mode": flags.mode, "blocked": flags.blocked})
	var audited: Dictionary = Presentation.new().capture(adapter.mission, _presentation_context, held)
	if not audited.ok: return audited
	# UI layout/localization may legitimately differ after mounting. Marker data
	# and its captured flags still belong to the exact validated presentation.
	var raw: Dictionary = _codec.decode(audited.record.payload).value
	for row: Dictionary in raw.markers:
		var node: Node = adapter.token_to_external[row.token]
		if not adapter.activation_plan.has(node) or adapter.activation_plan[node] != _marker_rows[row.token].flags: return _failure("PARTITION_MARKER_ACTIVATION_PLAN", row.token)
		# Priority/processing flags are installed only by PP.activate. The current
		# live node must stay gated; the exact validated plan owns its later flags.
		row.flags = adapter.activation_plan[node].duplicate()
	if raw.markers != _presentation_raw.markers: return _failure("PARTITION_EXTERNAL_PRESENTATION_CHANGED")
	for node: Node in objects.objects:
		var token: String = objects.objects[node]
		if not adapter.token_to_external.has(token) or adapter.token_to_external[token] != node: return _failure("PARTITION_EXTERNAL_TOKEN_OBJECT", token)
		var checked: Dictionary = _external_state(node, token)
		if not checked.ok: return checked
	var mission_check: Dictionary = _audit_mission(adapter.mission, audited.external_to_token, require_layout)
	if not mission_check.ok: return mission_check
	return objects

func bind_presentation(adapter: Variant) -> Dictionary:
	if _presentation_context.is_empty() or not _partition_error.is_empty() or _committed or _presentation_adapter != null or not is_instance_valid(_root) or _root.is_inside_tree(): return _failure("PARTITION_BIND_PHASE")
	var checked: Dictionary = _check_presentation_adapter(adapter, false)
	if not checked.ok: return checked
	var by_token: Dictionary = {}
	for node: Node in checked.objects: by_token[checked.objects[node]] = node
	var children: Dictionary = {}
	for row: Dictionary in _records.values():
		if row.parent != "1": continue
		var node: Node = by_token[row.token] if row.kind == EXTERNAL_MARKER else _nodes[row.id]
		if not is_instance_valid(node) or node.get_parent() != _root or children.has(node): return _failure("PARTITION_BIND_TOPOLOGY")
		children[node] = true
	if _root.get_child_count(true) != children.size(): return _failure("PARTITION_BIND_CHILD_SET")
	for child: Node in _root.get_children(true):
		if not children.has(child): return _failure("PARTITION_BIND_CHILD_SET")
	for row: Dictionary in _records.values():
		if row.kind == EXTERNAL_MARKER: _external_nodes[row.id] = by_token[row.token]
		if row.parent == "1": _root.move_child(_external_nodes[row.id] if row.kind == EXTERNAL_MARKER else _nodes[row.id], row.index)
	_presentation_adapter = adapter
	_partition_stage_start = adapter.mission._stage_started_ms
	return {"ok": true, "external_count": _external_nodes.size(), "markers_activated": false, "stage_age_requires_outer_clock": true}

func _external_activation_check() -> Dictionary:
	if _presentation_context.is_empty(): return {"ok": true}
	var checked: Dictionary = _check_presentation_adapter(_presentation_adapter, true)
	if not checked.ok: return checked
	if checked.objects.size() != _external_nodes.size(): return _failure("PARTITION_EXTERNAL_COUNT")
	for row: Dictionary in _records.values():
		if row.kind != EXTERNAL_MARKER: continue
		var node: Variant = _external_nodes.get(row.id)
		if not is_instance_valid(node) or not checked.objects.has(node) or checked.objects[node] != row.token or node.get_parent() != _root or node.get_index(true) != row.index: return _failure("PARTITION_EXTERNAL_TOPOLOGY", row.id)
	return {"ok": true}

func _fields(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size(): return false
	for key in value:
		if typeof(key) != TYPE_STRING or key not in expected: return false
	return true

func _id(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.is_empty() or value.length() > 19: return false
	if value[0] == "0": return false
	for ch: String in value:
		if ch < "0" or ch > "9": return false
	return value.length() < 19 or value <= "9223372036854775806"

func _kind(node: Node2D) -> String:
	if node.get_script() == null and node.get_class() == "Node2D": return "container"
	if _projectile_adapter != null and _projectile_adapter._projectile(node): return "projectile"
	if _axes_adapter != null and _axes_adapter._axes(node): return "li_brawn_axes"
	var linked_kind: String = _linked.kind(node)
	if not linked_kind.is_empty(): return linked_kind
	var procedural_kind: String = _procedural.kind(node)
	if not procedural_kind.is_empty(): return procedural_kind
	if node.get_script() == _battle.DeathRemains: return "death_remains"
	if node.get_script() == _battle.BlinkShotFx: return "blink_shot"
	if node.get_script() == _battle.BoltFx: return "bolt"
	if node.get_script() == _battle.TrapMarkerFx: return "trap_marker"
	if node.get_script() == _battle.BeastStampedeFx: return "beast_stampede"
	if node.get_script() == _battle.HitSpark: return "hit_spark"
	if node.get_script() == _battle.FloatLabel: return "float_label"
	if node.get_script() == _battle.MeteorFx: return "meteor"
	if node.get_script() == _battle.GroundFireFx: return "ground_fire"
	if node.get_script() == _battle.WardFx: return "ward"
	if node.get_script() == _battle.ArrowShotFx: return "arrow_shot"
	if node.get_script() == _battle.ArrowRainFx: return "arrow_rain"
	if node.get_script() == _battle.FlameburstFx: return "flameburst"
	if node.get_script() == _battle.AbilityFx: return "ability"
	if node.get_script() == _battle.BuildingCollapseFx: return "building_collapse"
	return ""

func _new(kind: String) -> Node2D:
	if _linked.TYPES.has(kind): return _linked.scripts[kind].new()
	if _procedural.TYPES.has(kind): return _procedural.scripts[kind].new()
	match kind:
		"container": return Node2D.new()
		"death_remains": return _battle.DeathRemains.new()
		"blink_shot": return _battle.BlinkShotFx.new()
		"bolt": return _battle.BoltFx.new()
		"trap_marker": return _battle.TrapMarkerFx.new()
		"beast_stampede": return _battle.BeastStampedeFx.new()
		"hit_spark": return _battle.HitSpark.new()
		"float_label": return _battle.FloatLabel.new()
		"meteor": return _battle.MeteorFx.new()
		"ground_fire": return _battle.GroundFireFx.new()
		"ward": return _battle.WardFx.new()
		"arrow_shot": return _battle.ArrowShotFx.new()
		"arrow_rain": return _battle.ArrowRainFx.new()
		"flameburst": return _battle.FlameburstFx.new()
		"ability": return _battle.AbilityFx.new()
		"building_collapse": return _battle.BuildingCollapseFx.new()
	return null

func _tag(value: Variant, units: Dictionary) -> Dictionary:
	if typeof(value) == TYPE_NIL: return {"ok": true, "value": {"state": "none"}}
	if typeof(value) != TYPE_OBJECT: return _failure("UNIT_REFERENCE_TYPE")
	if not is_instance_valid(value): return {"ok": true, "value": {"state": "expired"}}
	if value.get_script() != _unit or value.is_queued_for_deletion() or not units.has(value): return _failure("UNIT_REFERENCE_UNREGISTERED")
	return {"ok": true, "value": {"state": "entity", "id": units[value]}}

func _tag_check(value: Variant, known: Dictionary) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or typeof(value.get("state")) != TYPE_STRING: return _failure("UNIT_REFERENCE_TAG")
	if value.state in ["none", "expired"]:
		if not _fields(value, ["state"]): return _failure("UNIT_REFERENCE_TAG")
	elif value.state == "entity":
		if not _fields(value, ["state", "id"]) or not _id(value.id) or not known.has(value.id): return _failure("UNIT_REFERENCE_ID")
	else: return _failure("UNIT_REFERENCE_TAG")
	return {"ok": true}

func _values(node: Node2D, kind: String) -> Dictionary:
	if kind == "death_remains": return {"state": _remains.capture_node(node).value}
	var values: Dictionary = {}
	for field: String in FIELDS[kind]:
		if field != "ward_visual": values[field] = node.get(field)
	if _procedural.TYPES.has(kind):
		for field: String in FIELDS[kind]:
			if _procedural.TYPES[kind][field] == TYPE_PACKED_VECTOR2_ARRAY: values[field] = Array(node.get(field))
	for field: String in _linked.TEXTURES.get(kind, []): values[field] = _texture_token(node.get(field)).value
	if kind == "building_collapse": values["tex"] = _texture_token(node.tex).value
	if kind == "ward": values["ward_visual"] = _ward_signature(node.style).value
	return values

func _values_check(values: Variant, kind: String) -> Dictionary:
	if typeof(values) != TYPE_DICTIONARY or not _fields(values, FIELDS[kind]): return _failure("VALUE_FIELDS", kind)
	if _linked.TYPES.has(kind):
		var checked: Dictionary = _linked.validate(values, kind)
		if not checked.ok: return checked
		for field: String in _linked.TEXTURES[kind]:
			checked = _texture_check(values[field])
			if not checked.ok: return checked
		return {"ok": true}
	if _procedural.TYPES.has(kind): return _procedural.validate(values, kind)
	if kind == "death_remains": return _remains.validate_node(values.state)
	if kind in TIMED_KINDS: return _timed_check(values, kind)
	var floats: Array = ["_t"] if kind in ["bolt", "trap_marker"] else []
	if kind == "trap_marker": floats.append("rad")
	if kind == "beast_stampede": floats = ["dur", "t", "length", "travel_speed"]
	if kind == "hit_spark": floats = ["dur", "t"]
	if kind == "float_label": floats = ["t"]
	for key: String in floats:
		if typeof(values[key]) != TYPE_FLOAT or not is_finite(values[key]): return _failure("VALUE_FLOAT", key)
	if kind in ["bolt", "trap_marker"]:
		if typeof(values.col) != TYPE_COLOR: return _failure("VALUE_COLOR")
		if values._t < 0.0: return _failure("VALUE_ELAPSED")
		var key: String = "art" if kind == "bolt" else "key"
		if typeof(values[key]) != TYPE_STRING or values[key].length() > 128: return _failure("VALUE_STRING")
		key = "chain" if kind == "bolt" else "armed"
		if typeof(values[key]) != TYPE_BOOL: return _failure("VALUE_BOOL")
	if kind == "bolt":
		if typeof(values._trail) != TYPE_ARRAY or values._trail.size() > 10: return _failure("TRAIL_SIZE")
		for point: Variant in values._trail:
			if typeof(point) != TYPE_VECTOR2 or not point.is_finite(): return _failure("TRAIL_POINT")
	if kind == "trap_marker" and values.rad < 0.0: return _failure("TRAP_RADIUS")
	if kind == "hit_spark":
		if typeof(values.heavy) != TYPE_BOOL or typeof(values._seed) != TYPE_INT or values.dur <= 0.0 or values.t <= 0.0 or values.t > values.dur: return _failure("HIT_SPARK_VALUES")
	if kind == "float_label":
		if typeof(values.amount) != TYPE_INT or typeof(values.crit) != TYPE_BOOL or typeof(values.on_player) != TYPE_BOOL: return _failure("FLOAT_LABEL_VALUES")
		if values.t < 0.0 or values.t >= (0.95 if values.crit else 0.72): return _failure("FLOAT_LABEL_LIFETIME")
	if kind == "beast_stampede":
		if values.dur <= 0.0 or values.t <= 0.0 or values.t > values.dur or values.length <= 0.0 or values.travel_speed <= 0.0: return _failure("BEAST_LIFETIME")
		if typeof(values.dir) != TYPE_VECTOR2 or not values.dir.is_finite(): return _failure("BEAST_DIRECTION")
		if typeof(values.count) != TYPE_INT or values.count < 1 or values.count > LIMIT: return _failure("BEAST_COUNT")
		if typeof(values._pack) != TYPE_ARRAY or values._pack.size() != values.count: return _failure("BEAST_PACK_SIZE")
		for row: Variant in values._pack:
			if typeof(row) != TYPE_DICTIONARY or not _fields(row, ["side", "delay", "size"]): return _failure("BEAST_PACK_FIELDS")
			for field: String in row:
				if typeof(row[field]) != TYPE_FLOAT or not is_finite(row[field]): return _failure("BEAST_PACK_FLOAT")
	return {"ok": true}

func _read_node(projectile: Variant) -> Dictionary:
	# Generated @ names are rebuilt when attached in the saved effect order.
	var saved_name: String = "" if String(projectile.name).begins_with("@") else String(projectile.name)
	return {"name": saved_name, "position": projectile.position, "modulate": projectile.modulate, "basis_x": projectile.transform.x, "basis_y": projectile.transform.y,
		"visible": projectile.visible, "self_modulate": projectile.self_modulate, "z_index": projectile.z_index,
		"z_as_relative": projectile.z_as_relative, "show_behind_parent": projectile.show_behind_parent,
		"top_level": projectile.top_level, "y_sort_enabled": projectile.y_sort_enabled,
		"activation": {"mode": int(projectile.process_mode), "priority": projectile.process_priority,
			"physics_priority": projectile.process_physics_priority, "process": projectile.is_processing(),
			"physics": projectile.is_physics_processing(), "input": projectile.is_processing_input(),
			"shortcut": projectile.is_processing_shortcut_input(), "unhandled_input": projectile.is_processing_unhandled_input(),
			"unhandled_key": projectile.is_processing_unhandled_key_input(), "signals_blocked": projectile.is_blocking_signals()}}


func _check_activation(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _fields(value, ACTIVATION_FIELDS): return _failure("ACTIVATION_FIELDS")
	for key in ["mode", "priority", "physics_priority"]:
		if typeof(value[key]) != TYPE_INT: return _failure("ACTIVATION_INTEGER", key)
	if value.mode < 0 or value.mode > 4: return _failure("ACTIVATION_MODE")
	for key in ["priority", "physics_priority"]:
		if value[key] < -2147483648 or value[key] > 2147483647: return _failure("ACTIVATION_RANGE", key)
	for key in ["process", "physics", "input", "shortcut", "unhandled_input", "unhandled_key", "signals_blocked"]:
		if typeof(value[key]) != TYPE_BOOL: return _failure("ACTIVATION_BOOL", key)
	return {"ok": true}


func _check_node(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _fields(value, NODE_FIELDS): return _failure("NODE_FIELDS")
	if typeof(value.name) != TYPE_STRING or value.name.length() > 256: return _failure("NODE_NAME")
	for key in ["position", "basis_x", "basis_y"]:
		if typeof(value[key]) != TYPE_VECTOR2 or not value[key].is_finite(): return _failure("NODE_TRANSFORM", key)
	for key in ["visible", "z_as_relative", "show_behind_parent", "top_level", "y_sort_enabled"]:
		if typeof(value[key]) != TYPE_BOOL: return _failure("NODE_BOOL", key)
	if typeof(value.z_index) != TYPE_INT or value.z_index < -4096 or value.z_index > 4096: return _failure("NODE_Z")
	for key in ["modulate", "self_modulate"]:
		if typeof(value[key]) != TYPE_COLOR: return _failure("NODE_COLOR", key)
		var color: Color = value[key]
		for part in [color.r, color.g, color.b, color.a]:
			if not is_finite(part): return _failure("NODE_COLOR", key)
	return _check_activation(value.activation)


func _registry(registry: Dictionary, reversed: bool) -> Dictionary:
	if registry.size() > LIMIT: return _failure("REGISTRY_SIZE")
	var known: Dictionary = {}
	var seen: Dictionary = {}
	for key: Variant in registry:
		var id: Variant = key if reversed else registry[key]
		var node: Variant = registry[key] if reversed else key
		if not _id(id) or typeof(node) != TYPE_OBJECT or not is_instance_valid(node) or node.get_script() != _unit or node.is_queued_for_deletion(): return _failure("REGISTRY_ROW")
		if str(node.entity_id) != id or known.has(id) or seen.has(node): return _failure("REGISTRY_ID")
		known[id] = true
		seen[node] = true
	return {"ok": true, "known": known}

func capture(root: Node2D, version: String, units: Dictionary) -> Dictionary:
	_objects.clear()
	_records.clear()
	_source_markers.clear()
	if not _partition_error.is_empty(): return _failure(_partition_error)
	if version.is_empty() or version.length() > 256: return _failure("CONTENT_VERSION")
	var registry: Dictionary = _registry(units, false)
	if not registry.ok: return registry
	if not _partition_registry_matches(version, registry.known): return _failure("PARTITION_REGISTRY_CHANGED")
	if not _presentation_context.is_empty():
		_partition_units.clear()
		for unit: Node in units: _partition_units[units[unit]] = unit
	if root == null or not is_instance_valid(root) or _kind(root) != "container" or root.is_queued_for_deletion(): return _failure("VISUAL_ROOT")
	if not _presentation_context.is_empty():
		var partition: Dictionary = _capture_partition(root)
		if not partition.ok: return partition
	var rows: Array = []
	var stack: Array = [{"node": root, "parent": "", "index": 0}]
	while not stack.is_empty():
		if rows.size() >= LIMIT: return _failure("VISUAL_LIMIT")
		var entry: Dictionary = stack.pop_back()
		var node: Variant = entry.node
		if not is_instance_valid(node) or not node is Node2D or node.is_queued_for_deletion(): return _failure("VISUAL_NODE")
		if _source_markers.has(node):
			if entry.parent != "1": return _failure("PARTITION_MARKER_PARENT")
			var external_row: Dictionary = {"id": str(rows.size() + 1), "parent": entry.parent, "index": entry.index, "kind": EXTERNAL_MARKER, "token": _source_markers[node]}
			rows.append(external_row)
			_records[external_row.id] = external_row
			continue
		var kind: String = _kind(node)
		if kind.is_empty(): return _failure("UNSUPPORTED_VISUAL_SCRIPT", str(node.get_script()))
		# Current supported effects create no child nodes; containers express world/root order.
		if node.get_child_count(true) != node.get_child_count(): return _failure("UNSUPPORTED_INTERNAL_VISUAL")
		if kind != "container" and node.get_child_count(true) != 0: return _failure("UNSUPPORTED_VISUAL_CHILDREN", kind)
		if kind == "beast_stampede" and (not node.tex is Texture2D or node.tex.resource_path != TEX): return _failure("BEAST_TEXTURE")
		var supported: Dictionary = _timed_node_supported(node, kind)
		if not supported.ok: return supported
		var id: String = str(rows.size() + 1)
		var refs: Dictionary = {}
		for field: String in _reference_fields(kind):
			var tag: Dictionary = _tag(node.get(field), units)
			if not tag.ok: return tag
			refs[field] = tag.value
		var values: Dictionary
		if kind in AUTHORITY_KINDS:
			if kind == "li_brawn_axes" and (not is_instance_valid(_owner) or not is_same(node.game, _owner)): return _failure("AXES_GRAPH_OWNER")
			for signal_info: Dictionary in node.get_signal_list():
				if not node.get_signal_connection_list(signal_info.name).is_empty(): return _failure("AUTHORITY_SIGNAL_CONNECTION", kind)
			var captured: Dictionary = _adapter(kind).capture(node, version, units)
			if not captured.ok: return captured
			values = {"state": captured.record}
		else: values = _values(node, kind)
		var row: Dictionary = {"id": id, "parent": entry.parent, "index": entry.index,
			"kind": kind, "node": _read_node(node), "values": values, "references": refs}
		rows.append(row)
		_objects[node] = id
		_records[id] = row
		for index: int in range(node.get_child_count(true) - 1, -1, -1):
			stack.append({"node": node.get_child(index, true), "parent": id, "index": index})
	var has_remains := false
	for row: Dictionary in rows: has_remains = has_remains or row.kind == "death_remains"
	if has_remains:
		var remains_owner: Dictionary = _remains.capture_owner(_owner, _objects)
		if not remains_owner.ok: return remains_owner
	var owner_check: Dictionary = _capture_ground_owner(root, rows)
	if not owner_check.ok: return owner_check
	var encoded: Dictionary = _codec.encode(rows)
	if not encoded.ok: return encoded
	var wire: Dictionary = {"schema": SCHEMA if _presentation_context.is_empty() else CAMPAIGN_SCHEMA, "content_version": version, "records": encoded.value}
	var checked: Dictionary = validate(wire, version, registry.known)
	if not checked.ok: return checked
	return {"ok": true, "value": wire, "count": rows.size(), "complete_visual_graph": false}

func validate(record: Variant, version: String, known: Dictionary) -> Dictionary:
	if not _partition_error.is_empty(): return _failure(_partition_error)
	if not _partition_registry_matches(version, known): return _failure("PARTITION_REGISTRY_CHANGED")
	if typeof(record) != TYPE_DICTIONARY or not _fields(record, ["schema", "content_version", "records"]): return _failure("VISUAL_SCHEMA")
	if typeof(record.schema) != TYPE_STRING or typeof(record.content_version) != TYPE_STRING: return _failure("VISUAL_VERSION")
	if record.schema != (SCHEMA if _presentation_context.is_empty() else CAMPAIGN_SCHEMA) or record.content_version != version or version.is_empty() or version.length() > 256: return _failure("VISUAL_VERSION")
	for id: Variant in known:
		if not _id(id): return _failure("REGISTRY_ID")
	var decoded: Dictionary = _codec.decode(record.records)
	if not decoded.ok: return decoded
	if typeof(decoded.value) != TYPE_ARRAY or decoded.value.is_empty() or decoded.value.size() > LIMIT: return _failure("VISUAL_RECORDS")
	var indexed: Dictionary = {}
	var counts: Dictionary = {}
	var ancestry: Array = []
	var external_tokens: Dictionary = {}
	for row: Variant in decoded.value:
		if typeof(row) != TYPE_DICTIONARY or typeof(row.get("kind")) != TYPE_STRING: return _failure("VISUAL_RECORD_FIELDS")
		var external: bool = row.kind == EXTERNAL_MARKER
		if not _fields(row, ["id", "parent", "index", "kind", "token"] if external else ["id", "parent", "index", "kind", "node", "values", "references"]): return _failure("VISUAL_RECORD_FIELDS")
		if typeof(row.id) != TYPE_STRING or row.id != str(indexed.size() + 1): return _failure("VISUAL_ID_ORDER")
		if not FIELDS.has(row.kind) and not (external and not _presentation_context.is_empty()): return _failure("VISUAL_KIND")
		if typeof(row.parent) != TYPE_STRING or typeof(row.index) != TYPE_INT: return _failure("VISUAL_PARENT")
		if indexed.is_empty():
			if row.kind != "container" or row.parent != "" or row.index != 0: return _failure("VISUAL_ROOT_RECORD")
		else:
			if not indexed.has(row.parent) or indexed[row.parent].kind != "container": return _failure("VISUAL_PARENT_KIND")
			while not ancestry.is_empty() and ancestry.back() != row.parent: ancestry.pop_back()
			if ancestry.is_empty(): return _failure("VISUAL_PREORDER")
			if row.index != int(counts.get(row.parent, 0)): return _failure("VISUAL_SIBLING_ORDER")
			counts[row.parent] = row.index + 1
		if external:
			if row.parent != "1" or typeof(row.token) != TYPE_STRING or not _marker_rows.has(row.token) or external_tokens.has(row.token): return _failure("PARTITION_EXTERNAL_ROW")
			external_tokens[row.token] = true
			indexed[row.id] = row
			ancestry.append(row.id)
			continue
		var nc: Dictionary = _check_node(row.node)
		if not nc.ok: return nc
		var vc: Dictionary
		if row.kind in AUTHORITY_KINDS:
			if _adapter(row.kind) == null: return _failure("AUTHORITY_ADAPTER_REQUIRED", row.kind)
			if typeof(row.values) != TYPE_DICTIONARY or not _fields(row.values, ["state"]): return _failure("AUTHORITY_VALUES")
			vc = _adapter(row.kind).validate(row.values.state, version, known)
			if vc.ok and vc.node != row.node: return _failure("AUTHORITY_NODE_MISMATCH", row.id)
		else: vc = _values_check(row.values, row.kind)
		if not vc.ok: return vc
		if typeof(row.references) != TYPE_DICTIONARY or not _fields(row.references, _reference_fields(row.kind)): return _failure("VISUAL_REFERENCES")
		for field: String in row.references:
			var tc: Dictionary = _tag_check(row.references[field], known)
			if not tc.ok: return tc
		indexed[row.id] = row
		ancestry.append(row.id)
	if external_tokens.size() != _marker_rows.size(): return _failure("PARTITION_EXTERNAL_COVERAGE")
	_records = indexed
	return {"ok": true, "rows": decoded.value}

func _assign_node(node: Node2D, state: Dictionary) -> void:
	if not state.name.is_empty(): node.name = state.name
	node.transform = Transform2D(state.basis_x, state.basis_y, state.position)
	for field: String in ["modulate", "visible", "self_modulate", "z_index", "z_as_relative", "show_behind_parent", "top_level", "y_sort_enabled"]:
		node.set(field, state[field])

func prepare(record: Variant, version: String, units: Dictionary, expired_unit: Variant = null) -> Dictionary:
	if is_instance_valid(_root) or not _nodes.is_empty(): return _failure("VISUAL_ALREADY_PREPARED")
	var registry: Dictionary = _registry(units, true)
	if not registry.ok: return registry
	var checked: Dictionary = validate(record, version, registry.known)
	if not checked.ok: return checked
	if not _presentation_context.is_empty(): _partition_units = units.duplicate()
	for row: Dictionary in checked.rows:
		if row.kind == EXTERNAL_MARKER: continue
		if row.references.values().any(func(tag: Dictionary) -> bool: return tag.state == "expired"):
			if typeof(expired_unit) != TYPE_OBJECT or not is_instance_valid(expired_unit) or expired_unit.get_script() != _unit or expired_unit.get_parent() != null or expired_unit.is_inside_tree() or units.values().has(expired_unit): return _failure("LIVE_UNIT_TOMBSTONE_REQUIRED")
	for row: Dictionary in checked.rows:
		if row.kind not in AUTHORITY_KINDS: continue
		if row.kind == "li_brawn_axes":
			if not is_instance_valid(_owner) or _owner.get_script() != _battle or _owner.is_inside_tree() or _owner.is_queued_for_deletion(): return _failure("AXES_PRIVATE_OWNER_REQUIRED")
		var state: Dictionary = _adapter(row.kind).validate(row.values.state, version, registry.known)
		var tags: Array = state.references.values() if row.kind == "projectile" else [state.caster]
		if row.kind == "li_brawn_axes":
			for hit: Dictionary in state.hits: tags.append(hit.target)
		for tag: Dictionary in tags:
			if tag.state == "expired" and (typeof(expired_unit) != TYPE_OBJECT or not is_instance_valid(expired_unit) or expired_unit.get_script() != _unit or expired_unit.is_queued_for_deletion() or expired_unit.get_parent() != null or expired_unit.is_inside_tree() or units.values().has(expired_unit)): return _failure("LIVE_UNIT_TOMBSTONE_REQUIRED")
	# Validate the entire mixed graph and all references before allocation.
	for row: Dictionary in checked.rows:
		if row.kind == EXTERNAL_MARKER: continue
		var node: Node2D
		if row.kind in AUTHORITY_KINDS:
			var made: Dictionary = _adapter(row.kind).instantiate(row.values.state, version, registry.known)
			if not made.ok:
				dispose()
				return made
			node = made.projectile if row.kind == "projectile" else made.fx
			var bound: Dictionary
			if row.kind == "projectile": bound = _projectile_adapter.bind(node, row.values.state, version, units, expired_unit)
			else: bound = _axes_adapter.bind(node, row.values.state, version, units, _owner, expired_unit)
			if not bound.ok:
				node.free()
				dispose()
				return bound
			if bound.expired_bindings > 0: _unit_tombstone = expired_unit
		else:
			node = _new(row.kind)
			node.set_block_signals(true)
			node.process_mode = Node.PROCESS_MODE_DISABLED
			if row.kind in ["beast_stampede", "hit_spark"] + TIMED_KINDS or _procedural.TYPES.has(row.kind) or _linked.TYPES.has(row.kind): node.set_meta("_run_restore_prepared", true)
			_assign_node(node, row.node)
			for field: String in FIELDS[row.kind]:
				if row.kind == "death_remains":
					_remains.restore_node(node, row.values.state); continue
				if field == "ward_visual": continue
				if field in _linked.TEXTURES.get(row.kind, []) or (row.kind == "building_collapse" and field == "tex"):
					node.set(field, null if row.values[field].state == "none" else _textures[row.values[field].key])
				elif _procedural.TYPES.has(row.kind) and _procedural.TYPES[row.kind][field] == TYPE_PACKED_VECTOR2_ARRAY: node.set(field, PackedVector2Array(row.values[field]))
				else: node.set(field, row.values[field])
			_reference_bindings[row.id] = {}
			for field: String in row.references:
				var tag: Dictionary = row.references[field]
				node.set(field, units[tag.id] if tag.state == "entity" else (expired_unit if tag.state == "expired" else null))
				_reference_bindings[row.id][field] = node.get(field)
				if tag.state == "expired": _unit_tombstone = expired_unit
		_nodes[row.id] = node
		_activation[row.id] = row.node.activation
		if row.parent == "": _root = node
		else: _nodes[row.parent].add_child(node)
	return {"ok": true, "root": _root, "nodes": _nodes.duplicate(), "created_count": _nodes.size(), "external_count": _marker_rows.size(), "presentation_binding_required": not _presentation_context.is_empty(), "complete_visual_graph": false}

func encode_token(value: Variant, expected: String) -> Dictionary:
	if expected not in ["bolt", "trap_marker"]: return _failure("FX_EXPECTED_KIND")
	if typeof(value) == TYPE_NIL: return {"ok": true, "value": {"state": "none"}}
	if typeof(value) != TYPE_OBJECT: return _failure("FX_OBJECT")
	if not is_instance_valid(value): return {"ok": true, "value": {"state": "expired"}}
	if not value is Node2D or _kind(value) != expected or not _objects.has(value): return _failure("FX_UNREGISTERED")
	return {"ok": true, "value": {"state": "node", "id": _objects[value]}}

func validate_token(value: Variant, expected: String) -> Dictionary:
	if expected not in ["bolt", "trap_marker"]: return _failure("FX_EXPECTED_KIND")
	if typeof(value) != TYPE_DICTIONARY or typeof(value.get("state")) != TYPE_STRING: return _failure("FX_TAG")
	if value.state in ["none", "expired"]:
		if not _fields(value, ["state"]): return _failure("FX_TAG")
	elif value.state == "node":
		if not _fields(value, ["state", "id"]) or not _id(value.id) or not _records.has(value.id) or _records[value.id].kind != expected: return _failure("FX_NODE_KIND")
	else: return _failure("FX_TAG")
	return {"ok": true}

func decode_token(value: Variant, expected: String) -> Dictionary:
	var checked: Dictionary = validate_token(value, expected)
	if not checked.ok: return checked
	if value.state == "none": return {"ok": true, "value": null}
	if value.state == "node":
		if not _nodes.has(value.id): return _failure("FX_NOT_PREPARED")
		return {"ok": true, "value": _nodes[value.id]}
	if not _expired.has(expected):
		var node: Node2D = _new(expected)
		node.set_block_signals(true)
		node.process_mode = Node.PROCESS_MODE_DISABLED
		_expired[expected] = node
	return {"ok": true, "value": _expired[expected]}

func release_expired_fx() -> void:
	# Root calls only after every effect array has captured its typed references.
	for node: Node2D in _expired.values():
		if is_instance_valid(node): node.free()
	_expired.clear()

func activate() -> Dictionary:
	if not is_instance_valid(_root) or not _root.is_inside_tree() or not _root.get_tree().paused: return _failure("ACTIVATION_REQUIRES_PAUSED_TREE")
	if not _expired.is_empty(): return _failure("FX_TOMBSTONES_NOT_RELEASED")
	if _committed: return _failure("VISUAL_ALREADY_ACTIVATED")
	if is_instance_valid(_unit_tombstone): return _failure("UNIT_TOMBSTONE_NOT_RELEASED")
	var external_check: Dictionary = _external_activation_check()
	if not external_check.ok: return external_check
	for row: Dictionary in _records.values():
		if row.kind == "death_remains" and _remains_owner_record.is_empty(): return _failure("REMAINS_OWNER_NOT_BOUND")
	if not _remains_owner_record.is_empty():
		var objects: Dictionary = {}
		for id: String in _nodes: objects[_nodes[id]] = id
		var check: Dictionary = _remains.capture_owner(_owner, objects)
		if not check.ok or check.value != _remains_owner_record: return _failure("REMAINS_OWNER_CHANGED")
	if _ground_count(_records.values()) > 0:
		if not _ground_bound: return _failure("GROUND_FIRE_OWNER_NOT_BOUND")
		var owner_check: Dictionary = _capture_ground_owner(_root, _records.values(), true)
		if not owner_check.ok: return owner_check
	var child_counts: Dictionary = {}
	for row: Dictionary in _records.values():
		if row.parent != "": child_counts[row.parent] = int(child_counts.get(row.parent, 0)) + 1
	for id: String in _nodes:
		var node: Node2D = _nodes[id]
		if not is_instance_valid(node) or not node.is_node_ready() or not node.is_blocking_signals() or node.process_mode != Node.PROCESS_MODE_DISABLED: return _failure("VISUAL_ACTIVATION_STATE")
		var row: Dictionary = _records[id]
		if node.is_queued_for_deletion() or _kind(node) != row.kind or node.get_child_count(true) != int(child_counts.get(id, 0)): return _failure("VISUAL_ACTIVATION_TOPOLOGY")
		if row.parent != "" and (node.get_parent() != _nodes[row.parent] or node.get_index(true) != row.index): return _failure("VISUAL_ACTIVATION_TOPOLOGY")
		for field: String in _reference_bindings.get(id, {}):
			if not is_same(node.get(field), _reference_bindings[id][field]): return _failure("VISUAL_REFERENCE_CHANGED", row.kind + "." + field)
			var tag: Dictionary = row.references[field]
			var target: Variant = node.get(field)
			if tag.state == "entity" and (not is_instance_valid(target) or target.is_queued_for_deletion() or target.get_script() != _unit or str(target.entity_id) != tag.id): return _failure("VISUAL_BOUND_UNIT_CHANGED", row.kind + "." + field)
		if _linked.TYPES.has(row.kind):
			var prepared_check: Dictionary = _linked_prepared_check(node, row)
			if not prepared_check.ok: return prepared_check
			for field: String in _linked.TEXTURES[row.kind]:
				if not _texture_token(node.get(field)).ok: return _failure("LINKED_TEXTURE_CHANGED", field)
			if _values(node, row.kind) != row.values: return _failure("LINKED_PREPARATION_CHANGED", row.kind)
		if _procedural.TYPES.has(row.kind) and _values(node, row.kind) != row.values: return _failure("PROCEDURAL_PREPARATION_CHANGED", row.kind)
		if row.kind == "li_brawn_axes" and (not is_instance_valid(_owner) or _owner.fx_root != _root or not is_same(node.game, _owner)): return _failure("AXES_GRAPH_OWNER")
	for id: String in _nodes:
		var node: Node2D = _nodes[id]
		var state: Dictionary = _activation[id]
		if _kind(node) == "death_remains": _remains.restore_render_transform(node)
		node.process_priority = state.priority
		node.process_physics_priority = state.physics_priority
		node.set_process(state.process)
		node.set_physics_process(state.physics)
		node.set_process_input(state.input)
		node.set_process_shortcut_input(state.shortcut)
		node.set_process_unhandled_input(state.unhandled_input)
		node.set_process_unhandled_key_input(state.unhandled_key)
		node.set_block_signals(state.signals_blocked)
		node.process_mode = state.mode
		if node.has_meta("_run_restore_prepared"): node.remove_meta("_run_restore_prepared")
	_committed = true
	return {"ok": true}

func dispose() -> void:
	release_expired_fx()
	# The Presentation owns its markers and bindings even on a failed prepare.
	# Do not free them as an incidental descendant of a Visual-owned root.
	if not _committed and not _presentation_context.is_empty() and is_instance_valid(_owner) and _owner.get_script() == _battle:
		var mission: Variant = _owner.mission
		if is_instance_valid(mission) and mission.get_script() == Mission and mission.battle == _owner:
			for index: int in mission._markers.size():
				var node: Variant = mission._markers[index]
				var token := "marker:" + str(index)
				if not _marker_rows.has(token) or not is_instance_valid(node) or node.get_script() != Mission.MissionMarker or node.get_parent() == null: continue
				var descriptor: Variant = node.get_meta(Mission.PRESENTATION_META, null)
				if typeof(descriptor) != TYPE_DICTIONARY or descriptor != _marker_rows[token].descriptor: continue
				if not mission.actions.has(descriptor.action_id) or mission.actions[descriptor.action_id].marker != node: continue
				if is_instance_valid(_root) and _root.is_ancestor_of(node): node.get_parent().remove_child(node)
	if not _committed and is_instance_valid(_root): _root.free()
	_root = null
	_nodes.clear()
	_activation.clear()
	_unit_tombstone = null
	_reference_bindings.clear()
	_external_nodes.clear()
	_source_markers.clear()
	_presentation_adapter = null
	_partition_units.clear()

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
		"blink_shot":
			if v.dur != 0.42: return _failure("BLINK_SHOT_DURATION")
			for key: String in ["start_w", "end_w", "_S", "_E"]:
				if typeof(v[key]) != TYPE_VECTOR2 or not v[key].is_finite(): return _failure("BLINK_SHOT_POINT", key)
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
	if _procedural.TYPES.has(kind) or _linked.TYPES.has(kind):
		if not node.get_meta_list().is_empty(): return _failure("PROCEDURAL_METADATA", kind)
		for info: Dictionary in node.get_signal_list():
			if not node.get_signal_connection_list(info.name).is_empty(): return _failure("PROCEDURAL_CONNECTION", kind)
	for field: String in _linked.TEXTURES.get(kind, []):
		var texture: Dictionary = _texture_token(node.get(field))
		if not texture.ok: return texture
	if not _procedural.TYPES.has(kind) and not _linked.TYPES.has(kind) and kind not in TIMED_KINDS + AUTHORITY_KINDS + ["death_remains"]: return {"ok": true}
	if kind == "death_remains":
		var checked: Dictionary = _remains.capture_node(node)
		if not checked.ok: return checked
	# The supported timed and authority creators use these inherited defaults. Reject overrides.
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

func _capture_ground_owner(root: Node2D, rows: Array, prepared: bool = false) -> Dictionary:
	var count: int = _ground_count(rows)
	if count == 0 and _owner == null: return {"ok": true}
	if not is_instance_valid(_owner) or _owner.get_script() != _battle or _owner.fx_root != root or _owner._ground_fire_visuals != count: return _failure("GROUND_FIRE_OWNER_COUNT")
	var expected := Callable(_owner, "_on_ground_fire_visual_exited")
	var objects: Array = _nodes.values() if prepared else _objects.keys()
	for object: Node2D in objects:
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

func _adapter(kind: String) -> Variant:
	return _projectile_adapter if kind == "projectile" else _axes_adapter

func capture_remains_owner() -> Dictionary:
	var checked: Dictionary = _remains.capture_owner(_owner, _objects)
	if not checked.ok: return checked
	return _codec.encode(checked.value)

func bind_remains_owner(record: Variant) -> Dictionary:
	if _committed or not _remains_owner_record.is_empty() or not is_instance_valid(_root) or _root.is_inside_tree(): return _failure("REMAINS_BIND_PHASE")
	var checked: Dictionary = _codec.decode(record)
	if not checked.ok: return checked
	var bound: Dictionary = _remains.bind_owner(_owner, checked.value, _nodes)
	if not bound.ok: return bound
	_remains_owner_record = checked.value.duplicate(true)
	return {"ok": true}


func _reference_fields(kind: String) -> Array:
	return ["chain_from"] if kind == "bolt" else _linked.REFERENCES.get(kind, [])

func _linked_prepared_check(node: Node2D, row: Dictionary) -> Dictionary:
	if node.get_meta_list().size() != 1 or node.get_meta("_run_restore_prepared", false) != true: return _failure("LINKED_PREPARATION_MARKER", row.kind)
	for info: Dictionary in node.get_signal_list():
		if not node.get_signal_connection_list(info.name).is_empty(): return _failure("LINKED_PREPARATION_CONNECTION", row.kind)
	if node.material != null or node.use_parent_material or node.texture_filter != CanvasItem.TEXTURE_FILTER_PARENT_NODE or node.texture_repeat != CanvasItem.TEXTURE_REPEAT_PARENT_NODE or node.light_mask != 1 or node.visibility_layer != 1 or node.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED: return _failure("LINKED_PREPARATION_RENDER", row.kind)
	var state: Dictionary = _read_node(node); state.erase("activation")
	var expected: Dictionary = row.node.duplicate(); expected.erase("activation")
	if state != expected: return _failure("LINKED_PREPARATION_NODE", row.kind)
	return {"ok": true}
