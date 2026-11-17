extends SceneTree
## Measures the first rendered battle in the exact compiled Windows pack.

var draw_count := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	AudioServer.set_bus_mute(0,true)
	var flow = root.get_node("ContinueFlow")
	var began := Time.get_ticks_usec()
	RenderingServer.frame_post_draw.connect(func(): draw_count += 1)
	if change_scene_to_file("res://scenes/menu.tscn") != OK:
		_finish({"passed":false,"error":"menu"})
		return
	await scene_changed
	var menu := current_scene
	var deadline := Time.get_ticks_msec() + 35000
	while flow.busy() and flow.phase != flow.Phase.ERROR and Time.get_ticks_msec() < deadline:
		await process_frame
	var cached: bool = flow.can_launch() and flow._startup_entry_provider != null
	var identity: Dictionary = flow._startup_identity
	var startup_us := Time.get_ticks_usec() - began
	var startup_draws := draw_count
	if not cached or identity.get("source_mode",true):
		_finish({"passed":false,"error":"compiled startup result","cached":cached,"code":flow.last_result.get("code","")})
		return
	var story := _find_button(menu,"剧情模式")
	if story == null:
		_finish({"passed":false,"error":"story selection"})
		return
	root.get_node("Campaign").unlocked = 3
	story.pressed.emit()
	await RenderingServer.frame_post_draw
	var card := _campaign_card(menu,"三打祝家庄")
	var deploy := _find_button(card,"出 征") if card != null else null
	if deploy == null:
		_finish({"passed":false,"error":"deployment selection"})
		return
	var started := Time.get_ticks_usec()
	deploy.pressed.emit()
	var overlay := menu.get_node_or_null("BattleLoading")
	var loading_draw_at := 0
	var observed_scan := false
	deadline = Time.get_ticks_msec() + 20000
	while (current_scene == null or (is_instance_valid(menu) and current_scene == menu)) and Time.get_ticks_msec() < deadline:
		await RenderingServer.frame_post_draw
		if loading_draw_at == 0 and is_instance_valid(overlay): loading_draw_at = Time.get_ticks_usec()
		if is_instance_valid(menu) and menu._entry_scan != null: observed_scan = true
	var b = current_scene
	var first_battle_us := Time.get_ticks_usec() - started
	var entered: bool = is_instance_valid(b) and b.scene_file_path == "res://scenes/main.tscn" and b.level.id() == "level3"
	var preserved: bool = entered and b._gameplay_content_identity == identity and b.gameplay_rng_fault().is_empty()
	var used_once: bool = flow._startup_entry_provider == null and flow.take_startup_entry_identity().is_empty()
	_finish({"passed":startup_draws > 1 and entered and preserved and used_once and not observed_scan,
		"startup_us":startup_us,"startup_rendered_frames":startup_draws,"click_to_battle_draw_us":first_battle_us,
		"loading_draw_us":loading_draw_at-started if loading_draw_at > 0 else -1,
		"first_battle_started":entered,"installed_identity_preserved":preserved,"cached_identity_consumed_once":used_once,
		"new_entry_scan_observed":observed_scan,"identity":identity})

func _campaign_card(menu: Node, title: String) -> Node:
	var cards := menu.find_child("CampaignCardsScroll",true,false)
	if cards == null: return null
	for label in cards.find_children("*","Label",true,false):
		if (label as Label).text == title: return label.get_parent().get_parent()
	return null

func _find_button(scope: Node, text: String) -> Button:
	for candidate in scope.find_children("*","Button",true,false):
		var button := candidate as Button
		if button.is_visible_in_tree() and not button.disabled and button.text.contains(text): return button
	return null

func _finish(result: Dictionary) -> void:
	print("ZHU_STARTUP_PACK_RESULT ",JSON.stringify(result))
	if result.passed:
		root.get_node("AppLifecycle").request_quit("campaign_pack_probe")
	else:
		root.get_node("Sfx").shutdown()
		root.get_node("Music").shutdown()
		quit.call_deferred(1)
