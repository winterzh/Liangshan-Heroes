extends SceneTree
## Run only after the web art registry/import is ready. This is an appearance/lifecycle contract,
## not visual approval, animation approval, performance evidence, or human pacing evidence.
## Real mission actions drive the story. One duplicate callback probes cart placement idempotency.
const KEYS := ["chao_gai", "wu_yong", "gongsun_sheng", "liu_tang", "ruan_xiaoer", "ruan_xiaowu", "ruan_xiaoqi", "bai_sheng"]
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const EVENT_SCRIPT := "res://scripts/campaign_art_event.gd"
const OUTPUT := "res://qa/web_chatgpt_art_20260831/huangnigang_wiring.json"
var failures: Array[String] = []
var checks: Array = []
var snapshots: Array = []
var arena_completed := false
var arena_spawn_routes: Array = []
var carry_fixtures: Array = []

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks.append({"name": label, "passed": ok})
	print("[hn-art-check] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func _source(texture) -> String:
	if texture == null: return ""
	return texture.atlas.resource_path if texture is AtlasTexture else texture.resource_path

func _sha256_bytes(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()

func _source_sha(path: String) -> String:
	return _sha256_bytes(FileAccess.get_file_as_bytes(path)) if path != "" and FileAccess.file_exists(path) else ""

func _pixels_sha(texture) -> String:
	if texture == null: return ""
	var image = texture.get_image()
	return _sha256_bytes(image.get_data()) if image != null else ""

func _save_hash() -> String:
	return FileAccess.get_file_as_bytes("user://campaign.cfg").hex_encode().sha256_text() if FileAccess.file_exists("user://campaign.cfg") else "absent"

func _start(arena := false):
	var c = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]: c.set(mode, false)
	c.arena = arena
	c.current = c.index_for_id("level1")
	seed(5088120)
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	if not is_instance_valid(b.hud) or not is_instance_valid(b.map):
		_check(false, "scene construction failed before normal start")
		b.queue_free()
		return null
	b.hud._intro_root.hide()
	b._on_intro_done()
	b.hud._on_start_pressed()
	b._smoke = false
	Engine.time_scale = 4.0
	return b

func _map_signature(b) -> String:
	var cells: Array = []
	for y in range(b.map.h):
		for x in range(b.map.w):
			var c := Vector2i(x, y)
			cells.append([b.map.t_at(x, y), b.map.is_open_cell(c, "land"), b.map.is_open_cell(c, "water")])
	return JSON.stringify(cells).sha256_text()

func _cart_nodes(b) -> Array:
	return b.fx_root.get_children().filter(func(n): return n.get_meta("campaign_object", "") == "jujube_cart")

func _legacy_cart_count(b) -> int:
	var count := 0
	for n in b.fx_root.get_children():
		var script = n.get_script()
		if script != null and script.resource_path == EVENT_SCRIPT and _source(n.texture).ends_with("/jujube_load_default.png"): count += 1
	return count

func _snapshot_actor(b, u, campaign: bool, label: String) -> void:
	var art = root.get_node("Art")
	b._set_selection([u])
	b.hud.update_selection_panel([u])
	var expected: String = "hn_" + u.key if campaign else ""
	var portrait: String = _source(b.hud._port_tex.texture)
	var directions := {}
	_check(u.art_variant == expected and String(u.setup_def.get("art_variant", "")) == expected, label + " spawned variant " + u.key)
	if campaign:
		_check(portrait == "res://assets/campaign/portraits/%s.png" % expected, label + " HUD portrait " + u.key)
		for direction in DIRECTIONS:
			var frames: Array = art.unit_anim_frames(u.key, "idle", direction, u.art_variant)
			var source: String = _source(frames[0]) if not frames.is_empty() else ""
			directions[direction] = {"count": frames.size(), "source": source, "source_sha256": _source_sha(source), "pixels_sha256": _pixels_sha(frames[0]) if not frames.is_empty() else ""}
			_check(art.campaign_variant_has_direction(expected, direction) and frames.size() == 1 and source == "res://assets/campaign/anim/%s_idle_%s.png" % [expected, direction], label + " single-pose idle " + u.key + " " + direction)
	else:
		_check(portrait != "" and not portrait.begins_with("res://assets/campaign/"), label + " legacy HUD portrait " + u.key)
		var frames: Array = art.unit_anim_frames(u.key, "idle", "se", u.art_variant)
		var source: String = _source(frames[0]) if not frames.is_empty() else _source(art.unit_texture(u.key, u.art_variant))
		directions["legacy"] = {"count": frames.size(), "source": source, "source_sha256": _source_sha(source)}
		_check(source != "" and not source.begins_with("res://assets/campaign/"), label + " no campaign cache reuse " + u.key)
	snapshots.append({"pass": label, "key": u.key, "variant": u.art_variant, "portrait": portrait, "portrait_source_sha256": _source_sha(portrait), "portrait_pixels_sha256": _pixels_sha(b.hud._port_tex.texture), "directions": directions})

func _dispose(b, references: Array = []) -> void:
	var scene_ref = weakref(b)
	b.queue_free()
	await process_frame
	await process_frame
	_check(scene_ref.get_ref() == null and references.all(func(r): return r.get_ref() == null), "scene and cart nodes freed")

func _campaign_pass(label: String, complete: bool) -> Dictionary:
	var b = await _start()
	if b == null: return {}
	var l = b.level
	for key in KEYS:
		_check(b._defs.has(key) and b._defs[key].get("art_variant", "") == "hn_" + key, label + " local definition " + key)
	_check(l.jujube_carts.is_empty() and _cart_nodes(b).is_empty() and _legacy_cart_count(b) == 0, label + " no cart art before placement")
	for key in l.SEVEN:
		var u = b.find_unit(key)
		_check(u != null, label + " starting actor " + key)
		if u != null: _snapshot_actor(b, u, true, label)
	var before_nav := _map_signature(b)
	var before_unit_count: int = b.units.size()
	_check(b.mission.request_action("place_dates"), label + " accepts real cart placement task")
	var frames := 0
	while not b.mission.has_event("place_dates") and b.phase != b.Phase.END and frames < 600:
		await process_frame
		frames += 1
	_check(b.mission.has_event("place_dates"), label + " placement reached by walking")
	var cart_refs: Array = l.jujube_carts.map(func(n): return weakref(n))
	var ids: Array = l.jujube_carts.map(func(n): return n.get_instance_id())
	var cart_cells: Array = []
	var cart_geometry_ok: bool = l.jujube_carts.size() == 7
	for i in range(l.jujube_carts.size()):
		var n = l.jujube_carts[i]
		var expected_cart_path := "res://assets/campaign/environment/level1/jujube_cart_%02d.png" % (i + 1)
		cart_cells.append(str(b.map.world_to_cell(n.position)))
		cart_geometry_ok = cart_geometry_ok and n.get_parent() == b.fx_root and n.visible and n.size == 72.0 and n.duration < 0.0 \
			and not n.z_as_relative and n.z_index == clampi(1 + int(b.map.project(n.position).y), 1, 3400) and n.contact_shadow_enabled \
			and n.get_meta("jujube_cart_index", -1) == i and n.get_meta("mission_action", "") == "place_dates" \
			and b.map.world_to_cell(n.position) == l.JUJUBE_CART_CELLS[i] and not b.units.has(n) \
			and b.map.is_open_cell(l.JUJUBE_CART_CELLS[i], "land") and b.map.t_at(l.JUJUBE_CART_CELLS[i].x, l.JUJUBE_CART_CELLS[i].y) in [l.T.DRYHILL, l.T.FOREST, l.T.REEDS] \
			and n.position.distance_to(b.map.cell_to_world(l.SHADE)) <= 192.0 \
			and _source(n.texture) == expected_cart_path
	_check(cart_geometry_ok and _cart_nodes(b).size() == 7 and _legacy_cart_count(b) == 0, label + " seven unique 72px carts by the resting merchants, off the road, no eighth legacy object")
	_check(_map_signature(b) == before_nav and b.units.size() == before_unit_count, label + " placement leaves terrain, both nav profiles and unit population unchanged")
	_check(not b.mission.request_action("place_dates"), label + " completed placement cannot be requested again")
	l.on_mission_action(b, "place_dates", b.find_unit("chao_gai"))
	_check(l.jujube_carts.map(func(n): return n.get_instance_id()) == ids and _cart_nodes(b).size() == 7, label + " duplicate callback does not add carts")
	b._smoke = true
	var bai_seen := false
	var carry_walk_seen := false
	var unload_seen := false
	frames = 0
	while b.phase != b.Phase.END and frames < 14000:
		await process_frame
		frames += 1
		var bai = b.find_unit("bai_sheng")
		if bai != null and not bai_seen:
			bai_seen = true
			_snapshot_actor(b, bai, true, label + " late arrival")
		if bai != null and bool(bai.get_meta("carrying_wine", false)) and bai._move_blend > 0.3 and not carry_walk_seen:
			var actual = bai._anim_frame_for_state(root.get_node("Art").unit_texture(bai.key, bai.art_variant))
			carry_walk_seen = bai._campaign_wine_carry_state() == "carry_walk" and _source(actual) == "res://assets/campaign/anim/hn_bai_sheng_carry_walk_%s.png" % bai.animation_direction
		if bai != null and b.mission.has_event("bring_wine") and not unload_seen:
			var actual = bai._anim_frame_for_state(root.get_node("Art").unit_texture(bai.key, bai.art_variant))
			var source := _source(actual)
			unload_seen = not bool(bai.get_meta("carrying_wine", false)) and bai._campaign_wine_carry_state() == "" and (source.begins_with("res://assets/campaign/anim/hn_bai_sheng_idle_") or source.begins_with("res://assets/campaign/anim/hn_bai_sheng_walk_"))
		if bai_seen and unload_seen and not complete: break
	_check(bai_seen, label + " Bai Sheng arrives through real inquiry chain")
	_check(carry_walk_seen and unload_seen, label + " real shoulder carry switches back after real unloading")
	if complete:
		_check(b.phase == b.Phase.END and b.mission.has_event("escaped") and l.delivered == 3, label + " full mission still succeeds")
	_check(_cart_nodes(b).size() == 7 and _legacy_cart_count(b) == 0, label + " seven carts persist without duplication")
	var result := {"pass": label, "full_chain": complete, "game_seconds": b.mission.total_game_seconds, "stage_metrics": b.mission.stage_metrics.duplicate(true), "cart_cells": cart_cells,
		"timing_note": "Includes contract observation and duplicate-callback probe; not pacing evidence."}
	await _dispose(b, cart_refs)
	return result

func _arena_pass() -> void:
	var b = await _start(true)
	if b == null: return
	_check(b.level.id() == "arena" and b.mission == null, "arena constructs its own mode")
	_check(not b._defs.has("ruan_xiaoer"), "arena does not inherit locally added Ruan Xiaoer definition")
	_check(_cart_nodes(b).is_empty() and _legacy_cart_count(b) == 0, "arena contains no Huangnigang carts")
	for key in KEYS:
		var legacy_key: String = "ruan_brother" if key == "ruan_xiaoer" else key
		_check(not String(b._defs[legacy_key].get("art_variant", "")).begins_with("hn_"), "arena definition restored " + legacy_key)
		var reason: String = b._train_block_reason(b.level.hall, legacy_key)
		if legacy_key == "chao_gai":
			_check(not bool(b._defs[legacy_key].get("hero_trainable", false)) and reason == "unsupported" and not b.queue_train(b.level.hall, legacy_key, false) and b.find_unit(legacy_key) == null, "default Chao Gai remains untrainable without an added exception")
			arena_spawn_routes.append({"key": legacy_key, "route": "expected_untrainable_rejection", "blocked_reason": reason})
			continue
		var u = null
		var queued: bool = reason == "" and b.queue_train(b.level.hall, legacy_key, false)
		_check(queued, "arena normal recruitment " + legacy_key)
		arena_spawn_routes.append({"key": legacy_key, "route": "normal_training" if queued else "failed_training", "blocked_reason": reason})
		if u == null: u = b.find_unit(legacy_key)
		for i in range(180):
			if u != null: break
			await process_frame
			u = b.find_unit(legacy_key)
		_check(u != null, "arena recruited " + legacy_key)
		if u != null:
			_snapshot_actor(b, u, false, "arena")
			_check(not u.get_meta("carrying_wine", false) and u._campaign_wine_carry_state() == "", "arena has no campaign shoulder-carry state " + legacy_key)
	await _dispose(b)
	arena_completed = true

func _carry_pose_fixtures() -> void:
	# A detached test Unit changes only local fixture fields. No live story is modified.
	var art = root.get_node("Art")
	var u = load("res://scripts/unit.gd").new()
	u.key = "bai_sheng"
	u.art_variant = "hn_bai_sheng"
	u.set_meta("carrying_wine", true)
	for direction in DIRECTIONS:
		u.animation_direction = direction
		for moving in [false, true]:
			u._move_blend = 1.0 if moving else 0.0
			var state := "carry_walk" if moving else "carry_idle"
			var actual = u._anim_frame_for_state(art.unit_texture(u.key, u.art_variant))
			_check(u._campaign_wine_carry_state() == state and _source(actual) == "res://assets/campaign/anim/hn_bai_sheng_%s_%s.png" % [state, direction], "detached carry fixture exact pose " + state + " " + direction)
			carry_fixtures.append({"state": state, "direction": direction, "source": _source(actual), "source_sha256": _source_sha(_source(actual)), "legacy_overlay_condition": bool(u.get_meta("carrying_wine", false)) and u._campaign_wine_carry_state().is_empty()})
	# Exercise the exact-pose-unavailable branch without renaming/deleting shared art files.
	u.animation_direction = "qa_missing_direction"
	_check(u._campaign_wine_carry_state() == "" and bool(u.get_meta("carrying_wine", false)), "unavailable exact pose preserves legacy overlay eligibility (missing-direction fixture)")
	u.animation_direction = "se"
	u.art_variant = ""
	_check(u._campaign_wine_carry_state() == "" and bool(u.get_meta("carrying_wine", false)), "legacy Bai appearance retains the old carry overlay fallback")
	u.art_variant = "hn_chao_gai"
	_check(u._campaign_wine_carry_state() == "", "another hero never acquires Bai shoulder pose")
	u.art_variant = "hn_bai_sheng"
	u.set_meta("carrying_wine", false)
	_check(u._campaign_wine_carry_state() == "", "unloaded Bai never keeps the carry pose")
	u.free()

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	OS.set_environment("SMOKE_TEST", "")
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0, true)
	var art = root.get_node("Art")
	var definitions = load("res://scripts/defs.gd")
	var original_defs: Dictionary = definitions.UNITS.duplicate(true)
	var save_before := _save_hash()
	_check(art.campaign_object_texture("jujube_cart") != null, "registered and imported jujube cart")
	for key in KEYS:
		_check(_source(art.avatar_texture(key, "hn_" + key)) == "res://assets/campaign/portraits/hn_%s.png" % key, "registered and imported portrait " + key)
	for direction in DIRECTIONS:
		for state in ["carry_idle", "carry_walk"]:
			_check(art.campaign_variant_has_animation("hn_bai_sheng", state, direction), "registered exact shoulder pose " + state + " " + direction)
	var campaigns: Array = []
	if failures.is_empty():
		_carry_pose_fixtures()
		campaigns.append(await _campaign_pass("campaign first", true))
		await _arena_pass()
		campaigns.append(await _campaign_pass("campaign return", false))
	_check(campaigns.size() == 2 and campaigns.all(func(item): return item is Dictionary and not item.is_empty()) and arena_completed, "all three mode passes actually completed")
	_check(snapshots.size() == 23, "all 23 recruited or real-story actor snapshots were collected; untrainable Chao excluded from arena")
	var distinct_portraits := {}
	for item in snapshots:
		if String(item.pass).begins_with("campaign first") and item.portrait_pixels_sha256 != "": distinct_portraits[item.portrait_pixels_sha256] = true
	_check(distinct_portraits.size() == 8, "all eight Huangnigang actors have different portrait pixels")
	_check(definitions.UNITS == original_defs, "global unit definitions unchanged")
	_check(_save_hash() == save_before, "campaign progress file bytes unchanged")
	Engine.time_scale = 1.0
	var report := {"passed": failures.is_empty(), "failures": failures, "checks": checks, "actors": snapshots, "campaigns": campaigns, "arena_spawn_routes": arena_spawn_routes,
		"arena_roster_rules_passed": arena_spawn_routes.size() == 8 and arena_spawn_routes.all(func(item): return item.route == "normal_training" or (item.key == "chao_gai" and item.route == "expected_untrainable_rejection")),
		"carry_fixtures": carry_fixtures,
		"distinct_huangnigang_portrait_pixels": distinct_portraits.size(), "cart_source_sha256": _source_sha("res://assets/campaign/environment/level1/jujube_cart_01.png"),
		"evidence_scope": "Headless appearance, scene lifecycle and mode-isolation contract. Seven eligible arena heroes use normal recruitment; default Chao Gai is a rejection test. Detached carry fixtures exercise pose selection/fallback without altering a live mission. Missing-direction fixture checks unavailable exact-pose fallback without deleting assets. No visual acceptance or performance claim."}
	var path := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("[hn-art-summary] ", JSON.stringify({"passed": failures.is_empty(), "failures": failures, "checks": checks.size()}))
	quit(0 if failures.is_empty() else 1)
