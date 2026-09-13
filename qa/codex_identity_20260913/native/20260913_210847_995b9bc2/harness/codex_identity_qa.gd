extends SceneTree
## Private candidate. No native parse/run claim until the isolated runner executes it.
## Actual codex scene and connected UI signals; frozen frame indices are screenshot fixtures.
## Required: ART_QA_PROFILE, CODEX_QA_OUT, CODEX_QA_SOURCE_ROOT; CODEX_QA_VISUAL=1 for PNGs.

const CHARACTERS := ["song_jiang", "lin_chong", "sun_li", "hu_sanniang"]
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const DIRECTION_NAMES := ["东南", "西南", "东北", "西北"]
const MANIFESTS := {
	"song_jiang": "res://assets/direction4/song_jiang_20260906.json",
	"lin_chong": "res://assets/direction4/lin_chong_20260906.json",
	"sun_li": "res://assets/direction4/sun_li_20260913.json",
	"hu_sanniang": "res://assets/direction4/hu_sanniang_20260913.json",
}
const LOCALES := ["zh_CN", "en", "ja", "zh_TW"]
var checks: Array = []
var failures: Array = []
var routes: Array = []
var layouts: Array = []
var screenshots: Array = []
var languages: Array = []
var geometry_groups: Dictionary = {}
var profile_proof := {}
var identity_before := {}
var output := ""
var visual := false
var codex
var art
var localize

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"label": label, "passed": ok})
	print("[codex-identity] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func _profile_guard() -> bool:
	var profile := OS.get_environment("ART_QA_PROFILE").replace("\\", "/").simplify_path()
	var source := OS.get_environment("CODEX_QA_SOURCE_ROOT").replace("\\", "/").simplify_path()
	var project := ProjectSettings.globalize_path("res://").replace("\\", "/").simplify_path().trim_suffix("/")
	var safe := profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	var environment := {}
	for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		var actual := OS.get_environment(key).replace("\\", "/").simplify_path()
		environment[key] = actual
		safe = safe and actual.to_lower() == (profile + "/" + String(key).to_lower()).to_lower()
	var user_path := OS.get_user_data_dir().replace("\\", "/").simplify_path()
	safe = safe and user_path.to_lower().begins_with((profile + "/appdata/").to_lower())
	safe = safe and source.is_absolute_path() and source.to_lower().trim_suffix("/") != project.to_lower()
	safe = safe and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA") == "1"
	output = OS.get_environment("CODEX_QA_OUT").replace("\\", "/").simplify_path()
	safe = safe and output.is_absolute_path() and not output.to_lower().begins_with(source.to_lower().trim_suffix("/") + "/")
	profile_proof = {"passed": safe, "profile": profile, "environment": environment, "user_data_dir": user_path, "project": project, "source_root": source}
	return safe

func _vec(v: Vector2) -> Array:
	return [v.x, v.y]

func _rect(r: Rect2) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]

func _signature(frame) -> Dictionary:
	if not frame is Texture2D: return {}
	var result := {"path": frame.resource_path, "size": _vec(frame.get_size()), "draw_scale": float(frame.get_meta("draw_scale", 1.0)), "authored": bool(frame.get_meta("authored_direction4", false))}
	var offset: Variant = frame.get_meta("draw_offset_px", Vector2.ZERO)
	result["offset"] = _vec(offset) if offset is Vector2 else str(offset)
	if frame is AtlasTexture:
		result["atlas"] = frame.atlas.resource_path if frame.atlas != null else ""
		result["region"] = _rect(frame.region)
		result["margin"] = _rect(frame.margin)
		result["filter_clip"] = frame.filter_clip
	return result

func _signatures(frames: Array) -> Array:
	var result := []
	for frame in frames: result.append(_signature(frame))
	return result

func _identity() -> Dictionary:
	var result := {}
	for path in ["res://scripts/codex.gd", "res://scripts/art_db.gd", "res://scenes/codex.tscn", "res://assets/localization/catalog.json"]:
		result[path] = FileAccess.get_sha256(path)
	for key in CHARACTERS:
		result[MANIFESTS[key]] = FileAccess.get_sha256(MANIFESTS[key])
		for direction in DIRECTIONS:
			for state in ["idle", "walk", "attack"]:
				var path := "res://assets/anim/%s_%s_%s.tres" % [key, state, direction]
				result[path] = FileAccess.get_sha256(path)
	return result

func _button_for(node: Node, display: String):
	for child in node.get_children():
		if child is Button and not child is OptionButton and String(child.text).strip_edges().begins_with(display): return child
		var found = _button_for(child, display)
		if found != null: return found
	return null

func _select_character(key: String) -> bool:
	var button = _button_for(codex._list_scroll, String(codex._disp_name(key)))
	check(button != null, "real list button exists: " + key)
	if button == null: return false
	check(button.pressed.get_connections().size() > 0, "list button has production callback: " + key)
	button.pressed.emit()
	check(String(codex._cur) == key, "list signal selects exact character: " + key)
	return String(codex._cur) == key

func _direction_selector():
	return codex._direction_picker as OptionButton

func _direction() -> String:
	return DIRECTIONS[int(codex._direction_index)]

func _select_direction(index: int) -> bool:
	var selector = _direction_selector()
	check(selector != null and selector.item_count == 4, "four-item production direction selector")
	if selector == null or selector.item_count != 4: return false
	check(selector.item_selected.get_connections().size() > 0, "direction selector has production callback")
	check(not selector.disabled, "authored character permits direction selection")
	if selector.disabled: return false
	for item in range(4): check(selector.get_item_text(item) == localize.text(DIRECTION_NAMES[item]), "direction item has exact localized order: " + DIRECTIONS[item])
	selector.select(index)
	selector.item_selected.emit(index)
	check(_direction() == DIRECTIONS[index], "UI selection changes direction: " + DIRECTIONS[index])
	return _direction() == DIRECTIONS[index]

func _settle() -> void:
	for _i in range(4): await process_frame

func _open(locale: String) -> void:
	localize.set_language(locale, false)
	codex = load("res://scenes/codex.tscn").instantiate()
	root.add_child(codex)
	current_scene = codex
	await _settle()
	for box in [codex._port, codex._walk, codex._atk]: box.set_process(false)

func _close() -> void:
	if is_instance_valid(codex): codex.queue_free()
	await process_frame
	await process_frame
	codex = null

func _check_visible_layout(label: String) -> void:
	var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
	for pair in [["portrait", codex._port], ["walk", codex._walk], ["attack", codex._atk], ["name", codex._name_lbl], ["direction", _direction_selector()]]:
		if pair[1] == null:
			check(false, label + " missing control " + pair[0])
			continue
		var box = pair[1]
		check(viewport.grow(1.0).encloses(box.get_global_rect()), label + " visible viewport bounds: " + pair[0])
	for pair in [["biography", codex._bio_lbl], ["abilities", codex._abil_lbl]]:
		var r: Rect2 = pair[1].get_global_rect()
		check(r.position.x >= -1.0 and r.end.x <= viewport.end.x + 1.0, label + " text wraps horizontally: " + pair[0])

func _check_geometry(box, label: String) -> void:
	# Production _draw must consume this same pure layout result. This test checks
	# the independent geometric invariants; it does not recompute the fit algorithm.
	check(box.has_method("frame_layout"), "production drawing exposes frame layout: " + label)
	if not box.has_method("frame_layout"): return
	var shared_scale := -1.0
	var shared_ground := Vector2.INF
	for index in range(box.frames.size()):
		var frame: Texture2D = box.frames[index]
		if frame == null:
			check(false, "non-null displayed frame: " + label)
			continue
		var layout: Dictionary = box.frame_layout(index)
		check(layout.get("rect") is Rect2 and layout.get("ground") is Vector2 and layout.get("content_rect") is Rect2, "typed draw layout: " + label + "/" + str(index))
		if not layout.get("rect") is Rect2 or not layout.get("ground") is Vector2 or not layout.get("content_rect") is Rect2: continue
		var rect: Rect2 = layout.rect
		var content: Rect2 = layout.content_rect
		var ground: Vector2 = layout.ground
		var texture_size := frame.get_size()
		var per_pixel := rect.size.x / texture_size.x
		var draw_scale := float(frame.get_meta("draw_scale", 1.0))
		check(per_pixel > 0.0 and is_finite(per_pixel) and absf(rect.size.y / texture_size.y - per_pixel) <= 0.0001, "uniform positive image scale: " + label + "/" + str(index))
		var sampled_content := rect
		if frame is AtlasTexture:
			sampled_content = Rect2(rect.position + frame.margin.position * per_pixel, frame.region.size * per_pixel)
		check(content.position.distance_to(sampled_content.position) <= 0.002 and content.size.distance_to(sampled_content.size) <= 0.002, "reported content bounds match actual atlas crop and padding: " + label + "/" + str(index))
		check(Rect2(Vector2.ZERO, box.size).grow(0.02).encloses(content), "all sampled contents stay in animation box: " + label + "/" + str(index))
		if bool(frame.get_meta("authored_direction4", false)):
			var offset: Vector2 = frame.get_meta("draw_offset_px", Vector2.ZERO)
			var transformed_ground := rect.position + (Vector2(texture_size.x * 0.5, texture_size.y * 0.82) - offset) * per_pixel
			check(transformed_ground.distance_to(ground) <= 0.002, "metadata ground transforms to shared anchor: " + label + "/" + str(index))
			# Unit scales a virtual square, not source pixels. Different canvas sizes
			# therefore retain one base displayed canvas size after removing draw_scale.
			var normalized_scale := rect.size.x / draw_scale
			if shared_scale < 0.0:
				shared_scale = normalized_scale
				shared_ground = ground
			check(absf(normalized_scale - shared_scale) <= 0.002 and ground.distance_to(shared_ground) <= 0.002, "cross-frame body scale and ground are shared: " + label + "/" + str(index))
			var character := label.get_slice("/", 0)
			if character in CHARACTERS:
				if not geometry_groups.has(character): geometry_groups[character] = {"scale": normalized_scale, "ground": ground}
				var group: Dictionary = geometry_groups[character]
				check(absf(normalized_scale - float(group.scale)) <= 0.002 and ground.distance_to(group.ground) <= 0.002, "both actions and all directions retain one body scale and anchor: " + label + "/" + str(index))
				check(ground.distance_to(Vector2(box.size.x * 0.5, box.size.y - 18.0)) <= 0.002, "authored ground sits at shared bottom inset: " + label + "/" + str(index))
		layouts.append({"label": label, "index": index, "frame": _signature(frame), "rect": _rect(rect), "content_rect": _rect(content), "ground": _vec(ground)})

func _authored(key: String, direction: String) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFESTS[key]))
	for pair in [["walk", codex._walk], ["attack", codex._atk]]:
		var state: String = pair[0]
		var box = pair[1]
		var path := "res://assets/anim/%s_%s_%s.tres" % [key, state, direction]
		var resource: SpriteFrames = load(path)
		var expected := []
		if resource != null:
			for i in range(resource.get_frame_count(&"default")): expected.append(resource.get_frame_texture(&"default", i))
		check(not expected.is_empty() and expected.size() == manifest.states[state].size(), "installed explicit direction resource: " + key + "/" + state + "/" + direction)
		var actual: Array = box.frames
		check(_signatures(actual) == _signatures(expected), "codex uses authored exact frame order, crops and metadata: " + key + "/" + state + "/" + direction)
		check(_signatures(actual) == _signatures(art.unit_anim_frames(key, state, direction)), "codex matches actual directional Art route: " + key + "/" + state + "/" + direction)
		check(art.unit_anim_uses_directional_source(key, state, direction), "direction route cannot be legacy frame strip: " + key + "/" + state + "/" + direction)
		routes.append({"character": key, "state": state, "direction": direction, "resource": path, "resource_sha256": FileAccess.get_sha256(path), "displayed": _signatures(actual)})
		_check_geometry(box, key + "/" + state + "/" + direction)
	var portrait = art.portrait_texture(key)
	check(portrait != null and _signatures(codex._port.frames) == [_signature(portrait)], "portrait obeys current independent portrait route: " + key)
	_check_geometry(codex._port, "portrait/" + key)
	if art.STANDALONE_PORTRAITS.has(key):
		check(portrait.resource_path == art.STANDALONE_PORTRAITS[key], "installed standalone portrait wins: " + key)
		identity_before[portrait.resource_path] = FileAccess.get_sha256(portrait.resource_path)

func _capture(label: String) -> void:
	if not visual: return
	# Select representative readable poses only for the screenshot, preserving the
	# real AnimBox renderer and authored arrays. Routing checks precede this fixture.
	codex._walk._i = mini(1, maxi(0, codex._walk.frames.size() - 1))
	codex._atk._i = mini(2, maxi(0, codex._atk.frames.size() - 1))
	for box in [codex._port, codex._walk, codex._atk]: box.queue_redraw()
	await _settle()
	RenderingServer.force_draw(false)
	await process_frame
	var img := root.get_texture().get_image()
	var path := output.path_join(label + ".png")
	check(not img.is_empty() and img.get_size() == root.size and img.save_png(path) == OK, "native screenshot: " + label)
	if FileAccess.file_exists(path): screenshots.append({"label": label, "path": path, "sha256": FileAccess.get_sha256(path), "size": [img.get_width(), img.get_height()], "character": codex._cur, "direction": _direction(), "locale": localize.locale})

func _legacy() -> void:
	for key in ["an_daoquan", "hall"]:
		if not _select_character(key): continue
		check(_direction_selector().disabled, "legacy/static unit disables unsupported direction selector: " + key)
		var walk: Array = art.unit_anim_frames(key, "walk")
		if walk.is_empty() and art.unit_texture(key) != null: walk = [art.unit_texture(key)]
		var attack: Array = art.unit_anim_frames(key, "attack")
		if attack.is_empty(): attack = walk
		check(not walk.is_empty() and _signatures(codex._walk.frames) == _signatures(walk) and _signatures(codex._atk.frames) == _signatures(attack), "legacy/static fallback kept: " + key)
		_check_geometry(codex._walk, "fallback/" + key)
		if key == "an_daoquan": await _capture("legacy_an_daoquan")
	if not _select_character("arrow_tower"): return
	var ring := [Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2), Vector2i(0, 1), Vector2i(0, 0)]
	var expected := []
	for cell in ring: expected.append(art.tower_dir_texture("arrow_tower", cell))
	check(_direction_selector().disabled, "tower keeps automatic ring and disables hero directions")
	check(expected.size() == 8 and _signatures(codex._walk.frames) == _signatures(expected) and _signatures(codex._atk.frames) == _signatures(expected), "tower retains clockwise eight-frame ring")
	check(_signatures(codex._port.frames) == [_signature(art.tower_dir_texture("arrow_tower", Vector2i(1, 1)))], "tower portrait remains centre base")
	_check_geometry(codex._walk, "tower/eight_direction_ring")
	await _capture("legacy_arrow_tower")

func _animation_clock() -> void:
	if not _select_character("sun_li") or not _select_direction(0): return
	for box in [codex._walk, codex._atk]:
		box.set_process(true)
	var before := [codex._walk._i, codex._atk._i]
	await create_timer(0.34, true, false, true).timeout
	check(codex._walk._i != before[0] and codex._atk._i != before[1], "real process clock advances both animation panels")
	for box in [codex._walk, codex._atk]: box.set_process(false)
	_select_direction(1)
	check(codex._walk._i == 0 and codex._atk._i == 0 and codex._walk._t == 0.0 and codex._atk._t == 0.0, "direction switch resets frame index and phase")

func _finish() -> void:
	var after := _identity()
	for path in identity_before:
		after[path] = FileAccess.get_sha256(path)
		check(FileAccess.get_sha256(path) == identity_before[path], "inspected source unchanged: " + path)
	var report := {"schema": "codex_identity_qa_v1", "complete": true, "passed": failures.is_empty(), "count": checks.size(), "checks": checks, "failures": failures, "routes": routes, "layouts": layouts, "screenshots": screenshots, "languages": languages, "visual": visual, "private_profile": profile_proof, "identity_before": identity_before, "identity_after": after, "pid": OS.get_process_id(), "scope": "Actual codex scene, UI signal routing, four-language layout and native renders. Not gameplay, image generation quality, world restore, Steam or long-run acceptance."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		push_error("CODEX_IDENTITY_QA_REPORT_WRITE_FAILED")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	for name in ["Sfx", "Music"]:
		var singleton = root.get_node_or_null(name)
		if singleton != null and singleton.has_method("shutdown"): singleton.shutdown()
	quit(0 if failures.is_empty() else 1)

func _run() -> void:
	if not _profile_guard():
		print("CODEX_IDENTITY_QA_PRIVATE_PROFILE_REQUIRED")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	visual = OS.get_environment("CODEX_QA_VISUAL") == "1"
	check(not visual or DisplayServer.get_name() != "headless", "visual mode requires a real renderer")
	root.unfocusable = true
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	if visual: DisplayServer.window_set_size(root.size)
	Engine.time_scale = 1.0
	AudioServer.set_bus_mute(0, true)
	await process_frame
	art = root.get_node("Art")
	localize = root.get_node("Localize")
	var campaign = root.get_node("Campaign")
	var records: Dictionary = campaign.records.duplicate(true)
	var definitions: Dictionary = Defs.UNITS.duplicate(true)
	identity_before = _identity()
	await _open("zh_CN")
	for ci in range(CHARACTERS.size()):
		var key: String = CHARACTERS[ci]
		if not _select_character(key): continue
		var direction_signatures := {}
		for di in range(4):
			if not _select_direction(di): continue
			await _settle()
			_authored(key, DIRECTIONS[di])
			_check_visible_layout(key + "/" + DIRECTIONS[di])
			direction_signatures[DIRECTIONS[di]] = _signatures(codex._walk.frames)
			if di == ci or key == "sun_li": await _capture(key + "_" + DIRECTIONS[di])
		for a in range(4):
			for b in range(a + 1, 4): check(direction_signatures.get(DIRECTIONS[a], []) != direction_signatures.get(DIRECTIONS[b], []), "distinct true directions: " + key + "/" + DIRECTIONS[a] + "/" + DIRECTIONS[b])
	await _animation_clock()
	await _legacy()
	await _close()
	for locale in LOCALES:
		await _open(locale)
		_select_character("hu_sanniang")
		_select_direction(3)
		await _settle()
		_check_visible_layout("locale/" + locale)
		check(String(codex._name_lbl.text).contains(String(codex._disp_name("hu_sanniang"))) and not String(codex._bio_lbl.text).is_empty() and not String(codex._abil_lbl.text).is_empty(), "localized identity and biography/skills populated: " + locale)
		var selector = _direction_selector()
		var direction_labels := []
		if selector != null:
			for index in range(4): direction_labels.append(selector.get_item_text(index))
		languages.append({"locale": locale, "name": codex._name_lbl.text, "bio": codex._bio_lbl.text, "directions": direction_labels})
		if locale != "zh_CN": await _capture("locale_" + locale)
		await _close()
	check(routes.size() == 32, "all four heroes times four directions times two panels observed")
	check(languages.size() == 4, "all four locale scenes observed")
	if languages.size() == 4:
		for index in range(1, 4):
			# Proper names/star titles may legitimately share Simplified/Traditional
			# glyphs (扈三娘/地慧星/一丈青); prose is the meaningful locale witness.
			check(languages[index].bio != languages[0].bio, "non-Simplified locale uses translated biography: " + LOCALES[index])
	check(screenshots.size() == (12 if visual else 0), "bounded native screenshot set is complete")
	check(campaign.records == records and Defs.UNITS == definitions, "codex browsing preserves campaign progress and unit definitions")
	_finish()
