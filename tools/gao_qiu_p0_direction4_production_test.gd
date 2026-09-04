extends SceneTree
## Targeted production contract for the chapter-80 Gao flagship and wet-captive
## Gao Qiu. It verifies exact imported files, manifest/candidate byte identity,
## context-isolated text-only flag routing and the generic Gao Qiu hash lock.
## It is not a mission playthrough or human visual acceptance.

const CampaignArt := preload("res://scripts/campaign_art.gd")
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const SHIP_STATES := ["default", "damaged", "flooding", "disabled"]
const CAPTURED_STATES := ["idle", "down"]
const SHIP_MANIFEST := "res://assets/campaign/gao_flagship_direction4_manifest.json"
const CAPTURED_MANIFEST := "res://assets/campaign/gao_qiu_captured_direction4_manifest.json"
const REPORT := "res://qa/gao_qiu_p0_runtime_20260903/production_contract.json"

var checks: Array[Dictionary] = []
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[gao-qiu-p0] ", "PASS " if passed else "FAIL ", name,
		"" if detail == null else " :: " + JSON.stringify(detail))
	if not passed:
		failures.append(name)


func _res_path(project_relative: String) -> String:
	return "res://" + project_relative.trim_prefix("res://")


func _hash(path: String) -> String:
	return FileAccess.get_sha256(ProjectSettings.globalize_path(path)) if FileAccess.file_exists(path) else ""


func _source(texture: Texture2D) -> String:
	if texture == null:
		return ""
	if texture is AtlasTexture and texture.atlas != null:
		return texture.atlas.resource_path
	return texture.resource_path


func _load_manifest(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check("manifest parses " + path.get_file(), parsed is Dictionary, path)
	return parsed if parsed is Dictionary else {}


func _candidate_hash(output: Dictionary) -> String:
	var path := _res_path(String(output.get("candidate_path", "")))
	return _hash(path)


func _run() -> void:
	await process_frame
	var art := root.get_node("Art")
	var ship := _load_manifest(SHIP_MANIFEST)
	var captured := _load_manifest(CAPTURED_MANIFEST)
	_check("ship manifest gate", ship.get("frame_count") == 16
		and bool(ship.get("web_native_alpha", false))
		and not bool(ship.get("alpha_cleanup_performed", true))
		and bool(ship.get("manual_visual_review_passed", false))
		and ship.get("forbidden_operations_used", []) == [])
	_check("captured manifest gate", captured.get("frame_count") == 8
		and bool(captured.get("web_native_alpha", false))
		and not bool(captured.get("alpha_cleanup_performed", true))
		and bool(captured.get("manual_visual_review_passed", false))
		and captured.get("forbidden_operations_used", []) == [])

	var ship_outputs: Dictionary = {}
	for output in ship.get("outputs", []):
		ship_outputs[String(output.get("state", "")) + "_" + String(output.get("direction", ""))] = output
	for state in SHIP_STATES:
		var state_sources: Array[String] = []
		for direction in DIRECTIONS:
			var key: String = String(state) + "_" + String(direction)
			var output: Dictionary = ship_outputs.get(key, {})
			var expected := "res://assets/campaign/objects/gao_flagship_%s_%s.png" % [state, direction]
			var actual_hash := _hash(expected)
			_check("ship file and manifest hash " + key, not output.is_empty()
				and String(output.get("path", "")) == expected.trim_prefix("res://")
				and actual_hash == String(output.get("sha256", "")), {"actual": actual_hash, "manifest": output.get("sha256", "")})
			_check("ship production equals candidate " + key, actual_hash == String(output.get("candidate_sha256", ""))
				and actual_hash == _candidate_hash(output), output.get("candidate_path", ""))
			var texture := load(expected) as Texture2D
			_check("ship imported 512x512 " + key, texture != null and texture.get_size() == Vector2(512, 512),
				texture.get_size() if texture != null else Vector2.ZERO)
			_check("Art exact ship source " + key, bool(art.call("campaign_object_has_exact_directional_source", "gao_flagship", state, direction)))
			var runtime_texture := art.call("campaign_object_texture", "gao_flagship", state, direction) as Texture2D
			_check("Art resolves ship source " + key, _source(runtime_texture) == expected, _source(runtime_texture))
			state_sources.append(_source(runtime_texture))
		_check("ship four sources distinct " + state,
			state_sources.size() == 4 and state_sources.all(func(source): return state_sources.count(source) == 1), state_sources)

	var captured_outputs: Dictionary = {}
	for output in captured.get("outputs", []):
		captured_outputs[String(output.get("state", "")) + "_" + String(output.get("direction", ""))] = output
	for state in CAPTURED_STATES:
		var state_sources: Array[String] = []
		for direction in DIRECTIONS:
			var key: String = String(state) + "_" + String(direction)
			var output: Dictionary = captured_outputs.get(key, {})
			var expected := "res://assets/campaign/anim/gao_qiu_captured_%s_%s.png" % [state, direction]
			var actual_hash := _hash(expected)
			_check("captured file and manifest hash " + key, not output.is_empty()
				and String(output.get("path", "")) == expected.trim_prefix("res://")
				and actual_hash == String(output.get("sha256", "")), {"actual": actual_hash, "manifest": output.get("sha256", "")})
			_check("captured production equals candidate " + key, actual_hash == String(output.get("candidate_sha256", ""))
				and actual_hash == _candidate_hash(output), output.get("candidate_path", ""))
			var texture := load(expected) as Texture2D
			_check("captured imported 256x256 " + key, texture != null and texture.get_size() == Vector2(256, 256),
				texture.get_size() if texture != null else Vector2.ZERO)
			_check("exact captured variant state " + key, art.campaign_variant_has_animation("gao_qiu_captured", state, direction))
			var frames: Array = art.unit_anim_frames("gao_qiu", state, direction, "gao_qiu_captured")
			_check("Art resolves one captured frame " + key,
				frames.size() == 1 and _source(frames[0]) == expected,
				{"count": frames.size(), "source": _source(frames[0]) if not frames.is_empty() else ""})
			_check("captured source is directional " + key,
				art.unit_anim_uses_directional_source("gao_qiu", state, direction, "gao_qiu_captured"))
			state_sources.append(_source(frames[0]) if not frames.is_empty() else "")
		_check("captured four sources distinct " + state,
			state_sources.size() == 4 and state_sources.all(func(source): return state_sources.count(source) == 1), state_sources)

	var portrait: Dictionary = captured.get("portrait", {})
	var portrait_path := _res_path(String(portrait.get("path", "")))
	_check("captured portrait hash and candidate identity", portrait_path == "res://assets/campaign/portraits/gao_qiu_captured.png"
		and _hash(portrait_path) == String(portrait.get("sha256", ""))
		and _hash(portrait_path) == String(portrait.get("candidate_sha256", "")), portrait_path)
	_check("Art selects captured portrait", _source(art.avatar_texture("gao_qiu", "gao_qiu_captured")) == portrait_path)

	var protected_generic: Dictionary = captured.get("protected_generic_gao_qiu_sha256", {})
	_check("generic Gao Qiu baseline contains four atlases", protected_generic.size() == 4, protected_generic.size())
	for path in protected_generic:
		_check("generic Gao Qiu unchanged " + String(path).get_file(), _hash(_res_path(String(path))) == String(protected_generic[path]))

	var gao_spec := CampaignArt.flag_text_spec("gao_flagship_command")
	_check("flag spec is text-only and has no local repaint mask", String(gao_spec.get("text", "")) == "帅"
		and bool(gao_spec.get("text_only", false)) and not gao_spec.has("unlettered_masks"))
	_check("flag route requires exact context", String(CampaignArt.dynamic_flag_route("gao_flagship", "gao_flagship", "chapter80_gao_flagship").get("overlay_id", "")) == "gao_flagship_command"
		and CampaignArt.dynamic_flag_route("gao_flagship", "gao_flagship", "").is_empty()
		and CampaignArt.dynamic_flag_route("imperial_warship", "official_warship", "chapter80_gao_flagship").is_empty())
	var level5 := FileAccess.get_file_as_string("res://scripts/levels/level5_liangshan.gd")
	var flagship_spawn := level5.find('flagship=b.spawn_at("gao_flagship"')
	var flagship_context := level5.find('flagship.set_meta("campaign_flag_context","chapter80_gao_flagship")')
	_check("level5 binds context directly after Gao flagship spawn", flagship_spawn >= 0 and flagship_context > flagship_spawn and flagship_context - flagship_spawn < 240,
		{"spawn": flagship_spawn, "context": flagship_context})
	var captive_spawn := level5.find('gao=b.spawn_at("gao_qiu"')
	var captive_variant := level5.find('gao.art_variant="gao_qiu_captured"')
	_check("level5 binds wet-captive variant directly after exact Gao spawn", captive_spawn >= 0 and captive_variant > captive_spawn and captive_variant - captive_spawn < 180,
		{"spawn": captive_spawn, "variant": captive_variant})
	_finish()


func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var report := {
		"passed": failures.is_empty(),
		"checks": checks.size(),
		"failures": failures,
		"results": checks,
		"scope": "Gao flagship four states x four directions, wet-captive Gao two states x four directions, portrait, runtime Art routes, chapter80 context isolation and generic Gao hash lock.",
		"excluded": ["human playthrough", "full mission acceptance", "Steam build or upload"],
	}
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("[gao-qiu-p0-result] ", JSON.stringify({"passed": failures.is_empty(), "checks": checks.size(), "failures": failures, "report": REPORT}))
	for unused in range(3):
		await process_frame
	quit(0 if failures.is_empty() else 1)
