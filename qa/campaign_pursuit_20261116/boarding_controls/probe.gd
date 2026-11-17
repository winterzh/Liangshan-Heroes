extends "res://tools/zhujiazhuang_rts_test.gd"
## Focused threat and touch fixture in the real Jiangzhou scene.

func _run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false
	var facts := {}
	var b = await _start("",1)
	b.set_process(false)
	b.set_physics_process(false)
	var l = b.level
	for u in b.units: u.set_physics_process(false)
	check(b.hud.touch_ui and b._allow_touch,"Jiangzhou starts in the touch layout")
	for guard in l.executioners: guard.resolve_story("subdued")
	l.process(b,0)
	check(l.execution_halted and "轻点" in b.mission.objective
		and b.mission.actions.has("free_song") and b.mission.actions.has("free_dai"),"halted execution teaches both touch release actions")
	l._free(b,true)
	l._free(b,false)
	if not failures.is_empty():
		_finish(facts)
		return
	var song = l.song_freed
	var dai = l.dai_freed
	song.set_physics_process(false)
	dai.set_physics_process(false)
	var flag: Vector2i = b.mission.actions.board_song.cell
	var dock: Vector2 = b.map.cell_to_world(flag)
	song.position = dock
	var watch = l.city_guards[0]
	var threat_cell: Vector2i = b.map.nearest_open(flag+Vector2i(3,-2),"land")
	for u in b.units:
		if u.faction == 1 and not u.is_building:
			u.position = b.map.cell_to_world(l.CITY_POST)
	watch.position = b.map.cell_to_world(threat_cell)
	facts["threat_distance"] = watch.position.distance_to(dock)
	check(l._enemy_near(b,dock,l.BOARDING_THREAT_RADIUS),"an actual guard is inside the boarding radius")
	if not failures.is_empty():
		_finish(facts)
		return
	b._grid_build()
	b.fog = false
	var loc = root.get_node("Localize")
	var expected := {"zh_CN":"附近有官军","zh_TW":"附近有官軍","en":"troops are near","ja":"近くに官軍"}
	var hints := {}
	for locale: String in expected:
		loc.set_language(locale,false)
		b.select_single(song,false)
		b._update_sel_label()
		var hint: String = l.unit_tactical_hint(b,song)
		hints[locale] = hint
		check(hint.contains(expected[locale]) and b.hud._info_stats.text.contains(hint),
			"selected passenger exposes visible boarding danger in "+locale)
	facts["visible_threat"] = hints
	loc.set_language("zh_CN",false)
	check(l.unit_tactical_hint(b,l.named_units.chao_gai).is_empty(),"normal combat allies have no boarding warning")
	b.fog = true
	b._sight_now.fill(0)
	b._reveal_t.fill(0.0)
	check(not b.is_visible_world(watch.position)
		and l._enemy_near(b,song.position,l.BOARDING_THREAT_RADIUS)
		and "轻点" in l.unit_tactical_hint(b,song),"unseen guards still block boarding but are not exposed through the inspector")
	b.fog = false
	b.center_camera_cell(flag)
	b.select_single(song,false)
	b._tap_command(b.to_screen(dock),false)
	b.mission.tick(1.6)
	check(song.story_outcome == "" and not b.mission.actions.board_song.done
		and "再下达登船指令" in b.mission._status.text,"a blocked boarding order retains the passenger and explains how to retry")
	facts["retry"]=b.mission._status.text

	watch.position=b.map.cell_to_world(l.CITY_POST)
	b._grid_build()
	b.mission.tick(2.0)
	check(song.story_outcome == "" and "轻点" in l.unit_tactical_hint(b,song),"clearing the landing does not auto-board")
	b._tap_command(b.to_screen(dock),false)
	b.mission.tick(1.6)
	check(song.story_outcome == "embarked" and b.mission.has_event("board_song")
		and l.unit_tactical_hint(b,song).is_empty(),
		"one fresh tap boards Song and removes his boarding hint")
	b.hud.set_touch_ui(false)
	check("右键" in l.unit_tactical_hint(b,dai) and dai.story_outcome == "",
		"the other passenger retains his own order and desktop right-click prompt")
	facts["song_boarded"]=song.story_outcome
	facts["dai_desktop"]=l.unit_tactical_hint(b,dai)
	await _dispose(b)
	_finish(facts)

func _finish(facts: Dictionary) -> void:
	print("JIANG_BOARDING_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,
		"failures":failures,"facts":facts}))
	root.get_node("Sfx").shutdown()
	root.get_node("Music").shutdown()
	quit(0 if failures.is_empty() else 1)
