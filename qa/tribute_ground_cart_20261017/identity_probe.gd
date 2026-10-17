extends SceneTree
func _initialize() -> void:
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("GROUND_EXPECTED_IDENTITY")))
	var actual: Dictionary=load("res://scripts/run_build_identity.gd").IDENTITY
	var record:=FileAccess.open(OS.get_environment("GROUND_EXPECTED_IDENTITY").get_base_dir().path_join("actual_packed_identity.json"),FileAccess.WRITE)
	record.store_string(JSON.stringify(actual,"\t"));record.close()
	if JSON.parse_string(JSON.stringify(actual))!=expected:
		push_error("Existing PCK identity differs from actual retained compilation inputs");quit(1);return
	print("PCK_IDENTITY_EXACT ",actual.source_sha256," files=",actual.file_count)
	quit()
