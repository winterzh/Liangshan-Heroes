extends RefCounted
## Generated from exact historical table declarations, not historical fixture admission.
## No negative execution is implemented here; source audit reconstructs these bytes.
const CAPTURE_CASES := {
	"safe_queue_nonempty": "LEVEL8_SAFE_RETREAT_QUEUE",
	"safe_stop__chase_intent": "LEVEL8_SAFE_RETREAT_STOP_ANCHOR",
	"safe_stop__group_cap": "LEVEL8_SAFE_RETREAT_STOP_ANCHOR",
	"safe_stop__has_home": "LEVEL8_SAFE_RETREAT_STOP_ANCHOR",
	"safe_stop__home": "LEVEL8_SAFE_RETREAT_STOP_ANCHOR",
	"safe_stop__hua_lock_shots": "LEVEL8_SAFE_RETREAT_STOP_ANCHOR",
	"other_hp_zero": "LEVEL8_LIFETIME", "other_dying_true": "LEVEL8_LIFETIME",
	"other_role_null": "LEVEL8_SAFE_REQUIRED_ACTOR_MISSING",
	"other_alive_missing_active": "LEVEL8_ACTIVE_MEMBERSHIP",
	"other_outcome_captured": "LEVEL8_UNSUPPORTED_STORY_OUTCOME",
	"root_safe_selection": "LEVEL8_SAFE_SELECTED_ROOT",
	"root_safe__ability_caster": "LEVEL8_SAFE_ARMED_CASTER",
	"root_safe__item_caster": "LEVEL8_SAFE_ARMED_CASTER",
	"safe_event_missing": "LEVEL8_SAFE_EVENT_OUTCOME_PAIR",
	"other_safe_event_without_retreat": "LEVEL8_SAFE_EVENT_OUTCOME_PAIR",
	"safe_actor_outcome_empty": "LEVEL8_SAFE_EVENT_OUTCOME_PAIR",
	"freed_event_missing": "LEVEL8_SAFE_RESCUE_EVENT_PAIR",
	"rescue_done_false": "LEVEL8_SAFE_RESCUE_EVENT_PAIR",
	"safe_caster__walk_casts": "LEVEL8_SAFE_CAST_INTENT",
	"safe_caster__pending_casts": "LEVEL8_SAFE_CAST_INTENT",
	"safe_caster__channels": "LEVEL8_SAFE_CAST_INTENT",
	"safe_caster__pending_item_casts": "LEVEL8_SAFE_CAST_INTENT",
	"safe_caster__walk_item_casts": "LEVEL8_SAFE_CAST_INTENT"
}

class WorldCases:
	extends RefCounted
	var specs: Array = []
	const RECORD_TEXT := {"units": ["schema", "content_version"], "level": ["schema", "level_id", "content_version", "mission_token"], "root": ["schema", "content_version"], "mission": ["schema"], "presentation": ["schema"]}
	const CONTEXT_TEXT := ["level_id", "content_version", "mission_token", "presentation_token"]
	const CASTERS := {"_walk_casts": "c", "_pending_casts": "caster", "_channels": "caster", "_walk_item_casts": "c", "_pending_item_casts": "caster"}
	func _add(id: String, kind: String, expected: String, args: Dictionary = {}, layer: String = "paired") -> void:
		var spec := {"id": id, "kind": kind, "expected_code": expected, "expected_guard_layer": layer, "direct_pair_branch_coverage": layer == "paired" or layer == "pair_identity_type"}
		for key: String in args: spec[key] = args[key]
		specs.append(spec)

	func _build_specs() -> void:
		_add("safe_queue_nonempty", "queue", "UNIT_LEVEL8_SAFE_RETREAT_QUEUE", {}, "full_unit_contract")
		for field: String in ["_chase_intent", "_group_cap", "_has_home", "_home", "_hua_lock_shots"]:
			_add("safe_stop_" + field, "stop", "UNIT_LEVEL8_SAFE_RETREAT_STOP_ANCHOR", {"field": field}, "full_unit_contract")
		_add("other_role_null", "other_null", "LEVEL8_SAFE_REQUIRED_ACTOR_MISSING")
		_add("other_dead_complete_lifetime", "other_dead", "LEVEL8_SAFE_REQUIRED_ACTOR_LIFETIME")
		_add("other_alive_missing_active", "other_active_drop", "LEVEL8_ACTIVE_MEMBERSHIP", {}, "full_graph_membership")
		_add("other_missing_root_record", "other_root_drop", "UNBOUND_UNIT", {}, "full_level_registry")
		_add("other_captured_outcome", "other_outcome", "UNIT_LEVEL8_UNSUPPORTED_STORY_OUTCOME", {}, "full_unit_contract")
		_add("safe_event_missing", "safe_event_remove", "LEVEL8_SAFE_EVENT_OUTCOME_PAIR")
		_add("safe_actor_outcome_empty", "safe_outcome_remove", "LEVEL8_SAFE_EVENT_OUTCOME_PAIR")
		_add("other_safe_event_without_retreat", "other_event_add", "LEVEL8_SAFE_EVENT_OUTCOME_PAIR")
		_add("root_safe_selection", "root_selection", "LEVEL8_SAFE_SELECTED_ROOT")
		for field: String in ["_ability_caster", "_item_caster"]:
			_add("root_safe_" + field, "root_caster", "LEVEL8_SAFE_ARMED_CASTER", {"field": field})
		for kind: String in CASTERS:
			_add("safe_caster_" + kind, "cast", "LEVEL8_SAFE_CAST_INTENT", {"array": kind})
		_add("freed_event_missing", "freed_remove", "LEVEL8_SAFE_RESCUE_EVENT_PAIR")
		_add("rescue_done_false", "rescue_done", "LEVEL8_SAFE_RESCUE_EVENT_PAIR")
		var values: Array = [null, true, 1, 1.0, [], {}]
		var labels := ["nil", "bool", "int", "float", "array", "dictionary"]
		for section: String in RECORD_TEXT:
			for field: String in RECORD_TEXT[section]:
				for i: int in range(values.size()):
					_add("identity_" + section + "_" + field + "_" + labels[i], "identity", "LEVEL8_SAFE_IDENTITY_TEXT_TYPE", {"section": section, "path": [field], "value": values[i]}, "pair_identity_type")
		for section: String in ["mission", "presentation"]:
			for field: String in CONTEXT_TEXT:
				for i: int in range(values.size()):
					_add("identity_" + section + "_context_" + field + "_" + labels[i], "identity", "LEVEL8_SAFE_CONTEXT_TEXT_TYPE", {"section": section, "path": ["context", field], "value": values[i]}, "pair_identity_type")


class ComponentCases:
	extends RefCounted
	var specs: Array = []
	func _add(id: String, module: String, kind: String, code: String, extra: Dictionary = {}) -> void:
		var spec := {"id": id, "module": module, "kind": kind, "expected_code": code}
		spec.merge(extra); specs.append(spec)

	func _build_specs() -> void:
		for field: String in ["_chase_intent", "_group_cap", "_has_home", "_home", "_hua_lock_shots"]:
			for module: String in ["unit_full", "contract_values"]:
				_add(module + "_safe_stop_" + field, module, "stop", "LEVEL8_SAFE_RETREAT_STOP_ANCHOR", {"field": field, "subject": "safe"})
		for module: String in ["unit_full", "contract_parts"]:
			_add(module + "_safe_queue_nonempty", module, "queue", "LEVEL8_SAFE_RETREAT_QUEUE", {"subject": "safe"})
		var identities := {"is_captive": "RESCUED_IDENTITY", "is_hero": "RESCUED_IDENTITY", "faction": "RESCUED_IDENTITY", "base_speed": "RESCUED_IDENTITY", "art_variant": "RESCUED_IDENTITY", "is_noncombat": "PRISONER_IDENTITY", "atk": "PRISONER_IDENTITY", "ability": "PRISONER_IDENTITY", "key": "ROLE_KEY"}
		for field: String in identities:
			for module: String in ["unit_full", "contract_values"]:
				_add(module + "_rescued_identity_" + field, module, "rescued_identity", "LEVEL8_" + identities[field], {"field": field, "subject": "other"})
		for field: String in ["hp", "_dying"]:
			for module: String in ["unit_full", "contract_values"]:
				_add(module + "_other_lifetime_" + field, module, "lifetime", "LEVEL8_LIFETIME", {"field": field, "subject": "other"})
		for module: String in ["unit_full", "contract_values"]:
			_add(module + "_other_captured_outcome", module, "outcome", "LEVEL8_UNSUPPORTED_STORY_OUTCOME", {"subject": "other"})
		for kind: String in ["active_drop", "state_drop"]:
			for module: String in ["unit_membership", "contract_membership"]:
				_add(module + "_other_" + kind, module, kind, "LEVEL8_ACTIVE_MEMBERSHIP" if kind == "active_drop" else "LEVEL8_ROLE_NOT_IN_GRAPH", {"subject": "other"})
		var labels := ["nil", "bool", "int", "float", "array", "dictionary"]
		var unit_text := {"schema": "SCHEMA", "content_version": "CONTENT_VERSION", "entity_id": "SUBJECT_ID"}
		for field: String in unit_text:
			for label: String in labels:
				_add("unit_full_identity_" + field + "_" + label, "unit_full", "unit_identity", unit_text[field], {"field": field, "type_case": label, "subject": "safe"})
		var pair_rows := [
			["other_role_null", "other_null", "LEVEL8_SAFE_REQUIRED_ACTOR_MISSING"],
			["other_dead_complete_lifetime", "other_dead", "LEVEL8_SAFE_REQUIRED_ACTOR_LIFETIME"],
			["safe_event_missing", "safe_event_remove", "LEVEL8_SAFE_EVENT_OUTCOME_PAIR"],
			["safe_actor_outcome_empty", "safe_outcome_remove", "LEVEL8_SAFE_EVENT_OUTCOME_PAIR"],
			["other_safe_event_without_retreat", "other_event_add", "LEVEL8_SAFE_EVENT_OUTCOME_PAIR"],
			["root_safe_selection", "root_selection", "LEVEL8_SAFE_SELECTED_ROOT"],
			["freed_event_missing", "freed_remove", "LEVEL8_SAFE_RESCUE_EVENT_PAIR"],
			["rescue_done_false", "rescue_done", "LEVEL8_SAFE_RESCUE_EVENT_PAIR"]]
		for entry: Array in pair_rows: _add("pair_" + entry[0], "pair", entry[1], entry[2])
		for field: String in ["_ability_caster", "_item_caster"]:
			_add("pair_root_safe_" + field, "pair", "root_caster", "LEVEL8_SAFE_ARMED_CASTER", {"field": field})
		for kind: String in ["_walk_casts", "_pending_casts", "_channels", "_walk_item_casts", "_pending_item_casts"]:
			_add("pair_safe_caster_" + kind, "pair", "cast", "LEVEL8_SAFE_CAST_INTENT", {"array": kind})
		var records := {"units": ["schema", "content_version"], "level": ["schema", "level_id", "content_version", "mission_token"], "root": ["schema", "content_version"], "mission": ["schema"], "presentation": ["schema"]}
		for section: String in records:
			for field: String in records[section]:
				for label: String in labels:
					_add("pair_identity_" + section + "_" + field + "_" + label, "pair", "pair_identity", "LEVEL8_SAFE_IDENTITY_TEXT_TYPE", {"section": section, "path": [field], "type_case": label})
		for section: String in ["mission", "presentation"]:
			for field: String in ["level_id", "content_version", "mission_token", "presentation_token"]:
				for label: String in labels:
					_add("pair_identity_" + section + "_context_" + field + "_" + label, "pair", "pair_identity", "LEVEL8_SAFE_CONTEXT_TEXT_TYPE", {"section": section, "path": ["context", field], "type_case": label})


static func world_specs() -> Array:
	var table := WorldCases.new()
	table._build_specs()
	return table.specs

static func component_specs() -> Array:
	var table := ComponentCases.new()
	table._build_specs()
	return table.specs
