extends "res://tools/art_character_direction4_qa.gd"
## Initial-state regression for existing official chapters after shared scene codec changes.
var Maps: Script
var Scenes: Script
var B: Script
var M: Script
var trusted: Dictionary

func _case(index: int) -> void:
	var b = await _start("", index)
	for frame in range(4): await physics_frame
	await process_frame; paused = true
	var id: String = b.level.id()
	var context := {"mode":"campaign","level_id":id,"waves":0}
	var maps = Maps.new(trusted.content_version, context)
	var original: Dictionary = maps.capture(b.map)
	check(original.ok, id + " original installed entire map captured")
	if not original.ok: print(original); paused = false; await _dispose(b); return
	var owner = B.new(); owner.process_mode = Node.PROCESS_MODE_DISABLED; owner.set_block_signals(true)
	var world := Node2D.new(); owner.add_child(world)
	owner.map = M.new(); world.add_child(owner.map)
	owner.level = b.level.get_script().new(); owner.fog = b.fog; owner._vision = b._vision.duplicate()
	var staged: Dictionary = maps.stage_map_values(owner.map, original.value)
	check(staged.ok, id + " original authoritative map staged")
	if not staged.ok: print(staged); owner.free(); paused = false; await _dispose(b); return
	var factory = load("res://scripts/run_" + id + "_world_factory.gd")
	var runtime: Dictionary = factory.prepare_runtime(trusted)
	check(runtime.ok, id + " installed pure runtime factory")
	if not runtime.ok: print(runtime); owner.free(); paused = false; await _dispose(b); return
	owner._defs = runtime.runtime.defs; owner._abilities = runtime.runtime.abilities; owner._items = runtime.runtime.items
	check(owner.configure_restored_gameplay_rng(trusted, b.capture_gameplay_rng().record).ok, id + " original RNG staged")
	var guard: Dictionary = Scenes.new(trusted.content_version, context)._campaign_gameplay_guard(owner.map)
	var finished: Dictionary = maps.finish_display(owner.map, original.value)
	check(finished.ok, id + " original whole scene fixed factory restored")
	if not finished.ok: print(finished); owner.free(); paused = false; await _dispose(b); return
	var adapter = finished.display_adapter
	check(adapter._campaign_gameplay_guard(owner.map) == guard, id + " navigation/height/economy/RNG guard unchanged")
	var again: Dictionary = maps.capture_prepared(owner.map, adapter)
	var equal: bool = again.ok and again.value == original.value
	check(equal, id + " exact original complete map/scenery payload recapture")
	if not again.ok: print(again)
	var current: Dictionary = maps.capture(b.map)
	check(current.ok and current.value == original.value, id + " original source map unchanged")
	art_runtime.append({"case":id,"exact_map_recapture":equal,"complete_world_qualified":false,
		"scope":"Original initial installed chapter map/scenery regression. Disabled detached owner/Level shell and prepared transaction capture, not Unit/Mission/clock activation or independent process continuation."})
	adapter.dispose_campaign(); owner.free(); paused = false; await _dispose(b)

func _run() -> void:
	if not _art_profile_guard(): quit(2); return
	Maps = load("res://scripts/run_map_state.gd"); Scenes = load("res://scripts/run_scenery_state.gd")
	B = load("res://scripts/battle.gd"); M = load("res://scripts/game_map.gd")
	art_output = OS.get_environment("ART_QA_OUT"); art_character = "official_scenery_regression_v23h"; art_visual = false
	trusted = _art_identity(); check(trusted.get("save_eligible",false), "installed input identity")
	if not trusted.get("save_eligible",false): _art_finish(); return
	var selection: String = OS.get_environment("OFFICIAL_SCENE_INDEX")
	var allowed := [0, 1, 2, 3, 5, 6]
	if not selection.is_valid_int() or int(selection) not in allowed:
		check(false, "fixed official chapter case required"); _art_finish(); return
	await _case(int(selection))
	_art_finish()
