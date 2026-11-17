extends "res://tools/zhujiazhuang_rts_test.gd"

var locale: Node
var catalog: Dictionary
var rendered: Dictionary = {}

func _run() -> void:
	if OS.get_environment("STEAM_DISABLED") != "1" or not OS.get_user_data_dir().contains("/daming-debrief-"):
		quit(2)
		return
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	locale = root.get_node("Localize")
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/catalog.json"))
	var flow = root.get_node("ContinueFlow")
	var deadline := Time.get_ticks_msec() + 60000
	while flow.busy() and flow.phase != flow.Phase.ERROR and Time.get_ticks_msec() < deadline:
		await process_frame
	check(flow.can_launch(),"campaign startup is ready")
	if failures.is_empty(): await _route(false)
	if failures.is_empty(): await _route(true)
	print("DAMING_DEBRIEF_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"rendered":rendered}))
	root.get_node("Sfx").shutdown()
	root.get_node("Music").shutdown()
	quit(0 if failures.is_empty() else 1)

func _route(assault: bool) -> void:
	locale.set_language("zh_CN",false)
	var b = await _start("",7)
	b.set_process(false)
	b.set_physics_process(false)
	b._official_context.clear()
	for unit in b.units:
		unit.set_physics_process(false)
	var l = b.level
	check(b.phase == b.Phase.FIGHT and l.id() == "level8","actual Daming battlefield")
	var original: Array = l.campaign_debrief(b.mission)
	check(original[0].args == ["未打开"] and original[1].args == ["未打开"] and original[2].args == ["追兵未出动"]
		and original[3].args == ["尚未解枷","尚未解枷"],"closed gates, idle pursuit and both chained in initial debrief")
	if not failures.is_empty():
		await _dispose(b)
		return
	l.signaled = not assault
	l.signal_left = 90.0 if l.signaled else 0.0
	l._open_prison(b,assault)
	if assault:
		l.gate.take_damage(100000.0,l.strategist,false,true)
	else:
		l._open_gate(b,false)
	for unit in b.units:
		if unit.faction == 1 and not unit.is_building:
			unit.position = b.map.cell_to_world(l.ENEMY_HQ)
	b._grid_build()
	l.on_mission_action(b,"daming_rescue",l.strategist)
	check(l.rescued and l.gate_open and l.prison_open,"real prison, gate and unchaining callbacks")
	var freed: Array = l.campaign_debrief(b.mission)
	check(freed[3].args == ["尚未撤出","尚未撤出"],"unchained is distinct from safe")
	if not assault:
		for soldier in l.pursuit.duplicate():
			soldier.take_damage(100000.0,l.strategist,false,true)
		await process_frame
	l.lu.position = b.map.cell_to_world(l.EXIT_CELL)
	if assault:
		l._update_pursuit(b)
		l.pursuit_t = 0.25
		l._update_pursuit(b)
		check(l.pursuit_sent and b.mission.has_event("daming_pursuit"),"original pursuit units receive their orders")
	l.strategy_t = 0.0
	l.process(b,0.0)
	check(b.mission.has_event("daming_lu_safe") and not b.mission.has_event("daming_shi_safe"),"first evacuee has an independent arrival event")
	var before := _profile_sha()
	if assault:
		l.shi.take_damage(100000.0,l.pursuit[0],false,true)
	else:
		l.shi.position = b.map.cell_to_world(l.EXIT_CELL)
		l.strategy_t = 0.0
		l.process(b,0.0)
	await process_frame
	check(b.phase == b.Phase.END and b.hud._end_root.visible,"real victory or loss invokes the debrief")
	var expected: Array = [
		["南门 · %s", ["强攻破门" if assault else "火号接应夺门"]],
		["牢院 · %s", ["外军强开牢院" if assault else "乔装受验入牢"]],
		["留守追兵 · %s", ["追兵已出动" if assault else "出动前被击退"]],
		["撤离 · 卢俊义 %s · 石秀 %s", ["已撤离", "阵亡" if assault else "已撤离"]],
	]
	var samples: Dictionary = {}
	l.pursuit_sent = not l.pursuit_sent
	var raw_report := JSON.stringify(b.mission.report)
	for language in ["en","ja","zh_TW","zh_CN"]:
		locale._formatted_sources.clear()
		locale.set_language(language,false)
		await process_frame
		var rows: PackedStringArray = [_text("本局战果",language)]
		for item in expected:
			rows.append(_text(item[0],language) % item[1].map(func(key): return _text(key,language)))
		check("\n".join(rows) in b.hud._end_tally.text,"frozen %s result in %s" % ["assault loss" if assault else "signal victory",language])
		samples[language] = rows
	check(before == _profile_sha() and JSON.stringify(b.mission.report)==raw_report,"route fixture leaves progress and prior report alone")
	rendered["assault_loss" if assault else "signal_victory"] = samples
	await _dispose(b)

func _text(source: String, language: String) -> String:
	return source if language == "zh_CN" else String(catalog[source][language])

func _profile_sha() -> String:
	return FileAccess.get_sha256("user://campaign.cfg") if FileAccess.file_exists("user://campaign.cfg") else ""
