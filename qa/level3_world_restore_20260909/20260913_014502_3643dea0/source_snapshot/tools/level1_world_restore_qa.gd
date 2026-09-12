extends Node
## Level 1 component capture and actual Core/Session world installation.
const B := preload("res://scripts/battle.gd")
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Factory := preload("res://scripts/run_level1_world_factory.gd")
const Provider := preload("res://scripts/run_content_identity.gd")
const LevelState := preload("res://scripts/run_campaign_level_state.gd")
const UnitGraph := preload("res://scripts/run_unit_graph.gd")
const UnitState := preload("res://scripts/run_unit_state.gd")
const Identity := preload("res://scripts/run_graph_identity.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const Session := preload("res://scripts/run_world_session.gd")
const Store := preload("res://scripts/run_slot_store.gd")
const U := preload("res://scripts/unit.gd")
const M := preload("res://scripts/game_map.gd")
const Inventory := preload("res://scripts/hero_inventory.gd")
const Huang := preload("res://scripts/levels/level1_huangnigang_short.gd")
const CampaignScript := preload("res://scripts/campaign.gd")

var checks: Array = []
var trusted: Dictionary = {}
var report_path := ""
var held := false
var rejected := ""

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
	var restore_ran: bool = restored.get("code") == "DETACHED_DISABLED_UNIT_REQUIRED"
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
	for u in battle.units_root.get_children(true):
		if u == null or not is_instance_valid(u):
			continue
		var sd = u.get("setup_def")
		if typeof(sd) == TYPE_DICTIONARY:
			for k in sd:
				if typeof(k) != TYPE_STRING:
					print("GRAPH_SETUP_DEF_BAD_KEY unit=", u.name, " key_type=", typeof(k), " key=", k)
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

	# Full Session save_held / prepare_restore / commit for Level 1.
	await test_full_session_save_restore(battle, pack)
	battle = null
	await get_tree().process_frame
	finish()

func _pause_save(battle: Node, runtime: Dictionary, slot_root: String) -> Dictionary:
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
	return session.save_held(battle)

func test_full_session_save_restore(battle: Node, pack: Dictionary) -> void:
	var runtime: Dictionary = pack.runtime
	var slot_root := "user://continue/v1"
	# Mutate while unpaused so the battle clock is live, then freeze for capture.
	get_tree().paused = false
	for _i in range(12):
		await get_tree().physics_frame
	await get_tree().process_frame
	battle.level.delivered = 2
	battle.level.clean_trial = true
	battle.gold = 300
	battle.wood = 200
	battle._official_context = Profiles.HG_CONTEXT.duplicate(true)
	battle._save_barrier.configure(battle, battle._run_clock, Profiles.HG_CONTEXT)
	battle._save_barrier.capture_ready.connect(func(_c): held = true)
	battle._save_barrier.capture_rejected.connect(func(c): rejected = String(c))
	var saved: Dictionary = await _pause_save(battle, runtime, slot_root)
	if not saved.get("ok", false):
		print("SESSION_SAVE: ", saved)
		if battle._save_barrier != null:
			print("SESSION_BARRIER state=", battle._save_barrier.state, " health=", battle._save_barrier.health())
		check("Session.save_held level1", false)
		return
	check("Session.save_held level1", true)
	var store := Store.new(slot_root)
	var read_res: Dictionary = store.read_slot()
	if not check("slot readable after level1 save", read_res.ok):
		return
	check("slot context is HG", read_res.document.context == Profiles.HG_CONTEXT)
	check("slot profile is level1", String(read_res.document.world.profile.get("id", "")) == Profiles.HG_ID)
	battle.queue_free()
	await get_tree().process_frame
	battle = null
	# Fresh menu + restore.
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	get_tree().paused = true
	var session := Session.new(trusted, runtime, slot_root)
	var prepared: Dictionary = session.prepare_restore(menu)
	if not check("Session.prepare_restore level1", prepared.get("ok", false)):
		print("SESSION_PREPARE: ", prepared)
		return
	var committed: Dictionary = await session.commit_restore_async()
	if not check("Session.commit_restore level1", committed.get("ok", false)):
		print("SESSION_COMMIT: ", committed)
		return
	var restored_battle: Node = committed.battle
	check("restored level is Huang", restored_battle.level.get_script() == Huang)
	check("delivered restored", restored_battle.level.delivered == 2)
	check("clean_trial restored", restored_battle.level.clean_trial == true)
	check("economy restored", restored_battle.gold == 300 and restored_battle.wood == 200)
	check("still fighting after level1 restore", restored_battle.phase == B.Phase.FIGHT)
	session.dispose()
	restored_battle = await test_dead_carrier_save_restore(restored_battle, runtime)
	if is_instance_valid(restored_battle): restored_battle.queue_free()
	await get_tree().process_frame

func test_dead_carrier_save_restore(battle: Node, runtime: Dictionary) -> Node:
	# Component boundary fixture only: place an actor beside an original load,
	# select the cargo stage and advance its real mission timer explicitly. This
	# is neither a natural route nor one of the six cross-process checkpoints.
	get_tree().paused = true
	var level: Variant = battle.level
	var carrier: Variant = battle.find_unit("chao_gai")
	var bundle: Variant = level.bundles[0]
	if not check("death-drop fixture has live carrier and original load", is_instance_valid(carrier) and is_instance_valid(bundle) and carrier.hp > 0.0 and carrier.story_outcome == ""):
		return battle
	level.st = level.CARRY
	level.drug_done = true
	level.delivered = 0
	level.cargo.clear()
	level.force_attempts.clear()
	level._begin_cargo_choice(battle)
	var action_id := "force_take_0_0"
	if not check("death-drop fixture has real pickup action", battle.mission.actions.has(action_id)):
		return battle
	carrier.position = battle.map.cell_to_world(level._bundle_claim_cell(battle, 0))
	battle.map.sync_render_position(carrier)
	battle.select_members([carrier], false)
	battle.minimap_order(battle.map.cell_to_world(battle.mission.actions[action_id].cell), false)
	print("DEATH_DROP_ORDER actor=", carrier.key, " position=", carrier.position, " intent=", carrier.mission_order_active, " target=", carrier.mission_order_target, " action=", battle.mission.actions[action_id])
	battle.mission.tick(0.7)
	if not check("death-drop fixture real mission pickup retains original load", level.cargo.get(0) == carrier and carrier.get_meta("carrying_tribute", -1) == 0 and not battle.units.has(bundle) and not bundle.visible and bundle.get_parent() == battle.units_root):
		print("DEATH_DROP_PICKUP active=", battle.mission.active_action_id, " progress=", battle.mission._progress, " cargo=", level.cargo, " action=", battle.mission.actions[action_id], " position=", carrier.position)
		return battle
	var carrier_id: int = carrier.entity_id
	var bundle_id: int = bundle.entity_id
	# Same production take_damage path used by the existing Huang short death
	# fixture. Pause stays set so the 1.4-second death strip cannot expire.
	carrier.take_damage(10000.0, null, false, true)
	if not check("death-drop fixture real death leaves unladen dying node in root", carrier.hp == 0.0 and carrier._dying and carrier._death_t < U.DEATH_DUR and carrier.get_parent() == battle.units_root and not battle.units.has(carrier) and not carrier.has_meta("carrying_tribute")):
		return battle
	check("death-drop fixture cargo empty and original load active visible", level.cargo.is_empty() and level.bundles[0] == bundle and battle.units.has(bundle) and bundle.visible and bundle.process_mode != Node.PROCESS_MODE_DISABLED and not bundle.has_meta("tribute_process_mode"))
	check("death-drop fixture another survivor can take over", level._available_force_carriers().has("liu_tang") and battle.mission.actions.has("force_take_0_1") and battle.mission.actions.force_take_0_1.actors.has("liu_tang") and battle.phase == B.Phase.FIGHT)
	var death_t: float = carrier._death_t
	var main_slot: Dictionary = Store.new("user://continue/v1").read_slot()
	if not check("death-drop fixture original component slot readable", main_slot.ok):
		return battle
	var slot_root := "user://level1_death_drop_fixture/v1"
	# The prior restore carries the original slot's local receipt. Allocate a
	# separate local-only QA identity instead of writing across receipt scopes.
	battle._continue_receipt = null
	battle._save_barrier.capture_ready.connect(func(_c): held = true)
	battle._save_barrier.capture_rejected.connect(func(c): rejected = String(c))
	var saved: Dictionary = await _pause_save(battle, runtime, slot_root)
	if not check("death-drop fixture Session saves during death animation", saved.get("ok", false)):
		print("DEATH_DROP_SAVE: ", saved)
		return battle
	check("death-drop fixture saved before dying node expired", is_instance_valid(carrier) and carrier._dying and carrier._death_t == death_t and carrier.get_parent() == battle.units_root)
	var slot: Dictionary = Store.new(slot_root).read_slot()
	if not check("death-drop fixture independent slot readable", slot.ok):
		return battle
	battle.queue_free()
	await get_tree().process_frame
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	var session := Session.new(trusted, runtime, slot_root)
	var prepared: Dictionary = session.prepare_restore(menu)
	if not check("death-drop fixture Session prepares paused restore", prepared.get("ok", false)):
		print("DEATH_DROP_PREPARE: ", prepared)
		session.dispose()
		return null
	var committed: Dictionary = await session.commit_restore_async()
	if not check("death-drop fixture Session installs paused restore", committed.get("ok", false)):
		print("DEATH_DROP_COMMIT: ", committed)
		session.dispose()
		return null
	var restored: Node = committed.battle
	var restored_carrier: Variant = null
	for unit in restored.units_root.get_children(true):
		if unit.entity_id == carrier_id: restored_carrier = unit
	var restored_bundle: Variant = restored.level.bundles[0]
	check("death-drop fixture restored dying identity and empty hands", is_instance_valid(restored_carrier) and restored_carrier.hp == 0.0 and restored_carrier._dying and restored_carrier._death_t == death_t and restored_carrier.get_parent() == restored.units_root and not restored.units.has(restored_carrier) and not restored_carrier.has_meta("carrying_tribute"))
	check("death-drop fixture restored original load active visible and cargo empty", restored_bundle.entity_id == bundle_id and restored.units.has(restored_bundle) and restored_bundle.visible and restored_bundle.process_mode != Node.PROCESS_MODE_DISABLED and not restored_bundle.has_meta("tribute_process_mode") and restored.level.cargo.is_empty())
	check("death-drop fixture restored survivor and replacement pickup action", restored.level._available_force_carriers().has("liu_tang") and restored.mission.actions.has("force_take_0_1") and restored.mission.actions.force_take_0_1.actors.has("liu_tang") and restored.phase == B.Phase.FIGHT and get_tree().paused)
	var main_after: Dictionary = Store.new("user://continue/v1").read_slot()
	check("death-drop fixture leaves original component slot bytes unchanged", main_after.ok and main_after.file_sha256 == main_slot.file_sha256)
	session.dispose()
	return restored

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
