extends SceneTree
## Campaign-variant isolation across every current game mode.

const MODES := ["campaign", "arena", "skirmish", "skirmish_ai", "custom_defense", "scenario", "campaign_return"]
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const STATES := ["idle", "walk", "attack", "hurt", "down"]
const UNIT_KEY := "jiang_menshen"
const VARIANT := "jiang_menshen_fists"

var checks: Array = []
var failures: Array[String] = []
var snapshots: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[jiang-menshen-modes] ", "PASS " if passed else "FAIL ", name,
		"" if detail == null else " :: " + JSON.stringify(detail))
	if not passed: failures.append(name)


func _source(texture: Texture2D) -> String:
	if texture == null: return ""
	return texture.atlas.resource_path if texture is AtlasTexture and texture.atlas != null else texture.resource_path


func _configure_mode(mode: String) -> void:
	var campaign = root.get_node("Campaign")
	for key in ["arena", "skirmish", "skirmish_ai", "custom_defense", "scenario"]:
		campaign.set(key, false)
	campaign.custom_config = {}
	campaign.scenario_data = {}
	campaign.ai_friendly = false
	campaign.scale_on = false
	if mode in ["campaign", "campaign_return"]:
		campaign.current = campaign.index_for_id("level7")
	else:
		campaign.set(mode, true)
	if mode == "custom_defense":
		campaign.custom_config = {"name": "蒋门神隔离检查", "waves": []}
	if mode == "scenario":
		campaign.scenario_data = {
			"id": "jiang_menshen_isolation_scenario",
			"title": "造型隔离检查",
			"subtitle": "不得读取快活林专用蒋门神",
			"map": {"w": 48, "h": 48, "theme": "marsh", "base": "GRASS"},
			"camera_start": [24, 24], "deploy": [],
			"intro": [{"who": "旁白", "key": "narrator", "text": "造型隔离检查。"}],
		}


func _expected_level(mode: String) -> String:
	return String({
		"campaign": "level7", "campaign_return": "level7", "arena": "arena",
		"skirmish": "skirmish", "skirmish_ai": "skirmish_ai",
		"custom_defense": "custom_defense", "scenario": "jiang_menshen_isolation_scenario",
	}.get(mode, ""))


func _snapshot_sources(art: Node, variant: String) -> Dictionary:
	var result := {}
	for state in STATES:
		for direction in DIRECTIONS:
			var frames: Array = art.unit_anim_frames(UNIT_KEY, state, direction, variant)
			result[state + "|" + direction] = _source(frames[0]) if not frames.is_empty() else ""
	return result


func _release_battle_cursor_textures(battle) -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	for property in ["_target_cursor", "_cur_attack", "_cur_gather_wood", "_cur_gather_gold", "_cur_repair", "_cur_select", "_cur_garrison"]:
		battle.set(property, null)


func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	AudioServer.set_bus_mute(0, true)
	var art := root.get_node("Art")
	var first_campaign_sources := {}
	for mode in MODES:
		_configure_mode(mode)
		var battle = load("res://scenes/main.tscn").instantiate()
		root.add_child(battle)
		current_scene = battle
		await process_frame
		_check(mode + " opens expected level", String(battle.level.id()) == _expected_level(mode), String(battle.level.id()))
		var variant_units: Array = battle.units.filter(func(unit): return is_instance_valid(unit) and unit.art_variant == VARIANT)
		var generic_sources := _snapshot_sources(art, "")
		_check(mode + " generic cache never points into campaign directory",
			generic_sources.values().all(func(path): return String(path).is_empty() or not String(path).begins_with("res://assets/campaign/")),
			generic_sources)
		if mode in ["campaign", "campaign_return"]:
			_check(mode + " deploys exactly one campaign Jiang Zhong", variant_units.size() == 1 and variant_units[0].key == UNIT_KEY, variant_units.size())
			if not variant_units.is_empty():
				_check(mode + " starts alive and unresolved", variant_units[0].hp > 0.0 and variant_units[0].story_outcome == "")
				_check(mode + " keeps living subdued outcome", variant_units[0].defeat_outcome == "subdued")
			var campaign_sources := _snapshot_sources(art, VARIANT)
			_check(mode + " has all twenty exact campaign sources",
				campaign_sources.values().all(func(path): return String(path).begins_with("res://assets/campaign/anim/jiang_menshen_fists_")),
				campaign_sources)
			if mode == "campaign": first_campaign_sources = campaign_sources
			else: _check("campaign return sources equal first campaign after all warmed caches", campaign_sources == first_campaign_sources)
		else:
			_check(mode + " has no campaign Jiang Zhong instance", variant_units.is_empty(), variant_units.size())
		snapshots.append({"mode": mode, "level": String(battle.level.id()), "campaign_variant_units": variant_units.size(), "generic_sources": generic_sources})
		var scene_ref: WeakRef = weakref(battle)
		_release_battle_cursor_textures(battle)
		current_scene = null
		battle.queue_free()
		await process_frame
		await process_frame
		_check(mode + " scene is freed", scene_ref.get_ref() == null)

	var output := OS.get_environment("JIANG_MENSHEN_MODE_ISOLATION_REPORT")
	if output.is_empty(): output = "res://qa/jiang_menshen_direction4_production_20260902/runtime_modes.json"
	var absolute := ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var report := {
		"passed": failures.is_empty(), "checks": checks.size(), "failures": failures,
		"modes": MODES, "snapshots": snapshots,
		"scope": "Real scene construction for campaign, arena, skirmish, AI skirmish, custom defense, scenario, then campaign return. Verifies variant/cache/state isolation; not combat, balance, visual or performance evidence.",
		"checks_detail": checks,
	}
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("JIANG_MENSHEN_MODE_ISOLATION_RESULT ", JSON.stringify(report))
	for unused in range(3): await process_frame
	quit(0 if failures.is_empty() else 1)
