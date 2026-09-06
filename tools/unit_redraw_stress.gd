extends "res://tools/rts_performance_probe.gd"
## Uninstrumented live combat; independent runs are observations, not a paired FPS claim.
func sample(b, label: String) -> Dictionary:
	b._perf_bench_setup(200)
	b._prof_on = false
	var result: Dictionary = await super.sample(b,label)
	result["camera_zoom"] = str(b.camera.zoom)
	result["phase"] = b.phase
	var screenshot: String = OS.get_environment("REDRAW_SCREENSHOT")
	if not screenshot.is_empty():
		result["screenshot"] = screenshot
		result["screenshot_saved"] = root.get_texture().get_image().save_png(screenshot)==OK
	return result
