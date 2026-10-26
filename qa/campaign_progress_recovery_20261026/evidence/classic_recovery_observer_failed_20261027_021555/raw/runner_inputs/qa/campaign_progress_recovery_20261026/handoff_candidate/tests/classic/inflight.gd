extends RefCounted
## Independent acceptance observations; not the production save codec.
## Reads paused authority; never attaches Nodes/signals or calls gameplay commands.
const UnitScript = preload("res://scripts/unit.gd")
const ProjectileScript = preload("res://scripts/projectile.gd")
const QUEUE_FIELDS := {
	"_walk_casts": ["c", "slot", "tgt", "point", "serial", "t", "age"],
	"_pending_casts": ["caster", "slot", "lp", "tgt", "serial"],
	"_channels": ["caster", "center", "eff", "sc", "rank", "r", "tick", "tick_t", "ad"],
	"_pending_item_casts": ["caster", "slot", "uid", "point", "target", "serial"],
	"_walk_item_casts": ["c", "uid", "tgt", "point", "serial", "t", "age"]}
const PROJECTILE_VALUES := ["dmg", "crit", "damage_ability_id", "speed", "_dir", "_life", "kind", "splash", "on_slow_mult", "on_slow_dur", "_dist0", "_spin"]
const CAST_UNIT_VALUES := ["_cast_t", "_cast_dur", "_cast_serial", "_channel_t", "_channel_dur", "_order_serial"]
var _ids: Dictionary = {}
var _issue := ""
var _budget := 65536

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func _fail(path: String, reason: String) -> Variant:
	if _issue.is_empty(): _issue = path + ":" + reason
	return null

func _live_unit(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT and is_instance_valid(value) and value.get_script() == UnitScript and not value.is_queued_for_deletion() and value.hp > 0.0

func _encode(value: Variant, path: String, depth := 0) -> Variant:
	_budget -= 1
	if _budget < 0 or depth > 32: return _fail(path, "LIMIT")
	# All values have explicit types; dictionary keys cannot collide with tags.
	match typeof(value):
		TYPE_NIL: return {"type": "null"}
		TYPE_BOOL: return {"type": "bool", "value": value}
		TYPE_INT: return {"type": "int", "text": str(value)}
		TYPE_FLOAT:
			if not is_finite(value): return _fail(path, "NONFINITE_FLOAT")
			return {"type": "float", "value": value}
		TYPE_STRING: return {"type": "string", "value": value}
		TYPE_VECTOR2:
			if value == Vector2.INF: return {"type": "vector2_positive_inf"}
			if not value.is_finite(): return _fail(path, "NONFINITE_VECTOR")
			return {"type": "vector2", "xy": [value.x, value.y]}
		TYPE_COLOR:
			if not is_finite(value.r) or not is_finite(value.g) or not is_finite(value.b) or not is_finite(value.a): return _fail(path, "NONFINITE_COLOR")
			return {"type": "color", "rgba": [value.r, value.g, value.b, value.a]}
		TYPE_OBJECT:
			# A freed Object can compare equal to null. Test its Variant type first.
			if not is_instance_valid(value): return {"type": "unit_ref", "state": "expired"}
			if value.get_script() != UnitScript or not _ids.has(value): return _fail(path, "UNREGISTERED_OBJECT")
			return {"type": "unit_ref", "state": "entity", "id": _ids[value]}
		TYPE_ARRAY:
			var items: Array = []
			for index in range(value.size()): items.append(_encode(value[index], path + "[" + str(index) + "]", depth + 1))
			return {"type": "array", "items": items}
		TYPE_DICTIONARY:
			var keys: Array = value.keys()
			for key: Variant in keys:
				if typeof(key) != TYPE_STRING: return _fail(path, "NONSTRING_KEY")
			keys.sort()
			var entries: Array = []
			for key: String in keys: entries.append({"key": key, "value": _encode(value[key], path + "." + key, depth + 1)})
			return {"type": "dictionary", "entries": entries}
	return _fail(path, "UNSUPPORTED_TYPE_" + str(typeof(value)))

func _queue_shape(rows: Variant, fields: Array) -> bool:
	if typeof(rows) != TYPE_ARRAY or rows.size() > 4096: return false
	for row: Variant in rows:
		if typeof(row) != TYPE_DICTIONARY or row.size() != fields.size() or not row.has_all(fields): return false
	return true

func capture(battle: Variant, require_held := false) -> Dictionary:
	_ids.clear(); _issue = ""; _budget = 65536
	if not is_instance_valid(battle) or not battle.is_inside_tree() or not battle.get_tree().paused or Engine.is_in_physics_frame(): return _bad("OBSERVER_PAUSED_BOUNDARY_REQUIRED")
	if battle._run_clock.in_step(): return _bad("OBSERVER_OPEN_PHYSICS_STEP")
	if require_held and battle._save_barrier.state != battle._save_barrier.State.HELD: return _bad("OBSERVER_HELD_REQUIRED")
	# Include dying Units that have already left Battle.units but remain referenced.
	var seen_ids: Dictionary = {}
	var clock_units: Array = []
	for unit: Variant in battle.units_root.get_children(true):
		if unit.get_script() != UnitScript or unit.is_queued_for_deletion() or unit.entity_id <= 0: return _bad("OBSERVER_UNIT_REGISTRY")
		var token := str(unit.entity_id)
		if seen_ids.has(token): return _bad("OBSERVER_DUPLICATE_ENTITY")
		seen_ids[token] = true; _ids[unit] = token
		var row := {"id": token}
		for field: String in CAST_UNIT_VALUES: row[field] = unit.get(field)
		clock_units.append(row)
	clock_units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.id) < int(b.id))
	var queues: Dictionary = {}
	var counts: Dictionary = {}
	for field: String in QUEUE_FIELDS:
		var rows: Variant = battle.get(field)
		if not _queue_shape(rows, QUEUE_FIELDS[field]): return _bad("OBSERVER_QUEUE_SHAPE:" + field)
		queues[field] = rows
		counts[field] = rows.size()
	var projectiles: Array = []
	var live_projectiles := 0
	var children: Array = battle.fx_root.get_children(true)
	for index in range(children.size()):
		var node: Variant = children[index]
		if node.get_script() != ProjectileScript: continue
		# At HELD/paused comparison, queued frees should have drained. Reject a
		# contaminated boundary; pre-save trigger sampling should instead skip them.
		if node.is_queued_for_deletion(): return _bad("OBSERVER_QUEUED_PROJECTILE")
		var row := {"fx_index": index, "position": node.position,
			"basis_x": node.transform.x, "basis_y": node.transform.y,
			"target": node.target, "shooter": node.shooter}
		for field: String in PROJECTILE_VALUES: row[field] = node.get(field)
		projectiles.append(row)
		if node._life > 0.0 and node.dmg > 0.0 and _live_unit(node.target): live_projectiles += 1
	# These are remaining actions, not a promise that damage will eventually land.
	# Walk-only intents deliberately do not satisfy the combat checkpoint.
	var live_spell_windups := 0
	for row: Dictionary in battle._pending_casts:
		var caster: Variant = row.caster
		if not _live_unit(caster) or caster._cast_t <= 0.0 or int(row.serial) != caster._cast_serial: continue
		if typeof(row.tgt) != TYPE_NIL and not _live_unit(row.tgt): continue
		live_spell_windups += 1
	var live_item_windups := 0
	for row: Dictionary in battle._pending_item_casts:
		var caster: Variant = row.caster
		if not _live_unit(caster) or caster._cast_t <= 0.0 or int(row.serial) != caster._cast_serial or caster.inventory == null: continue
		if caster.inventory.find_uid(int(row.uid)) < 0: continue
		if typeof(row.target) != TYPE_NIL and not _live_unit(row.target): continue
		live_item_windups += 1
	var live_channels := 0
	for row: Dictionary in battle._channels:
		if _live_unit(row.caster) and row.caster._channel_t > 0.0: live_channels += 1
	var wire: Variant = _encode({"projectiles": projectiles, "queues": queues, "cast_units": clock_units}, "inflight")
	if not _issue.is_empty(): return _bad("OBSERVER_ENCODE:" + _issue)
	var witness := {"clock_next": str(battle._run_clock._next_tick), "enemies": battle.enemies_alive(),
		"projectiles": projectiles.size(), "queue_counts": counts, "live_projectiles": live_projectiles,
		"live_spell_windups": live_spell_windups, "live_item_windups": live_item_windups, "live_channels": live_channels,
		"in_flight": live_projectiles + live_spell_windups + live_item_windups + live_channels}
	# Keep require_held out of value: the restored scene is paused but has a fresh
	# IDLE barrier. The two snapshots must compare the same gameplay fields.
	return {"ok": true, "value": {"schema": "classic30_inflight_observation_v1", "data": wire}, "witness": witness}
