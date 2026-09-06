extends RefCounted
## No save/version/environment identity input. The host reads this exact rules string too.
const INPUT_RULES_JSON := """{"schema":1,"header":"liangshan-installed-inputs-v1","roots":["scripts","scenes","assets","content","scenarios","fonts","shaders","addons"],"required_roots":["scripts","scenes"],"root_files":["project.godot","export_presets.cfg","icon.png","icon.png.import","icon.ico"],"required_files":["project.godot"],"optional_content":["content/units.json","content/abilities.json"],"skip_directories":[".godot",".git","__pycache__"],"import_ignore_is_exclusion":false,"derived":"scripts/run_build_identity.gd","max_files":60000,"max_bytes":34359738368,"max_depth":40}"""
const BUILD_PATH := "res://scripts/run_build_identity.gd"
const PROVIDER_PATH := "res://scripts/run_content_identity.gd"
var _rules: Dictionary = {}
var _files: Dictionary = {}
var _dirs: Dictionary = {}
var _case_paths: Dictionary = {}
var _total_bytes: int = 0
var _error := ""
var _stamps: Dictionary = {}
var _verify_rows: Dictionary = {}
var _verify_stamps: Dictionary = {}

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "save_eligible": false, "save_code": code, "identity_scope": "installed_inputs"}

func _sha_text(text: String) -> String:
	return text.sha256_text()

func _valid_sha(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 64: return false
	for ch in value.to_utf8_buffer():
		if not (ch >= 48 and ch <= 57) and not (ch >= 97 and ch <= 102): return false
	return true

func _path_ok(path: String) -> bool:
	if path.is_empty() or path.is_absolute_path() or "\\" in path or ":" in path: return false
	for part in path.split("/"):
		if part in ["", ".", ".."]: return false
	for ch in path.to_utf8_buffer():
		if ch < 32 or ch == 127: return false
	return true

func _register(path: String) -> bool:
	if not _path_ok(path):
		_error = "INPUT_PATH"
		return false
	var folded: String = path.to_lower()
	if _case_paths.has(folded) and _case_paths[folded] != path:
		_error = "INPUT_CASE_COLLISION"
		return false
	_case_paths[folded] = path
	return true

func _no_link(path: String) -> bool:
	var current: String = path.simplify_path()
	while current.length() > 3 and current != current.get_base_dir():
		var parent := DirAccess.open(current.get_base_dir())
		if parent == null or parent.is_link(current.get_file()):
			_error = "INPUT_LINK_OR_PARENT"
			return false
		current = current.get_base_dir()
	return true

func _file(base: String, relative: String) -> void:
	if not _error.is_empty() or relative == String(_rules.derived) or _files.has(relative): return
	if not _register(relative): return
	var absolute: String = base.path_join(relative)
	if not _no_link(absolute): return
	var file := FileAccess.open(absolute, FileAccess.READ)
	if file == null:
		_error = "INPUT_UNREADABLE:" + relative
		return
	var size: int = file.get_length()
	file.close()
	if _files.size() >= int(_rules.max_files) or size < 0 or size > int(_rules.max_bytes) - _total_bytes:
		_error = "INPUT_BUDGET"
		return
	var before_time: int = FileAccess.get_modified_time(absolute)
	var digest: String
	if _verify_rows.is_empty():
		digest = FileAccess.get_sha256(absolute)
	else:
		if not _verify_rows.has(relative) or size != _verify_rows[relative].bytes or before_time != _verify_stamps.get(relative):
			_error = "INPUT_LIST_CHANGED:" + relative
			return
		digest = _verify_rows[relative].sha256
	file = FileAccess.open(absolute, FileAccess.READ)
	if file == null:
		_error = "INPUT_DISAPPEARED:" + relative
		return
	var after_size: int = file.get_length()
	file.close()
	if not _valid_sha(digest) or after_size != size or FileAccess.get_modified_time(absolute) != before_time:
		_error = "INPUT_CHANGED:" + relative
		return
	_files[relative] = {"path": relative, "bytes": size, "sha256": digest}
	_stamps[relative] = before_time
	_total_bytes += size

func _walk(base: String, relative: String, depth: int) -> void:
	if not _error.is_empty(): return
	if depth > int(_rules.max_depth):
		_error = "INPUT_DEPTH"
		return
	if not _register(relative) or not _no_link(base.path_join(relative)): return
	var dir := DirAccess.open(base.path_join(relative))
	if dir == null:
		_error = "INPUT_DIRECTORY_UNREADABLE:" + relative
		return
	_dirs[relative] = true
	# .gdignore is an import hint, not proof that explicit load/FileAccess cannot read a file.
	dir.include_hidden = true
	dir.include_navigational = false
	if dir.list_dir_begin() != OK:
		_error = "INPUT_DIRECTORY_LIST:" + relative
		return
	var name: String = dir.get_next()
	while not name.is_empty():
		if dir.is_link(name):
			_error = "INPUT_LINK:" + relative.path_join(name)
			break
		if dir.current_is_dir():
			if name not in _rules.skip_directories: _walk(base, relative.path_join(name), depth + 1)
		else:
			_file(base, relative.path_join(name))
		if not _error.is_empty(): break
		name = dir.get_next()
	dir.list_dir_end()

func _optional(base: String, relative: String) -> Dictionary:
	if _files.has(relative):
		var row: Dictionary = _files[relative].duplicate()
		row["present"] = true
		return row
	# These JSON files are opened directly by Defs; keep explicit absence markers too.
	if FileAccess.file_exists(base.path_join(relative)):
		_file(base, relative)
		if _files.has(relative):
			var row: Dictionary = _files[relative].duplicate()
			row["present"] = true
			return row
	if DirAccess.dir_exists_absolute(base.path_join(relative)): _error = "CONTENT_INPUT_TYPE:" + relative
	return {"path": relative, "present": false, "bytes": 0, "sha256": ""}

func _source_snapshot(base: String, provider_relative: String, verify_rows: Dictionary = {}, verify_stamps: Dictionary = {}) -> Dictionary:
	_files.clear(); _dirs.clear(); _case_paths.clear(); _stamps.clear(); _total_bytes = 0; _error = ""
	_verify_rows = verify_rows; _verify_stamps = verify_stamps
	if not base.is_absolute_path() or not _no_link(base): return _bad("SOURCE_ROOT")
	for name in _rules.root_files:
		var relative: String = name
		if FileAccess.file_exists(base.path_join(relative)):
			_file(base, relative)
		elif relative in _rules.required_files:
			return _bad("SOURCE_REQUIRED_FILE:" + relative)
		else:
			if DirAccess.dir_exists_absolute(base.path_join(relative)): return _bad("SOURCE_FILE_TYPE:" + relative)
			_dirs["@file/" + relative] = false
	for name in _rules.roots:
		var relative: String = name
		if DirAccess.dir_exists_absolute(base.path_join(relative)):
			_walk(base, relative, 0)
		elif relative in _rules.required_roots:
			return _bad("SOURCE_REQUIRED_DIRECTORY:" + relative)
		else:
			if FileAccess.file_exists(base.path_join(relative)): return _bad("SOURCE_DIRECTORY_TYPE:" + relative)
			_dirs[relative] = false
	_file(base, provider_relative) # Also pins the actual reviewed provider when loaded from scratchpad.
	var optional: Array[Dictionary] = []
	for relative in _rules.optional_content: optional.append(_optional(base, String(relative)))
	if not _error.is_empty(): return _bad(_error)
	var canonical: String = String(_rules.header) + "\nrules\t" + _sha_text(INPUT_RULES_JSON) + "\n"
	var dir_names: Array = _dirs.keys()
	dir_names.sort()
	for name in dir_names: canonical += "D\t%s\t%d\n" % [name, 1 if _dirs[name] else 0]
	var names: Array = _files.keys()
	names.sort()
	var records: Array[Dictionary] = []
	var native: Array[Dictionary] = []
	for name in names:
		var row: Dictionary = _files[name]
		canonical += "F\t%s\t%d\t%s\n" % [name, row.bytes, row.sha256]
		records.append(row)
		if String(name).begins_with("addons/") and String(name).get_extension() in ["dll", "so", "dylib", "gdextension"]: native.append(row)
	for row in optional: canonical += "O\t%s\t%d\n" % [row.path, 1 if row.present else 0]
	var result: Dictionary = {"ok": true, "code": "OK", "schema": 1, "rules_sha256": _sha_text(INPUT_RULES_JSON),
		"source_sha256": _sha_text(canonical), "file_count": records.size(), "total_bytes": _total_bytes,
		"files": records, "directories": _dirs.duplicate(), "optional_content": optional, "native_files": native,
		"provider_path": provider_relative, "provider_sha256": String(_files[provider_relative].sha256)}
	if verify_rows.is_empty():
		var second: Dictionary = _source_snapshot(base, provider_relative, _files.duplicate(true), _stamps.duplicate())
		if not second.ok or second != result: return _bad("INPUT_ENUMERATION_CHANGED")
	return result

func _mount_status() -> Dictionary:
	var tree: MainLoop = Engine.get_main_loop()
	if not tree is SceneTree: return _bad("MOUNT_PROVENANCE_UNAVAILABLE")
	var updater: Node = (tree as SceneTree).root.get_node_or_null("AndroidUpdater")
	if updater == null or not updater.has_method("run_content_mount_identity"):
		return _bad("MOUNT_PROVENANCE_UNAVAILABLE")
	var proof: Variant = updater.call("run_content_mount_identity")
	if typeof(proof) != TYPE_DICTIONARY or proof.size() != 3 or typeof(proof.get("schema")) != TYPE_INT \
		or proof.get("schema") != 1 or typeof(proof.get("complete")) != TYPE_BOOL or proof.get("complete") != true \
		or typeof(proof.get("patch_sha256")) != TYPE_STRING:
		return _bad("MOUNT_PROVENANCE_INVALID")
	var patch: String = proof.patch_sha256
	if not patch.is_empty():
		return _bad("PATCH_MOUNT_UNSUPPORTED" if _valid_sha(patch) else "MOUNT_PROVENANCE_INVALID")
	return {"ok": true}

func _check_optional_content(rows: Array) -> Dictionary:
	if rows.size() != _rules.optional_content.size(): return _bad("BUILD_OPTIONAL_FIELDS")
	for i in range(rows.size()):
		var row: Variant = rows[i]
		if typeof(row) != TYPE_DICTIONARY or row.size() != 4 or row.get("path") != _rules.optional_content[i] \
			or typeof(row.get("present")) != TYPE_BOOL or typeof(row.get("bytes")) != TYPE_INT or typeof(row.get("sha256")) != TYPE_STRING:
			return _bad("BUILD_OPTIONAL_FIELDS")
		var path: String = "res://" + String(row.path)
		if FileAccess.file_exists(path) != bool(row.present): return _bad("CONTENT_PRESENCE_MISMATCH:" + String(row.path))
		if not row.present:
			if row.bytes != 0 or row.sha256 != "": return _bad("BUILD_OPTIONAL_FIELDS")
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null: return _bad("CONTENT_UNREADABLE:" + String(row.path))
		var size: int = file.get_length()
		file.close()
		if not _valid_sha(row.sha256) or size != row.bytes or FileAccess.get_sha256(path) != row.sha256:
			return _bad("CONTENT_BYTES_MISMATCH:" + String(row.path))
	return {"ok": true}

func _native_export_check(rows: Array, exe: String, source_base: String = "") -> Dictionary:
	if rows.is_empty():
		return _bad("NATIVE_UNPINNED") if Engine.has_singleton("Steam") else {"ok": true}
	# The current package has one explicit GodotSteam Windows binding. Other native layouts are not silently accepted.
	if OS.get_name() != "Windows": return _bad("NATIVE_PLATFORM_UNSUPPORTED")
	var pins: Dictionary = {}
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY or row.size() != 3 or typeof(row.get("path")) != TYPE_STRING \
			or typeof(row.get("bytes")) != TYPE_INT or row.get("bytes") < 0 or row.get("bytes") > int(_rules.max_bytes) \
			or not _valid_sha(row.get("sha256")):
			return _bad("NATIVE_FIELDS")
		var path: String = row.path
		if not _path_ok(path) or not path.begins_with("addons/godotsteam/"): return _bad("NATIVE_LAYOUT_UNSUPPORTED")
		if path.get_extension() == "gdextension":
			# Export may rewrite a binding resource. Its source bytes are in the compiled manifest;
			# actual external library bytes below and the existing loaded-module probe verify runtime binding.
			if not ResourceLoader.exists("res://" + path): return _bad("NATIVE_BINDING_MISSING")
		elif path.get_extension() == "dll":
			if pins.has(path.get_file()): return _bad("NATIVE_DUPLICATE")
			pins[path.get_file()] = row
		else:
			return _bad("NATIVE_LAYOUT_UNSUPPORTED")
	if not Engine.has_singleton("Steam"): return _bad("NATIVE_NOT_LOADED")
	var mode := "debug" if OS.has_feature("editor") else "release"
	for name in ["steam_api64.dll", "libgodotsteam.windows.template_%s.x86_64.dll" % mode]:
		if not pins.has(name): return _bad("NATIVE_PIN_MISSING:" + name)
		var path: String = exe.get_base_dir().path_join(name) if source_base.is_empty() else source_base.path_join(String(pins[name].path))
		if not _no_link(path) or FileAccess.get_sha256(path) != pins[name].sha256:
			return _bad("NATIVE_BINARY_MISMATCH:" + name)
	return {"ok": true}

func resolve_runtime_identity() -> Dictionary:
	_rules = JSON.parse_string(INPUT_RULES_JSON)
	var mount: Dictionary = _mount_status()
	if not mount.ok: return mount
	var exe: String = OS.get_executable_path()
	if not exe.is_absolute_path() or not _no_link(exe): return _bad("ENGINE_BINARY_UNREADABLE")
	var engine_sha: String = FileAccess.get_sha256(exe)
	if not _valid_sha(engine_sha): return _bad("ENGINE_BINARY_UNREADABLE")
	# Godot consumes --main-pack before exposing OS command-line arguments.
	# Inspect this executed Script's backing instead; each branch still proves
	# its physical inputs or compiled manifest without falling back to the other.
	var executed_script: Script = get_script()
	var source_mode: bool = executed_script.has_source_code()
	if source_mode and not OS.has_feature("editor"): return _bad("SOURCE_BACKING_UNSUPPORTED")
	var snapshot: Dictionary
	var source_base := ""
	if source_mode:
		var script: Script = executed_script
		var resource: String = script.resource_path
		if not resource.begins_with("res://") or not script.has_source_code(): return _bad("SOURCE_PROVIDER_UNREADABLE")
		var base: String = ProjectSettings.globalize_path("res://").simplify_path()
		source_base = base
		var provider_relative: String = resource.trim_prefix("res://")
		var file := FileAccess.open(base.path_join(provider_relative), FileAccess.READ)
		if file == null: return _bad("SOURCE_PROVIDER_UNREADABLE")
		var raw: String = file.get_as_text()
		file.close()
		if raw.trim_prefix("\ufeff").replace("\r\n", "\n") != script.source_code.trim_prefix("\ufeff").replace("\r\n", "\n"):
			return _bad("SOURCE_EXECUTING_PROVIDER_MISMATCH")
		snapshot = _source_snapshot(base, provider_relative)
		if not snapshot.ok: return snapshot
	else:
		if get_script().resource_path != PROVIDER_PATH: return _bad("BUILD_PROVIDER_PATH")
		if not ResourceLoader.exists(BUILD_PATH): return _bad("BUILD_IDENTITY_MISSING")
		# Dynamic load after Updater, no Autoload/global symbol or preloaded base constant.
		var build: Resource = ResourceLoader.load(BUILD_PATH, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
		if not build is Script: return _bad("BUILD_IDENTITY_SCRIPT")
		if (build as Script).has_source_code(): return _bad("BUILD_IDENTITY_BACKING")
		var constants: Dictionary = (build as Script).get_script_constant_map()
		var value: Variant = constants.get("IDENTITY")
		if typeof(value) != TYPE_DICTIONARY: return _bad("BUILD_IDENTITY_FIELDS")
		snapshot = value
		var fields := ["schema", "rules_sha256", "source_sha256", "file_count", "total_bytes", "optional_content", "native_files", "provider_path", "provider_sha256"]
		if snapshot.size() != fields.size(): return _bad("BUILD_IDENTITY_FIELDS")
		for field in fields:
			if not snapshot.has(field): return _bad("BUILD_IDENTITY_FIELDS")
		if typeof(snapshot.schema) != TYPE_INT or snapshot.schema != 1 or snapshot.rules_sha256 != _sha_text(INPUT_RULES_JSON) \
			or not _valid_sha(snapshot.source_sha256) or not _valid_sha(snapshot.provider_sha256) \
			or snapshot.provider_path != PROVIDER_PATH.trim_prefix("res://") \
			or typeof(snapshot.file_count) != TYPE_INT or snapshot.file_count <= 0 or snapshot.file_count > int(_rules.max_files) \
			or typeof(snapshot.total_bytes) != TYPE_INT or snapshot.total_bytes < 0 or snapshot.total_bytes > int(_rules.max_bytes) \
			or typeof(snapshot.optional_content) != TYPE_ARRAY or typeof(snapshot.native_files) != TYPE_ARRAY:
			return _bad("BUILD_IDENTITY_FIELDS")
	var native: Dictionary = _native_export_check(snapshot.native_files, exe, source_base)
	if not native.ok: return native
	var optional: Dictionary = _check_optional_content(snapshot.optional_content)
	if not optional.ok: return optional
	return {"ok": true, "code": "OK", "identity_schema": 1, "identity_scope": "installed_inputs",
		"content_version": "source-v1:" + String(snapshot.source_sha256), "source_sha256": snapshot.source_sha256,
		"engine_binary_sha256": engine_sha, "source_mode": source_mode, "save_eligible": true, "save_code": "OK",
		"rules_sha256": snapshot.rules_sha256, "file_count": snapshot.file_count, "total_bytes": snapshot.total_bytes,
		"provider_sha256": snapshot.provider_sha256, "optional_content": snapshot.optional_content}
