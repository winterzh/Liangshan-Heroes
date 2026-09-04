extends SceneTree
## Runtime contract for Lu Zhishen's weapon identity.  It covers the shared
## free-mode definition and the Wild Boar Forest rescue override without
## touching art assets or player state.

const REPORT_PATH := "res://qa/lu_zhishen_iron_staff_20260902/runtime_report.json"

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var _unit_script = null
var _battle_script = null
var _level6_script = null
var _defs_script = null


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, details: Variant = null) -> void:
	checks.append({"name": name, "passed": passed, "details": details})
	print("[lu-iron-staff] ", "PASS " if passed else "FAIL ", name,
		"" if details == null else " :: " + JSON.stringify(details))
	if not passed:
		failures.append(name)


func _make_lu(definition: Dictionary, variant := ""):
	var unit = _unit_script.new()
	unit.setup("lu_zhishen", definition.duplicate(true), _unit_script.FACTION_LIANG, null, null)
	if variant != "":
		unit.art_variant = variant
	root.add_child(unit)
	unit.set_physics_process(false)
	return unit


func _stop_test_audio() -> void:
	for autoload_name in ["Sfx", "Music"]:
		var audio_root := root.get_node_or_null(autoload_name)
		if audio_root == null:
			continue
		audio_root.set("enabled", false)
		for child in audio_root.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream = null


func _exercise_free_mode(mode: String, campaign: Node) -> void:
	for flag in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(flag, false)
	campaign.set(mode, true)
	if mode == "custom_defense":
		campaign.custom_config = {"name": "鲁智深兵器契约夹具"}
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	var mode_def: Dictionary = battle._defs.get("lu_zhishen", {})
	var unit = battle.spawn_unit("lu_zhishen", _unit_script.FACTION_LIANG,
		battle.map.cell_to_world(Vector2i(8, 8))) if not mode_def.is_empty() else null
	_check(mode + " keeps iron_staff definition",
		String(mode_def.get("weapon_profile", "")) == "iron_staff",
		{"actual": mode_def.get("weapon_profile", "")})
	_check(mode + " real spawned Lu Zhishen resolves IRON_STAFF",
		unit != null and unit._weapon_kind() == _unit_script.WK.IRON_STAFF and unit.art_variant == "",
		{"weapon_kind": unit._weapon_kind() if unit != null else -1,
			"art_variant": unit.art_variant if unit != null else "missing"})
	current_scene = null
	battle.queue_free()
	await process_frame
	await process_frame


func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	AudioServer.set_bus_mute(0, true)
	_stop_test_audio()
	# Direct --script parsing happens before autoload references are ready.  Load
	# production scripts on the deferred frame, matching normal project startup.
	_unit_script = load("res://scripts/unit.gd")
	_battle_script = load("res://scripts/battle.gd")
	_level6_script = load("res://scripts/levels/level6_yezhulin.gd")
	_defs_script = load("res://scripts/defs.gd")
	var load_ok: bool = _unit_script != null and _battle_script != null \
		and _level6_script != null and _defs_script != null \
		and _unit_script.can_instantiate() and _battle_script.can_instantiate() \
		and _level6_script.can_instantiate() and _defs_script.can_instantiate()
	_check("production Unit/Battle/Defs/level6 scripts instantiate", load_ok)
	if not load_ok:
		quit(1)
		return
	var unit_definitions: Dictionary = _defs_script.UNITS
	var ability_definitions: Dictionary = _defs_script.ABILITIES
	var original_def: Dictionary = unit_definitions["lu_zhishen"]
	_check("central definition declares exact iron_staff profile",
		String(original_def.get("weapon_profile", "")) == "iron_staff",
		{"actual": original_def.get("weapon_profile", "")})

	var generic = _make_lu(original_def)
	_check("free-mode Lu Zhishen resolves IRON_STAFF",
		generic._weapon_kind() == _unit_script.WK.IRON_STAFF,
		{"actual_kind": generic._weapon_kind(), "iron_staff_kind": _unit_script.WK.IRON_STAFF})
	_check("free-mode Lu Zhishen keeps generic art variant", generic.art_variant == "",
		{"actual_variant": generic.art_variant})
	_check("iron staff uses dedicated attack sound route", generic._attack_sfx_name() == "atk_staff",
		{"actual": generic._attack_sfx_name()})

	# Exercise the actual attack entry point: a 30 px range must not infer SPEAR,
	# and the old AXE timing must not leak through the weapon cache.
	var target = _unit_script.new()
	target.key = "weapon_contract_target"
	target.position = Vector2(24.0, 0.0)
	root.add_child(target)
	target.set_physics_process(false)
	generic.position = Vector2.ZERO
	generic._target = target
	generic._weapon = -1
	generic._attack()
	_check("basic attack starts iron-staff swing", generic._swing_kind == _unit_script.WK.IRON_STAFF,
		{"actual_kind": generic._swing_kind})
	_check("iron-staff timing is separate from axe and spear",
		is_equal_approx(generic._swing_speed, 1.9) and is_equal_approx(generic._hit_at, 0.38),
		{"speed": generic._swing_speed, "hit_at": generic._hit_at})
	_check("iron staff is neither axe nor spear",
		generic._swing_kind not in [_unit_script.WK.AXE, _unit_script.WK.SPEAR],
		{"actual_kind": generic._swing_kind})

	var level_defs: Dictionary = unit_definitions.duplicate(true)
	var level_abilities: Dictionary = ability_definitions.duplicate(true)
	var level6 = _level6_script.new()
	level6.apply_overrides(level_defs, level_abilities)
	var rescue_def: Dictionary = level_defs["lu_zhishen"]
	_check("Wild Boar Forest override preserves iron_staff",
		String(rescue_def.get("weapon_profile", "")) == "iron_staff"
		and String(rescue_def.get("art_variant", "")) == "lu_zhishen_rescue",
		{"weapon_profile": rescue_def.get("weapon_profile", ""), "art_variant": rescue_def.get("art_variant", "")})
	var rescue = _make_lu(rescue_def)
	_check("rescue variant resolves IRON_STAFF", rescue._weapon_kind() == _unit_script.WK.IRON_STAFF,
		{"actual_kind": rescue._weapon_kind(), "variant": rescue.art_variant})
	_check("campaign override does not mutate shared free-mode definition",
		not unit_definitions["lu_zhishen"].has("art_variant")
		and String(unit_definitions["lu_zhishen"].get("weapon_profile", "")) == "iron_staff")

	# Old custom/free-mode dictionaries that predate weapon_profile still receive
	# the key fallback, preserving compatibility with existing setups.
	var legacy_def := original_def.duplicate(true)
	legacy_def.erase("weapon_profile")
	var legacy = _make_lu(legacy_def)
	_check("legacy custom definition keeps iron-staff key fallback",
		legacy._weapon_kind() == _unit_script.WK.IRON_STAFF,
		{"actual_kind": legacy._weapon_kind()})

	_check("Lu sweep selects dedicated iron-staff effect",
		String(_battle_script.ABILITY_FX.get("lu_sweep", "")) == "iron_staff",
		{"actual": _battle_script.ABILITY_FX.get("lu_sweep", "")})
	var staff_fx = _battle_script.IronStaffSweepFx.new()
	_check("dedicated iron-staff effect class instantiates",
		staff_fx != null and is_equal_approx(float(staff_fx.rad), 110.0))
	root.add_child(staff_fx)
	staff_fx.set_process(false)
	staff_fx.queue_redraw()
	await process_frame
	_check("dedicated iron-staff effect completes a real draw cycle", staff_fx.is_inside_tree())
	staff_fx.free()

	# All four free-play routes duplicate the same central definitions, but run
	# them through different LevelBase implementations.  Instantiate each real
	# mode and a real Lu Zhishen unit so no mode-local override can regress him.
	var campaign := root.get_node("Campaign")
	var flag_before := {}
	for flag in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		flag_before[flag] = campaign.get(flag)
	var current_before = campaign.current
	var custom_before: Dictionary = campaign.custom_config.duplicate(true)
	campaign.current = campaign.index_for_id("level8")
	for mode in ["arena", "skirmish", "skirmish_ai", "custom_defense"]:
		await _exercise_free_mode(mode, campaign)
	for flag in flag_before:
		campaign.set(flag, flag_before[flag])
	campaign.current = current_before
	campaign.custom_config = custom_before

	var report_dir := REPORT_PATH.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
	var report := {
		"passed": failures.is_empty(),
		"check_count": checks.size(),
		"failure_count": failures.size(),
		"failures": failures,
		"checks": checks,
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	_stop_test_audio()
	for node in [generic, target, rescue, legacy]:
		if is_instance_valid(node):
			node.free()
	print("[lu-iron-staff] RESULT ", JSON.stringify({"passed": failures.is_empty(),
		"checks": checks.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
