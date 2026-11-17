extends "res://tools/kuaihuolin_short_test.gd"
## Player-triggered rescue and duel prompts, plus a bounded transport-locator fixture.

const TAP := {"zh_CN":"轻点","zh_TW":"輕點","en":"tap","ja":"タップ"}
const KICK := {"zh_CN":"鸳鸯脚","zh_TW":"鴛鴦腳","en":"Mandarin Duck Kick","ja":"鴛鴦脚"}
const BREATH := {"zh_CN":"稳住酒势","zh_TW":"穩住酒勢","en":"Steady Yourself","ja":"酔いを抑える"}
var facts := {}

func _run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false
	await _forest()
	if failures.is_empty(): await _carts()
	if failures.is_empty(): await _showdown()
	print("SHORT_CHAPTER_CONTROLS_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,
		"failures":failures,"facts":facts}))
	root.get_node("Sfx").shutdown()
	root.get_node("Music").shutdown()
	quit(0 if failures.is_empty() else 1)

func _forest() -> void:
	var b = await _start("",5)
	Engine.time_scale = 4
	var l = b.level
	_click(b,[l.lu],Vector2i(34,16))
	var opened := await _until(func(): return l.st == l.RESCUE or b.phase == b.Phase.END,30)
	check(opened and l.st == l.RESCUE,"north route opens the actual rescue action")
	var loc = root.get_node("Localize")
	var prompts := {}
	if failures.is_empty():
		for locale: String in TAP:
			loc.set_language(locale,false)
			l._update_help(b)
			prompts[locale] = {"intercept":b.mission._status.text}
			check(String(b.mission._status.text).contains(TAP[locale]),"forest interception teaches a tap / "+locale)
		loc.set_language("zh_CN",false)
		var marker: Vector2 = b.map.cell_to_world(b.mission.actions.intercept.cell)
		b.center_camera_cell(b.mission.actions.intercept.cell)
		var serial: int = l.lu._order_serial
		b._touch_tap_or_double(b.to_screen(marker),false)
		check(l.lu._order_serial > serial and l.lu.mission_order_token > 0,"touch input issues the real forest order")
		var rescued := await _until(func(): return l.st == l.ESCAPE or b.phase == b.Phase.END,20)
		check(rescued and l.st == l.ESCAPE,"the touch rescue transitions to actual four-person escort")
		if failures.is_empty():
			for locale: String in TAP:
				loc.set_language(locale,false)
				var guidance: String = l._escort_arrival_guidance(b,false)
				prompts[locale]["escort"] = guidance
				check(guidance.contains(TAP[locale]) and guidance.contains("/4"),"exit boarding prompt names the tap and actual roster / "+locale)
	facts["forest"] = prompts
	loc.set_language("zh_CN",false)
	await _dispose(b)

func _carts() -> void:
	var b = await _start("",0)
	b.set_physics_process(false)
	b.set_process(false)
	var l = b.level
	l._begin_force_route(b,"Transport locator fixture",false)
	l._sync_controls(b)
	var owner = b.find_unit("chao_gai")
	b.select_single(owner,false)
	var serial: int = owner._order_serial
	var button: Button = null
	for node in b.mission._buttons.get_children():
		if node.get_meta(b.mission.PRESENTATION_META,{}).get("button_id","") == "hg_transport_next":
			button = node
			break
	check(button != null and l._selected_transport_action(b) == "force_take_0_0","original cart has the real next-step button")
	if not failures.is_empty():
		await _dispose(b)
		return
	var loc = root.get_node("Localize")
	var prompts := {}
	for locale: String in TAP:
		loc.set_language(locale,false)
		button.pressed.emit()
		prompts[locale] = {"next":b.mission._status.text,"tooltip":button.tooltip_text}
		check(String(b.mission._status.text).contains(TAP[locale])
			and owner._order_serial == serial and b.selection == [owner],"cart locator describes a tap without ordering movement / "+locale)
	loc.set_language("zh_CN",false)
	b.hud.set_touch_ui(false)
	button.pressed.emit()
	check(String(b.mission._status.text).contains("右键") and owner._order_serial == serial,"same cart locator describes right-click on desktop")
	facts["carts"] = prompts
	facts["carts_desktop"] = b.mission._status.text
	await _dispose(b)

func _showdown() -> void:
	var b = await _start("",6)
	Engine.time_scale = 4
	var l = b.level
	check("玉环步" in b.mission.objective and "下令移动" in b.mission.objective,"road guidance describes skill plus movement order")
	_move(b,l.shi,b.map.cell_to_world(Vector2i(44,25)))
	_move(b,l.wu,b.map.cell_to_world(Vector2i(48,19)))
	var near := await _until(func(): return l.wu.position.distance_to(l.menshen.position)<155,40)
	check(near and l.st == l.ROAD,"walking to the inn preserves the choice of a direct duel")
	_attack(b)
	check(await _until(func(): return l.st == l.SHOWDOWN,8),"actual attack opens the duel")
	var windup := await _until(func(): return l.fist_windup > 0 or b.phase == b.Phase.END,12)
	check(windup and l.fist_windup > 0.0 and l.special_kind == "heavy","real heavy punch starts its windup")
	if failures.is_empty():
		await _cast(b,1)
		var line: Vector2 = l.menshen.position.direction_to(l.wu.position)
		_move(b,l.wu,l.fist_at + line.orthogonal()*110)
		var exposed := await _until(func(): return l.exposed_left > 0 or b.phase == b.Phase.END,8)
		check(exposed and l.exposed_left > 0 and l.heavy_dodges == 1,"real side-step opens a live counter window")
	if failures.is_empty():
		var loc = root.get_node("Localize")
		var prompts := {}
		for locale: String in KICK:
			loc.set_language(locale,false)
			l._duel_tick(b,0.0)
			var status: String = b.mission._status.text
			prompts[locale] = status
			check(status.contains(KICK[locale]) and status.contains(BREATH[locale]),
				"counter window names the actual skill buttons / "+locale)
		facts["counter"] = prompts
		facts["window_remaining"] = l.exposed_left
		loc.set_language("zh_CN",false)
	await _dispose(b)
