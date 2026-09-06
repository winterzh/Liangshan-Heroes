extends SceneTree

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var files: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(label: String, passed: bool, details: Variant = null) -> void:
	checks.append({"name": label, "passed": passed, "details": details})
	if not passed: failures.append(label)
	print("[package-contract] ", "PASS " if passed else "FAIL ", label)

func _list(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	dir.include_hidden = true
	for name in dir.get_files(): files.append(path.path_join(name))
	for name in dir.get_directories(): _list(path.path_join(name))

func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("PACKAGE_EXPECTED")))
	var pack := OS.get_environment("PACKAGE_MOUNTED_PACK")
	_check("exact exported EXE SHA256", FileAccess.get_sha256(pack) == expected.sha256)
	_check("release PCK mounted", not Engine.is_editor_hint() and ProjectSettings.globalize_path("res://") != expected.project.path_join(""))
	_list("res://")
	var forbidden: Array[String] = []
	for path in files:
		var relative := path.trim_prefix("res://")
		if relative.begins_with("qa/") or relative.begins_with("tools/") or relative.begins_with("docs/") \
			or relative.begins_with("build/") or relative.begins_with("assets/campaign/source/") \
			or relative.begins_with("assets/direction4/") or relative.contains("web_prompts") \
			or relative.contains("_raw") or relative.contains("sun_li_direction4_draft") \
			or relative.contains("godot.local") or relative.ends_with(".pem") \
			or relative.contains(".godot/editor/") or relative.contains(".godot/shader_cache/"):
			forbidden.append(path)
	_check("no drafts development credentials or editor files in package", forbidden.is_empty(), forbidden)
	var art := root.get_node_or_null("Art")
	_check("packaged Art autoload", art != null)
	var frame_count := 0
	for entry in expected.resources:
		var path: String = entry.path
		var frames_resource = load(path)
		_check(path + " is SpriteFrames", frames_resource is SpriteFrames)
		if not frames_resource is SpriteFrames: continue
		var count: int = frames_resource.get_frame_count(&"default")
		_check(path + " exact authored frame count", count == int(entry.frames), count)
		var routed: Array = art.unit_anim_frames(entry.key, entry.state, entry.direction)
		_check(path + " runtime routing preserves frame count", routed.size() == count)
		for index in range(count):
			var frame = frames_resource.get_frame_texture(&"default", index)
			var label := path + " frame " + str(index)
			_check(label + " authored atlas with foot anchor", frame is AtlasTexture and frame.atlas != null \
				and bool(frame.get_meta("authored_direction4", false)) and frame.get_meta("draw_offset_px", null) is Vector2 \
				and frame.get_width() == frame.get_height())
			if frame is AtlasTexture and frame.atlas != null:
				_check(label + " production source resolves", expected.sources.has(String(frame.atlas.resource_path)) \
					and frame.atlas.get_width() > 0 and frame.atlas.get_height() > 0, frame.atlas.resource_path)
			if index < routed.size():
				_check(label + " runtime frame matches", routed[index] == frame)
			frame_count += 1
	for path in expected.sources:
		var texture = load(path)
		_check(path + " imported production source", texture is Texture2D and texture.get_width() > 0 and texture.get_height() > 0)
	_check("all 36 current hero SpriteFrames checked", expected.resources.size() == 36)
	_check("all 22 native production sources checked", expected.sources.size() == 22)
	_check("all 100 authored timeline entries checked", frame_count == 100, frame_count)
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"check_count": checks.size(), "source_commit": expected.source_commit, "executable_sha256": expected.sha256,
		"embedded_pck_files": files, "forbidden_files": forbidden, "frame_count": frame_count,
		"scope": "Godot 4.6.3 console mounts exact release EXE embedded PCK; external QA script is not packaged."}
	var file := FileAccess.open(OS.get_environment("PACKAGE_REPORT"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n"); file.close()
	print("PACKAGE_CONTRACT_RESULT ", JSON.stringify({"passed": failures.is_empty(), "checks": checks.size(), "frames": frame_count, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
