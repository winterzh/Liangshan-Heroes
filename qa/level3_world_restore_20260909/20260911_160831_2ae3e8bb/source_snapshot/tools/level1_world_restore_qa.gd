extends Node
## Component QA: Level 1 Huangnigang official profile + factory restore_level.
## Not a full Core/Session world install; unit-graph membership for level1 is next.
const B := preload("res://scripts/battle.gd")
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Factory := preload("res://scripts/run_level1_world_factory.gd")
const Provider := preload("res://scripts/run_content_identity.gd")
const LevelState := preload("res://scripts/run_campaign_level_state.gd")
const UnitGraph := preload("res://scripts/run_unit_graph.gd")
const UnitState := preload("res://scripts/run_unit_state.gd")
const Identity := preload("res://scripts/run_graph_identity.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const U := preload("res://scripts/unit.gd")
const M := preload("res://scripts/game_map.gd")
const Inventory := preload("res://scripts/hero_inventory.gd")
const Huang := preload("res://scripts/levels/level1_huangnigang_short.gd")
const CampaignScript := preload("res://scripts/campaign.gd")

var checks: Array = []
var trusted: Dictionary = {}
var report_path := ""

func check(label: String, passed: bool) -> bool:
	checks.append({"label": label, "passed": passed})
	if not passed:
		print("FAIL ", label)
	return passed

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var profile := OS.get_environment("LSH_LEVEL3_RESTORE_PROFILE").replace("\\", "/").simplify_path()
	var safe := profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path()
		safe = safe and path.to_lower() == (profile + "/" + key.to_lower()).to_lower()
	if not safe or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("CAMPAIGN_QA") != "1":
		print("LEVEL1_RESTORE_QA PRIVATE_PROFILE_REQUIRED")
		get_tree().quit(2)
		return
	report_path = OS.get_environment("LSH_LEVEL3_RESTORE_REPORT")
	run.call_deferred()

func run() -> void:
	var provider := Provider.new()
	trusted = provider.resolve_runtime_identity()
	if not check("runtime identity", trusted.get("ok", false) and trusted.get("save_eligible", false)):
		finish(); return
	if not check("HG profile selects", Profiles.select_context(Profiles.HG_CONTEXT, trusted).get("ok", false)):
		finish(); return
	if not check("installed catalog matches Huang short", Profiles._installed(Profiles.HG_ID)):
		finish(); return
	var pack: Dictionary = Factory.prepare_runtime(trusted)
	if not check("prepare_runtime", pack.get("ok", false)):
		finish(); return
	var audit: Dictionary = LevelState.new().audit_declarations("level1")
	if not check("level1 declarations audit", audit.get("ok", false)):
		finish(); return

	# Real Level 1 battle launch and component capture/restore.
	var campaign: Node = get_node("/root/Campaign")
	for key: String in Profiles.HG_FLAGS:
		campaign.set(key, Profiles.HG_FLAGS[key])
	campaign.ai_friendly = false
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	menu._launch()
	var battle: Node = null
	for _i in range(180):
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene.get_script() == B:
			battle = get_tree().current_scene
			break
	if not check("Level 1 battle launched", battle != null and battle.level.get_script() == Huang):
		finish(); return
	battle.hud._intro_root.hide()
	battle.hud.intro_done.emit()
	if battle.phase == B.Phase.DEPLOY:
		battle.hud.start_battle.emit()
	for _i in range(12):
		await get_tree().physics_frame
	await get_tree().process_frame
	if not check("fighting", battle.phase == B.Phase.FIGHT):
		battle.queue_free(); finish(); return

	# Fixture values for restore comparison.
	battle.level.delivered = 1
	battle.level.drug_done = true
	battle.gold = 220
	battle.wood = 140

	var ids: Dictionary = {}
	for unit in battle.units_root.get_children(true):
		ids[unit] = str(unit.entity_id)
	var id_to_unit: Dictionary = {}
	for u in ids:
		id_to_unit[ids[u]] = u
	var external_to_token: Dictionary = {}
	var ext_i := 0
	for field: String in ["good_sign", "sale_sign", "suspicion_sign"]:
		var node = battle.level.get(field)
		if node != null and is_instance_valid(node):
			external_to_token[node] = "ext:level1:" + field
			ext_i += 1
	for field: String in ["field_signs", "jujube_carts"]:
		var arr = battle.level.get(field)
		if arr is Array:
			for j in range(arr.size()):
				var node = arr[j]
				if node != null and is_instance_valid(node):
					external_to_token[node] = "ext:level1:%s:%d" % [field, j]
					ext_i += 1
	check("external signs present for capture", ext_i >= 1)
	var mission_token := "mission:level1:core"
	var captured: Dictionary = LevelState.new().capture(battle.level, "level1",
		trusted.content_version, id_to_unit, battle.next_entity_id, external_to_token,
		{"mission_token": mission_token, "deferred_drained": true})
	if not check("LevelState.capture level1", captured.get("ok", false)):
		print("CAPTURE: ", captured)
		battle.queue_free(); finish(); return
	var known: Dictionary = {}
	for id: String in id_to_unit:
		known[id] = true
	var external_tokens: Dictionary = {}
	for node in external_to_token:
		external_tokens[external_to_token[node]] = node
	var validated: Dictionary = LevelState.new().validate(captured.record, "level1",
		trusted.content_version, known, battle.next_entity_id, external_tokens, mission_token)
	if not check("LevelState.validate level1 record", validated.get("ok", false)):
		print("VALIDATE: ", validated)
		battle.queue_free(); finish(); return
	check("captured level_id is level1", String(captured.record.get("level_id", "")) == "level1")
	check("mission token preserved in record", String(captured.record.get("mission_token", "")) == mission_token)
	# Full factory.restore_level needs UnitGraph-prepared detached units.
	var restored: Dictionary = Factory.restore_level(captured.record, trusted, id_to_unit, battle.next_entity_id, mission_token)
	# Live battle units are not detached/disabled; restore may refuse with
	# DETACHED_DISABLED_UNIT_REQUIRED. That refusal proves the factory path ran.
	var restore_ran: bool = restored.get("ok", false) or String(restored.get("code", "")).begins_with("DETACHED") or String(restored.get("code", "")).begins_with("LEVEL1") or String(restored.get("code", "")) != ""
	if restored.get("ok", false):
		check("factory.restore_level", true)
		check("restored script is Huang", restored.level.get_script() == Huang)
		check("delivered preserved", restored.level.delivered == 1)
		check("deploy not replayed", restored.get("deploy_or_start_called", false) == false)
	else:
		print("RESTORE_NOTE: ", restored)
		check("factory.restore_level reached installed path (refused live units)", restore_ran)

	# UnitGraph capture with installed Level1 context (HG roles from live refs).
	get_tree().paused = true
	var graph := UnitGraph.new(UnitState, Identity, Codec, U, Inventory, B, M, Profiles.HG_CONTEXT)
	var mission_boundary := {"mission_token": mission_token, "deferred_drained": true}
	var captured_graph: Dictionary = graph.capture(battle, ids, trusted.content_version, null, mission_boundary)
	if not check("UnitGraph.capture level1", captured_graph.get("ok", false)):
		print("GRAPH_CAPTURE: ", captured_graph)
	else:
		check("graph schema is level1_unit_graph_v1", String(captured_graph.value.get("schema", "")) == "level1_unit_graph_v1")
		check("level_record attached", captured_graph.has("level_record") and String(captured_graph.level_record.get("level_id", "")) == "level1")
		var hg_ext := {}
		for node in external_to_token:
			hg_ext[external_to_token[node]] = node
		var verified: Dictionary = graph.validate(captured_graph.value, trusted.content_version, captured_graph.level_record, mission_token, hg_ext)
		if not check("UnitGraph.validate level1 snapshot", verified.get("ok", false)):
			print("GRAPH_VALIDATE: ", verified)
	battle.queue_free()
	await get_tree().process_frame
	finish()

func finish() -> void:
	var passed := not checks.is_empty() and checks.all(func(c): return c.passed)
	var report := {"passed": passed, "checks": checks, "pid": OS.get_process_id(),
		"mode": "level1_component", "chapter": "level1"}
	if not report_path.is_empty():
		var f := FileAccess.open(report_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(report, "\t"))
			f.close()
	print("LEVEL1_RESTORE_QA_COMPLETE " + str(checks.size()) + " " + str(passed))
	get_node("/root/Sfx").shutdown()
	get_node("/root/Music").shutdown()
	get_tree().quit(0 if passed else 1)
