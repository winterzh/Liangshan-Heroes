extends SceneTree
## External probe: manifest contains host expectations only; provider receives no identity arguments.
var _checks: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(label: String, passed: bool) -> void:
	_checks.append({"label": label, "passed": passed})

func _optional_content_matches(actual: Variant, expected: Variant) -> bool:
	# JSON transports byte counts as float64. Preserve the provider's integer
	# requirement and compare only exactly representable, bounded host integers.
	if typeof(actual) != TYPE_ARRAY or typeof(expected) != TYPE_ARRAY or actual.size() != expected.size(): return false
	var fields := ["path", "present", "bytes", "sha256"]
	for index in range(actual.size()):
		var row: Variant = actual[index]
		var host: Variant = expected[index]
		if typeof(row) != TYPE_DICTIONARY or typeof(host) != TYPE_DICTIONARY or row.size() != 4 or host.size() != 4: return false
		for field in fields:
			if not row.has(field) or not host.has(field): return false
		for field in ["path", "sha256"]:
			if typeof(row[field]) != TYPE_STRING or typeof(host[field]) != TYPE_STRING or row[field] != host[field]: return false
		if typeof(row.present) != TYPE_BOOL or typeof(host.present) != TYPE_BOOL or row.present != host.present: return false
		if typeof(row.bytes) != TYPE_INT or row.bytes < 0 or row.bytes > 34359738368: return false
		if typeof(host.bytes) not in [TYPE_INT, TYPE_FLOAT]: return false
		if typeof(host.bytes) == TYPE_FLOAT and (not is_finite(host.bytes) or floor(host.bytes) != host.bytes): return false
		if host.bytes < 0 or host.bytes > 34359738368 or row.bytes != int(host.bytes): return false
	return true

func _run() -> void:
	await process_frame
	var manifest_path: String = OS.get_environment("CONTENT_IDENTITY_PROBE_MANIFEST")
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null or file.get_length() > 1048576:
		printerr("CONTENT_IDENTITY_PROBE_MANIFEST_INVALID")
		quit(2)
		return
	var json := JSON.new()
	var parsed: int = json.parse(file.get_as_text())
	file.close()
	if parsed != OK or typeof(json.data) != TYPE_DICTIONARY:
		printerr("CONTENT_IDENTITY_PROBE_MANIFEST_INVALID")
		quit(2)
		return
	var manifest: Dictionary = json.data
	var provider_script: Script = load("res://scripts/run_content_identity.gd")
	var provider = provider_script.new()
	var result: Dictionary = provider.resolve_runtime_identity()
	_check("provider_resolved", result.get("ok") == true)
	_check("save_identity_eligible", result.get("save_eligible") == true and result.get("save_code") == "OK")
	_check("expected_source_mode", result.get("source_mode") == manifest.source_mode)
	_check("host_source_digest", result.get("source_sha256") == manifest.source_sha256)
	_check("host_rules_digest", result.get("rules_sha256") == manifest.rules_sha256)
	_check("host_provider_digest", result.get("provider_sha256") == manifest.provider_sha256)
	_check("actual_executing_binary", result.get("engine_binary_sha256") == FileAccess.get_sha256(OS.get_executable_path()) and result.get("engine_binary_sha256") == manifest.engine_binary_sha256)
	_check("exact_optional_content", _optional_content_matches(result.get("optional_content"), manifest.optional_content))
	_check("private_user", ProjectSettings.globalize_path("user://").simplify_path() == String(manifest.private_user).simplify_path())
	_check("native_present_when_expected", not bool(manifest.native_expected) or Engine.has_singleton("Steam"))
	var passed := true
	for row in _checks: passed = passed and row.passed
	for node_name in ["Sfx", "Music"]:
		var node: Node = root.get_node_or_null(node_name)
		if node != null and node.has_method("shutdown"): node.call("shutdown")
	var report := {"suite": "content-identity", "run_id": manifest.run_id, "process_id": OS.get_process_id(),
		"actual_user_dir": ProjectSettings.globalize_path("user://"), "manifest_sha256": FileAccess.get_sha256(manifest_path),
		"complete": true, "passed": passed, "checks": _checks, "check_count": _checks.size(), "identity": result,
		"full_battle_resume_tested": false, "release_process_tested": not OS.has_feature("editor")}
	file = FileAccess.open(String(manifest.report), FileAccess.WRITE)
	if file == null:
		printerr("CONTENT_IDENTITY_PROBE_REPORT_WRITE")
		quit(2)
		return
	var text: String = JSON.stringify(report)
	file.store_string(text)
	file.close()
	for i in range(3): await process_frame
	print("CONTENT_IDENTITY_REPORT ", text)
	quit(0 if passed else 1)
