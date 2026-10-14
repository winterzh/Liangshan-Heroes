extends SceneTree
func _guard(row: Dictionary) -> bool:
	var size_type := typeof(row.bytes)
	var safe_size := false
	if size_type == TYPE_INT:
		safe_size = row.bytes >= 0 and row.bytes <= 9007199254740991
	elif size_type == TYPE_FLOAT:
		safe_size = is_finite(row.bytes) and row.bytes >= 0.0 and row.bytes <= 9007199254740991.0 and floor(row.bytes) == row.bytes
	return safe_size
func _initialize() -> void:
	var cases := [
		["int_zero", 0, true], ["int_positive", 807, true], ["float_zero", 0.0, true], ["float_positive", 807.0, true],
		["JSON_positive", JSON.parse_string("807"), true], ["int_max_safe", 9007199254740991, true], ["float_max_safe", 9007199254740991.0, true],
		["int_unsafe", 9007199254740992, false], ["float_unsafe", 9007199254740992.0, false], ["int_max", 9223372036854775807, false],
		["negative_int", -1, false], ["negative_float", -1.0, false], ["fraction", 807.5, false], ["tiny_fraction", 0.000001, false],
		["nan", NAN, false], ["positive_inf", INF, false], ["negative_inf", -INF, false],
		["bool_true", true, false], ["bool_false", false, false], ["null", null, false], ["string", "807", false], ["array", [807], false], ["dictionary", {"bytes": 807}, false]
	]
	var all_passed := true
	for case in cases:
		var actual := _guard({"bytes": case[1]})
		var passed: bool = actual == case[2]
		all_passed = all_passed and passed
		print("TERMINAL_ROW_GUARD_CASE ", JSON.stringify({"id": case[0], "type": typeof(case[1]), "expected": case[2], "actual": actual, "passed": passed}))
	print("TERMINAL_ROW_GUARD_COMPLETE ", all_passed, " ", cases.size())
	quit(0 if all_passed else 1)
