extends SceneTree

func _initialize() -> void:
	var rows: Array = [
		["int_float_zero", 0, 0.0, true], ["float_int_zero", 0.0, 0, true],
		["negative_safe", -9007199254740991, -9007199254740991.0, true],
		["positive_safe", 9007199254740991, 9007199254740991.0, true],
		["unsafe", 9007199254740992, 9007199254740992.0, false],
		["unsafe_negative", -9007199254740992, -9007199254740992.0, false],
		["fraction", 1, 1.5, false], ["numeric_mismatch", 1, 2.0, false],
		["bool_int", true, 1, false], ["bool_float", false, 0.0, false],
		["string", "1", 1, false], ["null_zero", null, 0, false],
		["nan", NAN, NAN, false], ["infinity", INF, INF, false],
		["cross_infinity", 1, INF, false], ["negative_zero", 0, -0.0, false],
		["float_zero_sign", 0.0, -0.0, false], ["negative_zero_same", -0.0, -0.0, true],
		["same_float", 1.25, 1.25, true], ["changed_float", 1.25, 1.2500000000000002, false],
		["same_int_large", 9223372036854775807, 9223372036854775807, true],
		["nil", null, null, true], ["boolean", true, true, true],
		["dictionary_missing", {"a": 1}, {}, false],
		["dictionary_added", {}, {"a": 1}, false],
		["dictionary_key_changed", {"a": 1}, {"b": 1.0}, false],
		["dictionary_nonstring", {1: "x"}, {1: "x"}, false],
		["array_reordered", [1, 2], [2.0, 1.0], false],
		["array_length", [1], [1.0, 2.0], false],
		["nested_exact", {"x": [true, null, {"n": -2}]}, {"x": [true, null, {"n": -2.0}]}, true],
		["nested_changed", {"x": [true, null, {"n": -2}]}, {"x": [true, null, {"n": -3.0}]}, false],
		["unsupported_vector", Vector2.ZERO, Vector2.ZERO, false]]
	var actual_c := JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("TRANSPORT_ORIGINAL_C")))
	var original: Dictionary = {"active_run": 0, "settled": {}, "stats": {}, "unlocked": {}}
	rows.append(["actual_C_empty_private_Steam_transport", original, actual_c.effects.steam, true])
	var results: Array = []
	var all_passed := true
	for row: Array in rows:
		var actual := _json_transport_equal(row[1], row[2])
		var passed: bool = actual == row[3]
		all_passed = all_passed and passed
		results.append({"id": row[0], "expected": row[3], "actual": actual, "passed": passed})
	var observation := {"schema": "terminal_steam_transport_primitive_v1", "pid": OS.get_process_id(), "nonce": OS.get_environment("TRANSPORT_NONCE"),
		"checks": results, "all_passed": all_passed, "actual_C_direct_dictionary_equal": original == actual_c.effects.steam,
		"original_active_run_type": typeof(original.active_run), "parsed_active_run_type": typeof(actual_c.effects.steam.active_run), "full_chain_qualified": false}
	var file := FileAccess.open(OS.get_environment("TRANSPORT_OUT").path_join("report.json"), FileAccess.WRITE)
	if file == null: quit(2); return
	file.store_string(JSON.stringify(observation, "\t"))
	file.close()
	quit(0 if all_passed else 1)

func _json_transport_equal(left: Variant, right: Variant, depth: int = 0) -> bool:
	# JSON only; full keysets/order retained. Cross numeric types allow exact safe integers only.
	if depth > 64: return false
	var lt := typeof(left)
	var rt := typeof(right)
	if lt != rt:
		if not ((lt == TYPE_INT and rt == TYPE_FLOAT) or (lt == TYPE_FLOAT and rt == TYPE_INT)): return false
		var integer: int = left if lt == TYPE_INT else right
		var number: float = left if lt == TYPE_FLOAT else right
		if integer < -9007199254740991 or integer > 9007199254740991: return false
		if not is_finite(number) or number < -9007199254740991.0 or number > 9007199254740991.0 or floor(number) != number: return false
		return int(number) == integer and _json_transport_equal(float(integer), number, depth + 1)
	match lt:
		TYPE_NIL, TYPE_BOOL, TYPE_STRING, TYPE_INT:
			return left == right
		TYPE_FLOAT:
			if not is_finite(left) or not is_finite(right): return false
			var a := PackedByteArray()
			var b := PackedByteArray()
			a.resize(8)
			b.resize(8)
			a.encode_double(0, left)
			b.encode_double(0, right)
			return a == b
		TYPE_ARRAY:
			if left.size() != right.size(): return false
			for i: int in left.size():
				if not _json_transport_equal(left[i], right[i], depth + 1): return false
			return true
		TYPE_DICTIONARY:
			if left.size() != right.size(): return false
			for key: Variant in left:
				if typeof(key) != TYPE_STRING or not right.has(key): return false
				if not _json_transport_equal(left[key], right[key], depth + 1): return false
			for key: Variant in right:
				if typeof(key) != TYPE_STRING: return false
			return true
	return false

