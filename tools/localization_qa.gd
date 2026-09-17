extends Node
## Isolated runtime checks. The Python runner supplies private application data.

var checks: Array = []
var failures: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks.append({"label": label, "passed": value})
	if not value:
		failures.append(label)
		push_error(label)

func _run() -> void:
	await get_tree().process_frame
	var mode := OS.get_environment("LSH_QA_MODE")
	if mode == "preference":
		_preference()
		_finish()
		return
	if mode == "visual":
		await _visual()
		_finish()
		return
	if mode.begins_with("battle"):
		await _battle()
		_finish()
		return
	var scripts := DirAccess.get_files_at("res://scripts")
	for file in scripts:
		if file.ends_with(".gd"):
			var script: GDScript = load("res://scripts/" + file)
			check(script != null and script.can_instantiate(), "script parses: " + file)
	for file in DirAccess.get_files_at("res://scripts/levels"):
		if file.ends_with(".gd"):
			var script: GDScript = load("res://scripts/levels/" + file)
			check(script != null and script.can_instantiate(), "level parses: " + file)
	var raw_name: String = Defs.UNITS["lin_chong"].name
	var raw_star: String = Bios.star_name("lin_chong")
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	var scene_id := menu.get_instance_id()
	var original_records := Campaign.records.duplicate(true)
	var original_achievements := SteamAchievementCatalog.entries()
	var pretranslated := Label.new()
	menu.add_child(pretranslated)
	Localize.bind_text(pretranslated, Localize.text("暂停"))
	var formatted := Label.new()
	menu.add_child(formatted)
	Localize.bind_text(formatted, Localize.format_text("生命  %d / %d", [25, 100]), &"text", "  ×2")
	for language in ["en", "ja", "zh_TW", "zh_CN"]:
		Localize.set_language(language, false)
		await get_tree().process_frame
		check(get_tree().current_scene.get_instance_id() == scene_id, "language keeps scene: " + language)
		check(Campaign.records == original_records, "language keeps progress: " + language)
		for entry in original_achievements:
			var display := SteamPanels._achievement_display(entry)
			check(not String(display.title).is_empty() and not String(display.description).is_empty(), "achievement text: " + language + ": " + entry.id)
			if not String(entry.stat).is_empty():
				check(String(display.description).contains(str(entry.target)), "achievement counter target: " + language + ": " + entry.id)
		check(SteamAchievementCatalog.entries() == original_achievements, "achievement export is unchanged: " + language)
		check(pretranslated.text == Localize.text("暂停"), "pretranslated display binding: " + language)
		check(formatted.text == Localize.format_text("生命  %d / %d", [25, 100]) + "  ×2", "formatted display binding and repeat suffix: " + language)
		check(Defs.UNITS["lin_chong"].name == raw_name and Bios.star_name("lin_chong") == raw_star, "language keeps identifiers: " + language)
		check(Localize.format_text("生命  %d / %d", [25, 100]).contains("25") and Localize.format_text("生命  %d / %d", [25, 100]).contains("100"), "numeric values: " + language)
		var selector := menu.find_child("LanguageSelector", true, false) as OptionButton
		check(selector != null and selector.get_item_count() == 4, "main menu selector: " + language)
		if selector != null:
			check(selector.get_item_text(0) == "简体中文" and selector.get_item_text(3) == "日本語", "selector names: " + language)
		for sample in ["汉語繁體中文", "日本語あいうえおカキクケコ", "Liangshan Heroes"]:
			var font := UITheme.locale_font()
			for character in sample:
				check(font.has_char(character.unicode_at(0)), "font: " + language + ": " + character)
	get_tree().root.remove_child(menu)
	menu.free()
	get_tree().current_scene = null
	await _scenario_data()
	await _editor_search()
	_finish()


func _finish() -> void:
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "count": checks.size()}
	var output := OS.get_environment("LSH_QA_REPORT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	print("[localization QA] ", checks.size(), " checks; failures ", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(0.35, true, false, true).timeout
	for frame in range(5):
		await get_tree().process_frame
	var dump := []
	_ui_text(get_tree().current_scene, dump)
	var folder := OS.get_environment("LSH_QA_CAPTURE_DIR")
	var file := FileAccess.open(folder.path_join(label + "_text.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(dump, "\t"))
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var output := folder.path_join(label + ".png")
	check(get_viewport().get_texture().get_image().save_png(output) == OK, "capture: " + label)


func _visual() -> void:
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await _capture("menu")
	menu._show_story()
	await _capture("campaigns")
	menu._show_settings()
	await _capture("settings")
	get_tree().root.remove_child(menu)
	menu.free()
	var codex: Control = load("res://scenes/codex.tscn").instantiate()
	get_tree().root.add_child(codex)
	get_tree().current_scene = codex
	codex._select("an_daoquan")
	await _capture("codex")
	check(codex._name_lbl.get_global_rect().end.x <= get_viewport().get_visible_rect().size.x, "compendium heading stays inside viewport")
	codex._show_lore()
	await get_tree().create_timer(0.3).timeout
	await _capture("lore")
	check(codex._lore_text.get_global_rect().end.x <= get_viewport().get_visible_rect().size.x, "full biography wraps inside viewport")
	get_tree().root.remove_child(codex)
	codex.free()
	get_tree().current_scene = null


func _battle() -> void:
	Campaign.current = clampi(int(OS.get_environment("LEVEL")) - 1, 0, 7)
	var battle: Node2D = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	# The cursor is outside an off-screen QA window; freeze camera edge scrolling
	# so the viewport remains at the level's authored start during UI inspection.
	battle.camera.set_process(false)
	battle.camera.set_physics_process(false)
	for frame in range(10):
		await get_tree().process_frame
	check(battle.level != null and not battle.units.is_empty(), "campaign initialized")
	await _capture("intro")
	while battle.hud._intro_root.visible:
		battle.hud._advance_intro()
	battle._on_start_battle()
	for frame in range(30):
		await get_tree().process_frame
	for unit in battle.units:
		if unit.is_hero and unit.faction == Unit.FACTION_LIANG:
			battle.select_single(unit, false)
			break
	battle._open_pause()
	check(get_tree().paused, "campaign pauses")
	var state := _unit_state(battle)
	var phase: int = battle.phase
	var records := Campaign.records.duplicate(true)
	await _capture("paused")
	var previous := Localize.locale
	Localize.set_language("ja" if previous == "en" else "en", false)
	await get_tree().process_frame
	check(_unit_state(battle) == state, "switch preserves units, health and positions")
	check(battle.phase == phase and Campaign.records == records, "switch preserves phase and campaign records")
	check(battle.hud._pause_resume_button.text == Localize.text("继续 (Esc)"), "pause resume text follows language")
	if phase == battle.Phase.FIGHT:
		check(battle.hud.top_label.text == battle.level.top_status(battle), "paused battle status follows language")
	var old_ai: bool = battle.ai_friendly
	var old_micro: int = Settings.auto_micro_level
	battle.ai_friendly = true
	Settings.auto_micro_level = 3
	var unread: int = battle.hud._info_unread
	battle.hud.show_message(Localize.format_text("【%s】· 剩余能量 %d/%d", ["忠义双旗", 1, 2]), 2.0, true)
	check(battle.hud._info_unread == unread, "localized automatic skill remains quiet")
	battle.ai_friendly = false
	battle.hud.show_message(Localize.format_text("【%s】· 剩余能量 %d/%d", ["忠义双旗", 1, 2]), 2.0, true)
	check(battle.hud._info_unread == mini(battle.hud.INFO_LOG_CAP, unread + 1), "manual skill still notifies")
	battle.ai_friendly = old_ai
	Settings.auto_micro_level = old_micro
	await _capture("switched")
	Localize.set_language(previous, false)
	battle._close_pause()
	check(not get_tree().paused, "campaign resumes")
	if battle.mission != null:
		battle.mission._set_expanded(true)
	await _capture("battle")
	# Clear a previously selected object before switching; display callbacks must
	# never keep a dead unit alive or dereference one after it is freed.
	battle._set_selection([])
	Localize.set_language("ja" if previous == "en" else "en", false)
	await get_tree().process_frame
	check(battle.active_unit() == null, "language switch keeps empty selection")
	get_tree().paused = true
	if battle.mission != null:
		var m = battle.mission
		var action: String = m.active_action_id
		var progress: float = m._progress
		var stage: String = m.stage_id
		m.set_feedback(Localize.format_text("需要%s：请选中该人物，再右键%d号旗标。", ["鲁智深", 3]), 2.5)
		Localize.set_language("en" if Localize.locale != "en" else "ja", false)
		var feedback := Localize.format_text("需要%s：请选中该人物，再右键%d号旗标。", ["鲁智深", 3])
		check(m._status.text == feedback and m._feedback_text == feedback, "mission feedback refreshes in paused language switch")
		check(m._feedback_left == 2.5 and m.active_action_id == action and m._progress == progress and m.stage_id == stage, "mission language preserves timer action progress and stage")
		m.set_guidance("剧情演出中；不需要再点击任务按钮。")
		check(m._status.text == feedback, "localized feedback protects guidance until expiry")
		m._feedback_left = 0.0
		m.set_guidance("剧情演出中；不需要再点击任务按钮。")
		check(m._status.text == Localize.text("剧情演出中；不需要再点击任务按钮。"), "expired localized feedback accepts guidance")
	var custom: LevelBase = load("res://scripts/levels/scenario.gd").new()
	custom.data = {"intro": [{"who": "林冲", "text": "返回菜单"}]}
	var authored: Array = custom.intro_lines().duplicate(true)
	battle.hud.show_intro(custom.intro_lines(), custom.localize_intro_text())
	Localize.set_language("en", false)
	Localize.set_language("ja", false)
	check(battle.hud._intro_name.text == "【林冲】" and battle.hud._intro_text.text == "返回菜单", "custom dialogue remains authored during play and language switch")
	check(custom.intro_lines() == authored and battle.hud._intro_text.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED, "custom dialogue data and native translation boundary")
	battle.hud.show_intro(authored, true)
	check(battle.hud._intro_name.text == Localize.format_text("【%s】", "林冲") and battle.hud._intro_text.text == Localize.text("返回菜单"), "built-in dialogue still translates after custom dialogue")
	get_tree().paused = false
	get_tree().root.remove_child(battle)
	battle.free()
	get_tree().current_scene = null


func _unit_state(battle: Node2D) -> Array:
	var result := []
	for unit in battle.units:
		result.append([unit.get_instance_id(), unit.key, unit.display_name, unit.hp, unit.position])
	return result


func _ui_text(node: Node, result: Array) -> void:
	if node is Control and node.is_visible_in_tree():
		var value := ""
		if node is Label or node is Button or node is RichTextLabel:
			value = node.text
		if not value.is_empty():
			result.append({"path": str(node.get_path()), "text": node.tr(value),
				"rect": str(node.get_global_rect())})
	for child in node.get_children():
		_ui_text(child, result)


func _scenario_data() -> void:
	var editor: Control = load("res://scenes/scenario_editor.tscn").instantiate()
	get_tree().root.add_child(editor)
	get_tree().current_scene = editor
	var presets := ["据守：守基地+撑过所有波", "歼灭：消灭全部敌人", "限时坚守60秒"]
	var expected := ["survive_waves", "kill_all", "timer"]
	for language in Localize.LOCALES:
		Localize.set_language(language, false)
		for i in range(presets.size()):
			var row: HBoxContainer = editor._opt_row("规则", presets, presets[0], editor._apply_win_preset)
			editor.add_child(row)
			var option: OptionButton = row.get_child(1)
			option.select(i)
			option.item_selected.emit(i)
			check(editor._cfg["win"][0]["type"] == expected[i], "scenario preset callbacks: " + language + ": " + str(i))
			row.free()
		editor._cfg["title"] = "我的关卡" # A real catalogue key must still remain player data.
		editor._cfg["intro"] = [{"who": "林冲", "key": "lin_chong", "text": "暂停"}]
		editor._name_edit.text = editor._cfg["title"]
		var before: Dictionary = editor._cfg.duplicate(true)
		Localize.set_language("en" if language != "en" else "ja", false)
		await get_tree().process_frame
		check(editor._cfg == before and editor._name_edit.text == "我的关卡", "custom text survives locale change: " + language)
		check(editor._name_edit.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED, "player input bypasses translation: " + language)
		var path: String = ScenarioStore.save(editor._cfg)
		check(not path.is_empty(), "scenario save: " + language)
		var loaded: Dictionary = ScenarioStore.load_by_name("我的关卡")
		check(loaded.get("title") == "我的关卡" and loaded.get("intro") == before["intro"] and loaded.get("win") == before["win"], "scenario saved content preserved: " + language)
	Localize.set_language("en", false)
	check(editor._display_uname("lin_chong") == "Lin Chong", "scenario built-in object display translates")
	editor._cfg["units"] = {"lin_chong": {"name": "返回菜单"}}
	check(editor._display_uname("lin_chong") == "返回菜单", "scenario custom object name remains authored")
	get_tree().root.remove_child(editor)
	editor.free()
	get_tree().current_scene = null


func _editor_search() -> void:
	Localize.set_language("en", false)
	var editor: Control = load("res://scenes/editor.tscn").instantiate()
	get_tree().root.add_child(editor)
	get_tree().current_scene = editor
	var original: Dictionary = editor._cfg.duplicate(true)
	for query in ["lin chong", "林冲", "lin_chong"]:
		editor._unit_filter = query
		editor._rebuild()
		await get_tree().process_frame
		var rows: Array = []
		_ui_text(editor, rows)
		var found := false
		for row in rows:
			if row.text == Localize.text("林冲"):
				found = true
		check(found, "unit search matches localized name, original or key: " + query)
	check(editor._cfg == original, "localized editor search keeps unit configuration")
	get_tree().root.remove_child(editor)
	editor.free()
	get_tree().current_scene = null


func _preference() -> void:
	var action := OS.get_environment("LSH_QA_PREFERENCE_ACTION")
	if action == "save":
		check(not Localize._test_override, "ordinary selection allows saving")
		Localize.set_language("ja", true)
	elif action == "reload":
		check(Localize.locale == "ja" and not Localize._test_override, "new process reloads Japanese preference")
	else:
		check(Localize.locale == "en" and Localize._test_override, "environment override selects English")
		Localize.set_language("zh_TW", true)
	var stored := ConfigFile.new()
	check(stored.load(Localize.PREFERENCE_PATH) == OK, "language preference file exists")
	check(stored.get_value("language", "locale", "") == "ja", "saved preference remains Japanese")
	for pair in [["zh-Hans-TW", "zh_CN"], ["zh-Hant-CN", "zh_TW"], ["zh-HK", "zh_TW"], ["ja-JP", "ja"], ["de-DE", "en"]]:
		check(Localize.normalize_locale(pair[0]) == pair[1], "OS locale mapping: " + pair[0])
