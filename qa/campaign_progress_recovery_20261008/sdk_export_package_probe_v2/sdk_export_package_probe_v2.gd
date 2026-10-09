extends SceneTree
## External --script against an actual exported main-pack. SDK must stay uninitialized.
## No fixture/native replacement and no public continue-disabled assumption.
const MAIN_SCENE := "res://scenes/qa_real_sdk_bootstrap_v3.tscn"
const SDK_PROBE := "res://scripts/qa_real_sdk_bootstrap_v3.gd"
const PROVIDER := "res://scripts/run_content_identity.gd"
const BUILD := "res://scripts/run_build_identity.gd"
var checks: Array[String] = []
var failures: Array[String] = []
var nonce := ""
var output := ""
var output_validated := false
var manifest_sha := ""
var script_paths: Array[String] = []
var compiled_identity: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool,label: String) -> bool:
	checks.append(label)
	if not ok: failures.append(label)
	return ok

func _run() -> void:
	await process_frame
	output = OS.get_environment("LSH_SDK_PACKAGE_OUTPUT")
	nonce = OS.get_environment("LSH_SDK_PACKAGE_NONCE")
	manifest_sha = OS.get_environment("LSH_SDK_PACKAGE_SCRIPTS_SHA256")
	var manifest_path := OS.get_environment("LSH_SDK_PACKAGE_SCRIPTS_FILE")
	if not _check(output.is_absolute_path() and nonce.length() == 32 and manifest_sha.length() == 64,
		"owned external output nonce and script manifest fields"): _finish(); return
	output_validated = true
	if not _check(SteamRunPolicy.test_environment() and OS.get_environment("STEAM_DISABLED") == "1"
		and DisplayServer.get_name() == "headless" and "--script" in OS.get_cmdline_args(),
		"package probe is SDK disabled external headless script"): _finish(); return
	if not _check(FileAccess.file_exists(manifest_path) and FileAccess.get_sha256(manifest_path) == manifest_sha,
		"original script manifest SHA"): _finish(); return
	var file := FileAccess.open(manifest_path,FileAccess.READ)
	if not _check(file != null and file.get_length() <= 1048576,"bounded original script manifest"): _finish(); return
	var raw := file.get_buffer(file.get_length())
	file.close()
	var hash := HashingContext.new()
	if not _check(hash.start(HashingContext.HASH_SHA256) == OK and hash.update(raw) == OK
		and hash.finish().hex_encode() == manifest_sha,"original script manifest read buffer SHA"): _finish(); return
	var decoded: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not _check(decoded is Array and not decoded.is_empty() and decoded.size() <= 60000,
		"whole nonempty compiled script manifest"): _finish(); return
	var seen: Dictionary = {}
	for relative in decoded:
		if not _check(relative is String and relative.begins_with("scripts/") and relative.ends_with(".gd")
			and not ".." in relative and not "\\" in relative and not ":" in relative
			and not seen.has(relative),"valid unique packaged script path: " + str(relative)): _finish(); return
		seen[relative] = true
		script_paths.append(relative)
		var script: Resource = ResourceLoader.load("res://" + relative,"GDScript",ResourceLoader.CACHE_MODE_IGNORE)
		if not _check(script is GDScript and script.can_instantiate() and not script.has_source_code(),
			"actual compiled packaged script: " + relative): _finish(); return
	if not _check(seen.has(SDK_PROBE.trim_prefix("res://")) and seen.has(PROVIDER.trim_prefix("res://"))
		and seen.has(BUILD.trim_prefix("res://")),"entry provider and generated identity in whole script inventory"): _finish(); return
	if not _check(ProjectSettings.get_setting("application/run/main_scene","") == MAIN_SCENE,
		"actual packed default scene is dedicated SDK entry"): _finish(); return
	var packed: Resource = ResourceLoader.load(MAIN_SCENE,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
	if not _check(packed is PackedScene and packed.can_instantiate(),"packed SDK entry scene instantiable"): _finish(); return
	var node: Node = packed.instantiate()
	if not _check(node != null and node.get_script() != null and node.get_script().resource_path == SDK_PROBE
		and node.get_node_or_null("Menu") != null,"packed entry uses exact compiled probe and original menu child"):
		if node != null: node.free()
		_finish(); return
	# Never add this instance to the tree: the real-SDK observer _ready must not run.
	node.free()
	var build: Resource = ResourceLoader.load(BUILD,"GDScript",ResourceLoader.CACHE_MODE_IGNORE)
	var constants: Dictionary = build.get_script_constant_map()
	var value: Variant = constants.get("IDENTITY")
	if not _check(value is Dictionary and not value.is_empty(),"actual generated compiled identity is not seed stub"): _finish(); return
	compiled_identity = value.duplicate(true)
	if not _check(compiled_identity.get("provider_path") == PROVIDER.trim_prefix("res://")
		and compiled_identity.get("schema") == 1 and compiled_identity.get("file_count",0) > 0
		and compiled_identity.get("native_files") is Array and not compiled_identity.native_files.is_empty(),
		"actual compiled identity carries provider input and native dependencies"): _finish(); return
	var service: Node = root.get_node_or_null("SteamService")
	if not _check(service != null and not service.available and service.native == null,
		"production Steam service did not initialize SDK in package probe"): _finish(); return
	if not _check(Engine.has_singleton("Steam") and ClassDB.class_exists("SteamStatsReader"),
		"real exported Steam and read-only reader extensions loaded"): _finish(); return
	var reader: Object = ClassDB.instantiate("SteamStatsReader")
	var response: Variant = reader.call("query","identity")
	var identity: Variant = JSON.parse_string(response) if response is String else null
	if not _check(identity is Dictionary and identity.get("ok") == false
		and identity.get("code") == "STEAM_NOT_INITIALIZED",
		"real native reader refuses uninitialized SDK"): _finish(); return
	_finish()

func _finish() -> void:
	if not output_validated: quit(2); return
	var path := output.path_join("report.json")
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path): quit(2); return
	var report := {"schema":"sdk_export_package_probe_v2","passed":failures.is_empty(),
		"checks":checks,"failures":failures,"pid":OS.get_process_id(),"nonce":nonce,
		"script_manifest_sha256":manifest_sha,"scripts":script_paths,
		"compiled_identity":compiled_identity,"user_directory":OS.get_user_data_dir(),
		"SDK_account_qualified":false,"SDK_reward_once_qualified":false,
		"original19_qualified":false,"overall_goal_qualified":false}
	var text: String = JSON.stringify(report,"\t") + "\n"
	var raw: PackedByteArray = text.to_utf8_buffer()
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: quit(2); return
	file.store_buffer(raw)
	file.flush()
	var error: int = file.get_error()
	file.close()
	if error != OK: quit(2); return
	var closed := FileAccess.open(path,FileAccess.READ)
	if closed == null: quit(2); return
	var actual: PackedByteArray = closed.get_buffer(closed.get_length())
	closed.close()
	if actual != raw or FileAccess.get_sha256(path) != text.sha256_text(): quit(2); return
	print("SDK_EXPORTED_PACKAGE_COMPLETE ",OS.get_process_id()," ",nonce," ",checks.size()," ",failures.is_empty())
	quit(0 if failures.is_empty() else 1)
