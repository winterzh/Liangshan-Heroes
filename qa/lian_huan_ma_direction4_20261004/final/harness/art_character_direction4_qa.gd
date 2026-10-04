extends "res://tools/zhujiazhuang_rts_test.gd"
## Melee damage is resolved in physics. Capture its exact tick before a slow
## render frame/timer can advance the attacker into recovery.
class MeleeHitProbe extends Node:
	var attacker
	var target
	var previous_hp: float
	var captured := false
	var frame: Texture2D
	var lunge := 0.0
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(attacker) or not is_instance_valid(target): return
		if target.hp < previous_hp:
			var art = get_tree().root.get_node("Art")
			frame = attacker._anim_frame_for_state(art.unit_texture(attacker.key))
			lunge = attacker._lunge
			captured = true
		previous_hp = target.hp

class SiegeReleaseProbe extends Node:
	var attacker
	var target
	var captured := false
	var frame: Texture2D
	var kind := ""
	var phase := 0.0
	var authored := false
	var swing_scale := -1.0
	var direction := ""
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(attacker) or not is_instance_valid(target): return
		for projectile in attacker.battle.fx_root.get_children():
			if projectile.get_script() == null or projectile.get_script().resource_path != "res://scripts/projectile.gd": continue
			if projectile.get("shooter") != attacker or projectile.get("target") != target: continue
			frame = get_tree().root.get_node("Art").unit_texture(attacker.key)
			frame = attacker._anim_frame_for_state(frame)
			kind = projectile.kind
			phase = 1.0 - attacker._lunge
			authored = attacker._authored_direction4_attack_active()
			swing_scale = attacker._programmatic_swing_scale()
			direction = attacker.animation_direction
			captured = true
			return
## Candidate only: copy into a frozen private project's tools/ before running.
## ART_CHARACTER=sun_li|hu_sanniang|guan_zhanzi|hu_yanzhuo|wu_yong|hua_rong|yang_zhi|lu_junyi|guan_sheng|qin_ming|chao_gai
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

func _art_states() -> Array:
	return ["idle", "walk", "attack", "death"] if art_character == "siege_cata" else ART_STATES

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
	for state in _art_states():
		check(states.has(state) and not states.get(state, []).is_empty(), "manifest has authored " + state)
	if art_character != "siege_cata":
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
		for state in _art_states():
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
		var down_frames: Array = art.unit_anim_frames(art_character, "down", direction)
		if art_character == "gou_lian":
			# Hook already owns explicit nonfatal down PNGs. Preserve that
			# separate story route; empty-down is only a missing-source check.
			check(down_frames.size() == 1 and _texture_source(down_frames[0]) == "res://assets/anim/gou_lian_down_" + direction + ".png", "Hook explicit nonfatal down keeps separate legacy source: " + direction)
			check(not down_frames.is_empty() and _texture_source(down_frames[0]) != _texture_source(art.unit_anim_frames(art_character, "death", direction)[-1]), "Hook nonfatal down does not borrow authored death: " + direction)
		else:
			check(down_frames.is_empty(), "living down cannot borrow death: " + direction)
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

func _lu_campaign_priority(b) -> void:
	# Explicit live-actor appearance fixtures, not a full Daming chapter run.
	var art = root.get_node("Art")
	for variant in ["bound_lu_junyi", "rescued_lu_junyi", "daming_bound_lu_junyi", "daming_rescued_lu_junyi"]:
		var u = b.spawn_at("lu_junyi", 0, Vector2i(18, 36))
		u.set_physics_process(false)
		u.set_process(false)
		u.art_variant = variant
		u.is_captive = variant in ["bound_lu_junyi", "daming_bound_lu_junyi"]
		u.is_noncombat = true
		u.atk = 0.0
		u.ability_slots.clear()
		u.passive = true
		check(_texture_source(u.ui_portrait_texture()) == "res://assets/characters/hero_portraits_commanders_20260926/lu_junyi.png", "Lu story UI retains standard identity portrait: " + variant)
		check(_texture_source(art.avatar_texture("lu_junyi", variant)) == "res://assets/campaign/portraits/" + variant + ".png", "Lu story portrait source preview retained: " + variant)
		check(not u._authored_direction4_attack_active(), "Lu story actor excludes generic authored combat: " + variant)
		for direction in ART_DIRS:
			u.animation_direction = direction
			for state in ["idle", "walk", "hurt", "attack"]:
				var frames: Array = art.unit_anim_frames("lu_junyi", state, direction, variant)
				check(not frames.is_empty() and _texture_source(frames[0]).begins_with("res://assets/campaign/anim/" + variant), "Lu story action priority: " + variant + "/" + state + "/" + direction)
				if state in ["idle", "walk"]:
					u._move_blend = 1.0 if state == "walk" else 0.0
					u._anim_t = 0.0
					var actual = u._anim_frame_for_state(art.unit_texture(u.key, variant, direction))
					check(_texture_source(actual).begins_with("res://assets/campaign/anim/" + variant), "Lu real actor selects story body: " + variant + "/" + state + "/" + direction)
			check(art.unit_anim_frames("lu_junyi", "death", direction, variant).is_empty(), "Lu missing story death excludes generic armour: " + variant + "/" + direction)
			check(art.unit_anim_frames("lu_junyi", "down", direction, variant).is_empty(), "Lu story down excludes generic death: " + variant + "/" + direction)
		b.units.erase(u)
		b._grid_build()
		u.queue_free()
		await process_frame

func _qin_bound_priority(b) -> void:
	# Use the chapter's actual binding/release functions on an explicit actor fixture.
	# This verifies appearance compatibility, not the complete rescue mission.
	var chapter = load("res://scripts/levels/level3_zhujiazhuang.gd").new()
	var art = root.get_node("Art")
	var cell := _clear_art_patch(b)
	check(cell.x >= 0, "Qin bound appearance patch exists")
	if cell.x < 0: return
	var u = b.spawn_at("qin_ming", 2, cell)
	u.set_physics_process(false)
	u.auto_micro = false
	chapter._bind_captive(u)
	check(u.is_bound_person() and u.art_variant == "bound_qin_ming" and u.is_noncombat and is_zero_approx(u.base_speed) and is_zero_approx(u.atk) and u.ability_slots.is_empty(), "Qin actual chapter bind retains captive restrictions")
	check(_texture_source(u.ui_portrait_texture()) == "res://assets/characters/hero_portraits_aligned_20260926/qin_ming.png", "Qin bound UI retains current identity")
	u._move_blend = 0.0
	u._lunge = 0.0
	for direction in ART_DIRS:
		u.animation_direction = direction
		var bound_frames: Array = art.unit_anim_frames("qin_ming", "idle", direction, "bound_qin_ming")
		var generic_frames: Array = art.unit_anim_frames("qin_ming", "idle", direction)
		check(not bound_frames.is_empty() and _texture_pose(bound_frames[0]) == _texture_pose(generic_frames[0]), "Qin registered programmatic bound keeps own four-way body: " + direction)
		check(art.unit_texture("guan_sheng", "bound_qin_ming", direction) == null and art.unit_anim_frames("guan_sheng", "idle", direction, "bound_qin_ming").is_empty(), "Qin bound alias rejects another character: " + direction)
		var actual = u._anim_frame_for_state(art.unit_texture(u.key, u.art_variant, direction))
		check(u._frame_directional and _texture_pose(actual) == _texture_pose(generic_frames[0]) and not u._authored_direction4_attack_active(), "Qin real captive uses own idle and excludes generic combat display: " + direction)
		u.queue_redraw()
		await _art_screenshot(b, "qin_bound_" + direction, u)
	chapter._release_captive(u)
	check(not u.is_bound_person() and not u.is_noncombat and u.art_variant.is_empty() and is_equal_approx(u.base_speed, 80.0) and is_equal_approx(u.atk, 14.0), "Qin actual chapter release restores current movement/stats and clears bound variant")
	for direction in ART_DIRS:
		u.animation_direction = direction
		u._move_blend = 1.0
		u._anim_t = 0.0
		var actual = u._anim_frame_for_state(art.unit_texture(u.key, "", direction))
		var expected: Array = art.unit_anim_frames("qin_ming", "walk", direction)
		check(u._frame_directional and _texture_pose(actual) == _texture_pose(expected[0]), "Qin actual released actor uses current authored walk: " + direction)
		if direction in ["sw", "ne"]:
			u.queue_redraw()
			await _art_screenshot(b, "qin_released_" + direction, u)
	b.units.erase(u)
	b._grid_build()
	u.queue_free()
	await process_frame

func _chao_chapter_identity() -> void:
	# Real chapter opening actors; no mission clear or branch completion claimed.
	var art = root.get_node("Art")
	var b = await _start("", 0)
	_freeze_nonparticipants(b)
	var u = b.find_unit("chao_gai")
	check(u != null and b.level.get_script().resource_path == "res://scripts/levels/level1_huangnigang_short.gd" and u.art_variant == "hn_chao_gai", "Chao actual Huangnigang opening keeps story outfit")
	if u != null:
		check(_texture_source(u.ui_portrait_texture()) == "res://assets/characters/art_full_20260916/chao_gai_portrait_20260916.png", "Chao story HUD keeps standard identity")
		check(_texture_source(art.avatar_texture("chao_gai", "hn_chao_gai")) == "res://assets/campaign/portraits/hn_chao_gai.png", "Chao source preview keeps shirtless story portrait")
		check(not u._authored_direction4_attack_active(), "Chao story outfit excludes generic authored combat")
		for direction in ART_DIRS:
			u.animation_direction = direction
			u._move_blend = 0.0
			u._lunge = 0.0
			for state in ["idle", "walk", "attack", "hurt"]:
				var frames: Array = art.unit_anim_frames("chao_gai", state, direction, "hn_chao_gai")
				check(not frames.is_empty() and _texture_source(frames[0]).begins_with("res://assets/campaign/anim/hn_chao_gai_"), "Chao actual story action source stays shirtless: " + state + "/" + direction)
			check(art.unit_anim_frames("chao_gai", "death", direction, "hn_chao_gai").is_empty() and art.unit_anim_frames("chao_gai", "down", direction, "hn_chao_gai").is_empty(), "Chao missing story terminal never borrows generic dark clothing: " + direction)
			var actual = u._anim_frame_for_state(art.unit_texture(u.key, u.art_variant, direction))
			check(_texture_source(actual).begins_with("res://assets/campaign/anim/hn_chao_gai_idle_"), "Chao real chapter idle actor retains story source: " + direction)
			u.queue_redraw()
			await _art_screenshot(b, "chao_hn_" + direction, u)
			u._move_blend = 1.0
			u._anim_t = 0.0
			actual = u._anim_frame_for_state(art.unit_texture(u.key, u.art_variant, direction))
			check(_texture_source(actual).begins_with("res://assets/campaign/anim/hn_chao_gai_walk_"), "Chao real chapter walking actor retains story source: " + direction)
			if direction in ["sw", "ne"]:
				u.queue_redraw()
				await _art_screenshot(b, "chao_hn_walk_" + direction, u)
	await _dispose(b)
	b = await _start("", 1)
	_freeze_nonparticipants(b)
	u = b.find_unit("chao_gai")
	check(u != null and b.level.get_script().resource_path == "res://scripts/levels/level2_jiangzhou_rts.gd" and u.art_variant.is_empty(), "Chao actual Jiangzhou opening uses generic family")
	if u != null:
		check(_texture_source(u.ui_portrait_texture()) == "res://assets/characters/art_full_20260916/chao_gai_portrait_20260916.png", "Chao actual Jiangzhou retains matching standard portrait")
		for direction in ART_DIRS:
			u.animation_direction = direction
			u._move_blend = 0.0
			u._lunge = 0.0
			var actual = u._anim_frame_for_state(art.unit_texture(u.key, "", direction))
			var frames: Array = art.unit_anim_frames("chao_gai", "idle", direction)
			check(u._frame_directional and _texture_pose(actual) == _texture_pose(frames[0]), "Chao real Jiangzhou actor uses matching authored idle: " + direction)
			if direction in ["sw", "ne"]:
				u.queue_redraw()
				await _art_screenshot(b, "chao_jiang_" + direction, u)
	await _dispose(b)

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

func _zhu_actual_training() -> void:
	var b = await _start()
	var level = b.level
	check(level.get_script().resource_path == "res://scripts/levels/level3_zhujiazhuang_rts.gd" and level.ai_trained == 0, "Zhu actual current chapter starts before enemy training")
	for troop in ["zhu_keke", "zhu_gong", "zhu_qi"]:
		var cost_key := "liang_dao" if troop == "zhu_keke" else "liang_gong" if troop == "zhu_gong" else "liang_ma"
		for field in ["cost_gold", "cost_wood", "pop"]:
			check(b._defs[troop].get(field, 0) == b._defs[cost_key].get(field, 0), "Zhu actual chapter retains local training cost: " + troop + "/" + field)
	# Actual opening and subsequent timers at normal time: no clock edits,
	# injected units or direct calls to the enemy training implementation.
	for tick in range(420):
		if level.ai_trained >= 3: break
		await _wait(0.5)
	var keys: Array = []
	var rider = null
	for u in level.trained:
		if is_instance_valid(u):
			keys.append(u.key)
			if u.key == art_character: rider = u
	check(level.ai_trained >= 3 and keys.slice(0, 3) == ["zhu_keke", "zhu_gong", "zhu_qi"], "Zhu natural chapter training creates the actual ordered roster")
	check(level.ai_spent_gold > 0 and level.ai_spent_wood > 0, "Zhu natural enemy training spends actual faction resources")
	check(rider != null and rider.faction == 1 and b.units.has(rider) and rider.art_variant.is_empty(), "Zhu actual enemy " + art_character + " actor has generic authored outfit")
	art_runtime.append({"case":"zhu_natural_training", "trained":level.ai_trained, "roster":keys, "chapter_seconds":level.elapsed, "gold_spent":level.ai_spent_gold, "wood_spent":level.ai_spent_wood, "timers_modified":false, "actor_injected":false})
	if rider != null:
		_freeze_nonparticipants(b) # Appearance fixture only after natural training.
		b.fog = false
		# Disabling sight updates does not hide the existing opaque fog canvas.
		# This is only the post-training appearance fixture, not gameplay vision.
		if is_instance_valid(b._fog_layer): b._fog_layer.hide()
		check(not is_instance_valid(b._fog_layer) or not b._fog_layer.visible, "Zhu appearance fixture removes opaque fog overlay after natural training")
		rider.fog_visible = true
		rider.show()
		b.select_single(rider, false)
		var art = root.get_node("Art")
		check(_texture_source(rider.ui_portrait_texture()) == "res://assets/portraits5.png", "Zhu actual enemy HUD keeps current portrait atlas")
		for direction in ART_DIRS:
			rider.animation_direction = direction
			rider._move_blend = 0.0
			rider._lunge = 0.0
			var frames: Array = art.unit_anim_frames(art_character, "idle", direction)
			var actual = rider._anim_frame_for_state(art.unit_texture(art_character))
			check(not frames.is_empty() and _texture_pose(actual) == _texture_pose(frames[0]), "Zhu naturally trained actor uses exact new facing: " + direction)
			rider.queue_redraw()
			await _art_screenshot(b, "zhu_actual_" + direction, rider)
			check(rider.is_visible_in_tree() and not rider.garrisoned, "Zhu naturally trained actor is rendered in chapter capture: " + direction)
	await _dispose(b)

func _hook_actual_training() -> void:
	var b = await _start("", 3)
	var level = b.level
	check(level.get_script().resource_path == "res://scripts/levels/level4_lianhuanma_rts.gd", "Hook actual current chapter entry")
	var art = root.get_node("Art")
	var initial: Array = b.units.filter(func(u): return alive(u) and u.faction == 0 and u.key == "gou_lian")
	var initial_ids: Array = initial.map(func(u): return u.get_instance_id())
	check(initial.size() == 2 and level.riders.size() == 12, "Hook actual chapter opening roster retained")
	var barracks = b.units.filter(func(u): return alive(u) and u.faction == 0 and u.key == "barracks")[0]
	check(b._defs.gou_lian.pop == 2 and b._defs.gou_lian.cost_gold == 36 and b._defs.gou_lian.cost_wood == 24 and is_equal_approx(b.train_time_for("gou_lian"), 20.0), "Hook chapter recruitment cost/pop/20-second timer retained")
	var gold_before: int = b.gold
	var wood_before: int = b.wood
	check(b.queue_train(barracks, "gou_lian", false), "Hook real barracks accepts ordinary recruitment")
	check(b.gold == gold_before - 36 and b.wood == wood_before - 24 and is_equal_approx(barracks._train_t, 20.0), "Hook real enqueue spends exact resources and sets normal timer")
	var started: float = level.elapsed
	var soldier = null
	# Let the actual production queue create the actor; no injected actor,
	# altered production timer, clock or direct on_unit_trained call.
	for tick in range(100):
		var created: Array = b.units.filter(func(u): return alive(u) and u.faction == 0 and u.key == "gou_lian" and not initial_ids.has(u.get_instance_id()))
		if not created.is_empty():
			soldier = created[0]
			break
		await _wait(0.5)
	check(soldier != null and level.elapsed - started >= 19.9 and barracks._train_queue.is_empty(), "Hook real 20-second queue creates actual new infantry")
	art_runtime.append({"case":"hook_natural_training", "chapter_seconds":level.elapsed, "queue_seconds":level.elapsed-started, "gold_spent":36, "wood_spent":24, "pop":2, "timers_modified":false, "actor_injected":false})
	if soldier == null:
		await _dispose(b)
		return
	_freeze_nonparticipants(b) # Appearance/combat fixture starts after recruitment.
	b.fog = false
	if is_instance_valid(b._fog_layer): b._fog_layer.hide()
	soldier.fog_visible = true
	soldier.show()
	b.select_single(soldier, false)
	check(_texture_pose(soldier.ui_portrait_texture()) == _texture_pose(art.ui_portrait_texture("gou_lian")), "Hook naturally recruited actor uses exact current portrait cell")
	for direction in ART_DIRS:
		soldier.animation_direction = direction
		soldier._move_blend = 0.0
		soldier._lunge = 0.0
		var frames: Array = art.unit_anim_frames("gou_lian", "idle", direction)
		check(not frames.is_empty() and _texture_pose(soldier._anim_frame_for_state(art.unit_texture("gou_lian"))) == _texture_pose(frames[0]), "Hook naturally recruited actor uses exact authored facing: " + direction)
		soldier.queue_redraw()
		await _art_screenshot(b, "hook_actual_" + direction, soldier)
		check(soldier.is_visible_in_tree() and not soldier.garrisoned, "Hook actual recruited actor visible: " + direction)
	# Controlled positioning/slow fixture with actors already created by this
	# chapter. Production chapter process and attack commands remain live.
	var cell := _clear_art_patch(b)
	check(cell.x >= 0, "Hook controlled cooperative patch exists")
	if cell.x >= 0:
		var origin: Vector2 = b.map.cell_to_world(cell)
		var rider = level.riders[0]
		var neighbor = level.riders[1]
		var partner = initial[0]
		var inv = load("res://scripts/game_map.gd").ISO_INV
		soldier.position = origin
		rider.position = origin + inv * Vector2(28, 14)
		neighbor.position = rider.position + Vector2(100, 0)
		partner.position = origin + Vector2(240, 0)
		for actor in [rider, neighbor, partner]:
			actor.fog_visible = true
			actor.show()
		rider.apply_slow(0.7, 10.0) # Explicit impediment fixture, not natural victory.
		await _wait(0.35)
		check(level._hook_team(b, rider).size() == 1 and not bool(rider.get_meta("formation_broken", false)) and rider._damage_reduction_sources.has(level.LINK_SOURCE), "Hook one nearby gunner does not break linked rider")
		var hp_before: float = rider.hp
		soldier.auto_micro = false
		soldier.set_physics_process(true)
		var probe := MeleeHitProbe.new()
		probe.attacker = soldier
		probe.target = rider
		probe.previous_hp = hp_before
		probe.process_physics_priority = 1000
		root.add_child(probe)
		soldier.order_attack(rider, false, true)
		for tick in range(160):
			await _wait(0.025)
			if probe.captured: break
		check(probe.captured and rider.hp < hp_before and not bool(rider.get_meta("formation_broken", false)), "Hook real single-gunner cavalry hit retains formation")
		check(is_equal_approx(soldier.bonus_vs_cav, 3.5) and is_equal_approx(soldier._hit_at, 0.45) and is_equal_approx(soldier._swing_speed, 2.8), "Hook anti-cavalry multiplier and spear hit timing retained in actual chapter")
		var direction: String = soldier.animation_direction
		var attack_frames: Array = art.unit_anim_frames("gou_lian", "attack", direction)
		check(probe.captured and _texture_pose(probe.frame) == _texture_pose(attack_frames[1]), "Hook actual chapter cavalry hit uses authored strike frame")
		var single_damage: float = hp_before - rider.hp
		probe.queue_free()
		soldier.set_physics_process(false)
		soldier.order_stop()
		partner.position = rider.position + Vector2(0, 40)
		# A live eligible partner need only cover the contacting attacker; the
		# existing chapter rule does not require both partners to hit together.
		soldier.order_attack(rider, false, true)
		for tick in range(80):
			if bool(rider.get_meta("formation_broken", false)): break
			await _wait(0.025)
		check(level._hook_team(b, rider).size() == 2 and bool(rider.get_meta("formation_broken", false)), "Hook two eligible gunners and actual contact break impeded rider through normal chapter tick")
		check(level.broken_count == 1 and not rider._damage_reduction_sources.has(level.LINK_SOURCE) and is_equal_approx(rider.temp_speed, 0.45), "Hook cooperative break removes link reduction and applies existing slow")
		art_runtime.append({"case":"hook_cooperative_fixture", "actors_injected":false, "positioning_fixture":true, "impediment_fixture":true, "chapter_tick_called_directly":false, "single_hook_damage":single_damage, "single_hook_broken":false, "two_hooks_broken":bool(rider.get_meta("formation_broken",false)), "broken_count":level.broken_count, "damage_multiplier":soldier.bonus_vs_cav})
		soldier.set_physics_process(true)
		await _art_screenshot(b, "hook_coordinated", soldier)
	await _dispose(b)


func _lian_actual_link() -> void:
	var b = await _start("", 3)
	var level = b.level
	var art = root.get_node("Art")
	check(level.get_script().resource_path == "res://scripts/levels/level4_lianhuanma_rts.gd" and level.riders.size() == 12, "Linked rider actual chapter deploys all twelve original actors")
	var hooks: Array = b.units.filter(func(u): return alive(u) and u.faction == 0 and u.key == "gou_lian")
	check(hooks.size() == 2 and level.waves[0].time == 150.0 and level.waves[1].time == 270.0, "Linked rider actual opening and wave timers retained")
	for actor in level.riders:
		check(alive(actor) and actor.key == "lian_huan_ma" and actor.faction == 1 and not bool(actor.get_meta("formation_broken", true)) and actor.get_meta("wave_state") == "waiting", "Original linked cavalry opening identity and formation")
	# Controlled appearance/contact fixture after authentic deployment.
	# No injected rider, direct level tick, modified wave timer or victory.
	_freeze_nonparticipants(b)
	b.fog = false
	if is_instance_valid(b._fog_layer): b._fog_layer.hide()
	var rider = level.riders[0]
	rider.fog_visible = true
	rider.show()
	var portrait := _texture_pose(rider.ui_portrait_texture())
	check(portrait == _texture_pose(art.ui_portrait_texture("lian_huan_ma")), "Original enemy rider retains current exact portrait")
	for direction in ART_DIRS:
		rider.animation_direction = direction
		rider._move_blend = 0.0
		rider._lunge = 0.0
		var frames: Array = art.unit_anim_frames("lian_huan_ma", "idle", direction)
		check(_texture_pose(rider._anim_frame_for_state(art.unit_texture("lian_huan_ma"))) == _texture_pose(frames[0]), "Original chapter rider uses authored facing: " + direction)
		rider.queue_redraw()
		await _art_screenshot(b, "lian_actual_" + direction, rider)
	var cell := _clear_art_patch(b)
	check(cell.x >= 0, "Linked rider controlled contact patch exists")
	if cell.x >= 0:
		var origin: Vector2 = b.map.cell_to_world(cell)
		var inv = load("res://scripts/game_map.gd").ISO_INV
		var soldier = hooks[0]
		var partner = hooks[1]
		var neighbor = level.riders[1]
		soldier.position = origin
		rider.position = origin + inv * Vector2(28, 14)
		neighbor.position = rider.position + Vector2(100, 0)
		partner.position = origin + Vector2(240, 0)
		for actor in [soldier, partner, neighbor]:
			actor.fog_visible = true
			actor.show()
		rider.apply_slow(0.7, 10.0) # Explicit impediment fixture.
		await _wait(0.35)
		check(level._hook_team(b, rider).size() == 1 and rider._damage_reduction_sources.has(level.LINK_SOURCE), "Original rider with nearby unbroken neighbor receives linked reduction")
		await _art_screenshot(b, "lian_linked", rider)
		var hp_before: float = rider.hp
		soldier.auto_micro = false
		soldier.set_physics_process(true)
		soldier.order_attack(rider, false, true)
		for tick in range(160):
			if rider.hp < hp_before: break
			await _wait(0.025)
		check(rider.hp < hp_before and not bool(rider.get_meta("formation_broken", false)), "Single actual hook hit damages original rider without breaking formation")
		var damage: float = hp_before - rider.hp
		soldier.set_physics_process(false)
		soldier.order_stop()
		partner.position = rider.position + Vector2(0, 40)
		soldier.order_attack(rider, false, true)
		for tick in range(80):
			if bool(rider.get_meta("formation_broken", false)): break
			await _wait(0.025)
		check(level._hook_team(b, rider).size() == 2 and bool(rider.get_meta("formation_broken", false)), "Two eligible actual hooks and contact break original rider through normal chapter process")
		check(level.broken_count == 1 and rider.get_meta("wave_state") == "broken" and not rider._damage_reduction_sources.has(level.LINK_SOURCE) and is_equal_approx(rider.temp_speed, 0.45), "Existing break removes linked reduction and applies existing slow/state")
		check(alive(rider) and not rider._dying and rider.max_hp == 300.0 and rider.atk == 15.0 and rider.base_speed == 118.0 and _texture_pose(rider.ui_portrait_texture()) == portrait, "Formation break keeps living cavalry stats and portrait")
		rider._flinch = Vector2.ZERO
		rider._move_blend = 0.0
		rider._lunge = 0.0
		var frames: Array = art.unit_anim_frames("lian_huan_ma", "idle", rider.animation_direction)
		check(_texture_pose(rider._anim_frame_for_state(art.unit_texture("lian_huan_ma"))) == _texture_pose(frames[0]), "Living broken rider retains authored body rather than death pose")
		rider.queue_redraw()
		await _art_screenshot(b, "lian_broken", rider)
		# The 1.5-second story illustration can obscure the living actor. Let
		# it expire normally, then prove this same broken rider still attacks.
		await _wait(2.0)
		var probe := MeleeHitProbe.new()
		probe.attacker = rider
		probe.target = soldier
		probe.previous_hp = soldier.hp
		probe.process_physics_priority = 1000
		root.add_child(probe)
		var hook_hp_before: float = soldier.hp
		rider.auto_micro = false
		rider.set_physics_process(true)
		rider.order_attack(soldier, false, true)
		for tick in range(160):
			if probe.captured: break
			await _wait(0.025)
		var strike_frames: Array = art.unit_anim_frames("lian_huan_ma", "attack", rider.animation_direction)
		check(probe.captured and soldier.hp < hook_hp_before and alive(rider) and bool(rider.get_meta("formation_broken", false)), "Original broken rider remains alive and deals normal melee damage")
		check(probe.captured and _texture_pose(probe.frame) == _texture_pose(strike_frames[1]) and is_equal_approx(rider._hit_at, 0.45) and is_equal_approx(rider._swing_speed, 2.8), "Original broken rider normal hit selects authored spear strike with retained timing")
		var post_break_damage: float = hook_hp_before - soldier.hp
		var post_break_authored_hit: bool = probe.captured
		probe.queue_free()
		rider.set_physics_process(false)
		rider.order_stop()
		rider._lunge = 0.0
		rider._move_blend = 0.0
		rider.queue_redraw()
		await _art_screenshot(b, "lian_broken_alive", rider)
		art_runtime.append({"case":"lian_actual_link_fixture", "actors_injected":false, "positioning_fixture":true, "impediment_fixture":true, "chapter_tick_called_directly":false, "wave_timers_modified":false, "single_hook_damage":damage, "single_hook_broken":false, "two_hooks_broken":bool(rider.get_meta("formation_broken", false)), "broken_count":level.broken_count, "living_rider_after_break":alive(rider), "post_break_damage":post_break_damage, "post_break_authored_hit":post_break_authored_hit, "story_illustration":"Existing temporary broken_cavalry narrative illustration retained; it expires normally before living actor capture. Not a new death animation or full chapter clear."})
	await _dispose(b)

func _art_orders(b) -> void:
	if art_character == "siege_cata":
		await _siege_orders(b)
		return
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
		check(u != null and u.is_cavalry == (not art_character in ["guan_zhanzi", "wu_yong", "hua_rong", "yang_zhi", "lu_junyi", "qin_ming", "chao_gai", "zhu_gong", "zhu_keke", "gou_lian"]), "expected mounted or infantry body: " + direction)
		if u == null: continue
		if art_character == "chao_gai":
			check(not u.is_cavalry and not u.is_ranged and u.is_hero and is_equal_approx(u.max_hp, 300.0) and is_equal_approx(u.atk, 19.0) and is_equal_approx(u.atk_cd, 0.85) and is_equal_approx(u.atk_range, 28.0) and is_equal_approx(u.base_speed, 80.0), "Chao existing melee infantry stats retained: " + direction)
			check(u.setup_def.get("ability", "") == "chao_rally" and u.setup_def.get("aura", "") == "atk" and is_equal_approx(float(u.setup_def.get("aura_r", 0.0)), 180.0) and is_equal_approx(float(u.setup_def.get("aura_p", 0.0)), 1.25), "Chao existing rally/aura retained: " + direction)
		if art_character == "zhu_qi":
			check(u.is_cavalry and not u.is_hero and not u.is_ranged and is_equal_approx(u.max_hp, 200.0) and is_equal_approx(u.atk, 13.0) and is_equal_approx(u.atk_cd, 1.0) and is_equal_approx(u.atk_range, 26.0) and is_equal_approx(u.base_speed, 110.0), "Zhu ordinary mounted gameplay stats retained: " + direction)
			check(u._weapon_kind() == u.WK.SWORD and u.setup_def.get("weapon_profile", "").is_empty() and u._attack_sfx_name() == "atk_spear", "Zhu visual spear sound preserves existing gameplay weapon inference: " + direction)
			check(_texture_source(u.ui_portrait_texture()) == "res://assets/portraits5.png" and _texture_pose(u.ui_portrait_texture()) == _texture_pose(art.ui_portrait_texture("zhu_qi")), "Zhu current portrait atlas identity retained: " + direction)
		if art_character == "zhu_gong":
			check(not u.is_cavalry and not u.is_hero and u.is_ranged and is_equal_approx(u.max_hp, 60.0) and is_equal_approx(u.atk, 9.0) and is_equal_approx(u.atk_cd, 1.4) and is_equal_approx(u.atk_range, 180.0) and is_equal_approx(u.base_speed, 64.0), "Zhu ordinary archer gameplay stats retained: " + direction)
			check(u._weapon_kind() == u.WK.BOW and u.setup_def.get("weapon_profile", "").is_empty() and u._attack_sfx_name() == "atk_bow", "Zhu ordinary archer bow and sound retained: " + direction)
			check(_texture_source(u.ui_portrait_texture()) == "res://assets/portraits5.png" and _texture_pose(u.ui_portrait_texture()) == _texture_pose(art.ui_portrait_texture("zhu_gong")), "Zhu archer current portrait atlas identity retained: " + direction)
		if art_character == "zhu_keke":
			check(not u.is_cavalry and not u.is_hero and not u.is_ranged and is_equal_approx(u.max_hp, 95.0) and is_equal_approx(u.atk, 11.0) and is_equal_approx(u.atk_cd, 1.0) and is_equal_approx(u.atk_range, 24.0) and is_equal_approx(u.base_speed, 66.0), "Zhu ordinary manor infantry gameplay stats retained: " + direction)
			check(u._weapon_kind() == u.WK.SWORD and u.setup_def.get("weapon_profile", "").is_empty() and u._attack_sfx_name() == "atk_sword", "Zhu ordinary manor infantry sword and sound retained: " + direction)
			check(_texture_source(u.ui_portrait_texture()) == "res://assets/portraits5.png" and _texture_pose(u.ui_portrait_texture()) == _texture_pose(art.ui_portrait_texture("zhu_keke")), "Zhu manor infantry current portrait atlas identity retained: " + direction)
		if art_character == "gou_lian":
			check(not u.is_cavalry and not u.is_hero and not u.is_ranged and is_equal_approx(u.max_hp, 105.0) and is_equal_approx(u.atk, 11.0) and is_equal_approx(u.atk_cd, 1.1) and is_equal_approx(u.atk_range, 30.0) and is_equal_approx(u.base_speed, 68.0) and is_equal_approx(u.bonus_vs_cav, 3.5), "Hook ordinary anti-cavalry gameplay stats retained: " + direction)
			check(u._weapon_kind() == u.WK.SPEAR and u.setup_def.get("weapon_profile", "").is_empty() and u._attack_sfx_name() == "atk_spear", "Hook inferred spear and sound retained: " + direction)
			check(_texture_source(u.ui_portrait_texture()) == "res://assets/portraits8.png" and art.PORTRAIT8_CELLS.gou_lian == Vector2i(2, 1) and _texture_pose(u.ui_portrait_texture()) == _texture_pose(art.ui_portrait_texture("gou_lian")), "Hook exact current portrait atlas cell retained: " + direction)
		if art_character == "lian_huan_ma":
			check(u.is_cavalry and not u.is_hero and not u.is_ranged and is_equal_approx(u.max_hp, 300.0) and is_equal_approx(u.atk, 15.0) and is_equal_approx(u.atk_cd, 1.0) and is_equal_approx(u.atk_range, 26.0) and is_equal_approx(u.base_speed, 118.0) and is_equal_approx(u.radius, 13.0), "Linked rider ordinary cavalry stats retained: " + direction)
			check(u._weapon_kind() == u.WK.SPEAR and u.setup_def.get("weapon_profile", "").is_empty() and u._attack_sfx_name() == "atk_spear", "Linked rider key-specific spear and sound retained: " + direction)
			check(_texture_source(u.ui_portrait_texture()) == "res://assets/portraits9.png" and art.PORTRAIT9_CELLS.lian_huan_ma == Vector2i(1, 0) and _texture_pose(u.ui_portrait_texture()) == _texture_pose(art.ui_portrait_texture("lian_huan_ma")), "Linked rider exact current portrait cell retained: " + direction)
		if art_character == "qin_ming":
			check(not u.is_cavalry and u.is_ranged and u.is_hero and is_equal_approx(u.max_hp, 180.0) and is_equal_approx(u.atk, 14.0) and is_equal_approx(u.atk_cd, 1.15) and is_equal_approx(u.atk_range, 220.0) and is_equal_approx(u.base_speed, 80.0), "Qin existing ranged infantry stats retained: " + direction)
			check(u.setup_def.get("proj_kind", "") == "magic" and u.setup_def.get("abilities", []) == ["qin_ming_q", "qin_ming_w", "qin_ming_e", "qin_ming_r"], "Qin existing projectile and ability kit retained: " + direction)
		if art_character == "guan_sheng":
			check(u.is_cavalry and u.is_hero and is_equal_approx(u.max_hp, 480.0) and is_equal_approx(u.atk, 32.0) and is_equal_approx(u.atk_cd, 0.95) and is_equal_approx(u.atk_range, 30.0) and is_equal_approx(u.base_speed, 108.0), "Guan existing mounted gameplay stats retained: " + direction)
			check(u.setup_def.get("abilities", []) == ["guan_sheng_q", "guan_sheng_w", "guan_sheng_e", "guan_sheng_r"], "Guan existing ability kit retained: " + direction)
		u.auto_micro = false
		var start_id: int = u.get_instance_id()
		b.select_single(u, false)
		if art_character in ["zhu_qi", "zhu_gong", "zhu_keke", "gou_lian", "lian_huan_ma"]:
			await process_frame
			check(b.hud._port_tex.texture == u.ui_portrait_texture(), "Zhu selected HUD keeps current portrait cell: " + direction)
		if art_character in ["hu_yanzhuo", "wu_yong", "hua_rong", "yang_zhi", "lu_junyi", "guan_sheng", "qin_ming", "chao_gai"]:
			await process_frame
			var identity_path := "res://assets/characters/hero_portraits_20260926/wu_yong.png" if art_character == "wu_yong" else "res://assets/characters/hu_yanzhuo_direction4_20261003/portrait.png"
			if art_character == "hua_rong": identity_path = "res://assets/characters/hero_portraits_aligned_20260926/hua_rong.png"
			if art_character == "yang_zhi": identity_path = "res://assets/characters/hero_portraits_aligned_20260926/yang_zhi.png"
			if art_character == "lu_junyi": identity_path = "res://assets/characters/hero_portraits_commanders_20260926/lu_junyi.png"
			if art_character == "guan_sheng": identity_path = "res://assets/characters/hero_portraits_aligned_20260926/guan_sheng.png"
			if art_character == "qin_ming": identity_path = "res://assets/characters/hero_portraits_aligned_20260926/qin_ming.png"
			if art_character == "chao_gai": identity_path = "res://assets/characters/art_full_20260916/chao_gai_portrait_20260916.png"
			check(u.ui_portrait_texture().resource_path == identity_path, "real unit identity portrait: " + direction)
			check(b.hud._port_tex.texture == u.ui_portrait_texture(), "selected HUD uses matching identity: " + direction)
		b.minimap_order(origin + map_script.ISO_INV * vectors[index], false)
		await _wait(0.65)
		var selected_frame = u._anim_frame_for_state(art.unit_texture(art_character))
		check(u.position.distance_to(origin) > 4 and u.animation_direction == direction, "real movement and facing: " + direction)
		check(u._frame_directional and not selected_frame == null, "real moving frame uses authored direction: " + direction)
		await _art_screenshot(b, "walk_" + direction, u)
		u.order_stop()
		var ranged := art_character in ["wu_yong", "hua_rong", "qin_ming", "zhu_gong"]
		check(u.is_ranged == ranged, "existing attack class retained: " + direction)
		var target = b.spawn_unit("guan_dao", 1, u.position + map_script.ISO_INV * vectors[index].normalized() * (120 if ranged else 28))
		target.passive = true
		target.set_physics_process(false)
		var hp_before: float = target.hp
		var hit_probe: MeleeHitProbe
		if not ranged:
			hit_probe = MeleeHitProbe.new()
			hit_probe.attacker = u
			hit_probe.target = target
			hit_probe.previous_hp = hp_before
			hit_probe.process_physics_priority = 1000 # After the actual unit tick.
			root.add_child(hit_probe)
		u.order_attack(target, false, true)
		var projectile_released := false
		for tick in range(160):
			await _wait(0.025)
			if ranged:
				projectile_released = b.fx_root.get_children().any(func(p): return p.get_script() != null and p.get_script().resource_path == "res://scripts/projectile.gd" and p.get("shooter") == u and p.get("target") == target)
				if projectile_released: break
			elif target.hp < hp_before and u._lunge > 0: break
		check(projectile_released if ranged else target.hp < hp_before, "normal attack releases projectile or deals melee damage: " + direction)
		if art_character in ["zhu_qi", "zhu_keke"]:
			check(is_equal_approx(u._swing_speed, 2.1) and is_equal_approx(u._hit_at, 0.48), "Zhu existing ordinary attack timing retained: " + direction)
		if art_character in ["gou_lian", "lian_huan_ma"]:
			check(is_equal_approx(u._swing_speed, 2.8) and is_equal_approx(u._hit_at, 0.45), "Hook existing ordinary spear attack timing retained: " + direction)
		if art_character == "zhu_gong":
			check(is_equal_approx(u._swing_speed, 1.9) and is_equal_approx(u._hit_at, 0.42), "Zhu existing ordinary bow attack timing retained: " + direction)
			check(b.fx_root.get_children().any(func(p): return p.get_script() != null and p.get_script().resource_path == "res://scripts/projectile.gd" and p.get("shooter") == u and p.get("target") == target and p.get("kind") == "arrow"), "Zhu real ordinary arrow projectile retained: " + direction)
		if art_character == "qin_ming":
			check(b.fx_root.get_children().any(func(p): return p.get_script() != null and p.get_script().resource_path == "res://scripts/projectile.gd" and p.get("shooter") == u and p.get("target") == target and p.get("kind") == "magic"), "Qin real magic projectile kind retained: " + direction)
		check(u.animation_direction == direction, "attack locks real facing: " + direction)
		selected_frame = u._anim_frame_for_state(art.unit_texture(art_character))
		var attack_frames: Array = art.unit_anim_frames(art_character, "attack", direction)
		var expected_hit_slot := clampi(int((1.0 - u._hit_at) * attack_frames.size()), 0, attack_frames.size() - 1)
		if not ranged: selected_frame = hit_probe.frame
		check((ranged or hit_probe.captured) and _texture_pose(selected_frame) == _texture_pose(attack_frames[expected_hit_slot]), "actual attack release selects manifest strike phase: " + direction)
		check(u._authored_direction4_attack_active() and is_zero_approx(u._programmatic_swing_scale()) and not u._should_draw_programmatic_swing_fx(), "no duplicate full-body swing or weapon trail: " + direction)
		var release_pose := _texture_pose(selected_frame)
		var release_lunge: float = u._lunge
		if not ranged:
			release_lunge = hit_probe.lunge
			hit_probe.queue_free()
		if ranged:
			check(target.hp == hp_before, "projectile travels before damage: " + direction)
			await _art_screenshot(b, "release_" + direction, u)
			u.order_stop()
			for tick in range(160):
				await _wait(0.025)
				if target.hp < hp_before: break
		check(target.hp < hp_before, "normal attack causes actual target damage: " + direction)
		art_runtime.append({"case": "ranged" if ranged else "melee", "direction": direction, "damage": hp_before - target.hp, "projectile_released": projectile_released, "lunge": release_lunge, "hit_at": u._hit_at, "sampled_pose": release_pose, "expected_hit_slot": expected_hit_slot})
		await _art_screenshot(b, ("ranged_" if ranged else "melee_") + direction, u)
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

func _siege_orders(b) -> void:
	_freeze_nonparticipants(b)
	var cell := _clear_art_patch(b)
	check(cell.x >= 0, "clear mechanical movement patch exists")
	if cell.x < 0: return
	var origin: Vector2 = b.map.cell_to_world(cell)
	var art = root.get_node("Art")
	var map_script = load("res://scripts/game_map.gd")
	var vectors := [Vector2(96, 48), Vector2(-96, 48), Vector2(96, -48), Vector2(-96, -48)]
	for index in range(4):
		var direction: String = ART_DIRS[index]
		var u = b.spawn_unit("siege_cata", 0, origin)
		check(u != null and u.is_ranged and not u.is_cavalry and not u.is_hero, "existing mechanical ranged class: " + direction)
		if u == null: continue
		check(is_equal_approx(u.max_hp, 260.0) and is_equal_approx(u.atk, 47.0) and is_equal_approx(u.atk_cd, 3.0) and is_equal_approx(u.atk_range, 280.0) and is_equal_approx(u.base_speed, 32.0), "existing catapult stats retained: " + direction)
		check(u.setup_def.get("trained_at", "") == "siege_workshop" and int(u.setup_def.get("min_age", 0)) == 3 and int(u.setup_def.get("pop", 0)) == 3 and is_equal_approx(float(u.setup_def.get("vs_tower", 0)), 3.0) and is_equal_approx(float(u.setup_def.get("vs_hero", 0)), 0.3), "existing production and damage multipliers: " + direction)
		u.auto_micro = false
		b.select_single(u, false)
		await process_frame
		check(b.hud._port_tex.texture == u.ui_portrait_texture(), "selected catapult HUD identity retained: " + direction)
		b.minimap_order(origin + map_script.ISO_INV * vectors[index], false)
		await _wait(0.65)
		var actual = u._anim_frame_for_state(art.unit_texture("siege_cata"))
		var walking: Array = art.unit_anim_frames("siege_cata", "walk", direction)
		check(u.position.distance_to(origin) > 4 and u.animation_direction == direction, "real catapult rolling command and facing: " + direction)
		check(walking.size() == 2 and u._frame_directional and _texture_pose(actual) in [_texture_pose(walking[0]), _texture_pose(walking[1])], "real transport selects reviewed wheel phase: " + direction)
		check(u._authored_catapult_chassis_active(), "authored rigid chassis excludes infantry gait: " + direction)
		await _art_screenshot(b, "walk_" + direction, u)
		u.order_stop()
		var target = b.spawn_unit("guan_dao", 1, u.position + map_script.ISO_INV * vectors[index].normalized() * 120)
		target.passive = true
		target.set_physics_process(false)
		var hp_before: float = target.hp
		var probe := SiegeReleaseProbe.new()
		probe.attacker = u
		probe.target = target
		probe.process_physics_priority = 1000
		root.add_child(probe)
		u.order_attack(target, false, true)
		for tick in range(200):
			await _wait(0.025)
			if probe.captured: break
		var attack: Array = art.unit_anim_frames("siege_cata", "attack", direction)
		check(probe.captured and probe.kind == "boulder", "normal attack releases real boulder: " + direction)
		var release_pose: Dictionary = art_manifest.poses["release_" + direction]
		var release_rect: Array = release_pose.region
		check(attack.size() == 8 and probe.captured and probe.frame is AtlasTexture and _texture_source(probe.frame) == "res://" + art_manifest.sources[release_pose.source].path and probe.frame.region == Rect2(release_rect[0], release_rect[1], release_rect[2], release_rect[3]), "physics release tick selects empty upright spoon: " + direction)
		check(probe.direction == direction and probe.authored and is_zero_approx(probe.swing_scale), "real release keeps facing and excludes bow swing: " + direction)
		await _art_screenshot(b, "release_" + direction, u)
		for tick in range(200):
			await _wait(0.025)
			if target.hp < hp_before: break
		check(target.hp < hp_before, "real boulder lands and damages target: " + direction)
		art_runtime.append({"case": "ranged", "direction": direction, "damage": hp_before - target.hp, "projectile_released": probe.captured, "projectile_kind": probe.kind, "release_phase": probe.phase, "sampled_pose": _texture_pose(probe.frame), "expected_release_pose": "release_" + direction})
		await _art_screenshot(b, "ranged_" + direction, u)
		probe.queue_free()
		var last_facing: String = u.animation_direction
		u.take_damage(u.max_hp * 20.0, null, false, true)
		check(u._dying and not b.units.has(u) and u.animation_direction == last_facing, "mechanical lethal fixture removes combat actor and keeps facing: " + direction)
		await _wait(0.45)
		await _art_screenshot(b, "fall_" + direction, u)
		await _wait(0.42)
		await _art_screenshot(b, "terminal_" + direction, u)
		target.take_damage(target.max_hp * 20.0, null, false, true)
		await _wait(1.55)
		check(not is_instance_valid(u), "mechanical wreck fade releases original actor: " + direction)

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

func _authored_codex() -> void:
	var codex = load("res://scenes/codex.tscn").instantiate()
	root.add_child(codex)
	await process_frame
	codex._select(art_character)
	var art = root.get_node("Art")
	var portrait_path := "res://assets/characters/%s_direction4_%s/portrait.png" % [art_character, "20261003" if art_character == "hu_yanzhuo" else "20260915"]
	if art_character == "wu_yong": portrait_path = "res://assets/characters/hero_portraits_20260926/wu_yong.png"
	if art_character == "hua_rong": portrait_path = "res://assets/characters/hero_portraits_aligned_20260926/hua_rong.png"
	if art_character == "yang_zhi": portrait_path = "res://assets/characters/hero_portraits_aligned_20260926/yang_zhi.png"
	if art_character == "lu_junyi": portrait_path = "res://assets/characters/hero_portraits_commanders_20260926/lu_junyi.png"
	if art_character == "guan_sheng": portrait_path = "res://assets/characters/hero_portraits_aligned_20260926/guan_sheng.png"
	if art_character == "qin_ming": portrait_path = "res://assets/characters/hero_portraits_aligned_20260926/qin_ming.png"
	if art_character == "chao_gai": portrait_path = "res://assets/characters/art_full_20260916/chao_gai_portrait_20260916.png"
	if art_character in ["zhu_qi", "zhu_gong", "zhu_keke"]: portrait_path = "res://assets/portraits5.png"
	if art_character == "gou_lian": portrait_path = "res://assets/portraits8.png"
	if art_character == "lian_huan_ma": portrait_path = "res://assets/portraits9.png"
	check(_texture_source(art.portrait_texture(art_character)) == portrait_path, "new identity portrait route")
	check(not codex._port.frames.is_empty() and _texture_source(codex._port.frames[0]) == portrait_path, "actual codex uses new identity portrait")
	if art_character in ["zhu_qi", "zhu_gong", "zhu_keke", "gou_lian", "lian_huan_ma"]:
		check(not codex._port.frames.is_empty() and _texture_pose(codex._port.frames[0]) == _texture_pose(art.portrait_texture(art_character)), "Zhu actual codex keeps exact current portrait cell")
	for index in range(4):
		codex._direction_picker.item_selected.emit(index)
		await process_frame
		var direction: String = ART_DIRS[index]
		check(codex._cur == art_character and codex._direction_index == index and not codex._direction_picker.disabled, "codex connected direction selection: " + direction)
		for state in ["walk", "attack"]:
			var box = codex._walk if state == "walk" else codex._atk
			var frames: Array = art.unit_anim_frames(art_character, state, direction)
			check(box.frames.size() == frames.size(), "codex exact action count: " + state + direction)
			for i in range(mini(box.frames.size(), frames.size())):
				check(_texture_pose(box.frames[i]) == _texture_pose(frames[i]), "codex exact authored action: " + state + direction + str(i))
		await _art_screenshot(null, "codex_" + direction)
	codex.queue_free()
	await process_frame
	if art_character in ["hu_yanzhuo", "wu_yong", "hua_rong", "yang_zhi", "lu_junyi", "guan_sheng", "qin_ming", "chao_gai", "zhu_qi", "zhu_gong", "zhu_keke", "gou_lian", "lian_huan_ma"]:
		var canvas := Control.new()
		root.add_child(canvas)
		var bg := ColorRect.new()
		bg.color = Color("29291f")
		bg.size = Vector2(root.size)
		canvas.add_child(bg)
		var x := 20.0
		for side in [48, 96, 192, 320]:
			var box := TextureRect.new()
			box.texture = art.ui_portrait_texture(art_character)
			box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			box.position = Vector2(x, 80)
			box.size = Vector2(side, side)
			canvas.add_child(box)
			x += side + 35
		await process_frame
		await _art_screenshot(null, "portrait_sizes")
		canvas.queue_free()
		await process_frame

func _matrix_rows() -> Array:
	var rows: Array = []
	for state in _art_states():
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
	check(art_character in ["sun_li", "hu_sanniang", "guan_zhanzi", "hu_yanzhuo", "wu_yong", "hua_rong", "yang_zhi", "lu_junyi", "guan_sheng", "qin_ming", "chao_gai", "siege_cata", "zhu_qi", "zhu_gong", "zhu_keke", "gou_lian", "lian_huan_ma"], "supported selected character")
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
	if art_character == "lu_junyi": await _lu_campaign_priority(b)
	if art_character == "qin_ming": await _qin_bound_priority(b)
	if art_character == "sun_li": await _sun_rider_cast(b)
	await _pose_matrix(b)
	await _dispose(b)
	if art_character == "chao_gai": await _chao_chapter_identity()
	if art_character in ["zhu_qi", "zhu_gong", "zhu_keke"]: await _zhu_actual_training()
	if art_character == "gou_lian": await _hook_actual_training()
	if art_character == "lian_huan_ma": await _lian_actual_link()
	if art_character == "sun_li": await _sun_contact()
	elif art_character == "hu_sanniang": await _hu_live_capture()
	elif art_character != "siege_cata": await _authored_codex()
	art_identity_after = _art_identity()
	check(art_identity_before.get("source_sha256") == art_identity_after.get("source_sha256") and art_identity_before.get("file_count") == art_identity_after.get("file_count"), "installed content identity unchanged during character QA")
	_art_finish()
