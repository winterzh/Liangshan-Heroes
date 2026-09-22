extends SceneTree
func _initialize() -> void:
	var actual := OS.get_user_data_dir()
	print("PRIVATE_EXE_PROFILE ", actual)
	quit(0 if actual.replace("\\", "/") == OS.get_environment("LSH_EXPECTED_PROFILE").replace("\\", "/") else 2)
