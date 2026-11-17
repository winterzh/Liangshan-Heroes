extends "res://tools/yezhulin_short_test.gd"
## Use real north-route movement and finish the normal intercept through the touch tap handler.

func _run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false
	var facts := {}
	var b = await _start("",5)
	var l = b.level
	var m = b.mission
	Engine.time_scale = 4
	check(b.hud.touch_ui and b._allow_touch,"battle starts in the enabled touch layout")
	_click(b,[l.lu],Vector2i(34,16))
	var opened := await _until(func(): return l.st == l.RESCUE or b.phase == b.Phase.END,30)
	check(opened and l.st == l.RESCUE and m.actions.has("intercept"),"north route reaches the real hidden intercept flag")
	if not failures.is_empty():
		_finish(facts)
		return
	var localize = root.get_node("Localize")
	var expected := {"zh_CN":"轻点","zh_TW":"輕點","en":"tap","ja":"タップ"}
	var action: Dictionary = m.actions.intercept
	var marker: Vector2 = b.map.cell_to_world(action.cell)
	var serial: int = l.lu._order_serial
	facts["touch"] = {}
	for locale: String in expected:
		localize.set_language(locale,false)
		var symbol: String = expected[locale]
		var style := " / " + locale
		check(m.focus_action("intercept") and m._status.text.contains(symbol),
			"locate describes a tap, with the required actor and dwell time"+style)
		var focus_status: String = m._status.text
		m.prepare_manual_move([],marker)
		check(m._status.text.contains(symbol),"wrong selection feedback describes a tap"+style)
		facts.touch[locale] = {"focus":focus_status,"wrong_selection":m._status.text}
		check(b.selection == [l.lu] and l.lu._order_serial == serial and m.active_action_id == "",
			"locating the task keeps the player in control"+style)
	localize.set_language("zh_CN",false)
	# Exercise the actor-locator construction and its actual button callback.
	m.add_actor_locator("intercept","lu_zhishen")
	var actor_button: Button = action.actor_button
	actor_button.pressed.emit()
	check(m._status.text.contains("轻点") and b.selection == [l.lu] and l.lu._order_serial == serial,
		"the actor locator selects and points at the correct touch flag without ordering movement")
	facts["actor_locator"] = {"tip":actor_button.tooltip_text,"status":m._status.text}
	check(not actor_button.tooltip_text.contains("右键"),"the actor locator tooltip applies to either input method")

	b.hud.set_touch_ui(false)
	m.focus_action("intercept")
	check(m._status.text.contains("右键"),"the desktop task locator still describes right-click")
	facts["desktop"] = m._status.text
	b.hud.set_touch_ui(true)
	m.focus_action("intercept")
	var tapped: Vector2 = b.to_screen(marker)
	var under_flag = b._friendly_at(tapped)
	facts["under_flag"] = {"actor":under_flag.key,"captive":under_flag.is_captive} if under_flag != null else {}
	check(under_flag != null and (under_flag.is_captive or under_flag == l.lu),
		"the real intercept flag overlaps a friendly target")
	b._touch_tap_or_double(tapped,false)
	check(l.lu.mission_order_token > 0 and l.lu._order_serial > serial,
		"the touch handler stamps an actual manual mission order")
	var finished := await _until(func(): return m.has_event("intercept") or b.phase == b.Phase.END,28)
	check(finished and m.has_event("intercept") and l.rescued,"the tap completes the actual staff intercept")
	facts["intercept"] = m.has_event("intercept")
	facts["clock"] = m.total_game_seconds
	# The actual chapter action above is complete. Exercise the shared initial prompts separately.
	m.begin("touch_copy_fixture","任务提示","任务提示")
	check(m._status.text.contains("轻点"),"a new touch stage explains how to use a flag")
	m.add_action("touch_copy_fixture","任务提示",action.cell,["lu_zhishen"],1.0,40.0,48.0,false)
	check(m._status.text.contains("轻点"),"a flag without a viewport locator still explains how to tap")
	_finish(facts)

func _finish(facts: Dictionary) -> void:
	print("TOUCH_MISSION_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"facts":facts}))
	root.get_node("Sfx").shutdown()
	root.get_node("Music").shutdown()
	quit(0 if failures.is_empty() else 1)
