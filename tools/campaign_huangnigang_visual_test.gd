extends SceneTree
## Reserve a graphical window before running. Real story captures never inject story state,
## HP, variants or positions. The separate walk fixture resets positions and freezes mission
## processing, then observes normal Unit movement/animation; it is not playthrough evidence.
const VIEW := Vector2i(1280, 720)
const KEYS := ["chao_gai", "wu_yong", "gongsun_sheng", "liu_tang", "ruan_xiaoer", "ruan_xiaowu", "ruan_xiaoqi", "bai_sheng"]
const DIRECTIONS := ["se", "sw", "nw", "ne"]
const STEP := [Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(0, -2)]
const ORIGINS := [Vector2i(3, 10), Vector2i(7, 10), Vector2i(11, 10), Vector2i(15, 10), Vector2i(3, 14), Vector2i(7, 14), Vector2i(11, 14), Vector2i(3, 18)]
const STORY_SHOTS := ["01_seven_carts", "02_bai_carrying_wine", "03_wine_unloaded", "04_convoy_unconscious", "05_tribute_carried"]
var output := ""
var failures: Array[String] = []
var checks: Array = []
var captures: Array = []
var walk_observations: Array = []
var walk_regions := {}
var source_hashes := {}
var story_completed := false

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks.append({"name": label, "passed": ok})
	if not ok: failures.append(label)
	print("[hn-visual-check] ", "PASS " if ok else "FAIL ", label)

func _source(texture) -> String:
	if texture == null: return ""
	return texture.atlas.resource_path if texture is AtlasTexture else texture.resource_path

func _sha(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func _texture_record(texture) -> Dictionary:
	if texture == null: return {"source": "", "missing": true}
	var source := _source(texture)
	if not source_hashes.has(source):
		source_hashes[source] = _sha(FileAccess.get_file_as_bytes(source)) if FileAccess.file_exists(source) else ""
	return {"source": source, "region": str(texture.region) if texture is AtlasTexture else "whole",
		"size": str(texture.get_size()), "source_sha256": source_hashes[source]}

func _actor_record(b, u) -> Dictionary:
	var art = root.get_node("Art")
	var frame = u._anim_frame_for_state(art.unit_texture(u.key, u.art_variant))
	return {"key": u.key, "variant": u.art_variant, "direction": u.animation_direction, "move_blend": u._move_blend,
		"z_index": u.z_index, "z_as_relative": u.z_as_relative,
		"render_height": float(u.get_meta("render_height", 0.0)), "expected_render_height": b.map.height_at(u.position),
		"projected_feet": [b.map.project(u.position).x, b.map.project(u.position).y],
		"wine_carry_pose": u._campaign_wine_carry_state(), "legacy_wine_overlay_condition": bool(u.get_meta("carrying_wine", false)) and u._campaign_wine_carry_state().is_empty(),
		"position": [u.position.x, u.position.y], "cell": str(b.map.world_to_cell(u.position)), "hp": u.hp, "outcome": u.story_outcome,
		"visible": u.visible, "body_base_size": u.radius * 3.7 * u.visual_scale, "frame": _texture_record(frame),
		"portrait": _texture_record(art.avatar_texture(u.key, u.art_variant)),
		"carrying_wine": bool(u.get_meta("carrying_wine", false)), "carrying_tribute": int(u.get_meta("carrying_tribute", -1))}

func _objects(b) -> Array:
	var result: Array = []
	for n in b.fx_root.get_children():
		var script = n.get_script()
		if (script == null or script.resource_path != "res://scripts/campaign_art_event.gd") and n.get_meta("campaign_object", "") != "jujube_cart": continue
		result.append({"object": String(n.get_meta("campaign_object", "")), "cart_index": int(n.get_meta("jujube_cart_index", -1)),
			"position": [n.position.x, n.position.y], "size": n.size, "visible": n.visible, "texture": _texture_record(n.texture),
			"z_index": n.z_index, "z_as_relative": n.z_as_relative, "expected_projected_z": clampi(1 + int(b.map.project(n.position).y), 1, 3400),
			"contact_shadow_enabled": bool(n.get("contact_shadow_enabled")) if n.get_meta("campaign_object", "") == "jujube_cart" else false})
	return result

func _ground_wine_count(b) -> int:
	var count := 0
	for item in _objects(b):
		if String(item.texture.source) == "res://assets/campaign/environment/level1/wine_buckets.png" and item.visible: count += 1
	return count

func _cart_count(b) -> int:
	return b.fx_root.get_children().filter(func(n): return n.get_meta("campaign_object", "") == "jujube_cart" and n.visible).size()

func _hero_bar_record(b) -> Array:
	var rows: Array = []
	for chip in b.hud._hero_bar.get_children():
		if is_instance_valid(chip.hero):
			rows.append({"key": chip.hero.key, "current_variant": chip.hero.art_variant,
				"drawn_variant": chip._last_drawn_art_variant, "drawn_portrait": chip._last_drawn_portrait_path})
	return rows

func _start():
	Engine.time_scale = 1.0
	var c = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]: c.set(mode, false)
	c.current = c.index_for_id("level1")
	seed(5088120)
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	if not is_instance_valid(b.hud) or not is_instance_valid(b.map):
		_check(false, "normal scene construction")
		return null
	b.hud._intro_root.hide()
	b._on_intro_done()
	b.hud._on_start_pressed()
	b._smoke = true
	Engine.time_scale = 4.0
	return b

func _camera(b, center: Vector2, zoom_value: float, screen_anchor := Vector2(820, 315)) -> void:
	b.camera.set_process(false)
	b.camera.zoom = Vector2.ONE * zoom_value
	b.camera.position = b.to_screen(center) - (screen_anchor - Vector2(VIEW) * 0.5) / zoom_value
	b.camera.offset = Vector2.ZERO
	b.camera.force_update_scroll()

func _snapshot(b, label: String, fixture: bool) -> Dictionary:
	var actors: Array = []
	for u in b.level.actors:
		if is_instance_valid(u): actors.append(_actor_record(b, u))
	var convoy: Array = []
	for u in b.level.convoy:
		if is_instance_valid(u): convoy.append({"key": u.key, "hp": u.hp, "outcome": u.story_outcome, "position": [u.position.x, u.position.y]})
	var ground_loads: Array = []
	for u in b.units:
		if is_instance_valid(u) and u.key == "treasure_cart": ground_loads.append({"id": u.get_instance_id(), "visible": u.visible, "position": [u.position.x, u.position.y]})
	return {"label": label, "fixture": fixture, "phase": b.phase, "stage": b.mission.stage_id, "events": b.mission.events.duplicate(true),
		"game_seconds": b.mission.total_game_seconds, "objective": b.mission.objective, "top_status": b.hud.top_label.text,
		"active_action": b.mission.active_action_id, "kills": b.kills, "actors": actors, "convoy": convoy, "objects": _objects(b), "hero_bar": _hero_bar_record(b),
		"ground_tribute_loads": ground_loads, "cart_count": _cart_count(b), "ground_wine_pairs": _ground_wine_count(b),
		"camera": {"position": str(b.camera.position), "zoom": b.camera.zoom.x}, "task_panel": str(b.mission._panel.get_global_rect()),
		"adjustments": ["Camera framing and selection only; simulation frozen for capture"] if not fixture else ["Separate fresh scene; mission processing frozen", "Observation starting positions explicitly set", "Normal order_move changes direction and animation; no variant/event/animation phase injection"]}

func _refresh_panel(b) -> void:
	# tick(0) also stops/repaths actors; capture refreshes only the presentation fields.
	b.mission._panel.visible = b.phase == b.Phase.FIGHT and b.mission.stage_id != ""
	b.mission._panel.position = b.hud.campaign_objective_position()
	b.mission._panel.reset_size()

func _capture(b, label: String, fixture := false) -> void:
	var prior_mode: int = b.process_mode
	b.process_mode = Node.PROCESS_MODE_DISABLED
	var mission_before := {"active": b.mission.active_action_id, "progress": b.mission._progress, "retry": b.mission._retry, "events": b.mission.events.duplicate(true)}
	b.hud.set_top(b.level.top_status(b))
	_refresh_panel(b)
	await process_frame
	await process_frame
	_refresh_panel(b)
	b._grid_build()
	for u in b.units:
		if is_instance_valid(u):
			# Freezing can precede Scenery's last per-frame elevation sync.
			# Apply the existing render transform after the final physics movement.
			b.map.sync_render_position(u)
			u.queue_redraw()
	for effect in b.fx_root.get_children():
		if effect is Node2D: b.map.sync_render_position(effect)
	_check(b.units.all(func(u): return not is_instance_valid(u) or is_equal_approx(float(u.get_meta("render_height", 0.0)), b.map.height_at(u.position))), label + " final unit elevation synchronized after capture freeze")
	await RenderingServer.frame_post_draw
	_check(_hero_bar_record(b).all(func(row): return row.drawn_variant == row.current_variant and row.drawn_portrait == "res://assets/campaign/portraits/%s.png" % row.current_variant), label + " hero quick-switch bar really drew current variant portraits")
	var image = root.get_texture().get_image()
	var path := output.path_join(label + ".png")
	var ok: bool = image != null and image.get_size() == VIEW and image.save_png(path) == OK
	_check(ok, label + " rendered at 1280x720")
	_check(mission_before.active == b.mission.active_action_id and mission_before.progress == b.mission._progress and mission_before.retry == b.mission._retry and mission_before.events == b.mission.events, label + " UI refresh leaves mission commands and events untouched")
	var record := _snapshot(b, label, fixture)
	record["png"] = path
	record["png_sha256"] = _sha(FileAccess.get_file_as_bytes(path)) if ok else ""
	record["captured"] = ok
	captures.append(record)
	_write(output.path_join(label + ".json"), record)
	b.process_mode = prior_mode

func _target(b, index: int) -> bool:
	var l = b.level
	var bai = b.find_unit("bai_sheng")
	match index:
		0: return b.mission.has_event("place_dates") and _cart_count(b) == 7
		1: return bai != null and bool(bai.get_meta("carrying_wine", false)) and bai._move_blend > 0.3 and not b.mission.has_event("bring_wine")
		2: return b.mission.has_event("bring_wine") and bai != null and not bool(bai.get_meta("carrying_wine", false))
		3: return b.mission.has_event("drugged") and not b.mission.has_event("take_0")
		4:
			var liu = b.find_unit("liu_tang")
			return b.mission.has_event("take_0") and not b.mission.has_event("deliver_0") and liu != null and liu.has_meta("carrying_tribute") and liu._move_blend > 0.3
	return false

func _story() -> void:
	var b = await _start()
	if b == null: return
	for index in range(STORY_SHOTS.size()):
		var frames := 0
		while not _target(b, index) and b.phase != b.Phase.END and frames < 12000:
			await process_frame
			frames += 1
		_check(_target(b, index), STORY_SHOTS[index] + " reached through real mission actions")
		if not _target(b, index): break
		b._smoke = false
		var selected = b.find_unit("chao_gai" if index == 0 else ("bai_sheng" if index in [1, 2] else "liu_tang"))
		b._set_selection([selected])
		b.hud.update_selection_panel([selected])
		match index:
			0: _camera(b, b.map.cell_to_world(Vector2i(23, 15)), 1.0, Vector2(885, 325))
			1: _camera(b, selected.position, 2.0)
			2: _camera(b, b.map.cell_to_world(Vector2i(24, 22)), 1.18)
			_: _camera(b, b.map.cell_to_world(Vector2i(24, 20)), 1.18)
		if index == 1:
			var record := _actor_record(b, selected)
			_check(_ground_wine_count(b) == 0 and record.wine_carry_pose == "carry_walk" and not record.legacy_wine_overlay_condition and record.frame.source == "res://assets/campaign/anim/hn_bai_sheng_carry_walk_%s.png" % selected.animation_direction, "real shoulder-carried wine uses carry_walk without a legacy or ground bucket pair")
		if index == 0:
			_check(b.level.jujube_carts.all(func(n): return not n.z_as_relative and n.z_index == clampi(1 + int(b.map.project(n.position).y), 1, 3400) and n.contact_shadow_enabled), "seven carts use world depth and soft contact shadows")
		if index == 2:
			var record := _actor_record(b, selected)
			var normal_pose: bool = String(record.frame.source).begins_with("res://assets/campaign/anim/hn_bai_sheng_idle_") or String(record.frame.source).begins_with("res://assets/campaign/anim/hn_bai_sheng_walk_")
			_check(_ground_wine_count(b) == 1 and not selected.get_meta("carrying_wine", false) and record.wine_carry_pose == "" and normal_pose, "unloaded wine appears once on ground while Bai resumes ordinary idle/walk")
		if index == 3: _check(b.level.convoy.size() == 15 and b.level.convoy.all(func(u): return u.hp > 0.0 and u.story_outcome == "unconscious") and b.kills == 0, "all fifteen convoy members are alive and unconscious")
		if index == 4: _check(b.units.filter(func(u): return is_instance_valid(u) and u.key == "treasure_cart").size() == 2, "one carried tribute leaves exactly two ground loads")
		await _capture(b, STORY_SHOTS[index])
		b._smoke = true
	var frames := 0
	while b.phase != b.Phase.END and frames < 12000:
		await process_frame
		frames += 1
	story_completed = b.phase == b.Phase.END and b.mission.has_event("escaped")
	_check(story_completed, "real chapter completes after all captures")
	_write(output.path_join("story_completion.json"), {"completed": story_completed, "game_seconds": b.mission.total_game_seconds, "stage_metrics": b.mission.stage_metrics, "events": b.mission.events.keys(), "timing_note": "Capture observation pauses; not player pacing evidence."})
	b.queue_free()
	await process_frame
	await process_frame

func _observe_walk(b, frame_number: int, direction: String) -> bool:
	var all_moving := true
	for u in b.level.actors:
		var record := _actor_record(b, u)
		if record.direction != direction or record.move_blend <= 0.3:
			all_moving = false
			continue
		var expected := "res://assets/campaign/anim/hn_%s_walk_%s.png" % [u.key, direction]
		if record.frame.source != expected:
			all_moving = false
			continue
		var key: String = u.key + "|" + direction
		if not walk_regions.has(key): walk_regions[key] = []
		if not walk_regions[key].has(record.frame.region):
			walk_regions[key].append(record.frame.region)
			record["observation_frame"] = frame_number
			record["expected_direction"] = direction
			walk_observations.append(record)
	return all_moving

func _walk_fixture() -> void:
	var b = await _start()
	if b == null: return
	var frames := 0
	while not b.mission.has_event("bring_wine") and b.phase != b.Phase.END and frames < 6000:
		await process_frame
		frames += 1
	_check(b.level.actors.size() == 8 and b.mission.has_event("bring_wine") and not b.find_unit("bai_sheng").get_meta("carrying_wine", false), "ordinary-walk fixture starts after eight actors spawn and Bai really unloads")
	if b.level.actors.size() != 8 or not b.mission.has_event("bring_wine"):
		b.queue_free()
		return
	b._smoke = false
	b.set_process(false)
	Engine.time_scale = 1.0
	for u in b.units:
		if not u in b.level.actors: u.set_physics_process(false)
	for i in range(KEYS.size()):
		var u = b.find_unit(KEYS[i])
		_check(b.map.is_open_cell(ORIGINS[i], "land"), "fixture origin open " + KEYS[i])
		u.order_stop()
		u.position = b.map.cell_to_world(ORIGINS[i])
		b.map.sync_render_position(u)
	b._grid_build()
	b._set_selection([b.find_unit("bai_sheng")])
	b.hud.update_selection_panel([b.find_unit("bai_sheng")])
	_camera(b, b.map.cell_to_world(Vector2i(10, 13)), 1.06, Vector2(850, 325))
	var offset := Vector2i.ZERO
	for index in range(DIRECTIONS.size()):
		offset += STEP[index]
		for i in range(KEYS.size()):
			var u = b.find_unit(KEYS[i])
			var destination: Vector2 = b.map.cell_to_world(ORIGINS[i] + offset)
			_check(b.map._segment_open(u.position, destination, "land"), "fixture walk segment open " + KEYS[i] + " " + DIRECTIONS[index])
			u.order_move(destination)
		var screenshots := 0
		var aligned_at := -1
		for frame_number in range(150):
			await process_frame
			b._grid_build()
			var all_moving := _observe_walk(b, frame_number, DIRECTIONS[index])
			if all_moving and aligned_at < 0: aligned_at = frame_number
			if all_moving and (screenshots == 0 or (screenshots == 1 and frame_number >= aligned_at + 16)):
				await _capture(b, "fixture_walk_%s_%d" % [DIRECTIONS[index], screenshots + 1], true)
				screenshots += 1
		_check(screenshots == 2, "two rendered walk observations " + DIRECTIONS[index])
	for key in KEYS:
		for direction in DIRECTIONS:
			_check(walk_regions.get(key + "|" + direction, []).size() >= 2, "two actual walk poses " + key + " " + direction)
	for u in b.level.actors: u.order_stop()
	for i in range(30): await process_frame
	for u in b.level.actors:
		var record := _actor_record(b, u)
		_check(record.move_blend <= 0.3 and String(record.frame.source).begins_with("res://assets/campaign/anim/hn_%s_idle_" % u.key), "idle resumes in same variant " + u.key)
	await _capture(b, "fixture_idle_after_walk", true)
	await _cart_depth_fixture(b)
	b.queue_free()
	await process_frame
	await process_frame

func _cart_depth_fixture(b) -> void:
	var cart = b.level.jujube_carts[-1]
	var actor = b.find_unit("chao_gai")
	for u in b.level.actors:
		u.order_stop()
		if u != actor: u.set_physics_process(false)
	b._set_selection([actor])
	b.hud.update_selection_panel([actor])
	_camera(b, cart.position, 1.65)
	for behind in [true, false]:
		var side := -16.0 if behind else 16.0
		actor.position = cart.position + Vector2(side - 20.0, side + 20.0)
		b.map.sync_render_position(actor)
		var destination: Vector2 = cart.position + Vector2(side + 20.0, side - 20.0)
		_check(b.map._segment_open(actor.position, destination, "land"), "cart depth fixture path open " + str(behind))
		actor.order_move(destination)
		var captured := false
		for frame in range(180):
			await process_frame
			b._grid_build()
			if actor._move_blend <= 0.3 or absf(b.map.project(actor.position).x - b.map.project(cart.position).x) > 10.0: continue
			_check(actor.z_index < cart.z_index if behind else actor.z_index > cart.z_index, "actual actor/cart draw order " + ("behind" if behind else "front"))
			await _capture(b, "fixture_cart_actor_" + ("behind" if behind else "front"), true)
			captured = true
			break
		_check(captured, "cart overlap movement observed " + ("behind" if behind else "front"))
		actor.order_stop()

func _write(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "write " + path)
		return
	file.store_string(JSON.stringify(value, "\t"))
	file.close()

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	OS.set_environment("SMOKE_TEST", "")
	if DisplayServer.get_name() == "headless":
		push_error("This tool requires the reserved graphical window; headless is not screenshot evidence.")
		quit(2)
		return
	output = ProjectSettings.globalize_path("res://qa/web_chatgpt_art_20260831/huangnigang_visual_clear")
	DirAccess.make_dir_recursive_absolute(output)
	root.mode = Window.MODE_WINDOWED
	root.size = VIEW
	root.content_scale_size = VIEW
	DisplayServer.window_set_size(VIEW)
	root.title = "Huangnigang visual QA · 1280×720"
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0, true)
	var art = root.get_node("Art")
	for key in KEYS:
		for direction in DIRECTIONS:
			_check(art.campaign_variant_has_animation("hn_" + key, "idle", direction) and art.campaign_variant_has_animation("hn_" + key, "walk", direction), "ready idle and walk " + key + " " + direction)
	for direction in DIRECTIONS:
		for state in ["carry_idle", "carry_walk"]:
			_check(art.campaign_variant_has_animation("hn_bai_sheng", state, direction), "ready exact Bai shoulder pose " + state + " " + direction)
	if failures.is_empty():
		await _story()
		await _walk_fixture()
	_check(story_completed and captures.size() == 16, "all five real story and eleven explicit fixture images captured")
	Engine.time_scale = 1.0
	var report := {"passed": failures.is_empty(), "failures": failures, "checks": checks, "captures": captures,
		"walk_observations": walk_observations, "walk_regions": walk_regions, "visual_review": "pending: view screenshots for size, alpha, shadows, occlusion, cart placement, clothing/portrait consistency and baked-in duplicate wine buckets", "human_playtest": false, "performance_test": false}
	_write(output.path_join("report.json"), report)
	print("[hn-visual-summary] ", JSON.stringify({"passed": failures.is_empty(), "failures": failures, "captures": captures.size(), "walk_observations": walk_observations.size()}))
	quit(0 if failures.is_empty() else 1)
