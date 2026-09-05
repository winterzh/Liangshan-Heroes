extends SceneTree
## Graphical QA matrix for the same strict contract as
## skirmish_top4_direction4_actions_test.gd.  Exact strips render every frame;
## missing/legacy/idle fallback renders a red diagnostic cell instead, so the
## screenshot cannot accidentally present fallback art as accepted production.

const VIEW_SIZE := Vector2i(1920, 1080)
const UNITS := ["guan_dao", "guan_gong", "guan_jingqi", "guan_qi"]
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const STATES := ["walk", "attack", "death"]
const REQUIRED_FRAMES := {"walk": 2, "attack": 3, "death": 4}
const OUTPUT_DIR := "res://qa/skirmish_direction4_actions_20260905/runtime_visual"
const PNG_PATH := OUTPUT_DIR + "/action_matrix_1920x1080.png"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const LEFT_WIDTH := 220.0
const TOP_HEIGHT := 98.0
const ROW_HEIGHT := 81.0
const COLUMN_WIDTH := 425.0

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var cells: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[skirmish-top4-actions-visual] ", "PASS " if passed else "FAIL ", name,
		"" if detail == null else " :: " + JSON.stringify(detail))
	if not passed:
		failures.append(name)


func _expected(key: String, state: String, direction: String) -> String:
	return "res://assets/anim/%s_%s_%s.png" % [key, state, direction]


func _source(frame: Variant) -> String:
	if frame is AtlasTexture and frame.atlas != null:
		return frame.atlas.resource_path
	return frame.resource_path if frame != null else ""


func _all_exact(frames: Array, expected: String) -> bool:
	if frames.is_empty():
		return false
	for frame in frames:
		if _source(frame) != expected:
			return false
	return true


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
		return atlas_image.get_region(Rect2i(
			int(round(region.position.x)), int(round(region.position.y)),
			int(round(region.size.x)), int(round(region.size.y))))
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
	left_image.convert(Image.FORMAT_RGBA8)
	right_image.convert(Image.FORMAT_RGBA8)
	return left_image.get_data() == right_image.get_data()


func _has_non_idle(frames: Array, idle_frames: Array) -> bool:
	if frames.is_empty() or idle_frames.is_empty():
		return false
	for frame in frames:
		if not _same_pixels(frame, idle_frames[0]):
			return true
	return false


func _label(parent: Node, text: String, rect: Rect2, font_size: int,
		color := Color("e8dfc5"), align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _rect(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var panel := ColorRect.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.color = color
	parent.add_child(panel)
	return panel


func _draw_exact_cell(layer: CanvasLayer, frames: Array, cell_rect: Rect2,
		frame_count: int, distinct: bool) -> void:
	var frame_size := 64.0
	var spacing := 9.0
	var visible_count := mini(frames.size(), 4)
	var strip_width := visible_count * frame_size + maxi(0, visible_count - 1) * spacing
	var start_x := cell_rect.position.x + 14.0
	if strip_width < 310.0:
		start_x += (310.0 - strip_width) * 0.5
	for index in visible_count:
		var frame_bg := Rect2(start_x + index * (frame_size + spacing),
			cell_rect.position.y + 8.0, frame_size, frame_size)
		_rect(layer, frame_bg, Color("31404a") if index % 2 == 0 else Color("3a4650"))
		var texture_rect := TextureRect.new()
		texture_rect.position = frame_bg.position
		texture_rect.size = frame_bg.size
		texture_rect.texture = frames[index]
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		layer.add_child(texture_rect)
	var badge_color := Color("79df95") if distinct else Color("ff7f73")
	_label(layer, "%dF\n%s" % [frame_count, "CHANGED" if distinct else "IDLE COPY"],
		Rect2(cell_rect.end.x - 91.0, cell_rect.position.y + 10.0, 82.0, 54.0),
		12, badge_color)


func _draw_failure_cell(layer: CanvasLayer, cell_rect: Rect2, label_text: String,
		selected: String) -> void:
	_rect(layer, cell_rect.grow(-6.0), Color(0.24, 0.055, 0.055, 0.95))
	_label(layer, label_text,
		Rect2(cell_rect.position.x + 10.0, cell_rect.position.y + 6.0,
			cell_rect.size.x - 20.0, 28.0), 18, Color("ff8b7c"))
	_label(layer, selected.get_file() if not selected.is_empty() else "NO FRAMES",
		Rect2(cell_rect.position.x + 10.0, cell_rect.position.y + 35.0,
			cell_rect.size.x - 20.0, 31.0), 12, Color("ffc4bc"))


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("skirmish_top4_direction4_actions_visual_test requires a graphical renderer")
		quit(2)
		return
	AudioServer.set_bus_mute(0, true)
	root.mode = Window.MODE_WINDOWED
	root.size = VIEW_SIZE
	root.content_scale_size = VIEW_SIZE
	DisplayServer.window_set_size(VIEW_SIZE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var art := root.get_node_or_null("Art")
	_check("Art autoload available", art != null)
	if art == null:
		_finish(null)
		return

	var layer := CanvasLayer.new()
	root.add_child(layer)
	_rect(layer, Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color("10161c"))
	_rect(layer, Rect2(0, 0, VIEW_SIZE.x, 50), Color("1d2a33"))
	_label(layer, "LIANGSHAN DEFENSE · OFFICIAL TOP-4 · EXACT FOUR-DIRECTION ACTION MATRIX",
		Rect2(0, 1, VIEW_SIZE.x, 40), 23, Color("f2d17a"))
	_label(layer, "row = unit/state · each accepted cell shows every production frame · red = missing or fallback",
		Rect2(0, 40, VIEW_SIZE.x, 25), 15, Color("aebdca"))
	_rect(layer, Rect2(0, 66, VIEW_SIZE.x, 2), Color("8b713e"))

	for column in DIRECTIONS.size():
		_label(layer, DIRECTIONS[column].to_upper(),
			Rect2(LEFT_WIDTH + column * COLUMN_WIDTH, 67, COLUMN_WIDTH, 29),
			18, Color("8fd1f5"))

	var row_index := 0
	for key in UNITS:
		for state in STATES:
			var y := TOP_HEIGHT + row_index * ROW_HEIGHT
			var row_color := Color("172129") if row_index % 2 == 0 else Color("131c23")
			_rect(layer, Rect2(0, y, VIEW_SIZE.x, ROW_HEIGHT), row_color)
			_label(layer, "%s\n%s" % [key, state.to_upper()],
				Rect2(12, y + 4, LEFT_WIDTH - 24, ROW_HEIGHT - 8), 17,
				Color("e8dfc5"), HORIZONTAL_ALIGNMENT_LEFT)
			for column in DIRECTIONS.size():
				var direction: String = DIRECTIONS[column]
				var expected := _expected(key, state, direction)
				var frames: Array = art.unit_anim_frames(key, state, direction, "")
				var selected := _source(frames[0]) if not frames.is_empty() else ""
				var exact := FileAccess.file_exists(expected) \
					and ResourceLoader.exists(expected) \
					and _all_exact(frames, expected) \
					and bool(art.unit_anim_uses_directional_source(key, state, direction, ""))
				var enough := frames.size() >= int(REQUIRED_FRAMES[state])
				var idle_frames: Array = art.unit_anim_frames(key, "idle", direction, "")
				var distinct := _has_non_idle(frames, idle_frames)
				var accepted := exact and enough and distinct
				var cell_rect := Rect2(LEFT_WIDTH + column * COLUMN_WIDTH, y,
					COLUMN_WIDTH, ROW_HEIGHT)
				_rect(layer, Rect2(cell_rect.position.x, cell_rect.position.y,
					1, cell_rect.size.y), Color("33444f"))
				if accepted:
					_draw_exact_cell(layer, frames, cell_rect, frames.size(), distinct)
				else:
					var issue := "MISSING / FALLBACK"
					if exact and not enough:
						issue = "TOO FEW FRAMES %d/%d" % [frames.size(), REQUIRED_FRAMES[state]]
					elif exact and enough and not distinct:
						issue = "ALL FRAMES = IDLE"
					_draw_failure_cell(layer, cell_rect, issue, selected)
				_check("%s %s %s accepted visual cell" % [key, state, direction], accepted, {
					"expected": expected,
					"selected": selected,
					"exact": exact,
					"frames": frames.size(),
					"required": REQUIRED_FRAMES[state],
					"distinct_from_idle": distinct,
				})
				cells.append({
					"unit": key, "state": state, "direction": direction,
					"expected": expected, "selected": selected,
					"exact": exact, "frame_count": frames.size(),
					"required_frames": REQUIRED_FRAMES[state],
					"distinct_from_idle": distinct, "accepted": accepted,
				})
			row_index += 1

	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var correct_size := image != null and not image.is_empty() and image.get_size() == VIEW_SIZE
	var save_error := image.save_png(ProjectSettings.globalize_path(PNG_PATH)) if correct_size else ERR_CANT_CREATE
	_check("1920x1080 matrix capture written", correct_size and save_error == OK \
		and FileAccess.file_exists(PNG_PATH), {
			"path": PNG_PATH, "size": image.get_size() if image != null else Vector2i.ZERO,
			"error": save_error,
		})
	_finish(layer)


func _finish(layer: CanvasLayer) -> void:
	var accepted := 0
	for cell in cells:
		if bool(cell.get("accepted", false)):
			accepted += 1
	var report := {
		"passed": failures.is_empty(),
		"automation": true,
		"human_visual_review": false,
		"viewport": [VIEW_SIZE.x, VIEW_SIZE.y],
		"capture": PNG_PATH,
		"capture_sha256": FileAccess.get_sha256(PNG_PATH) if FileAccess.file_exists(PNG_PATH) else "",
		"renderer": RenderingServer.get_video_adapter_name(),
		"expected_cells": UNITS.size() * DIRECTIONS.size() * STATES.size(),
		"accepted_cells": accepted,
		"checks": checks.size(),
		"failures": failures,
		"results": checks,
		"cells": cells,
		"scope": "Graphical exact-source frame matrix for four official units x walk/attack/death x SE/SW/NE/NW.",
		"fallback_is_rendered_as_failure_not_art": true,
		"excluded": ["human visual approval", "gameplay", "performance acceptance", "Steam build or upload"],
		"steam_modified_or_exported": false,
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	var wrote := file != null
	if wrote:
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
	print("SKIRMISH_TOP4_DIRECTION4_ACTIONS_VISUAL_RESULT ", JSON.stringify({
		"passed": failures.is_empty(),
		"accepted_cells": accepted,
		"expected_cells": report["expected_cells"],
		"capture": PNG_PATH,
		"report": REPORT_PATH,
		"report_written": wrote,
	}))
	if is_instance_valid(layer):
		layer.queue_free()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	quit(0 if wrote and failures.is_empty() else 1)
