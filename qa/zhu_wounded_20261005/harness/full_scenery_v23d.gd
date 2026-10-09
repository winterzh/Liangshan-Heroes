extends "res://gao_scenery_v20k.gd"
## Complete original Gao/Daming map/scenery component; detached owners remain
## explicit, with no Unit/Mission/clock activation or independent-process claim.

func _daming_roundtrip(b, label: String) -> void:
	var local_context := {"mode":"campaign","level_id":"level8","waves":0}
	var maps = Maps.new(trusted.content_version, local_context)
	var original: Dictionary = maps.capture(b.map)
	check(original.ok, label + " actual entire installed Daming map capture")
	if not original.ok: print(original); return
	var display: Dictionary = original.value.sections.display
	check(display.schema == "level8_scenery_state_v1", label + " installed Daming display schema")
	check(not SceneryState.new(trusted.content_version).validate(display).ok, label + " default context rejects chapter")
	check(not SceneryState.new(trusted.content_version, context).validate(display).ok, label + " Gao context rejects Daming")
	for lane: String in ["walls", "sprites", "trees"]:
		var altered: Dictionary = display.duplicate(true)
		altered.ownership[lane].erase(altered.ownership[lane][0])
		check(not SceneryState.new(trusted.content_version, local_context).validate(altered).ok, label + " missing native owner rejected: " + lane)
	var night = b.map.sample_scenery.get_child(0, true)
	night.add_to_group("qa_foreign_canvas_group")
	check(not maps.capture(b.map).ok, label + " non-native night group rejected")
	night.remove_from_group("qa_foreign_canvas_group")
	var old_map = null
	for node: Node in b.map.sample_scenery._walls:
		if node.get_script() == load("res://scripts/campaign_passage.gd"):
			old_map = node.map; node.map = null
			check(not maps.capture(b.map).ok, label + " null live Passage map rejected")
			node.map = old_map
			break
	var bad: Dictionary = display.duplicate(true)
	var payload: Dictionary = load("res://scripts/run_state_value_codec.gd").new().decode(bad.lighting.payload).value
	payload.ownership.cuiyun = payload.ownership.lamps[0]
	bad.lighting.payload = load("res://scripts/run_state_value_codec.gd").new().encode(payload).value
	check(not SceneryState.new(trusted.content_version, local_context).validate(bad).ok, label + " wrong tower light owner rejected")
	var owner = B.new(); owner.process_mode = Node.PROCESS_MODE_DISABLED; owner.set_block_signals(true)
	var world := Node2D.new(); owner.add_child(world)
	owner.map = M.new(); world.add_child(owner.map)
	owner.level = load("res://scripts/levels/level8_daming_rts.gd").new()
	owner.fog = b.fog; owner._vision = b._vision.duplicate()
	var staged: Dictionary = maps.stage_map_values(owner.map, original.value)
	check(staged.ok and not staged.complete, label + " authoritative entire map staged")
	if not staged.ok: print(staged); owner.free(); return
	var runtime: Dictionary = load("res://scripts/run_level8_world_factory.gd").prepare_runtime(trusted)
	check(runtime.ok, label + " installed runtime prepared without callbacks")
	if not runtime.ok: print(runtime); owner.free(); return
	owner._defs = runtime.runtime.defs; owner._abilities = runtime.runtime.abilities; owner._items = runtime.runtime.items
	var rng: Dictionary = owner.configure_restored_gameplay_rng(trusted, b.capture_gameplay_rng().record)
	check(rng.ok, label + " original actual RNG staged")
	var guard: Dictionary = SceneryState.new(trusted.content_version, local_context)._campaign_gameplay_guard(owner.map)
	var finished: Dictionary = maps.finish_display(owner.map, original.value)
	check(finished.ok, label + " full original fixed Daming scenery factory restored")
	if not finished.ok: print(finished); owner.free(); return
	check(not finished.complete and finished.display_requires_activation, label + " full world activation still pending")
	var adapter = finished.display_adapter
	check(adapter._campaign_gameplay_guard(owner.map) == guard, label + " map/nav/height/economy/RNG factory guard unchanged")
	check(not maps.capture(owner.map).ok, label + " ordinary capture still rejects gated foreign transaction")
	check(not maps.capture_prepared(owner.map, SceneryState.new(trusted.content_version, local_context)).ok, label + " unowned adapter rejected")
	var again: Dictionary = maps.capture_prepared(owner.map, adapter)
	check(again.ok, label + " whole restored map recaptured")
	if not again.ok: print(again)
	var equal: bool = again.ok and again.value == original.value
	check(equal, label + " exact whole map/scenery payload recapture")
	var current: Dictionary = maps.capture(b.map)
	check(current.ok and current.value == original.value, label + " entire source map unchanged")
	check(owner.map.sample_scenery._lantern_texture != b.map.sample_scenery._lantern_texture,
		label + " fresh gradient belongs to restored scenery")
	art_runtime.append({"case":label,"exact_map_recapture":equal,"schema":display.schema,
		"complete_world_qualified":false,"public_campaign_continue_qualified":false,
		"scope":"Entire original map, five navigation grids, height/material/reeds, night, lights, CityWall, Passage, sprites, crowd and shadow ownership reconstructed and exactly recaptured. Original disabled Battle/Level shells, not restored Units/Mission/clock or independent process continuation. Phase fixtures explicit."})
	adapter.dispose_campaign(); owner.free()

func _daming_cases() -> void:
	var b = await _start("", 7)
	for frame in range(4): await physics_frame
	await process_frame; paused = true
	await _daming_roundtrip(b, "level8 initial")
	b.level._open_prison(b, false)
	check(b.level.prison_open and not b.level.rescued, "original admission without rescue")
	await _daming_roundtrip(b, "level8 prison admitted")
	b.level.chai.position = b.map.cell_to_world(Vector2i(19, 15))
	b.level.yue.position = b.level.chai.position + Vector2(25, 0)
	b.level.on_mission_action(b, "daming_fire", b.level.scout)
	check(b.level.signaled and b.level.signal_left == 90.0, "original fire signal callback")
	await _daming_roundtrip(b, "level8 signal")
	b.level.process(b, 91.0)
	check(b.level.signal_left == 0.0 and b.level.reserve_returned, "original expired signal callback")
	await _daming_roundtrip(b, "level8 signal expired")
	b.level._open_gate(b, true)
	for unit in b.units:
		if alive(unit) and unit.faction == 1 and not unit.is_building: unit.position = b.map.cell_to_world(Vector2i(44, 8))
	b.level.on_mission_action(b, "daming_rescue", b.level.chai)
	check(b.level.rescued and not b.level.lu.is_captive and not b.level.shi.is_captive, "original rescue callback")
	await _daming_roundtrip(b, "level8 gate open rescued")
	paused = false; await _dispose(b)

func _run() -> void:
	if not _art_profile_guard(): quit(2); return
	Maps = load("res://scripts/run_map_state.gd"); SceneryState = load("res://scripts/run_scenery_state.gd")
	B = load("res://scripts/battle.gd"); M = load("res://scripts/game_map.gd")
	L = load("res://scripts/levels/level5_gao_rts.gd"); Factory = load("res://scripts/run_level5_world_factory.gd")
	art_output = OS.get_environment("ART_QA_OUT"); art_character = "full_scenery_v23d"; art_visual = false
	trusted = _art_identity(); check(trusted.get("save_eligible",false), "installed input identity")
	if not trusted.get("save_eligible",false): _art_finish(); return
	var b = await _start("",4)
	for frame in range(4): await physics_frame
	await process_frame; paused = true
	await _roundtrip_map(b,"level5 initial")
	b.level._send_wave(b,0)
	await _roundtrip_map(b,"level5 wave sent")
	paused = false; await _dispose(b)
	await _classic_regression(); await _daming_cases(); _art_finish()
