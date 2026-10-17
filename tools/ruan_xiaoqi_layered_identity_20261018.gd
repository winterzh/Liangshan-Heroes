extends Node
func _ready() -> void:
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("RUAN_EXPECTED_IDENTITY")))
	var actual: Dictionary=load("res://scripts/run_build_identity.gd").IDENTITY
	if JSON.parse_string(JSON.stringify(actual))!=expected:
		push_error("Mounted base+patch identity differs from actual frozen Ruan Xiaoqi inputs");get_tree().quit(1);return
	print("BASE_PATCH_IDENTITY_EXACT ",actual.source_sha256," files=",actual.file_count)
	get_tree().quit()
