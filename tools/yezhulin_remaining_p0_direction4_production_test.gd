extends SceneTree
## Targeted production contract for the last seven four-direction states that
## still lacked accepted provenance after the 2026-09-03 reuse review.

const MANIFEST := "res://assets/campaign/yezhulin_remaining_p0_direction4_manifest.json"
const REPORT := "res://qa/yezhulin_remaining_p0_direction4_production_20260903/runtime_report.json"
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const SPECS := [
	{"key": "lin_chong", "variant": "lin_chong_escort", "states": {"idle": 1}},
	{"key": "dong_chao", "variant": "dong_chao_escort", "states": {"idle": 1, "walk": 4}},
	{"key": "xue_ba", "variant": "xue_ba_escort", "states": {"idle": 1, "walk": 4}},
	{"key": "shi_qian", "variant": "shi_qian_lantern", "states": {"idle": 1}},
	{"key": "shi_xiu", "variant": "bound_shi_xiu", "states": {"idle": 1}},
]

var checks: Array[Dictionary] = []
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[yezhulin-remaining] ", "PASS " if passed else "FAIL ", name,
		"" if detail == null else " :: " + JSON.stringify(detail))
	if not passed:
		failures.append(name)


func _source(texture: Texture2D) -> String:
	if texture == null:
		return ""
	if texture is AtlasTexture and texture.atlas != null:
		return texture.atlas.resource_path
	return texture.resource_path


func _output_map(manifest: Dictionary) -> Dictionary:
	var result := {}
	for row in manifest.get("outputs", []):
		var key := "%s|%s|%s|%s" % [row.kind, row.variant, str(row.state), str(row.direction)]
		result[key] = row
	return result


func _validate_animation(art, outputs: Dictionary, key: String, variant: String,
		state: String, direction: String, expected_frames: int) -> void:
	var label := "%s_%s_%s" % [variant, state, direction]
	var expected_path := "res://assets/campaign/anim/%s.png" % label
	var output_key := "animation|%s|%s|%s" % [variant, state, direction]
	var row: Dictionary = outputs.get(output_key, {})
	_check(label + " manifest row", not row.is_empty(), output_key)
	_check(label + " exact file exists", FileAccess.file_exists(expected_path), expected_path)
	if row.is_empty() or not FileAccess.file_exists(expected_path):
		return
	var actual_hash := FileAccess.get_sha256(ProjectSettings.globalize_path(expected_path))
	_check(label + " production hash", actual_hash.to_upper() == String(row.production_sha256).to_upper(),
		{"actual": actual_hash, "expected": row.production_sha256})
	var texture := load(expected_path) as Texture2D
	var expected_size := Vector2(256 * expected_frames, 256)
	_check(label + " imported strip geometry", texture != null and texture.get_size() == expected_size,
		texture.get_size() if texture != null else Vector2.ZERO)
	_check(label + " exact action exists", art.campaign_variant_has_animation(variant, state, direction))
	var frames: Array = art.unit_anim_frames(key, state, direction, variant)
	var all_exact := frames.size() == expected_frames
	var frame_hashes := {}
	for frame in frames:
		all_exact = all_exact and _source(frame) == expected_path
		frame_hashes[frame.get_image().get_data().hex_encode().sha256_text()] = true
	_check(label + " Art resolves exact frame count", all_exact,
		{"frame_count": frames.size(), "source": _source(frames[0]) if not frames.is_empty() else ""})
	_check(label + " decoded frames are distinct", frame_hashes.size() == expected_frames, frame_hashes.size())
	_check(label + " directional source flag",
		art.unit_anim_uses_directional_source(key, state, direction, variant))


func _run() -> void:
	await process_frame
	var art := root.get_node("Art")
	var manifest_data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	_check("production manifest parses", manifest_data is Dictionary, MANIFEST)
	if not manifest_data is Dictionary:
		_finish()
		return
	var manifest: Dictionary = manifest_data
	_check("final provenance kind",
		manifest.get("schema_version") == 1
		and manifest.get("kind") == "yezhulin_remaining_p0_exact_web_cleanup_fixed_grid_production_provenance")
	_check("production manifest contains 33 outputs",
		manifest.get("production_file_count") == 33 and manifest.get("outputs", []).size() == 33)
	_check("web cleanup and local-operation gates",
		manifest.get("web_alpha_cleanup_performed") is bool and manifest.web_alpha_cleanup_performed
		and manifest.get("local_alpha_cleanup_performed") is bool and not manifest.local_alpha_cleanup_performed
		and manifest.get("masking_or_connected_component_isolation_performed") is bool
		and not manifest.masking_or_connected_component_isolation_performed
		and manifest.get("mirroring_or_repainting_performed") is bool and not manifest.mirroring_or_repainting_performed
		and manifest.get("steam_modified_or_exported") is bool and not manifest.steam_modified_or_exported)
	var backup_value := String(manifest.get("backup_manifest", ""))
	var backup_res := "res://" + backup_value.trim_prefix("Liangshan-Heroes/")
	var backup_exists := FileAccess.file_exists(backup_res)
	_check("pre-batch backup manifest exists", backup_exists, backup_res)
	if backup_exists:
		var backup_hash := FileAccess.get_sha256(ProjectSettings.globalize_path(backup_res))
		_check("pre-batch backup manifest hash",
			backup_hash.to_upper() == String(manifest.get("backup_manifest_sha256", "")).to_upper(), backup_hash)

	var outputs := _output_map(manifest)
	for spec in SPECS:
		var key: String = spec.key
		var variant: String = spec.variant
		for state in spec.states:
			var expected_frames: int = spec.states[state]
			for direction in DIRECTIONS:
				_validate_animation(art, outputs, key, variant, state, direction, expected_frames)
		var portrait_path := "res://assets/campaign/portraits/%s.png" % variant
		var portrait_row: Dictionary = outputs.get("portrait|%s|<null>|se" % variant, {})
		var portrait: Texture2D = art.avatar_texture(key, variant)
		_check(variant + " portrait manifest row", not portrait_row.is_empty())
		_check(variant + " exact portrait path", _source(portrait) == portrait_path, _source(portrait))
		if not portrait_row.is_empty() and FileAccess.file_exists(portrait_path):
			var portrait_hash := FileAccess.get_sha256(ProjectSettings.globalize_path(portrait_path))
			_check(variant + " portrait hash",
				portrait_hash.to_upper() == String(portrait_row.production_sha256).to_upper())
	_check("invalid direction remains absent",
		not art.campaign_variant_has_animation("dong_chao_escort", "walk", "wrong"))
	_finish()


func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var report := {
		"passed": failures.is_empty(),
		"checks": checks.size(),
		"failures": failures,
		"results": checks,
		"scope": "Five variants covering the last seven provenance-noncompliant states: four exact directions, Dong Chao and Xue Ba four-frame walk, portraits, manifest hashes, operation gates and pre-batch backup.",
		"excluded": ["mission progression", "human playtest", "performance", "Steam build or upload"],
	}
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	for unused in range(3):
		await process_frame
	quit(0 if failures.is_empty() else 1)
