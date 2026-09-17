extends SceneTree
## External editor-host probe against --main-pack. No raw PNG source reads.
## No static project class references before autoloads have initialized.
const CHARACTERS := ["song_jiang", "lin_chong", "sun_li", "hu_sanniang"]
const DIRECTIONS := ["se", "sw", "ne", "nw"]
var checks: Array = []
var failures: Array = []
var portraits: Array = []
var routes: Array = []
var fits: Array = []
var profile_proof: Dictionary = {}
var art
var codex

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"label": label, "passed": ok})
	print("[codex-pack] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func _profile_guard() -> bool:
	var profile := OS.get_environment("ART_QA_PROFILE").replace("\\", "/").simplify_path()
	var safe := profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	var environment := {}
	for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		var actual := OS.get_environment(key).replace("\\", "/").simplify_path()
		environment[key] = actual
		safe = safe and actual.to_lower() == (profile + "/" + String(key).to_lower()).to_lower()
	var user_path := OS.get_user_data_dir().replace("\\", "/").simplify_path()
	safe = safe and user_path.to_lower().begins_with((profile + "/appdata/").to_lower())
	safe = safe and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA") == "1"
	safe = safe and OS.get_environment("PCK_ART_REPORT").is_absolute_path() and OS.get_environment("PCK_ART_PACK").is_absolute_path() and OS.get_environment("PCK_ART_PACK_SHA").length() == 64
	profile_proof = {"passed": safe, "profile": profile, "environment": environment, "user_data_dir": user_path}
	return safe

func _signature(texture) -> Dictionary:
	if not texture is Texture2D: return {}
	var result := {"size": [texture.get_width(), texture.get_height()], "draw_scale": float(texture.get_meta("draw_scale", 1.0)), "authored": bool(texture.get_meta("authored_direction4", false))}
	var offset: Vector2 = texture.get_meta("draw_offset_px", Vector2.ZERO)
	result["offset"] = [offset.x, offset.y]
	if texture is AtlasTexture:
		result["atlas"] = texture.atlas.resource_path if texture.atlas != null else ""
		result["region"] = [texture.region.position.x, texture.region.position.y, texture.region.size.x, texture.region.size.y]
		result["margin"] = [texture.margin.position.x, texture.margin.position.y, texture.margin.size.x, texture.margin.size.y]
		result["filter_clip"] = texture.filter_clip
	else: result["path"] = texture.resource_path
	return result

func _signatures(frames: Array) -> Array:
	var result := []
	for texture in frames: result.append(_signature(texture))
	return result

func _portrait_check() -> void:
	var seen := {}
	for key in CHARACTERS:
		var path: String = "res://assets/characters/codex_portraits_20260913/" + key + ".png"
		check(ResourceLoader.exists(path), "packed portrait remap exists: " + key)
		var texture = art.portrait_texture(key)
		var expected = ResourceLoader.load(path)
		check(art.STANDALONE_PORTRAITS.get(key) == path and texture is Texture2D and not texture is AtlasTexture and texture == expected, "packed standalone full portrait selected: " + key)
		if not texture is Texture2D or texture != expected: continue
		check(texture.get_size() == Vector2(1024, 1024), "actual packed portrait is 1024 square: " + key)
		check(art.avatar_texture(key) == texture, "packed standard HUD avatar shares portrait: " + key)
		var decoded: Image = texture.get_image()
		check(not decoded.is_empty() and decoded.get_size() == Vector2i(1024, 1024), "portrait imports into actual 1024 pixel image: " + key)
		var hasher := HashingContext.new()
		hasher.start(HashingContext.HASH_SHA256)
		hasher.update(decoded.get_data())
		var digest := hasher.finish().hex_encode()
		check(not seen.has(digest), "four packed decoded portraits have distinct pixels: " + key)
		seen[digest] = true
		portraits.append({"character": key, "path": path, "resolved_resource": texture.resource_path, "size": [texture.get_width(), texture.get_height()], "image_format": int(decoded.get_format()), "decoded_pixels_sha256": digest})

func _button_for(node: Node, display: String):
	for child in node.get_children():
		if child is Button and not child is OptionButton and String(child.text).strip_edges().begins_with(display): return child
		var found = _button_for(child, display)
		if found != null: return found
	return null

func _character_check(key: String) -> void:
	var button = _button_for(codex._list_scroll, String(codex._disp_name(key)))
	check(button != null and button.pressed.get_connections().size() > 0, "packed scene has connected character button: " + key)
	if button == null: return
	button.pressed.emit()
	check(codex._cur == key and codex._port.frames.size() == 1 and codex._port.frames[0] == art.portrait_texture(key), "actual packed codex selects correct portrait: " + key)
	var envelope := Rect2()
	var first := true
	var common_ground := Vector2.ZERO
	var common_scale := 0.0
	var minimum_walk := INF
	var directions_seen: Array = []
	for direction_index in range(4):
		var direction: String = DIRECTIONS[direction_index]
		var picker: OptionButton = codex._direction_picker
		check(not picker.disabled and picker.item_count == 4 and picker.item_selected.get_connections().size() > 0, "packed scene enables real four-way selector: " + key)
		picker.select(direction_index)
		picker.item_selected.emit(direction_index)
		check(codex._direction_index == direction_index, "packed selector callback takes exact direction: " + key + "/" + direction)
		await process_frame
		for pair in [["walk", codex._walk], ["attack", codex._atk]]:
			var state: String = pair[0]
			var box = pair[1]
			box.set_process(false)
			var path := "res://assets/anim/%s_%s_%s.tres" % [key, state, direction]
			var resource = ResourceLoader.load(path)
			check(resource is SpriteFrames, "actual packed directional SpriteFrames exists: " + key + "/" + state + "/" + direction)
			if not resource is SpriteFrames: continue
			var expected: Array = []
			for index in range(resource.get_frame_count(&"default")): expected.append(resource.get_frame_texture(&"default", index))
			var displayed: Array = box.frames
			check(not expected.is_empty() and _signatures(displayed) == _signatures(expected) and _signatures(displayed) == _signatures(art.unit_anim_frames(key, state, direction)), "actual packed codex uses exact authored frames: " + key + "/" + state + "/" + direction)
			check(art.unit_anim_uses_directional_source(key, state, direction), "packed direction does not borrow old strip: " + key + "/" + state + "/" + direction)
			routes.append({"character": key, "direction": direction, "state": state, "resource": path, "frames": _signatures(displayed)})
			if state == "walk": directions_seen.append(_signatures(displayed))
			for index in range(displayed.size()):
				var texture: Texture2D = displayed[index]
				var layout: Dictionary = box.frame_layout(index)
				var rect: Rect2 = layout.rect
				var content: Rect2 = layout.content_rect
				var ground: Vector2 = layout.ground
				var scale := rect.size.x / float(texture.get_meta("draw_scale", 1.0))
				var offset: Vector2 = texture.get_meta("draw_offset_px", Vector2.ZERO)
				var pixel_scale := rect.size.x / texture.get_width()
				var projected_ground := rect.position + (texture.get_size() * Vector2(0.5, 0.82) - offset) * pixel_scale
				check(projected_ground.distance_to(ground) <= 0.002, "packed actual frame keeps metadata foot anchor: " + key + "/" + state + "/" + direction + "/" + str(index))
				if first:
					common_ground = ground
					common_scale = scale
					envelope = content
					first = false
				else: envelope = envelope.merge(content)
				check(ground.distance_to(common_ground) <= 0.002 and absf(scale - common_scale) <= 0.002, "packed directions/actions share scale and ground: " + key + "/" + state + "/" + direction + "/" + str(index))
				if state == "walk": minimum_walk = minf(minimum_walk, content.size.y)
	for a in range(directions_seen.size()):
		for b in range(a + 1, directions_seen.size()): check(directions_seen[a] != directions_seen[b], "packed true walk views remain distinct: " + key)
	var size: Vector2 = codex._walk.size
	var top := minf(envelope.position.y, common_ground.y)
	var bottom := maxf(envelope.end.y, common_ground.y)
	var width_use := 2.0 * maxf(absf(envelope.position.x - common_ground.x), absf(envelope.end.x - common_ground.x)) / (size.x - 16.0)
	var height_use := (bottom - top) / (size.y - 24.0)
	check(not first and is_finite(minimum_walk) and minimum_walk >= size.y * 0.5 - 0.02, "packed walking preview remains at least half panel height: " + key)
	check(top >= 12.0 - 0.02 and absf(bottom - (size.y - 12.0)) <= 0.02 and width_use <= 1.0002 and height_use <= 1.0002 and maxf(width_use, height_use) >= 0.98, "packed previews use available space without clipping: " + key)
	fits.append({"character": key, "panel_size": [size.x, size.y], "minimum_walk_height": minimum_walk, "width_use": width_use, "height_use": height_use, "top": top, "bottom": bottom})

func _run() -> void:
	if not _profile_guard():
		print("CODEX_PACK_PRIVATE_PROFILE_REQUIRED")
		quit(2)
		return
	await process_frame
	Engine.time_scale = 1.0
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	art = root.get_node("Art")
	root.get_node("Localize").set_language("zh_CN", false)
	_portrait_check()
	codex = ResourceLoader.load("res://scenes/codex.tscn").instantiate()
	root.add_child(codex)
	current_scene = codex
	for _frame in range(4): await process_frame
	for key in CHARACTERS: await _character_check(key)
	check(portraits.size() == 4 and routes.size() == 32 and fits.size() == 4, "complete packed four-portrait and 32-route set")
	codex.queue_free()
	await process_frame
	await process_frame
	for name in ["Sfx", "Music"]:
		var singleton = root.get_node_or_null(name)
		if singleton != null and singleton.has_method("shutdown"): singleton.shutdown()
	var report := {"schema": "codex_pck_probe_v1", "complete": true, "passed": failures.is_empty(), "checks": checks, "failures": failures, "portraits": portraits, "routes": routes, "fits": fits, "private_profile": profile_proof, "pid": OS.get_process_id(), "pack": OS.get_environment("PCK_ART_PACK"), "pack_sha256": OS.get_environment("PCK_ART_PACK_SHA"), "scope": "Editor host loads actual exported pack. One codex scene/locale; no release executable gameplay, screenshots, Steam client or server acceptance. Portrait digest is decoded texture pixels, never raw source PNG SHA."}
	var output := FileAccess.open(OS.get_environment("PCK_ART_REPORT"), FileAccess.WRITE)
	if output == null:
		push_error("CODEX_PACK_REPORT_WRITE_FAILED")
		quit(1)
		return
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	quit(0 if failures.is_empty() else 1)
