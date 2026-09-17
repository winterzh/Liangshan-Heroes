extends "res://tools/localization_qa.gd"
## Exercise non-campaign HUDs, every ability tooltip, and a full settlement panel.

func _run() -> void:
	await get_tree().process_frame
	var tooltip_sizes: Array = []
	for mode in ["arena", "defense", "skirmish"]:
		Campaign.arena = mode == "arena"
		Campaign.skirmish = mode == "defense"
		Campaign.skirmish_ai = mode == "skirmish"
		Campaign.scenario = false
		Campaign.custom_defense = false
		var battle: Node2D = load("res://scenes/main.tscn").instantiate()
		get_tree().root.add_child(battle)
		get_tree().current_scene = battle
		battle.camera.set_process(false)
		battle.camera.set_physics_process(false)
		await _capture(mode + "_intro")
		while battle.hud._intro_root.visible:
			battle.hud._advance_intro()
		battle._on_start_battle()
		for unit in battle.units:
			if unit.faction == Unit.FACTION_LIANG and unit.key == "hall":
				battle.select_single(unit, false)
				break
		await _capture(mode + "_hall")
		if mode == "arena":
			var max_height := 0.0
			var longest := ""
			for aid in Defs.ABILITIES:
				var a: Dictionary = Defs.ABILITIES[aid]
				battle.hud.show_skill_tip(self, Rect2(1020, 620, 72, 64), Localize.text(a.name), Defs.ability_desc(aid, 3), Defs.ability_levels(aid), UITheme.PAPER)
				for frame in range(3):
					await get_tree().process_frame
				var rect: Rect2 = battle.hud._tip_panel.get_global_rect()
				tooltip_sizes.append({"key": aid, "rect": str(rect)})
				check(get_viewport().get_visible_rect().encloses(rect), "complete ability tooltip fits: " + aid)
				if rect.size.y > max_height:
					max_height = rect.size.y
					longest = aid
			if longest != "":
				battle.hud.show_skill_tip(self, Rect2(1020, 620, 72, 64), Localize.text(Defs.ABILITIES[longest].name), Defs.ability_desc(longest, 3), Defs.ability_levels(longest), UITheme.PAPER)
				await _capture("longest_tooltip")
			battle.hud.hide_skill_tip(null)
		var tally := ""
		for key in ["wu_song", "lu_zhishen", "huangfu_duan", "hu_yanzhuo", "shan_tinggui", "song_jiang"]:
			tally += Localize.text(String(Defs.UNITS[key].name)) + " · 1234\n" + Localize.text(String(Defs.ABILITIES[Defs.UNITS[key].abilities[0]].name)) + " · 1234\n\n"
		battle.hud.show_end(true, Localize.text("梁山以正面强攻与局部钩镰合战击溃十二骑，官军主阵已经解除。韩滔与呼延灼的具体结局及钩马章法，按本局演义印另行结算。"), 1234, true, tally, {"story_total": 4, "story_done": 2, "goals": [{"state": "missed", "label": Localize.text("守住忠义堂，击退一波波官军围剿")}]})
		await _capture(mode + "_settlement")
		check(get_viewport().get_visible_rect().encloses(battle.hud._end_next.get_global_rect()), "settlement navigation fits: " + mode)
		for button in battle.hud._end_next.get_parent().get_children():
			check(get_viewport().get_visible_rect().encloses(button.get_global_rect()), "settlement button fits: " + mode + ": " + button.text)
		check(battle.hud._end_sub.get_global_rect().end.x <= get_viewport().get_visible_rect().end.x, "settlement summary wraps: " + mode)
		get_tree().current_scene = null
		get_tree().root.remove_child(battle)
		battle.free()
		await get_tree().process_frame
	var f := FileAccess.open(OS.get_environment("LSH_QA_CAPTURE_DIR").path_join("tooltip_sizes.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(tooltip_sizes, "\t"))
	_finish()
