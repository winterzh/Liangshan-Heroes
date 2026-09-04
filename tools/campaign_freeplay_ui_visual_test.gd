extends SceneTree
## 1280x720 campaign UI evidence for the free-clear / original-story reward layer.
## This captures rendered pixels and target control bounds. It is visual QA,
## not a human playtest, campaign completion, pacing, or performance evidence.

const VIEW_SIZE := Vector2i(1280, 720)
const DEFAULT_OUT := "res://qa/campaign_freeplay_rewards_20260901/ui_visual"

var output_dir := ""
var results: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	OS.set_environment("SMOKE_TEST", "")
	OS.set_environment("LEVEL", "")
	if DisplayServer.get_name() == "headless":
		push_error("Campaign UI visual capture needs a graphical renderer.")
		quit(2)
		return
	output_dir = OS.get_environment("CAMPAIGN_UI_VISUAL_OUT")
	if output_dir == "":
		output_dir = ProjectSettings.globalize_path(DEFAULT_OUT)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("Cannot create UI evidence directory: " + output_dir)
		quit(2)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = VIEW_SIZE
	root.content_scale_size = VIEW_SIZE
	root.title = "Liangshan campaign UI QA · 1280×720"
	AudioServer.set_bus_mute(0, true)
	root.get_node("Settings").edge_scroll = false
	var campaign = root.get_node("Campaign")
	var records_before: Dictionary = campaign.records.duplicate(true)
	var current_before: int = campaign.current
	var unlocked_before: int = campaign.unlocked
	var all_passed := await _capture_story_menu(campaign)
	all_passed = await _capture_battle_hud(campaign) and all_passed
	campaign.records = records_before
	campaign.current = current_before
	campaign.unlocked = unlocked_before
	var report := {
		"viewport": [VIEW_SIZE.x, VIEW_SIZE.y],
		"samples": results,
		"all_target_bounds_inside_viewport": all_passed,
		"save_writes": false,
		"human_playtest": false,
		"pacing_test": false,
		"performance_test": false,
		"scope": "Rendered menu and live battle HUD at 1280x720; target-control bounds are recorded after layout settled.",
	}
	var report_error := _write_json(output_dir.path_join("report.json"), report)
	print("[campaign-ui-visual] ", JSON.stringify({"passed": all_passed, "samples": results.size(), "report_error": report_error}))
	quit(0 if all_passed and report_error == OK else 1)


func _capture_story_menu(campaign) -> bool:
	campaign.records = {
		"level6": {"cleared": true, "story_complete": false, "best_done": 2, "story_total": 3, "best_goal_ids": ["intercept", "mercy"], "contract_version": 1},
		"level1": {"cleared": true, "story_complete": true, "best_done": 4, "story_total": 4, "best_goal_ids": ["named", "wine", "drugged", "safe"], "contract_version": 1},
		"level7": {"cleared": true, "story_complete": false, "best_done": 3, "story_total": 4, "best_goal_ids": ["drinks", "challenge", "subdue"], "contract_version": 1},
		"level2": {"cleared": true, "story_complete": false, "best_done": 3, "story_total": 4, "best_goal_ids": ["signal", "rescue", "bailong"], "contract_version": 1},
	}
	campaign.unlocked = campaign.LEVELS.size()
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var entry_image: Dictionary = _save_frame("campaign_entry_1280.png")
	var entry_texts := _find_texts(menu, ["剧情模式", "八幕全开放", "自由通关", "演义印"])
	results.append({
		"id": "campaign_entry",
		"png": output_dir.path_join("campaign_entry_1280.png"),
		"png_ok": entry_image.ok,
		"resolution_ok": entry_image.resolution_ok,
		"visible_rule_texts": entry_texts,
	})
	menu._show_story()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image_result: Dictionary = _save_frame("story_menu_1280.png")
	var cards: Array[Dictionary] = []
	var target_inside: bool = true
	_collect_story_cards(menu, cards)
	for card in cards:
		target_inside = target_inside and bool(card.get("inside_viewport", false))
	var sample := {
		"id": "story_menu",
		"png": output_dir.path_join("story_menu_1280.png"),
		"png_ok": image_result.ok,
		"resolution_ok": image_result.resolution_ok,
		"cards_found": cards.size(),
		"cards": cards,
		"target_bounds_inside_viewport": target_inside,
		"visible_reward_texts": _find_texts(menu, ["演义印", "已通关", "演义"]),
	}
	results.append(sample)
	menu.queue_free()
	await process_frame
	await process_frame
	return entry_image.ok and entry_image.resolution_ok and not entry_texts.is_empty() \
		and image_result.ok and image_result.resolution_ok and cards.size() == 8 and target_inside


func _capture_battle_hud(campaign) -> bool:
	for key in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(key, false)
	campaign.current = campaign.index_for_id("level2")
	seed(5088120)
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	battle.hud._intro_root.hide()
	battle._on_intro_done()
	battle.hud._on_start_pressed()
	for _i in range(5):
		await process_frame
	battle.hud.set_top(battle.level.top_status(battle))
	battle.mission.tick(0.0)
	battle.mission._panel.reset_size()
	await process_frame
	await process_frame
	battle.mission.tick(0.0)
	battle.mission._panel.reset_size()
	await RenderingServer.frame_post_draw
	var image_result: Dictionary = _save_frame("battle_hud_four_goals_1280.png")
	var panel: Control = battle.mission._panel
	var panel_rect: Rect2 = panel.get_global_rect()
	var bottom_panel: Control = battle.hud._bottom_panel
	var bottom_rect: Rect2 = bottom_panel.get_global_rect()
	var target_inside: bool = _rect_inside_viewport(panel_rect)
	var clear_of_command_panel: bool = panel_rect.end.y <= bottom_rect.position.y - 6.0
	var story_goal_count: int = battle.mission.story_goals.size()
	var sample := {
		"id": "battle_hud_four_goals",
		"level_id": battle.level.id(),
		"stage_id": battle.mission.stage_id,
		"png": output_dir.path_join("battle_hud_four_goals_1280.png"),
		"png_ok": image_result.ok,
		"resolution_ok": image_result.resolution_ok,
		"objective_panel_rect": _rect_dict(panel_rect),
		"bottom_command_panel_rect": _rect_dict(bottom_rect),
		"target_bounds_inside_viewport": target_inside,
		"clear_of_command_panel": clear_of_command_panel,
		"story_goal_count": story_goal_count,
		"visible_freeplay_texts": _find_texts(panel, ["核心目标", "演义目标（可选）", "本关仍可继续", "自行下令", "任务按钮仅代为派遣"]),
	}
	results.append(sample)
	var partial_result := {
		"core_cleared": true,
		"story_complete": false,
		"story_done": 3,
		"story_total": 4,
		"new_story_seal": false,
		"goals": [
			{"label":"候李逵排头动手","state":"done"},
			{"label":"分别救下宋江、戴宗","state":"done"},
			{"label":"白龙庙与张顺、张横相会","state":"missed"},
			{"label":"本关具名好汉全部脱险","state":"done"},
		],
	}
	battle.hud.show_end(true, "宋江、戴宗已经登船脱险。", 12, true, "", partial_result)
	await process_frame
	await RenderingServer.frame_post_draw
	var partial_image: Dictionary = _save_frame("battle_result_partial_1280.png")
	var end_sub_rect: Rect2 = battle.hud._end_sub.get_global_rect()
	var partial_text: String = battle.hud._end_sub.text
	var partial_clear := "基础通关：完成" in partial_text and "演义复现：3/4" in partial_text \
		and "演义印未收录（可重打补齐）" in partial_text \
		and "待补演义：白龙庙与张顺、张横相会" in partial_text
	results.append({
		"id": "battle_result_partial",
		"png": output_dir.path_join("battle_result_partial_1280.png"),
		"png_ok": partial_image.ok,
		"resolution_ok": partial_image.resolution_ok,
		"summary_rect": _rect_dict(end_sub_rect),
		"summary_inside_viewport": _rect_inside_viewport(end_sub_rect),
		"reward_distinction_clear": partial_clear,
		"summary_text": partial_text,
	})
	var complete_result := partial_result.duplicate(true)
	complete_result.story_complete = true
	complete_result.story_done = 4
	complete_result.new_story_seal = true
	for goal in complete_result.goals: goal.state = "done"
	battle.hud.show_end(true, "宋江、戴宗已经登船脱险。", 12, true, "", complete_result)
	await process_frame
	await RenderingServer.frame_post_draw
	var complete_image: Dictionary = _save_frame("battle_result_seal_1280.png")
	var complete_text: String = battle.hud._end_sub.text
	var complete_clear := "基础通关：完成" in complete_text and "演义复现：4/4" in complete_text \
		and "首次获得演义印" in complete_text and "待补演义：" not in complete_text
	results.append({
		"id": "battle_result_seal",
		"png": output_dir.path_join("battle_result_seal_1280.png"),
		"png_ok": complete_image.ok,
		"resolution_ok": complete_image.resolution_ok,
		"summary_inside_viewport": _rect_inside_viewport(battle.hud._end_sub.get_global_rect()),
		"reward_distinction_clear": complete_clear,
		"summary_text": complete_text,
	})
	var passed: bool = image_result.ok and image_result.resolution_ok and target_inside and clear_of_command_panel and story_goal_count == 4 \
		and partial_image.ok and partial_image.resolution_ok and partial_clear \
		and complete_image.ok and complete_image.resolution_ok and complete_clear
	# Generated minimap/fog textures otherwise outlive the queued scene until the
	# SceneTree exits, which turns successful visual evidence into noisy RID leaks.
	if is_instance_valid(battle.hud.minimap):
		battle.hud.minimap._bg = null
	if is_instance_valid(battle._fog_layer):
		battle._fog_layer.tex = null
	battle._fog_tex = null
	if battle.map.height_field != null:
		battle.map.height_field.texture = null
	battle.map.material = null
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	for cursor_name in ["_target_cursor", "_cur_attack", "_cur_gather_wood", "_cur_gather_gold", "_cur_repair", "_cur_select", "_cur_garrison"]:
		battle.set(cursor_name, null)
	current_scene = null
	battle.queue_free()
	await process_frame
	await process_frame
	return passed


func _collect_story_cards(node: Node, out: Array[Dictionary]) -> void:
	for child in node.get_children():
		if child is PanelContainer and child.custom_minimum_size == Vector2(200, 250):
			var texts := _all_label_texts(child)
			if texts.any(func(value): return String(value).begins_with("第 ")):
				var rect: Rect2 = child.get_global_rect()
				out.append({"rect": _rect_dict(rect), "inside_viewport": _rect_inside_viewport(rect), "texts": texts})
		_collect_story_cards(child, out)


func _all_label_texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label and node.visible:
		out.append(node.text)
	if node is Button and node.visible:
		out.append(node.text)
	for child in node.get_children():
		out.append_array(_all_label_texts(child))
	return out


func _find_texts(node: Node, needles: Array[String]) -> Array[String]:
	var found: Array[String] = []
	for value in _all_label_texts(node):
		for needle in needles:
			if needle in value and not found.has(value):
				found.append(value)
	return found


func _rect_inside_viewport(rect: Rect2) -> bool:
	return rect.position.x >= -0.5 and rect.position.y >= -0.5 and rect.end.x <= VIEW_SIZE.x + 0.5 and rect.end.y <= VIEW_SIZE.y + 0.5


func _rect_dict(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y, "right": rect.end.x, "bottom": rect.end.y}


func _save_frame(filename: String) -> Dictionary:
	var image := root.get_texture().get_image()
	var resolution_ok := image != null and not image.is_empty() and image.get_size() == VIEW_SIZE
	var error := ERR_CANT_CREATE
	if resolution_ok:
		error = image.save_png(output_dir.path_join(filename))
	return {"ok": error == OK, "resolution_ok": resolution_ok, "error": error}


func _write_json(path: String, data: Variant) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return OK
