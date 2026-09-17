extends "res://tools/zhujiazhuang_rts_test.gd"
## Candidate only: copy into a frozen private project's tools/ before running.
## ART_CHARACTER=sun_li|hu_sanniang, ART_MANIFEST=res://assets/direction4/...json
## ART_QA_OUT must be outside installed source roots; ART_VISUAL=1 enables real renders.
## ART_QA_PROFILE is required and must own APPDATA/LOCALAPPDATA/TEMP/TMP.
## Target dummies, pose matrices and nonparticipants are explicit frozen fixtures.
## Movement, melee, Sun R and chapter contact/capture use normal runtime commands.

const ART_DIRS := ["se", "sw", "ne", "nw"]
const ART_STATES := ["idle", "walk", "attack", "hurt", "death"]
var art_character := ""
var art_manifest_path := ""
var art_output := ""
var art_visual := false
var art_manifest: Dictionary = {}
var art_rows: Array = []
var art_runtime: Array = []
var art_images: Array = []
var art_identity_before: Dictionary = {}
var art_identity_after: Dictionary = {}
var art_profile_proof: Dictionary = {}

func _art_profile_guard() -> bool:
	# The Python runner establishes this boundary before production autoloads.
	# Verify it before opening our report or creating any character fixtures.
	var profile := OS.get_environment("ART_QA_PROFILE").replace("\\", "/").simplify_path()
	var safe := profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	var actual_paths := {}
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		var actual := OS.get_environment(key).replace("\\", "/").simplify_path()
		actual_paths[key] = actual
		safe = safe and actual.to_lower() == (profile + "/" + key.to_lower()).to_lower()
	var user_path := OS.get_user_data_dir().replace("\\", "/").simplify_path()
	safe = safe and user_path.to_lower().begins_with((profile + "/appdata/").to_lower())
	safe = safe and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA") == "1"
	art_profile_proof = {"passed": safe, "profile": profile, "actual_environment": actual_paths, "user_data_dir": user_path}
	if not safe: print("ART_CHARACTER_QA PRIVATE_PROFILE_REQUIRED")
	return safe

func _texture_source(frame) -> String:
	if frame is AtlasTexture: return frame.atlas.resource_path if frame.atlas != null else ""
	return frame.resource_path if frame != null else ""

func _texture_pose(frame) -> String:
	return _texture_source(frame) + (str(frame.region) if frame is AtlasTexture else "")

func _art_finish() -> void:
	var result := {
		"character": art_character, "manifest": art_manifest_path,
		"checks": checks, "passed": failures.is_empty(), "failures": failures,
		"resources": art_rows, "runtime": art_runtime, "screenshots": art_images,
		"identity_before": art_identity_before, "identity_after": art_identity_after,
		"private_profile": art_profile_proof,
		"visual": art_visual, "engine_time_scale": Engine.time_scale,
		"render_window": {"position": [root.position.x, root.position.y], "unfocusable": root.unfocusable},
		"scope": "Isolated character resource/command/render fixtures at normal time. Not a chapter clear, balance, save/restore or long performance acceptance."
	}
	var f := FileAccess.open(art_output.path_join("report.json"), FileAccess.WRITE)
	if f == null:
		push_error("Cannot write character QA report")
		quit(1)
		return
	f.store_string(JSON.stringify(result, "\t") + "\n")
	print("[art-character] ", art_character, " ", checks, " checks; failures=", failures)
	quit(0 if failures.is_empty() else 1)

func _art_identity() -> Dictionary:
	var provider = load("res://scripts/run_content_identity.gd").new()
	var result: Dictionary = provider.resolve_runtime_identity()
	check(bool(result.get("ok", false)), "installed content identity resolves")
	if not bool(result.get("ok", false)): return result
	var selected: Array = art_manifest.get("resources", []).duplicate()
	for source in art_manifest.get("sources", {}).values(): selected.append(source.path)
	for raw in selected:
		var relative := String(raw).trim_prefix("res://")
		check(provider._files.has(relative), "new character file included in installed identity: " + relative)
	return result

func _art_contracts() -> void:
	var art = root.get_node("Art")
	check(String(art_manifest.get("character", "")) == art_character, "manifest belongs to selected character")
	var states: Dictionary = art_manifest.get("states", {})
	for state in ART_STATES:
		check(states.has(state) and not states.get(state, []).is_empty(), "manifest has authored " + state)
	check(states.get("hurt", []).size() == 1, "hurt manifest has the single recoil frame consumed by Unit")
	if not failures.is_empty(): return
	for source in art_manifest.get("sources", {}).values():
		var path := "res://" + String(source.path).trim_prefix("res://")
		check(FileAccess.get_sha256(path) == String(source.sha256), "native source SHA: " + path)
		var tex = load(path)
		check(tex is Texture2D, "source imports as Texture2D: " + path)
		if tex is Texture2D:
			check(tex.get_width() == int(source.imported_size[0]) and tex.get_height() == int(source.imported_size[1]), "actual imported dimensions: " + path)
	for direction in ART_DIRS:
		for state in ART_STATES:
			var path := "res://assets/anim/%s_%s_%s.tres" % [art_character, state, direction]
			var frames: Array = art.unit_anim_frames(art_character, state, direction)
			var order: Array = states[state]
			check(art._resolve_generic_directional_path(art_character, state, direction) == path, "exact TRES routing: " + state + " " + direction)
			check(frames.size() == order.size(), "manifest frame count: " + state + " " + direction)
			check(art.unit_anim_uses_directional_source(art_character, state, direction), "authored direction is not mirrored: " + state + " " + direction)
			if frames.size() != order.size(): continue
			var ids: Array = []
			for index in range(frames.size()):
				var frame = frames[index]
				var pose_key: String = String(order[index]) + "_" + String(direction)
				check(art_manifest.poses.has(pose_key), "pose present: " + pose_key)
				if not art_manifest.poses.has(pose_key): continue
				var pose: Dictionary = art_manifest.poses[pose_key]
				var expected_source: Dictionary = art_manifest.sources[pose.source]
				check(frame is AtlasTexture and frame.get_width() == frame.get_height(), "square AtlasTexture: " + pose_key)
				if not frame is AtlasTexture: continue
				check(_texture_source(frame) == "res://" + String(expected_source.path).trim_prefix("res://"), "exact source: " + pose_key)
				var r: Array = pose.region
				var m: Array = pose.margin
				var o: Array = pose.draw_offset_px
				check(frame.region == Rect2(r[0], r[1], r[2], r[3]) and frame.margin == Rect2(m[0], m[1], m[2], m[3]) and frame.filter_clip, "exact crop/padding and clipping: " + pose_key)
				var actual_offset: Variant = frame.get_meta("draw_offset_px") if frame.has_meta("draw_offset_px") else null
				check(actual_offset is Vector2 and actual_offset.distance_to(Vector2(o[0], o[1])) <= 0.00002 and bool(frame.get_meta("authored_direction4", false)), "authored ground metadata within 0.00002 texture pixels: " + pose_key)
				check(is_equal_approx(float(frame.get_meta("draw_scale", 1.0)), float(pose.get("draw_scale", 1.0))), "pose body scale: " + pose_key)
				ids.append(_texture_pose(frame))
			art_rows.append({"state": state, "direction": direction, "frames": ids, "resource_sha256": FileAccess.get_sha256(path)})
		check(art.unit_anim_frames(art_character, "down", direction).is_empty(), "living down cannot borrow death: " + direction)
	check(art.unit_anim_frames(art_character, "idle", "north").is_empty(), "invalid direction rejected")
	# One small shared isolation check; no complete unrelated world restore suite.
	for pair in [["lin_chong", "lin_chong_prisoner"], ["song_jiang", "song_jiang_bound"]]:
		var vf: Array = art.unit_anim_frames(pair[0], "idle", "se", pair[1])
		check(not vf.is_empty() and _texture_source(vf[0]).begins_with("res://assets/campaign/anim/" + pair[1]), "existing campaign costume priority: " + pair[1])
		check(art.unit_anim_frames(pair[0], "death", "se", pair[1]).is_empty(), "existing missing campaign death does not borrow generic: " + pair[1])

func _freeze_nonparticipants(b) -> void:
	for u in b.units:
		if is_instance_valid(u):
			u.passive = true
			u.order_stop()
			u.set_physics_process(false)

func _clear_art_patch(b) -> Vector2i:
	for x in range(8, b.map.w - 8):
		for y in range(8, b.map.h - 8):
			var cell := Vector2i(x, y)
			var open := true
			for dx in range(-3, 4):
				for dy in range(-3, 4):
					if not b.map.is_open_world(b.map.cell_to_world(cell + Vector2i(dx, dy))): open = false
					# Traversable forest still conceals the body; choose an existing
					# open surface for readable movement evidence without editing terrain.
					if b.map.t_at(x + dx, y + dy) in [b.map.T.FOREST, b.map.T.REEDS, b.map.T.MARSH]: open = false
			if not open: continue
			var pos: Vector2 = b.map.cell_to_world(cell)
			if b.units.any(func(u): return is_instance_valid(u) and u.position.distance_to(pos) < 180): continue
			return cell
	return Vector2i(-1, -1)

func _art_screenshot(b, name: String, subject = null) -> void:
	if not art_visual: return
	if subject != null and is_instance_valid(subject):
		b.fog = false
		b.camera.zoom = Vector2.ONE * 2.7
		b.center_camera_cell(b.map.world_to_cell(subject.position))
	await RenderingServer.frame_post_draw
	var path := art_output.path_join(name + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "real rendered screenshot: " + name)
	art_images.append({"name": name, "path": path, "sha256": FileAccess.get_sha256(path)})

func _art_orders(b) -> void:
	_freeze_nonparticipants(b)
	var cell := _clear_art_patch(b)
	check(cell.x >= 0, "clear live movement patch exists")
	if cell.x < 0: return
	var origin: Vector2 = b.map.cell_to_world(cell)
	var art = root.get_node("Art")
	var map_script = load("res://scripts/game_map.gd")
	var vectors := [Vector2(96, 48), Vector2(-96, 48), Vector2(96, -48), Vector2(-96, -48)]
	for index in range(4):
		var direction: String = ART_DIRS[index]
		var u = b.spawn_unit(art_character, 0, origin)
		check(u != null and u.is_cavalry == (art_character != "guan_zhanzi"), "expected mounted or infantry body: " + direction)
		if u == null: continue
		u.auto_micro = false
		var start_id: int = u.get_instance_id()
		b.select_single(u, false)
		b.minimap_order(origin + map_script.ISO_INV * vectors[index], false)
		await _wait(0.65)
		var selected_frame = u._anim_frame_for_state(art.unit_texture(art_character))
		check(u.position.distance_to(origin) > 4 and u.animation_direction == direction, "real movement and facing: " + direction)
		check(u._frame_directional and not selected_frame == null, "real moving frame uses authored direction: " + direction)
		await _art_screenshot(b, "walk_" + direction, u)
		u.order_stop()
		var target = b.spawn_unit("guan_dao", 1, u.position + map_script.ISO_INV * vectors[index].normalized() * 28)
		target.passive = true
		target.set_physics_process(false)
		var hp_before: float = target.hp
		u.order_attack(target, false, true)
		for tick in range(160):
			await _wait(0.025)
			if target.hp < hp_before and u._lunge > 0: break
		check(target.hp < hp_before, "normal melee command deals damage: " + direction)
		check(u.animation_direction == direction, "melee locks real facing: " + direction)
		selected_frame = u._anim_frame_for_state(art.unit_texture(art_character))
		var attack_frames: Array = art.unit_anim_frames(art_character, "attack", direction)
		var expected_hit_slot := clampi(int((1.0 - u._hit_at) * attack_frames.size()), 0, attack_frames.size() - 1)
		check(_texture_pose(selected_frame) == _texture_pose(attack_frames[expected_hit_slot]), "actual hit lands in manifest strike phase: " + direction)
		check(u._authored_direction4_attack_active() and is_zero_approx(u._programmatic_swing_scale()) and not u._should_draw_programmatic_swing_fx(), "no duplicate full-body swing or weapon trail: " + direction)
		art_runtime.append({"case": "melee", "direction": direction, "damage": hp_before - target.hp, "lunge": u._lunge, "hit_at": u._hit_at, "sampled_pose": _texture_pose(selected_frame), "expected_hit_slot": expected_hit_slot})
		await _art_screenshot(b, "melee_" + direction, u)
		u.take_damage(7, target, false, true) # Explicit controlled incoming-hit fixture.
		var hurt_frames: Array = art.unit_anim_frames(art_character, "hurt", direction)
		check(_texture_pose(u._anim_frame_for_state(art.unit_texture(art_character))) == _texture_pose(hurt_frames[0]), "incoming damage selects authored recoil: " + direction)
		await _art_screenshot(b, "hurt_" + direction, u)
		var death_direction: String = u.animation_direction
		u.take_damage(u.max_hp * 20.0, null, false, true) # Explicit lethal fixture, not a combat victory.
		check(u._dying and not b.units.has(u) and u.get_instance_id() == start_id, "lethal hit removes original combat actor: " + direction)
		check(u.animation_direction == death_direction, "death retains last facing: " + direction)
		await _wait(0.45)
		await _art_screenshot(b, "fall_" + direction, u)
		await _wait(0.42)
		await _art_screenshot(b, "terminal_" + direction, u)
		target.take_damage(target.max_hp * 20.0, null, false, true)
		await _wait(1.55)
		check(not is_instance_valid(u), "death releases after terminal fade: " + direction)

func _sun_rider_cast(b) -> void:
	var cell := _clear_art_patch(b)
	check(cell.x >= 0, "clear real summon patch exists")
	if cell.x < 0: return
	var caster = b.spawn_at("sun_li", 0, cell)
	caster.auto_micro = false
	caster.restore_progress(6, 0.0, 1, [0, 0, 0, 0]) # Explicit level-six ability fixture.
	check(caster.can_learn(3), "Sun R becomes learnable at existing level requirement")
	caster.learn(3)
	b.select_single(caster, false)
	b._cast_ability_slot(3)
	var riders: Array = []
	for tick in range(100):
		await _wait(0.025)
		riders = b.units.filter(func(u): return is_instance_valid(u) and u.is_summon and u.stat_owner_key == "sun_li")
		if riders.size() == 3: break
	check(riders.size() == 3 and caster.slot_cd_frac(3) > 0.0, "actual player R produces three rider illusions and cooldown")
	var art = root.get_node("Art")
	for rider in riders:
		check(rider.key == "sun_li" and rider.is_cavalry and not rider.is_hero and rider.ability_slots.is_empty(), "rider keeps owner art/type without recursive hero abilities")
		check(is_equal_approx(rider.max_hp, caster.max_hp * 0.5) and is_equal_approx(rider.atk, caster.atk * 0.5), "rider preserves rank-one copy stats")
		check(rider._summon_ttl > 0 and rider._summon_ttl <= 22.0, "rider retains bounded existing lifetime")
		rider.set_physics_process(false)
		for direction in ART_DIRS:
			rider.animation_direction = direction
			rider._lunge = 0.45 # Explicit copied-actor drawing fixture after real R.
			var frame = rider._anim_frame_for_state(art.unit_texture("sun_li"))
			var expected: Array = art.unit_anim_frames("sun_li", "attack", direction)
			check(rider._frame_directional and _texture_pose(frame) == _texture_pose(expected[int(0.55 * expected.size())]), "real rider uses owner attack: " + direction)
			check(rider._authored_direction4_attack_active() and is_zero_approx(rider._programmatic_swing_scale()), "real rider does not restore old swing: " + direction)
	await _art_screenshot(b, "sun_real_riders", caster)
	for rider in riders: b.despawn_summon(rider)
	caster.take_damage(caster.max_hp * 20.0, null, false, true)
	await _wait(1.55)

func _sun_contact() -> void:
	var b = await _start()
	_freeze_nonparticipants(b)
	var level = b.level
	level._introduce_sun(b) # Explicit branch setup; actual actor moves normally afterward.
	var sun = level.sun
	var action: Dictionary = b.mission.actions.zhu_rts_inside
	check(sun != null and sun.art_variant.is_empty(), "current chapter Sun uses generic character family")
	check(action.actors == ["sun_li", "song_jiang", "lin_chong", "hua_rong"] and is_equal_approx(float(action.duration), 5.0), "current four-hero contact rule is retained")
	var initial: Vector2 = sun.position
	action.actor_button.pressed.emit()
	check(b.selection == [sun] and sun.position == initial and not sun.mission_order_active, "actor locator selects actual Sun without moving him")
	b.select_single(sun, false)
	b._issue_order(b.to_screen(b.map.cell_to_world(action.cell)) + Vector2(0, -22), false)
	for tick in range(240):
		await _wait(0.25)
		if b.mission.active_action_id == "zhu_rts_inside": break
	check(b.mission.active_action_id == "zhu_rts_inside" and sun.position.distance_to(initial) > 4, "real Sun walks from his arrival position and begins contact")
	if b.mission.active_action_id == "zhu_rts_inside":
		await _wait(0.5)
		check(not level.inside_open, "contact remains incomplete before five seconds")
		b._stamp_manual([sun])
		sun.order_hold_position()
		await _wait(5.5)
		check(not level.inside_open and b.mission.active_action_id.is_empty(), "manual hold cancels contact without automatic resumption")
		b.select_single(sun, false)
		b._issue_order(b.to_screen(b.map.cell_to_world(action.cell)) + Vector2(0, -22), false)
		for tick in range(80):
			await _wait(0.25)
			if level.inside_open: break
	check(level.inside_open and bool(action.done) and b.mission.has_event("zhu_gate_opened"), "fresh real Sun order holds and opens side gate")
	check(alive(level.gate), "inside contact preserves intact main gate")
	await _art_screenshot(b, "sun_actual_contact", sun)
	await _dispose(b)

func _hu_live_capture() -> void:
	var b = await _start()
	_freeze_nonparticipants(b)
	var hu = b.level.hu
	var instance_id: int = hu.get_instance_id()
	check(hu.key == "hu_sanniang" and hu.art_variant.is_empty() and hu.defeat_outcome == "captured", "actual chapter Hu uses generic art and nonlethal capture")
	# Nonparticipants and defender are frozen. The attacker still uses normal
	# target acquisition, animation time and repeated melee damage; no HP edits.
	var attacker = b.spawn_unit("lin_chong", 0, hu.position + Vector2(34, 0))
	attacker.auto_micro = false
	attacker.order_attack(hu, false, true)
	for tick in range(320):
		await _wait(0.25)
		if hu.story_outcome == "captured": break
	check(hu.story_outcome == "captured" and hu.hp > 0 and not hu._dying, "normal melee damage actually captures living Hu")
	check(hu.get_instance_id() == instance_id and hu.faction == 1 and b.units.has(hu), "capture retains the same enemy actor without recruitment")
	check(b.mission.has_event("zhu_hu_captured"), "normal chapter callback records Hu capture")
	check(is_zero_approx(hu._lunge) and is_zero_approx(hu._cast_t), "capture cancels pending combat animation")
	var art = root.get_node("Art")
	for direction in ART_DIRS:
		check(art.unit_anim_frames("hu_sanniang", "down", direction).is_empty(), "captured branch cannot select death as down: " + direction)
		hu.animation_direction = direction # Explicit 4-view captured-pose render fixture.
		hu.queue_redraw()
		await _art_screenshot(b, "hu_captured_" + direction, hu)
	await _wait(1.55)
	check(is_instance_valid(hu) and not hu._dying and hu.hp > 0 and hu.story_outcome == "captured", "captured Hu remains present after normal death duration")
	await _dispose(b)

func _executioner_codex() -> void:
	var codex = load("res://scenes/codex.tscn").instantiate()
	root.add_child(codex)
	await process_frame
	codex._select("guan_zhanzi")
	var art = root.get_node("Art")
	for index in range(4):
		codex._direction_picker.item_selected.emit(index)
		await process_frame
		var direction: String = ART_DIRS[index]
		check(codex._cur == "guan_zhanzi" and codex._direction_index == index and not codex._direction_picker.disabled, "codex connected direction selection: " + direction)
		for state in ["walk", "attack"]:
			var box = codex._walk if state == "walk" else codex._atk
			var frames: Array = art.unit_anim_frames("guan_zhanzi", state, direction)
			check(box.frames.size() == frames.size(), "codex exact action count: " + state + direction)
			for i in range(mini(box.frames.size(), frames.size())):
				check(_texture_pose(box.frames[i]) == _texture_pose(frames[i]), "codex exact authored action: " + state + direction + str(i))
		await _art_screenshot(null, "codex_" + direction)
	codex.queue_free()
	await process_frame

func _matrix_rows() -> Array:
	var rows: Array = []
	for state in ART_STATES:
		var seen: Array = []
		var order: Array = art_manifest.states[state]
		for index in range(order.size()):
			if order[index] in seen: continue
			seen.append(order[index])
			rows.append({"state": state, "index": index, "count": order.size(), "pose": order[index]})
	return rows

func _pose_matrix(b) -> void:
	if not art_visual: return
	var rows := _matrix_rows()
	b.phase = b.Phase.DEPLOY
	b.world.hide()
	b.hud.hide()
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("29291f")
	background.size = Vector2(root.size)
	canvas.add_child(background)
	var art_world := Node2D.new()
	art_world.transform = load("res://scripts/game_map.gd").ISO.scaled(Vector2.ONE * 2.3)
	canvas.add_child(art_world)
	# Paginate to preserve useful pixel scale rather than squeeze all rows.
	for page in range(int(ceil(float(rows.size()) / 4.0))):
		var page_nodes: Array = []
		for ri in range(page * 4, mini((page + 1) * 4, rows.size())):
			var row: Dictionary = rows[ri]
			var label := Label.new()
			label.text = String(row.state) + "/" + String(row.pose)
			label.position = Vector2(12, 130 + (ri % 4) * 210)
			canvas.add_child(label)
			page_nodes.append(label)
			for col in range(4):
				var ground := Vector2(290 + col * 280, 210 + (ri % 4) * 210)
				var u = b.spawn_at(art_character, 0, Vector2i(18, 36))
				b.units.erase(u)
				u.reparent(art_world, false)
				u.position = art_world.transform.affine_inverse() * ground
				u.set_physics_process(false)
				u.set_process(false)
				u.animation_direction = ART_DIRS[col]
				u.face_left = col in [1, 3]
				u.display_name = ART_DIRS[col]
				u.fog_visible = true
				var phase: float = (float(row.index) + 0.1) / float(row.count)
				u._idle_t = phase * TAU / 1.4 if row.state == "idle" else 0.0
				u._move_blend = 1.0 if row.state == "walk" else 0.0
				u._anim_t = phase * TAU if row.state == "walk" else 0.0
				u._lunge = 1.0 - phase if row.state == "attack" else 0.0
				u._flinch = Vector2(2, 0) if row.state == "hurt" else Vector2.ZERO
				u._dying = row.state == "death"
				if u._dying:
					u.hp = 0
					u._death_t = u.DEATH_DUR * phase
				u.selected = not u._dying
				u.show()
				u.queue_redraw()
				page_nodes.append(u)
		await process_frame
		await _art_screenshot(b, "unit_pose_matrix_" + str(page + 1))
		for node in page_nodes: node.queue_free()
		await process_frame
	canvas.queue_free()
	await process_frame
	b.world.show()
	b.hud.show()

func _run() -> void:
	if not _art_profile_guard():
		quit(2)
		return
	OS.set_environment("CAMPAIGN_QA", "1")
	AudioServer.set_bus_mute(0, true)
	Engine.time_scale = 1.0
	art_character = OS.get_environment("ART_CHARACTER")
	art_manifest_path = OS.get_environment("ART_MANIFEST")
	art_output = OS.get_environment("ART_QA_OUT")
	art_visual = OS.get_environment("ART_VISUAL") == "1"
	if art_output.is_empty(): art_output = "res://.godot/art_character_direction4/" + art_character
	DirAccess.make_dir_recursive_absolute(art_output)
	check(art_character in ["sun_li", "hu_sanniang", "guan_zhanzi"], "supported selected character")
	check(not art_manifest_path.is_empty() and FileAccess.file_exists(art_manifest_path), "explicit candidate manifest exists")
	if not failures.is_empty():
		_art_finish()
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(art_manifest_path))
	check(parsed is Dictionary, "manifest JSON is a dictionary")
	if not parsed is Dictionary:
		_art_finish()
		return
	art_manifest = parsed
	if art_visual:
		root.unfocusable = true
		root.size = Vector2i(1440, 960)
		root.content_scale_size = root.size
		DisplayServer.window_set_size(root.size)
	await process_frame
	_art_contracts()
	if not failures.is_empty():
		_art_finish()
		return
	art_identity_before = _art_identity()
	if not failures.is_empty():
		_art_finish()
		return
	var b = await _start("skirmish", 4)
	await _art_orders(b)
	if art_character == "sun_li": await _sun_rider_cast(b)
	await _pose_matrix(b)
	await _dispose(b)
	if art_character == "sun_li": await _sun_contact()
	elif art_character == "hu_sanniang": await _hu_live_capture()
	else: await _executioner_codex()
	art_identity_after = _art_identity()
	check(art_identity_before.get("source_sha256") == art_identity_after.get("source_sha256") and art_identity_before.get("file_count") == art_identity_after.get("file_count"), "installed content identity unchanged during character QA")
	_art_finish()
