extends Node
## Native-resolution offscreen rendering, not a physical-device/human playtest.
## Run this scene ONLY in an isolated project with an LSH-rts-* user-data profile.

const LayoutAudit := preload("res://tools/rts_touch_layout_qa.gd")
const CASES := [
	["pc_1280", Vector2i(1280, 720)],
	["xiaomi_12s_ultra", Vector2i(3200, 1440)],
	["vivo_x300_ultra", Vector2i(3168, 1440)],
	["lenovo_y900", Vector2i(3000, 1876)],
	["lenovo_y900_13_2026", Vector2i(3840, 2560)],
	["tablet_13_16x10", Vector2i(2880, 1800)],
	["fold_4x3", Vector2i(1920, 1440)],
]

var viewport: SubViewport
var battle: Battle
var samples: Array = []
var failures: Array = []
var output := ""
var graphical := false

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var profile := String(ProjectSettings.get_setting("application/config/custom_user_dir_name", ""))
	output = OS.get_environment("LSH_RTS_QA_OUT")
	if not profile.begins_with("LSH-rts-") or output == "":
		push_error("RTS UI QA requires an isolated LSH-rts-* profile and LSH_RTS_QA_OUT.")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	graphical = DisplayServer.get_name() != "headless"
	AudioServer.set_bus_mute(0, true)
	Settings.edge_scroll = false
	Campaign.arena = true
	Campaign.skirmish = false
	Campaign.skirmish_ai = false
	Campaign.scenario = false
	Campaign.custom_defense = false
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.size_2d_override = Vector2i(1280, 720)
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	battle = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(battle)
	await _settle()
	if battle.hud == null or not battle._gameplay_rng_issue.is_empty():
		push_error("Battle startup failed: " + battle._gameplay_rng_issue)
		get_tree().quit(2)
		return
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.camera.set_process(false)
	battle.camera.set_physics_process(false)
	battle.hud._intro_root.hide()
	battle.hud.start_btn.hide()
	battle.phase = Battle.Phase.FIGHT
	battle.track_hero_combat_stats = true
	for key in ["song_jiang", "lin_chong", "lu_zhishen", "wu_song", "li_kui", "hua_rong"]:
		var hero := battle.spawn_at(key, Unit.FACTION_LIANG, Vector2i(18 + battle.liang_heroes().size(), 25))
		if hero == null:
			push_error("Missing fixture hero: " + key)
			get_tree().quit(2)
			return
		hero.hero_level = 10
		hero.skill_points = 8
		hero._hero_leveled = true
		for slot in hero.ability_slots:
			slot["rank"] = 1
	for unit in battle.units:
		unit.set_process(false)
		unit.set_physics_process(false)
	var hero: Unit = null
	for candidate in battle.liang_heroes():
		if candidate.key == "song_jiang": hero = candidate
	battle.select_single(hero, false)
	var selection_filter := OS.get_environment("LSH_RTS_UI_CASES")
	var state_filter := OS.get_environment("LSH_RTS_UI_STATES")
	for device in CASES:
		if selection_filter != "" and String(device[0]) not in selection_filter.split(","):
			continue
		var physical: Vector2i = device[1]
		# Exactly the production canvas_items/expand relationship: one scale
		# factor, with extra logical width or height revealed instead of cropped.
		var scale_factor := minf(float(physical.x) / 1280.0, float(physical.y) / 720.0)
		viewport.size = physical
		viewport.size_2d_override = Vector2i(roundi(float(physical.x) / scale_factor), roundi(float(physical.y) / scale_factor))
		var touch: bool = String(device[0]) != "pc_1280"
		for safe_case in ([false, true] if touch else [false]):
			var inset_x := 72 if safe_case else 0
			var inset_y := 24 if safe_case else 0
			OS.set_environment("LIANGSHAN_HUD_SAFE_AREA_TEST", "%d,%d,%d,%d,%d,%d" % [physical.x, physical.y, inset_x, inset_y, physical.x - inset_x * 2, physical.y - inset_y * 2])
			battle.hud.set_touch_ui(touch)
			battle.hud._apply_safe_area()
			var prefix := "%s_%s" % [String(device[0]), "safe" if safe_case else "plain"]
			for state in (["selected", "toast", "info", "inventory", "both", "aiming", "auto_aiming", "approaching", "casting", "controlled", "stats", "dead", "idle"] if touch else ["selected"]):
				if state_filter != "" and state not in state_filter.split(","):
					continue
				battle._disarm_ability()
				Settings.auto_micro_level = 1 if state == "auto_aiming" else 0
				for candidate in battle.liang_heroes():
					candidate.auto_micro = state == "auto_aiming"
				battle._walk_casts.clear()
				battle._pending_casts.clear()
				hero._cast_t = 0.0
				hero._stun_t = 0.0
				hero.hp = hero.max_hp
				battle.hud._clear_info_toasts()
				battle.hud._message_log.clear()
				battle.hud._compact_combat_stats = state == "stats"
				battle.hud._hero_keys.clear()
				battle.hud._refresh_hero_bar()
				battle.select_single(hero, false)
				battle.hud._set_info_expanded(state in ["info", "both"])
				battle.hud._inventory_popup_open = state in ["inventory", "both"]
				if state in ["aiming", "auto_aiming"]:
					battle.cast_ability(hero, 1, true)
				elif state == "approaching":
					battle._queue_walk_cast_point(hero, 1, hero.position + Vector2(1000, 0))
				elif state == "casting":
					battle._begin_cast(hero, 1, hero.position + Vector2(100, 0))
				elif state == "controlled":
					hero._stun_t = 3.0
				elif state == "dead":
					hero.hp = 0.0 # Fixture only: retains the registered roster slot.
					battle._set_selection([])
				elif state == "idle":
					battle._set_selection([])
				if state in ["toast", "info", "both"]:
					battle.hud.show_message("布局检查：英雄技能、物品与战况信息同时可见。", 10.0)
				battle.hud._refresh_skill_rail()
				battle.hud._refresh_resource_values()
				battle.hud.refresh_inventory()
				battle.hud._apply_safe_area()
				await _settle()
				var result: Dictionary = LayoutAudit.new().audit(battle.hud)
				if state in ["aiming", "approaching", "casting", "controlled"]:
					var actual_state := String(battle.hud._hero_skill_state(hero, 1).get("state", ""))
					if actual_state != state:
						result.ok = false
						result.failures.append({"name": "command_state", "expected": state, "actual": actual_state})
				result["id"] = prefix + "_" + state
				result["physical"] = str(physical)
				if graphical:
					var path := output.path_join("touch_" + String(result.id) + ".png")
					result["screenshot"] = path
					result["screenshot_error"] = viewport.get_texture().get_image().save_png(path)
					if int(result.screenshot_error) != OK:
						result.ok = false
				samples.append(result)
				if not result.ok:
					failures.append({"id": result.id, "failures": result.failures})
				print("[rts-touch-ui] ", result.id, " ", "PASS" if result.ok else JSON.stringify(result.failures))
				hero.hp = hero.max_hp
	if OS.get_environment("LSH_RTS_UI_ECONOMY") == "1":
		await _economy_language_samples()
	_interaction_checks()
	var file := FileAccess.open(output.path_join("touch-layout-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": failures.is_empty(), "graphical": graphical, "human_playtest": false,
		"rendering": "native SubViewport; production 1280x720 canvas_items/expand-equivalent logical size", "samples": samples, "failures": failures}, "\t"))
	print("[rts-touch-ui] DONE samples=", samples.size(), " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _settle() -> void:
	for frame in range(5):
		await get_tree().process_frame
	if graphical:
		await RenderingServer.frame_post_draw

func _interaction_checks() -> void:
	battle.hud.set_touch_ui(true)
	battle.hud._refresh_skill_rail()
	var tested := false
	for row in battle.hud._skill_rail.get_children():
		for button in row.get_children():
			if not button is HUD.HeroSlotButton or not is_instance_valid(button.hero) or not button.display_only:
				continue
			var rank: int = int(button.hero.ability_slots[button.slot]["rank"])
			button.hero.skill_points = 8
			button.hero.hero_level = 10
			_tap(button, Vector2(2, button.size.y - 2))
			var body_unchanged: bool = int(button.hero.ability_slots[button.slot]["rank"]) == rank
			_tap(button, button._learn_plus_center())
			var plus_learns: bool = int(button.hero.ability_slots[button.slot]["rank"]) == rank + 1
			if not body_unchanged or not plus_learns:
				failures.append({"id": "pure_passive_upgrade", "body_unchanged": body_unchanged, "plus_learns": plus_learns})
			tested = true
			break
		if tested: break
	if not tested:
		failures.append({"id": "pure_passive_upgrade", "reason": "fixture missing"})

func _tap(button: Control, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = true
	button._gui_input(event)
	event.pressed = false
	button._gui_input(event)

func _economy_language_samples() -> void:
	viewport.size = Vector2i(2560, 1440)
	viewport.size_2d_override = Vector2i(1280, 720)
	OS.set_environment("LIANGSHAN_HUD_SAFE_AREA_TEST", "2560,1440,48,16,2464,1408")
	battle.hud.set_touch_ui(true)
	battle.current_age = 1
	var workshop := battle.spawn_at("siege_workshop", Unit.FACTION_LIANG, Vector2i(22, 34))
	var worker: Unit = null
	var hall: Unit = null
	for unit in battle.units:
		if unit.is_worker and worker == null: worker = unit
		if unit.key == "hall": hall = unit
	workshop.set_process(false)
	workshop.set_physics_process(false)
	worker._carry_amt = 7.0
	worker._carry_kind = "gold"
	worker._state = Unit.ST_RETURN
	hall._train_queue.append("lou_luo")
	hall._train_t = 6.0
	for locale in ["zh_CN", "zh_TW", "en", "ja"]:
		Localize.set_language(locale, false)
		for sample in ["worker", "age_locked_train", "train_tooltip", "auto_aiming"]:
			Settings.auto_micro_level = 1 if sample == "auto_aiming" else 0
			battle._disarm_ability()
			for hero in battle.liang_heroes():
				hero.auto_micro = sample == "auto_aiming"
			battle.hud.hide_skill_tip(null)
			battle.hud._clear_info_toasts()
			battle.select_single(worker if sample == "worker" else workshop, false)
			if sample == "auto_aiming":
				var hero: Unit = battle.liang_heroes()[0]
				battle.select_single(hero, false)
				battle.cast_ability(hero, 1, true)
			battle.hud._refresh_resource_values()
			battle.hud._apply_safe_area()
			await _settle()
			if sample == "train_tooltip":
				for button in battle.hud._skill_bar.get_children():
					if button is HUD.CmdButton and String(button.spec.get("kind", "")) == "train":
						button._on_hover_in()
						break
				await _settle()
			var result: Dictionary = LayoutAudit.new().audit(battle.hud)
			result["id"] = "economy_" + locale + "_" + sample
			var resource_rect: Rect2 = battle.hud._res_bar.get_global_rect()
			var menu_rect: Rect2 = battle.hud._menu_btn.get_global_rect()
			if resource_rect.end.x > menu_rect.position.x - 8.0:
				result.ok = false
				result.failures.append({"name": "resource_bar_avoids_menu", "resource": str(resource_rect), "menu": str(menu_rect)})
			if sample == "train_tooltip" and not Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(battle.hud._tip_panel.get_global_rect()):
				result.ok = false
				result.failures.append({"name": "training_tooltip_in_viewport"})
			if graphical:
				result["screenshot"] = output.path_join(String(result.id) + ".png")
				if viewport.get_texture().get_image().save_png(result.screenshot) != OK: result.ok = false
			samples.append(result)
			if not result.ok: failures.append({"id": result.id, "failures": result.failures})
			print("[rts-touch-ui] ", result.id, " ", "PASS" if result.ok else JSON.stringify(result.failures))
