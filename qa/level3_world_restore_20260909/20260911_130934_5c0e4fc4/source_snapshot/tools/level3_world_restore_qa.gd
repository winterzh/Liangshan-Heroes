extends Node
## Comprehensive QA for Level 3 Zhujiazhuang full world save & restore lifecycle.
## Tests real Level 3 battle launch, capture under HELD barrier,
## disk slot serialization round-trip, multi-frame presentation layout,
## and complete world restoration without classic regression.
const B := preload("res://scripts/battle.gd")
const U := preload("res://scripts/unit.gd")
const M := preload("res://scripts/game_map.gd")
const Zhu := preload("res://scripts/levels/level3_zhujiazhuang_rts.gd")
const Classic := preload("res://scripts/levels/skirmish.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Factory := preload("res://scripts/run_level3_world_factory.gd")
const Provider := preload("res://scripts/run_content_identity.gd")
const Session := preload("res://scripts/run_world_session.gd")
const Store := preload("res://scripts/run_slot_store.gd")
const Core := preload("res://scripts/run_battle_world_core.gd")
const Mission := preload("res://scripts/campaign_mission.gd")
const Lifecycle := preload("res://scripts/run_local_lifecycle.gd")
const CampaignScript := preload("res://scripts/campaign.gd")

var checks: Array = []
var source: Variant = null
var held := false
var rejected := ""
var trusted: Dictionary = {}
var runtime: Dictionary = {}
var codec := Codec.new()
var slot_root := ""
var report_path := ""

func check(matrix: String, label: String, passed: bool) -> bool:
	checks.append({"matrix": matrix, "label": label, "passed": passed})
	if not passed:
		print("FAIL ", matrix, " ", label)
	return passed

func _on_held(_clock: Dictionary) -> void:
	held = true

func _on_rejected(code: String) -> void:
	rejected = code

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var profile := OS.get_environment("LSH_LEVEL3_RESTORE_PROFILE").replace("\\", "/").simplify_path()
	var safe := profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path()
		safe = safe and path.to_lower() == (profile + "/" + key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower().begins_with((profile + "/appdata/").to_lower())
	if not safe or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("CAMPAIGN_QA") != "1":
		print("LEVEL3_RESTORE_QA PRIVATE_PROFILE_REQUIRED")
		get_tree().quit(2)
		return
	slot_root = OS.get_environment("LSH_LEVEL3_RESTORE_SLOT_ROOT")
	if slot_root.is_empty():
		slot_root = "user://continue/v1"
	report_path = OS.get_environment("LSH_LEVEL3_RESTORE_REPORT")
	run.call_deferred()

func run() -> void:
	var provider := Provider.new()
	trusted = provider.resolve_runtime_identity()
	if not check("INIT", "runtime content identity resolved", trusted.get("ok", false) and trusted.get("save_eligible", false)):
		finish(); return
	var runtime_pack: Dictionary = Factory.prepare_runtime(trusted)
	if not check("INIT", "Level 3 runtime pack prepared", runtime_pack.get("ok", false)):
		finish(); return
	runtime = runtime_pack.runtime

	await test_level3_save_and_restore()
	await test_negative_tampered_restore()
	finish()

func finish() -> void:
	var passed := not checks.is_empty() and checks.all(func(c): return c.passed)
	var report := {
		"passed": passed,
		"checks": checks,
		"pid": OS.get_process_id(),
		"full_world": true,
		"chapter": "level3",
	}
	if not report_path.is_empty():
		var f := FileAccess.open(report_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(report, "\t"))
			f.close()
	print("LEVEL3_WORLD_RESTORE_QA_COMPLETE " + str(checks.size()) + " " + str(passed))
	get_node("/root/Sfx").shutdown()
	get_node("/root/Music").shutdown()
	get_tree().quit(0 if passed else 1)

func test_level3_save_and_restore() -> void:
	# 1. Start a real Level 3 battle from menu
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame

	check("SAVE", "player continue button remains hidden before release", menu.find_child("ContinueBattle", true, false) == null)

	var campaign: Node = get_node("/root/Campaign")
	for key: String in Profiles.ZHU_FLAGS:
		campaign.set(key, Profiles.ZHU_FLAGS[key])
	campaign.ai_friendly = false
	menu._launch()

	for _i in range(180):
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene.get_script() == B:
			break
	source = get_tree().current_scene
	if not check("SAVE", "real Level 3 battle launched", source != null and source.get_script() == B and source.level.get_script() == Profiles.level_script(Profiles.ZHU_ID)):
		return

	source.hud._intro_root.hide()
	source.hud.intro_done.emit()
	if source.phase == B.Phase.DEPLOY:
		source.hud.start_battle.emit()
	for _i in range(12):
		await get_tree().physics_frame
	await get_tree().process_frame

	check("SAVE", "Level 3 fighting without RNG fault", source.phase == B.Phase.FIGHT and source.mission != null and source.gameplay_rng_fault().is_empty())
	check("SAVE", "Level 3 has 7 prisoners and units deployed", source.level.prisoners.size() == 7 and source.units.size() > 40)

	# Mutate some Level 3 state to verify restoration
	source.level.ai_trained = 5
	source.level.raids_sent = 2
	source.level.expansion_secured = true
	source.gold = 680
	source.wood = 420
	source.faction_res[1] = {"gold": 180.0, "wood": 100.0}
	# Introduce sun so the contact action (with quiet_complete) is in the slot.
	source.level._introduce_sun(source)
	check("SAVE", "contact action exists with quiet_complete before first save",
		source.mission.actions.has("zhu_rts_inside")
		and bool(source.mission.actions["zhu_rts_inside"].get("quiet_complete", false)))

	# Configure save barrier for Level 3
	source._official_context = Profiles.ZHU_CONTEXT.duplicate(true)
	source._save_barrier.configure(source, source._run_clock, Profiles.ZHU_CONTEXT)
	source._save_barrier.capture_ready.connect(_on_held)
	source._save_barrier.capture_rejected.connect(_on_rejected)

	get_tree().paused = true
	held = false
	rejected = ""
	if not check("SAVE", "save barrier requests capture", source._save_barrier.request_capture().ok):
		return
	for _i in range(180):
		await get_tree().process_frame
		if held or rejected != "":
			break
	if not check("SAVE", "barrier reaches HELD state", held and rejected == "" and source._save_barrier.state == source._save_barrier.State.HELD and source._save_barrier.health().ok):
		return

	# Save to slot
	var session := Session.new(trusted, runtime, slot_root)
	var saved: Dictionary = session.save_held(source)
	check("SAVE", "session.save_held succeeds for Level 3", saved.ok)
	if not saved.ok:
		print("SAVE_HELD_FAILED: ", saved)
		return

	# Inspect written slot on disk
	var store := Store.new(slot_root)
	var read_res: Dictionary = store.read_slot()
	check("STORE", "disk slot readable", read_res.ok)
	if not read_res.ok:
		return
	var doc: Dictionary = read_res.document
	check("STORE", "slot schema is official_continue_slot_v1", doc.schema == Store.CAMPAIGN_SCHEMA)
	check("STORE", "slot context matches Profiles.ZHU_CONTEXT", doc.context == Profiles.ZHU_CONTEXT)
	check("STORE", "world schema is official_world_core_preparation_v1", doc.world.schema == Core.CAMPAIGN_SCHEMA)
	check("STORE", "world profile id is campaign_level3_v1", doc.world.profile.id == Profiles.ZHU_ID)
	check("STORE", "world sections count is 22", doc.world.sections.size() == Core.CAMPAIGN_SECTIONS.size())
	check("STORE", "world sections has mission", doc.world.sections.has("mission"))
	check("STORE", "world sections has presentation", doc.world.sections.has("presentation"))

	# Free live source and create a fresh menu scene for restore
	source.queue_free()
	await get_tree().process_frame
	source = null

	var restore_menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(restore_menu)
	get_tree().current_scene = restore_menu
	await get_tree().process_frame

	# 2. Restore world from slot
	var restore_session := Session.new(trusted, runtime, slot_root)
	var prepared: Dictionary = restore_session.prepare_restore(restore_menu)
	check("RESTORE", "session.prepare_restore succeeds", prepared.ok)
	if not prepared.ok:
		print("PREPARE_RESTORE_FAILED: ", prepared)
		return

	# Verify premature commit without presentation layout is rejected
	var premature_stage: Dictionary = restore_session.stage_mount()
	check("RESTORE", "stage_mount succeeds", premature_stage.ok)
	var premature_commit: Dictionary = restore_session.commit_restore()
	check("RESTORE", "commit_restore without layout finish is rejected", not premature_commit.ok and premature_commit.code == "PRESENTATION_LAYOUT_REQUIRED")

	# Wait across frames for presentation layout
	var layout_ok := false
	for frame: int in 12:
		await get_tree().process_frame
		var res: Dictionary = restore_session.finish_presentation_layout()
		if res.ok:
			layout_ok = true
			break
		if res.code != "PRESENTATION_LAYOUT_PENDING":
			print("LAYOUT_ERROR: ", res)
			break
	check("RESTORE", "finish_presentation_layout completes across frames", layout_ok)
	if not layout_ok:
		return

	# Commit restore
	var committed: Dictionary = restore_session.commit_restore()
	check("RESTORE", "commit_restore succeeds", committed.ok)
	if not committed.ok:
		print("COMMIT_RESTORE_FAILED: ", committed)
		return

	var restored_battle: Node = committed.battle
	check("RESTORE", "current_scene is restored battle", get_tree().current_scene == restored_battle)
	check("RESTORE", "menu freed", not is_instance_valid(restore_menu))
	check("RESTORE", "official context is Level 3", restored_battle._official_context == Profiles.ZHU_CONTEXT)
	check("RESTORE", "level is Zhu RTS", restored_battle.level.get_script() == Profiles.level_script(Profiles.ZHU_ID))
	check("RESTORE", "level state ai_trained preserved", restored_battle.level.ai_trained == 5)
	check("RESTORE", "level state raids_sent preserved", restored_battle.level.raids_sent == 2)
	check("RESTORE", "level state expansion_secured preserved", restored_battle.level.expansion_secured == true)
	check("RESTORE", "economy gold restored", restored_battle.gold == 680)
	check("RESTORE", "economy wood restored", restored_battle.wood == 420)
	check("RESTORE", "faction_res float values preserved", typeof(restored_battle.faction_res[1]["gold"]) == TYPE_FLOAT and restored_battle.faction_res[1]["gold"] == 180.0)
	check("RESTORE", "mission node present and bound", restored_battle.mission != null and restored_battle.mission.get_script() == Mission)
	check("RESTORE", "units restored (>40)", restored_battle.units.size() > 40)
	check("RESTORE", "prisoners count is 7", restored_battle.level.prisoners.size() == 7)
	check("RESTORE", "save barrier installed in IDLE state with valid scope", restored_battle._save_barrier != null and restored_battle._save_barrier.state == restored_battle._save_barrier.State.IDLE and restored_battle._save_barrier._scope().ok)
	# quiet_complete must survive capture/restore so contact success does not stack toasts.
	check("RESTORE", "zhu_rts_inside quiet_complete preserved",
		restored_battle.mission.actions.has("zhu_rts_inside")
		and bool(restored_battle.mission.actions["zhu_rts_inside"].get("quiet_complete", false)))

	await test_stage_after_contact(restored_battle, restore_session)

func _pause_save(battle: Node) -> Dictionary:
	held = false
	rejected = ""
	get_tree().paused = true
	if not battle._save_barrier.request_capture().ok:
		return {"ok": false, "code": "BARRIER_REQUEST"}
	for _i in range(180):
		await get_tree().process_frame
		if held or rejected != "":
			break
	if not (held and rejected == "" and battle._save_barrier.state == battle._save_barrier.State.HELD and battle._save_barrier.health().ok):
		return {"ok": false, "code": "BARRIER_HELD"}
	var session := Session.new(trusted, runtime, slot_root)
	var saved: Dictionary = session.save_held(battle)
	return saved

func _restore_from_menu() -> Dictionary:
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	get_tree().paused = true
	var session := Session.new(trusted, runtime, slot_root)
	var prepared: Dictionary = session.prepare_restore(menu)
	if not prepared.ok:
		return prepared
	return await session.commit_restore_async()

func test_stage_after_contact(battle: Node, session: Variant) -> void:
	# Stage-2: complete side-gate contact after the first restore (sun already saved).
	var lvl = battle.level
	if not check("STAGE2", "restored battle still fighting", battle.phase == B.Phase.FIGHT):
		return
	if not check("STAGE2", "quiet_complete still set after restore",
			bool(battle.mission.actions.get("zhu_rts_inside", {}).get("quiet_complete", false))):
		return
	if not check("STAGE2", "sun restored after first save",
			lvl.sun != null and is_instance_valid(lvl.sun) and lvl.sent_sun):
		return
	# Use the real mission action API (player right-click / button path).
	var started: bool = battle.mission.request_action("zhu_rts_inside")
	if not check("STAGE2", "request_action contact accepted", started):
		return
	battle._official_context = Profiles.ZHU_CONTEXT.duplicate(true)
	# Hold at contact until the 5s action completes (time_scale accelerates sim).
	Engine.time_scale = 2.0
	var waited := 0.0
	while waited < 30.0 and battle.phase != B.Phase.END and not battle.mission.has_event("zhu_gate_opened"):
		await get_tree().process_frame
		waited += get_process_delta_time() * Engine.time_scale
	Engine.time_scale = 1.0
	if not check("STAGE2", "contact opened side gate after restore",
			battle.mission.has_event("zhu_gate_opened") and lvl.inside_open):
		return

	# Save again mid-campaign after contact.
	battle._save_barrier.configure(battle, battle._run_clock, Profiles.ZHU_CONTEXT)
	battle._save_barrier.capture_ready.connect(_on_held)
	battle._save_barrier.capture_rejected.connect(_on_rejected)
	var saved2: Dictionary = await _pause_save(battle)
	if not check("STAGE2", "second save after contact succeeds", saved2.get("ok", false)):
		print("STAGE2_SAVE_FAILED: ", saved2)
		return

	# Free live battle and restore from the new slot.
	session.dispose()
	battle.queue_free()
	await get_tree().process_frame
	battle = null
	var restored2: Dictionary = await _restore_from_menu()
	if not check("STAGE2", "second restore commit succeeds", restored2.get("ok", false)):
		print("STAGE2_RESTORE_FAILED: ", restored2)
		return
	var b2: Node = restored2.battle
	check("STAGE2", "inside_open preserved", b2.level.inside_open == true)
	check("STAGE2", "zhu_gate_opened event preserved", b2.mission.has_event("zhu_gate_opened"))
	check("STAGE2", "quiet_complete still set on second restore",
		bool(b2.mission.actions.get("zhu_rts_inside", {}).get("quiet_complete", false)))
	check("STAGE2", "prisoners still present after contact restore", b2.level.prisoners.size() == 7)

	# Terminal lifecycle: close the local receipt and refuse further continue.
	if b2._continue_receipt != null:
		var ended: Dictionary = b2._continue_receipt.terminal(false)
		check("STAGE2", "local lifecycle terminal accepted", ended.get("ok", false))
		var store := Store.new(slot_root)
		var read_res: Dictionary = store.read_slot(true)
		# A later prepare_restore must refuse terminal slots via LOCAL_RUN_TERMINAL.
		if read_res.ok:
			b2.queue_free()
			await get_tree().process_frame
			var menu2: Node = load("res://scenes/menu.tscn").instantiate()
			get_tree().root.add_child(menu2)
			get_tree().current_scene = menu2
			await get_tree().process_frame
			get_tree().paused = true
			var s2 := Session.new(trusted, runtime, slot_root)
			var refused: Dictionary = s2.prepare_restore(menu2)
			check("STAGE2", "terminal slot restore refused",
				not refused.ok and String(refused.get("code", "")).begins_with("LOCAL_"))
			s2.dispose()
			menu2.queue_free()
			await get_tree().process_frame
		else:
			b2.queue_free()
			await get_tree().process_frame
	else:
		b2.queue_free()
		await get_tree().process_frame

func test_negative_tampered_restore() -> void:
	var store := Store.new(slot_root)
	var read_res: Dictionary = store.read_slot()
	if not read_res.ok:
		return
	var valid_doc: Dictionary = read_res.document

	# Tampered profile id test
	var tampered_profile := valid_doc.duplicate(true)
	tampered_profile.world.profile.id = "campaign_level4_v1"
	var core := Core.new(trusted, runtime)
	var prep_bad_prof: Dictionary = core.prepare(tampered_profile.world)
	check("NEGATIVE", "tampered profile id rejected with WORLD_CORE_PROFILE", not prep_bad_prof.ok and prep_bad_prof.code == "WORLD_CORE_PROFILE")
	core.dispose()

	# Tampered section test
	var tampered_sections := valid_doc.duplicate(true)
	tampered_sections.world.sections.erase("presentation")
	core = Core.new(trusted, runtime)
	var prep_bad_sec: Dictionary = core.prepare(tampered_sections.world)
	check("NEGATIVE", "missing presentation section rejected with WORLD_CORE_SECTIONS", not prep_bad_sec.ok and prep_bad_sec.code == "WORLD_CORE_SECTIONS")
	core.dispose()

	# Tampered content version test
	var tampered_version := valid_doc.duplicate(true)
	tampered_version.world.content_version = "tampered:version:bad"
	core = Core.new(trusted, runtime)
	var prep_bad_ver: Dictionary = core.prepare(tampered_version.world)
	check("NEGATIVE", "mismatched content version rejected with WORLD_CORE_IDENTITY", not prep_bad_ver.ok and prep_bad_ver.code == "WORLD_CORE_IDENTITY")
	core.dispose()
