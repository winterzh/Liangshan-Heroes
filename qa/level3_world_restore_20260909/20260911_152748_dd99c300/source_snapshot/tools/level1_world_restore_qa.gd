extends Node
## Component QA: Level 1 Huangnigang official profile + factory restore_level.
## Not a full Core/Session world install; unit-graph membership for level1 is next.
const B := preload("res://scripts/battle.gd")
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Factory := preload("res://scripts/run_level1_world_factory.gd")
const Provider := preload("res://scripts/run_content_identity.gd")
const LevelState := preload("res://scripts/run_campaign_level_state.gd")
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
	check("external signs present for capture", ext_i >= 1)
	var mission_token := "mission:level1:core"
	var captured: Dictionary = LevelState.new().capture(battle.level, "level1",
		trusted.content_version, id_to_unit, battle.next_entity_id, external_to_token,
		{"mission_token": mission_token, "deferred_drained": true})
	if not check("LevelState.capture level1", captured.get("ok", false)):
		print("CAPTURE: ", captured)
		battle.queue_free(); finish(); return
	# Restore into a fresh Level instance (no deploy/on_start).
	var restored: Dictionary = Factory.restore_level(captured.record, trusted, id_to_unit, battle.next_entity_id, mission_token)
	if not check("factory.restore_level", restored.get("ok", false)):
		print("RESTORE: ", restored)
		battle.queue_free(); finish(); return
	var lvl = restored.level
	check("script identity", lvl.get_script() == Huang)
	check("delivered preserved", lvl.delivered == 1)
	check("drug_done preserved", lvl.drug_done == true)
	check("deploy not replayed", restored.get("deploy_or_start_called", false) == false)
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
