extends SceneTree
## One normal-menu entry per chapter and one random defense entry in the frozen Windows pack.

const MENU := "res://scenes/menu.tscn"
const BATTLE := "res://scenes/main.tscn"
var trusted := {}
var samples: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var appdata := OS.get_environment("APPDATA").replace("\\","/")
	if OS.get_environment("STEAM_DISABLED") != "1" or not appdata.contains("/entry-492e6437/") \
			or not OS.get_user_data_dir().replace("\\","/").begins_with(appdata + "/"):
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	if change_scene_to_file(MENU) != OK:
		_fail("main menu")
		return
	await scene_changed
	var flow = root.get_node("ContinueFlow")
	var deadline := Time.get_ticks_msec()+60000
	while flow.busy() and flow.phase != flow.Phase.ERROR and Time.get_ticks_msec()<deadline:
		await process_frame
	trusted=flow._startup_identity
	if not flow.can_launch() or not trusted.get("ok",false) or trusted.get("source_mode",true):
		_fail("compiled startup identity")
		return
	var campaign = root.get_node("Campaign")
	for id in campaign.STORY_ORDER:
		var index: int = campaign.index_for_id(id)
		if not await _visit(id,campaign.LEVELS[index].title): return
	if not await _visit("skirmish",""): return
	print("FINAL_ENTRY_RESULT ",JSON.stringify({"passed":true,"identity":trusted,"samples":samples,
		"catalog_sha256":FileAccess.get_sha256("res://assets/localization/catalog.json")}))
	root.get_node("AppLifecycle").request_quit("windows_final_entry_qa")

func _visit(id: String, title: String) -> bool:
	var menu := current_scene
	var random_mode := id=="skirmish"
	var pick := _find_button(menu,"驻守战" if random_mode else "剧情模式")
	if pick == null: return _fail("mode selector for "+id)
	pick.pressed.emit()
	await RenderingServer.frame_post_draw
	var deploy: Button
	if random_mode:
		deploy=_find_button(menu,"随机波次 · 开战")
		var edited := 0
		for node in menu.find_children("*","SpinBox",true,false):
			var box := node as SpinBox
			if not box.is_visible_in_tree(): continue
			if box.max_value==999.0:
				box.value=17
				edited+=1
			elif box.max_value==600.0:
				box.value=41
				edited+=1
		if edited!=2: return _fail("random configuration")
		await RenderingServer.frame_post_draw
	else:
		var card := _campaign_card(menu,title)
		if card != null: deploy=_find_button(card,"出 征")
	if deploy == null: return _fail("deployment selector for "+id)
	var clicked := Time.get_ticks_usec()
	deploy.pressed.emit()
	var loading := menu.get_node_or_null("BattleLoading")
	if loading == null or not loading.visible: return _fail("loading feedback for "+id)
	await RenderingServer.frame_post_draw
	var loading_us := Time.get_ticks_usec()-clicked
	var deadline := Time.get_ticks_msec()+20000
	while (current_scene == null or current_scene == menu) and Time.get_ticks_msec()<deadline:
		await RenderingServer.frame_post_draw
	var b = current_scene
	if b == null or b.scene_file_path != BATTLE or b.level.id() != id:
		return _fail("battle transition for "+id)
	await RenderingServer.frame_post_draw
	var ready_us := Time.get_ticks_usec()-clicked
	if not b.gameplay_rng_fault().is_empty() or b._gameplay_content_identity!=trusted:
		return _fail("battle identity for "+id)
	var prefs_verified := false
	if random_mode:
		var cfg := ConfigFile.new()
		var campaign = root.get_node("Campaign")
		prefs_verified=cfg.load("user://campaign.cfg")==OK and cfg.get_value("pref","defense_rand_waves",0)==17 \
			and is_equal_approx(float(cfg.get_value("pref","defense_interval",0)),41.0) \
			and campaign.defense_random and campaign.defense_waves==17 and is_equal_approx(campaign.defense_interval,41.0)
		if not prefs_verified: return _fail("random preference persistence")
	for page in range(30):
		if not b.hud._intro_root.visible: break
		b.hud._intro_btn.pressed.emit()
		await process_frame
	if b.hud.start_btn.visible: b.hud.start_btn.pressed.emit()
	await RenderingServer.frame_post_draw
	if b.phase!=b.Phase.FIGHT: return _fail("battle start for "+id)
	var released := [weakref(b),weakref(b.map),weakref(b.hud),weakref(b.world),weakref(b.units_root)]
	b.hud.to_menu.emit()
	deadline=Time.get_ticks_msec()+15000
	while (current_scene == null or current_scene.scene_file_path!=MENU) and Time.get_ticks_msec()<deadline:
		await process_frame
	await RenderingServer.frame_post_draw
	for frame in range(3): await process_frame
	if current_scene==null or current_scene.scene_file_path!=MENU or paused \
			or not released.all(func(ref): return ref.get_ref()==null):
		return _fail("battle cleanup for "+id)
	var sample := {"mode":id,"click_to_loading_us":loading_us,"click_to_battle_draw_us":ready_us,
		"released_battle_refs":released.size(),"random_preferences_persisted":prefs_verified}
	samples.append(sample)
	print("FINAL_ENTRY_MODE ",JSON.stringify(sample))
	return true

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

func _fail(reason: String) -> bool:
	push_error(reason)
	quit.call_deferred(1)
	return false
