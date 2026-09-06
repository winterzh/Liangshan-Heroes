extends SceneTree
## Real-time automated lifecycle fixture for the production death renderer.
##
## Four real Unit nodes die once through take_damage() on the authored skirmish
## map. Unit physics, DeathRemains processing and WorldShadowBatch processing
## advance only through normal engine frames: this fixture never writes death
## clocks, remains age, reveal state, or elapsed deltas.

const OUT := "res://qa/skirmish_direction4_fix_20260905"
const REPORT := OUT + "/realtime_death_report.json"
const VIEW := Vector2i(1280, 720)
const KEYS := ["guan_dao", "guan_gong", "guan_jingqi", "guan_qi"]
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const SAMPLE_TARGETS := [0.0, 0.40, 0.75, 1.50]

var battle
var world_shadow_script
var overlay: CanvasLayer
var title_label: Label
var units := {}
var remains := {}
var initial := {}
var samples: Array[Dictionary] = []
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var pending_capture_images := {}
var start_usec := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[realtime-death] ", "PASS " if passed else "FAIL ", name,
		"" if detail == null else " :: " + JSON.stringify(detail))
	if not passed:
		failures.append(name)


func _elapsed() -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000000.0


func _wait_until(target: float) -> void:
	while _elapsed() < target:
		await process_frame


func _v2(value: Vector2) -> Array:
	return [snappedf(value.x, 0.001), snappedf(value.y, 0.001)]


func _instance_state(node: Variant) -> Dictionary:
	var valid := node != null and is_instance_valid(node)
	return {
		"valid": valid,
		"inside_tree": node.is_inside_tree() if valid else false,
		"queued_for_deletion": node.is_queued_for_deletion() if valid else false,
	}


func _sample(target: float) -> Dictionary:
	if target <= 0.0:
		# One ordinary frame lets Unit physics and the retained MultiMesh owner
		# publish their first post-lethal state. This is still the ~0 s sample.
		await process_frame
	else:
		await _wait_until(target)
	# SceneTree.process_frame is emitted before Node._process callbacks. Sample
	# only after this same frame was actually rendered so Unit physics, remains
	# processing, retained-shadow pruning, and deferred queue_free have all run.
	await RenderingServer.frame_post_draw
	var record := {
		"target_seconds": target,
		"actual_seconds": _elapsed(),
		"shadow": world_shadow_script.batch_summary(battle),
		"units": {},
	}
	for key in KEYS:
		var unit = units.get(key)
		var mark = remains.get(key)
		var unit_state := _instance_state(unit)
		var mark_state := _instance_state(mark)
		var row := {
			"unit": unit_state,
			"mark": mark_state,
			"in_live_battle_units": battle.units.has(unit) if unit_state.valid else false,
		}
		if unit_state.valid:
			row.unit.merge({
				"dying": bool(unit._dying),
				"death_t": float(unit._death_t),
				"flash": float(unit._flash),
				"hp": float(unit.hp),
				"position": _v2(unit.position),
				"render_height": float(unit.get_meta("render_height", 0.0)),
				"physics_processing": unit.is_physics_processing(),
			})
			row.unit["wall_minus_death_clock_seconds"] = \
				float(record.actual_seconds) - float(row.unit.death_t)
		if mark_state.valid:
			row.mark.merge({
				"age": float(mark.age),
				"remaining": float(mark.remaining),
				"revealed": bool(mark.is_revealed()),
				"reveal_alpha": float(mark.reveal_alpha()),
				"position": _v2(mark.position),
				"render_height": float(mark.get_meta("render_height", 0.0)),
				"processing": mark.is_processing(),
				"frame": int(mark.frame_index),
			})
			row.mark["wall_minus_mark_age_seconds"] = \
				float(record.actual_seconds) - float(row.mark.age)
		record.units[key] = row
	samples.append(record)
	print("[realtime-death] SAMPLE target=", target, " actual=", record.actual_seconds,
		" shadow=", JSON.stringify(record.shadow))
	return record


func _image_metrics(image: Image) -> Dictionary:
	var lit := 0
	var dark := 0
	var colored := 0
	# Sparse deterministic sampling proves the capture is an actual rendered map,
	# rather than a blank viewport, without turning this into a pixel benchmark.
	for y in range(0, image.get_height(), 12):
		for x in range(0, image.get_width(), 12):
			var c := image.get_pixel(x, y)
			var lum := (c.r + c.g + c.b) / 3.0
			if lum > 0.10:
				lit += 1
			else:
				dark += 1
			if maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)) > 0.08:
				colored += 1
	return {"sample_step_px": 12, "lit_samples": lit, "dark_samples": dark,
		"colored_samples": colored}


func _snapshot(file_name: String, label_text: String) -> void:
	title_label.text = label_text
	await process_frame
	await RenderingServer.frame_post_draw
	var render_elapsed := _elapsed()
	var image := root.get_texture().get_image()
	pending_capture_images[file_name] = image
	captures.append({
		"file": OUT.path_join(file_name),
		"render_elapsed_seconds": render_elapsed,
		"size": _v2(Vector2(image.get_size())) if image != null else [0, 0],
	})


func _save_captures() -> void:
	# PNG compression is intentionally after every lifecycle sample. It is a
	# blocking CPU operation and must not consume wall time between natural Unit
	# or DeathRemains observations.
	for index in captures.size():
		var record: Dictionary = captures[index]
		var file_name: String = String(record.file).get_file()
		var image: Image = pending_capture_images.get(file_name)
		var output := OUT.path_join(file_name)
		var save_error := image.save_png(output) if image != null else ERR_UNAVAILABLE
		var metrics := _image_metrics(image) if image != null else {}
		record.save_error = save_error
		record.sha256 = FileAccess.get_sha256(output) if save_error == OK else ""
		record.metrics = metrics
		captures[index] = record
		_check(file_name + " saved at 1280x720",
			save_error == OK and image != null and image.get_size() == VIEW, record)
		_check(file_name + " contains rendered map color",
			int(metrics.get("lit_samples", 0)) > 800 and int(metrics.get("colored_samples", 0)) > 500,
			metrics)
	pending_capture_images.clear()


func _central_open_cell() -> Vector2i:
	var best := Vector2i(battle.map.w / 2, battle.map.h / 2)
	var best_height := -INF
	# Keep a broad safety margin so the four horizontal isometric offsets and
	# the 1280x720 camera framing stay on authored terrain.
	for y in range(10, battle.map.h - 10):
		for x in range(10, battle.map.w - 10):
			var cell := Vector2i(x, y)
			if not battle.map.is_open_cell(cell, "land"):
				continue
			var height: float = battle.map.height_at(battle.map.cell_to_world(cell))
			if height > best_height:
				best_height = height
				best = cell
	return best


func _spawn_probe_units() -> bool:
	var center_cell := _central_open_cell()
	var offsets := [-6, -2, 2, 6]
	var occupied: Array[Vector2i] = []
	for index in KEYS.size():
		var desired := center_cell + Vector2i(offsets[index], -offsets[index])
		var cell: Vector2i = battle.map.nearest_open(desired, "land")
		if cell.x < 0 or cell in occupied:
			_check("unique open spawn cell for " + KEYS[index], false,
				{"center": _v2(center_cell), "desired": _v2(desired), "actual": _v2(cell)})
			return false
		occupied.append(cell)
		var world_position: Vector2 = battle.map.cell_to_world(cell)
		var unit = battle.spawn_unit(KEYS[index], 1, world_position)
		if unit == null:
			_check("spawn real Unit " + KEYS[index], false, {"cell": _v2(cell)})
			return false
		unit.animation_direction = DIRECTIONS[index]
		unit._direction_candidate = DIRECTIONS[index]
		unit._direction_votes = 4
		unit.face_left = DIRECTIONS[index] in ["sw", "nw"]
		unit.stance = unit.STANCE_PASSIVE
		unit.passive = true
		unit.fog_visible = true
		unit.visible = true
		unit.z_index = clampi(1 + int(battle.to_screen(unit.position).y), 1, 3400)
		battle.map.sync_render_position(unit)
		unit.queue_redraw()
		units[KEYS[index]] = unit
		initial[KEYS[index]] = {
			"cell": _v2(cell),
			"position": _v2(unit.position),
			"render_height": float(unit.get_meta("render_height", 0.0)),
			"direction": DIRECTIONS[index],
		}
	battle.camera.position = battle.to_screen(battle.map.cell_to_world(center_cell))
	battle.camera.zoom = Vector2.ONE * 1.25
	battle.camera.force_update_scroll()
	await process_frame
	await process_frame
	for key in KEYS:
		var unit = units[key]
		battle.map.sync_render_position(unit)
		initial[key].position = _v2(unit.position)
		initial[key].render_height = float(unit.get_meta("render_height", 0.0))
		_check(key + " uses natural physics before death", unit.is_physics_processing(),
			{"process_mode": unit.process_mode, "physics_processing": unit.is_physics_processing()})
	return true


func _kill_once_each() -> bool:
	for key in KEYS:
		var unit = units[key]
		var count_before: int = battle._death_remains.size()
		unit.take_damage(unit.hp + 1.0)
		var count_after: int = battle._death_remains.size()
		if count_after != count_before + 1:
			_check(key + " creates one independent remains node", false,
				{"before": count_before, "after": count_after})
			return false
		var mark = battle._death_remains.back()
		remains[key] = mark
		initial[key].mark_position = _v2(mark.position)
		initial[key].mark_render_height = float(mark.get_meta("render_height", 0.0))
		_check(key + " lethal event removes live combat registry", not battle.units.has(unit),
			{"hp": unit.hp, "dying": unit._dying})
		_check(key + " remains uses natural processing", mark.is_processing(),
			{"process_mode": mark.process_mode, "age": mark.age})
	return true


func _row(sample: Dictionary, key: String) -> Dictionary:
	return sample.units.get(key, {})


func _all_sample(sample: Dictionary, predicate: Callable) -> bool:
	for key in KEYS:
		if not predicate.call(_row(sample, key), key):
			return false
	return true


func _validate_samples(zero: Dictionary, at_040: Dictionary, at_075: Dictionary,
		at_150: Dictionary) -> void:
	for sample in [zero, at_040, at_075]:
		var label := "%.2f" % float(sample.target_seconds)
		_check(label + " bodies remain render nodes but not live combat units",
			_all_sample(sample, func(row: Dictionary, _key: String) -> bool:
				return bool(row.unit.get("valid", false)) and bool(row.unit.get("dying", false)) \
					and not bool(row.get("in_live_battle_units", true))), sample.units)
		_check(label + " four retained shadows remain visible",
			int(sample.shadow.get("retained_dying_units", -1)) == 4 \
				and int(sample.shadow.get("retained_dying_visible", -1)) == 4,
			sample.shadow)

	_check("0.40 lethal flash naturally decays to zero",
		_all_sample(at_040, func(row: Dictionary, _key: String) -> bool:
			return float(row.unit.get("flash", 99.0)) <= 0.001), at_040.units)
	_check("0.40 remains naturally entered short reveal ramp",
		_all_sample(at_040, func(row: Dictionary, _key: String) -> bool:
			var age := float(row.mark.get("age", -1.0))
			var alpha := float(row.mark.get("reveal_alpha", -1.0))
			return bool(row.mark.get("revealed", false)) and age >= 0.35 \
				and alpha > 0.0 and alpha < 0.80), at_040.units)
	_check("0.75 remains naturally reached full reveal",
		_all_sample(at_075, func(row: Dictionary, _key: String) -> bool:
			return bool(row.mark.get("revealed", false)) \
				and float(row.mark.get("reveal_alpha", -1.0)) >= 0.999), at_075.units)

	for sample in [zero, at_040, at_075]:
		var target := float(sample.target_seconds)
		_check("%.2f death clock follows real elapsed frames" % target,
			_all_sample(sample, func(row: Dictionary, _key: String) -> bool:
				var clock := float(row.unit.get("death_t", -9.0))
				return clock >= 0.0 and absf(clock - float(sample.actual_seconds)) <= 0.16),
			{"actual_seconds": sample.actual_seconds, "units": sample.units})

	for sample in [zero, at_040, at_075, at_150]:
		for key in KEYS:
			var row := _row(sample, key)
			if bool(row.unit.get("valid", false)):
				_check("%s @ %.2f body position/height stable" % [key, float(sample.target_seconds)],
					row.unit.get("position", []) == initial[key].position \
						and is_equal_approx(float(row.unit.get("render_height", -999.0)),
							float(initial[key].render_height)),
					{"initial": initial[key], "actual": row.unit})
			if bool(row.mark.get("valid", false)):
				_check("%s @ %.2f remains position/height stable" % [key, float(sample.target_seconds)],
					row.mark.get("position", []) == initial[key].mark_position \
						and is_equal_approx(float(row.mark.get("render_height", -999.0)),
							float(initial[key].mark_render_height)),
					{"initial": initial[key], "actual": row.mark})

	_check("1.50 bodies naturally freed and remain absent from combat registry",
		_all_sample(at_150, func(row: Dictionary, _key: String) -> bool:
			return not bool(row.unit.get("valid", true)) \
				and not bool(row.get("in_live_battle_units", true))), at_150.units)
	_check("1.50 retained death shadows naturally pruned",
		int(at_150.shadow.get("retained_dying_units", -1)) == 0 \
			and int(at_150.shadow.get("retained_dying_visible", -1)) == 0,
		at_150.shadow)
	_check("1.50 long-lived remains persist through body release",
		_all_sample(at_150, func(row: Dictionary, _key: String) -> bool:
			return bool(row.mark.get("valid", false)) and bool(row.mark.get("revealed", false)) \
				and float(row.mark.get("age", 0.0)) >= 1.30 \
				and float(row.mark.get("remaining", 0.0)) > 40.0), at_150.units)


func _make_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 100
	root.add_child(overlay)
	var bar := ColorRect.new()
	bar.position = Vector2(0, 0)
	bar.size = Vector2(VIEW.x, 52)
	bar.color = Color(0.03, 0.035, 0.04, 0.86)
	overlay.add_child(bar)
	title_label = Label.new()
	title_label.position = Vector2(0, 6)
	title_label.size = Vector2(VIEW.x, 34)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	overlay.add_child(title_label)
	for index in KEYS.size():
		var label := Label.new()
		label.text = "%s  %s" % [KEYS[index], DIRECTIONS[index].to_upper()]
		label.position = Vector2(index * 320.0, 56.0)
		label.size = Vector2(320.0, 28.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
		overlay.add_child(label)


func _write_report() -> void:
	var sources := {}
	for path in ["res://scripts/battle.gd", "res://scripts/unit.gd", "res://scripts/art_db.gd",
			"res://scripts/world_shadow.gd", OUT + "/realtime_death_probe.gd"]:
		sources[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	var report := {
		"schema_version": 1,
		"kind": "skirmish_realtime_death_lifecycle_probe",
		"status": "PASS" if failures.is_empty() else "FAIL",
		"scope": "Real-time automated fixture on the actual 1280x720 skirmish map; not a human playtest, not a 30-wave completion, and not a performance soak.",
		"renderer": DisplayServer.get_name(),
		"rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method", ""),
		"viewport": [VIEW.x, VIEW.y],
		"manual_time_mutation": false,
		"manual_unit_physics_calls": false,
		"manual_remains_process_calls": false,
		"timing_domains": "actual_seconds is monotonic wall time; death_t is natural physics time; mark.age is natural idle-process time. Samples are taken after frame_post_draw.",
		"human_playtest": false,
		"thirty_wave_completion": false,
		"performance_test": false,
		"battle_main_loop_frozen": true,
		"unrelated_units_frozen": true,
		"actual_map_and_scenery_retained": true,
		"sample_targets_seconds": SAMPLE_TARGETS,
		"initial": initial,
		"samples": samples,
		"captures": captures,
		"checks": checks,
		"failures": failures,
		"source_hashes": sources,
	}
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file == null:
		failures.append("write realtime report")
		push_error("Unable to write " + REPORT)
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("[realtime-death] RESULT ", "PASS" if failures.is_empty() else "FAIL",
		" checks=", checks.size(), " failures=", failures.size(), " report=", REPORT)


func _cleanup() -> void:
	current_scene = null
	if is_instance_valid(battle):
		battle.queue_free()
	if is_instance_valid(overlay):
		overlay.queue_free()
	await process_frame
	await process_frame


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This visual lifecycle probe requires a graphical renderer")
		quit(2)
		return
	OS.set_environment("CAMPAIGN_QA", "1")
	# Load singleton-dependent production scripts only after the project
	# autoloads exist. A top-level preload runs before Art is registered when a
	# SceneTree script is the command-line entry point.
	await process_frame
	world_shadow_script = load("res://scripts/world_shadow.gd")
	if world_shadow_script == null or not world_shadow_script.can_instantiate():
		push_error("Unable to load the production WorldShadow script")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = VIEW
	root.content_scale_size = VIEW
	AudioServer.set_bus_mute(0, true)
	Engine.time_scale = 1.0
	var settings = root.get_node("Settings")
	settings.edge_scroll = false
	settings.auto_micro_level = 0
	settings.game_speed = 1.0
	settings.show_damage = false
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(mode, false)
	campaign.skirmish = true
	campaign.defense_waves = 1
	campaign.defense_random = false

	battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	if battle.hud != null:
		battle.hud.hide()
	if battle.phase == battle.Phase.INTRO:
		battle._on_intro_done()
	battle.phase = battle.Phase.DEPLOY
	# Only the coordinator and camera are frozen. Child Unit physics, authored
	# scenery, DeathRemains and WorldShadowBatch retain ordinary process modes.
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.camera.set_process(false)
	battle.camera.set_physics_process(false)
	battle.fog = false
	if battle._fog_layer != null:
		battle._fog_layer.hide()
	for existing in battle.units.duplicate():
		if existing != null and is_instance_valid(existing):
			existing.hide()
			existing.set_process(false)
			existing.set_physics_process(false)
	_make_overlay()

	if not await _spawn_probe_units():
		_write_report()
		await _cleanup()
		quit(1)
		return
	if not _kill_once_each():
		_write_report()
		await _cleanup()
		quit(1)
		return
	start_usec = Time.get_ticks_usec()
	var zero := await _sample(0.0)
	var at_040 := await _sample(0.40)
	var at_075 := await _sample(0.75)
	await _snapshot("realtime_death_075.png",
		"REAL-TIME 0.75 s | same four victims | bodies + full remains + fading shadows")
	var at_150 := await _sample(1.50)
	await _snapshot("realtime_death_150.png",
		"REAL-TIME 1.50 s | bodies naturally freed | persistent ground remains")
	_save_captures()
	_validate_samples(zero, at_040, at_075, at_150)
	_write_report()
	var exit_code := 0 if failures.is_empty() else 1
	await _cleanup()
	quit(exit_code)
