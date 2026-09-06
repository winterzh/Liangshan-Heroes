extends SceneTree
## Targeted imported-runtime contract for the level-4 linked armored cavalry.
## It verifies manifest/candidate/production byte identity and exact Art routing
## for five states x four directions. It is not a mission playthrough.

const UNIT_KEY := "lian_huan_ma"
const STATES := ["idle", "walk", "attack", "hurt", "death"]
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const MANIFEST := "res://assets/direction4/lianhuanma_p0_direction4_manifest.json"
const REPORT := "res://qa/lianhuanma_p0_direction4_production_20260903/runtime_contract.json"

var checks: Array[Dictionary] = []
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[lian-huan-ma-direction4] ", "PASS " if passed else "FAIL ", name,
		"" if detail == null else " :: " + JSON.stringify(detail))
	if not passed:
		failures.append(name)


func _source(texture: Texture2D) -> String:
	if texture == null:
		return ""
	if texture is AtlasTexture and texture.atlas != null:
		return texture.atlas.resource_path
	return texture.resource_path


func _hash(path: String) -> String:
	return FileAccess.get_sha256(ProjectSettings.globalize_path(path)) if FileAccess.file_exists(path) else ""


func _run() -> void:
	await process_frame
	var art := root.get_node("Art")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	_check("production manifest parses", parsed is Dictionary, MANIFEST)
	var manifest: Dictionary = parsed if parsed is Dictionary else {}
	_check("production manifest scope", manifest.get("production_file_count") == 20
		and manifest.get("campaign_level") == 4
		and String(manifest.get("scene_context", "")) == "lianhuanma_battle"
		and bool(manifest.get("web_alpha_cleanup_performed", false))
		and not bool(manifest.get("local_alpha_cleanup_performed", true))
		and not bool(manifest.get("steam_modified_or_exported", true)))

	var outputs: Dictionary = {}
	for row in manifest.get("outputs", []):
		outputs[String(row.get("state", "")) + "_" + String(row.get("direction", ""))] = row
	_check("manifest has twenty unique state-direction outputs", outputs.size() == 20, outputs.size())

	for state in STATES:
		var state_sources: Array[String] = []
		for direction in DIRECTIONS:
			var key: String = state + "_" + direction
			var row: Dictionary = outputs.get(key, {})
			var expected := "res://assets/anim/%s_%s_%s.png" % [UNIT_KEY, state, direction]
			var candidate := "res://" + String(row.get("candidate_path", "")).trim_prefix("res://")
			var actual_hash := _hash(expected)
			_check("manifest and production hash " + key, not row.is_empty()
				and String(row.get("production_path", "")) == expected.trim_prefix("res://")
				and actual_hash == String(row.get("production_sha256", ""))
				and actual_hash == String(row.get("candidate_sha256", ""))
				and actual_hash == _hash(candidate), {
					"actual": actual_hash, "manifest": row.get("production_sha256", ""), "candidate": candidate})
			var texture := load(expected) as Texture2D
			var expected_size := Vector2(512, 256) if state == "walk" else Vector2(256, 256)
			_check("imported texture size " + key,
				texture != null and texture.get_size() == expected_size,
				texture.get_size() if texture != null else Vector2.ZERO)
			var frames: Array = art.unit_anim_frames(UNIT_KEY, state, direction, "")
			var expected_frames := 2 if state == "walk" else 1
			_check("Art resolves exact frames " + key,
				frames.size() == expected_frames and frames.all(func(frame): return _source(frame) == expected), {
					"frame_count": frames.size(),
					"sources": frames.map(func(frame): return _source(frame)),
				})
			_check("directional source flag " + key,
				art.unit_anim_uses_directional_source(UNIT_KEY, state, direction, ""))
			state_sources.append(expected)
		_check("four sources distinct " + state,
			state_sources.size() == 4 and state_sources.all(func(source): return state_sources.count(source) == 1),
			state_sources)

	var level4 := FileAccess.get_file_as_string("res://scripts/levels/level4_lianhuanma.gd")
	_check("authored level4 spawns exact linked cavalry key", 'spawn_at("lian_huan_ma"' in level4)
	_check("invalid direction cannot silently pass exact-source gate",
		not art.unit_anim_uses_directional_source(UNIT_KEY, "idle", "wrong", ""))
	_finish()


func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var report := {
		"passed": failures.is_empty(),
		"checks": checks.size(),
		"failures": failures,
		"results": checks,
		"scope": "lian_huan_ma idle/walk/attack/hurt/death x four exact directions, imported sizes, manifest/candidate byte identity, Art selection and level4 spawn key",
		"excluded": ["mission completion", "human playtest", "Steam build or upload"],
	}
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("LHM_DIRECTION4_CONTRACT_RESULT ", JSON.stringify({
		"passed": failures.is_empty(), "checks": checks.size(), "failures": failures, "report": REPORT}))
	for unused in range(3):
		await process_frame
	quit(0 if failures.is_empty() else 1)
