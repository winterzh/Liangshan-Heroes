extends SceneTree

var failed := false
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	failed = failed or not condition
	print("BRIEFING ", "PASS " if condition else "FAIL ", description)

func chapter(index: int):
	root.get_node("Campaign").current = index
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	battle.hud._intro_root.hide()
	battle._on_intro_done()
	battle._on_start_battle()
	return battle

func check_brief(b, expected: Dictionary, name: String) -> void:
	check(b.mission.stage_title == expected.title and b.mission.objective == expected.objective, name)

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	var localize := root.get_node("Localize")
	localize.set_language("zh_CN", false)
	var b = await chapter(3)
	var level = b.level
	check(level.id() == "level4" and b.phase == b.Phase.FIGHT, "registered Level4 starts")
	check_brief(b, level.PREPARE_BRIEFING, "prepare title and objective")
	var destinations := {}
	for button in b.mission._buttons.get_children():
		var descriptor: Dictionary = button.get_meta(b.mission.PRESENTATION_META, {})
		if descriptor.get("kind") == "map":
			destinations[descriptor.label] = descriptor.cell
	check(destinations == {"北侧芦苇地":level.LANES[0], "南侧芦苇地":level.LANES[1],
		"北路辎重营":level.NORTH_POST, "南路辎重营":level.SOUTH_POST, "官军大营":level.ENEMY_CAMP},
		"five map buttons bind actual destinations")
	var original_selection: Array = b.selection.duplicate()
	for button in b.mission._buttons.get_children():
		var descriptor: Dictionary = button.get_meta(b.mission.PRESENTATION_META, {})
		if descriptor.get("label") == "官军大营":
			b.center_camera_cell(level.ENEMY_CAMP)
			var expected: Vector2 = b.camera.position
			b.center_camera_cell(level.CAMP)
			button.pressed.emit()
			check(b.camera.position.is_equal_approx(expected) and b.selection == original_selection,
				"map button moves camera and preserves selection")
	level.waves[0].sent = true
	level._update_briefing(b)
	check_brief(b, level.DEFEND_BRIEFING, "after first wave starts")
	level.lhm_killed = 12
	level._update_briefing(b)
	check_brief(b, level.COUNTER_BRIEFING, "twelve defeated points to siege")
	level.lhm_killed = 8
	level.manor_fallen = true
	level._update_briefing(b)
	check_brief(b, level.FINISH_BRIEFING, "early camp destruction points to surviving riders")
	for locale in ["en", "ja", "zh_TW", "zh_CN"]:
		localize.set_language(locale, false)
		check(b.mission._title.text == localize.text(level.FINISH_BRIEFING.title)
			and b.mission._objective.text == localize.text(level.FINISH_BRIEFING.objective)
			and (locale == "zh_CN" or b.mission._objective.text != level.FINISH_BRIEFING.objective),
			"visible Level4 text updates in " + locale)
	b.queue_free()
	await process_frame
	b = await chapter(1)
	level = b.level
	check(level.id() == "level2" and b.phase == b.Phase.FIGHT, "registered Level2 starts")
	level._uprising(b, b.find_unit("li_kui"))
	# Boundary fixture only: force the executioners to the defeated state.
	for executioner in level.executioners:
		executioner.hp = 0
	level.process(b, 0.01)
	check(level.execution_halted and b.mission.stage_title == "救人 · 分别解缚"
		and b.mission.objective.begins_with("行刑已停")
		and b.mission.actions.has("free_song") and b.mission.actions.has("free_dai"),
		"execution halt creates both rescue actions and replaces stale objective")
	for locale in ["en", "ja", "zh_TW"]:
		localize.set_language(locale, false)
		check(b.mission._objective.text == localize.text(b.mission.objective)
			and b.mission._objective.text != b.mission.objective, "visible Level2 text updates in " + locale)
	b.queue_free()
	await process_frame
	print("BRIEFING_SUMMARY checks=", checks, " passed=", not failed)
	quit(1 if failed else 0)
