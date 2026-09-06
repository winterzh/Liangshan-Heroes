extends RefCounted
## Trusted Script injection only. No script/resource path comes from a snapshot.
## Capture under the outer complete-step barrier; pending deletions must finish.
## units_root children (including dying Units) and Battle.units have separate order.
## Caller owns persistent IDs and the retained identity context across later saves.
## prepare() never installs Battle fields, connects signals, attaches or activates.
const SCHEMA := "defense_unit_graph_v1"
const MAX_UNITS := 4096
const MAX_ID := "9223372036854775807"
const GRAPH_FIELDS := ["schema", "content_version", "root_order", "active_order", "records"]
var _factory: Variant = null
var _identity_script: Script
var _unit_script: Script
var _battle_script: Script
var _map_script: Script

func _init(unit_state_script: Script, identity_script: Script, codec_script: Script,
		unit_script: Script, inventory_script: Script, battle_script: Script, map_script: Script) -> void:
	_identity_script = identity_script
	_unit_script = unit_script
	_battle_script = battle_script
	_map_script = map_script
	for script: Script in [unit_state_script, identity_script, codec_script, unit_script,
		inventory_script, battle_script, map_script]:
		if script == null or not script.can_instantiate(): return
	_factory = unit_state_script.new(codec_script, unit_script, inventory_script)

func _bad(code: String, field: String = "") -> Dictionary:
	return {"ok": false, "code": code, "field": field}

func _version(value: String) -> bool:
	return not value.strip_edges().is_empty() and value.length() <= 256

func _id(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.is_empty() or value.length() > MAX_ID.length(): return false
	if value.unicode_at(0) < 49 or value.unicode_at(0) > 57: return false
	for index in range(1, value.length()):
		if value.unicode_at(index) < 48 or value.unicode_at(index) > 57: return false
	return value.length() < MAX_ID.length() or value <= MAX_ID

func _fields(value: Variant, expected: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != expected.size(): return false
	for key in value:
		if typeof(key) != TYPE_STRING or key not in expected: return false
	return true

func _node(value: Variant, script: Script) -> bool:
	return typeof(value) == TYPE_OBJECT and is_instance_valid(value) and value is Node \
		and value.get_script() == script and not value.is_queued_for_deletion()

func _destination(battle: Variant, game_map: Variant) -> Dictionary:
	if _factory == null: return _bad("MODULE_CONFIGURATION")
	if not _node(battle, _battle_script): return _bad("BATTLE_INSTANCE")
	if not _node(game_map, _map_script) or not is_same(battle.map, game_map): return _bad("BATTLE_MAP")
	if battle.is_inside_tree() and not battle.get_tree().paused: return _bad("PAUSED_BATTLE_REQUIRED")
	return {"ok": true}

func _live_graph(battle: Variant) -> Dictionary:
	if not _node(battle, _battle_script): return _bad("BATTLE_INSTANCE")
	var checked: Dictionary = _destination(battle, battle.map)
	if not checked.ok: return checked
	var unit_root: Variant = battle.units_root
	if typeof(unit_root) != TYPE_OBJECT or not is_instance_valid(unit_root) or not unit_root is Node2D:
		return _bad("UNITS_ROOT")
	if unit_root.is_queued_for_deletion() or not battle.is_ancestor_of(unit_root): return _bad("UNITS_ROOT")
	if unit_root.get_child_count(true) > MAX_UNITS: return _bad("UNIT_LIMIT")
	var ordered: Array = []
	var membership: Dictionary = {}
	# Internal children are included; an unexpected non-Unit is rejected, not skipped.
	for child: Variant in unit_root.get_children(true):
		if not _node(child, _unit_script): return _bad("ROOT_CHILD_UNIT")
		if not is_same(child.battle, battle) or not is_same(child.map, battle.map): return _bad("UNIT_OWNER")
		ordered.append(child)
		membership[child] = true
	if typeof(battle.units) != TYPE_ARRAY or battle.units.size() > MAX_UNITS: return _bad("ACTIVE_ARRAY")
	var active: Array = []
	var seen: Dictionary = {}
	for unit: Variant in battle.units:
		if not _node(unit, _unit_script) or not membership.has(unit): return _bad("ACTIVE_UNIT_OUTSIDE_ROOT")
		if seen.has(unit): return _bad("ACTIVE_DUPLICATE")
		seen[unit] = true
		active.append(unit)
	return {"ok": true, "ordered": ordered, "active": active, "membership": membership}

func _capture_failed(error: Dictionary, identity: Variant, owns_identity: bool) -> Dictionary:
	if owns_identity: identity.dispose()
	return error

func capture(battle: Variant, object_to_id: Variant, content_version: String,
		retained_identity: Variant = null) -> Dictionary:
	if _factory == null: return _bad("MODULE_CONFIGURATION")
	if not _version(content_version): return _bad("CONTENT_VERSION")
	var graph: Dictionary = _live_graph(battle)
	if not graph.ok: return graph
	if typeof(object_to_id) != TYPE_DICTIONARY or object_to_id.size() != graph.ordered.size():
		return _bad("REGISTRY_COMPLETE_SET")
	var id_to_unit: Dictionary = {}
	for unit: Variant in object_to_id:
		if not _node(unit, _unit_script) or not graph.membership.has(unit): return _bad("REGISTRY_COMPLETE_SET")
		var entity_id: Variant = object_to_id[unit]
		if not _id(entity_id): return _bad("ENTITY_ID")
		if id_to_unit.has(entity_id): return _bad("ENTITY_ID_DUPLICATE")
		id_to_unit[entity_id] = unit
	var owns_identity: bool = typeof(retained_identity) == TYPE_NIL
	var identity: Variant = retained_identity
	if owns_identity:
		identity = _identity_script.new(_unit_script)
	elif typeof(identity) != TYPE_OBJECT or not is_instance_valid(identity) or identity.get_script() != _identity_script:
		return _bad("IDENTITY_CONTEXT")
	var configured: Dictionary = identity.configure(id_to_unit, graph.ordered)
	if not configured.ok: return _capture_failed(configured, identity, owns_identity)
	var records: Array = []
	var root_order: Array = []
	var active_order: Array = []
	for unit: Variant in graph.ordered:
		var entity_id: String = object_to_id[unit]
		var result: Dictionary = _factory.capture(unit, entity_id, content_version, object_to_id, identity.encode_identity)
		if not result.ok: return _capture_failed(result, identity, owns_identity)
		records.append(result.record)
		root_order.append(entity_id)
	for unit: Variant in graph.active: active_order.append(object_to_id[unit])
	return {"ok": true, "value": {"schema": SCHEMA, "content_version": content_version,
		"root_order": root_order, "active_order": active_order, "records": records}, "identity": identity,
		"complete_battle_restore": false}

func validate(snapshot: Variant, content_version: String) -> Dictionary:
	if _factory == null: return _bad("MODULE_CONFIGURATION")
	if not _version(content_version): return _bad("CONTENT_VERSION")
	if not _fields(snapshot, GRAPH_FIELDS): return _bad("GRAPH_FIELDS")
	if typeof(snapshot.schema) != TYPE_STRING or snapshot.schema != SCHEMA: return _bad("GRAPH_SCHEMA")
	if typeof(snapshot.content_version) != TYPE_STRING or snapshot.content_version != content_version:
		return _bad("CONTENT_VERSION")
	for field: String in ["root_order", "active_order", "records"]:
		if typeof(snapshot[field]) != TYPE_ARRAY or snapshot[field].size() > MAX_UNITS: return _bad("GRAPH_ARRAY", field)
	if snapshot.records.size() != snapshot.root_order.size(): return _bad("RECORD_COUNT")
	var known: Dictionary = {}
	for entity_id: Variant in snapshot.root_order:
		if not _id(entity_id): return _bad("ENTITY_ID")
		if known.has(entity_id): return _bad("ROOT_ID_DUPLICATE")
		known[entity_id] = true
	var active_seen: Dictionary = {}
	for entity_id: Variant in snapshot.active_order:
		if not _id(entity_id) or not known.has(entity_id): return _bad("ACTIVE_ID_UNKNOWN")
		if active_seen.has(entity_id): return _bad("ACTIVE_ID_DUPLICATE")
		active_seen[entity_id] = true
	# Validate every record before any Unit or tombstone is allocated. The inner
	# codec bounds each record; outer RunSession must additionally bound file bytes.
	var identity: Variant = _identity_script.new(_unit_script)
	var declared: Dictionary = identity.declare_entities(known)
	if not declared.ok:
		identity.dispose()
		return declared
	for index in range(snapshot.records.size()):
		var record: Variant = snapshot.records[index]
		if typeof(record) != TYPE_DICTIONARY or record.get("entity_id") != snapshot.root_order[index]:
			identity.dispose()
			return _bad("RECORD_ORDER", str(index))
		var result: Dictionary = _factory.validate(record, content_version, known, identity.validate_identity)
		if not result.ok:
			identity.dispose()
			return _bad("UNIT_" + String(result.get("code", "INVALID")), str(index) + ":" + String(result.get("field", "")))
	identity.dispose()
	# Deep copy only after the bounded inner codec has rejected cycles/invalid trees.
	return {"ok": true, "value": snapshot.duplicate(true), "known_ids": known}

func _restore_failed(error: Dictionary, created: Array, identity: Variant = null) -> Dictionary:
	# Only newly created, never-attached Units enter this list; source graph excluded.
	if identity != null: identity.dispose()
	var freed: int = 0
	for unit: Variant in created:
		if is_instance_valid(unit):
			unit.free()
			freed += 1
	return {"ok": false, "code": error.get("code", "RESTORE_FAILED"), "field": error.get("field", ""),
		"created_count": created.size(), "freed_count": freed, "battle_modified": false}

func prepare(snapshot: Variant, content_version: String, battle: Variant, game_map: Variant) -> Dictionary:
	var destination: Dictionary = _destination(battle, game_map)
	if not destination.ok: return _restore_failed(destination, [])
	var checked: Dictionary = validate(snapshot, content_version)
	if not checked.ok: return _restore_failed(checked, [])
	var saved: Dictionary = checked.value
	var identity: Variant = _identity_script.new(_unit_script)
	var declared: Dictionary = identity.declare_entities(checked.known_ids)
	if not declared.ok: return _restore_failed(declared, [], identity)
	var created: Array = []
	var id_to_unit: Dictionary = {}
	var object_to_id: Dictionary = {}
	var activation_plan: Array = []
	for record: Dictionary in saved.records:
		var shell: Dictionary = _factory.instantiate(record, content_version, checked.known_ids, identity.validate_identity)
		if not shell.ok: return _restore_failed(shell, created, identity)
		created.append(shell.unit)
		id_to_unit[shell.entity_id] = shell.unit
		object_to_id[shell.unit] = shell.entity_id
		activation_plan.append({"entity_id": shell.entity_id, "unit": shell.unit, "activation": shell.activation})
	var configured: Dictionary = identity.configure(id_to_unit, created)
	if not configured.ok: return _restore_failed(configured, created, identity)
	var expired: Variant = identity.expired_unit() if not created.is_empty() else null
	for index in range(created.size()):
		var bound: Dictionary = _factory.bind(created[index], saved.records[index], content_version, id_to_unit,
			battle, game_map, identity.decode_identity, identity.validate_identity, expired)
		if not bound.ok: return _restore_failed(bound, created, identity)
	# Unit binding is complete, but the outer Battle/effect transaction still uses
	# this same identity. Caller releases all tombstones only after every graph has
	# bound, then attaches/activates while the complete-step barrier remains held.
	var active: Array = []
	for entity_id: String in saved.active_order: active.append(id_to_unit[entity_id])
	return {"ok": true, "units_in_root_order": created, "active_units": active,
		"id_to_unit": id_to_unit, "object_to_id": object_to_id, "activation_plan": activation_plan,
		"identity": identity, "expired_unit": expired, "attached": false, "activated": false,
		"tombstones_released": false,
		"pending_battle_signals": ["died", "story_resolved"], "complete_battle_restore": false}
