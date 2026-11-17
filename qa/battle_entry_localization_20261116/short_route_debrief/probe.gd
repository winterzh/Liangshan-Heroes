extends "res://tools/zhujiazhuang_rts_test.gd"
## Controlled route states rendered by three actual chapter and settlement scenes.

const LANGUAGES := ["zh_CN", "zh_TW", "ja", "en"]
var localization: Node
var catalog: Dictionary
var results := {}

func _run() -> void:
	var profile := OS.get_environment("APPDATA").replace("\\","/")
	if OS.get_environment("STEAM_DISABLED") != "1" or not profile.contains("/short-debrief-") \
			or not OS.get_user_data_dir().replace("\\","/").begins_with(profile + "/"):
		quit(2)
		return
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	localization = root.get_node("Localize")
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/catalog.json"))
	var flow = root.get_node("ContinueFlow")
	var deadline := Time.get_ticks_msec() + 60000
	while flow.busy() and flow.phase != flow.Phase.ERROR and Time.get_ticks_msec() < deadline:
		await process_frame
	check(flow.can_launch(),"campaign startup is ready")
	if failures.is_empty(): await _forest()
	if failures.is_empty(): await _tribute()
	if failures.is_empty(): await _duel()
	_finish()

func _chapter(index: int, id: String):
	localization.set_language("en",false)
	var b = await _start("",index)
	check(b.phase == b.Phase.FIGHT and b.level.id() == id,"live chapter " + id)
	b.set_process(false)
	b.set_physics_process(false)
	for unit in b.units:
		unit.set_physics_process(false)
	b._official_context.clear()
	return b

func _settle(b) -> void:
	b.phase = b.Phase.END
	b._complete_end(false,"")
	check(b.hud._end_root.visible,"actual settlement panel")

func _forest() -> void:
	var b = await _chapter(5,"level6")
	var level = b.level
	var rows: Array = level.campaign_debrief(b.mission)
	check(rows[0].args == ["未走暗护路线","未完成拦棍"],"forest starts before rescue")
	for route in {"north_pines":"北侧松林暗护","south_reeds":"南侧芦丛暗护","lost_trail":"跟丢后赶往大树"}:
		level.shadow_route = route
		rows = level.campaign_debrief(b.mission)
		check(rows[0].args[0] == {"north_pines":"北侧松林暗护","south_reeds":"南侧芦丛暗护","lost_trail":"跟丢后赶往大树"}[route],
			"forest distinguishes " + route)
	level._begin_open_rescue(b,"Controlled forest fixture")
	check(b.mission.has_event("yezhulin_early_force"),"actual early rescue handler")
	level.st = level.CARE
	level._finish_untie(b)
	level._finish_tending(b)
	check(is_instance_valid(level.lin_freed) and level.treated,"untie and tending handlers")
	level.lu.position = b.map.cell_to_world(level.EXIT_W)
	for member in level._escort_group():
		member.set_physics_process(false)
		if member != level.lu: member.position = b.map.cell_to_world(level.REST)
	_settle(b)
	level.treated = false
	level.rest_reached = true
	await _debrief(b,"yezhulin",[
		["救援 · %s · %s",["提前强救","未完成拦棍"]],
		["护送 · %s · %s",["已照料脚伤","尚未歇脚"]],
		["出林口 · %d/4 人到达",[1]],
	])
	await _dispose(b)

func _tribute() -> void:
	var b = await _chapter(0,"level1")
	var level = b.level
	var rows: Array = level.campaign_debrief(b.mission)
	check(rows[0].args == ["酒计尚未完成"] and rows[1].args == [0,0],"tribute starts without cargo")
	level.drug_done = true
	rows = level.campaign_debrief(b.mission)
	check(rows[0].args == ["酒计得手"],"wine success distinguished from force")
	level.drug_done = false
	level._begin_force_route(b,"Controlled force fixture",false)
	check(level.force_started and b.mission.has_event("huangnigang_force"),"actual force route handler")
	b.mission.mark("force_delivered_0","Controlled cargo fixture")
	level.delivered = 2
	var living: Array = level._living_companions()
	check(living.size() == 8,"eight companions available")
	for member in living:
		member.set_physics_process(false)
		member.position = b.map.cell_to_world(level.GATE_W) + Vector2(200,0)
	living[0].position = b.map.cell_to_world(level.GATE_W)
	_settle(b)
	level.delivered = 7
	living[1].position = b.map.cell_to_world(level.GATE_W)
	await _debrief(b,"huangnigang",[
		["夺纲 · %s",["转为强夺"]],
		["运出车货 · %d/7 车 · %d/11 担",[1,2]],
		["西冈口 · %d/8 人到达",[1]],
	])
	await _dispose(b)

func _duel() -> void:
	var b = await _chapter(6,"level7")
	var level = b.level
	var rows: Array = level.campaign_debrief(b.mission)
	check(rows[0].args == [0] and rows[2].args == ["尚未交还施恩"],"duel starts without preparation")
	for action in ["drink_0","drink_0","drink_1"]:
		level.on_mission_action(b,action,level.wu)
	check(level.drunk == 2,"actual drinking handler counts distinct taverns")
	level.counter_hits = 3
	b.mission.mark("mengzhou_signature","Controlled signature fixture")
	b.mission.mark("menshen_subdued","Controlled duel fixture")
	_settle(b)
	b.mission.mark("restore_shop","Controlled handover fixture")
	level.counter_hits = 4
	await _debrief(b,"kuaihuolin",[
		["酒望 · 饮酒 %d/4 处",[2]],
		["反击命中 %d 次 · %s",[3,"玉环步接鸳鸯脚命中"]],
		["酒店 · %s",["蒋门神已败，酒店尚未交还"]],
	])
	rows = level.campaign_debrief(b.mission)
	check(rows[2].args == ["已交还施恩"],"store reports completed handover")
	await _dispose(b)

func _text(key: String, language: String) -> String:
	return key if language == "zh_CN" else catalog[key][language]

func _debrief(b, key: String, expected: Array) -> void:
	var rows_by_language: Dictionary = {}
	var raw := JSON.stringify(b.mission.report)
	for language in LANGUAGES:
		localization._formatted_sources.clear()
		localization.set_language(language,false)
		await process_frame
		var rows: PackedStringArray = [_text("本局战果",language)]
		for row in expected:
			var args: Array = []
			for item in row[1]:
				args.append(_text(item,language) if item is String else item)
			rows.append(_text(row[0],language) % args)
		check("\n".join(rows) in b.hud._end_tally.text,"frozen "+key+" in "+language)
		rows_by_language[language] = rows
	check(JSON.stringify(b.mission.report) == raw,"debrief does not alter original log")
	results[key] = rows_by_language

func _finish() -> void:
	print("SHORT_DEBRIEF_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"results":results,
		"fixture":"real Yezhulin, Huangnigang and Kuaihuolin UI with controlled end states; no campaign progress"}))
	if failures.is_empty():
		root.get_node("AppLifecycle").request_quit("short_debrief_fixture")
	else:
		root.get_node("Sfx").shutdown()
		root.get_node("Music").shutdown()
		quit.call_deferred(1)
