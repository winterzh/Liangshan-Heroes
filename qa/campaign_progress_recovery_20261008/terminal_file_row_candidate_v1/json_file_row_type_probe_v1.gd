extends SceneTree
func _initialize() -> void:
	var live := {"relative_user_path": "record.json", "bytes": 807, "sha256": "abc"}
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(live))
	var observations := {"live_bytes_type": typeof(live.bytes), "JSON_bytes_type": typeof(parsed.bytes), "direct_dictionary_equal": live == parsed, "normalized_fields_equal": live.relative_user_path == parsed.relative_user_path and live.bytes == int(parsed.bytes) and live.sha256 == parsed.sha256}
	print("TERMINAL_ROW_TYPE_DIAGNOSTIC ", JSON.stringify(observations))
	quit(0 if typeof(live.bytes) == TYPE_INT and typeof(parsed.bytes) == TYPE_FLOAT and live != parsed and observations.normalized_fields_equal else 1)
