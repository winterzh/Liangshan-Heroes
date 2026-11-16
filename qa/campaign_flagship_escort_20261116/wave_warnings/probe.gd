extends "res://tools/gao_rts_play.gd"

const CONTEXT := {"level_id":"level5","content_version":"fixture:gao-wave-warnings:v1","mission_token":"mission:gao:warnings","presentation_token":"presentation:gao:warnings"}
const TEXTS := [
	"第一批约25秒后出发。岸军守东山关，留战船和岸弓互相支援。",
	"第二批约25秒后出发。可备火并集结两艘接应船，或用普通战船迎敌。",
	"第二批约25秒后出发。让普通战船接应内港，岸军继续守东山关。",
	"第三批约25秒后出发。步军留守东山关，舰队看清座船与护船的位置再接战。",
	"第三批约25秒后出发。座船已停，守住水陆通路，准备击退余部。",
]
const LOCATOR_LABELS := ["东山关防线","内港接战线"]
var observed: Array = []
var locations := {}

func _message_count(b, source: String) -> int:
	var total := 0
	for row in b.hud._message_log:
		if row.text == source:
			total += int(row.count)
	return total

func _toast_label(b, source: String) -> Label:
	for row in b.hud.msg_box.get_children():
		if row.get_meta("info_text","") == source:
			return row.get_node("Text") as Label
	return null

func _trigger(b, wave: int, source: String, enabled := true) -> bool:
	var l = b.level
	for index in range(l.waves.size()):
		l.waves[index].sent = index < wave
		l.waves[index].warned = index < wave
	var before := _message_count(b,source)
	l.elapsed = l.waves[wave].time - 25.25
	l.strategy_t = 0.0
	l.process(b,0.10)
	var not_early: bool = not l.waves[wave].warned and _message_count(b,source)==before
	l.strategy_t = 0.0
	l.process(b,0.20)
	var on_time: bool = l.waves[wave].warned and not l.waves[wave].sent 		and _message_count(b,source)==before + int(enabled)
	l.strategy_t = 0.0
	l.process(b,0.25)
	var once: bool = not l.waves[wave].sent and _message_count(b,source)==before + int(enabled)
	observed.append({"wave":wave+1,"expected":source,"enabled":enabled,
		"no_early_warning":not_early,"scheduled_at_25_seconds":on_time,"single_message":once})
	return not_early and on_time and once

func _verify_locales(b, source: String, catalog: Dictionary) -> bool:
	var toast := _toast_label(b, source)
	if toast == null:
		return false
	for locale in ["zh_CN","zh_TW","en","ja"]:
		root.get_node("Localize").set_language(locale,false)
		var expected: String = source if locale=="zh_CN" else catalog[source][locale]
		if toast.text != expected:
			return false
	root.get_node("Localize").set_language("zh_CN",false)
	return true

func _verify_locators(b, catalog: Dictionary) -> void:
	var locators := {}
	for child in b.mission._buttons.get_children():
		var descriptor: Dictionary = child.get_meta(&"campaign_presentation_v1",{})
		if descriptor.get("kind","")=="map" and descriptor.label in LOCATOR_LABELS:
			locators[descriptor.label] = child
	check(locators.size()==2,"both authored defense and harbor locators are present")
	if locators.size()!=2:
		return
	var selected = b.find_unit("ruan_xiaoqi_boat")
	b.select_single(selected,false)
	var before: Array = b.units.map(func(u): return u._order_serial)
	for index in range(2):
		var key: String = LOCATOR_LABELS[index]
		var button: Button = locators[key]
		var expected: Vector2i = b.level.LAND_FRONT if index==0 else b.level.SEA_FRONT
		var descriptor: Dictionary = button.get_meta(&"campaign_presentation_v1")
		button.pressed.emit()
		var target: Vector2 = b.to_screen(b.map.cell_to_world(expected))
		var localized := true
		for locale in ["zh_CN","zh_TW","en","ja"]:
			root.get_node("Localize").set_language(locale,false)
			var display: String = key if locale=="zh_CN" else catalog[key][locale]
			localized = localized and display in button.text
		root.get_node("Localize").set_language("zh_CN",false)
		locations[key] = {"cell":[descriptor.cell.x,descriptor.cell.y],"camera_error":b.camera.position.distance_to(target),
			"four_locales":localized}
		check(descriptor.cell==expected and b.camera.position.is_equal_approx(target) and localized,
			"locator centers the camera and displays in all four languages")
	check(b.selection==[selected] and before==b.units.map(func(u): return u._order_serial),
		"real locator buttons issue no unit order or selection change")
	await process_frame
	var presentation: Script = load("res://scripts/run_campaign_presentation_state.gd")
	var component = presentation.new()
	var captured: Dictionary = component.capture(b.mission, CONTEXT)
	var validated: Dictionary = component.validate(captured.record, CONTEXT) if captured.get("ok",false) else captured
	if not validated.get("ok",false):
		print("GAO_PREVIEW_CAPTURE ",JSON.stringify(validated))
	var captured_labels := []
	if validated.get("ok",false):
		for row in validated.value.buttons:
			if row.descriptor.get("kind","")=="map":
				captured_labels.append(row.descriptor.label)
	check(validated.get("ok",false) and LOCATOR_LABELS.all(func(key): return key in captured_labels),
		"both normal locator descriptors can be captured by the campaign presentation component")

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	root.size=Vector2i(960,540)
	root.content_scale_size=root.size
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/gao_wave_warnings.json"))
	var b = await _start("",4)
	b.set_process(false)
	b.set_physics_process(false)
	b.camera.set_process(false)
	for unit in b.units:
		unit.set_physics_process(false)
	await _verify_locators(b,catalog)
	check(_trigger(b,0,TEXTS[0]) and _verify_locales(b,TEXTS[0],catalog),"first warning fires once with shore-and-fleet advice in four locales")
	check(_trigger(b,1,TEXTS[1]) and _verify_locales(b,TEXTS[1],catalog),"eligible second wave offers fire or regular ships in four locales")
	b.level._fire_unavailable(b,"fixture loss")
	check(_trigger(b,1,TEXTS[2]) and _verify_locales(b,TEXTS[2],catalog),"second wave switches to regular ships once the optional route is lost")
	check(_trigger(b,2,TEXTS[3]) and _verify_locales(b,TEXTS[3],catalog),"third wave explains how to engage an active flagship in four locales")
	b.level.flagship_disabled = true
	b.level.flagship.story_outcome = "subdued"
	check(_trigger(b,2,TEXTS[4]) and _verify_locales(b,TEXTS[4],catalog),"third wave focuses on remaining troops if flagship is already disabled")
	var l=b.level
	for unit in l.water_groups[2]+l.land_groups[2]:
		unit.story_outcome = "retreated"
	check(_trigger(b,2,TEXTS[4],false),"no additional warning when the entire next force was cleared early")
	root.get_node("Localize").set_language("en",false)
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	print("GAO_WAVE_WARNINGS_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,
		"warning_triggers":observed,"locators":locations,"rendered_size":[root.size.x,root.size.y],
		"scope":"existing scheduled warning and actual locator/translation bindings with a frozen battle fixture"}))
	# Allow the production background art queue to finish before a fixture
	# that jumped the timers hands control back to the normal return path.
	await create_timer(3.0,true,false,true).timeout
	b.hud.to_menu.emit()
	await scene_changed
	for index in range(4):
		await process_frame
	if failures.is_empty():
		root.get_node("AppLifecycle").request_quit("gao_wave_warning_fixture")
	else:
		quit(1)
