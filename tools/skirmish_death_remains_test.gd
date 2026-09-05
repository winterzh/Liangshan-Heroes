extends SceneTree
## Focused contract for the 2026-09-04 skirmish death-remains cleanup.
## It exercises the real Battle helpers and production atlas. A graphical run
## additionally saves one 1280x720 review frame; neither run is a playthrough.

const OUTPUT := "res://qa/skirmish_direction4_fix_20260905"
const VIEW := Vector2i(1280, 720)

var failures: Array[String] = []
var checks: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String, detail: Dictionary = {}) -> void:
	print("[skirmish-death-remains] ", "PASS " if ok else "FAIL ", label)
	checks.append({"name": label, "passed": ok, "detail": detail})
	if not ok:
		failures.append(label)


func _probe(b, key: String, pos: Vector2):
	# Avoid resolving the Unit global class while this SceneTree script itself is
	# compiling. The project autoloads (including Sfx, used by Unit) are ready by
	# the time the real battle scene creates the probe.
	var u = b.spawn_unit(key, 1, pos)
	if u != null:
		u.set_process(false)
		u.set_physics_process(false)
		u.visible = false
	return u


func _frames_for(b, u) -> Array[int]:
	var frames: Array[int] = []
	for seed in range(60):
		frames.append(int(b._death_remains_frame_for(u, seed)))
	return frames


func _image_has_scene_content(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var lit_samples := 0
	for y in range(12, image.get_height(), 24):
		for x in range(12, image.get_width(), 24):
			var color := image.get_pixel(x, y)
			if maxf(color.r, maxf(color.g, color.b)) > 0.035:
				lit_samples += 1
				if lit_samples >= 24:
					return true
	return false


func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	AudioServer.set_bus_mute(0, true)
	var graphical := DisplayServer.get_name() != "headless"
	if graphical:
		root.mode = Window.MODE_WINDOWED
		root.size = VIEW
		root.content_scale_size = VIEW
		root.title = "Liangshan skirmish death-remains QA"

	var settings = root.get_node("Settings")
	settings.edge_scroll = false
	settings.auto_micro_level = 0
	settings.game_speed = 1.0
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(mode, false)
	campaign.skirmish = true
	campaign.defense_waves = 1
	campaign.defense_random = false

	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	_check(b.phase == b.Phase.FIGHT, "real skirmish reaches the playable fight phase")
	b.set_process(false)
	b.set_physics_process(false)
	for existing in b.units:
		if is_instance_valid(existing):
			existing.set_process(false)
			existing.set_physics_process(false)

	var base_cell: Vector2i = b.map.nearest_open(Vector2i(23, 35), "land")
	var base: Vector2 = b.map.cell_to_world(base_cell)
	var probes := {
		"ranged": _probe(b, "guan_gong", base + Vector2(-260, -180)),
		"spear": _probe(b, "liang_qiang", base + Vector2(-220, -180)),
		"armored": _probe(b, "guan_dao", base + Vector2(-180, -180)),
		"cavalry": _probe(b, "guan_qi", base + Vector2(-140, -180)),
		"common": _probe(b, "lou_luo", base + Vector2(-100, -180)),
		"camel": _probe(b, "camel_rider", base + Vector2(-60, -180)),
		"elephant": _probe(b, "war_elephant", base + Vector2(-20, -180)),
	}
	_check(probes.values().all(func(u): return u != null), "semantic probe units use real production definitions")

	var ranged_frames := _frames_for(b, probes.ranged)
	var spear_frames := _frames_for(b, probes.spear)
	var armored_frames := _frames_for(b, probes.armored)
	var cavalry_frames := _frames_for(b, probes.cavalry)
	var common_frames := _frames_for(b, probes.common)
	var camel_frames := _frames_for(b, probes.camel)
	var elephant_frames := _frames_for(b, probes.elephant)
	_check(ranged_frames.count(0) == 50 and ranged_frames.count(3) == 10,
		"ranged deaths are mostly blood with rare shield-arrow debris")
	_check(spear_frames.count(0) == 50 and spear_frames.count(1) == 10,
		"spear deaths are mostly blood with rare broken-spears")
	_check(armored_frames.count(0) == 50 and armored_frames.count(2) == 10,
		"armored infantry is mostly blood with rare armor debris")
	_check(cavalry_frames.count(0) == 50 and cavalry_frames.count(1) == 10,
		"spear cavalry is mostly blood with rare matching broken-spears")
	_check(common_frames.count(0) == 50 and common_frames.count(5) == 10,
		"ordinary light troops are mostly blood with rare cloth debris")
	_check(camel_frames.all(func(frame): return frame == 0)
		and elephant_frames.all(func(frame): return frame == 0),
		"camels and elephants drop only the compact blood trace")
	var all_semantic: Array = ranged_frames + spear_frames + armored_frames \
		+ cavalry_frames + common_frames + camel_frames + elephant_frames
	_check(6 not in all_semantic and all_semantic.all(func(frame): return frame in b.DEATH_REMAINS_SAFE_FRAMES),
		"ordinary production selection never emits the fallen banner or bone cells")
	var infantry_trace = b._spawn_death_remains(probes.armored)
	var cavalry_trace = b._spawn_death_remains(probes.cavalry)
	if infantry_trace != null:
		infantry_trace.process_mode = Node.PROCESS_MODE_DISABLED
	if cavalry_trace != null:
		cavalry_trace.process_mode = Node.PROCESS_MODE_DISABLED
	_check(infantry_trace != null and cavalry_trace != null \
		and infantry_trace.frame_texture != null and cavalry_trace.frame_texture != null \
		and infantry_trace.frame_index in b.DEATH_REMAINS_SAFE_FRAMES \
		and cavalry_trace.frame_index in b.DEATH_REMAINS_SAFE_FRAMES \
		and is_equal_approx(infantry_trace.visual_size, clampf(probes.armored.radius * 5.2, 48.0, 78.0)) \
		and is_equal_approx(cavalry_trace.visual_size, clampf(probes.cavalry.radius * 5.2, 48.0, 78.0)) \
		and cavalry_trace.visual_size > infantry_trace.visual_size,
		"infantry and cavalry both use the restrained atlas with radius-calibrated traces")

	var story_probe = _probe(b, "guan_dao", base + Vector2(0, -180))
	story_probe.story_outcome = "captured"
	var summon_probe = _probe(b, "guan_dao", base + Vector2(40, -180))
	summon_probe.is_summon = true
	var water_probe = _probe(b, "guan_dao", base + Vector2(80, -180))
	water_probe.movement_profile = "water"
	var siege_probe = _probe(b, "siege_cata", base + Vector2(120, -180))
	_check(b._unit_leaves_death_remains(probes.common)
		and not b._unit_leaves_death_remains(story_probe)
		and not b._unit_leaves_death_remains(summon_probe)
		and not b._unit_leaves_death_remains(water_probe)
		and not b._unit_leaves_death_remains(siege_probe)
		and not b._unit_leaves_death_remains(b.level.hall),
		"non-character, story, summon, water and building deaths leave no human remains")

	var direction_marks: Array = []
	var direction_origins := [
		base + Vector2(-96, -72), base + Vector2(0, -72),
		base + Vector2(-96, 72), base + Vector2(0, 72),
	]
	var direction_index := 0
	var direction_ok := true
	for direction in ["se", "sw", "ne", "nw"]:
		var u = _probe(b, "guan_dao", direction_origins[direction_index])
		direction_index += 1
		u.animation_direction = direction
		u.hp = 0.0
		var mark = b._spawn_death_remains(u)
		direction_ok = direction_ok and mark != null \
			and String(mark.captured_direction) == direction \
			and mark.fall_offset.is_zero_approx() \
			and mark.position.is_equal_approx(u.position) \
			and mark.frame_scale > 0.0
		if mark != null:
			mark.process_mode = Node.PROCESS_MODE_DISABLED
			direction_marks.append(mark)
	_check(direction_ok and direction_marks.size() == 4,
		"all four directions retain provenance while traces stay on the logical foot point")

	var delay_mark = direction_marks[0]
	var delay_ok: bool = not delay_mark.is_revealed() \
		and is_equal_approx(delay_mark.reveal_delay, b.DEATH_REMAINS_REVEAL_DELAY) \
		and is_equal_approx(delay_mark.reveal_fade_duration, b.DEATH_REMAINS_REVEAL_FADE) \
		and is_zero_approx(delay_mark.reveal_alpha())
	delay_mark._process(0.34)
	delay_ok = delay_ok and not delay_mark.is_revealed() and is_zero_approx(delay_mark.reveal_alpha())
	delay_mark._process(0.02)
	var ramp_alpha: float = delay_mark.reveal_alpha()
	delay_ok = delay_ok and delay_mark.is_revealed() and ramp_alpha > 0.0 and ramp_alpha < 0.2
	delay_mark._process(b.DEATH_REMAINS_REVEAL_FADE)
	delay_ok = delay_ok and is_equal_approx(delay_mark.reveal_alpha(), 1.0)
	_check(delay_ok, "mark stays hidden for 0.35 seconds then fades in over a short bounded ramp",
		{"ramp_alpha_at_036": ramp_alpha, "fade_duration": delay_mark.reveal_fade_duration})

	# A four-frame death strip spends the first quarter of DEATH_DUR on its
	# upright impact frame. The ground trace must become visible only when that
	# first frame has finished, while the dying Unit is still present to play the
	# remaining fall/down frames. Once the Unit is freed, the independent trace
	# must remain alive. This guards the signal ordering used by real lethal hits,
	# not only direct helper calls.
	var unit_script := load("res://scripts/unit.gd") as Script
	var unit_constants: Dictionary = unit_script.get_script_constant_map() if unit_script != null else {}
	var death_duration := float(unit_constants.get("DEATH_DUR", 0.0))
	_check(death_duration > 0.0 \
		and is_equal_approx(b.DEATH_REMAINS_REVEAL_DELAY, death_duration / 4.0),
		"blood reveal matches the first-frame boundary of a four-frame death strip",
		{"death_duration": death_duration, "reveal_delay": b.DEATH_REMAINS_REVEAL_DELAY})
	var lifecycle_origin := base
	var lifecycle_origin_found := false
	for cy in range(2, b.map.h - 2):
		if lifecycle_origin_found:
			break
		for cx in range(2, b.map.w - 2):
			var candidate: Vector2 = b.map.cell_to_world(Vector2i(cx, cy))
			if not b.map.is_open_world(candidate, "land"):
				continue
			var clear_of_marks := true
			for existing_mark in b._death_remains:
				if is_instance_valid(existing_mark) \
						and existing_mark.position.distance_to(candidate) <= b.DEATH_REMAINS_MERGE_DISTANCE + 24.0:
					clear_of_marks = false
					break
			if clear_of_marks:
				lifecycle_origin = candidate
				lifecycle_origin_found = true
				break
	var lifecycle_victim = _probe(b, "guan_dao", lifecycle_origin)
	lifecycle_victim.visible = true
	lifecycle_victim.animation_direction = "nw"
	var shadow_module = load("res://scripts/world_shadow.gd")
	var shadow_batch = b.world.get_node_or_null(String(shadow_module.BATCH_NODE_NAME))
	if shadow_batch != null:
		shadow_batch._update_visible_units()
	var shadow_baseline: Dictionary = shadow_module.batch_summary(b)
	var lifecycle_mark_count: int = b._death_remains.size()
	var saved_phase = b.phase
	b.phase = b.Phase.DEPLOY # keep this focused death from advancing the wave fixture
	lifecycle_victim.take_damage(lifecycle_victim.hp + 1.0)
	b.phase = saved_phase
	var lifecycle_mark = b._death_remains[-1] if b._death_remains.size() > lifecycle_mark_count else null
	if lifecycle_mark != null:
		lifecycle_mark.process_mode = Node.PROCESS_MODE_DISABLED
	var lethal_signal_ok: bool = lifecycle_mark != null \
		and lifecycle_victim._dying and lifecycle_victim.hp <= 0.0 \
		and lifecycle_victim not in b.units and not lifecycle_mark.is_revealed() \
		and String(lifecycle_mark.captured_direction) == "nw"
	_check(lethal_signal_ok,
		"a real lethal signal captures direction and creates one initially hidden trace")
	if shadow_batch != null:
		shadow_batch._update_visible_units()
	var shadow_start: Dictionary = shadow_module.batch_summary(b)
	var shadow_start_opacity: float = shadow_module._unit_opacity(
		lifecycle_victim, shadow_module._death_fraction(lifecycle_victim))
	_check(lifecycle_victim not in b.units \
		and int(shadow_start.get("retained_dying_units", 0)) == 1 \
		and int(shadow_start.get("retained_dying_visible", 0)) == 1 \
		and int(shadow_start.get("contact_instances", 0)) == int(shadow_baseline.get("contact_instances", -1)) \
		and absf(shadow_start_opacity - 1.0) < 0.01,
		"death shadow stays in the render-only batch without rejoining combat units",
		{"baseline": shadow_baseline, "after_death": shadow_start,
			"retained_opacity": shadow_start_opacity})
	if lifecycle_mark != null and death_duration > 0.0:
		var before_boundary := maxf(0.001, b.DEATH_REMAINS_REVEAL_DELAY - 0.01)
		lifecycle_victim._phys_body(before_boundary)
		lifecycle_mark._process(before_boundary)
		var before_boundary_ok: bool = is_instance_valid(lifecycle_victim) \
			and lifecycle_victim._dying and not lifecycle_mark.is_revealed()
		lifecycle_victim._phys_body(0.02)
		lifecycle_mark._process(0.02)
		var after_boundary_ok: bool = is_instance_valid(lifecycle_victim) \
			and lifecycle_victim._dying and lifecycle_mark.is_revealed() \
			and lifecycle_mark.reveal_alpha() > 0.0 and lifecycle_mark.reveal_alpha() < 1.0
		_check(before_boundary_ok and after_boundary_ok,
			"trace begins its fade-in after frame one while the remaining death frames still play")
		if shadow_batch != null:
			shadow_batch._update_visible_units()
		var shadow_mid: Dictionary = shadow_module.batch_summary(b)
		var death_fraction: float = shadow_module._death_fraction(lifecycle_victim)
		var shadow_mid_opacity: float = shadow_module._unit_opacity(lifecycle_victim, death_fraction)
		_check(int(shadow_mid.get("retained_dying_visible", 0)) == 1 \
			and death_fraction > 0.0 and death_fraction < 1.0 \
			and absf(shadow_mid_opacity - (1.0 - death_fraction)) < 0.01,
			"render-only death shadow remains submitted while its opacity progresses",
			{"death_fraction": death_fraction, "retained_opacity": shadow_mid_opacity,
				"batch": shadow_mid})
		var elapsed := before_boundary + 0.02
		lifecycle_victim._phys_body(maxf(0.0, death_duration - elapsed - 0.01))
		if shadow_batch != null:
			shadow_batch._update_visible_units()
		var shadow_pre_free: Dictionary = shadow_module.batch_summary(b)
		_check(int(shadow_pre_free.get("retained_dying_visible", 0)) == 1 \
			and shadow_module._death_fraction(lifecycle_victim) > 0.99,
			"death shadow remains submitted until the final instant of the death strip",
			shadow_pre_free)
		lifecycle_victim._phys_body(0.02)
		var queued_after_strip: bool = lifecycle_victim.is_queued_for_deletion()
		await process_frame
		if shadow_batch != null and is_instance_valid(shadow_batch):
			shadow_batch._update_visible_units()
		var shadow_end: Dictionary = shadow_module.batch_summary(b)
		_check(queued_after_strip and not is_instance_valid(lifecycle_victim) \
			and is_instance_valid(lifecycle_mark) and lifecycle_mark.is_revealed() \
			and lifecycle_mark.remaining > 0.0,
			"the Unit is freed after its death strip while the ground trace persists")
		_check(int(shadow_end.get("retained_dying_units", -1)) == 0 \
			and int(shadow_end.get("retained_dying_visible", -1)) == 0 \
			and int(shadow_end.get("contact_instances", -1)) \
				== int(shadow_baseline.get("contact_instances", -2)) - 1,
			"death shadow retention prunes itself when the body node is freed", shadow_end)
	else:
		_check(false, "trace reveals after frame one while the remaining death frames still play")
		_check(false, "death shadow remains submitted until the final instant of the death strip")
		_check(false, "the Unit is freed after its death strip while the ground trace persists")
		_check(false, "death shadow retention prunes itself when the body node is freed")

	var invalid_shadow_probe = _probe(b, "guan_dao", lifecycle_origin + Vector2(64.0, 0.0))
	invalid_shadow_probe.hp = 0.0
	invalid_shadow_probe._dying = true
	b.units.erase(invalid_shadow_probe)
	shadow_module.retain_dying_shadow(b, invalid_shadow_probe)
	invalid_shadow_probe.queue_free()
	await process_frame
	if shadow_batch != null and is_instance_valid(shadow_batch):
		shadow_batch._update_visible_units()
	var invalid_pruned: Dictionary = shadow_module.batch_summary(b)
	_check(int(invalid_pruned.get("retained_dying_units", -1)) == 0,
		"an early-freed retained body is pruned without leaving a stale shadow reference",
		invalid_pruned)
	var clear_shadow_probe = _probe(b, "guan_dao", lifecycle_origin + Vector2(96.0, 0.0))
	clear_shadow_probe.visible = true
	clear_shadow_probe.hp = 0.0
	clear_shadow_probe._dying = true
	b.units.erase(clear_shadow_probe)
	shadow_module.retain_dying_shadow(b, clear_shadow_probe)
	if shadow_batch != null and is_instance_valid(shadow_batch):
		shadow_batch._update_visible_units()
	var clear_before: Dictionary = shadow_module.batch_summary(b)
	shadow_module.clear_dying_shadows(b)
	var clear_after: Dictionary = shadow_module.batch_summary(b)
	_check(int(clear_before.get("retained_dying_visible", 0)) == 1 \
		and int(clear_after.get("retained_dying_units", -1)) == 0 \
		and int(clear_after.get("retained_dying_visible", -1)) == 0 \
		and int(clear_after.get("contact_instances", -1)) \
			== int(clear_before.get("contact_instances", -2)) - 1,
		"explicit section cleanup removes retained submissions in the same frame",
		{"before": clear_before, "after": clear_after})
	clear_shadow_probe.queue_free()
	await process_frame

	var merge_origin := base + Vector2(112, 0)
	var first = _probe(b, "guan_dao", merge_origin)
	first.animation_direction = "se"
	first.hp = 0.0
	var before_merge: int = b._death_remains.size()
	var first_mark = b._spawn_death_remains(first)
	first_mark.process_mode = Node.PROCESS_MODE_DISABLED
	first_mark._process(2.0)
	var aged_remaining: float = first_mark.remaining
	var second = _probe(b, "guan_dao", merge_origin + Vector2(18, 0))
	second.animation_direction = "se"
	second.hp = 0.0
	var merged_mark = b._spawn_death_remains(second)
	var near_merge_ok: bool = merged_mark == first_mark \
		and b._death_remains.size() == before_merge + 1 \
		and first_mark.merge_count == 2 \
		and first_mark.remaining > aged_remaining \
		and is_equal_approx(first_mark.remaining, first_mark.lifetime)
	_check(near_merge_ok, "a real death within 36px refreshes and deepens the existing mark")
	var third = _probe(b, "guan_dao", merge_origin + Vector2(54, 0))
	third.animation_direction = "se"
	third.hp = 0.0
	var separate_mark = b._spawn_death_remains(third)
	_check(separate_mark != first_mark and b._death_remains.size() == before_merge + 2,
		"a death outside the 36px merge radius creates a separate mark")

	var scale_anchor_ok := true
	for frame in b.DEATH_REMAINS_SAFE_FRAMES:
		scale_anchor_ok = scale_anchor_ok \
			and float(b.DEATH_REMAINS_FRAME_SCALE.get(frame, 0.0)) > 0.0 \
			and b.DEATH_REMAINS_FRAME_ANCHOR.get(frame, null) is Vector2
	_check(scale_anchor_ok, "every production frame has a positive scale and explicit anchor correction")
	_check(is_equal_approx(float(b.DEATH_REMAINS_FRAME_SCALE.get(0, 0.0)), 0.65) \
		and is_equal_approx(float(b.DEATH_REMAINS_FRAME_SCALE.get(1, 0.0)), 0.45) \
		and is_equal_approx(float(b.DEATH_REMAINS_FRAME_SCALE.get(2, 0.0)), 0.25) \
		and is_equal_approx(float(b.DEATH_REMAINS_FRAME_SCALE.get(3, 0.0)), 0.38) \
		and is_equal_approx(float(b.DEATH_REMAINS_FRAME_SCALE.get(5, 0.0)), 0.30),
		"blood and equipment categories use independently reduced visual scales")
	_check(b.DEATH_REMAINS_LIFETIME == 45.0 and b.DEATH_REMAINS_FADE == 8.0 \
		and b.DEATH_REMAINS_CAP == 48 and b.DEATH_REMAINS_LITE_LIFETIME == 24.0 \
		and b.DEATH_REMAINS_LITE_FADE == 5.0 and b.DEATH_REMAINS_LITE_CAP == 24,
		"normal and lightweight lifetime/fade/cap contracts remain unchanged")

	var screenshot := ""
	var equipment_screenshot := ""
	var equipment_comparison: Array = []
	if graphical:
		b.hud.hide()
		# The fixture freezes the battle before its periodic fog refresh. Hide only
		# the fog overlay for this review frame so an untouched all-black capture
		# cannot be reported as visual evidence.
		b.fog = false
		if b._fog_layer != null:
			b._fog_layer.visible = false
		if b.map.sample_scenery != null:
			b.map.sample_scenery._refresh_fog_visibility()
		b.camera.position = b.to_screen(base)
		b.camera.zoom = Vector2.ONE * 1.55
		b.camera.force_update_scroll()
		b._grid_build()
		for mark in b._death_remains:
			if is_instance_valid(mark):
				mark.process_mode = Node.PROCESS_MODE_DISABLED
				if not mark.is_revealed():
					mark._process(mark.reveal_delay + mark.reveal_fade_duration + 0.01)
				mark.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		screenshot = OUTPUT.path_join("skirmish_death_remains_1280.png")
		var screenshot_ok := image != null and image.get_size() == VIEW \
			and _image_has_scene_content(image) \
			and image.save_png(screenshot) == OK
		_check(screenshot_ok, "1280x720 production-map review frame saved")

		# Fixed-frame comparison: every debris category is forced beside a real
		# Unit using its actual death-down renderer. This cannot accidentally miss
		# helmet/shield frames through the normal deterministic rarity selection.
		for child in b.units_root.get_children():
			if is_instance_valid(child):
				child.hide()
		for effect in b.fx_root.get_children():
			if is_instance_valid(effect):
				effect.hide()
		for old_mark in b._death_remains:
			if is_instance_valid(old_mark):
				old_mark.queue_free()
		b._death_remains.clear()
		await process_frame
		var comparison_specs := [
			{"key": "guan_dao", "frame": 0, "label": "血迹 0.65"},
			{"key": "guan_qi", "frame": 1, "label": "长兵器 0.45"},
			{"key": "guan_qi", "frame": 2, "label": "盔甲 0.25"},
			{"key": "guan_gong", "frame": 3, "label": "盾片 0.38"},
			{"key": "guan_dao", "frame": 5, "label": "布鞋 0.30"},
		]
		var comparison_offsets := [-320.0, -160.0, 0.0, 160.0, 320.0]
		var projected_center: Vector2 = b.to_screen(base)
		var comparison_marks: Array = []
		var saved_comparison_phase = b.phase
		b.phase = b.Phase.DEPLOY
		for index in comparison_specs.size():
			var spec: Dictionary = comparison_specs[index]
			var projected_unit := projected_center + Vector2(float(comparison_offsets[index]), -22.0)
			var comparison_unit = _probe(b, String(spec.key), b.to_logic(projected_unit))
			comparison_unit.position = b.to_logic(projected_unit)
			comparison_unit.animation_direction = "se"
			comparison_unit.visible = true
			b.map.sync_render_position(comparison_unit)
			var mark_count_before: int = b._death_remains.size()
			comparison_unit.take_damage(comparison_unit.hp + 1.0)
			var comparison_mark = b._death_remains[-1] \
				if b._death_remains.size() > mark_count_before else null
			if comparison_mark == null:
				continue
			comparison_unit.process_mode = Node.PROCESS_MODE_DISABLED
			comparison_unit._death_t = float(comparison_unit.DEATH_DUR) * 0.57
			comparison_unit._flash = 0.0
			comparison_unit.queue_redraw()
			var frame := int(spec.frame)
			var projected_mark := projected_unit + Vector2(52.0, 8.0)
			var mark_position: Vector2 = b.to_logic(projected_mark)
			comparison_mark.position = mark_position
			comparison_mark.process_mode = Node.PROCESS_MODE_DISABLED
			comparison_mark.configure(b._death_remains_texture(), frame,
				clampf(comparison_unit.radius * 5.2, 48.0, 78.0),
				b.map.ground_basis(mark_position), b.DEATH_REMAINS_LIFETIME,
				b.DEATH_REMAINS_FADE, b.DEATH_REMAINS_REVEAL_DELAY,
				float(b.DEATH_REMAINS_FRAME_SCALE.get(frame, 1.0)),
				b.DEATH_REMAINS_FRAME_ANCHOR.get(frame, Vector2.ZERO), "se",
				Vector2.ZERO, b.DEATH_REMAINS_REVEAL_FADE)
			comparison_mark.set_meta("death_remains_frame", frame)
			comparison_mark._process(comparison_mark.reveal_delay \
				+ comparison_mark.reveal_fade_duration + 0.01)
			comparison_mark.show()
			comparison_mark.queue_redraw()
			b.map.sync_render_position(comparison_mark)
			comparison_marks.append(comparison_mark)
			var body_size: float = comparison_unit.radius * 3.7 * comparison_unit.visual_scale
			var debris_size: float = comparison_mark.visual_size * comparison_mark.frame_scale
			equipment_comparison.append({"key": String(spec.key), "frame": frame,
				"scale": comparison_mark.frame_scale, "body_square_px": body_size,
				"debris_square_px": debris_size, "square_ratio": debris_size / body_size})
		b.phase = saved_comparison_phase
		# Real lethal hits also spawn damage numbers and impact accents. Keep them
		# out of this size plate so only the five fixed residue nodes are compared.
		for effect in b.fx_root.get_children():
			if is_instance_valid(effect) and effect not in comparison_marks:
				effect.hide()
		var fixed_frames_ok := equipment_comparison.size() == 5
		var ratios_by_frame := {}
		for entry in equipment_comparison:
			ratios_by_frame[int(entry.frame)] = float(entry.square_ratio)
		fixed_frames_ok = fixed_frames_ok and ratios_by_frame.has(1) \
			and float(ratios_by_frame[1]) >= 0.45 and float(ratios_by_frame[1]) <= 0.75 \
			and ratios_by_frame.has(2) and float(ratios_by_frame[2]) < 0.45 \
			and ratios_by_frame.has(3) and float(ratios_by_frame[3]) < 0.60 \
			and ratios_by_frame.has(5) and float(ratios_by_frame[5]) < 0.50
		_check(fixed_frames_ok,
			"fixed equipment frames are materially smaller than adjacent real death bodies",
			{"pairs": equipment_comparison})
		var labels := CanvasLayer.new()
		labels.layer = 100
		b.add_child(labels)
		var title := Label.new()
		title.text = "固定残骸比例 · 真实死亡单位对照"
		title.position = Vector2(420.0, 42.0)
		title.size = Vector2(440.0, 36.0)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 24)
		title.add_theme_color_override("font_outline_color", Color.BLACK)
		title.add_theme_constant_override("outline_size", 5)
		labels.add_child(title)
		for index in comparison_specs.size():
			var label := Label.new()
			label.text = String(comparison_specs[index].label)
			label.position = Vector2(640.0 + float(comparison_offsets[index]) * 1.20 - 74.0, 110.0)
			label.size = Vector2(148.0, 30.0)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 19)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 4)
			labels.add_child(label)
		b.camera.position = projected_center
		b.camera.zoom = Vector2.ONE * 1.20
		b.camera.force_update_scroll()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var equipment_image := root.get_texture().get_image()
		equipment_screenshot = OUTPUT.path_join("equipment_scale.png")
		var equipment_screenshot_ok := equipment_image != null \
			and equipment_image.get_size() == VIEW and _image_has_scene_content(equipment_image) \
			and equipment_image.save_png(equipment_screenshot) == OK
		_check(equipment_screenshot_ok,
			"fixed-frame real-Unit equipment scale comparison saved",
			{"path": equipment_screenshot})

	var report := {
		"passed": failures.is_empty(),
		"failures": failures,
		"checks": checks,
		"check_count": checks.size(),
		"headless": not graphical,
		"screenshot": screenshot,
		"equipment_screenshot": equipment_screenshot,
		"equipment_comparison": equipment_comparison,
		"human_playtest": false,
		"performance_test": false,
		"scope": "Real skirmish Battle helpers, production atlas, semantic weighting, direction provenance with foot-point placement, lethal-signal ordering, render-only fading death shadows, four-frame death timing, delayed reveal ramp, persistent post-strip traces, nearby merge, per-category frame calibration and unchanged lifetime/cap/exclusion contracts.",
	}
	var report_name := "report_visual.json" if graphical else "report_headless.json"
	var report_file := FileAccess.open(OUTPUT.path_join(report_name), FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "  ") + "\n")
		report_file.close()
	else:
		failures.append("report file opens")
	print("[skirmish-death-remains-result] ", JSON.stringify(report))
	b.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
