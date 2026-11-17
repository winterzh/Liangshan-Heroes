extends "res://tools/zhujiazhuang_rts_test.gd"

var rendered: Dictionary = {}

func _run() -> void:
	if OS.get_environment("STEAM_DISABLED") != "1" or not OS.get_user_data_dir().contains("/lian-debrief-"):
		quit(2)
		return
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	var flow = root.get_node("ContinueFlow")
	var deadline := Time.get_ticks_msec() + 60000
	while flow.busy() and flow.phase != flow.Phase.ERROR and Time.get_ticks_msec() < deadline:
		await process_frame
	var b = await _start("",3)
	b.set_process(false)
	b.set_physics_process(false)
	for unit in b.units: unit.set_physics_process(false)
	var l = b.level
	var localize = root.get_node("Localize")
	check(b.phase == b.Phase.FIGHT and l.id() == "level4","actual Lianhuanma battlefield")
	var original: Array = l.campaign_debrief(b.mission)
	check(original[0].args == ["北路",6,"未出击"] and original[1].args == ["南路",6,"未出击"],
		"both initial groups contain six riders and neither has charged")
	check(original[0].source.ends_with("辎重营仍在") and original[2].args == [0,"未擒获韩滔"],
		"untouched supply and generals are shown accurately")
	if not failures.is_empty():
		quit(1)
		return
	# Drive the real wave/death callbacks in a controlled mixed-outcome battle.
	l._send_wave(b,1)
	l.posts[0].take_damage(100000.0,l.song,false,true)
	l.posts[1].take_damage(100000.0,l.song,false,true)
	l.riders[0].set_meta("formation_broken",true)
	l.riders[6].set_meta("formation_broken",true)
	l.broken_count = 2
	l.riders[0].take_damage(100000.0,l.song,false,true)
	l.riders[6].take_damage(100000.0,l.song,false,true)
	l.han.resolve_story("captured")
	await process_frame
	var result: Array = l.campaign_debrief(b.mission)
	check(result[0].args == ["北路",5,"未出击",45] and result[0].source.ends_with("断援使冲锋推迟 %d 秒"),
		"northern pre-charge cut keeps five and schedules a 45-second delay")
	check(result[1].args == ["南路",5,"已出击"] and result[1].source.ends_with("出击后断援"),
		"southern post-charge cut keeps five with no delay")
	check(result[2].args == [2,"韩滔已被生擒"], "stored hook count and actual capture event")
	var baseline_log := JSON.stringify(b.mission.report)
	var profile := _profile_sha()
	b._official_context.clear()
	b.phase = b.Phase.END
	b._complete_end(false,"")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/catalog.json"))
	l.broken_count = 9
	l.waves[0].sent = true
	b.mission.events.erase("lhm_han_captured")
	for language in ["en","ja","zh_TW","zh_CN"]:
		localize._formatted_sources.clear()
		localize.set_language(language,false)
		await process_frame
		var lines: PackedStringArray = [_text(catalog,"本局战果",language)]
		for row in result:
			var args: Array = []
			for item in row.args:
				args.append(_text(catalog,item,language) if item is String else item)
			lines.append(_text(catalog,row.source,language) % args)
		check(b.hud._end_root.visible and "\n".join(lines) in b.hud._end_tally.text,
			"actual settlement preserves and rerenders frozen results in "+language)
		rendered[language] = lines
	check(JSON.stringify(b.mission.report) == baseline_log and _profile_sha() == profile,
		"debrief refresh leaves historical report and progress alone")
	await _dispose(b)
	print("LIAN_DEBRIEF_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"rendered":rendered}))
	root.get_node("Sfx").shutdown()
	root.get_node("Music").shutdown()
	quit(0 if failures.is_empty() else 1)

func _text(catalog: Dictionary, source: String, language: String) -> String:
	return source if language == "zh_CN" else String(catalog[source][language])

func _profile_sha() -> String:
	return FileAccess.get_sha256("user://campaign.cfg") if FileAccess.file_exists("user://campaign.cfg") else ""
