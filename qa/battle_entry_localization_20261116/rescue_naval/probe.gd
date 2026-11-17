extends "res://tools/zhujiazhuang_rts_test.gd"
## Language switching on the actual chapter UI with controlled mission states.

const LANGUAGES := ["zh_CN","zh_TW","ja","en"]
const JIANG_FLAGS := {
	"free_song": "好汉 · 救下宋江", "free_dai": "好汉 · 救下戴宗",
	"board_song": "宋江 · 登船", "board_dai": "戴宗 · 登船",
}
const JIANG_REPORTS := [
	"宋江已解缚，不能作战；请派兵保护并亲自下令撤离。",
	"戴宗已解缚，不能作战；请派兵保护并亲自下令撤离。",
	"宋江已活着登船。", "戴宗已活着登船。",
]
const GAO_FLAGS := {"gao_fire_0":"刘唐：外港举火","gao_fire_1":"刘唐：内港举火"}
const GAO_OUTCOMES := ["高俅三次进兵失利，水寨与钱粮守住。本局以击退座船收束；生擒押堂可在重玩时挑战。","高俅三次进兵失利，水寨与钱粮守住。高俅已由水军生擒、岸军押至忠义堂，宋江仍以礼相待，盼借此求得招安。"]
var localization: Node
var catalog: Dictionary
var results := {}

func _run() -> void:
	var profile := OS.get_environment("APPDATA").replace("\\","/")
	if OS.get_environment("STEAM_DISABLED") != "1" or not profile.contains("/rescue-naval-locale-") \
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
	if failures.is_empty(): await _jiang()
	if failures.is_empty(): await _gao(false)
	if failures.is_empty(): await _gao(true)
	_finish()

func _text(key: String, language: String) -> String:
	return key if language == "zh_CN" else catalog[key][language]

func _check_flag_sources(b, keys: Dictionary) -> void:
	for action_id in keys:
		check(b.mission.actions.has(action_id),"registered " + action_id)
		if b.mission.actions.has(action_id):
			var action: Dictionary = b.mission.actions[action_id]
			check(action.label == keys[action_id] and action.marker.label == keys[action_id],
				"action and marker retain the locale-independent label for " + action_id)

func _check_flag_ui(b, keys: Dictionary, language: String) -> void:
	for action_id in keys:
		if not b.mission.actions.has(action_id): continue
		var action: Dictionary = b.mission.actions[action_id]
		var text := _text(keys[action_id],language)
		check(text in action.button.text and localization.text(action.marker.label) == text,
			"%s button and marker in %s" % [action_id,language])

func _jiang() -> void:
	localization.set_language("en",false)
	var b = await _start("",1)
	var level = b.level
	check(b.phase == b.Phase.FIGHT and level.id() == "level2","real Jiangzhou battle UI")
	if not failures.is_empty(): return
	b.set_physics_process(false)
	for guard in level.executioners: guard.resolve_story("subdued")
	level.process(b,0.0)
	check(level.execution_halted,"execution cutoff registers both rescue actions")
	level._free(b,true)
	level._free(b,false)
	_check_flag_sources(b,JIANG_FLAGS)
	for unit in b.units:
		unit.set_physics_process(false)
		if unit.faction == 1: unit.position = b.map.cell_to_world(level.CITY_POST)
	for action_id in ["board_song","board_dai"]:
		if not b.mission.actions.has(action_id): continue
		var passenger = level.song_freed if action_id == "board_song" else level.dai_freed
		passenger.position = b.map.cell_to_world(b.mission.actions[action_id].cell)
		b._grid_build()
		level.on_mission_action(b,action_id,passenger)
		check(passenger.story_outcome == "embarked","actual boarding handler for " + action_id)
	var report_text := JSON.stringify(b.mission.report)
	check(JIANG_REPORTS.all(func(line): return line in b.mission.report),"rescue and boarding keep original report keys in English")
	localization._formatted_sources.clear()
	var seen := {}
	for language in LANGUAGES:
		localization.set_language(language,false)
		_check_flag_ui(b,JIANG_FLAGS,language)
		var rows: Array = JSON.parse_string(report_text)
		var result: Dictionary = b.mission.result_snapshot(false)
		var report: String = b._end_report_text(result,rows,{"track_combat":false,"kills":{},"combat":{}},true)
		check(JIANG_REPORTS.all(func(line): return _text(line,language) in report),
			"all rescue and boarding debrief rows in " + language)
		seen[language] = JIANG_REPORTS.map(func(key): return _text(key,language))
	check(JSON.stringify(b.mission.report) == report_text,"switching languages preserves the Jiangzhou report")
	results["jiangzhou"] = seen
	await _dispose(b)

func _gao(captured: bool) -> void:
	localization.set_language("en",false)
	var b = await _start("",4)
	var level = b.level
	check(b.phase == b.Phase.FIGHT and level.id() == "level5","real Gao Qiu battle UI")
	if not failures.is_empty(): return
	b.set_physics_process(false)
	if not captured:
		level.on_mission_action(b,"gao_prepare",b.find_unit("liu_tang"))
		check(level.fire_prepared,"prepare action creates both fire markers")
		_check_flag_sources(b,GAO_FLAGS)
		for language in LANGUAGES:
			localization.set_language(language,false)
			_check_flag_ui(b,GAO_FLAGS,language)
		results["gao_fire"] = GAO_FLAGS.values()
	# This fixture only drives the settlement renderer. Do not write campaign progress.
	b._official_context.clear()
	level.flagship_disabled = true
	level.water_groups.clear()
	level.land_groups.clear()
	if captured:
		level.prisoner = b.find_unit("zhang_shun_boat")
		b.mission.mark("gao_captured","高俅已押抵忠义堂。点击「收兵通关」即可结算。")
	level._finish(b)
	check(b.phase == b.Phase.END and b.hud._end_root.visible,"actual settlement renderer for capture=%s" % captured)
	var source: String = GAO_OUTCOMES[int(captured)]
	var seen := {}
	for language in LANGUAGES:
		localization.set_language(language,false)
		var target := _text(source,language)
		check(target in b.hud._end_sub.text,"settlement text capture=%s in %s" % [captured,language])
		seen[language] = target
	results["gao_capture" if captured else "gao_basic"] = seen
	await _dispose(b)

func _finish() -> void:
	print("RESCUE_NAVAL_LOCALE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"results":results,
		"fixture":"real Jiangzhou and Gao UI with controlled rescue, fire preparation and end states; no campaign progress"}))
	if failures.is_empty():
		root.get_node("AppLifecycle").request_quit("rescue_naval_locale_fixture")
	else:
		root.get_node("Sfx").shutdown()
		root.get_node("Music").shutdown()
		quit.call_deferred(1)
