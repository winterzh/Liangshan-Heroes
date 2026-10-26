extends Node
## Command driver only. All gameplay, Unit, map, clock and serializers are the
## actual installed resources; no substitutes or injected content identities.
var checks: Array = []
var failures: Array = []
var orders := 0
var trusted: Dictionary = {}
var execution_kind := "unresolved"
const SLOT := "user://continue/v1"
const Codec := preload("res://scripts/run_state_value_codec.gd")
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Lifecycle := preload("res://scripts/run_campaign_local_lifecycle.gd")
const Intent := preload("res://scripts/run_campaign_progress_intent.gd")
const Store := preload("res://scripts/run_slot_store.gd")
const Session := preload("res://scripts/run_world_session.gd")
var checkpoint: Dictionary = {}
var empty_checkpoint: Dictionary = {}
var terminal_checkpoint: Dictionary = {}
var initial_progress: Dictionary = {}
var initial_rewards: Dictionary = {}
var hold_ready := false
var hold_error := ""
var owned_session: Variant
var terminal_receipt: Variant
var startup_observation: Dictionary = {}
var root: Window:
	get: return get_tree().root
var current_scene: Node:
	get: return get_tree().current_scene
	set(value): get_tree().current_scene = value

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var profile := OS.get_environment("CH_PROFILE").replace("\\", "/").simplify_path()
	var safe: bool = profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		safe = safe and OS.get_environment(key).replace("\\", "/").simplify_path().to_lower() == (profile + "/" + key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(profile.to_lower() + "/appdata/")
	safe = safe and ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/").to_lower() == OS.get_environment("CH_PROJECT").replace("\\", "/").trim_suffix("/").to_lower()
	if not safe or OS.get_environment("STEAM_DISABLED") != "1" or not OS.get_environment("CAMPAIGN_QA").is_empty():
		push_error("CH_FOUR_PRIVATE_ROOTS_REQUIRED"); quit(2); return
	_run.call_deferred()

func _run() -> void:
	push_error("CH_WORKER_NOT_IMPLEMENTED"); quit(2)

func quit(code := 0) -> void:
	get_tree().quit(code)

func check(ok: bool, label: String) -> void:
	checks.append({"label": label, "passed": ok})
	if not ok: failures.append(label)
	print("HG ", "PASS " if ok else "FAIL ", label)

func alive(unit: Variant) -> bool:
	return is_instance_valid(unit) and unit.hp > 0.0 and unit.story_outcome == ""

func identity(expected_source_mode := true) -> bool:
	execution_kind = "source_project" if expected_source_mode else OS.get_environment("CH_EXECUTION_KIND")
	trusted = load("res://scripts/run_content_identity.gd").new().resolve_runtime_identity()
	check(trusted.get("ok", false) and trusted.get("save_eligible", false) and trusted.get("source_mode", not expected_source_mode) == expected_source_mode,
		"real executed identity resolves in requested source/package mode")
	if not trusted.get("ok", false):
		print("IDENTITY ", trusted); return false
	if not expected_source_mode:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CH_EXPECTED_IDENTITY")))
		var script: Script = load("res://scripts/run_build_identity.gd")
		var actual: Dictionary = script.get_script_constant_map().IDENTITY
		check(not script.has_source_code(), "build identity is actual exported bytecode")
		check(JSON.parse_string(JSON.stringify(actual)) == expected, "full compiled input manifest matches frozen exporter output")
		check(trusted.content_version == "source-v1:" + expected.source_sha256, "Provider uses actual exported source identity")
		check(trusted.engine_binary_sha256 == OS.get_environment("CH_EXPECTED_EXE_SHA"), "executed compiled-PCK loader matches its pinned original editor binary")
		check(execution_kind == "compiled_pck_editor_loader" and OS.has_feature("editor"),
			"explicit compiled_pck_editor_loader executes actual exported bytecode on the editor engine")
	return failures.is_empty()

func _start(mode := "", index := 0) -> Node:
	check(mode.is_empty() and index == 0, "only the ordinary Huangnigang campaign is requested")
	var campaign: Variant = root.get_node("Campaign")
	campaign.current = index
	for key in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(key, false)
	if mode != "": campaign.set(mode, true)
	root.get_node("Settings").auto_micro_level = 0
	seed(5088120)
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu); current_scene = menu
	await get_tree().process_frame
	check(root.get_node("ContinueFlow").can_launch(), "real startup gate permits normal menu launch")
	if not failures.is_empty(): return null
	menu._launch()
	for frame in range(240):
		await get_tree().process_frame
		if is_instance_valid(current_scene) and current_scene.get_script() == load("res://scripts/battle.gd"): break
	var battle: Variant = current_scene
	check(is_instance_valid(battle) and battle.get_script() == load("res://scripts/battle.gd") and battle.level.id() == "level1", "normal menu launches actual Huangnigang")
	if not failures.is_empty(): return null
	var intro_ok: bool = await _show_start_intro(battle)
	check(intro_ok and battle.phase == battle.Phase.DEPLOY, "authored intro buttons alone reach deployment")
	if not failures.is_empty(): return null
	battle.hud.start_btn.pressed.emit()
	return battle

func _show_start_intro(_battle: Variant) -> bool:
	return false

func _dispose(battle: Node) -> void:
	battle.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _click(battle: Variant, units: Array, cell: Vector2i, amove := false) -> void:
	battle.select_members(units, false)
	battle.minimap_order(battle.map.cell_to_world(cell), amove)
	orders += 1

func _action(battle: Variant, unit: Variant, action_id: String) -> void:
	if not alive(unit) or not battle.mission.actions.has(action_id): return
	if battle.mission.actions[action_id].done or battle.mission.active_action_id == action_id: return
	_click(battle, [unit], battle.mission.actions[action_id].cell)

func report(extra: Dictionary = {}) -> void:
	var exact: Dictionary = Codec.new().encode(terminal_checkpoint)
	var exact_saved: Dictionary = Codec.new().encode(checkpoint)
	check(exact.ok and exact_saved.ok, "terminal and saved checkpoints use the lossless production codec")
	var value := {"schema":"campaign_huang_terminal_v1", "passed": not checks.is_empty() and failures.is_empty(), "checks": checks, "failures": failures,
		"mode":OS.get_environment("CH_MODE"), "batch_nonce":OS.get_environment("CH_NONCE"),
		"profile":OS.get_environment("CH_PROFILE"), "slot_root":SLOT,
		"terminal_checkpoint":terminal_checkpoint, "exact_terminal":exact.get("value"),
		"checkpoint":checkpoint, "exact_checkpoint":exact_saved.get("value"), "startup":startup_observation,
		"orders": orders, "trusted_identity": trusted, "pid": OS.get_process_id(),
		"native_steam_account_tested": false, "ordinary_player_continue_entry_tested": false,
		"human_acceptance":false, "performance_accepted":false, "published":false, "simulation_time_scale": Engine.time_scale}
	value.merge(extra, true)
	# External workers qualify source or compiled PCK behavior. The original
	# release template has a separate normal-startup receipt and no worker hook.
	value["execution_kind"] = execution_kind
	value["native_release_tested"] = false
	var file := FileAccess.open(OS.get_environment("CH_REPORT"), FileAccess.WRITE)
	if file == null:
		push_error("CH_REPORT_UNWRITABLE"); quit(2); return
	file.store_string(JSON.stringify(value, "\t")); file.close()
	root.get_node("Sfx").shutdown(); root.get_node("Music").shutdown()
	quit(0 if value.passed else 1)

func saved_cart_bindings(world: Dictionary, battle: Variant, label: String) -> Dictionary:
	# JujubeCart is Node2D, not Unit. Its persisted identity is the actual
	# Level/Visual external token; OS instance IDs are never a restart identity.
	var codec: Variant = load("res://scripts/run_state_value_codec.gd").new()
	var level_record: Dictionary = codec.decode(world.sections.level.payload)
	var visual_record: Dictionary = codec.decode(world.sections.visual.records)
	check(level_record.get("ok", false) and visual_record.get("ok", false), label + ": actual saved Level and Visual records decode")
	if not level_record.get("ok", false) or not visual_record.get("ok", false): return {}
	var persisted_tokens: Array = level_record.value.external.jujube_carts
	var canonical: Array = range(7).map(func(i): return "ext:level1:jujube_carts:%d" % i)
	check(persisted_tokens == canonical and battle.level.jujube_carts.size() == 7, label + ": saved Level binds all seven canonical cart tokens")
	if persisted_tokens != canonical or battle.level.jujube_carts.size() != 7: return {}
	var visual_carts: Dictionary = {}
	for row: Dictionary in visual_record.value:
		if row.kind != "hg_cart": continue
		var token: String = row.values.token
		check(not visual_carts.has(token), label + ": visual cart token is unique " + token)
		visual_carts[token] = row
	check(visual_carts.size() == 7, label + ": saved Visual graph contains exactly seven original cart props")
	var actual_tokens: Dictionary = load("res://scripts/run_level1_visual_state.gd").tokens(battle.level)
	var states: Array = []
	for i in range(7):
		var token: String = canonical[i]
		var cart: Variant = battle.level.jujube_carts[i]
		check(is_instance_valid(cart) and actual_tokens.get(cart, "") == token and visual_carts.has(token), label + ": actual cart object is bound to saved token " + token)
		if not is_instance_valid(cart) or not visual_carts.has(token): return {}
		var saved: Dictionary = visual_carts[token]
		var saved_position: Vector2 = saved.node.position
		check(cart.position.distance_to(saved_position) < 0.001 and cart.visible == saved.node.visible and int(cart.get_meta("jujube_cart_index", -1)) == i and saved.values.metadata.get("jujube_cart_index", -1) == i, label + ": token retains actual saved position, visibility and cart index " + token)
		states.append({"token": token, "position": [saved_position.x, saved_position.y], "visible": saved.node.visible, "cart_index": i})
	return {"cart_tokens": persisted_tokens.duplicate(), "cart_states": states}

func wait_startup() -> bool:
	var flow: Node = root.get_node("ContinueFlow")
	for frame in range(240):
		if flow.can_launch(): break
		await get_tree().process_frame
	startup_observation = flow.last_result.duplicate(true)
	check(flow.can_launch() and startup_observation.get("startup_checked", false), "candidate startup recovery completes before gameplay or restore")
	return failures.is_empty()

func cfg_snapshot() -> Dictionary:
	var path: String = root.get_node("Campaign").SAVE_PATH
	if not FileAccess.file_exists(path): return {"exists":false, "path":path, "sha256":"", "sections":{}}
	var before: String = FileAccess.get_sha256(path)
	var cfg := ConfigFile.new()
	check(cfg.load(path) == OK, "actual campaign CFG independently loads")
	var sections: Dictionary = {}
	for name: String in cfg.get_sections():
		var values: Dictionary = {}
		for key: String in cfg.get_section_keys(name): values[key] = cfg.get_value(name, key)
		sections[name] = values
	check(FileAccess.get_sha256(path) == before, "CFG read preserves exact bytes")
	return {"exists":true, "path":path, "sha256":before, "sections":sections}

func rewards_snapshot() -> Dictionary:
	var service: Node = root.get_node("SteamService")
	check(not service.available and not service.stats_ready and service._active_run == 0
		and service._run_counter == 0 and service._local_runs == null, "Steam-disabled service has no credited run or native ledger")
	return {"stats":service.state.stats.duplicate(true), "unlocked":service.state.unlocked.duplicate(true),
		"settled":service.state.settled.duplicate(true), "active_run":service._active_run, "run_counter":service._run_counter}

func lifecycle_row(receipt: Variant) -> Dictionary:
	check(receipt != null and receipt.get_script() == Lifecycle, "actual campaign lifecycle script retained")
	if receipt == null or receipt.get_script() != Lifecycle: return {}
	var head: Dictionary = receipt.open_head()
	check(head.ok, "actual lifecycle chain reads")
	if not head.ok: return {}
	var owner: String = root.get_node("Campaign").cloud_owner
	var scope: Dictionary = {"owner":owner, "content_version":trusted.content_version, "engine_sha256":trusted.engine_binary_sha256}
	check(owner.is_empty() and head.document.schema == Lifecycle.CAMPAIGN_SCHEMA
		and head.document.context == Profiles.HG_CONTEXT and head.document.scope == scope
		and receipt.matches_scope(Profiles.HG_CONTEXT, trusted, owner), "Huangnigang lifecycle binds actual context owner content and engine")
	var inventory: Dictionary = receipt.inventory()
	check(inventory.ok, "lifecycle inventory reads without recovery or writes")
	return {"directory":receipt.directory, "token":receipt.token, "file_sha256":head.file_sha256,
		"generation":int(head.revision), "document":head.document.duplicate(true), "inventory":inventory.get("items", {}).duplicate(true)}

func checkpoint_save(battle: Variant, label: String, _freeze_copy := false) -> bool:
	var runtime: Dictionary = load("res://scripts/run_level1_world_factory.gd").prepare_runtime(trusted)
	check(runtime.get("ok", false), label + ": actual installed runtime prepared")
	check(battle._official_context == Profiles.HG_CONTEXT and battle._steam_run_id == 0, label + ": actual uncredited Huangnigang context")
	check(battle._save_barrier.world == battle and battle._save_barrier.clock == battle._run_clock
		and battle._save_barrier._capture_context == Profiles.HG_CONTEXT, label + ": candidate itself configured the campaign barrier")
	if not failures.is_empty(): return false
	var was_paused: bool = get_tree().paused
	get_tree().paused = true
	hold_ready = false; hold_error = ""
	battle._save_barrier.capture_ready.connect(func(_clock): hold_ready = true, CONNECT_ONE_SHOT)
	battle._save_barrier.capture_rejected.connect(func(code): hold_error = String(code), CONNECT_ONE_SHOT)
	var requested: Dictionary = battle._save_barrier.request_capture()
	check(requested.ok, label + ": real complete-step capture requested")
	if not requested.ok: return false
	for frame in range(240):
		await get_tree().process_frame
		if hold_ready or not hold_error.is_empty(): break
	check(hold_ready and hold_error.is_empty() and battle._save_barrier.health().ok, label + ": real barrier drained and held")
	if not failures.is_empty(): return false
	var store := Store.new(SLOT)
	var inspected: Dictionary = store.inspect_slot()
	var expected_revision: int = 0 if label == "seventh_empty_cart_in_transit" else 1
	check(inspected.ok and int(inspected.revision) == expected_revision, label + ": fixed slot has expected predecessor")
	if expected_revision == 1:
		check(inspected.file_sha256 == empty_checkpoint.saved_sha256 and battle._continue_receipt.token == empty_checkpoint.binding.token, label + ": resave retains prior slot and token")
	if not failures.is_empty(): return false
	owned_session = Session.new(trusted, runtime.runtime, SLOT)
	var saved: Dictionary = owned_session.save_held(battle, null, {"revision":int(inspected.revision), "file_sha256":inspected.file_sha256})
	check(saved.ok, label + ": actual Session saves with expected-slot compare-and-swap")
	if not saved.ok: return false
	var slot: Dictionary = store.read_slot()
	check(slot.ok and slot.document.schema == Store.CAMPAIGN_SCHEMA and slot.document.world.profile.id == Profiles.HG_ID
		and slot.document.context == Profiles.HG_CONTEXT and int(slot.revision) == expected_revision + 1, label + ": actual campaign slot independently reads")
	if not slot.ok: return false
	var cart_bindings: Dictionary = saved_cart_bindings(slot.document.world, battle, label)
	var life: Dictionary = lifecycle_row(battle._continue_receipt)
	if cart_bindings.is_empty() or life.is_empty(): return false
	check(life.generation == 1 and life.document.state == "active" and life.document.progress_state == "none"
		and not life.document.victory and life.document.intent.is_empty() and life.document.progress_receipt.is_empty(), label + ": actual active campaign gen1")
	check(slot.document.binding.kind == "uncredited" and slot.document.binding.token == life.token
		and slot.document.binding.receipt_sha256 == life.file_sha256, label + ": slot binds exact campaign gen1 bytes")
	if expected_revision == 1:
		check(life == empty_checkpoint.lifecycle and slot.document.binding == empty_checkpoint.binding, label + ": no receipt replacement or regeneration")
	var carried: Dictionary = {}
	var positions: Dictionary = {}
	for index in battle.level.cargo:
		carried[str(index)] = battle.level.cargo[index].entity_id
		var point: Vector2 = battle.level.cargo[index].position
		positions[str(index)] = [point.x, point.y]
	checkpoint = {"label":label, "slot_root":SLOT, "directory":store.directory,
		"saved_sha256":slot.file_sha256, "generation":int(slot.revision), "binding":slot.document.binding.duplicate(true), "lifecycle":life,
		"eleven_entity_ids":battle.level.bundles.map(func(u): return u.entity_id), "carried":carried, "positions":positions,
		"delivered_loads":battle.level.delivered, "stage":battle.level.st, "profile":slot.document.world.profile.id,
		"writer_pid":OS.get_process_id(), "content_version":trusted.content_version, "empty_carried":{},
		"cart_tokens":cart_bindings.cart_tokens, "cart_states":cart_bindings.cart_states}
	for index in battle.level.empty_cargo: checkpoint.empty_carried[str(index)] = battle.level.empty_cargo[index].entity_id
	terminal_receipt = battle._continue_receipt
	var released: Dictionary = battle._save_barrier.release_capture()
	check(released.ok, label + ": actual capture released")
	get_tree().paused = was_paused
	owned_session.dispose(); owned_session = null
	return failures.is_empty()

func wait_natural_terminal(battle: Variant) -> bool:
	var flow: Node = root.get_node("ContinueFlow")
	var deadline: int = Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < deadline:
		if battle.phase == battle.Phase.END and not flow.busy() and flow.last_result.get("terminal_completed", false) \
			and flow.last_result.get("campaign_progress_committed", false) and battle.hud._end_root.visible: break
		if flow.last_result.get("terminal_pending", false): break
		await get_tree().process_frame
	check(battle.phase == battle.Phase.END and battle.level.victory and not flow.busy()
		and flow.last_result.get("ok", false) and flow.last_result.get("terminal_completed", false)
		and flow.last_result.get("campaign_progress_committed", false) and battle.hud._end_root.visible,
		"natural END completes asynchronous campaign transaction and actual end HUD before inspection")
	if not failures.is_empty(): print("CH_TERMINAL_FLOW ", flow.last_result)
	return failures.is_empty()

func verify_terminal_ack(life: Dictionary, cfg: Dictionary, label: String) -> Dictionary:
	var document: Dictionary = life.get("document", {})
	var intent: Dictionary = document.get("intent", {})
	var acknowledgement: Dictionary = document.get("progress_receipt", {})
	var model: String = String(document.get("schema", ""))
	var intent_schema := ""
	var ack_schema := ""
	var intent_fields: Array = ["schema", "token", "context", "profile_id", "owner", "content_version", "engine_sha256", "victory", "result"]
	match model:
		"local_campaign_continue_lifecycle_v2":
			intent_schema = "campaign_progress_intent_v1"
			ack_schema = "campaign_progress_ack_v1"
		"local_campaign_continue_lifecycle_v3":
			intent_schema = "campaign_progress_intent_v2"
			ack_schema = "campaign_progress_ack_v2"
			intent_fields.append("credit")
		_:
			check(false, label + ": known exact lifecycle/intent/ACK version contract")
			return {}
	var bound: bool = model == Lifecycle.CAMPAIGN_SCHEMA and document.get("generation") == 3 \
		and document.get("state") == "terminal" and document.get("progress_state") == "applied" \
		and document.get("victory") == true and Intent.fields(intent, intent_fields) \
		and intent.get("schema") == intent_schema and intent.get("token") == life.get("token") \
		and intent.get("context") == Profiles.HG_CONTEXT and intent.get("profile_id") == Profiles.HG_ID \
		and intent.get("owner") == "" and intent.get("victory") == true \
		and intent.get("content_version") == trusted.content_version and intent.get("engine_sha256") == trusted.engine_binary_sha256
	check(bound, label + ": exact installed lifecycle and offline terminal intent contract")
	if not bound: return {}
	if model == "local_campaign_continue_lifecycle_v3":
		var uncredited: bool = intent.get("credit") == {"kind":"uncredited"}
		check(uncredited, label + ": offline credit is exactly uncredited with no synthetic binding")
		if not uncredited: return {}
	var cfg_ok: bool = cfg.get("exists", false) and Intent.hex(cfg.get("sha256"), 64)
	check(cfg_ok, label + ": independently read durable CFG has a complete SHA")
	if not cfg_ok: return {}
	var intent_sha256: String = JSON.stringify(intent).sha256_text()
	var expected_ack := {"schema":ack_schema, "code":"CAMPAIGN_CFG_READBACK_VERIFIED",
		"persisted":true, "suppressed":false, "file_sha256":cfg.sha256}
	var expected_proof: Dictionary = {}
	if model == "local_campaign_continue_lifecycle_v3":
		expected_proof = {"schema":"campaign_uncredited_handoff_v1", "token":life.token,
			"context":Profiles.HG_CONTEXT.duplicate(true), "intent_sha256":intent_sha256}
		expected_ack["steam_handoff"] = expected_proof
	var exact_ack: bool = acknowledgement == expected_ack
	check(exact_ack, label + ": exact versioned ACK fields bind CFG SHA and same-token handoff")
	if not exact_ack: return {}
	var inspected: Dictionary = {}
	if model == "local_campaign_continue_lifecycle_v3":
		var service: Node = root.get_node("SteamService")
		var inspectable: bool = service.has_method("inspect_campaign_handoff")
		check(inspectable, label + ": actual SteamService exposes independent handoff inspection")
		if not inspectable: return {}
		# Dynamic call keeps the LCv2 worker compatible with its older service API.
		# This uncredited proof validates the frozen intent; it is not an SDK ledger.
		inspected = service.call("inspect_campaign_handoff", intent)
		var exact_inspection: bool = inspected == {"ok":true, "proof":expected_proof}
		check(exact_inspection, label + ": independent service inspection matches the complete uncredited proof")
		if not exact_inspection: return {}
	check(FileAccess.get_sha256(cfg.path) == cfg.sha256, label + ": handoff inspection preserves exact CFG bytes")
	return {"lifecycle_schema":model, "intent_schema":intent_schema, "intent_sha256":intent_sha256,
		"acknowledgement":acknowledgement.duplicate(true), "service_inspection":inspected.duplicate(true),
		"native_steam_account_tested":false}

func verify_terminal(battle: Variant, full_result: Dictionary) -> bool:
	check(battle._continue_receipt == terminal_receipt and battle._continue_receipt.token == checkpoint.binding.token,
		"natural terminal uses the original saved lifecycle object and token")
	var life: Dictionary = lifecycle_row(battle._continue_receipt)
	if life.is_empty(): return false
	check(life.generation == 3 and life.document.state == "terminal" and life.document.progress_state == "applied"
		and life.document.victory, "actual campaign journal reaches terminal applied gen3")
	var chain: Array = []
	for generation in range(1, 4):
		var item: Dictionary = battle._continue_receipt._verified("record_%010d.json" % generation)
		check(item.ok and int(item.revision) == generation and item.document.token == checkpoint.binding.token,
			"same-token committed campaign journal retains generation %d" % generation)
		if not item.ok: return false
		chain.append(item)
	check(chain[0].file_sha256 == checkpoint.lifecycle.file_sha256 and chain[0].document == checkpoint.lifecycle.document,
		"terminal chain preserves exact previously observed active gen1 bytes")
	check(chain[1].previous == chain[0].file_sha256 and chain[2].previous == chain[1].file_sha256
		and chain[1].document.state == "terminal" and chain[1].document.progress_state == "pending"
		and chain[1].document.progress_receipt.is_empty() and chain[1].document.intent == chain[2].document.intent,
		"real gen1 to gen2 to gen3 hash chain retains one frozen terminal intent")
	var intent: Dictionary = chain[2].document.intent
	check(intent.token == checkpoint.binding.token and intent.context == Profiles.HG_CONTEXT
		and intent.content_version == trusted.content_version and intent.engine_sha256 == trusted.engine_binary_sha256,
		"terminal intent binds the same actual run and installed identity")
	for key: String in Intent.RESULT_FIELDS:
		check(intent.result[key] == full_result[key], "durable projection retains natural result field " + key)
	check(full_result.has_all(["goals", "core_goal", "missed_ids", "pending_ids"])
		and full_result.goals.size() == 4 and full_result.missed_ids.is_empty() and full_result.pending_ids.is_empty(),
		"full frozen Mission result retains goal detail beyond the durable six-field projection")
	var cfg: Dictionary = cfg_snapshot()
	var handoff_validation: Dictionary = verify_terminal_ack(life, cfg, "natural terminal gen3")
	if handoff_validation.is_empty(): return false
	var cfg_reader := ConfigFile.new()
	check(cfg_reader.load(cfg.path) == OK and Intent.cfg_dominates(cfg_reader, intent), "actual CFG contains this natural campaign outcome")
	var progress: Dictionary = cfg.sections.get("progress", {})
	var expected_ids: Array = ["merchant_cover", "wine_scheme", "no_bloodshed", "all_safe"]
	var record: Dictionary = progress.get("records", {}).get("level1", {})
	check(progress.get("schema") == 2 and progress.get("owner") == "" and progress.get("unlocked") == 2
		and record.get("cleared", false) and record.get("story_complete", false) and record.get("best_done") == 4
		and record.get("story_total") == 4 and record.get("best_goal_ids") == expected_ids and record.get("contract_version") == 3,
		"fresh offline CFG records four current Huangnigang goals and unlocks chapter two")
	var campaign: Node = root.get_node("Campaign")
	check(campaign.unlocked == progress.get("unlocked") and campaign.records == progress.get("records")
		and campaign.cloud_owner == progress.get("owner"), "in-memory campaign matches durable CFG")
	var slot: Dictionary = Store.new(SLOT).read_slot()
	check(slot.ok and slot.file_sha256 == checkpoint.saved_sha256 and slot.document.binding == checkpoint.binding,
		"terminal closes lifecycle without rewriting the saved active slot")
	var rewards: Dictionary = rewards_snapshot()
	check(rewards == initial_rewards, "Steam-disabled terminal adds no native reward or ledger run")
	terminal_checkpoint = {"slot_root":SLOT, "slot_sha256":slot.file_sha256, "slot_binding":slot.document.binding.duplicate(true),
		"lifecycle":life, "chain":chain, "cfg":cfg, "rewards":rewards, "handoff_validation":handoff_validation,
		"campaign_memory":{"unlocked":campaign.unlocked, "records":campaign.records.duplicate(true), "owner":campaign.cloud_owner},
		"full_frozen_result":full_result.duplicate(true), "initial_cfg":initial_progress,
		"flow_result":root.get_node("ContinueFlow").last_result.duplicate(true)}
	return failures.is_empty()
