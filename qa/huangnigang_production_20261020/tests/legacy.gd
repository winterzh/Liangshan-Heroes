extends "base.gd"
var held := false
var rejection := ""

func _run() -> void:
	if not identity(true): report(); return
	var profiles: Script = load("res://scripts/run_official_restore_profile.gd")
	check(profiles.HG_ID == "campaign_level1_v1", "real original three-target profile installed")
	var runtime: Dictionary = load("res://scripts/run_level1_world_factory.gd").prepare_runtime(trusted)
	if not runtime.get("ok", false): check(false, "legacy runtime prepares"); report(); return
	var battle: Variant = await _start()
	for i in range(12): await get_tree().physics_frame
	check(battle.level.bundles.size() == 3, "real legacy scene deploys exactly three old targets")
	get_tree().paused = true
	battle._save_barrier.configure(battle, battle._run_clock, profiles.HG_CONTEXT)
	battle._save_barrier.capture_ready.connect(func(_c): held = true)
	battle._save_barrier.capture_rejected.connect(func(code): rejection = String(code))
	var requested: Dictionary = battle._save_barrier.request_capture()
	check(requested.get("ok", false), "legacy capture requested")
	for i in range(180):
		await get_tree().process_frame
		if held or rejection != "": break
	check(held and rejection == "" and battle._save_barrier.health().ok, "legacy real barrier holds complete initial scene")
	if not held or rejection != "": report(); return
	var session: Variant = load("res://scripts/run_world_session.gd").new(trusted, runtime.runtime, "user://hg_legacy3/v1")
	var saved: Dictionary = session.save_held(battle)
	check(saved.get("ok", false), "actual original three-target complete world saved")
	if not saved.get("ok", false): print("LEGACY_SAVE ", saved); report(); return
	var slot: Dictionary = load("res://scripts/run_slot_store.gd").new("user://hg_legacy3/v1").read_slot()
	check(slot.get("ok", false), "actual legacy saved record readable")
	if not slot.get("ok", false): report(); return
	check(slot.document.world.profile.id == "campaign_level1_v1", "saved original profile remains v1")
	var copied: Array = dump_fixture_slot("hg_legacy3", OS.get_environment("HG_LEGACY_COPY"))
	check(copied.size() == 2, "only committed old fixture and lifecycle bytes retained")
	report({"scope": "Real legacy original3 initial scene save; no synthetic identity or converted new slot.",
		"slot_sha256": slot.file_sha256, "copied_fixture_files": copied,
		"profile": slot.document.world.profile.id, "load_ids": battle.level.bundles.map(func(u): return u.entity_id)})
