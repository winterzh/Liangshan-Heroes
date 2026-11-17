extends "res://tools/zhujiazhuang_rts_test.gd"
## Controlled timing fixture for both cavalry lanes, not a combat playthrough.

func _run() -> void:
	var area := OS.get_environment("APPDATA").replace("\\","/")
	if OS.get_environment("STEAM_DISABLED") != "1" or not area.contains("/lian-notices-") \
			or not OS.get_user_data_dir().replace("\\","/").begins_with(area + "/"):
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	var locale = root.get_node("Localize")
	locale.set_language("en",false)
	var flow = root.get_node("ContinueFlow")
	var deadline := Time.get_ticks_msec() + 60000
	while flow.busy() and flow.phase != flow.Phase.ERROR and Time.get_ticks_msec() < deadline:
		await process_frame
	check(flow.can_launch(),"campaign startup is ready")
	if not failures.is_empty():
		_finish({})
		return
	var b = await _start("",3)
	var level = b.level
	check(b.phase == b.Phase.FIGHT and level.id() == "level4","actual cavalry battle and HUD")
	if not failures.is_empty():
		_finish({})
		return
	for lane in range(2):
		level.elapsed = float(level.waves[lane].time) - 25.0
		level.strategy_t = 0.0
		level.process(b,0.0)
		check(level.waves[lane].warned and not level.waves[lane].sent,"warned lane %d before dispatch" % lane)
		level.elapsed = float(level.waves[lane].time)
		level.strategy_t = 0.0
		level.process(b,0.0)
		check(level.waves[lane].sent,"dispatched lane %d" % lane)
		level.on_unit_died(b,level.posts[lane])
		check(b.mission.has_event("lhm_supply_%d" % lane),"logged supply loss in lane %d" % lane)
	var notices: Array[String] = []
	notices.assign(level.LANE_WARNING + level.LANE_CHARGE + level.LANE_SUPPLY_LOST)
	var raw: Array = b.hud._message_log.map(func(row): return row.text)
	check(notices.all(func(source): return raw.count(source) == 1),"HUD log keeps one unformatted catalogue key per notice in English")
	check(level.LANE_SUPPLY_LOST.all(func(source): return source in b.mission.report),
		"both supply reports retain their source keys")
	var report_bytes := JSON.stringify(b.mission.report)
	locale._formatted_sources.clear()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/catalog.json"))
	var seen := {}
	for language in ["zh_CN","zh_TW","ja","en"]:
		check(locale.set_language(language,false),"switched to " + language)
		var report_rows: Array = JSON.parse_string(report_bytes)
		var result: Dictionary = b.mission.result_snapshot(false)
		var end_report: String = b._end_report_text(result,report_rows,{"track_combat":false,"kills":{},"combat":{}},true)
		var expected: Array[String] = []
		for source in notices:
			var target: String = source if language == "zh_CN" else catalog[source][language]
			expected.append(target)
			check(target in b.hud._info_log.text,"battle log in %s: %s" % [language,source.left(6)])
		for source in level.LANE_SUPPLY_LOST:
			var target: String = source if language == "zh_CN" else catalog[source][language]
			check(target in end_report,"debrief in %s: %s" % [language,source.left(6)])
		seen[language] = expected
	check(JSON.stringify(b.mission.report) == report_bytes,"language changes leave original report rows intact")
	_finish(seen)

func _finish(messages: Dictionary) -> void:
	print("LIAN_NOTICES_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"messages":messages,
		"fixture":"battle opened, wave clock advanced and supply-loss callbacks invoked; no combat or save roundtrip"}))
	if failures.is_empty():
		root.get_node("AppLifecycle").request_quit("lian_notice_fixture")
	else:
		root.get_node("Sfx").shutdown()
		root.get_node("Music").shutdown()
		quit.call_deferred(1)
