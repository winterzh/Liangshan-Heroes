extends SceneTree
## Read-only contract executed by the frozen exported Windows executable.
## The script itself stays outside the PCK and writes only to PACKAGE_DIRECTION_REPORT.

const UNITS := ["guan_dao", "guan_gong", "guan_jingqi", "guan_qi"]
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const STATE_FRAMES := {"idle": 1, "walk": 2, "attack": 3, "death": 4}
const ACTION_STATES := ["walk", "attack", "death"]
const FROZEN_EXE_SHA256 := "b333e117755c0a33fbbc5731fd3768514a68fce21c5e45dc730f38dd138bbfc1"
const SW_SOURCE_ALPHA_SHA256 := {
	"idle": "e8b2bb584d0ceb70f3f3e6b50c7f5eb2c77a9613e50a94a2dec8e6e14fe70768",
	"walk": "56056231427122c7a16466567e3bb9910745ce8238ba791c1b8d3f2db770f130",
	"attack": "c864356b00484766c51628d280c8651ad455a7e78b1ac4b7ba2f35e182c4836e",
	"death": "5afe3be87e322f8a5c0b388a92f2fb4749540e0d380095daf57e7c5662b2d75a",
}

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var resource_rows: Array[Dictionary] = []
var action_cells := 0
var accepted_action_cells := 0
var created_nodes: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, details: Variant = null) -> void:
	checks.append({"name": name, "passed": passed, "details": details})
	print("[package-direction] ", "PASS " if passed else "FAIL ", name,
		"" if details == null else " :: " + JSON.stringify(details))
	if not passed:
		failures.append(name)


func _expected_path(key: String, state: String, direction: String) -> String:
	return "res://assets/anim/%s_%s_%s.png" % [key, state, direction]


func _frame_source(frame: Variant) -> String:
	if frame is AtlasTexture and frame.atlas != null:
		return String(frame.atlas.resource_path)
	return String(frame.resource_path) if frame != null else ""


func _frame_image(frame: Variant) -> Image:
	if frame == null:
		return null
	if frame is AtlasTexture:
		if frame.atlas == null:
			return null
		var atlas_image: Image = frame.atlas.get_image()
		if atlas_image == null or atlas_image.is_empty():
			return null
		var region: Rect2 = frame.region
		return atlas_image.get_region(Rect2i(
			int(round(region.position.x)), int(round(region.position.y)),
			int(round(region.size.x)), int(round(region.size.y))))
	if frame is Texture2D:
		return frame.get_image()
	return null


func _same_pixels(left: Variant, right: Variant) -> bool:
	var a := _frame_image(left)
	var b := _frame_image(right)
	if a == null or b == null or a.get_size() != b.get_size():
		return false
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	return a.get_data() == b.get_data()


func _canonical_visible_rgba_sha(texture: Texture2D) -> String:
	if texture == null:
		return ""
	var image := texture.get_image()
	if image == null or image.is_empty():
		return ""
	image.convert(Image.FORMAT_RGBA8)
	var bytes := image.get_data()
	# Godot's lossless importer may fill RGB underneath alpha=0.  Those invisible
	# border pixels are deliberately normalized before comparing source semantics.
	for index in range(0, bytes.size(), 4):
		if bytes[index + 3] == 0:
			bytes[index] = 0
			bytes[index + 1] = 0
			bytes[index + 2] = 0
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if hashing.update(bytes) != OK:
		return ""
	return hashing.finish().hex_encode()


func _alpha_sha(texture: Texture2D) -> String:
	if texture == null:
		return ""
	var image := texture.get_image()
	if image == null or image.is_empty():
		return ""
	image.convert(Image.FORMAT_RGBA8)
	var rgba := image.get_data()
	var alpha := PackedByteArray()
	alpha.resize(image.get_width() * image.get_height())
	for pixel in alpha.size():
		alpha[pixel] = rgba[pixel * 4 + 3]
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if hashing.update(alpha) != OK:
		return ""
	return hashing.finish().hex_encode()


func _all_sources(frames: Array, expected: String) -> bool:
	if frames.is_empty():
		return false
	for frame in frames:
		if _frame_source(frame) != expected:
			return false
	return true


func _all_frame_metadata(frames: Array) -> bool:
	if frames.is_empty():
		return false
	for frame in frames:
		if frame == null or not bool(frame.get_meta("authored_direction4", false)):
			return false
		if not frame.get_meta("draw_offset_px", null) is Vector2:
			return false
	return true


func _recipe_matches(state: String, frames: Array, idle: Variant) -> bool:
	if idle == null or frames.size() != int(STATE_FRAMES[state]):
		return false
	match state:
		"walk":
			return _same_pixels(frames[0], idle) and not _same_pixels(frames[1], idle)
		"attack":
			return _same_pixels(frames[0], idle) and not _same_pixels(frames[1], idle) \
				and _same_pixels(frames[2], idle)
		"death":
			return _same_pixels(frames[0], idle) and not _same_pixels(frames[1], idle) \
				and not _same_pixels(frames[2], idle) and _same_pixels(frames[2], frames[3])
	return true


func _frame_index_in_strip(frame: Variant) -> int:
	if not frame is AtlasTexture:
		return -1
	var atlas_frame := frame as AtlasTexture
	if atlas_frame.region.size.x <= 0.0:
		return -1
	return int(round(atlas_frame.region.position.x / atlas_frame.region.size.x))


func _make_unit(unit_script, defs_script, key: String):
	var definition: Dictionary = (defs_script.UNITS[key] as Dictionary).duplicate(true)
	var unit = unit_script.new()
	unit.setup(key, definition, unit_script.FACTION_GUAN, null, null)
	root.add_child(unit)
	unit.set_process(false)
	unit.set_physics_process(false)
	created_nodes.append(unit)
	return unit


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var executable := OS.get_executable_path().replace("\\", "/")
	var cmdline := OS.get_cmdline_args()
	# Godot consumes --main-pack before OS.get_cmdline_args().  The wrapper binds
	# the exact argument here; this script independently hashes that frozen EXE.
	var mounted_pack := OS.get_environment("PACKAGE_MOUNTED_PACK").replace("\\", "/")
	var mounted_pack_sha := FileAccess.get_sha256(mounted_pack) if not mounted_pack.is_empty() else ""
	_check("console mounts the frozen exported EXE as main pack", not Engine.is_editor_hint()
		and mounted_pack.to_lower().ends_with("/liangshanheroes.exe")
		and mounted_pack_sha == FROZEN_EXE_SHA256, {
			"runner_executable": executable,
			"mounted_pack": mounted_pack,
			"mounted_pack_sha256": mounted_pack_sha,
			"expected_sha256": FROZEN_EXE_SHA256,
			"cmdline": cmdline,
			"editor_hint": Engine.is_editor_hint(),
			"display_server": DisplayServer.get_name(),
		})

	var alignment_script = load("res://scripts/skirmish_frame_alignment.gd")
	var unit_script = load("res://scripts/unit.gd")
	var defs_script = load("res://scripts/defs.gd")
	var battle_script = load("res://scripts/battle.gd")
	var shadow_script = load("res://scripts/world_shadow.gd")
	var art := root.get_node_or_null("Art")
	_check("frozen package loads direction alignment helper", alignment_script != null
		and alignment_script.can_instantiate())
	_check("frozen package loads Unit, Defs, Battle and WorldShadow", unit_script != null
		and defs_script != null and battle_script != null and shadow_script != null
		and unit_script.can_instantiate() and defs_script.can_instantiate()
		and battle_script.can_instantiate() and shadow_script.can_instantiate())
	_check("Art autoload is available in exported script run", art != null)
	if alignment_script == null or unit_script == null or defs_script == null \
			or battle_script == null or shadow_script == null or art == null:
		_finish()
		return
	_check("alignment helper exposes complete action recipes", alignment_script.RECIPES == {
		"idle": ["idle"], "walk": ["idle", "walk_step"],
		"attack": ["idle", "attack_strike", "idle"],
		"death": ["idle", "death_fall", "death_down", "death_down"],
	})

	for key in UNITS:
		for direction in DIRECTIONS:
			var idle_frames: Array = art.unit_anim_frames(key, "idle", direction, "")
			var idle = idle_frames[0] if idle_frames.size() == 1 else null
			for state in STATE_FRAMES:
				var expected := _expected_path(key, state, direction)
				var exists := ResourceLoader.exists(expected)
				var texture := load(expected) as Texture2D if exists else null
				var expected_frames := int(STATE_FRAMES[state])
				var shape_ok := texture != null and texture.get_height() == 256 \
					and texture.get_width() == 256 * expected_frames
				var frames: Array = art.unit_anim_frames(key, state, direction, "")
				var exact_route := frames.size() == expected_frames \
					and _all_sources(frames, expected) \
					and bool(art.unit_anim_uses_directional_source(key, state, direction, ""))
				var metadata_ok := _all_frame_metadata(frames)
				var every_frame_256 := not frames.is_empty()
				for frame in frames:
					var image := _frame_image(frame)
					if image == null or image.get_size() != Vector2i(256, 256):
						every_frame_256 = false
				var recipe_ok := _recipe_matches(state, frames, idle)
				var accepted := exists and shape_ok and exact_route and metadata_ok \
					and every_frame_256 and recipe_ok
				resource_rows.append({
					"unit": key, "direction": direction, "state": state,
					"path": expected, "resource_exists": exists,
					"texture_size": [texture.get_width(), texture.get_height()] if texture != null else [],
					"frame_count": frames.size(), "expected_frames": expected_frames,
					"selected_sources": frames.map(func(frame): return _frame_source(frame)),
					"exact_route": exact_route, "metadata": metadata_ok,
					"every_frame_256": every_frame_256, "recipe": recipe_ok,
					"accepted": accepted,
				})
				_check("%s %s %s packaged exact strip" % [key, state, direction], accepted,
					resource_rows[-1])
				if state in ACTION_STATES:
					action_cells += 1
					if accepted:
						accepted_action_cells += 1

	# The importer applies its color-space/alpha-border transform, so its decoded
	# RGB byte hash is not the source PNG byte hash. Bind the exact revised shape
	# through source-derived alpha, and retain the decoded RGBA hash as evidence.
	# Source PNG byte provenance is checked separately before staging/export.
	for state in SW_SOURCE_ALPHA_SHA256:
		var path := _expected_path("guan_gong", state, "sw")
		var texture := load(path) as Texture2D
		var actual_alpha := _alpha_sha(texture)
		_check("guan_gong %s SW matches approved source alpha" % state,
			actual_alpha == String(SW_SOURCE_ALPHA_SHA256[state]), {
				"path": path, "actual_alpha": actual_alpha,
				"expected_alpha": SW_SOURCE_ALPHA_SHA256[state],
				"decoded_visible_rgba_sha256": _canonical_visible_rgba_sha(texture),
			})

	# Exercise Unit's real attack/walk selectors rather than stopping at ArtDB.
	var playback = _make_unit(unit_script, defs_script, "guan_gong")
	playback.animation_direction = "sw"
	playback._move_blend = 1.0
	playback._lunge = 0.0
	playback._anim_t = 0.0
	var walk_first = playback._anim_frame_for_state(null)
	playback._anim_t = PI
	var walk_second = playback._anim_frame_for_state(null)
	_check("Unit playback selects both SW walk frames", _frame_index_in_strip(walk_first) == 0
		and _frame_index_in_strip(walk_second) == 1 and playback._frame_directional, {
			"indices": [_frame_index_in_strip(walk_first), _frame_index_in_strip(walk_second)],
			"sources": [_frame_source(walk_first), _frame_source(walk_second)],
		})
	playback._move_blend = 0.0
	var attack_indices: Array[int] = []
	for lunge in [1.0, 0.5, 0.01]:
		playback._lunge = lunge
		attack_indices.append(_frame_index_in_strip(playback._anim_frame_for_state(null)))
	_check("Unit playback uses idle-strike-idle attack timing", attack_indices == [0, 1, 2]
		and playback._frame_directional, {"indices": attack_indices})
	playback._lunge = 0.5
	playback._real_frames = true
	playback._frame_directional = true
	_check("authored SW attack suppresses extra programmatic motion and FX",
		is_zero_approx(playback._programmatic_swing_scale())
		and not playback._should_draw_programmatic_swing_fx())

	# Confirm the helper annotation is consumed in the actual Unit pixel-space API.
	var gong_death_se: Array = art.unit_anim_frames("guan_gong", "death", "se", "")
	var fall_meta: Vector2 = gong_death_se[1].get_meta("draw_offset_px", Vector2.ZERO)
	var down_meta: Vector2 = gong_death_se[2].get_meta("draw_offset_px", Vector2.ZERO)
	_check("reviewed guan_gong SE death offsets are packaged", fall_meta == Vector2(-29, -3)
		and down_meta == Vector2(20, -41), {"fall": fall_meta, "down": down_meta})
	_check("Unit scales packaged frame offsets from 256px space",
		playback._frame_draw_offset(gong_death_se[1], 64.0).is_equal_approx(Vector2(-7.25, -0.75)), {
			"actual": playback._frame_draw_offset(gong_death_se[1], 64.0),
		})

	# Spear visuals are a routing correction only; combat range remains unchanged.
	for key in ["guan_qi", "guan_jingqi"]:
		var definition: Dictionary = defs_script.UNITS[key]
		var cavalry = _make_unit(unit_script, defs_script, key)
		_check(key + " packaged definition retains range 26 and spear profile",
			int(definition.get("range", -1)) == 26
			and String(definition.get("weapon_profile", "")) == "spear", {
				"range": definition.get("range", null),
				"weapon_profile": definition.get("weapon_profile", ""),
			})
		_check(key + " runtime resolves spear weapon kind",
			cavalry._weapon_kind() == unit_script.WK.SPEAR, {
				"actual": cavalry._weapon_kind(), "spear": unit_script.WK.SPEAR,
			})

	# A lethal hit must not leave the red flash frozen throughout the death strip.
	var dying = _make_unit(unit_script, defs_script, "guan_dao")
	dying._dying = true
	dying._death_t = 0.0
	dying._flash = 0.18
	dying._phys_body(0.10)
	var flash_mid: float = dying._flash
	dying._phys_body(0.10)
	_check("lethal flash decays to zero during packaged death playback",
		is_equal_approx(flash_mid, 0.08) and is_zero_approx(dying._flash), {
			"after_0_1": flash_mid, "after_0_2": dying._flash,
		})

	# Package-level blood/debris semantics and delayed reveal.
	var battle = battle_script.new()
	var atlas := battle._death_remains_texture() as Texture2D
	_check("death-remains atlas resolves from packaged ArtDB", atlas != null
		and atlas.get_width() % 4 == 0 and atlas.get_height() % 2 == 0
		and atlas.get_width() / 4 == atlas.get_height() / 2, {
			"size": [atlas.get_width(), atlas.get_height()] if atlas != null else [],
		})
	_check("blood/equipment package constants keep restrained delayed reveal",
		battle_script.DEATH_REMAINS_SAFE_FRAMES == [0, 1, 2, 3, 5]
		and is_equal_approx(battle_script.DEATH_REMAINS_REVEAL_DELAY, 0.35)
		and is_equal_approx(battle_script.DEATH_REMAINS_REVEAL_FADE, 0.20)
		and float(battle_script.DEATH_REMAINS_FRAME_SCALE[0]) < 1.0
		and float(battle_script.DEATH_REMAINS_FRAME_SCALE[1]) < 1.0)
	var spear_probe = _make_unit(unit_script, defs_script, "guan_qi")
	var ranged_probe = _make_unit(unit_script, defs_script, "guan_gong")
	_check("death debris matches packaged unit roles",
		battle._death_remains_frame_for(spear_probe, 0) == 1
		and battle._death_remains_frame_for(ranged_probe, 0) == 3, {
			"spear": battle._death_remains_frame_for(spear_probe, 0),
			"ranged": battle._death_remains_frame_for(ranged_probe, 0),
		})
	var mark = battle_script.DeathRemains.new()
	mark.configure(atlas, 0, 56.0, Transform2D.IDENTITY, 45.0, 8.0,
		battle_script.DEATH_REMAINS_REVEAL_DELAY, battle_script.DEATH_REMAINS_FRAME_SCALE[0],
		battle_script.DEATH_REMAINS_FRAME_ANCHOR[0], "sw", Vector2.ZERO,
		battle_script.DEATH_REMAINS_REVEAL_FADE)
	_check("death mark starts hidden and has a valid packaged atlas frame",
		not mark.is_revealed() and is_zero_approx(mark.reveal_alpha())
		and mark.frame_texture != null)
	mark.age = battle_script.DEATH_REMAINS_REVEAL_DELAY \
		+ battle_script.DEATH_REMAINS_REVEAL_FADE
	_check("death mark fades in after the body begins falling",
		mark.is_revealed() and is_equal_approx(mark.reveal_alpha(), 1.0))

	# The shared shadow batch must retain a killed moving unit until its authored
	# body fade completes, while still exposing one batched draw submission.
	var shadow_battle = battle_script.new()
	var shadow_batch = shadow_script.ShadowBatch.new()
	# Retention itself is CPU-side.  Do not call setup() in this headless contract:
	# that would allocate dummy-renderer MultiMesh RIDs solely for the QA harness.
	shadow_batch.battle = shadow_battle
	var shadow_unit = _make_unit(unit_script, defs_script, "guan_dao")
	shadow_unit.battle = shadow_battle
	shadow_unit.hp = 0.0
	shadow_unit._dying = true
	shadow_batch.retain_dying_unit(shadow_unit)
	var retained: Dictionary = shadow_batch.summary()
	_check("packaged shadow batch retains one dying body", retained.get("retained_dying_units", 0) == 1, retained)
	shadow_batch.clear_retained_dying_units()
	_check("packaged shadow retention clears on section cleanup",
		shadow_batch.summary().get("retained_dying_units", -1) == 0,
		shadow_batch.summary())
	# These isolated helpers were intentionally never inserted into the tree.
	# Free them explicitly so the QA runner itself does not create RID/ObjectDB
	# shutdown noise that could be mistaken for a packaged-game defect.
	mark.free()
	battle.free()
	shadow_batch.free()
	shadow_battle.free()

	_finish()


func _finish() -> void:
	for node in created_nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()
	var report_path := OS.get_environment("PACKAGE_DIRECTION_REPORT")
	if report_path.is_empty():
		report_path = OS.get_user_data_dir().path_join("package_direction_contract.json")
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var report := {
		"kind": "steam_test_export_package_direction_contract",
		"schema": 1,
		"passed": failures.is_empty(),
		"execution_scope": "Godot console mounts the frozen exported LiangshanHeroes.exe with --main-pack; the external read-only QA script validates res:// resources from that embedded PCK. This is not the release EXE executing --script itself.",
		"runner_executable": OS.get_executable_path().replace("\\", "/"),
		"cmdline": OS.get_cmdline_args(),
		"engine": Engine.get_version_info(),
		"display_server": DisplayServer.get_name(),
		"editor_hint": Engine.is_editor_hint(),
		"checks": checks.size(),
		"failures": failures,
		"results": checks,
		"resource_rows": resource_rows,
		"resource_files_expected": UNITS.size() * DIRECTIONS.size() * STATE_FRAMES.size(),
		"resource_files_accepted": resource_rows.filter(func(row): return bool(row.accepted)).size(),
		"action_cells_expected": UNITS.size() * DIRECTIONS.size() * ACTION_STATES.size(),
		"action_cells_accepted": accepted_action_cells,
		"source_static_excluded": true,
		"human_visual_review": false,
		"performance_or_full_playthrough": false,
	}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	var wrote := file != null
	if wrote:
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
	print("PACKAGE_DIRECTION_CONTRACT_RESULT ", JSON.stringify({
		"passed": failures.is_empty(), "checks": checks.size(),
		"failures": failures.size(), "resources": report.resource_files_accepted,
		"resource_expected": report.resource_files_expected,
		"action_cells": accepted_action_cells, "action_expected": action_cells,
		"report": report_path, "report_written": wrote,
	}))
	for unused in range(3):
		await process_frame
	quit(0 if wrote and failures.is_empty() else 1)
