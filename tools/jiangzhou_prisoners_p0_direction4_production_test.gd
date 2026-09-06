extends SceneTree
## Targeted production contract for Song Jiang and Dai Zong at the Jiangzhou
## execution ground and after rescue. It verifies exact imported files,
## portraits, four real rescued walk frames, and directional Art routing.

const MANIFEST := "res://assets/campaign/jiangzhou_prisoners_p0_direction4_manifest.json"
const REPORT := "res://qa/jiangzhou_prisoners_p0_direction4_production_20260903/runtime_report.json"
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const CHARACTERS := [
	{"key": "song_jiang", "bound": "song_jiang_bound", "rescued": "song_jiang_rescued"},
	{"key": "dai_zong", "bound": "dai_zong_bound", "rescued": "dai_zong_rescued"},
]

var checks: Array[Dictionary] = []
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[jiangzhou-prisoners] ", "PASS " if passed else "FAIL ", name,
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
	_check("final four-frame provenance kind",
		manifest.get("schema_version") == 2
		and manifest.get("kind") == "jiangzhou_prisoners_exact_web_cleanup_fixed_grid_four_frame_production_provenance")
	_check("production manifest contains 28 outputs",
		manifest.get("production_file_count") == 28 and manifest.get("outputs", []).size() == 28)
	_check("web cleanup and local-operation gates",
		manifest.get("web_alpha_cleanup_performed") is bool and manifest.web_alpha_cleanup_performed
		and manifest.get("local_alpha_cleanup_performed") is bool and not manifest.local_alpha_cleanup_performed
		and manifest.get("masking_or_connected_component_isolation_performed") is bool
		and not manifest.masking_or_connected_component_isolation_performed
		and manifest.get("mirroring_or_repainting_performed") is bool and not manifest.mirroring_or_repainting_performed
		and manifest.get("steam_modified_or_exported") is bool and not manifest.steam_modified_or_exported)
	_check("preserved pre-batch backup hash",
		String(manifest.get("backup_manifest_sha256", "")).to_upper()
		== "3434F03C3818AB562B652EE21CF81D93A151C013152DD23DEB0BD8C8C84B8EBB")
	var outputs := _output_map(manifest)
	for spec in CHARACTERS:
		var key: String = spec.key
		var bound: String = spec.bound
		var rescued: String = spec.rescued
		for direction in DIRECTIONS:
			_validate_animation(art, outputs, key, bound, "idle", direction, 1)
			_validate_animation(art, outputs, key, rescued, "idle", direction, 1)
			_validate_animation(art, outputs, key, rescued, "walk", direction, 4)
		_check(bound + " has no exact walk substitute",
			not art.campaign_variant_has_animation(bound, "walk", "se"))
		_check(rescued + " invalid direction is absent",
			not art.campaign_variant_has_animation(rescued, "walk", "wrong"))
		for variant in [bound, rescued]:
			var portrait_path := "res://assets/campaign/portraits/%s.png" % variant
			var portrait_row: Dictionary = outputs.get("portrait|%s|<null>|se" % variant, {})
			var portrait: Texture2D = art.avatar_texture(key, variant)
			_check(variant + " portrait manifest row", not portrait_row.is_empty())
			_check(variant + " exact portrait path", _source(portrait) == portrait_path, _source(portrait))
			if not portrait_row.is_empty() and FileAccess.file_exists(portrait_path):
				var portrait_hash := FileAccess.get_sha256(ProjectSettings.globalize_path(portrait_path))
				_check(variant + " portrait hash", portrait_hash.to_upper() == String(portrait_row.production_sha256).to_upper())
	_finish()


func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var report := {
		"passed": failures.is_empty(),
		"checks": checks.size(),
		"failures": failures,
		"results": checks,
		"scope": "Jiangzhou Song Jiang and Dai Zong bound idle, rescued idle, rescued four-frame walk, four exact directions, portraits, provenance gates and preserved backup",
		"excluded": ["mission progression", "human playtest", "performance", "Steam build or upload"],
	}
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	for unused in range(3):
		await process_frame
	quit(0 if failures.is_empty() else 1)
