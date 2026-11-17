extends "res://tools/zhujiazhuang_rts_test.gd"
## Controlled disguise, evacuation and loss states in the actual Daming UI.

const LANGUAGES := ["zh_CN","zh_TW","ja","en"]
const SAFE_ROWS := ["卢俊义已活着抵达城外接应地","石秀已活着抵达城外接应地"]
const LOSSES := ["卢俊义在营救途中阵亡；二人必须活着抵达接应地。","石秀在营救途中阵亡；二人必须活着抵达接应地。"]
var localization: Node
var catalog: Dictionary
var results := {}

func _run() -> void:
	var profile := OS.get_environment("APPDATA").replace("\\","/")
	if OS.get_environment("STEAM_DISABLED") != "1" or not profile.contains("/daming-notices-") \
			or not OS.get_user_data_dir().replace("\\","/").begins_with(profile + "/"):
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	localization = root.get_node("Localize")
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/catalog.json"))
	var flow = root.get_node("ContinueFlow")
	var deadline := Time.get_ticks_msec() + 60000
	while flow.busy() and flow.phase != flow.Phase.ERROR and Time.get_ticks_msec() < deadline:
		await process_frame
	check(flow.can_launch(),"campaign startup is ready")
	if failures.is_empty(): await _notices()
	if failures.is_empty(): await _loss(0)
	if failures.is_empty(): await _loss(1)
	_finish()

func _text(source: String, language: String) -> String:
	return source if language == "zh_CN" else catalog[source][language]

func _daming():
	localization.set_language("en",false)
	var b = await _start("",7)
	check(b.phase == b.Phase.FIGHT and b.level.id() == "level8","real Daming HUD")
	b.set_physics_process(false)
	for unit in b.units: unit.set_physics_process(false)
	return b

func _notices() -> void:
	var b = await _daming()
	if not failures.is_empty(): return
	var level = b.level
	for spy in level.spies:
		spy._break_invis()
		spy.position = b.map.cell_to_world(level.SAFEHOUSE)
	for unit in b.units:
		if unit.faction == 1 and not unit.is_building:
			unit.position = b.map.cell_to_world(level.ENEMY_HQ)
	b._grid_build()
	level._cover_tick(b,0.0)
	check(level.spies.all(func(spy): return not spy.get_meta("daming_covered",true)),
		"all three exposure handlers run")
	check(not level._guarded(b,level.SAFEHOUSE,170),"safehouse is clear for recovery")
	level._cover_tick(b,3.0)
	check(level.spies.all(func(spy): return spy.get_meta("daming_covered",false)),
		"all three spies restore the disguise through the safehouse handler")
	for camp in level.posts: level.on_unit_died(b,camp)
	check(b.mission.has_event("daming_post_0") and b.mission.has_event("daming_post_1"),
		"both recruitment camp handlers record their own events")
	level.gate_open = true
	level.prison_open = true
	level.on_mission_action(b,"daming_rescue",level.strategist)
	check(level.rescued,"the rescued-prisoner handler activates the evacuation")
	# Controlled positions exercise the two successive arrival events.
	for index in range(2):
		var wounded = level.lu if index == 0 else level.shi
		wounded.position = b.map.cell_to_world(level.EXIT_CELL)
		b._official_context.clear()
		level.strategy_t = 0.0
		level.process(b,0.0)
		check(wounded.story_outcome == "retreated","wounded prisoner reaches the exit in step %d" % index)
		if index == 0:
			check(b.phase == b.Phase.FIGHT and level._wounded_group(b) == [level.shi],
				"first arrival leaves only Shi Xiu to be evacuated")
	var keys: Array = level.SPY_EXPOSED_NOTICE.values() + level.SPY_RESTORED_NOTICE.values() + level.SUPPLY_LOST_NOTICE + SAFE_ROWS
	var report_keys: Array = level.SUPPLY_LOST_NOTICE + SAFE_ROWS
	var log_keys: Array = b.hud._message_log.map(func(row): return row.text)
	check(keys.all(func(source): return log_keys.count(source) == 1),"all ten messages retain their source keys in English")
	check(report_keys.all(func(source): return source in b.mission.report),
		"supply and evacuation rows retain their source keys")
	var stored_rows := JSON.stringify(b.mission.report)
	localization._formatted_sources.clear()
	var seen := {}
	for language in LANGUAGES:
		localization.set_language(language,false)
		for source in keys:
			check(_text(source,language) in b.hud._info_log.text,"battle log is localized in %s: %s" % [language,source.left(5)])
		for source in report_keys:
			check(_text(source,language) in b.hud._end_tally.text,"end report is localized in %s: %s" % [language,source.left(5)])
		seen[language] = keys.map(func(key): return _text(key,language))
	check(JSON.stringify(b.mission.report) == stored_rows,"language changes preserve the report source data")
	results["notices"] = seen
	await _dispose(b)

func _loss(index: int) -> void:
	var b = await _daming()
	if not failures.is_empty(): return
	var level = b.level
	b._official_context.clear()
	level.on_unit_died(b,level.lu if index == 0 else level.shi)
	check(b.phase == b.Phase.END and b.hud._end_root.visible,"the original loss handler shows the debrief")
	var seen := {}
	for language in LANGUAGES:
		localization.set_language(language,false)
		var expected := _text(LOSSES[index],language)
		check(expected in b.hud._end_sub.text,"prisoner %d loss debrief in %s" % [index,language])
		seen[language] = expected
	results["lu_lost" if index == 0 else "shi_lost"] = seen
	await _dispose(b)

func _finish() -> void:
	print("DAMING_NOTICES_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"results":results,
		"fixture":"controlled disguise and exit states, original event handlers and debrief UI, no campaign progress"}))
	if failures.is_empty():
		root.get_node("AppLifecycle").request_quit("daming_notices_fixture")
	else:
		root.get_node("Sfx").shutdown()
		root.get_node("Music").shutdown()
		quit.call_deferred(1)
