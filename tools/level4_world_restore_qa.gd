extends Node
## Component/stage fixtures, not a natural full victory or player acceptance.
const B := preload("res://scripts/battle.gd")
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Factory := preload("res://scripts/run_level4_world_factory.gd")
const Provider := preload("res://scripts/run_content_identity.gd")
const Session := preload("res://scripts/run_world_session.gd")
const Store := preload("res://scripts/run_slot_store.gd")
const Core := preload("res://scripts/run_battle_world_core.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
var checks: Array = []
var trusted: Dictionary
var runtime: Dictionary
var held := false
var rejected := ""
var session: RefCounted

func check(label: String, ok: bool) -> bool:
	checks.append({"label": label, "passed": ok})
	print("LEVEL4 ", "PASS " if ok else "FAIL ", label)
	return ok

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var project := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var profile := OS.get_user_data_dir().replace("\\", "/")
	if project != OS.get_environment("LSH_INPUT_QA_PROJECT").replace("\\", "/") or profile != OS.get_environment("LSH_INPUT_QA_PROFILE").replace("\\", "/") or not String(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("LSH-") or OS.get_environment("STEAM_DISABLED") != "1":
		get_tree().quit(2); return
	run.call_deferred()

func _on_held(_clock: Dictionary) -> void: held = true
func _on_rejected(code: String) -> void: rejected = code

func run() -> void:
	trusted = Provider.new().resolve_runtime_identity()
	if not check("installed identity", trusted.get("save_eligible", false)): print(trusted); finish(); return
	var pack := Factory.prepare_runtime(trusted)
	if not check("installed runtime without deploy", pack.get("ok", false) and not pack.get("deploy_or_start_called", true)): print(pack); finish(); return
	runtime = pack.runtime
	check("unimplemented Gao still rejected", not Profiles.select_context({"mode": "campaign", "level_id": "level5", "waves": 0}, trusted).ok)
	var mode := OS.get_environment("LSH_LEVEL4_MODE")
	if mode == "resume":
		await cross_resume(); finish(); return
	var campaign := get_node("/root/Campaign")
	for key in Profiles.LIAN_FLAGS: campaign.set(key, Profiles.LIAN_FLAGS[key])
	campaign.ai_friendly = false
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	menu._launch()
	for frame in range(180):
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene.get_script() == B: break
	var b: Node = get_tree().current_scene
	if not check("real level4 launch", b != null and b.get_script() == B and b.level.id() == "level4"): finish(); return
	b.hud._intro_root.hide(); b.hud.intro_done.emit()
	if b.phase == B.Phase.DEPLOY: b.hud.start_battle.emit()
	for frame in range(12): await get_tree().physics_frame
	await get_tree().process_frame
	b._official_context = Profiles.LIAN_CONTEXT.duplicate(true)
	b._save_barrier.configure(b, b._run_clock, Profiles.LIAN_CONTEXT)
	get_tree().paused = true
	if mode == "save":
		await save(b, "user://level4_cross/v1", "cross_process")
		finish(); return
	b = await roundtrip(b, "initial")
	if not is_instance_valid(b): finish(); return
	var barracks: Variant = b.units.filter(func(u): return u.key == "barracks" and u.faction == 0)[0]
	var gold: int = b.gold
	check("paid hook recruitment", b.queue_train(barracks, "gou_lian", false) and b.gold < gold)
	b = await roundtrip(b, "paid_queue")
	if not is_instance_valid(b): finish(); return
	# Explicit stage fixture uses the authored wave dispatcher and real order queues.
	b.level._send_wave(b, 0)
	check("north six riders dispatched", b.level.riders.slice(0, 6).all(func(u): return u.get_meta("wave_state") == "charging"))
	b = await roundtrip(b, "charging")
	if not is_instance_valid(b): finish(); return
	# Controlled local geometry; real hook-team and terrain/slow rules perform break.
	var rider: Variant = b.level.riders[0]
	var hook: Variant = b.units.filter(func(u): return u.key == "gou_lian" and u.faction == 0)[0]
	rider.position = b.level.xu.position + Vector2(35, 0)
	hook.position = b.level.xu.position + Vector2(5, 20)
	b.level.xu.order_attack(rider)
	hook.order_attack(rider)
	rider.apply_slow(0.5, 4.0)
	b.level._rider_tick(b)
	check("actual coordinated break", rider.get_meta("formation_broken") and b.level.broken_count == 1)
	b = await roundtrip(b, "broken")
	if not is_instance_valid(b): finish(); return
	b.level.riders[0].take_damage(100000.0, null, false, true)
	check("real rider death callback counted once", b.level.lhm_killed == 1)
	b = await roundtrip(b, "dying_rider")
	if not is_instance_valid(b): finish(); return
	b.level.hu.take_damage(100000.0, null, false, true)
	b.level.han.take_damage(100000.0, null, false, true)
	check("real capture and retreat", b.level.hu.story_outcome == "retreated" and b.level.han.story_outcome == "captured")
	b = await roundtrip(b, "leaders_resolved")
	if not is_instance_valid(b): finish(); return
	b.level.on_mission_action(b, "lhm_drill_reset", b.level.xu)
	check("actual drill reset creates dummy", is_instance_valid(b.level.dummy))
	b = await roundtrip(b, "drill_ready")
	if not is_instance_valid(b): finish(); return
	get_tree().paused = false
	var old_tick: int = b._run_clock._next_tick
	for frame in range(30): await get_tree().physics_frame
	await get_tree().process_frame
	get_tree().paused = true
	check("restored world continues natural simulation", b._run_clock._next_tick > old_tick and b.gameplay_rng_fault().is_empty())
	b = await roundtrip(b, "after_simulation")
	finish()

func save(b: Node, slot: String, label: String) -> Dictionary:
	b._continue_receipt = null
	held = false; rejected = ""
	if not b._save_barrier.capture_ready.is_connected(_on_held):
		b._save_barrier.capture_ready.connect(_on_held, CONNECT_ONE_SHOT)
	if not b._save_barrier.capture_rejected.is_connected(_on_rejected):
		b._save_barrier.capture_rejected.connect(_on_rejected, CONNECT_ONE_SHOT)
	var requested: Dictionary = b._save_barrier.request_capture()
	if not check(label + " capture request", requested.ok): return {"ok": false}
	for frame in range(180):
		await get_tree().process_frame
		if held or rejected != "": break
	if not check(label + " held boundary", held and rejected == ""): print(rejected); return {"ok": false}
	var saved: Dictionary = Session.new(trusted, runtime, slot).save_held(b)
	if not check(label + " save whole world", saved.ok): print(saved); return saved
	var read: Dictionary = Store.new(slot).read_slot()
	if not check(label + " closed slot readable", read.ok): print(read); return read
	check(label + " exact chapter context", read.document.context == Profiles.LIAN_CONTEXT)
	return read

func roundtrip(b: Node, label: String) -> Node:
	var slot := "user://level4_" + label + "/v1"
	var read := await save(b, slot, label)
	if not read.ok: return null
	var before: Dictionary = read.document.world
	var bad: Dictionary = before.duplicate(true)
	bad.profile.id = Profiles.ZHU_ID
	var core := Core.new(trusted, runtime)
	var invalid: Dictionary = core.prepare(bad)
	check(label + " wrong chapter refused before install", not invalid.ok)
	core.dispose()
	if label == "initial":
		negative_cases(before)
	b.queue_free(); await get_tree().process_frame
	if session != null: session.dispose(); session = null
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	session = Session.new(trusted, runtime, slot)
	var restore_start_ms := Time.get_ticks_msec()
	var prepared: Dictionary = session.prepare_restore(menu)
	if not check(label + " prepare private world", prepared.ok): print(prepared); return null
	var installed: Dictionary = await session.commit_restore_async()
	if not check(label + " install paused world", installed.ok): print(installed); return null
	var restored: Node = installed.battle
	var recaptured := await save(restored, slot + "_recaptured", label + " recapture")
	if not recaptured.ok: return null
	for section in ["units", "level", "map", "rng"]:
		check(label + " exact " + section, before.sections[section] == recaptured.document.world.sections[section])
	# Stage age uses wall-clock time in production, including paused UI time.
	# Its bounded advance is expected; every other mission field must be exact.
	var codec := Codec.new()
	var old_mission: Dictionary = codec.decode(before.sections.mission.payload).value
	var new_mission: Dictionary = codec.decode(recaptured.document.world.sections.mission.payload).value
	var age_delta: int = new_mission.values.stage_age_ms - old_mission.values.stage_age_ms
	check(label + " stage clock rebased within measured interval", age_delta >= 0 and age_delta <= Time.get_ticks_msec() - restore_start_ms + 100)
	old_mission.values.erase("stage_age_ms"); new_mission.values.erase("stage_age_ms")
	check(label + " exact remaining mission state", old_mission == new_mission)
	check(label + " release snapshot barrier", restored._save_barrier.release_capture().ok)
	check(label + " reading leaves disk untouched", Store.new(slot).read_slot().file_sha256 == read.file_sha256)
	if label == "after_simulation":
		# The snapshot gate blocks minimum_size_changed during restoration.
		# Let native containers finish queued sorts while gameplay stays paused.
		for frame in range(12): await get_tree().process_frame
		for row in restored.hud.msg_box.get_children():
			var text: Label = row.get_node("Text")
			check("restored toast layout fits text", absf(row.size.y - text.get_combined_minimum_size().y - 12.0) < 2.0)
		await RenderingServer.frame_post_draw
		var screenshot := get_viewport().get_texture().get_image()
		check("actual restored viewport captured", screenshot.save_png(OS.get_environment("LSH_LEVEL4_REPORT").get_basename() + ".png") == OK)
	return restored

func negative_cases(world: Dictionary) -> void:
	var codec := Codec.new()
	var decoded: Dictionary = codec.decode(world.sections.level.payload)
	if not check("negative fixture level decoded", decoded.ok): return
	for kind in ["wrong_kill_count", "duplicate_rider", "wrong_rider_lane"]:
		var bad: Dictionary = world.duplicate(true)
		if kind == "wrong_rider_lane":
			var id: String = decoded.value.references.riders[0]
			var index: int = bad.sections.units.root_order.find(id)
			var unit: Dictionary = codec.decode(bad.sections.units.records[index].payload)
			if not check("negative fixture unit decoded", unit.ok): return
			unit.value.metadata.wave_group.value = 1
			bad.sections.units.records[index].payload = codec.encode(unit.value).value
		else:
			var value: Dictionary = decoded.value.duplicate(true)
			if kind == "wrong_kill_count": value.values.lhm_killed = 1
			else: value.references.riders[1] = value.references.riders[0]
			bad.sections.level.payload = codec.encode(value).value
		var core := Core.new(trusted, runtime)
		var result: Dictionary = core.prepare(bad)
		check("corrupt " + kind + " rejected", not result.ok)
		core.dispose()

func cross_resume() -> void:
	get_tree().paused = true
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	session = Session.new(trusted, runtime, "user://level4_cross/v1")
	var prepared: Dictionary = session.prepare_restore(menu)
	if not check("new process prepares saved world", prepared.ok): print(prepared); return
	var installed: Dictionary = await session.commit_restore_async()
	if not check("new process installs saved world", installed.ok): print(installed); return
	var b: Node = installed.battle
	var initial_tick: int = b._run_clock._next_tick
	get_tree().paused = false
	for frame in range(40): await get_tree().physics_frame
	await get_tree().process_frame
	get_tree().paused = true
	check("new process advances simulation", b._run_clock._next_tick > initial_tick and b.gameplay_rng_fault().is_empty())
	await save(b, "user://level4_cross_resaved/v1", "new_process_resave")

func finish() -> void:
	var passed := not checks.is_empty() and checks.all(func(row): return row.passed)
	var path := OS.get_environment("LSH_LEVEL4_REPORT")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"passed": passed, "checks": checks, "pid": OS.get_process_id(), "mode": OS.get_environment("LSH_LEVEL4_MODE"), "fixture": true, "player_entry": false}, "\t")); file.close()
	else: passed = false
	get_node("/root/Sfx").shutdown(); get_node("/root/Music").shutdown()
	get_tree().quit(0 if passed else 1)
