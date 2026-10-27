extends RefCounted
## The outer graph validator supplies a trusted maximum over ALL allocated item
## identities: living/dying inventories, hero_item_progress and retired/effect aliases.
## A snapshot cannot certify its own maximum. This module never renumbers a stack.
const SCHEMA := "battle_item_uid_v1"
const MAX_UID := 9223372036854775807
var _codec: Variant
var _battle_script: Script

func _init(codec_script: Script, battle_script: Script) -> void:
	_codec = codec_script.new()
	_battle_script = battle_script

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func _version(value: String) -> bool:
	return not value.strip_edges().is_empty() and value.length() <= 256

func _battle(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT and is_instance_valid(value) and value is Node \
		and value.get_script() == _battle_script and not value.is_queued_for_deletion()

func _counter(value: Variant, verified_allocated_uid_max: Variant) -> Dictionary:
	if typeof(verified_allocated_uid_max) != TYPE_INT or verified_allocated_uid_max < 0:
		return _bad("VERIFIED_MAX_REQUIRED")
	if typeof(value) != TYPE_INT or value <= 0 or value <= verified_allocated_uid_max:
		return _bad("COUNTER_NOT_ABOVE_ALLOCATED")
	return {"ok": true, "next_item_uid": value, "exhausted": value == MAX_UID}

func capture(battle: Variant, content_version: String, verified_allocated_uid_max: Variant) -> Dictionary:
	if not _battle(battle): return _bad("BATTLE_INSTANCE")
	if not _version(content_version): return _bad("CONTENT_VERSION")
	var checked: Dictionary = _counter(battle.next_item_uid, verified_allocated_uid_max)
	if not checked.ok: return checked
	var encoded: Dictionary = _codec.encode(checked.next_item_uid)
	if not encoded.ok: return encoded
	return {"ok": true, "value": {"schema": SCHEMA, "content_version": content_version,
		"next_item_uid": encoded.value}, "complete_battle_restore": false}

func validate(snapshot: Variant, content_version: String, verified_allocated_uid_max: Variant) -> Dictionary:
	if not _version(content_version): return _bad("CONTENT_VERSION")
	if typeof(snapshot) != TYPE_DICTIONARY or snapshot.size() != 3: return _bad("COUNTER_FIELDS")
	for key: Variant in snapshot:
		if typeof(key) != TYPE_STRING or key not in ["schema", "content_version", "next_item_uid"]:
			return _bad("COUNTER_FIELDS")
	if typeof(snapshot.schema) != TYPE_STRING or snapshot.schema != SCHEMA: return _bad("COUNTER_SCHEMA")
	if typeof(snapshot.content_version) != TYPE_STRING or snapshot.content_version != content_version:
		return _bad("CONTENT_VERSION")
	var decoded: Dictionary = _codec.decode(snapshot.next_item_uid)
	if not decoded.ok: return decoded
	return _counter(decoded.value, verified_allocated_uid_max)

func restore(battle: Variant, snapshot: Variant, content_version: String,
		verified_allocated_uid_max: Variant) -> Dictionary:
	if not _battle(battle): return _bad("BATTLE_INSTANCE")
	if battle.is_inside_tree() and not battle.get_tree().paused: return _bad("PAUSED_BATTLE_REQUIRED")
	# Only a fresh allocation domain may accept an externally validated counter.
	# New graph inventories may already be staged; no new allocation may have run.
	if battle.next_item_uid != 1: return _bad("FRESH_COUNTER_REQUIRED")
	var checked: Dictionary = validate(snapshot, content_version, verified_allocated_uid_max)
	if not checked.ok: return checked
	battle.next_item_uid = checked.next_item_uid
	return {"ok": true, "next_item_uid": checked.next_item_uid,
		"exhausted": checked.exhausted, "complete_battle_restore": false}
