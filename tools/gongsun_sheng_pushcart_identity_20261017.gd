extends SceneTree
func _initialize() -> void:
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("GONGSUN_EXPECTED_IDENTITY")))
	var actual: Dictionary=load("res://scripts/run_build_identity.gd").IDENTITY
	if JSON.parse_string(JSON.stringify(actual))!=expected:
		push_error("Packed identity differs from actual frozen Gongsun Sheng art inputs");quit(1);return
	print("PCK_IDENTITY_EXACT ",actual.source_sha256," files=",actual.file_count)
	quit()
