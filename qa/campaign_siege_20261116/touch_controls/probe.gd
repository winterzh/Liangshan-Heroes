extends "res://tools/zhujiazhuang_rts_test.gd"
## Uses the actual touch command handler in a desktop touch preview.
## Sun Li and the rescued party are placed in controlled starting states.

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	var b = await _start()
	var l = b.level
	var loc = root.get_node("Localize")
	check(b.hud.touch_ui,"desktop touch preview is enabled")
	for u in b.units: u.set_physics_process(false)
	var worker = l.workers[0]
	var mines: Array = b.units.filter(func(u): return u.key == "gold_mine" and b.map.world_to_cell(u.position) in l.CAMP_GOLD_CELLS \
		and b.is_visible_world(u.position) and not b._resource_blocked(u))
	mines.sort_custom(func(a,z): return a.res_left > z.res_left)
	var mine = mines.front()
	for u in l.workers:
		u.order_stop()
	l.activate_mission_button(b,"zhu_find_camp_gold")
	var mining_text: String = b.mission._feedback_text
	check(str(ceili(mine.res_left)) in mining_text and "轻点金矿采集" in mining_text and "0名工人" in mining_text, \
		"camp mine feedback reports actual assignments and the touch order")
	b.select_single(worker,false)
	b._tap_command(b.to_screen(mine.position),false)
	check(worker._gather_node == mine and worker._state == worker.ST_GATHER,"tapping the mine sends a normal gather order")

	l._introduce_sun(b)
	var contact: Vector2 = b.map.cell_to_world(l.INNER_CONTACT)
	l.sun.position = contact
	l.sun.order_hold_position()
	b.center_camera_cell(l.INNER_CONTACT)
	await process_frame
	var tap_prompts := {"zh_CN":"轻点接应旗标","zh_TW":"輕點接應旗標","en":"tap the rendezvous flag","ja":"旗をタップ"}
	var hints := {}
	for locale in tap_prompts:
		loc.set_language(locale,false)
		hints[locale] = l.unit_tactical_hint(b,l.sun)
		check(tap_prompts[locale] in hints[locale],"Sun Li's inspector identifies the touch flag in " + locale)
	loc.set_language("zh_CN",false)
	b.hud.set_touch_ui(false)
	check("右键接应标记" in l.unit_tactical_hint(b,l.sun),"desktop keeps the mouse guidance")
	b.hud.set_touch_ui(true)
	b.select_single(l.sun,false)
	check(b._friendly_at(b.to_screen(contact)) == l.sun,"the selected actor overlaps the flag")
	b._tap_command(b.to_screen(contact),false)
	check(l.sun.mission_order_token > 0 and l.sun.mission_order_target.distance_to(contact) < 1.0, \
		"tapping the overlapped flag issues a manual arrival order")
	await _wait(6.5)
	check(l.inside_open and b.mission.has_event("zhu_gate_opened"),"normal mission timing opens the side gate")

	l.on_mission_action(b,"zhu_rts_rescue",l.song)
	var before: Array = l.prisoners.map(func(u): return u._order_serial)
	l.activate_mission_button(b,"zhu_select_shi_qian")
	check(b.selection == [l.prisoners[0]] and "轻点前营地面" in b.mission._status.text,"evacuation control selects Shi Qian and gives the tap instruction")
	l.activate_mission_button(b,"zhu_select_rescued")
	check(b.selection.size() == 7 and b.selection == l.prisoners and b.selection.map(func(u): return u._order_serial) == before \
		and "轻点前营地面" in b.mission._status.text,"the full party can be selected without issuing movement")
	b.center_camera_cell(l.CAMP)
	await process_frame
	var ground := Vector2.ZERO
	for offset in [Vector2i(3,2),Vector2i(3,-2),Vector2i(-3,2),Vector2i(-3,-2)]:
		var p: Vector2 = b.to_screen(b.map.cell_to_world(l.CAMP + offset))
		if b._friendly_at(p) == null and b._enemy_at(p) == null and b._resource_at(p) == null:
			ground = p
			break
	check(ground != Vector2.ZERO,"forward camp includes open ground for the order")
	b._tap_command(ground,false)
	check(b.selection.size() == 7 and b.selection.all(func(u): return u._state == u.ST_MOVE) \
		and b.selection.map(func(u): return u._order_serial) != before,"tapping the ground sends actual movement orders to the seven evacuees")
	await _dispose(b)
	print("ZHU_TOUCH_CONTROLS_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks, \
		"failures":failures,"facts":{"mining":mining_text,"rendezvous":hints}}))
	if failures.is_empty():
		root.get_node("AppLifecycle").request_quit("zhu_touch_fixture")
	else:
		root.get_node("Sfx").shutdown()
		root.get_node("Music").shutdown()
		quit.call_deferred(1)
