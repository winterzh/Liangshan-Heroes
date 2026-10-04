extends "res://tools/art_character_direction4_qa.gd"
class CapturedBodyFixture extends "res://scripts/unit.gd":
	func _draw() -> void:
		# Same production body drawing, with all world-space labels omitted for
		# the explicit unobscured matrix. Actual chapter screenshots retain UI.
		_draw_sprite_animated(get_tree().root.get_node("Art").unit_texture(key), Color.WHITE, 0.0)

## Targeted story-only batch. Four-view matrices use explicit display fixtures.
## The real chapter's original Han Tao is captured by original Xu Ning's normal
## attacks at full HP. Nonparticipants/defender and contact positions are fixtures;
## no HP, attack, training, mission outcome or simulation-time edits.

func _capture_contracts() -> void:
	var art = root.get_node("Art")
	for direction in ART_DIRS:
		var frames: Array = art.unit_captured_frames("han_tao", direction)
		check(frames.size() == 1, "one exact captured frame: " + direction)
		if frames.size() != 1: continue
		var frame = frames[0]
		var pose: Dictionary = art_manifest.poses["captured_" + direction]
		var rect: Array = pose.region
		check(frame is AtlasTexture and frame.atlas.resource_path == "res://" + art_manifest.sources.captured.path and frame.region == Rect2(rect[0],rect[1],rect[2],rect[3]), "exact native sample: " + direction)
		check(frame.get_width() == frame.get_height() and frame.filter_clip and frame.get_meta("authored_direction4", false), "square clipped authored frame: " + direction)
		check(is_equal_approx(float(frame.get_meta("draw_scale", 1.0)), float(pose.draw_scale)), "captured body scale metadata: " + direction)
		check(frame.atlas.get_size() == Vector2(1254,1254), "native import dimensions retained: " + direction)
		check(FileAccess.get_sha256("res://" + art_manifest.sources.captured.path) == art_manifest.sources.captured.sha256, "native source bytes retained: " + direction)
		check(art.unit_anim_frames("han_tao", "down", direction).is_empty(), "captured resource stays separate from generic down/death: " + direction)
		check(art.unit_captured_frames("han_tao", direction, "bound_qin_ming").is_empty(), "story costume cannot borrow captured armor: " + direction)
		for other in ["peng_qi", "hu_sanniang", "hu_yanzhuo", "xu_ning"]:
			check(art.unit_captured_frames(other, direction).is_empty(), "captured art rejects another character: " + other + direction)
		art_rows.append({"state":"captured","direction":direction,"source":_texture_source(frame),"pose":_texture_pose(frame)})
	for direction in ["", "bad", "SE"]:
		check(art.unit_captured_frames("han_tao", direction).is_empty(), "invalid captured direction rejected: " + direction)
	check(_texture_source(art.ui_portrait_texture("han_tao")) == "res://assets/portraits4.png", "current Han Tao identity portrait retained")

func _captured_matrix(b) -> void:
	if not art_visual: return
	b.world.hide(); b.hud.hide()
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("29291f")
	background.size = Vector2(root.size)
	canvas.add_child(background)
	var world := Node2D.new()
	world.transform = load("res://scripts/game_map.gd").ISO.scaled(Vector2.ONE * 2.3)
	canvas.add_child(world)
	for row in range(2):
		for col in range(4):
			var label := Label.new()
			label.text = ART_DIRS[col] + (" / normal" if row == 0 else " / 2x visual fixture")
			label.position = Vector2(170 + col*305, 160 + row*350)
			canvas.add_child(label)
			var u := CapturedBodyFixture.new()
			u.setup("han_tao", b._defs.han_tao, 1, b, b.map)
			world.add_child(u)
			u.position = world.transform.affine_inverse() * Vector2(270 + col*305,350 + row*350)
			u.set_physics_process(false); u.set_process(false)
			u.resolve_story("captured") # Display fixture, never the real mission actor.
			u.animation_direction = ART_DIRS[col]
			u.face_left = col in [1,3]
			u.visual_scale = 1.0 if row == 0 else 2.0
			u.fog_visible = true
			u.display_name = ""
			u.show(); u.queue_redraw()
	await process_frame
	await _art_screenshot(null, "han_captured_matrix")
	canvas.queue_free()
	await process_frame
	b.world.show(); b.hud.show()
	b._grid_build()

func _actual_capture() -> void:
	var b = await _start("", 3)
	_freeze_nonparticipants(b)
	b.fog = false; b.fog_layer.hide()
	check(b.level.get_script().resource_path == "res://scripts/levels/level4_lianhuanma_rts.gd", "actual current linked-cavalry RTS chapter")
	var han = b.level.han
	var xu = b.level.xu
	var hu = b.level.hu
	check(han.key == "han_tao" and han.defeat_outcome == "captured" and han.story_outcome.is_empty() and han.hp == han.max_hp and han.hp > 400, "original living full-HP Han has nonlethal chapter outcome")
	check(xu.key == "xu_ning" and b.level.riders.size() == 12 and hu.defeat_outcome == "retreated", "original Xu, twelve riders and Hu retreat outcome retained")
	var actor_id: int = han.get_instance_id()
	var portrait_before: String = _texture_pose(han.ui_portrait_texture())
	var hp_before: float = han.hp
	# Level-one Q uses the ordinary available skill point as an explicit fixture.
	# Prove an actually available active skill becomes unavailable on capture;
	# unlearned slots alone would not establish this boundary.
	var learned_q_fixture: bool = han.can_learn(0)
	if learned_q_fixture: han.learn(0)
	check(int(han.ability_slots[0].rank) > 0 and han.slot_ready(0), "normally learned level-one Q is ready before capture")
	var stats_before := [han.max_hp,han.atk,han.base_speed,han.atk_cd,han.atk_range,han.radius]
	var signals := {"deaths":0,"captures":0}
	han.died.connect(func(_u): signals.deaths += 1)
	han.story_resolved.connect(func(_u, outcome):
		if outcome == "captured": signals.captures += 1)
	await _art_screenshot(b, "han_opening", han)
	var cell := _clear_art_patch(b)
	check(cell.x >= 0, "empty chapter patch for explicit normal-damage contact fixture")
	if cell.x < 0:
		await _dispose(b)
		return
	han.position = b.map.cell_to_world(cell)
	xu.position = han.position + Vector2(34,0)
	xu.passive = false; xu.auto_micro = false; xu.set_physics_process(true)
	b._grid_build()
	xu.order_attack(han,false,true)
	var previous: float = han.hp
	var damage_ticks := 0
	for tick in range(1200):
		await _wait(0.1)
		if han.hp < previous: damage_ticks += 1
		previous = han.hp
		if han.story_outcome == "captured": break
	xu.order_stop(); xu.passive = true; xu.set_physics_process(false)
	check(han.story_outcome == "captured" and han.hp > 0 and not han._dying and damage_ticks > 1, "normal repeated original-Xu attacks capture living Han from full HP")
	check(han.get_instance_id() == actor_id and han.faction == 1 and b.units.has(han), "capture keeps original enemy actor without recruitment or conversion")
	check(b.mission.has_event("lhm_han_captured") and signals.captures == 1 and signals.deaths == 0, "normal chapter callback records capture once without death signal")
	check(stats_before == [han.max_hp,han.atk,han.base_speed,han.atk_cd,han.atk_range,han.radius], "existing cavalry combat stats remain unchanged")
	check(han.passive and han.stance == han.STANCE_PASSIVE and han._pending_target == null and han._pending_done and is_zero_approx(han._lunge) and is_zero_approx(han._cast_t), "capture cancels pending combat and enters passive story state")
	var art = root.get_node("Art")
	for direction in ART_DIRS:
		han.animation_direction = direction # Four-view display fixture, same real actor.
		han.face_left = direction in ["sw","nw"]
		var chosen: Array = han._story_animation_frames()
		check(chosen.size() == 1 and _texture_pose(chosen[0]) == _texture_pose(art.unit_captured_frames("han_tao",direction)[0]) and han._frame_directional, "real captured draw uses exact authored pose without mirroring: " + direction)
		check(_texture_pose(han.ui_portrait_texture()) == portrait_before, "captured HUD identity retained: " + direction)
		han.queue_redraw()
		await _art_screenshot(b, "han_captured_" + direction, han)
	var capture_hp: float = han.hp
	han.take_damage(999.0,xu) # Post-capture rejection fixture, not initial capture.
	check(han.hp == capture_hp and signals.deaths == 0, "further damage cannot kill or alter captured Han")
	check(not han.resolve_story("retreated") and signals.captures == 1, "resolved captive cannot change outcome or duplicate signal")
	for slot in range(4): check(not han.slot_ready(slot), "captured Han cannot use skill slot: " + str(slot))
	var held_position: Vector2 = han.position
	han.set_physics_process(true)
	han.order_move(held_position + Vector2(80,0))
	han.order_attack(xu,false,true)
	await _wait(han.DEATH_DUR + 0.5)
	check(is_instance_valid(han) and han.visible and han.hp == capture_hp and not han._dying and han.story_outcome == "captured", "living prisoner persists beyond corpse lifetime")
	check(han.position == held_position and han._target == null and han._pending_target == null and is_zero_approx(han._lunge), "captured movement/attack orders stay inert")
	await _art_screenshot(b,"han_capture_persistent",han)
	art_runtime.append({"case":"han_actual_capture","actor_retained":han.get_instance_id()==actor_id,"captured":han.story_outcome=="captured","mission_event":b.mission.has_event("lhm_han_captured"),"hp_before":hp_before,"hp_after":han.hp,"damage_ticks":damage_ticks,"hp_modified":false,"actor_injected":false,"stats_modified":false,"ordinary_level_one_q_learning_fixture":learned_q_fixture,"contact_positions_fixture":true,"nonparticipants_frozen":true,"defender_frozen_until_capture":true,"time_scale":Engine.time_scale,"signals":signals,"chapter_seconds":b.level.elapsed})
	# Actual original Hu, explicit resolution fixture. This does not claim chapter
	# victory/retreat threshold: only existing hidden-retreated rendering/callback.
	var hu_id: int = hu.get_instance_id()
	check(hu.resolve_story("retreated"), "explicit original-Hu retreat fixture resolves")
	check(hu.get_instance_id() == hu_id and hu.hp > 0 and not hu._dying and not hu.visible and b.mission.has_event("lhm_hu_fled"), "retreated original Hu stays alive, hidden and records existing callback")
	await _art_screenshot(b,"hu_retreated",hu)
	await _captured_matrix(b)
	var other = b.spawn_at("han_tao",1,cell+Vector2i(2,0))
	other.set_physics_process(false)
	other.resolve_story("subdued") # Other-outcome appearance fixture.
	check(other._story_animation_frames().is_empty(), "subdued Han does not borrow wrist-bound capture pose")
	await _dispose(b)

func _run() -> void:
	if not _art_profile_guard():
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	Engine.time_scale = 1.0
	art_character = "han_tao"
	art_manifest_path = OS.get_environment("ART_MANIFEST")
	art_output = OS.get_environment("ART_QA_OUT")
	art_visual = OS.get_environment("ART_VISUAL") == "1"
	check(art_output.is_absolute_path(), "explicit external QA output")
	DirAccess.make_dir_recursive_absolute(art_output)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(art_manifest_path))
	check(parsed is Dictionary, "captured manifest loaded")
	if not parsed is Dictionary:
		_art_finish()
		return
	art_manifest = parsed
	if art_visual:
		root.unfocusable = true; root.size = Vector2i(1440,960)
		root.content_scale_size = root.size
		DisplayServer.window_set_size(root.size)
	await process_frame
	_capture_contracts()
	art_identity_before = _art_identity()
	if failures.is_empty(): await _actual_capture()
	art_identity_after = _art_identity()
	check(art_identity_before.get("source_sha256") == art_identity_after.get("source_sha256") and art_identity_before.get("file_count") == art_identity_after.get("file_count"), "installed source identity unchanged across captured QA")
	_art_finish()
