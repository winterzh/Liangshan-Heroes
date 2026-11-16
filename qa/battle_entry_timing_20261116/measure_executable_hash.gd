extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2)
		return
	var path := args[0]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		quit(3)
		return
	var length := file.get_length()
	file.close()
	var elapsed: Array[float] = []
	var digest := ""
	for visit in range(2):
		var started := Time.get_ticks_usec()
		var result := FileAccess.get_sha256(path)
		elapsed.append(float(Time.get_ticks_usec() - started) / 1000.0)
		if result.length() != 64 or (visit > 0 and digest != result):
			quit(4)
			return
		digest = result
	print("PACKAGE_HASH " + JSON.stringify({"bytes": length, "sha256": digest, "elapsed_ms": elapsed}))
	quit()
