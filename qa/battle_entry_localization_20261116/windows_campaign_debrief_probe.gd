extends "rts_test.gd"
## Check the eight real settlement panels against the exported catalog.

const LANGUAGES := ["zh_CN", "zh_TW", "en", "ja"]
const EXPECTED := [
	[3,"夺纲 · %s"], [3,"白龙庙 · %s · 取得补给 %d/2"],
	[3,"北矿 · %s"], [3,"%s · 余 %d 骑 · %s · 辎重营仍在"],
	[3,"火攻 · %s"], [3,"救援 · %s · %s"],
	[3,"酒望 · 饮酒 %d/4 处"], [4,"南门 · %s"],
]
const CATALOG_PATH := "res://assets/localization/catalog.json"

var localization: Node
var catalog: Dictionary
var results := {}
var identity := {}

func _run() -> void:
	if OS.get_environment("STEAM_DISABLED") != "1" or not OS.get_user_data_dir().contains("/all_debrief_pack/"):
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	localization = root.get_node("Localize")
	catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	var flow = root.get_node("ContinueFlow")
	var start := Time.get_ticks_msec()+60000
	while flow.busy() and flow.phase != flow.Phase.ERROR and Time.get_ticks_msec() < start:
		await process_frame
	identity = flow._startup_identity
	check(flow.can_launch() and not identity.get("source_mode",true),"exported startup identity")
	check(catalog.size() == 5071,"exported four-language catalog")
	if failures.is_empty():
		for index in range(EXPECTED.size()):
			await _chapter(index)
			if not failures.is_empty(): break
	_finish()

func _text(key: String, language: String) -> String:
	return key if language == "zh_CN" else catalog[key][language]

func _chapter(index: int) -> void:
	localization.set_language("en",false)
	var b = await _start("",index)
	var label := "level%d" % (index+1)
	check(b.phase == b.Phase.FIGHT and b.level.id() == label and b.gameplay_rng_fault().is_empty(),"compiled battle "+label)
	b.set_process(false)
	b.set_physics_process(false)
	for unit in b.units:
		unit.set_physics_process(false)
	b._official_context.clear()
	var report := JSON.stringify(b.mission.report)
	var rows: Array = b.level.campaign_debrief(b.mission)
	check(rows.size() == EXPECTED[index][0] and rows[0].source == EXPECTED[index][1],"compiled outcome rows "+label)
	b.phase = b.Phase.END
	b._complete_end(false,"")
	check(b.hud._end_root.visible,"settlement opened "+label)
	var languages := {}
	for language in LANGUAGES:
		localization._formatted_sources.clear()
		localization.set_language(language,false)
		await process_frame
		var expected: PackedStringArray = [_text("本局战果",language)]
		for row in rows:
			var args: Array = []
			for value in row.args:
				args.append(_text(value,language) if value is String else value)
			expected.append(_text(row.source,language) % args)
		var output := "\n".join(expected)
		check(output in b.hud._end_tally.text,"outcomes visible in "+label+" "+language)
		languages[language] = expected
	check(JSON.stringify(b.mission.report) == report,"historical log preserved "+label)
	results[label] = languages
	await _dispose(b)

func _finish() -> void:
	print("ALL_DEBRIEF_PACK_RESULT ",JSON.stringify({
		"passed":failures.is_empty(),"checks":checks,"failures":failures,"results":results,
		"identity":identity,"catalog_sha256":FileAccess.get_sha256(CATALOG_PATH),"catalog_entries":catalog.size(),
	}))
	if failures.is_empty():
		root.get_node("AppLifecycle").request_quit("all_campaign_debrief_pack")
	else:
		root.get_node("Sfx").shutdown()
		root.get_node("Music").shutdown()
		quit.call_deferred(1)
