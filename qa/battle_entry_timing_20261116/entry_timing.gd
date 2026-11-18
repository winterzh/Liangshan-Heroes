extends SceneTree

const MENU := "res://scenes/menu.tscn"
const BATTLE := "res://scenes/main.tscn"
const PICK := {
	"level6": ["剧情模式", "出 征"],
	"level3": ["剧情模式", "出 征"],
	"skirmish": ["驻守战", "30 关"],
	"skirmish_ai": ["1v1 对战", "普通"],
	"arena": ["竞技场"],
}

var entry_at := 0
var battle_added_at := 0
var frames_after_click: Array[int] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var mode := OS.get_environment("LSH_ENTRY_MODE")
	if DisplayServer.get_name() == "headless" or not PICK.has(mode):
		_fail("rendered mode and a known entry path are required")
		return
	node_added.connect(_on_node_added)
	RenderingServer.frame_post_draw.connect(_on_frame_drawn)
	if change_scene_to_file(MENU) != OK:
		_fail("could not open menu")
		return
	await scene_changed
	await RenderingServer.frame_post_draw
	var samples: Array[Dictionary] = []
	for visit in range(2):
		var sample := await _visit(mode, visit)
		if sample.is_empty():
			return
		samples.append(sample)
		current_scene.call("_goto_menu")
		await scene_changed
		await RenderingServer.frame_post_draw
	print("ENTRY_TIMING " + JSON.stringify({"mode":mode, "source":"rendered local project", "samples":samples}))
	quit(0)


func _visit(mode: String, visit: int) -> Dictionary:
	var menu := current_scene
	var available_from := Time.get_ticks_usec()
	var flow := root.get_node("ContinueFlow")
	while not flow.can_launch():
		if flow.phase == flow.Phase.ERROR or Time.get_ticks_usec() - available_from >= 60000000:
			_fail("menu progress verification did not finish")
			return {}
		await process_frame
	var readiness_ms := _ms(Time.get_ticks_usec() - available_from)
	var selector := _find_button(menu, PICK[mode][0])
	if selector == null and mode in ["level3", "level6"]:
		selector = _find_button(menu, "开始战役")
	if selector == null:
		_fail("mode button was not visible: " + mode)
		return {}
	var selection_us := 0
	if mode != "arena":
		var mode_at := Time.get_ticks_usec()
		selector.pressed.emit()
		await RenderingServer.frame_post_draw
		selection_us = Time.get_ticks_usec() - mode_at
		if mode in ["level3", "level6"]:
			var title := "三打祝家庄" if mode == "level3" else "大闹野猪林"
			var card := _campaign_card(menu, title)
			selector = _find_button(card, PICK[mode][1]) if card != null else null
		else:
			selector = _find_button(menu, PICK[mode][1])
		if selector == null:
			_fail("deploy/configuration button was not visible: " + mode)
			return {}

	battle_added_at = 0
	frames_after_click.clear()
	entry_at = Time.get_ticks_usec()
	var started_at := entry_at
	selector.pressed.emit()
	await scene_changed
	var ready_at := Time.get_ticks_usec()
	var battle = current_scene
	if battle.scene_file_path != BATTLE or battle.level.id() != mode or battle_added_at <= entry_at:
		_fail("unexpected transition for " + mode)
		return {}
	var rendered_before_ready := frames_after_click.size()
	await RenderingServer.frame_post_draw
	var initial_draw := Time.get_ticks_usec()
	var first_feedback := frames_after_click[0] if not frames_after_click.is_empty() else initial_draw
	entry_at = 0

	var intro_lines := 0
	while battle.hud._intro_root.visible:
		if intro_lines >= 30:
			_fail("intro did not reach deployment")
			return {}
		battle.hud._intro_btn.pressed.emit()
		intro_lines += 1
		await RenderingServer.frame_post_draw
	var play_at := Time.get_ticks_usec()
	var started_from_button: bool = battle.hud.start_btn.visible
	if started_from_button:
		battle.hud.start_btn.pressed.emit()
	await RenderingServer.frame_post_draw
	if battle.phase != battle.Phase.FIGHT:
		_fail("ordinary HUD controls did not open play")
		return {}
	var fight_rendered_at := Time.get_ticks_usec()
	var first_order := await _measure_first_order(battle, mode)
	if first_order < 0:
		_fail("right-click did not assign a movement order for " + mode)
		return {}
	return {
		"visit":visit + 1,
		"menu_until_entry_enabled_ms":readiness_ms,
		"mode_page_ms":_ms(selection_us) if mode != "arena" else null,
		"entry_to_first_render_ms":_ms(first_feedback - started_at),
		"entry_to_battle_attached_ms":_ms(battle_added_at - started_at),
		"battle_attached_to_scene_ready_ms":_ms(ready_at - battle_added_at),
		"scene_ready_to_first_battle_render_ms":_ms(initial_draw - ready_at),
		"entry_to_first_battle_render_ms":_ms(initial_draw - started_at),
		"frames_before_scene_ready":rendered_before_ready,
		"intro_pages":intro_lines,
		"start_button_to_fight_render_ms":_ms(fight_rendered_at - play_at) if started_from_button else null,
		"right_click_to_order_render_ms":first_order,
	}

func _measure_first_order(battle: Node, mode: String) -> float:
	var movers: Array = battle.units.filter(func(unit):
		return unit.faction == 0 and unit.hp > 0.0 and not unit.is_building and not unit.is_noncombat)
	if movers.is_empty():
		return -1.0
	var unit = battle.level.lu if mode == "level6" else movers.front()
	battle.select_single(unit, false)
	var origin: Vector2i = battle.map.world_to_cell(unit.position)
	await RenderingServer.frame_post_draw
	for offset in [Vector2i(-3, 0), Vector2i(3, 0), Vector2i(0, -3), Vector2i(0, 3)]:
		var cell: Vector2i = origin + offset
		if not battle.map.is_open_cell(cell):
			continue
		var ground: Vector2 = battle.map.cell_to_world(cell)
		var point: Vector2 = battle.to_screen(ground)
		if battle._unit_at(point) != null:
			continue
		var event := InputEventMouseButton.new()
		event.position = battle.get_canvas_transform() * point
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = true
		var serial: int = unit._order_serial
		var clicked := Time.get_ticks_usec()
		battle._unhandled_input(event)
		if unit._order_serial <= serial or battle._click_fx_t <= 0.0:
			return -1.0
		if battle._click_fx_pos.distance_to(point) > 1.0:
			return -1.0
		await RenderingServer.frame_post_draw
		return _ms(Time.get_ticks_usec() - clicked)
	return -1.0


func _campaign_card(menu: Node, title: String) -> Node:
	var cards := menu.find_child("CampaignCardsScroll", true, false)
	if cards == null:
		return null
	for label in cards.find_children("*", "Label", true, false):
		if (label as Label).text == title:
			return label.get_parent().get_parent()
	return null


func _find_button(scope: Node, text: String) -> Button:
	for candidate in scope.find_children("*", "Button", true, false):
		var button := candidate as Button
		if button.is_visible_in_tree() and not button.disabled and button.text.contains(text):
			return button
	return null


func _on_node_added(node: Node) -> void:
	if entry_at > 0 and node.get_parent() == root and node.scene_file_path == BATTLE:
		battle_added_at = Time.get_ticks_usec()


func _on_frame_drawn() -> void:
	if entry_at > 0:
		frames_after_click.append(Time.get_ticks_usec())


func _ms(us: int) -> float:
	return snappedf(us / 1000.0, 0.01)


func _fail(detail: String) -> void:
	printerr("ENTRY_TIMING_ERROR " + detail)
	quit(1)
