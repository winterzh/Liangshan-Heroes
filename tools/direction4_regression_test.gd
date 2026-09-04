extends SceneTree
## Headless contract for the generic, non-campaign-variant four-direction path.
## It installs test-only imported-resource proxies under assets/anim for this
## process, exercises the real Art/Unit/Battle entry points, then removes them.

const CA := preload("res://scripts/campaign_art.gd")
const FIXTURE_DIR := "res://qa/direction4_20260901/fixtures"
const RUNTIME_DIR := "res://qa/direction4_20260901/runtime"
const REPORT_PATH := "res://qa/direction4_20260901/report.json"
const ANIM_DIR := "res://assets/anim"
const DIRECTIONAL_KEY := "qa_direction4"
const LEGACY_KEY := "qa_direction4_legacy"
const CAST_ID := "qa_direction4_cast"

const LOGIC_DIRECTIONS := {
	"se": Vector2(100.0, 0.0),
	"sw": Vector2(0.0, 100.0),
	"ne": Vector2(0.0, -100.0),
	"nw": Vector2(-100.0, 0.0),
}
const OPPOSITE := {"se":"nw", "sw":"ne", "ne":"sw", "nw":"se"}
const FIXTURE_FILES := [
	"qa_direction4_idle_se.png", "qa_direction4_idle_sw.png",
	"qa_direction4_idle_ne.png", "qa_direction4_idle_nw.png",
	"qa_direction4_walk_se.png", "qa_direction4_walk_sw.png",
	"qa_direction4_walk_ne.png", "qa_direction4_walk_nw.png",
	"qa_direction4_hurt_se.png", "qa_direction4_hurt_sw.png",
	"qa_direction4_hurt_ne.png", "qa_direction4_hurt_nw.png",
	"qa_direction4_attack.png", "qa_direction4_death.png",
	"qa_direction4_legacy_idle.png", "qa_direction4_legacy_walk.png",
]

var checks: Array = []
var failures: Array[String] = []
var _installed_targets: Array[String] = []
var _runtime_resources: Array[String] = []
var _unit_script = null
var _battle_script = null
var _unit_definitions: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, details: Variant = null) -> void:
	checks.append({"name":name, "passed":passed, "details":details})
	print("[direction4] ", "PASS " if passed else "FAIL ", name,
		"" if details == null else " :: " + JSON.stringify(details))
	if not passed:
		failures.append(name)


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path)


func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(_absolute(path))


func _clean_test_proxies() -> void:
	for filename in FIXTURE_FILES:
		var target := ANIM_DIR.path_join(filename)
		_remove_if_present(target + ".import")
		_remove_if_present(target)
	for path in _runtime_resources:
		_remove_if_present(path)
	_installed_targets.clear()
	_runtime_resources.clear()


func _test_proxies_absent() -> bool:
	for filename in FIXTURE_FILES:
		var target := ANIM_DIR.path_join(filename)
		var runtime := RUNTIME_DIR.path_join(filename + ".tres")
		if FileAccess.file_exists(target) or FileAccess.file_exists(target + ".import") \
				or FileAccess.file_exists(runtime):
			return false
	return true


func _install_fixture_proxy(filename: String) -> bool:
	var source := FIXTURE_DIR.path_join(filename)
	var target := ANIM_DIR.path_join(filename)
	var runtime := RUNTIME_DIR.path_join(filename + ".tres")
	var image := Image.load_from_file(_absolute(source))
	if image == null or image.is_empty() or image.get_height() <= 0 \
			or image.get_width() % image.get_height() != 0:
		return false
	var texture := ImageTexture.create_from_image(image)
	if texture == null or ResourceSaver.save(texture, runtime) != OK:
		return false
	_runtime_resources.append(runtime)
	if DirAccess.copy_absolute(_absolute(source), _absolute(target)) != OK:
		return false
	_installed_targets.append(target)
	# ResourceLoader follows a normal Godot .import remap. The remapped texture
	# is created from the ignored QA fixture at runtime, so no test art is added
	# permanently to the production assets directory.
	var remap := ConfigFile.new()
	remap.set_value("remap", "importer", "texture")
	remap.set_value("remap", "type", "ImageTexture")
	remap.set_value("remap", "path", runtime)
	remap.set_value("deps", "source_file", target)
	remap.set_value("deps", "dest_files", [runtime])
	return remap.save(_absolute(target + ".import")) == OK and ResourceLoader.exists(target)


func _frame_source(frame: Texture2D) -> String:
	if frame is AtlasTexture and frame.atlas != null:
		return frame.atlas.resource_path
	return frame.resource_path if frame != null else ""


func _unique_count(values: Array) -> int:
	var unique: Dictionary = {}
	for value in values:
		unique[value] = true
	return unique.size()


func _clear_art_fixture_cache(art: Node) -> void:
	var erase: Array = []
	for cache_key in art._anim_cache.keys():
		var text := String(cache_key)
		if DIRECTIONAL_KEY in text or LEGACY_KEY in text:
			erase.append(cache_key)
	for cache_key in erase:
		art._anim_cache.erase(cache_key)


func _stop_test_audio() -> void:
	# Direct --script tests quit without a normal scene transition. Stop the two
	# autoload audio pools explicitly so active WAV playbacks reach the mixer
	# before SceneTree teardown and are not reported as leaked test objects.
	for autoload_name in ["Sfx", "Music"]:
		var audio_root := root.get_node_or_null(autoload_name)
		if audio_root == null:
			continue
		audio_root.set("enabled", false)
		for child in audio_root.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream = null


func _make_unit(key: String, definition: Dictionary):
	var unit = _unit_script.new()
	unit.setup(key, definition, 0, null, null)
	root.add_child(unit)
	return unit


func _test_directional_art(art: Node) -> void:
	var sources: Dictionary = {}
	var hashes: Dictionary = {}
	for direction in CA.DIRECTIONS:
		var frames: Array = art.unit_anim_frames(DIRECTIONAL_KEY, "walk", direction)
		var expected := ANIM_DIR.path_join("%s_walk_%s.png" % [DIRECTIONAL_KEY, direction])
		var exact: bool = frames.size() == 2 and _frame_source(frames[0]) == expected \
			and art.unit_anim_uses_directional_source(DIRECTIONAL_KEY, "walk", direction)
		_check("exact directional walk loads " + direction, exact,
			{"expected":expected, "actual":_frame_source(frames[0]) if not frames.is_empty() else "", "frames":frames.size()})
		if not frames.is_empty():
			sources[direction] = _frame_source(frames[0])
			hashes[direction] = hash(frames[0].get_image().get_data())
		var cached: Array = art.unit_anim_frames(DIRECTIONAL_KEY, "walk", direction)
		_check("directional cache is stable " + direction,
			frames.size() == cached.size() and not frames.is_empty() \
				and frames[0].get_instance_id() == cached[0].get_instance_id())
	_check("directional cache entries stay separated",
		sources.size() == 4 and hashes.size() == 4 \
			and _unique_count(sources.values()) == 4 \
			and _unique_count(hashes.values()) == 4,
		{"sources":sources, "hashes":hashes})

	# An undirected attack strip exists deliberately. A missing directional
	# attack must keep the real action instead of freezing on a directional idle.
	for direction in CA.DIRECTIONS:
		var fallback: Array = art.unit_anim_frames(DIRECTIONAL_KEY, "attack", direction)
		var expected_attack := ANIM_DIR.path_join(DIRECTIONAL_KEY + "_attack.png")
		_check("legacy action wins over directional idle " + direction,
			fallback.size() == 2 and _frame_source(fallback[0]) == expected_attack \
				and not art.unit_anim_uses_directional_source(DIRECTIONAL_KEY, "attack", direction),
			{"expected":expected_attack, "actual":_frame_source(fallback[0]) if not fallback.is_empty() else ""})

	# If neither an exact directional action nor a legacy action exists, keeping
	# the same-direction idle is still the safest final visual fallback.
	for direction in CA.DIRECTIONS:
		var final_fallback: Array = art.unit_anim_frames(DIRECTIONAL_KEY, "gather", direction)
		var expected_idle := ANIM_DIR.path_join("%s_idle_%s.png" % [DIRECTIONAL_KEY, direction])
		_check("missing all action art keeps same-direction idle " + direction,
			final_fallback.size() == 2 and _frame_source(final_fallback[0]) == expected_idle \
				and art.unit_anim_uses_directional_source(DIRECTIONAL_KEY, "gather", direction),
			{"expected":expected_idle, "actual":_frame_source(final_fallback[0]) if not final_fallback.is_empty() else ""})

	# Terminal animation compatibility is stricter: a directional idle must not
	# turn an existing undirected death strip into a standing death pose.
	for direction in CA.DIRECTIONS:
		var death: Array = art.unit_anim_frames(DIRECTIONAL_KEY, "death", direction)
		var expected_death := ANIM_DIR.path_join(DIRECTIONAL_KEY + "_death.png")
		_check("legacy death survives directional idle " + direction,
			death.size() == 2 and _frame_source(death[0]) == expected_death \
				and not art.unit_anim_uses_directional_source(DIRECTIONAL_KEY, "death", direction),
			{"expected":expected_death, "actual":_frame_source(death[0]) if not death.is_empty() else ""})


func _test_legacy_art(art: Node) -> void:
	var expected := ANIM_DIR.path_join(LEGACY_KEY + "_walk.png")
	var old_signature: Array = art.unit_anim_frames(LEGACY_KEY, "walk")
	_check("legacy two-argument animation signature still loads",
		old_signature.size() == 2 and _frame_source(old_signature[0]) == expected)
	for direction in CA.DIRECTIONS:
		var directional_query: Array = art.unit_anim_frames(LEGACY_KEY, "walk", direction)
		_check("legacy undirected animation fallback " + direction,
			directional_query.size() == 2 and _frame_source(directional_query[0]) == expected \
				and not art.unit_anim_uses_directional_source(LEGACY_KEY, "walk", direction),
			{"expected":expected, "actual":_frame_source(directional_query[0]) if not directional_query.is_empty() else ""})


func _test_unit_frame_directionality(art: Node) -> void:
	for direction in CA.DIRECTIONS:
		var unit = _make_unit(DIRECTIONAL_KEY,
			{"name":"方向绘制夹具", "hp":100, "atk":10, "cd":1.0, "range":24, "speed":70})
		unit.animation_direction = direction
		unit._move_blend = 1.0
		var idle: Array = art.unit_anim_frames(DIRECTIONAL_KEY, "idle", direction)
		var actual = unit._anim_frame_for_state(idle[0]) if not idle.is_empty() else null
		var expected := ANIM_DIR.path_join("%s_walk_%s.png" % [DIRECTIONAL_KEY, direction])
		_check("Unit marks exact four-direction frame as non-mirrored " + direction,
			actual != null and _frame_source(actual) == expected and unit._frame_directional,
			{"expected":expected, "actual":_frame_source(actual) if actual != null else "",
				"frame_directional":unit._frame_directional})
		unit.queue_free()
	var legacy = _make_unit(LEGACY_KEY,
		{"name":"旧镜像夹具", "hp":100, "atk":10, "cd":1.0, "range":24, "speed":70})
	legacy.animation_direction = "sw"
	legacy._move_blend = 1.0
	var legacy_idle: Array = art.unit_anim_frames(LEGACY_KEY, "idle", "sw")
	var legacy_frame = legacy._anim_frame_for_state(legacy_idle[0]) if not legacy_idle.is_empty() else null
	_check("Unit keeps legacy undirected frame eligible for horizontal mirror",
		legacy_frame != null and _frame_source(legacy_frame) == ANIM_DIR.path_join(LEGACY_KEY + "_walk.png") \
			and not legacy._frame_directional,
		{"actual":_frame_source(legacy_frame) if legacy_frame != null else "",
			"frame_directional":legacy._frame_directional})
	legacy.queue_free()


func _test_generic_hurt_directionality(art: Node) -> void:
	for direction in CA.DIRECTIONS:
		var unit = _make_unit(DIRECTIONAL_KEY,
			{"name":"通用受伤夹具", "hp":100, "atk":10, "cd":1.0, "range":24, "speed":70})
		unit.animation_direction = direction
		unit._flinch = Vector2(2.0, 0.0)
		var idle: Array = art.unit_anim_frames(DIRECTIONAL_KEY, "idle", direction)
		var actual = unit._anim_frame_for_state(idle[0]) if not idle.is_empty() else null
		var expected := ANIM_DIR.path_join("%s_hurt_%s.png" % [DIRECTIONAL_KEY, direction])
		_check("generic Unit selects exact directional hurt " + direction,
			unit.art_variant.is_empty() and actual != null and _frame_source(actual) == expected \
				and unit._frame_directional,
			{"expected":expected, "actual":_frame_source(actual) if actual != null else "",
				"frame_directional":unit._frame_directional})
		unit.queue_free()


func _test_explicit_weapon_profiles() -> void:
	var wu = _make_unit("wu_song", _unit_definitions["wu_song"])
	_check("generic wu_song keeps blade weapon profile", wu._weapon_kind() == 0,
		{"weapon_kind":wu._weapon_kind(), "expected":"SWORD"})
	wu.art_variant = "wu_song_mengzhou"
	_check("wu_song_mengzhou remains fist weapon profile", wu._weapon_kind() == 4,
		{"weapon_kind":wu._weapon_kind(), "expected":"FIST"})
	wu.queue_free()

	var linked = _make_unit("lian_huan_ma", _unit_definitions["lian_huan_ma"])
	_check("lian_huan_ma uses spear weapon profile", linked._weapon_kind() == 1,
		{"weapon_kind":linked._weapon_kind(), "expected":"SPEAR"})
	linked.queue_free()

	# Keep one ordinary range-derived unit in the fixture so this change cannot
	# accidentally replace the existing heuristic for unrelated definitions.
	var ordinary = _make_unit("liang_dao", _unit_definitions["liang_dao"])
	_check("unrelated melee unit keeps range-derived sword profile", ordinary._weapon_kind() == 0,
		{"weapon_kind":ordinary._weapon_kind(), "expected":"SWORD"})
	ordinary.queue_free()


func _test_jiang_menshen_story_pose_routing(art: Node) -> void:
	for direction in CA.DIRECTIONS:
		var menshen = _make_unit("jiang_menshen", _unit_definitions["jiang_menshen"])
		menshen.art_variant = "jiang_menshen_fists"
		menshen.animation_direction = direction
		var idle: Array = art.unit_anim_frames("jiang_menshen", "idle", direction, menshen.art_variant)
		var expected_attack := CA.animation_path(menshen.art_variant, "attack", direction)
		var expected_idle := CA.animation_path(menshen.art_variant, "idle", direction)
		menshen.set_meta("story_pose", "rush_windup")
		var rush_frame = menshen._anim_frame_for_state(idle[0]) if not idle.is_empty() else null
		_check("Jiang rush_windup uses exact attack start " + direction,
			rush_frame != null and _frame_source(rush_frame) == expected_attack and menshen._frame_directional,
			{"expected":expected_attack,"actual":_frame_source(rush_frame) if rush_frame != null else ""})
		menshen.set_meta("story_pose", "windup")
		var heavy_frame = menshen._anim_frame_for_state(idle[0]) if not idle.is_empty() else null
		_check("Jiang windup keeps exact attack start " + direction,
			heavy_frame != null and _frame_source(heavy_frame) == expected_attack and menshen._frame_directional)
		menshen.set_meta("story_pose", "unrelated_pose")
		var unrelated_frame = menshen._anim_frame_for_state(idle[0]) if not idle.is_empty() else null
		_check("unrelated Jiang story pose stays idle " + direction,
			unrelated_frame != null and _frame_source(unrelated_frame) == expected_idle and menshen._frame_directional,
			{"expected":expected_idle,"actual":_frame_source(unrelated_frame) if unrelated_frame != null else ""})
		menshen.queue_free()

		var wu = _make_unit("wu_song", _unit_definitions["wu_song"])
		wu.art_variant = "wu_song_mengzhou"
		wu.animation_direction = direction
		var wu_idle: Array = art.unit_anim_frames("wu_song", "idle", direction, wu.art_variant)
		wu.set_meta("story_pose", "rush_windup")
		var wu_frame = wu._anim_frame_for_state(wu_idle[0]) if not wu_idle.is_empty() else null
		_check("rush_windup does not affect another variant " + direction,
			wu_frame != null and _frame_source(wu_frame) == CA.animation_path(wu.art_variant, "idle", direction),
			{"actual":_frame_source(wu_frame) if wu_frame != null else ""})
		wu.queue_free()


func _test_all_movable_unit_facing() -> Dictionary:
	var tested: Array[String] = []
	var failed: Dictionary = {}
	var keys: Array = _unit_definitions.keys()
	keys.sort()
	for raw_key in keys:
		var key := String(raw_key)
		var definition: Dictionary = _unit_definitions[key]
		if bool(definition.get("building", false)) or definition.has("res_kind") \
				or float(definition.get("speed", 0.0)) <= 0.0:
			continue
		var unit = _make_unit(key, definition)
		unit.art_variant = ""
		var missed: Array[String] = []
		for direction in CA.DIRECTIONS:
			var prior: String = OPPOSITE[direction]
			unit.animation_direction = prior
			unit._direction_candidate = prior
			unit._direction_votes = 0
			# Normal movement updates are deliberately damped by four votes.
			for vote in range(4):
				unit._face_dir(LOGIC_DIRECTIONS[direction])
			if unit.animation_direction != direction:
				missed.append(direction)
		if not missed.is_empty():
			failed[key] = missed
		tested.append(key)
		unit.queue_free()
	_check("every ordinary movable unit updates all four directions",
		not tested.is_empty() and failed.is_empty(),
		{"tested_count":tested.size(), "failed":failed})
	return {"tested":tested, "failed":failed}


func _test_attack_direction_lock() -> void:
	for direction in CA.DIRECTIONS:
		var attacker = _make_unit(DIRECTIONAL_KEY,
			{"name":"方向攻击夹具", "hp":100, "atk":10, "cd":1.0, "range":24, "speed":70})
		var target = _make_unit("qa_direction_target",
			{"name":"攻击目标", "hp":100, "atk":0, "cd":1.0, "range":24, "speed":70})
		attacker.position = Vector2.ZERO
		target.position = LOGIC_DIRECTIONS[direction]
		attacker.animation_direction = OPPOSITE[direction]
		attacker._direction_candidate = OPPOSITE[direction]
		attacker._direction_votes = 0
		attacker._target = target
		attacker._attack()
		var began_facing: bool = attacker.animation_direction == direction and attacker._lunge > 0.0
		for vote in range(4):
			attacker._face_dir(LOGIC_DIRECTIONS[OPPOSITE[direction]])
		_check("attack windup locks direction " + direction,
			began_facing and attacker.animation_direction == direction,
			{"actual":attacker.animation_direction, "lunge":attacker._lunge})
		attacker.queue_free()
		target.queue_free()


func _test_cast_direction_lock() -> void:
	var battle = _battle_script.new()
	battle._abilities = {CAST_ID:{
		"target":"point", "targeted":true, "cast_windup":0.75,
		"effect":{"kind":"damage", "cast_range":400.0},
	}}
	for direction in CA.DIRECTIONS:
		var caster = _make_unit(DIRECTIONAL_KEY,
			{"name":"方向施法夹具", "hp":100, "atk":10, "cd":1.0, "range":24, "speed":70})
		caster.position = Vector2.ZERO
		caster.ability_slots = [{"id":CAST_ID}]
		caster.animation_direction = OPPOSITE[direction]
		caster._direction_candidate = OPPOSITE[direction]
		caster._direction_votes = 0
		battle._begin_cast(caster, 0, LOGIC_DIRECTIONS[direction])
		var began_facing: bool = caster.animation_direction == direction and caster._cast_t > 0.0
		for vote in range(4):
			caster._face_dir(LOGIC_DIRECTIONS[OPPOSITE[direction]])
		_check("cast windup locks direction " + direction,
			began_facing and caster.animation_direction == direction,
			{"actual":caster.animation_direction, "cast_t":caster._cast_t})
		caster.queue_free()
		battle._pending_casts.clear()
	battle.free()


func _write_report(movable: Dictionary) -> void:
	var report := {
		"passed":failures.is_empty(),
		"checks":checks,
		"failures":failures,
		"ordinary_movable_count":movable.get("tested", []).size(),
		"ordinary_movable_failures":movable.get("failed", {}),
		"fixture_directory":FIXTURE_DIR,
		"production_source_files_persistently_modified":false,
		"temporary_assets_anim_proxy_cleanup":_test_proxies_absent(),
	}
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  ") + "\n")
		output.close()
	else:
		failures.append("report opens")
	print("[direction4-result] ", JSON.stringify(report))


func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	_stop_test_audio()
	# Loading these after the first deferred frame mirrors normal project startup;
	# direct --script parsing otherwise resolves their autoload references before
	# the corresponding singletons exist.
	_unit_script = load("res://scripts/unit.gd")
	_battle_script = load("res://scripts/battle.gd")
	var definitions_script = load("res://scripts/defs.gd")
	var runtime_scripts_ok: bool = _unit_script != null and _battle_script != null \
		and definitions_script != null and _unit_script.can_instantiate() \
		and _battle_script.can_instantiate() and definitions_script.can_instantiate()
	_check("production Unit/Battle/Defs scripts instantiate", runtime_scripts_ok)
	if not runtime_scripts_ok:
		_write_report({"tested":[], "failed":{}})
		quit(1)
		return
	_unit_definitions = definitions_script.UNITS
	DirAccess.make_dir_recursive_absolute(_absolute(RUNTIME_DIR))
	_clean_test_proxies()
	var fixture_failures: Array[String] = []
	for filename in FIXTURE_FILES:
		if not _install_fixture_proxy(filename):
			fixture_failures.append(filename)
	_check("all test-only animation proxies install", fixture_failures.is_empty(), fixture_failures)
	var art := root.get_node("Art")
	_clear_art_fixture_cache(art)
	_test_directional_art(art)
	_test_legacy_art(art)
	_test_unit_frame_directionality(art)
	_test_generic_hurt_directionality(art)
	_test_explicit_weapon_profiles()
	_test_jiang_menshen_story_pose_routing(art)
	var movable := _test_all_movable_unit_facing()
	_test_attack_direction_lock()
	_test_cast_direction_lock()
	await process_frame
	_clear_art_fixture_cache(art)
	_clean_test_proxies()
	_check("temporary assets/anim proxies are removed", _test_proxies_absent())
	_write_report(movable)
	_stop_test_audio()
	# Give the audio server time to release the stopped playback objects.
	for frame in range(3):
		await process_frame
	quit(0 if failures.is_empty() else 1)
