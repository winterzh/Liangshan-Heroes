extends "res://tools/campaign_mode_performance_test.gd"
## Shared setup for full-helper rendering and timing with per-run source receipts.
var rr_manifest := {}
var rr_manifest_path := ""
var rr_anchor := Vector2.ZERO
var rr_source_before := {}
var rr_source_after := {}
const RR_SOURCE_DIRECTORIES := ["scripts", "scenes", "assets", "shaders", "resources", "data",
	"addons", "content", "scenarios", "tools/contracts/redraw_reject"]
const RR_FIXED_SOURCE_FILES := ["project.godot", "tools/prepare_redraw_reject_validation.py",
	"tools/redraw_reject_qa.gd", "tools/redraw_reject_timing.gd",
	"tools/redraw_reject_validation_base.gd", "tools/campaign_mode_performance_test.gd"]

func rr_prefs() -> Dictionary:
	var saved := {}
	for path in ["user://campaign.cfg", "user://settings.cfg"]:
		saved[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return saved

func rr_directory_entries(relative: String):
	# Absolute filesystem access avoids imported-resource/PCK directory remapping.
	var dir := DirAccess.open(ProjectSettings.globalize_path("res://" + relative))
	if dir == null:
		check(false, "source directory cannot open: " + relative + " error=" + str(DirAccess.get_open_error()))
		return null
	dir.include_hidden = true
	dir.include_navigational = false
	var error := dir.list_dir_begin()
	if error != OK:
		check(false, "source directory cannot enumerate: " + relative + " error=" + str(error))
		return null
	var entries := []
	var name := dir.get_next()
	while not name.is_empty():
		entries.append({"name": name, "directory": dir.current_is_dir(), "link": dir.is_link(name)})
		name = dir.get_next()
	dir.list_dir_end()
	return entries

func rr_walk_sources(relative: String, files: Dictionary, directories: Dictionary) -> bool:
	var entries = rr_directory_entries(relative)
	if entries == null: return false
	directories[relative] = true
	for entry in entries:
		var path: String = relative + "/" + entry.name
		if entry.link:
			check(false, "source link/reparse point requires review: " + path)
			return false
		if entry.directory:
			if not rr_walk_sources(path, files, directories): return false
		else:
			files[path] = true
	return true

func rr_enumerate_sources() -> Dictionary:
	var files := {}
	var directories := {}
	var presence := {}
	var entries = rr_directory_entries("")
	if entries == null: return {"valid": false}
	var root_entries := {}
	for entry in entries:
		root_entries[entry.name] = entry
		if String(entry.name).to_lower().begins_with("icon."):
			if entry.link:
				check(false, "root icon link requires review: " + entry.name)
				return {"valid": false}
			if not entry.directory: files[entry.name] = true
	for path in RR_SOURCE_DIRECTORIES:
		# Optional roots are explicitly absent only when the root listing proves it.
		# Contracts is required; its parent directory and entry must be readable.
		var parent: String = path.get_base_dir()
		var directory_entry: Variant = root_entries.get(path)
		if not parent.is_empty():
			var nested_entries = rr_directory_entries(parent)
			if nested_entries == null: return {"valid": false}
			for entry in nested_entries:
				if entry.name == path.get_file(): directory_entry = entry
			if directory_entry == null:
				check(false, "required contracts directory missing: " + path)
				return {"valid": false}
		presence[path] = directory_entry != null
		if directory_entry == null: continue
		if directory_entry.link or not directory_entry.directory:
			check(false, "source directory replaced or linked: " + path)
			return {"valid": false}
		if not rr_walk_sources(path, files, directories): return {"valid": false}
	for path in rr_manifest.source_scope.fixed_files + rr_manifest.source_scope.generated_files:
		var absolute := ProjectSettings.globalize_path("res://" + path)
		var parent_dir := DirAccess.open(absolute.get_base_dir())
		if parent_dir == null or not FileAccess.file_exists(absolute):
			check(false, "required source file missing/unreadable: " + path)
			return {"valid": false}
		if parent_dir.is_link(absolute.get_file()):
			check(false, "required source file is a link: " + path)
			return {"valid": false}
		files[path] = true
	var paths: Array = files.keys()
	var dirs: Array = directories.keys()
	paths.sort()
	dirs.sort()
	return {"valid": true, "file_paths": paths, "directory_paths": dirs, "directory_presence": presence}

func rr_same_source_paths(actual: Dictionary, expected: Dictionary) -> bool:
	return bool(actual.get("valid", false)) and bool(expected.get("valid", false)) \
		and actual.file_paths == expected.file_paths and actual.directory_paths == expected.directory_paths \
		and actual.directory_presence == expected.directory_presence

func rr_file_sha(path: String, normalize_lf: bool) -> String:
	var file := FileAccess.open(ProjectSettings.globalize_path("res://" + path), FileAccess.READ)
	if file == null:
		check(false, "source file cannot open: " + path + " error=" + str(FileAccess.get_open_error()))
		return ""
	var length := file.get_length()
	var raw := file.get_buffer(length)
	var error := file.get_error()
	var complete := raw.size() == length and file.get_length() == length and error in [OK, ERR_FILE_EOF]
	file.close()
	if not complete:
		check(false, "source file read incomplete/failed: " + path)
		return ""
	if normalize_lf:
		# Match Python's byte replacement exactly, including BOM/invalid UTF-8 bytes.
		var normalized := PackedByteArray()
		for index in range(raw.size()):
			if raw[index] == 13 and index + 1 < raw.size() and raw[index + 1] == 10: continue
			normalized.append(raw[index])
		raw = normalized
	var hasher := HashingContext.new()
	if hasher.start(HashingContext.HASH_SHA256) != OK or hasher.update(raw) != OK:
		check(false, "source hashing failed: " + path)
		return ""
	return hasher.finish().hex_encode()

func rr_source_snapshot() -> Dictionary:
	var snapshot := rr_enumerate_sources()
	var paths_match := rr_same_source_paths(snapshot, rr_manifest.prepared_source_snapshot)
	check(paths_match, "full source path set and directory presence match preparation")
	if not paths_match:
		snapshot["valid"] = false
		return snapshot
	var hashes := {}
	var combined := PackedStringArray()
	for path in snapshot.file_paths:
		var digest := rr_file_sha(path, rr_manifest.sources[path].normalize_lf)
		if digest.is_empty():
			snapshot["valid"] = false
			return snapshot
		hashes[path] = digest
		combined.append(path + "\t" + digest)
	var stable := rr_same_source_paths(rr_enumerate_sources(), snapshot)
	check(stable, "source paths remain stable while hashing")
	snapshot.merge({"valid": stable, "file_sha256": hashes,
		"combined_sha256": "\n".join(combined).sha256_text(), "file_count": hashes.size()}, true)
	return snapshot

func rr_write_source_receipt(name: String, snapshot: Dictionary) -> void:
	var file := FileAccess.open(output.path_join(name), FileAccess.WRITE)
	if file == null:
		check(false, "cannot write source receipt: " + name)
		return
	file.store_string(JSON.stringify(snapshot, "\t"))
	file.close()

func rr_check_sources() -> bool:
	rr_source_after = rr_source_snapshot()
	rr_write_source_receipt("source_after.json", rr_source_after)
	return bool(rr_source_after.get("valid", false)) and bool(rr_source_before.get("valid", false)) \
		and rr_source_after.file_sha256 == rr_source_before.file_sha256

func rr_setup():
	if DisplayServer.get_name() == "headless":
		push_error("Render/full-helper timing needs a real renderer")
		return null
	rr_manifest_path = OS.get_environment("REDRAW_VALIDATION_MANIFEST")
	output = OS.get_environment("REDRAW_VALIDATION_OUT")
	if rr_manifest_path.is_empty() or output.is_empty():
		push_error("Set REDRAW_VALIDATION_MANIFEST and REDRAW_VALIDATION_OUT")
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(rr_manifest_path))
	if not parsed is Dictionary or parsed.get("schema", 0) != 2 or not parsed.has("source_scope") \
		or not parsed.has("sources") or not parsed.has("prepared_source_snapshot"):
		push_error("Prepare a new schema-2 redraw validation manifest before running")
		return null
	rr_manifest = parsed
	var scope: Dictionary = rr_manifest.source_scope
	var generated := []
	for name in ["old_render_unit.gd", "new_render_unit.gd", "timing_unit.gd"]:
		generated.append(rr_manifest_path.get_base_dir().path_join(name).trim_prefix("res://"))
	generated.sort()
	var expected_paths: Array = rr_manifest.sources.keys()
	expected_paths.sort()
	check(rr_manifest_path.begins_with("res://.godot/") and scope.get("directory_roots") == RR_SOURCE_DIRECTORIES \
		and scope.get("fixed_files") == RR_FIXED_SOURCE_FILES and scope.get("generated_files") == generated \
		and scope.get("include_hidden") == true and scope.get("root_icon_prefix") == "icon." \
		and scope.get("links") == "reject" and expected_paths == rr_manifest.prepared_source_snapshot.get("file_paths"),
		"manifest retains the complete shared source enumeration scope")
	if not failures.is_empty(): return null
	DirAccess.make_dir_recursive_absolute(output)
	rr_source_before = rr_source_snapshot()
	rr_write_source_receipt("source_before.json", rr_source_before)
	check(bool(rr_source_before.get("valid", false)) and rr_source_before.get("file_sha256") == rr_manifest.prepared_source_snapshot.file_sha256,
		"actual source matches this run's prepared snapshot")
	if not failures.is_empty(): return null
	OS.set_environment("CAMPAIGN_QA", "1")
	AudioServer.set_bus_mute(0, true)
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	root.size = Vector2i(960, 640)
	DisplayServer.window_set_size(root.size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.time_scale = 1.0
	Engine.max_fps = 60
	Engine.physics_ticks_per_second = 60
	var music = root.get_node("Music")
	var deadline: int = Time.get_ticks_usec() + 60_000_000
	while music._thr != null and music._thr.is_alive() and Time.get_ticks_usec() < deadline:
		await process_frame
	check(music._thr == null or not music._thr.is_alive(), "normal audio synthesis completes before fixture")
	if not failures.is_empty(): return null
	var b = await _start("level5")
	b.process_mode = Node.PROCESS_MODE_DISABLED
	b.set_process_input(false)
	b.set_process_unhandled_input(false)
	b.camera.set_process(false)
	b.camera.zoom = Vector2.ONE
	var highest := -INF
	for y in range(b.map.h):
		for x in range(b.map.w):
			var point: Vector2 = b.map.cell_to_world(Vector2i(x, y))
			var elevation: float = b.map.height_at(point)
			if elevation > highest:
				highest = elevation
				rr_anchor = point
	check(b.map.height_field != null and highest > 1.0, "actual level5 heightfield supplies non-flat anchor")
	check(b.to_screen(rr_anchor).distance_to(b.map.ISO * rr_anchor) > 1.0, "Battle projection includes real elevation")
	return b

func rr_view(b, location: String, population: int, lite := true) -> bool:
	var p: Vector2 = b.to_screen(rr_anchor)
	var extent: float = b.get_viewport().get_visible_rect().size.x * 0.5 / b.camera.zoom.x + 120.0
	var offset := 0.0
	if location == "inside_edge": offset = extent - 0.5
	elif location == "outside_edge": offset = extent + 0.5
	elif location == "offscreen": offset = extent + 80.0
	b.camera.position = p - Vector2(offset, 0)
	b.camera.force_update_scroll()
	b._grid_build() # Real viewport rectangle and projection; then set labelled load fixture.
	b._lite_fx = lite
	b._mob_count = population
	return b.unit_visual_active(rr_anchor)

func rr_finish(b, saved: Dictionary, extra: Dictionary) -> void:
	await _dispose(b, true)
	check(rr_check_sources(), "actual source unchanged through validation and disposal")
	check(rr_prefs() == saved, "campaign/settings save bytes unchanged")
	extra["checks"] = report.mode_checks
	extra["failures"] = failures
	extra["passed"] = failures.is_empty()
	extra["renderer"] = RenderingServer.get_current_rendering_method()
	extra["gpu"] = RenderingServer.get_video_adapter_name()
	extra["source_manifest"] = rr_manifest
	extra["source_before"] = rr_source_before
	extra["source_after"] = rr_source_after
	extra["performance_claim"] = false
	FileAccess.open(output.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(extra, "\t"))
	print("[redraw-validation] ", JSON.stringify({"checks":report.mode_checks.size(),"passed":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
