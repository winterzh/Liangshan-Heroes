extends Node

const MENU := "res://scenes/menu.tscn"
const BATTLE := "res://scenes/main.tscn"
const PICK := {
	"level3": ["剧情模式", "出 征"],
	"skirmish": ["驻守战", "30 关"],
	"skirmish_ai": ["1v1 对战", "普通"],
	"arena": ["竞技场"],
}

var entry_at := 0
var battle_added_at := 0
var frames_after_click: Array[int] = []
var first_identity: Dictionary


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("rendered mode is required")
		return
	get_tree().node_added.connect(_on_node_added)
	RenderingServer.frame_post_draw.connect(_on_frame_drawn)
	if get_tree().change_scene_to_file(MENU) != OK:
		_fail("could not open menu")
		return
	await get_tree().scene_changed
	await RenderingServer.frame_post_draw
	var cases := [
		["fast_arena","arena",false,false],
		["ready_level3","level3",true,false],
		["cancelled_arena","arena",true,true],
		["ready_skirmish","skirmish",true,false],
		["ready_skirmish_ai","skirmish_ai",true,false],
	]
	for index in range(cases.size()):
		var row: Array = cases[index]
		var menu := get_tree().current_scene
		var started := Time.get_ticks_usec()
		while menu._entry_scan == null and Time.get_ticks_usec()-started < 10000000:
			await get_tree().process_frame
		var provider: RefCounted = menu._entry_scan
		if provider == null:
			_fail("no Windows prewarm started after the first menu frame")
			return
		if row[2]:
			while provider.runtime_identity_scan_pending() and Time.get_ticks_usec()-started < 20000000:
				await get_tree().process_frame
			if provider.runtime_identity_scan_pending():
				_fail("prewarm did not finish")
				return
		else:
			if not provider.runtime_identity_scan_pending():
				_fail("fast click did not join an active prewarm")
				return
		var pending: bool = provider.runtime_identity_scan_pending()
		var elapsed := _ms(Time.get_ticks_usec()-started)
		if row[3]:
			menu.cancel_battle_prewarm()
			if menu._entry_scan != null:
				_fail("menu operation could not release the prior verification")
				return
		var sample := await _visit(row[1], index)
		if sample.is_empty():
			return
		sample.merge({"label":row[0],"mode":row[1],"elapsed_menu_before_selection_ms":elapsed,
			"warmup_pending_before_selection":pending,"explicitly_cancelled_prewarm":row[3]})
		print("ENTRY_PREWARM_SAMPLE " + JSON.stringify(sample))
		if index < cases.size() - 1:
			get_tree().current_scene.call("_goto_menu")
			await get_tree().scene_changed
			await RenderingServer.frame_post_draw
	var synchronous: Dictionary = load("res://scripts/run_content_identity.gd").new().resolve_runtime_identity()
	if synchronous != first_identity:
		_fail("background identity differs from synchronous save/restore identity")
		return
	print("ENTRY_PACK_IDENTITY " + JSON.stringify(synchronous))
	get_tree().quit()


func _visit(mode: String, visit: int) -> Dictionary:
	var menu := get_tree().current_scene
	var selector := _find_button(menu, PICK[mode][0])
	if selector == null:
		_fail("mode button was not visible: " + mode)
		return {}
	var selection_us := 0
	if mode != "arena":
		var mode_at := Time.get_ticks_usec()
		selector.pressed.emit()
		await RenderingServer.frame_post_draw
		selection_us = Time.get_ticks_usec() - mode_at
		if mode == "level3":
			var card := _campaign_card(menu, "三打祝家庄")
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
	var previous_max_fps := Engine.max_fps
	selector.pressed.emit()
	var overlay := menu.get_node_or_null("BattleLoading")
	if overlay == null or not overlay.find_children("*", "ProgressBar", true, false)[0].indeterminate:
		_fail("loading status was not installed")
		return {}
	var provider: RefCounted = menu._entry_scan
	selector.pressed.emit()
	if provider != menu._entry_scan or overlay != menu.get_node_or_null("BattleLoading"):
		_fail("duplicate transition replaced the loading flow")
		return {}
	await get_tree().scene_changed
	var ready_at := Time.get_ticks_usec()
	if Engine.max_fps != previous_max_fps:
		_fail("loading frame limit leaked after scene change")
		return {}
	var battle = get_tree().current_scene
	if battle.scene_file_path != BATTLE or battle.level.id() != mode or battle_added_at <= entry_at:
		_fail("unexpected transition for " + mode)
		return {}
	var rendered_before_ready := frames_after_click.size()
	var identity: Dictionary = battle._gameplay_content_identity
	if rendered_before_ready < 1 or not battle._gameplay_identity_bound(identity) or identity.get("source_mode") != false:
		_fail("invalid entry " + JSON.stringify({"mode":mode,"visit":visit,
			"frames":rendered_before_ready,"identity":identity,"rng_fault":battle._gameplay_rng_issue,
			"rng_started":battle._gameplay_rng_start_kind,"phase":battle.phase}))
		return {}
	if first_identity.is_empty():
		first_identity = identity.duplicate(true)
	elif identity != first_identity:
		_fail("repeat entry reused a different identity for unchanged inputs")
		return {}
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
	return {
		"visit":visit + 1,
		"mode_page_ms":_ms(selection_us) if mode != "arena" else null,
		"entry_to_first_render_ms":_ms(first_feedback - started_at),
		"entry_to_battle_attached_ms":_ms(battle_added_at - started_at),
		"battle_attached_to_scene_ready_ms":_ms(ready_at - battle_added_at),
		"scene_ready_to_first_battle_render_ms":_ms(initial_draw - ready_at),
		"entry_to_first_battle_render_ms":_ms(initial_draw - started_at),
		"frames_before_scene_ready":rendered_before_ready,
		"intro_pages":intro_lines,
		"start_button_to_fight_render_ms":_ms(Time.get_ticks_usec() - play_at) if started_from_button else null,
	}


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
	if entry_at > 0 and node.get_parent() == get_tree().root and node.scene_file_path == BATTLE:
		battle_added_at = Time.get_ticks_usec()


func _on_frame_drawn() -> void:
	if entry_at > 0:
		frames_after_click.append(Time.get_ticks_usec())


func _ms(us: int) -> float:
	return snappedf(us / 1000.0, 0.01)


func _fail(detail: String) -> void:
	printerr("ENTRY_TIMING_ERROR " + detail)
	get_tree().quit(1)
