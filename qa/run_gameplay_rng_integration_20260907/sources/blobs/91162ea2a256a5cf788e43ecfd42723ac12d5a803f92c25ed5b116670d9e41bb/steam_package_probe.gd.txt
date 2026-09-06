extends SceneTree
## Runs outside the exported pack; never initialize Steam or write account data.
var checks: Array[Dictionary] = []
var files: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(label: String, passed: bool) -> void:
	checks.append({"name":label, "passed":passed})

func _list(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	dir.include_hidden = true
	for name in dir.get_files(): files.append(path.path_join(name))
	for name in dir.get_directories(): _list(path.path_join(name))

func _run() -> void:
	await process_frame
	check("Steam export feature", OS.has_feature("steam"))
	check("native extension in exported package", Engine.has_singleton("Steam"))
	var service := root.get_node("SteamService")
	check("Steam QA initialization disabled", not service.available and service.native == null)
	_list("res://")
	var forbidden := false
	for path in files:
		for prefix in ["tools/", "qa/", "docs/", "marketing/", "vendor/", "build/", "assets/campaign/source/"]:
			forbidden = forbidden or path.begins_with("res://" + prefix)
		forbidden = forbidden or "_raw" in path or "web_prompts" in path or ".godot/editor/" in path
	check("package excludes development and source evidence", not forbidden)
	var catalog: GDScript = load("res://scripts/steam_achievement_catalog.gd")
	for entry in catalog.entries():
		for field in ["icon", "locked_icon"]:
			check(entry.id + " " + field, load(entry[field]) is Texture2D)
	var campaign := root.get_node("Campaign")
	var policy: GDScript = load("res://scripts/steam_run_policy.gd")
	campaign.current = 0
	campaign.scenario = false
	campaign.custom_defense = false
	campaign.skirmish = false
	campaign.skirmish_ai = false
	campaign.arena = false
	var level: RefCounted = campaign.make_level()
	check("official script identity survives export remapping", policy.classify(campaign, level).mode == "campaign")
	root.get_node("Sfx").shutdown()
	root.get_node("Music").shutdown()
	var passed := true
	for row in checks: passed = passed and row.passed
	var out := FileAccess.open(OS.get_environment("STEAM_PACKAGE_REPORT"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"passed":passed,"checks":checks,"files":files}, "\t"))
	out.close()
	for i in range(3): await process_frame
	print("STEAM_PACKAGE ", "PASS" if passed else "FAIL", " ", checks.size())
	quit(0 if passed else 1)
