extends Node
## EXTERNAL UNEXECUTED v25: four processes, actual single-safe save/continue/terminal.
## Inherited v24o A NONCANONICAL_RECORD failed; v24r1 successor is still pending.
## Baseline audits must adopt any later genuinely qualified successor corrections.
## Ordinary player movement and native Mission/Battle ticks only. No gameplay fixture.
## Load fixed scripts after autoload initialization; never use saved script paths.
const CASES := ["A_single_save", "B_install_settle_resave", "C_install_finish", "D_read_terminal"]
const SLOT_ROOT := "user://daming_safe_retreat_v25/continue/v1"
const HANDOFF_A := "user://daming_safe_retreat_v25/handoff_A.json"
const HANDOFF_B := "user://daming_safe_retreat_v25/handoff_B.json"
const HANDOFF_C := "user://daming_safe_retreat_v25/terminal_C.json"
const ADMIT_REPORT := "蔡福安排的公人身份受验通过，柴进与乐和可入牢就位"
const ACTION_ID := "daming_admit"
const RESCUE_ID := "daming_rescue"
const ROUTE_LIMIT_MS := 180000
const CONTINUE_LIMIT_MS := 20000
const C_SETTLE_TICKS := 120

var B: Script
var Daming: Script
var Profiles: Script
var Factory: Script
var Provider: Script
var Session: Script
var Store: Script
var Core: Script
var Codec: Script
var trusted: Dictionary = {}
var runtime: Dictionary = {}
var checks: Array = []
var observations: Array = []
var evidence: Array = []
var mode := ""
var nonce := ""
var output := ""
var profile := ""
var handoff: Dictionary = {}
var held := false
var rejected := ""
var held_physics := -1
var orders := 0
var restore_session: RefCounted
var retained_identity: RefCounted
var battle: Node
var finished := false
var first_role := ""
var route: RefCounted
var Lifecycle: Script
var terminal_signal_results: Array = []
var terminal_qualified := false
var terminal_readback_qualified := false
var single_safe_disk_qualified := false

func check(label: String, passed: bool, detail: Variant = null) -> bool:
	checks.append({"label": label, "passed": passed, "detail": null if passed else detail})
	if not passed: print("FAIL ", label, " ", detail)
	return passed

func _guard() -> bool:
	profile = OS.get_environment("DAMING_RETREAT_PROFILE").replace("\\", "/").simplify_path().trim_suffix("/")
	output = OS.get_environment("DAMING_RETREAT_OUT").replace("\\", "/").simplify_path().trim_suffix("/")
	var safe: bool = profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile) and output.is_absolute_path() and DirAccess.dir_exists_absolute(output)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		var actual: String = OS.get_environment(key).replace("\\", "/").simplify_path().trim_suffix("/")
		safe = safe and actual.to_lower() == profile.path_join(key.to_lower()).to_lower()
	var user_dir: String = OS.get_user_data_dir().replace("\\", "/").simplify_path()
	var project: String = ProjectSettings.globalize_path("res://").replace("\\", "/").simplify_path().trim_suffix("/")
	safe = safe and user_dir.to_lower().begins_with(profile.path_join("appdata").to_lower() + "/")
	safe = safe and not output.to_lower().begins_with(project.to_lower() + "/") and output.to_lower() != project.to_lower()
	safe = safe and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA") == "1"
	return safe

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _guard():
		print("DAMING_RETREAT PRIVATE_PROFILE_REQUIRED")
		get_tree().quit(2)
		return
	mode = OS.get_environment("DAMING_RETREAT_CASE")
	nonce = OS.get_environment("DAMING_RETREAT_NONCE")
	first_role = OS.get_environment("DAMING_RETREAT_FIRST_ROLE")
	if not check("known case and nonempty nonce", mode in CASES and not nonce.is_empty() and first_role in ["lu", "shi"] and OS.get_environment("DAMING_RETREAT_QA") == "1"): finish(); return
	output = output.path_join(mode)
	if not check("fresh case evidence directory", not DirAccess.dir_exists_absolute(output)): finish(); return
	if not check("case evidence directory created", DirAccess.make_dir_recursive_absolute(output) == OK): finish(); return
	run.call_deferred()

func _write_new_json(path: String, value: Variant) -> bool:
	if not check("immutable evidence path unused " + path.get_file(), not FileAccess.file_exists(path)): return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not check("evidence writable " + path.get_file(), file != null): return false
	file.store_string(JSON.stringify(value, "\t") + "\n")
	file.close()
	evidence.append({"path": path, "sha256": FileAccess.get_sha256(path)})
	return true

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not check("prior evidence readable " + path.get_file(), file != null): return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not check("prior evidence dictionary " + path.get_file(), value is Dictionary): return {}
	return value

func _load_fixed_scripts() -> void:
	B = load("res://scripts/battle.gd")
	Daming = load("res://scripts/levels/level8_daming_rts.gd")
	Profiles = load("res://scripts/run_official_restore_profile.gd")
	Factory = load("res://scripts/run_level8_world_factory.gd")
	Provider = load("res://scripts/run_content_identity.gd")
	Session = load("res://scripts/run_world_session.gd")
	Store = load("res://scripts/run_slot_store.gd")
	Core = load("res://scripts/run_battle_world_core.gd")
	Codec = load("res://scripts/run_state_value_codec.gd")
	Lifecycle = load("res://scripts/run_local_lifecycle.gd")
	route = load("res://tools/daming_safe_retreat_route_v25.gd").new()

func run() -> void:
	_load_fixed_scripts()
	if not check("normal simulation clock", is_equal_approx(Engine.time_scale, 1.0) and Engine.physics_ticks_per_second == 60 and is_equal_approx(get_node("/root/Settings").game_speed, 1.0)): finish(); return
	trusted = Provider.new().resolve_runtime_identity()
	if not check("installed runtime identity eligible", trusted.get("ok", false) and trusted.get("save_eligible", false), trusted): finish(); return
	var expected_content: String = OS.get_environment("DAMING_RETREAT_EXPECT_CONTENT")
	var expected_engine: String = OS.get_environment("DAMING_RETREAT_EXPECT_ENGINE")
	if not check("producer pinned exact installed content and engine", not expected_content.is_empty() and not expected_engine.is_empty() and trusted.content_version == expected_content and trusted.engine_binary_sha256 == expected_engine): finish(); return
	var pack: Dictionary = Factory.prepare_runtime(trusted)
	if not check("installed Daming pure runtime factory", pack.get("ok", false), pack): finish(); return
	runtime = pack.runtime
	var configured: Dictionary = route.configure(self, first_role)
	if not check("fixed role and route module configured", configured.get("ok", false), configured): finish(); return
	if mode == CASES[0]:
		battle = await _launch()
		if is_instance_valid(battle): await _single_save(battle)
	elif mode in [CASES[1], CASES[2]]:
		battle = await _restore()
		if is_instance_valid(battle):
			if mode == CASES[1]: await _single_settle_resave(battle)
			else: await _finish_natural_terminal(battle)
	else:
		await _read_terminal_in_new_process()
	finish()

func _launch() -> Node:
	var initial_slot: Dictionary = Store.new(SLOT_ROOT).read_slot()
	if not check("fresh first-process slot", not initial_slot.ok and initial_slot.get("code", "") == "NO_SLOT", initial_slot): return null
	if not check("no previous process handoffs", not FileAccess.file_exists(HANDOFF_A) and not FileAccess.file_exists(HANDOFF_B) and not FileAccess.file_exists(HANDOFF_C)): return null
	var campaign: Node = get_node("/root/Campaign")
	var flags: Dictionary = Profiles.install_flags(Profiles.DAMING_ID)
	if not check("installed Daming launch flags", flags.get("ok", false), flags): return null
	for key: String in flags.flags: campaign.set(key, flags.flags[key])
	campaign.ai_friendly = false
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	menu._launch()
	for frame in range(180):
		await get_tree().process_frame
		var current: Node = get_tree().current_scene
		if is_instance_valid(current) and current.get_script() == B: break
	var b: Node = get_tree().current_scene
	if not check("actual Daming Battle launched", is_instance_valid(b) and b.get_script() == B and b.level.get_script() == Daming): return null
	# Original launch UI signals skip only the intro/deployment wait, never gameplay.
	b.hud._intro_root.hide()
	b.hud.intro_done.emit()
	if b.phase == b.Phase.DEPLOY: b.hud.start_battle.emit()
	for frame in range(12): await get_tree().physics_frame
	await get_tree().process_frame
	if not check("normal Battle launch already classifies actual Daming context", b._official_context == Profiles.DAMING_CONTEXT): return null
	b._save_barrier.configure(b, b._run_clock, Profiles.DAMING_CONTEXT)
	if not check("fight and original unstarted admission", _healthy(b) and not b.level.prison_open and not b.mission.actions[ACTION_ID].done and not b.mission.actions.has(RESCUE_ID)): return null
	return b

func _healthy(b: Node) -> bool:
	return is_instance_valid(b) and b.phase == b.Phase.FIGHT and b.level.get_script() == Daming and b.gameplay_rng_fault().is_empty() and b._run_clock.fault().is_empty() and is_equal_approx(Engine.time_scale, 1.0)

func _single_save(b: Node) -> void:
	if not check("fresh profile has no previous level8 result", not get_node("/root/Campaign").level_record("level8").cleared): return
	if not await route.natural_rescue(b): return
	if not await route.first_exit_and_hold(b): return
	orders = route.commands.size()
	if not _check_safe_effects(b): return
	if not _audit_bindings(b): return
	if not _write_new_json(output.path_join("route_commands.json"), route.commands): return
	if not _write_new_json(output.path_join("natural_route_checkpoints.json"), route.checkpoint_ticks): return
	single_safe_disk_qualified = await _save(b, HANDOFF_A, {})

func _on_held(_clock: Dictionary) -> void:
	held = true
	held_physics = Engine.get_physics_frames()

func _on_rejected(code: String) -> void: rejected = code

func _hold(b: Node, label: String) -> bool:
	held = false
	rejected = ""
	held_physics = -1
	b._save_barrier.capture_ready.connect(_on_held, CONNECT_ONE_SHOT)
	b._save_barrier.capture_rejected.connect(_on_rejected, CONNECT_ONE_SHOT)
	var requested: Dictionary = b._save_barrier.request_capture()
	if not check(label + " actual barrier request", requested.get("ok", false), requested): return false
	var deadline: int = Time.get_ticks_msec() + 15000
	for frame in range(180):
		await get_tree().process_frame
		if held or not rejected.is_empty() or Time.get_ticks_msec() >= deadline: break
	return check(label + " real healthy HELD", held and rejected.is_empty() and b._save_barrier.state == b._save_barrier.State.HELD and b._save_barrier.health().ok, {"rejected": rejected, "health": b._save_barrier.health(), "held_physics": held_physics})

func _retreat_state(b: Node) -> Dictionary:
	var value: Dictionary = route.observe(b)
	value["mission_elapsed"] = b.mission.elapsed
	value["level_elapsed"] = b.level.elapsed
	value["next_tick"] = str(b._run_clock._next_tick)
	return value

func _save(b: Node, handoff_path: String, expected: Dictionary) -> bool:
	var saver: RefCounted = Session.new(trusted, runtime, SLOT_ROOT)
	var before: int = Time.get_ticks_msec()
	var stage_started: int = b.mission._stage_started_ms
	var saved: Dictionary = saver.save_held(b, retained_identity, expected)
	var after: int = Time.get_ticks_msec()
	if not check("complete Session save_held succeeds", saved.get("ok", false), saved): return false
	var slot: Dictionary = Store.new(SLOT_ROOT).read_slot()
	if not check("actual committed disk head matches receipt", slot.get("ok", false) and slot.file_sha256 == saved.file_sha256 and slot.revision == saved.generation, slot.get("code", "")): return false
	if not check("complete installed campaign packet and paused resume", slot.document.schema == Store.CAMPAIGN_SCHEMA and slot.document.context == Profiles.DAMING_CONTEXT and slot.document.resume_paused): return false
	var mission: Dictionary = Codec.new().decode(slot.document.world.sections.mission.payload).value
	var source_age: int = int(mission.values.stage_age_ms)
	if not check("source Mission wall age bounded at actual Session capture", source_age >= before - stage_started and source_age <= after - stage_started): return false
	var packet_name: String = output.path_join("saved_packet.json")
	if not _write_new_json(packet_name, slot.document): return false
	if not _write_new_json(output.path_join("saved_world.json"), slot.document.world): return false
	var next_handoff := {"schema": "daming_safe_retreat_cross_process_handoff_v25", "mode": mode, "pid": OS.get_process_id(), "nonce": nonce, "first_role": first_role, "content_version": trusted.content_version, "engine_sha256": trusted.engine_binary_sha256, "file_sha256": slot.file_sha256, "generation": slot.revision, "packet": slot.document, "state": _retreat_state(b), "source_timing": {"capture_before": before, "capture_after": after, "stage_started": stage_started, "source_stage_age": source_age, "held_physics": held_physics}, "ancestor_pids": [], "ancestor_nonces": []}
	if not handoff.is_empty():
		next_handoff.ancestor_pids = handoff.ancestor_pids.duplicate()
		next_handoff.ancestor_nonces = handoff.ancestor_nonces.duplicate()
		next_handoff.ancestor_pids.append(handoff.pid)
		next_handoff.ancestor_nonces.append(handoff.nonce)
	if not _write_new_json(handoff_path, next_handoff): return false
	observations.append({"saved": next_handoff.state, "slot_sha256": slot.file_sha256, "generation": slot.revision})
	return true

func _restore() -> Node:
	handoff = _read_json(HANDOFF_A if mode == CASES[1] else HANDOFF_B)
	if not check("complete prior process handoff", handoff.has_all(["schema", "mode", "pid", "nonce", "first_role", "content_version", "engine_sha256", "file_sha256", "generation", "packet", "state", "source_timing", "ancestor_pids", "ancestor_nonces"])): return null
	var expected_mode: String = CASES[0] if mode == CASES[1] else CASES[1]
	if not check("correct preceding genuinely distinct process", handoff.schema == "daming_safe_retreat_cross_process_handoff_v25" and handoff.mode == expected_mode and handoff.first_role == first_role and int(handoff.pid) != OS.get_process_id() and handoff.nonce != nonce and not handoff.ancestor_pids.has(OS.get_process_id()) and not handoff.ancestor_nonces.has(nonce)): return null
	if not check("same frozen source and actual engine across processes", handoff.content_version == trusted.content_version and handoff.engine_sha256 == trusted.engine_binary_sha256): return null
	var slot: Dictionary = Store.new(SLOT_ROOT).read_slot(true)
	if not check("prior disk bytes and generation verified", slot.get("ok", false) and slot.file_sha256 == handoff.file_sha256 and slot.revision == int(handoff.generation), slot.get("code", "")): return null
	# The actual Store hash above proves disk bytes. Normalize only this external
	# handoff comparison through JSON; it gives both sides identical number types.
	# All strict component comparisons below use the Store-validated packet.
	if not check("handoff retains the full committed packet", JSON.parse_string(JSON.stringify(slot.document)) == handoff.packet): return null
	if not _write_new_json(output.path_join("input_packet.json"), slot.document): return null
	if not _write_new_json(output.path_join("input_world.json"), slot.document.world): return null
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	get_tree().paused = true
	restore_session = Session.new(trusted, runtime, SLOT_ROOT)
	var prepare_before: int = Time.get_ticks_msec()
	var prepared: Dictionary = restore_session.prepare_restore(menu)
	var prepare_after: int = Time.get_ticks_msec()
	if not check("actual Session prepare_restore succeeds", prepared.get("ok", false), prepared): return null
	if not check("old menu retained and new entire Battle detached inert", get_tree().current_scene == menu and not prepared.battle.is_inside_tree() and prepared.battle.process_mode == Node.PROCESS_MODE_DISABLED): return null
	# Stage separately only to observe the real Session mount bounds and rebased
	# pointer stamps. commit_restore_async then owns native layout/final activation.
	var mount_before: int = Time.get_ticks_msec()
	var staged: Dictionary = restore_session.stage_mount()
	var mount_after: int = Time.get_ticks_msec()
	if not check("actual Session paused stage_mount succeeds", staged.get("ok", false), staged): return null
	var mounted_input_stamps := {}
	for field: String in ["_last_group_time", "_press_ms", "_last_tap_ms"]: mounted_input_stamps[field] = staged.battle.get(field)
	var before_commit_physics: int = Engine.get_physics_frames()
	var installed: Dictionary = await restore_session.commit_restore_async(120)
	var after_commit_physics: int = Engine.get_physics_frames()
	if not check("actual Session commit_restore_async succeeds", installed.get("ok", false), installed): return null
	var b: Node = installed.battle
	retained_identity = installed.identity
	var activation_physics: int = b._run_clock._engine_anchor
	if not check("complete installed paused Battle and local resume", get_tree().current_scene == b and b.get_parent() == get_tree().root and get_tree().paused and _healthy(b) and not installed.steam_credit and installed.generation == slot.revision and installed.paused == slot.document.resume_paused and activation_physics >= before_commit_physics and activation_physics <= after_commit_physics): return null
	if not await _hold(b, "restored complete world"): return null
	if not _verify_packet_install(b, slot.document): return null
	var fresh_before: int = Time.get_ticks_msec()
	var fresh_process: int = Engine.get_process_frames()
	var fresh_stage_started: int = b.mission._stage_started_ms
	var capture: Dictionary = Core.new(trusted, runtime, {}, null, Profiles.DAMING_CONTEXT).capture(b, retained_identity)
	var fresh_after: int = Time.get_ticks_msec()
	if not check("fresh full Core capture at real restored HELD", capture.get("ok", false), capture): return null
	if not _write_new_json(output.path_join("restored_world.json"), capture.record): return null
	var times := {"prepare_before": prepare_before, "prepare_after": prepare_after, "mount_before": mount_before, "mount_after": mount_after, "mounted_input_stamps": mounted_input_stamps, "activation_physics": activation_physics, "held_physics": held_physics, "fresh_before": fresh_before, "fresh_after": fresh_after, "fresh_process": fresh_process, "fresh_stage_started": fresh_stage_started}
	if not _compare_complete_world(slot.document.world, capture.record, times): return null
	if not _audit_bindings(b): return null
	observations.append({"restored": _retreat_state(b), "clock_audit": times})
	return b

func _same_keys(left: Dictionary, right: Dictionary) -> bool:
	var a: Array = left.keys()
	var b: Array = right.keys()
	a.sort()
	b.sort()
	return a == b

func _verify_packet_install(b: Node, packet: Dictionary) -> bool:
	var required: Array = ["schema", "generation", "context", "binding", "resume_paused", "options", "session_settings", "root_node", "world"]
	if not check("complete Session packet field set retained", packet.size() == required.size() and packet.has_all(required)): return false
	var options: Dictionary = Codec.new().decode(packet.options)
	var settings: Dictionary = Codec.new().decode(packet.session_settings)
	var root_node: Dictionary = Codec.new().decode(packet.root_node)
	if not check("all Session install fields decode explicitly", options.ok and settings.ok and root_node.ok and options.value is Dictionary and settings.value is Dictionary and root_node.value is Dictionary): return false
	if not check("Session option/settings schemas complete", options.value.size() == Store.OPTIONS.size() and options.value.has_all(Store.OPTIONS) and settings.value.size() == Store.SESSION_SETTINGS.size() and settings.value.has_all(Store.SESSION_SETTINGS)): return false
	var campaign: Node = get_node("/root/Campaign")
	var actual_options := {}
	for field: String in Store.OPTIONS: actual_options[field] = campaign.get(field)
	if not check("every Session Campaign option installed exactly", actual_options == options.value): return false
	var actual_settings := {}
	for field: String in Store.SESSION_SETTINGS: actual_settings[field] = get_node("/root/Settings").get(field)
	if not check("every Session setting installed exactly", actual_settings == settings.value): return false
	var selected: Dictionary = Profiles.normalize_context(packet.context)
	if not check("Session context fixed installed Daming profile", selected.ok and selected.context == Profiles.DAMING_CONTEXT and selected.profile_id == Profiles.DAMING_ID): return false
	var flags: Dictionary = Profiles.install_flags(selected.profile_id)
	if not check("installed Session campaign flags explicitly available", flags.ok and not flags.flags.is_empty()): return false
	var actual_flags := {}
	for field: String in flags.flags: actual_flags[field] = campaign.get(field)
	if not check("every installed profile flag exact after Session commit", actual_flags == flags.flags): return false
	if not check("Session context and saved resume pause actually installed", b._official_context == packet.context and packet.resume_paused and get_tree().paused and b._save_barrier._was_paused == packet.resume_paused): return false
	if not check("Session binding is explicit local-only schema", packet.binding is Dictionary and packet.binding.has_all(["kind", "token", "receipt_sha256"]) and packet.binding.size() == 3 and packet.binding.kind == "uncredited" and b._steam_run_id == 0 and is_instance_valid(b._continue_receipt)): return false
	var local_script: Script = load("res://scripts/run_local_lifecycle.gd")
	if not check("actual local receipt fixed script/token/slot scope", b._continue_receipt.get_script() == local_script and b._continue_receipt.token == packet.binding.token and b._continue_receipt.directory == local_script.new(packet.binding.token, SLOT_ROOT).directory): return false
	var binding: Dictionary = b._continue_receipt.binding()
	if not check("actual durable local lifecycle binding exact", binding.ok and binding.binding == packet.binding): return false
	var steam: Node = get_node("/root/SteamService")
	if not check("Steam-disabled Session active lease/context installed", steam._active_run == 0 and steam._context == packet.context): return false
	var adapter: RefCounted = Core.new(trusted, runtime, {}, null, Profiles.DAMING_CONTEXT)
	var actual_root: Dictionary = adapter._visuals(b)._read_node(b)
	if not check("complete saved Visual root_node installed exactly at HELD", actual_root == root_node.value): return false
	return _write_new_json(output.path_join("session_packet_install_audit.json"), {"packet_generation": packet.generation, "options": actual_options, "session_settings": actual_settings, "profile_flags": actual_flags, "context": b._official_context, "resume_paused": b._save_barrier._was_paused, "binding": binding.binding, "steam_run_id": b._steam_run_id, "steam_active_run": steam._active_run, "steam_context": steam._context, "root_node": packet.root_node, "actual_root_node": Codec.new().encode(actual_root).value})

func _compare_complete_world(original: Dictionary, fresh: Dictionary, times: Dictionary) -> bool:
	var required: Array = ["schema", "profile", "content_version", "engine_sha256", "sections"]
	if not check("complete whole-world envelope and field set exact", original.size() == required.size() and original.has_all(required) and _same_keys(original, fresh)): return false
	var old_envelope: Dictionary = original.duplicate(true)
	var new_envelope: Dictionary = fresh.duplicate(true)
	old_envelope.erase("sections")
	new_envelope.erase("sections")
	if not check("whole-world schema/profile/context/content/engine envelope exact", old_envelope == new_envelope): return false
	if not check("complete exact section keyset retained", _same_keys(original.sections, fresh.sections) and original.sections.size() == Core.CAMPAIGN_SECTIONS.size() and original.sections.has_all(Core.CAMPAIGN_SECTIONS)): return false
	for section: String in ["mission", "root"]:
		var old_wrapper: Dictionary = original.sections[section].duplicate(true)
		var new_wrapper: Dictionary = fresh.sections[section].duplicate(true)
		if not check("complete " + section + " wrapper field set exact", old_wrapper.has("payload") and new_wrapper.has("payload") and _same_keys(old_wrapper, new_wrapper)): return false
		old_wrapper.erase("payload")
		new_wrapper.erase("payload")
		if not check("every non-payload " + section + " wrapper field exact", old_wrapper == new_wrapper): return false
	var old_mission_decode: Dictionary = Codec.new().decode(original.sections.mission.payload)
	var new_mission_decode: Dictionary = Codec.new().decode(fresh.sections.mission.payload)
	if not check("full Mission payload explicitly decoded", old_mission_decode.ok and new_mission_decode.ok): return false
	var old_mission: Dictionary = old_mission_decode.value
	var new_mission: Dictionary = new_mission_decode.value
	var saved_age: int = int(old_mission.values.stage_age_ms)
	var fresh_age: int = int(new_mission.values.stage_age_ms)
	var mission_clock_ok: bool = saved_age == int(handoff.source_timing.source_stage_age) and times.fresh_stage_started >= times.prepare_before - saved_age and times.fresh_stage_started <= times.prepare_after - saved_age and fresh_age >= times.fresh_before - times.fresh_stage_started and fresh_age <= times.fresh_after - times.fresh_stage_started
	if not check("Mission complete wall age rebased within real prepare/capture intervals", mission_clock_ok): return false
	old_mission.values.erase("stage_age_ms")
	new_mission.values.erase("stage_age_ms")
	var differs: Array = []
	for section: String in original.sections:
		if section == "root": continue
		var equal: bool = old_mission == new_mission if section == "mission" else original.sections[section] == fresh.sections[section]
		if not equal: differs.append(section)
	if not check("all complete non-root sections exact after independent install", differs.is_empty(), differs): return false
	var old_root_decode: Dictionary = Codec.new().decode(original.sections.root.payload)
	var new_root_decode: Dictionary = Codec.new().decode(fresh.sections.root.payload)
	if not check("full Root payload explicitly decoded", old_root_decode.ok and new_root_decode.ok): return false
	var old_root: Dictionary = old_root_decode.value
	var new_root: Dictionary = new_root_decode.value
	if not check("full Root clock subfield schemas exact", _same_keys(old_root.simulation, new_root.simulation) and old_root.simulation.size() == 4 and old_root.simulation.has_all(["schema", "physics_hz", "next_tick", "cache_frame"]) and _same_keys(old_root.clocks, new_root.clocks) and old_root.clocks.size() == 3 and old_root.clocks.has_all(["physics", "process", "msec"]) and _same_keys(old_root.clock_values, new_root.clock_values) and old_root.clock_values.size() == 5 and old_root.clock_values.has_all(["_last_group_time", "_press_ms", "_last_tap_ms", "_res_block_frame", "_eco_lane_cache_bucket"])): return false
	var clock_ok: bool = old_root.simulation.schema == new_root.simulation.schema and old_root.simulation.physics_hz == new_root.simulation.physics_hz and old_root.simulation.next_tick == new_root.simulation.next_tick
	clock_ok = clock_ok and int(new_root.simulation.cache_frame) == int(old_root.simulation.cache_frame) + int(times.held_physics) - int(times.activation_physics)
	clock_ok = clock_ok and int(new_root.clocks.physics) == int(new_root.simulation.cache_frame) and new_root.clocks.process == times.fresh_process and new_root.clocks.msec >= times.fresh_before and new_root.clocks.msec <= times.fresh_after
	for field: String in ["_last_group_time", "_press_ms", "_last_tap_ms"]:
		var age: int = int(old_root.clocks.msec) - int(old_root.clock_values[field])
		var stamp: int = int(times.mounted_input_stamps[field])
		clock_ok = clock_ok and stamp >= times.mount_before - age and stamp <= times.mount_after - age and old_root.clock_values[field] == 0 and new_root.clock_values[field] == 0
	for field: String in ["_res_block_frame", "_eco_lane_cache_bucket"]: clock_ok = clock_ok and old_root.clock_values[field] == new_root.clock_values[field]
	if not check("Root logical tick/cache phase and mount/HELD input clock contract exact", clock_ok): return false
	for field: String in ["simulation", "clocks", "clock_values"]: old_root.erase(field); new_root.erase(field)
	if not check("all Root non-clock values/references/grids/economy exact", old_root == new_root): return false
	return _write_new_json(output.path_join("full_world_comparison.json"), {"compared": original.sections.keys(), "differing": differs, "mission_clock_qualified": mission_clock_ok, "root_clock_qualified": clock_ok, "all_root_nonclock_exact": old_root == new_root, "timing": times})

func _audit_bindings(b: Node) -> bool:
	if not check("new Mission and all Units refer to installed new Battle", b.mission.battle == b and b.units_root.get_children().all(func(u): return u.battle == b and u.map == b.map)): return false
	for u: Node in b.units_root.get_children():
		for signal_name: String in ["died", "story_resolved"]:
			var links: Array = u.get_signal_connection_list(signal_name)
			var expected_method: String = "_on_unit_died" if signal_name == "died" else "_on_unit_story_resolved"
			if not check("one installed Battle callback " + str(u.entity_id) + "/" + signal_name, links.size() == 1 and links[0].callable.get_object() == b and links[0].callable.get_method() == expected_method): return false
	for action_id: String in b.mission.actions:
		var a: Dictionary = b.mission.actions[action_id]
		if a.button != null:
			var links: Array = a.button.get_signal_connection_list("pressed")
			if not check("action control owns only new Mission callback " + action_id, links.size() == 1 and links[0].callable.get_object() == b.mission and links[0].callable.get_method() == "focus_action" and links[0].callable.get_bound_arguments() == [action_id] and a.button.get_parent() == b.mission._buttons): return false
		if not check("action marker belongs to new complete FX " + action_id, a.marker.get_parent() == b.fx_root and b.mission._markers.has(a.marker)): return false
	return true

func _release_and_run(b: Node) -> bool:
	var released: Dictionary = b._save_barrier.release_capture()
	if not check("actual restored barrier released", released.get("ok", false), released): return false
	# A was explicitly saved paused; resume this real paused battle deliberately.
	get_tree().paused = false
	return true

func _safe_text(u: Node) -> String:
	return Localize.text(u.setup_def.name) + Localize.text("已活着抵达城外接应地")

func _check_safe_effects(b: Node) -> bool:
	if not check("one safe actor remains coherent full FIGHT", route.single_safe_valid(b), _retreat_state(b)): return false
	var other: String = "shi" if first_role == "lu" else "lu"
	var first: Node = b.level.get(first_role)
	var remaining: Node = b.level.get(other)
	if not check("real safe report appears once and other report absent", b.mission.report.count(_safe_text(first)) == 1 and b.mission.report.count(_safe_text(remaining)) == 0): return false
	if not check("real rescue complete and freed event", b.mission.has_event("daming_prisoners_freed") and b.mission.actions.has(RESCUE_ID) and b.mission.actions[RESCUE_ID].done): return false
	return true

func _safe_effects(b: Node) -> Dictionary:
	var actor: Node = b.level.get(first_role)
	var id: String = str(actor.entity_id)
	var action: Dictionary = b.mission.actions[RESCUE_ID]
	var action_buttons := 0
	var action_markers := 0
	for node: Node in b.mission._buttons.get_children():
		var descriptor: Dictionary = node.get_meta("campaign_presentation_v1", {})
		if descriptor.get("kind") == "action" and descriptor.get("action_id") == RESCUE_ID: action_buttons += 1
	for node: Node in b.mission._markers:
		var descriptor: Dictionary = node.get_meta("campaign_presentation_v1", {})
		if descriptor.get("kind") == "marker" and descriptor.get("action_id") == RESCUE_ID: action_markers += 1
	return {"safe_id": id, "key": actor.key, "hp": actor.hp, "outcome": actor.story_outcome, "position": [actor.position.x, actor.position.y], "art_variant": actor.art_variant, "faction": actor.faction, "base_speed": actor.base_speed, "is_captive": actor.is_captive, "is_hero": actor.is_hero, "visible": actor.visible, "selected": actor.selected, "in_root": actor.get_parent() == b.units_root, "active": b.units.has(actor), "stopped": route._stopped(actor), "safe_event": b.mission.has_event("daming_" + first_role + "_safe"), "safe_report_count": b.mission.report.count(_safe_text(actor)), "rescue_done": action.done, "rescue_button_visible": action.button.visible, "rescue_marker_visible": action.marker.visible, "rescue_buttons": action_buttons, "rescue_markers": action_markers}

func _single_settle_resave(b: Node) -> void:
	if not check("B independently installed generation1 and no driver commands", int(handoff.generation) == 1 and orders == 0): return
	if not _check_safe_effects(b): return
	var baseline: Dictionary = _safe_effects(b)
	var start_tick: int = b._run_clock._next_tick
	var start_elapsed: float = b.mission.elapsed
	if not _release_and_run(b): return
	var deadline: int = Time.get_ticks_msec() + CONTINUE_LIMIT_MS
	while Time.get_ticks_msec() < deadline and b._run_clock._next_tick - start_tick < C_SETTLE_TICKS:
		await get_tree().process_frame
		if not _healthy(b): break
	var actual_ticks: int = b._run_clock._next_tick - start_tick
	if not check("B observed real ordinary clock ticks", _healthy(b) and actual_ticks >= C_SETTLE_TICKS and is_equal_approx(Engine.time_scale, 1.0) and Engine.physics_ticks_per_second == 60 and is_equal_approx(get_node("/root/Settings").game_speed, 1.0), {"actual": actual_ticks, "requested": C_SETTLE_TICKS}): return
	if not check("B Mission elapsed follows real physics ticks", absf((b.mission.elapsed - start_elapsed) - float(actual_ticks) / 60.0) < 0.0001): return
	get_tree().paused = true
	if not await _hold(b, "B settled single-safe resave"): return
	if not _check_safe_effects(b): return
	if not check("safe actor report/action/control identity does not replay or revive", _safe_effects(b) == baseline, _safe_effects(b)): return
	if not _audit_bindings(b): return
	if not _write_new_json(output.path_join("safe_no_replay_ticks.json"), {"ticks": actual_ticks, "baseline": baseline, "after": _safe_effects(b)}): return
	single_safe_disk_qualified = await _save(b, HANDOFF_B, {"revision": int(handoff.generation), "file_sha256": handoff.file_sha256})

func _on_terminal_operation(result: Dictionary) -> void:
	terminal_signal_results.append(result.duplicate(true))

func _campaign_observation() -> Dictionary:
	var c: Node = get_node("/root/Campaign")
	return {"records": c.records.duplicate(true), "unlocked": c.unlocked, "cloud_owner": c.cloud_owner, "level8_record": c.level_record("level8")}

func _steam_observation() -> Dictionary:
	var service: Node = get_node("/root/SteamService")
	return {"active_run": service._active_run, "stats": service.state.stats.duplicate(true), "unlocked": service.state.unlocked.duplicate(true), "settled": service.state.settled.duplicate(true)}

func _profile_file_row(path: String) -> Dictionary:
	var absolute := ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()
	var user_root := ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path().trim_suffix("/")
	if not check("known profile evidence path below isolated user root", absolute.begins_with(user_root + "/") and FileAccess.file_exists(path), path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not check("known profile evidence file readable", file != null, path): return {}
	var length := file.get_length()
	file.close()
	return {"relative_user_path": absolute.trim_prefix(user_root + "/"), "bytes": length, "sha256": FileAccess.get_sha256(path)}

func _campaign_file_observation() -> Dictionary:
	var path: String = get_node("/root/Campaign").SAVE_PATH
	if not FileAccess.file_exists(path): return {"exists": false}
	var row: Dictionary = _profile_file_row(path)
	if row.is_empty(): return {}
	return {"exists": true, "file": row}

func _terminal_head(token: String) -> Dictionary:
	var receipt: RefCounted = Lifecycle.new(token, SLOT_ROOT)
	var head: Dictionary = receipt.open_head()
	if not check("real local lifecycle terminal verified chain", head.get("ok", false) and int(head.get("revision", 0)) == 2 and head.get("document", {}).get("state") == "terminal" and head.get("document", {}).get("victory") == true, head.get("code", "")): return {}
	var files: Array = []
	for generation in [1, 2]:
		var row: Dictionary = _profile_file_row(receipt.directory.path_join("record_%010d.json" % generation))
		if row.is_empty(): return {}
		files.append(row)
	return {"token": token, "revision": head.revision, "file_sha256": head.file_sha256, "document": head.document, "files": files}

func _terminal_effects(b: Node) -> Dictionary:
	var event_ids: Array = ["daming_lu_safe", "daming_shi_safe", "daming_victory"]
	var events := {}
	for id: String in event_ids: events[id] = b.mission.events.get(id, false)
	return {"events": events, "lu_report_count": b.mission.report.count(_safe_text(b.level.lu)), "shi_report_count": b.mission.report.count(_safe_text(b.level.shi)), "victory_report_count": b.mission.report.count("两名获救者生还，梁山前营守住"), "mission_frozen": b.mission._result_frozen, "mission_result": b.mission._result_cache.duplicate(true), "stage_metrics": b.mission.stage_metrics.duplicate(true), "campaign": _campaign_observation(), "steam": _steam_observation(), "flow_result": get_node("/root/ContinueFlow").last_result.duplicate(true), "terminal_operation_signals": terminal_signal_results.duplicate(true)}

func _finish_natural_terminal(b: Node) -> void:
	if not check("C independent generation2 install and no driver commands", int(handoff.generation) == 2 and orders == 0): return
	if not _check_safe_effects(b): return
	var before_campaign: Dictionary = _campaign_observation()
	var before_steam: Dictionary = _steam_observation()
	var campaign_file_before: Dictionary = _campaign_file_observation()
	if not check("Campaign QA suppression remains enabled with file observed", OS.get_environment("CAMPAIGN_QA") == "1" and not campaign_file_before.is_empty()): return
	if not check("this isolated run has no prior clear or seal", not before_campaign.level8_record.cleared and not before_campaign.level8_record.story_complete): return
	var flow: Node = get_node("/root/ContinueFlow")
	if not check("no pending terminal operation before real final escort", flow.phase == flow.Phase.IDLE): return
	flow.operation_finished.connect(_on_terminal_operation)
	if not await route.finish_other_naturally(b): return
	orders = route.commands.size()
	if not check("one observed natural durable terminal notification", terminal_signal_results.size() == 1 and terminal_signal_results[0].get("ok", false) and terminal_signal_results[0].get("terminal_completed", false) and terminal_signal_results[0].get("local_terminal", false), terminal_signal_results): return
	if not check("normal completion froze actual Mission result", b.mission._result_frozen and b.mission._result_cache.get("core_cleared", false), b.mission._result_cache): return
	var result: Dictionary = b.mission._result_cache.duplicate(true)
	var after_campaign: Dictionary = _campaign_observation()
	var record: Dictionary = after_campaign.level8_record
	if not check("same-run local campaign core result present in memory", record.cleared and record.best_done == result.story_done and record.story_total == result.story_total and record.best_goal_ids == result.done_ids and record.story_complete == result.story_complete and record.contract_version == result.contract_version): return
	if not check("private Steam service performs zero credited settlement", b._steam_run_id == 0 and _steam_observation() == before_steam): return
	if not check("actual terminal HUD displayed after completion", b.hud._end_root.visible and b.hud._end_title.text == Localize.text("旗开得胜！") and b.hud._end_sub.text.contains(Localize.format_text("\n基础通关：%s", Localize.text("完成"))), {"visible": b.hud._end_root.visible, "title": b.hud._end_title.text, "sub": b.hud._end_sub.text}): return
	var terminal: Dictionary = _terminal_head(handoff.packet.binding.token)
	if terminal.is_empty(): return
	# Campaign._save explicitly suppresses all cfg writes under CAMPAIGN_QA=1.
	# Capture the actual memory result above; never pretend it is durable Campaign data.
	var campaign_file_after: Dictionary = _campaign_file_observation()
	if not check("QA Campaign file deliberately remains absent or exactly unchanged", campaign_file_after == campaign_file_before, campaign_file_after): return
	var baseline: Dictionary = _terminal_effects(b)
	if not check("safe and victory reports each exactly once", baseline.lu_report_count == 1 and baseline.shi_report_count == 1 and baseline.victory_report_count == 1, baseline): return
	for frame in range(120): await get_tree().process_frame
	if not check("post-terminal normal frames add no result or callback signal", b.phase == b.Phase.END and _terminal_effects(b) == baseline, _terminal_effects(b)): return
	var terminal_after: Dictionary = _terminal_head(handoff.packet.binding.token)
	if not check("post-terminal real local journal remains exact", terminal_after == terminal and _campaign_file_observation() == campaign_file_before): return
	var latest: Dictionary = Store.new(SLOT_ROOT).read_slot()
	if not check("actual terminal preserves last complete generation2 slot bytes", latest.get("ok", false) and latest.revision == 2 and latest.file_sha256 == handoff.file_sha256): return
	var next_handoff := {"schema": "daming_safe_retreat_terminal_handoff_v25", "mode": mode, "first_role": first_role, "pid": OS.get_process_id(), "nonce": nonce, "content_version": trusted.content_version, "engine_sha256": trusted.engine_binary_sha256, "slot_file_sha256": latest.file_sha256, "slot_generation": latest.revision, "slot_binding": latest.document.binding, "terminal": terminal, "campaign": after_campaign, "campaign_before": before_campaign, "campaign_file": campaign_file_before, "campaign_persistence_qualified": false, "campaign_persistence_boundary": "Campaign._save returns without writing under CAMPAIGN_QA=1", "effects": baseline, "ancestor_pids": handoff.ancestor_pids.duplicate(), "ancestor_nonces": handoff.ancestor_nonces.duplicate()}
	next_handoff.ancestor_pids.append(handoff.pid)
	next_handoff.ancestor_nonces.append(handoff.nonce)
	if not _write_new_json(output.path_join("terminal_observation.json"), next_handoff): return
	if not _write_new_json(output.path_join("route_commands.json"), route.commands): return
	if not _write_new_json(HANDOFF_C, next_handoff): return
	terminal_qualified = true
	observations.append({"natural_terminal": true, "same_run_story_complete_in_memory": result.story_complete, "campaign_persistence_qualified": false, "full_story_seal_condition": result.story_complete and not before_campaign.level8_record.story_complete, "steam_credit": false, "observed_terminal_operation_signal_count": terminal_signal_results.size(), "callback_invocation_count_qualified": false})

func _verify_relative_profile_file(row: Dictionary) -> bool:
	if not check("terminal file row fixed fields", row.size() == 3 and row.has_all(["relative_user_path", "bytes", "sha256"]) and typeof(row.relative_user_path) == TYPE_STRING and not row.relative_user_path.is_empty() and not row.relative_user_path.is_absolute_path() and ".." not in row.relative_user_path.replace("\\", "/").split("/") and typeof(row.sha256) == TYPE_STRING and row.sha256.length() == 64 and row.sha256.is_valid_hex_number()): return false
	return check("fresh process profile file bytes exact", _profile_file_row("user://" + row.relative_user_path) == row, row.relative_user_path)

func _read_terminal_in_new_process() -> void:
	handoff = _read_json(HANDOFF_C)
	if not check("complete actual C terminal handoff", handoff.has_all(["schema", "mode", "first_role", "pid", "nonce", "content_version", "engine_sha256", "slot_file_sha256", "slot_generation", "slot_binding", "terminal", "campaign", "campaign_before", "campaign_file", "campaign_persistence_qualified", "effects", "ancestor_pids", "ancestor_nonces"])): return
	if not check("terminal handoff correct distinct process role source chain", handoff.schema == "daming_safe_retreat_terminal_handoff_v25" and handoff.mode == CASES[2] and handoff.first_role == first_role and int(handoff.pid) != OS.get_process_id() and handoff.nonce != nonce and not handoff.ancestor_pids.has(OS.get_process_id()) and not handoff.ancestor_nonces.has(nonce) and handoff.content_version == trusted.content_version and handoff.engine_sha256 == trusted.engine_binary_sha256): return
	var slot: Dictionary = Store.new(SLOT_ROOT).read_slot()
	if not check("new process verifies old slot remains exact generation2", slot.get("ok", false) and slot.revision == 2 and slot.file_sha256 == handoff.slot_file_sha256 and JSON.parse_string(JSON.stringify(slot.document.binding)) == handoff.slot_binding): return
	var terminal: Dictionary = _terminal_head(slot.document.binding.token)
	if terminal.is_empty(): return
	if not check("new process exact terminal receipt full readback", JSON.parse_string(JSON.stringify(terminal)) == handoff.terminal): return
	for row: Dictionary in handoff.terminal.files:
		if not _verify_relative_profile_file(row): return
	if handoff.campaign_file.get("exists", false):
		if not _verify_relative_profile_file(handoff.campaign_file.file): return
	elif not check("new process QA did not create Campaign file", _campaign_file_observation() == {"exists": false}): return
	if not check("new process reloads prior Campaign baseline because QA suppressed write", handoff.campaign_persistence_qualified == false and JSON.parse_string(JSON.stringify(_campaign_observation())) == handoff.campaign_before): return
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	get_tree().paused = true
	var before_canvas: Transform2D = get_tree().root.canvas_transform
	var before_campaign: Dictionary = _campaign_observation()
	var before_nodes: Array = get_tree().root.get_children().duplicate()
	var rejected_session: RefCounted = Session.new(trusted, runtime, SLOT_ROOT)
	var prepared: Dictionary = rejected_session.prepare_restore(menu)
	if not check("actual Session refuses obsolete active slot after durable terminal", not prepared.get("ok", false) and prepared.get("code", "") == "LOCAL_RUN_TERMINAL", prepared): rejected_session.dispose(); return
	if not check("terminal rejected before any new Battle Unit or graph allocation", rejected_session._core._battle == null and rejected_session._core._identity == null and rejected_session._core._unit_plan.is_empty() and get_tree().current_scene == menu and get_tree().root.get_children() == before_nodes and get_tree().root.canvas_transform == before_canvas and _campaign_observation() == before_campaign): rejected_session.dispose(); return
	var disposed: Dictionary = rejected_session.dispose()
	if not check("rejected Session safely disposes", disposed.get("ok", false), disposed): return
	for row: Dictionary in handoff.terminal.files:
		if not _verify_relative_profile_file(row): return
	if handoff.campaign_file.get("exists", false):
		if not _verify_relative_profile_file(handoff.campaign_file.file): return
	elif not check("new process QA did not create Campaign file", _campaign_file_observation() == {"exists": false}): return
	if not _write_new_json(output.path_join("fresh_terminal_readback.json"), {"terminal": terminal, "campaign": _campaign_observation(), "slot_sha256": slot.file_sha256, "actual_restore_rejection": prepared, "campaign_runtime_after_C": handoff.campaign, "campaign_persistence_qualified": false, "no_new_battle": true, "steam_credit": false}): return
	terminal_readback_qualified = true

func finish() -> void:
	if finished: return
	finished = true
	var passed: bool = not checks.is_empty() and checks.all(func(row): return row.passed)
	var report := {"schema": "daming_safe_retreat_cross_process_report_v25", "case": mode, "pid": OS.get_process_id(), "nonce": nonce, "passed": passed, "checks": checks, "observations": observations, "evidence": evidence, "trusted": trusted, "orders": orders, "previous_pid": handoff.get("pid", 0), "previous_nonce": handoff.get("nonce", ""), "private_profile": profile, "actual_user_data_dir": OS.get_user_data_dir(), "full_world_case_only": true, "public_campaign_continue_qualified": false, "first_role": first_role, "single_safe_disk_case_qualified": passed and single_safe_disk_qualified, "natural_victory_qualified": passed and terminal_qualified, "local_terminal_readback_qualified": passed and terminal_readback_qualified, "campaign_persistence_qualified": false, "steam_reward_once_qualified": false, "callback_invocation_count_qualified": false, "negative_harness_status": "not_implemented_not_run", "teleports": 0, "fixture_ticks": 0, "progress_injections": 0, "clock_acceleration": false, "scope": "External unexecuted runner adapted from failing v24o baseline; requires qualified successor audit corrections. Natural rescue/single-safe complete disk Session install/resave and durable local natural terminal; each case qualified only by actual checks. No public continue, Steam reward, release, performance or device qualification."}
	if output.is_empty() or not DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output.path_join("report.json")):
		print("DAMING_RETREAT REPORT_PATH_NOT_FRESH")
		passed = false
	else:
		var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
		if file == null: passed = false
		else: file.store_string(JSON.stringify(report, "\t") + "\n"); file.close()
	# Dispose the installed world and caller-owned identity only after evidence.
	if is_instance_valid(battle):
		battle.queue_free()
		await get_tree().process_frame
	if retained_identity != null: retained_identity.dispose(); retained_identity = null
	if restore_session != null: restore_session.dispose(); restore_session = null
	print("DAMING_RETREAT_V25_COMPLETE ", mode, " ", checks.size(), " ", passed)
	get_node("/root/Sfx").shutdown()
	get_node("/root/Music").shutdown()
	get_tree().quit(0 if passed else 1)
