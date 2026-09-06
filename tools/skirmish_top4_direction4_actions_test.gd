extends SceneTree
## Strict, read-only production contract for the four high-frequency official
## units used by Liangshan defense.  Unlike the broad coverage audit, this
## test does not accept legacy-action or directional-idle fallback as success.

const UNITS := ["guan_dao", "guan_gong", "guan_jingqi", "guan_qi"]
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const REQUIRED_FRAMES := {"walk": 2, "attack": 3, "death": 4}
const REPORT := "res://qa/skirmish_direction4_actions_20260905/action_contract.json"

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var cells: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[skirmish-top4-actions] ", "PASS " if passed else "FAIL ", name,
		"" if detail == null else " :: " + JSON.stringify(detail))
	if not passed:
		failures.append(name)


func _expected(key: String, state: String, direction: String) -> String:
	return "res://assets/anim/%s_%s_%s.png" % [key, state, direction]


func _source(frame: Variant) -> String:
	if frame is AtlasTexture and frame.atlas != null:
		return frame.atlas.resource_path
	return frame.resource_path if frame != null else ""


func _frame_image(frame: Variant) -> Image:
	if frame == null:
		return null
	if frame is AtlasTexture:
		if frame.atlas == null:
			return null
		var atlas_image: Image = frame.atlas.get_image()
		if atlas_image == null or atlas_image.is_empty():
			return null
		var region: Rect2 = frame.region
		var rect := Rect2i(
			int(round(region.position.x)), int(round(region.position.y)),
			int(round(region.size.x)), int(round(region.size.y)))
		return atlas_image.get_region(rect)
	if frame is Texture2D:
		return frame.get_image()
	return null


func _same_pixels(left: Variant, right: Variant) -> bool:
	var left_image := _frame_image(left)
	var right_image := _frame_image(right)
	if left_image == null or right_image == null:
		return false
	if left_image.get_size() != right_image.get_size():
		return false
	# Compare normalized pixels, not importer storage formats.  This prevents an
	# otherwise identical idle copy saved with a different PNG color type from
	# being counted as a changed action pose.
	left_image.convert(Image.FORMAT_RGBA8)
	right_image.convert(Image.FORMAT_RGBA8)
	return left_image.get_data() == right_image.get_data()


func _all_sources(frames: Array) -> Array[String]:
	var result: Array[String] = []
	for frame in frames:
		result.append(_source(frame))
	return result


func _all_sources_equal(frames: Array, expected: String) -> bool:
	if frames.is_empty():
		return false
	for frame in frames:
		if _source(frame) != expected:
			return false
	return true


func _has_non_idle_frame(frames: Array, idle_frames: Array) -> bool:
	if frames.is_empty() or idle_frames.is_empty():
		return false
	var idle: Variant = idle_frames[0]
	for frame in frames:
		if not _same_pixels(frame, idle):
			return true
	return false


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var art := root.get_node_or_null("Art")
	_check("Art autoload available", art != null)
	if art == null:
		_finish()
		return

	for key in UNITS:
		for direction in DIRECTIONS:
			var idle_expected := _expected(key, "idle", direction)
			var idle_frames: Array = art.unit_anim_frames(key, "idle", direction, "")
			var idle_exact := ResourceLoader.exists(idle_expected) \
				and _all_sources_equal(idle_frames, idle_expected)
			_check("%s idle %s exact baseline" % [key, direction], idle_exact, {
				"expected": idle_expected,
				"selected": _all_sources(idle_frames),
				"frames": idle_frames.size(),
			})

			for state in REQUIRED_FRAMES:
				var expected := _expected(key, state, direction)
				var physical := FileAccess.file_exists(expected)
				var imported := ResourceLoader.exists(expected)
				var frames: Array = art.unit_anim_frames(key, state, direction, "")
				var sources := _all_sources(frames)
				var exact := physical and imported and _all_sources_equal(frames, expected)
				var directional := bool(art.unit_anim_uses_directional_source(key, state, direction, ""))
				var enough_frames := frames.size() >= int(REQUIRED_FRAMES[state])
				var changed := _has_non_idle_frame(frames, idle_frames)
				var texture_shape: Array[int] = []
				if imported:
					var texture := load(expected) as Texture2D
					if texture != null:
						texture_shape = [texture.get_width(), texture.get_height()]
				var square_strip := texture_shape.size() == 2 and texture_shape[1] > 0 \
					and texture_shape[0] % texture_shape[1] == 0

				_check("%s %s %s exact directional source" % [key, state, direction], exact, {
					"expected": expected,
					"physical": physical,
					"imported": imported,
					"selected": sources,
				})
				_check("%s %s %s directional routing flag" % [key, state, direction],
					directional, {"exact": exact, "directional": directional})
				_check("%s %s %s frame minimum" % [key, state, direction],
					enough_frames, {
						"actual": frames.size(), "required": REQUIRED_FRAMES[state]})
				_check("%s %s %s square-frame strip" % [key, state, direction],
					square_strip, texture_shape)
				_check("%s %s %s differs from idle" % [key, state, direction],
					idle_exact and changed, {
						"idle_exact": idle_exact, "has_non_idle_frame": changed})
				cells.append({
					"unit": key,
					"state": state,
					"direction": direction,
					"expected": expected,
					"physical": physical,
					"imported": imported,
					"selected_sources": sources,
					"exact": exact,
					"directional": directional,
					"frame_count": frames.size(),
					"required_frames": REQUIRED_FRAMES[state],
					"texture_size": texture_shape,
					"has_non_idle_frame": changed,
				})

	_finish()


func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var exact_cells := 0
	for cell in cells:
		if bool(cell.get("exact", false)) \
			and int(cell.get("frame_count", 0)) >= int(cell.get("required_frames", 999)) \
			and bool(cell.get("has_non_idle_frame", false)):
			exact_cells += 1
	var report := {
		"passed": failures.is_empty(),
		"automation": true,
		"human_visual_review": false,
		"scope": "Strict exact-source walk/attack/death contract for guan_dao, guan_gong, guan_jingqi and guan_qi across SE/SW/NE/NW.",
		"expected_cells": UNITS.size() * DIRECTIONS.size() * REQUIRED_FRAMES.size(),
		"accepted_cells": exact_cells,
		"requirements": REQUIRED_FRAMES,
		"checks": checks.size(),
		"failures": failures,
		"results": checks,
		"cells": cells,
		"fallback_is_failure": true,
		"excluded": ["human playtest", "performance acceptance", "Steam build or upload"],
		"steam_modified_or_exported": false,
	}
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	var wrote := file != null
	if wrote:
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
	print("SKIRMISH_TOP4_DIRECTION4_ACTIONS_RESULT ", JSON.stringify({
		"passed": failures.is_empty(),
		"accepted_cells": exact_cells,
		"expected_cells": report["expected_cells"],
		"failures": failures.size(),
		"report": REPORT,
		"report_written": wrote,
	}))
	for unused in range(3):
		await process_frame
	quit(0 if wrote and failures.is_empty() else 1)
