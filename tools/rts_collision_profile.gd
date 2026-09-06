extends "res://tools/rts_performance_probe.gd"

func sample(b, label: String) -> Dictionary:
	if not OS.get_environment("RTS_PROFILE_BENCH").is_empty():
		b._perf_bench_setup(int(OS.get_environment("RTS_PROFILE_BENCH")))
	b._prof_on = true
	var result: Dictionary = await super.sample(b, label)
	result["level_script"] = b.level.get_script().resource_path
	result["phase"] = b.phase
	result["stage"] = b.level.get("stage")
	result["camera_zoom"] = str(b.camera.zoom)
	var image_path: String = "res://.godot/rts_profile_" + b.level.id() + ".png"
	root.get_texture().get_image().save_png(image_path)
	return result
