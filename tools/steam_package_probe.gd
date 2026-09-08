extends SceneTree
## Runs outside the exported pack; never initialize Steam or write account data.
var checks: Array[Dictionary] = []
var files: Array[String] = []
var localization_report: Dictionary = {}

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

func _check_localization() -> void:
	var catalog_path := "res://assets/localization/catalog.json"
	var expected_hash := OS.get_environment("LSH_QA_CATALOG_SHA")
	var actual_hash := FileAccess.get_sha256(catalog_path)
	check("packed localization catalog matches QA source", expected_hash.length() == 64 and actual_hash == expected_hash)
	check("packed font license", FileAccess.file_exists("res://assets/fonts/OFL.txt"))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	check("packed localization catalog is a nonempty dictionary", parsed is Dictionary and not parsed.is_empty())
	var localize: Node = root.get_node_or_null("Localize")
	check("packed Localize autoload", localize != null)
	var font: Font = load("res://assets/fonts/NotoSansCJK-Regular.ttc")
	check("packed CJK font resource", font != null)
	var lore_script: GDScript = load("res://scripts/lore_data.gd")
	check("packed original-text lore resource", lore_script != null)
	if not parsed is Dictionary or parsed.is_empty() or localize == null or lore_script == null:
		return
	var constants: Dictionary = lore_script.get_script_constant_map()
	var lore: Dictionary = constants.get("LORE", {})
	var chapters: Dictionary = constants.get("CHAPTERS", {})
	check("packed 108 complete biographies", lore.size() == 108)
	check("packed 108 chapter reference entries", chapters.size() == 108)
	for key in lore:
		var source: String = lore[key]
		check("packed biography has complete paragraphs: " + key, source.split("\n\n", false).size() >= 2)
		var references: Variant = chapters.get(key, [])
		var valid_references := references is Array and not references.is_empty()
		if references is Array:
			for chapter in references:
				valid_references = valid_references and chapter is int and chapter >= 1 and chapter <= 120
		check("packed biography chapter references: " + key, valid_references)
	var original_locale: String = localize.locale
	var expected_pause := {"zh_CN": "暂停", "zh_TW": "暫停", "en": "Paused", "ja": "一時停止"}
	var theme_script: GDScript = load("res://scripts/ui_theme.gd")
	var locale_reports: Array[Dictionary] = []
	for language in ["zh_CN", "zh_TW", "en", "ja"]:
		check("packed language switch: " + language, localize.set_language(language, false))
		check("packed translation locale: " + language, TranslationServer.get_locale() == language and localize.text("暂停") == expected_pause[language])
		var mismatches: Array[String] = []
		var mismatch_count := 0
		for source in parsed:
			var entry: Variant = parsed[source]
			var translated: Variant = source if language == "zh_CN" else (entry.get(language, "") if entry is Dictionary else "")
			if not translated is String or translated.is_empty() or localize.text(source) != translated:
				mismatch_count += 1
				if mismatches.size() < 20:
					mismatches.append(source)
		check("packed complete catalog translations: " + language, mismatch_count == 0)
		for key in lore:
			var source: String = lore[key]
			var entry: Variant = parsed.get(source, {})
			var translated: String = source if language == "zh_CN" else String(entry.get(language, ""))
			check("packed full biography translation: " + language + ": " + key,
				parsed.has(source) and not translated.is_empty() and localize.text(source) == translated
				and translated.count("\n\n") == source.count("\n\n"))
		var locale_font: FontVariation = theme_script.locale_font()
		check("packed font face: " + language, locale_font.variation_face_index == {"zh_CN": 2, "zh_TW": 3}.get(language, 0))
		for character in "汉語繁體中文日本語あいうえおカキクケコABC":
			check("packed font glyph: " + language + ": " + character, font != null and locale_font.has_char(character.unicode_at(0)))
		locale_reports.append({"locale": language, "catalog_entries": parsed.size(), "mismatch_count": mismatch_count, "first_mismatches": mismatches})
	localize.set_language(original_locale, false)
	localization_report = {"catalog_sha256": actual_hash, "expected_catalog_sha256": expected_hash,
		"biographies": lore.size(), "chapter_references": chapters.size(), "locales": locale_reports}

func _run() -> void:
	await process_frame
	check("Steam export feature", OS.has_feature("steam"))
	check("native extension in exported package", Engine.has_singleton("Steam"))
	var service := root.get_node("SteamService")
	check("Steam QA initialization disabled", not service.available and service.native == null)
	_list("res://")
	var forbidden := false
	for path in files:
		for prefix in ["tools/", "qa/", "docs/", "marketing/", "vendor/", "build/", "scratchpad/", "assets/campaign/source/"]:
			forbidden = forbidden or path.begins_with("res://" + prefix)
		if path.begins_with("res://assets/localization/"):
			forbidden = forbidden or path != "res://assets/localization/catalog.json"
		forbidden = forbidden or "_raw" in path or "web_prompts" in path or ".godot/editor/" in path
	check("package excludes development and source evidence", not forbidden)
	_check_localization()
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
	out.store_string(JSON.stringify({"passed":passed,"checks":checks,"files":files,"localization":localization_report}, "\t"))
	out.close()
	for i in range(3): await process_frame
	print("STEAM_PACKAGE ", "PASS" if passed else "FAIL", " ", checks.size())
	quit(0 if passed else 1)
