extends "res://tools/localization_qa.gd"
## Additional real-window review of secondary menus and localized editor panels.

var layout_findings: Array = []
var page := ""

func _run() -> void:
	await get_tree().process_frame
	var menu := await _scene("menu")
	await _page("menu")
	await _bottom(menu, "menu_bottom")
	for method in ["_show_defense", "_show_1v1", "_show_more", "_show_scenario_picker", "_show_custom_picker", "_show_story", "_show_settings"]:
		var original := menu.get_children()
		menu.call(method)
		await _page(method)
		await _bottom(menu, method + "_bottom")
		for child in menu.get_children():
			if child not in original:
				child.queue_free()
		await get_tree().process_frame
	for panel in ["achievements", "workshop"]:
		var original := menu.get_children()
		if panel == "achievements":
			SteamPanels.show_achievements(menu)
		else:
			SteamPanels.show_workshop(menu)
		await _page(panel)
		for child in menu.get_children():
			if child not in original:
				child.queue_free()
		await get_tree().process_frame
	await _release(menu)
	var editor := await _scene("editor")
	for section in ["units", "abilities", "waves", "global"]:
		editor._section = section
		editor._rebuild()
		await _page("editor_" + section)
	await _release(editor)
	var scenario := await _scene("scenario_editor")
	await _page("scenario_editor")
	await _bottom(scenario, "scenario_editor_bottom")
	for tool_name in ["select", "terrain", "unit", "decor", "reinforce", "gate", "camera", "erase"]:
		scenario.tool = tool_name
		scenario._refresh_tool_panel()
		await _page("scenario_tool_" + tool_name)
		if tool_name in ["unit", "reinforce"]:
			_check_palette_categories(scenario, tool_name)
		await _bottom(scenario, "scenario_tool_" + tool_name + "_bottom")
	var picker: OptionButton = scenario._key_opt(["wu_song"], "wu_song", func(_key: String) -> void: pass)
	check(picker.get_item_text(0) == Localize.text(Defs.UNITS.wu_song.name), "reinforcement picker translates built-in names")
	picker.free()
	await _custom_name_boundary(scenario)
	scenario._edit_unit("wu_song")
	await _page("scenario_unit")
	await _release(scenario)
	var codex := await _scene("codex")
	for key in ["wu_song", "huangfu_duan", "ruan_brother", "guan_musket"]:
		codex._select(key)
		await _page("codex_" + key)
		await _bottom(codex, "codex_" + key + "_bottom")
		codex._show_lore()
		await _page("lore_" + key)
		codex._hide_lore()
		await get_tree().create_timer(0.3).timeout
	var all_keys: Array = Bios.STAR.keys()
	for key in Defs.UNITS:
		if key not in all_keys:
			all_keys.append(key)
	for key in all_keys:
		codex._select(key)
		for frame in range(3):
			await get_tree().process_frame
		var edge := get_viewport().get_visible_rect().end.x
		check(codex._name_lbl.get_global_rect().end.x <= edge, "compendium heading width: " + key)
		check(codex._bio_lbl.get_global_rect().end.x <= edge, "compendium biography width: " + key)
		check(codex._abil_lbl.get_global_rect().end.x <= edge, "compendium ability width: " + key)
	await _release(codex)
	var f := FileAccess.open(OS.get_environment("LSH_QA_CAPTURE_DIR").path_join("layout_findings.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(layout_findings, "\t"))
	check(layout_findings.is_empty(), "visible text stays within the viewport or a scroll region")
	_finish()

func _check_palette_categories(scenario: Control, tool_name: String) -> void:
	var captions: Array = []
	for button in scenario._tool_panel.find_children("*", "Button", true, false):
		captions.append(button.text)
	for category in ["天罡", "地煞", "英雄·大将", "兵卒", "建筑"]:
		var expected: String = ("▸" if category == scenario._palette_cat else "") + Localize.text(category) + " (%d)" % scenario._units_in_cat(category).size()
		check(expected in captions, "palette category is localized: " + tool_name + ": " + category)

func _custom_name_boundary(scenario: Control) -> void:
	# A user name matching a catalogue key must remain user data in native controls.
	var custom_key := "qa_custom_name_collision"
	var custom_name := "返回菜单"
	var had_units: bool = scenario._cfg.has("units")
	var previous_category: String = scenario._palette_cat
	var previous_tool: String = scenario.tool
	var previous_unit: String = scenario.cur_unit
	if not had_units:
		scenario._cfg["units"] = {}
	var custom: Dictionary = Defs.UNITS.gao_qiu.duplicate(true)
	custom["name"] = custom_name
	scenario._cfg["units"][custom_key] = custom
	scenario._refresh_unit_keys()
	scenario._palette_cat = "英雄·大将"
	scenario.tool = "unit"
	scenario._refresh_tool_panel()
	await get_tree().process_frame
	var custom_button: Button = null
	var builtin_button: Button = null
	for button in scenario._tool_panel.find_children("*", "Button", true, false):
		if button.text == custom_name:
			custom_button = button
		if button.text == Localize.text(Defs.UNITS.gao_qiu.name):
			builtin_button = button
	check(custom_button != null, "unit palette retains custom source name")
	check(builtin_button != null, "unit palette explicitly translates built-in name")
	if custom_button != null:
		check(custom_button.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED, "custom unit button disables automatic translation")
		custom_button.pressed.emit()
		check(scenario.cur_unit == custom_key, "custom unit button selects its original key")
		check(scenario._toast.text == Localize.text("单位：") + custom_name, "custom unit notification translates only its prefix")
		var ancestor := custom_button.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer:
				ancestor.ensure_control_visible(custom_button)
			ancestor = ancestor.get_parent()
	if builtin_button != null:
		check(builtin_button.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED, "translated built-in unit button avoids a second translation")
	var selected: Array = []
	var collision: OptionButton = scenario._key_opt([custom_key, "wu_song"], custom_key, func(key: String) -> void: selected.append(key))
	collision.name = "CustomNameBoundaryPicker"
	collision.position = Vector2(440, 340)
	collision.size = Vector2(250, 42)
	scenario.add_child(collision)
	check(collision.get_item_text(0) == custom_name, "unit dropdown retains custom source name")
	check(collision.get_item_text(1) == Localize.text(Defs.UNITS.wu_song.name), "mixed unit dropdown explicitly translates built-in name")
	check(collision.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED, "custom unit dropdown disables automatic translation")
	check(collision.get_popup().auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED, "custom unit popup disables automatic translation")
	collision.select(1)
	collision.item_selected.emit(1)
	collision.select(0)
	collision.item_selected.emit(0)
	check(selected == ["wu_song", custom_key], "mixed unit dropdown returns original keys")
	check(scenario._cfg["units"][custom_key]["name"] == custom_name, "custom name display leaves saved source intact")
	await _page("scenario_custom_name_boundary")
	collision.queue_free()
	scenario._cfg["units"].erase(custom_key)
	if not had_units:
		scenario._cfg.erase("units")
	scenario._palette_cat = previous_category
	scenario.tool = previous_tool
	scenario.cur_unit = previous_unit
	scenario._refresh_unit_keys()
	scenario._refresh_tool_panel()
	await get_tree().process_frame

func _scene(id: String) -> Control:
	var scene: Control = load("res://scenes/" + id + ".tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	return scene

func _release(scene: Control) -> void:
	get_tree().current_scene = null
	get_tree().root.remove_child(scene)
	scene.free()
	await get_tree().process_frame

func _page(id: String) -> void:
	page = id
	await _capture(id)
	_inspect(get_tree().current_scene)

func _bottom(node: Node, id: String) -> void:
	var scrolls := node.find_children("*", "ScrollContainer", true, false)
	var changed := false
	for scroll in scrolls:
		if scroll.is_visible_in_tree() and scroll.get_v_scroll_bar().max_value > scroll.size.y:
			scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
			changed = true
	if changed:
		await _page(id)
	for scroll in scrolls:
		scroll.scroll_vertical = 0

func _inspect(node: Node) -> void:
	if node is Control and node.is_visible_in_tree() and (node is Label or node is Button):
		var rect: Rect2 = node.get_global_rect()
		var viewport := get_viewport().get_visible_rect()
		var can_scroll_x := false
		var can_scroll_y := false
		var parent := node.get_parent()
		while parent != null:
			if parent is ScrollContainer:
				can_scroll_x = can_scroll_x or parent.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
				can_scroll_y = can_scroll_y or parent.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
			parent = parent.get_parent()
		var overflow_x: bool = not can_scroll_x and (rect.position.x < -1 or rect.end.x > viewport.end.x + 1)
		var overflow_y: bool = not can_scroll_y and (rect.position.y < -1 or rect.end.y > viewport.end.y + 1)
		if overflow_x or overflow_y:
			layout_findings.append({"page": page, "node": str(node.get_path()), "text": node.text, "rect": str(rect), "horizontal": overflow_x, "vertical": overflow_y})
	for child in node.get_children():
		_inspect(child)
