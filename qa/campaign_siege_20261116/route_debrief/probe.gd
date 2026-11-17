extends "res://tools/zhujiazhuang_rts_test.gd"

var snapshots: Dictionary = {}

func _run() -> void:
	if OS.get_environment("STEAM_DISABLED") != "1" or not OS.get_user_data_dir().contains("/zhu-debrief-"):
		quit(2)
		return
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	var flow = root.get_node("ContinueFlow")
	var deadline := Time.get_ticks_msec() + 60000
	while flow.busy() and flow.phase != flow.Phase.ERROR and Time.get_ticks_msec() < deadline:
		await process_frame
	var b = await _start()
	b.set_process(false)
	b.set_physics_process(false)
	for unit in b.units: unit.set_physics_process(false)
	var level = b.level
	var localize = root.get_node("Localize")
	check(b.phase == b.Phase.FIGHT and level.id() == "level3", "actual Zhujiazhuang battlefield")
	if not failures.is_empty():
		print("PHASE ", b.phase, " LEVEL ", level.id(), " FAULT ", b.gameplay_rng_fault())
		quit(1)
		return
	check(load("res://scripts/level_base.gd").new().campaign_debrief(null).is_empty(),"other levels default to the existing report")
	var initial: Array = level.campaign_debrief(b.mission)
	check(initial[0].args == ["未夺下"] and initial[1].args == ["外营未拆",0]
		and initial[2].args == ["正门未破","偏门未开"], "no route is credited before its event")
	var gates = [level.gate,level.side_gate]
	gates[0].take_damage(100000.0,level.song,false,true)
	await process_frame
	var frontal: Array = level.campaign_debrief(b.mission)
	check(frontal[2].args == ["正门已攻破","偏门未开"],"actual main gate death records frontal assault")
	gates[1].take_damage(100000.0,level.song,false,true)
	await process_frame
	var flanked: Array = level.campaign_debrief(b.mission)
	check(flanked[2].args == ["正门已攻破","偏门由强攻打开"],"a forced side gate is distinct from infiltration")
	level.raids_sent = 3
	level.outpost.take_damage(100000.0,level.song,false,true)
	await process_frame
	level.expansion_secured = true
	var combined: Array = level.campaign_debrief(b.mission)
	check(combined[0].args == ["已夺下"] and combined[1].args == ["已断援",3],"outpost death and stored raid count retain prior activity")
	# Inject the other validated route signal to exercise the separate report state.
	b.mission.events.erase("zhu_side_breached")
	level.inside_open = true
	var rows_before := JSON.stringify(b.mission.report)
	var profile := FileAccess.get_sha256("user://campaign.cfg") if FileAccess.file_exists("user://campaign.cfg") else ""
	b._official_context.clear()
	b.phase = b.Phase.END
	b._complete_end(false,"")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/catalog.json"))
	var expected_rows: Array = [
		["北矿 · %s",["已夺下"]],
		["南营 · %s · 共派出 %d 队",["已断援",3]],
		["入口 · %s · %s",["正门已攻破","孙立已打开偏门"]],
	]
	# Frozen settlement must never consult gameplay or its prior format history after a locale switch.
	level.raids_sent = 55
	level.inside_open = false
	level.main_breached = false
	for language in ["en","ja","zh_TW","zh_CN"]:
		localize._formatted_sources.clear()
		localize.set_language(language,false)
		await process_frame
		var report: String = b.hud._end_tally.text
		var heading := _translated(catalog,"本局战果",language)
		var expected: PackedStringArray = []
		for row in expected_rows:
			var format := _translated(catalog,row[0],language)
			var args: Array = []
			for item in row[1]:
				args.append(_translated(catalog,item,language) if item is String else item)
			expected.append(format % args)
		check(b.hud._end_root.visible and heading+"\n"+"\n".join(expected) in report, "actual frozen settlement in "+language)
		snapshots[language] = [heading,expected]
	check(JSON.stringify(b.mission.report) == rows_before, "settlement leaves event log intact")
	check(profile == (FileAccess.get_sha256("user://campaign.cfg") if FileAccess.file_exists("user://campaign.cfg") else ""), "fixture did not change campaign progress")
	b.queue_free()
	await process_frame
	print("ZHU_DEBRIEF_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"settlement_rows":snapshots}))
	root.get_node("AppLifecycle").request_quit("zhu_debrief_probe")
	if not failures.is_empty(): quit(1)

func _translated(catalog: Dictionary, source: String, language: String) -> String:
	return source if language == "zh_CN" else String(catalog[source][language])
