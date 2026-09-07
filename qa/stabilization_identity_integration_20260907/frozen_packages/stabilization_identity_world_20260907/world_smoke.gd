extends SceneTree
## One fresh process/scene per manifest case. Production main scene and Battle._ready.
## No SMOKE_TEST, accelerated clock, fixture spawn, forced victory or restore factory.
const CASES := {
	"defense30": {"index": 0, "script": "res://scripts/levels/skirmish.gd", "id": "skirmish", "refs": ["hall"], "arrays": {}},
	"level1": {"index": 0, "script": "res://scripts/levels/level1_huangnigang_short.gd", "id": "level1", "refs": ["cart"], "arrays": {"actors": 7, "bundles": 3}},
	"level2": {"index": 1, "script": "res://scripts/levels/level2_jiangzhou_rts.gd", "id": "level2", "refs": ["scaffold", "song_bound", "dai_bound", "post", "temple"], "arrays": {"camps": 2, "caches": 2, "executioners": 2}},
	"level3": {"index": 2, "script": "res://scripts/levels/level3_zhujiazhuang_rts.gd", "id": "level3", "refs": ["hall", "song", "gate", "side_gate", "enemy_base", "outpost", "hu"], "arrays": {"workers": 6, "prisoners": 1}},
	"level4": {"index": 3, "script": "res://scripts/levels/level4_lianhuanma_rts.gd", "id": "level4", "refs": ["hall", "song", "xu", "hu", "han", "enemy_base"], "arrays": {"workers": 6, "posts": 2, "riders": 12}},
	"level5": {"index": 4, "script": "res://scripts/levels/level5_gao_rts.gd", "id": "level5", "refs": ["hall", "song", "flagship", "fireboat"], "arrays": {"workers": 6, "posts": 2}},
	"level6": {"index": 5, "script": "res://scripts/levels/level6_yezhulin.gd", "id": "level6", "refs": ["lin_freed", "lu"], "arrays": {"escorts": 2}},
	"level7": {"index": 6, "script": "res://scripts/levels/level7_kuaihuolin_short.gd", "id": "level7", "refs": ["wu", "shi", "menshen", "sign"], "arrays": {}},
	"level8": {"index": 7, "script": "res://scripts/levels/level8_daming_rts.gd", "id": "level8", "refs": ["hall", "strategist", "scout", "chai", "yue", "gate", "lu", "shi", "enemy_hq"], "arrays": {"workers": 6, "spies": 3, "posts": 2}}}
const MODE_FIELDS := ["skirmish", "skirmish_ai", "arena", "custom_defense", "scenario", "defense_random", "ai_friendly", "scale_on"]
var checks: Array = []
var failures: Array = []
var manifest: Dictionary = {}
var report_path := ""
var manifest_ready := false
var case_id := ""
var battle: Variant
var unit_script: Script
var seen_native: Dictionary = {}
var seen_stable: Dictionary = {}
var high_water := 0
var audit_issue := ""
var completed_ticks := 0
var samples: Array = []
var successful_actions: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _check(label: String, passed: bool) -> bool:
	checks.append({"label": label, "passed": passed})
	if not passed: failures.append(label)
	return passed

func _ok(label: String, result: Dictionary) -> bool:
	checks.append({"label": label, "passed": result.get("ok") == true, "code": result.get("code", "")})
	if result.get("ok") != true:
		failures.append(label)
		return false
	return true

func _guard(label: String) -> void:
	for path: String in manifest.source_sha256:
		_check(label + " " + path, FileAccess.get_sha256(path) == manifest.source_sha256[path])

func _finish(aborted := false) -> void:
	var fault: String = battle.gameplay_rng_fault() if is_instance_valid(battle) else ""
	if is_instance_valid(battle):
		if battle.is_inside_tree():
			battle.queue_free()
			await process_frame
			await process_frame
		else: battle.free()
	current_scene = null
	if manifest_ready: _guard("source after")
	var result := {"suite": "stable-identity-world-entry", "run_id": manifest.get("run_id", ""), "case_id": case_id,
		"complete": not aborted, "passed": failures.is_empty() and not aborted, "failures": failures,
		"checks": checks, "check_count": checks.size(), "failed_count": failures.size(), "process_id": OS.get_process_id(),
		"actual_user_dir": OS.get_user_data_dir(), "source_sha256": manifest.get("source_sha256", {}),
		"completed_physics_ticks": completed_ticks, "audit_issue": audit_issue, "samples": samples,
		"successful_actions": successful_actions, "observed_stable_entities": seen_stable.size(), "final_gameplay_fault": fault,
		"scope": "One actual main.tscn/Battle._ready with normal Campaign flags and authored map/deployment/on_start, at least 120 actual physics callbacks and every observed root/active Unit identity checked. Standard defense additionally pays and waits for one normal worker production; Lianhuanma uses actual mission action dispatch/path/wait twice for optional dummy creation and replacement. No stage skip, fixture-spawn, full campaign completion, 30-wave completion, restore, save slot, performance or human-playtest claim."}
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file == null:
			quit(1)
			return
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
	print("[stable-identity world-entry QA] ", JSON.stringify(result))
	quit(0 if result.passed else 1)

func _run() -> void:
	var path := OS.get_environment("RUN_RESTORE_QA_MANIFEST")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if not path.is_empty() else null
	if typeof(data) != TYPE_DICTIONARY:
		_check("host manifest", false)
		await _finish(true)
		return
	manifest = data
	for key: String in ["run_id", "private_user", "report", "case_id", "engine_binary_sha256"]:
		if typeof(manifest.get(key)) != TYPE_STRING or manifest[key].is_empty():
			_check("host field " + key, false)
			await _finish(true)
			return
	case_id = manifest.case_id
	if not CASES.has(case_id) or typeof(manifest.get("source_sha256")) != TYPE_DICTIONARY or manifest.source_sha256.is_empty():
		_check("case and source manifest", false)
		await _finish(true)
		return
	report_path = manifest.report
	if not report_path.is_absolute_path() or FileAccess.file_exists(report_path):
		_check("fresh absolute report", false)
		report_path = ""
		await _finish(true)
		return
	manifest_ready = true
	_check("private profile", OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower() == manifest.private_user.replace("\\", "/").simplify_path().to_lower())
	_guard("source before")
	# Host must isolate/sanitize before process launch; this driver never clears a
	# diagnostic flag after an autoload may already have acted on it.
	for key: String in ["SMOKE_TEST", "PERF_BENCH", "LEVEL", "SKIRMISH", "SKIRMISH_AI", "ARENA", "SCENARIO", "CUSTOM_DEFENSE", "DEF_RANDOM", "DEF_WAVES", "DEF_HEROES", "AI_FRIENDLY", "SCALE_ON", "ENEMY_MULT", "HERO_MULT", "AUTO_MICRO", "AUTOMICRO", "SCREENSHOT_DIR", "INFO_UI_TEST", "INFO_UI_TEST_DIR", "BUILD_TEST"]:
		_check("clean launch " + key, OS.get_environment(key).is_empty())
	_check("Steam native explicitly disabled", OS.get_environment("STEAM_DISABLED") == "1")
	var steam: Variant = root.get_node("SteamService")
	_check("test profile has no native Steam session", not steam.available and steam.native == null)
	if not failures.is_empty():
		await _finish(true)
		return
	var campaign: Variant = root.get_node("Campaign")
	for key: String in MODE_FIELDS: campaign.set(key, false)
	campaign.current = CASES[case_id].index
	campaign.skirmish = case_id == "defense30"
	campaign.defense_waves = 30
	campaign.defense_hero_cap = 4
	campaign.defense_rand_waves = 30
	campaign.defense_interval = 25.0
	campaign.custom_config = {}
	campaign.scenario_data = {}
	var settings: Variant = root.get_node("Settings")
	settings.game_speed = 1.0
	settings.auto_micro_level = 0
	unit_script = load("res://scripts/unit.gd")
	var scene: PackedScene = load("res://scenes/main.tscn")
	battle = scene.instantiate()
	# The same new-game API used by production _ready, configured before its normal
	# deployment to provide a repeatable QA seed; saved records are never supplied.
	var identity := {"ok": true, "save_eligible": true, "content_version": "identity_world_qa_v1", "engine_binary_sha256": manifest.engine_binary_sha256}
	if not _ok("new gameplay RNG API before normal ready", battle.configure_new_gameplay_rng(identity, 2026090700 + int(CASES[case_id].index))):
		await _finish(true)
		return
	root.add_child(battle)
	current_scene = battle
	if not _check("actual ready resolves exact official level", battle.is_node_ready() and is_instance_valid(battle.map) and is_instance_valid(battle.units_root) and battle.level.get_script().resource_path == CASES[case_id].script and battle.level.id() == CASES[case_id].id and battle.gameplay_rng_fault().is_empty()):
		await _finish(true)
		return
	_check("real world hierarchy and FX ordering", battle.is_ancestor_of(battle.units_root) and battle.units_root.get_parent() == battle.world and battle.fx_root.get_parent() == battle.world and battle.units_root.get_index() < battle.fx_root.get_index() and battle.fx_root.z_index == 3500)
	_check("official mode classified but test run never submits Steam", battle._official_context.mode == ("defense" if case_id == "defense30" else "campaign") and battle._steam_run_id == 0 and not steam.available)
	_check("authored mandatory deployment entities", _required())
	_check("all initial root and active IDs valid", _audit())
	_sample("deployed")
	# Same HUD handler/signals as advancing intro and pressing the real start button.
	var intro_steps := 0
	while battle.hud._intro_root.visible and intro_steps < 30:
		battle.hud._advance_intro()
		intro_steps += 1
	if battle.phase == battle.Phase.DEPLOY: battle.hud.start_btn.pressed.emit()
	if not _check("normal intro/start path reaches fight once", battle.phase == battle.Phase.FIGHT and battle.gameplay_rng_fault().is_empty()):
		await _finish(true)
		return
	_check("campaign mission exists only for official chapters", (battle.mission != null) == (case_id != "defense30"))
	if case_id == "level1": _check("chapter on_start really creates advancing convoy", is_instance_valid(battle.level.yang) and not battle.level.convoy.is_empty())
	if case_id == "defense30": _check("fixed classic wave state initialized", battle.level._started and battle.level._waves().size() == 30 and battle.level._wave == 0 and not campaign.defense_random)
	var initial_tick: int = battle._ai_tick_frame
	for step: int in range(122):
		await physics_frame
		if not _healthy_step(): break
	await process_frame
	completed_ticks = battle._ai_tick_frame - initial_tick
	_check("at least 120 real physics callbacks completed", completed_ticks >= 120)
	_check("every observed root and active Unit remained valid", audit_issue.is_empty() and _audit())
	_check("mandatory entities survive initial run", _required())
	_sample("after_120_physics")
	if case_id == "defense30" and failures.is_empty(): await _normal_production()
	if case_id == "level4" and failures.is_empty(): await _normal_dummy_replacement()
	_check("final scene remains healthy fight without fixture victories", battle.phase == battle.Phase.FIGHT and battle.gameplay_rng_fault().is_empty() and not paused)
	_check("observed global allocator never regressed or reused", audit_issue.is_empty() and _audit())
	_sample("final")
	await _finish()

func _valid_unit(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT and is_instance_valid(value) and value.get_script() == unit_script and battle.units.has(value) and value.hp > 0.0

func _required() -> bool:
	for field: String in CASES[case_id].refs:
		if not _valid_unit(battle.level.get(field)): return false
	for field: String in CASES[case_id].arrays:
		var rows: Variant = battle.level.get(field)
		if typeof(rows) != TYPE_ARRAY or rows.size() < CASES[case_id].arrays[field]: return false
		for value: Variant in rows:
			if not _valid_unit(value): return false
	if case_id == "defense30":
		for key: String in ["gold_mine", "stockade_gate", "lou_luo", "liang_dao", "tree"]:
			if battle.count_alive(0, key) < {"gold_mine": 1, "stockade_gate": 2, "lou_luo": 5, "liang_dao": 2, "tree": 16}[key]: return false
	if case_id == "level5":
		for field: String in ["water_groups", "land_groups"]:
			var groups: Array = battle.level.get(field)
			if groups.size() != 3: return false
			for group: Array in groups:
				if group.is_empty(): return false
				for u: Variant in group:
					if not _valid_unit(u): return false
	if case_id == "level7":
		if battle.level.taverns.size() != 4: return false
		for row: Dictionary in battle.level.taverns:
			if not _valid_unit(row.u): return false
	return true

func _audit() -> bool:
	if not audit_issue.is_empty(): return false
	if not is_instance_valid(battle) or not battle.gameplay_rng_fault().is_empty(): audit_issue = "BATTLE_FAULT"; return false
	var next_id: Variant = battle.next_entity_id
	if typeof(next_id) != TYPE_INT or next_id <= 0 or next_id < high_water: audit_issue = "ALLOCATOR_REGRESSION"; return false
	high_water = next_id
	var root_nodes: Dictionary = {}
	var ids: Dictionary = {}
	for u: Variant in battle.units_root.get_children(true):
		if not is_instance_valid(u) or u.get_script() != unit_script: audit_issue = "ROOT_NON_UNIT"; return false
		var eid: Variant = u.entity_id
		if typeof(eid) != TYPE_INT or eid <= 0 or eid >= next_id or ids.has(eid): audit_issue = "ROOT_ID_BOUNDS_OR_DUPLICATE"; return false
		if u.battle != battle or u.map != battle.map: audit_issue = "UNIT_OWNER"; return false
		var native_id: int = u.get_instance_id() # Test observer only; no production scheduling use.
		if seen_native.has(native_id) and seen_native[native_id] != eid: audit_issue = "ENTITY_FIELD_CHANGED"; return false
		if seen_stable.has(eid) and seen_stable[eid] != native_id: audit_issue = "STABLE_ID_REUSED"; return false
		seen_native[native_id] = eid
		seen_stable[eid] = native_id
		root_nodes[u] = true
		ids[eid] = true
	var active: Dictionary = {}
	for u: Variant in battle.units:
		if not is_instance_valid(u) or not root_nodes.has(u) or active.has(u): audit_issue = "ACTIVE_MEMBERSHIP"; return false
		active[u] = true
	return not root_nodes.is_empty() and not active.is_empty()

func _healthy_step() -> bool:
	return _audit() and not paused and battle.phase == battle.Phase.FIGHT

func _sample(label: String) -> void:
	samples.append({"label": label, "root_units": battle.units_root.get_child_count(true), "active_units": battle.units.size(),
		"next_entity_id_decimal": str(battle.next_entity_id), "battle_physics_counter": battle._ai_tick_frame, "phase": battle.phase,
		"gameplay_fault": battle.gameplay_rng_fault(), "map_size": [battle.map.w, battle.map.h]})

func _normal_production() -> void:
	var hall: Variant = battle.level.hall
	var before_count: int = battle.count_alive(0, "lou_luo")
	var issued_after: int = battle.next_entity_id
	var gold_before: int = battle.gold
	var wood_before: int = battle.wood
	var expected_gold: int = int(battle._defs.lou_luo.get("cost_gold", 0))
	var expected_wood: int = int(battle._defs.lou_luo.get("cost_wood", 0))
	if not _check("normal hall accepts paid worker queue", battle.queue_train(hall, "lou_luo")):
		return
	_check("worker queue charges exact current costs", battle.gold == gold_before - expected_gold and battle.wood == wood_before - expected_wood and hall._train_queue == ["lou_luo"])
	var start_tick: int = battle._ai_tick_frame
	for step: int in range(1800):
		await physics_frame
		if not _healthy_step() or hall._train_queue.is_empty(): break
	await process_frame
	var matches: Array = battle.units.filter(func(u): return is_instance_valid(u) and u.key == "lou_luo" and u.faction == 0 and u.entity_id >= issued_after)
	_check("normal production timer yields exactly one fresh positive-ID worker", hall._train_queue.is_empty() and battle.count_alive(0, "lou_luo") == before_count + 1 and matches.size() == 1 and matches[0].entity_id >= issued_after and not hall.production_blocked)
	successful_actions.production = {"kind": "paid_worker", "actual_wait_physics": battle._ai_tick_frame - start_tick, "new_ids": matches.map(func(u): return str(u.entity_id)), "cost_gold": expected_gold, "cost_wood": expected_wood}

func _normal_dummy_replacement() -> void:
	var prior: Variant = null
	var prior_id := 0
	var allocated_ids: Array = []
	var first_tick: int = battle._ai_tick_frame
	for pass_index: int in range(2):
		if not _check("real optional drill action accepted " + str(pass_index), battle.mission.request_action("lhm_drill_reset")): return
		for step: int in range(1800):
			await physics_frame
			if not _healthy_step(): break
			if is_instance_valid(battle.level.dummy) and battle.level.dummy != prior: break
		await process_frame
		var now: Variant = battle.level.dummy
		if not _check("real mission dispatch creates/replaces drill Unit " + str(pass_index), _valid_unit(now) and now != prior and now.entity_id > prior_id and battle.mission.active_action_id.is_empty()): return
		if pass_index == 1: _check("successful replacement releases original and removes active membership", not is_instance_valid(prior) and not battle.units.has(prior))
		prior = now
		prior_id = now.entity_id
		allocated_ids.append(str(prior_id))
	successful_actions.replacement = {"kind": "actual_optional_drill_twice", "actual_wait_physics": battle._ai_tick_frame - first_tick, "successive_ids": allocated_ids, "orders_dispatched": 2}
