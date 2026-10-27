extends Node
## External capture-only base for the current closed-A raw fixture contract.
## Session installs the original typed packet; no old handoff/packet/world fixture is synthesized.
## Full original packet/world/binding/HELD audits are retained; no natural-Flow qualification.
const Support := preload("worker_support.gd")
const SLOT_ROOT := "user://continue/v1"
var B: Script
var Daming: Script
var Profiles: Script
var Factory: Script
var Provider: Script
var Session: Script
var Store: Script
var Core: Script
var Codec: Script
var Lifecycle: Script
var Intent: Script
var support: RefCounted
var admitted: Dictionary = {}
var trusted: Dictionary = {}
var runtime: Dictionary = {}
var checks: Array = []
var observations: Array = []
var evidence: Array = []
var capture_packet: Dictionary = {}
var capture_adapter: RefCounted
var restore_session: RefCounted
var retained_identity: RefCounted
var owned_installed_battle: Node
var owned_menu: Node
var battle: Node
var held := false
var rejected := ""
var held_physics := -1
var finished := false
var nonce := ""
var output := ""
var profile := ""
var first_role := ""
var evidence_serial := 0

func _brief(value: Variant) -> Dictionary:
	var out := {"type": type_string(typeof(value))}
	if value is Dictionary:
		for field: String in ["code", "path", "field", "section"]:
			if typeof(value.get(field)) == TYPE_STRING: out[field] = value[field].left(200)
		out["summary"] = "fields=" + str(value.size()) + "; ok=" + str(value.get("ok", "missing"))
	else: out["summary"] = str(value).left(200)
	return out

func check(label: String, passed: bool, detail: Variant = null) -> bool:
	checks.append({"label": label, "passed": passed, "detail": null if passed else _brief(detail)})
	if not passed: print("DN_CAPTURE_FAIL ", label, " ", _brief(detail))
	return passed

func _clone(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value

func _bits(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8); bytes.encode_double(0, value)
	return bytes.hex_encode()

func _exact(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b): return false
	if a is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _exact(a[key], b[key]): return false
		return true
	if a is Array:
		if a.size() != b.size(): return false
		for i: int in range(a.size()):
			if not _exact(a[i], b[i]): return false
		return true
	if typeof(a) == TYPE_FLOAT: return _bits(a) == _bits(b)
	return is_same(a, b) if typeof(a) == TYPE_OBJECT else a == b

func _live_view(value: Variant) -> Variant:
	if typeof(value) == TYPE_OBJECT:
		return {"type": "Object", "valid": is_instance_valid(value), "object_id": str(value.get_instance_id()) if is_instance_valid(value) else "expired"}
	if typeof(value) == TYPE_FLOAT: return {"type": "Float", "ieee_f64": _bits(value)}
	if value is Dictionary:
		var entries: Array = []
		for key: Variant in value: entries.append({"key": _live_view(key), "value": _live_view(value[key])})
		return {"type": "Dictionary", "entries": entries}
	if value is Array:
		var items: Array = []
		for item: Variant in value: items.append(_live_view(item))
		return {"type": "Array", "items": items}
	var encoded: Dictionary = Codec.new().encode(value)
	return {"type": type_string(typeof(value)), "codec": encoded.get("value"), "codec_ok": encoded.get("ok", false)}

func _write_new_json(path: String, value: Variant) -> bool:
	# Inherited complete packet audit is called before AND after the mutation.
	# Give each raw artifact a fresh path; never overwrite an earlier audit.
	evidence_serial += 1
	var fresh: String = path.get_base_dir().path_join(str(evidence_serial).pad_zeros(4) + "_" + path.get_file())
	if not check("new evidence path unused " + fresh.get_file(), not FileAccess.file_exists(fresh)): return false
	var file := FileAccess.open(fresh, FileAccess.WRITE)
	if not check("complete raw evidence writable " + fresh.get_file(), file != null): return false
	file.store_string(JSON.stringify(value, "\t") + "\n"); file.close()
	evidence.append({"path": fresh, "sha256": FileAccess.get_sha256(fresh)})
	return true

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
	Lifecycle = load("res://scripts/run_campaign_local_lifecycle.gd")
	Intent = load("res://scripts/run_campaign_progress_intent.gd")
	# No historical res://tools parent, natural route or gameplay driver is loaded.

func _healthy(b: Node) -> bool:
	return is_instance_valid(b) and b.phase == b.Phase.FIGHT and b.level.get_script() == Daming and b.gameplay_rng_fault().is_empty() and b._run_clock.fault().is_empty() and is_equal_approx(Engine.time_scale, 1.0)

func _on_held(_clock: Dictionary) -> void:
	held = true
	held_physics = Engine.get_physics_frames()

func _on_rejected(code: String) -> void: rejected = code

func _hold_owned_links(barrier: Node, signal_name: String, callback: Callable) -> Array:
	var found: Array = []
	for link: Dictionary in barrier.get_signal_connection_list(signal_name):
		if link.callable == callback: found.append(link)
	return found

func _hold_other_links(barrier: Node, signal_name: String, callback: Callable) -> Array:
	var found: Array = []
	for link: Dictionary in barrier.get_signal_connection_list(signal_name):
		if link.callable != callback: found.append({"callable": link.callable, "flags": link.flags})
	return found

func _hold_link_summary(links: Array) -> Dictionary:
	var flags: Array = []
	var targets: Array = []
	var methods: Array = []
	var bound_counts: Array = []
	var unbound_counts: Array = []
	for link: Dictionary in links:
		var callback: Callable = link.callable
		flags.append(int(link.flags))
		targets.append(callback.get_object_id())
		methods.append(String(callback.get_method()))
		bound_counts.append(callback.get_bound_arguments().size())
		unbound_counts.append(callback.get_unbound_arguments_count())
	return {"own_count": links.size(), "flags": flags, "targets": targets, "methods": methods, "bound_counts": bound_counts, "unbound_counts": unbound_counts}

func _hold_cleanup(barrier: Node, label: String, stage: String) -> bool:
	var results: Dictionary = {}
	var clean := true
	for name: String in ["capture_ready", "capture_rejected"]:
		var callback: Callable = Callable(self, "_on_held" if name == "capture_ready" else "_on_rejected")
		var own_before: Array = _hold_owned_links(barrier, name, callback)
		var other_before: Array = _hold_other_links(barrier, name, callback)
		# Only this exact unbound callable is removed; other targets/methods/binds
		# remain registered even when they listen to the same barrier signal.
		if barrier.is_connected(name, callback): barrier.disconnect(name, callback)
		var own_after: Array = _hold_owned_links(barrier, name, callback)
		var other_after: Array = _hold_other_links(barrier, name, callback)
		var untouched: bool = other_before == other_after
		var summary: Dictionary = _hold_link_summary(own_before)
		summary["own_after"] = own_after.size()
		summary["flags_after"] = _hold_link_summary(own_after).flags
		summary["other_before"] = other_before.size()
		summary["other_after"] = other_after.size()
		summary["other_unchanged"] = untouched
		results[name] = summary
		clean = check(label + " " + stage + " " + name + " only own listeners cleared", own_after.is_empty() and untouched, summary) and clean
	observations.append({"hold_connection_audit": {"label": label, "stage": stage, "signals": results}})
	return check(label + " " + stage + " both own barrier listeners cleared", clean, results)

func _hold(b: Node, label: String) -> bool:
	var barrier: Node = b._save_barrier
	if not _hold_cleanup(barrier, label, "before_connect"): return false
	held = false
	rejected = ""
	held_physics = -1
	var ready_error: int = barrier.capture_ready.connect(_on_held, CONNECT_ONE_SHOT)
	var rejected_error: int = barrier.capture_rejected.connect(_on_rejected, CONNECT_ONE_SHOT)
	var ready_links: Array = _hold_owned_links(barrier, "capture_ready", Callable(self, "_on_held"))
	var rejected_links: Array = _hold_owned_links(barrier, "capture_rejected", Callable(self, "_on_rejected"))
	var ready_summary: Dictionary = _hold_link_summary(ready_links)
	var rejected_summary: Dictionary = _hold_link_summary(rejected_links)
	var exact: bool = ready_error == OK and rejected_error == OK and ready_links.size() == 1 and rejected_links.size() == 1
	exact = exact and ready_summary.flags == [CONNECT_ONE_SHOT] and rejected_summary.flags == [CONNECT_ONE_SHOT]
	exact = exact and ready_summary.targets == [get_instance_id()] and rejected_summary.targets == [get_instance_id()]
	exact = exact and ready_summary.methods == ["_on_held"] and rejected_summary.methods == ["_on_rejected"]
	exact = exact and ready_summary.bound_counts == [0] and rejected_summary.bound_counts == [0] and ready_summary.unbound_counts == [0] and rejected_summary.unbound_counts == [0]
	observations.append({"hold_connection_audit": {"label": label, "stage": "installed", "signals": {"capture_ready": ready_summary, "capture_rejected": rejected_summary}, "ready_error": ready_error, "rejected_error": rejected_error}})
	if not check(label + " exact two owned one-shot barrier listeners", exact, {"ready": ready_summary, "rejected": rejected_summary, "ready_error": ready_error, "rejected_error": rejected_error}):
		_hold_cleanup(barrier, label, "connect_failure")
		return false
	var requested: Dictionary = b._save_barrier.request_capture()
	if not check(label + " actual barrier request", requested.get("ok", false), requested):
		_hold_cleanup(barrier, label, "request_refused")
		return false
	var deadline: int = Time.get_ticks_msec() + 15000
	for frame in range(180):
		await get_tree().process_frame
		if held or not rejected.is_empty() or Time.get_ticks_msec() >= deadline: break
	var ready: bool = check(label + " real healthy HELD", held and rejected.is_empty() and b._save_barrier.state == b._save_barrier.State.HELD and b._save_barrier.health().ok, {"rejected": rejected, "health": b._save_barrier.health(), "held_physics": held_physics})
	var cleaned: bool = _hold_cleanup(barrier, label, "after_wait")
	return ready and cleaned

func _retreat_state(b: Node) -> Dictionary:
	return {"phase": b.phase, "lu_id": str(b.level.lu.entity_id), "shi_id": str(b.level.shi.entity_id), "lu_outcome": b.level.lu.story_outcome, "shi_outcome": b.level.shi.story_outcome, "events": b.mission.events.duplicate(true), "mission_elapsed": b.mission.elapsed, "level_elapsed": b.level.elapsed, "next_tick": str(b._run_clock._next_tick)}

func _profile_check() -> bool:
	if admitted.is_empty() or support == null or support.reader == null: return check("admitted raw fixture exists for profile audit", false)
	var descriptor: Dictionary = admitted.descriptor
	var scope: String = ProjectSettings.globalize_path(SLOT_ROOT).replace("\\", "/").simplify_path().trim_suffix("/")
	if not check("complete private copy has exactly original two-file six-directory inventory", support.reader.inventory_matches(scope,descriptor.frozen_inventory,admitted.packet.binding.token)): return false
	if not check("private slot exact raw SHA", FileAccess.get_sha256(scope.path_join("5088120/1/record_0000000001.json")) == support.request.slot.sha256): return false
	if not check("private LC3 exact raw SHA", FileAccess.get_sha256(scope.path_join("local_runs/"+admitted.packet.binding.token+"/5088120/1/record_0000000001.json")) == support.request.lifecycle.sha256): return false
	return check("original frozen sources remain unchanged",support.reader.unchanged())

func _restore() -> Node:
	if not _profile_check(): return null
	var slot: Dictionary = Store.new(SLOT_ROOT).read_slot()
	if not check("actual closed gen1 Slot read exact raw and typed packet", slot.get("ok",false) and slot.revision == 1 and slot.file_sha256 == support.request.slot.sha256 and _exact(slot.document,admitted.packet),slot): return null
	if not _write_new_json(output.path_join("input_packet.json"),slot.document): return null
	if not _write_new_json(output.path_join("input_world.json"),slot.document.world): return null
	if not check("capture-only process owns no prior main scene",get_tree().current_scene == null): return null
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	owned_menu = menu
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	while Engine.is_in_physics_frame(): await get_tree().process_frame
	# Diagnostic Session restore, not a player Continue/Flow qualification.
	get_tree().paused = true
	restore_session = Session.new(trusted,runtime,SLOT_ROOT)
	var prepare_before: int = Time.get_ticks_msec()
	var prepared: Dictionary = restore_session.prepare_restore(menu)
	var prepare_after: int = Time.get_ticks_msec()
	if not check("actual Session prepare_restore succeeds",prepared.get("ok",false),prepared): return null
	if not check("old menu retained and complete Battle detached inert",get_tree().current_scene == menu and not prepared.battle.is_inside_tree() and prepared.battle.process_mode == Node.PROCESS_MODE_DISABLED): return null
	var mount_before: int = Time.get_ticks_msec()
	var staged: Dictionary = restore_session.stage_mount()
	var mount_after: int = Time.get_ticks_msec()
	if not check("actual Session paused stage_mount succeeds",staged.get("ok",false),staged): return null
	var mounted_input_stamps := {}
	for field: String in ["_last_group_time","_press_ms","_last_tap_ms"]: mounted_input_stamps[field] = staged.battle.get(field)
	var before_commit_physics: int = Engine.get_physics_frames()
	var installed: Dictionary = await restore_session.commit_restore_async(120)
	var after_commit_physics: int = Engine.get_physics_frames()
	if not check("actual Session commit_restore_async succeeds",installed.get("ok",false),installed): return null
	var restored: Node = installed.battle
	# Successful commit has already handed ownership to this caller.
	owned_installed_battle = restored
	owned_menu = null
	retained_identity = installed.identity
	var activation_physics: int = restored._run_clock._engine_anchor
	if not check("complete installed paused Battle and original local resume",get_tree().current_scene == restored and restored.get_parent() == get_tree().root and get_tree().paused and _healthy(restored) and not installed.steam_credit and installed.generation == slot.revision and installed.paused == slot.document.resume_paused and activation_physics >= before_commit_physics and activation_physics <= after_commit_physics): return null
	if not await _hold(restored,"restored complete world"): return null
	if not _verify_packet_install(restored,slot.document): return null
	var fresh_before: int = Time.get_ticks_msec()
	var fresh_process: int = Engine.get_process_frames()
	var fresh_stage_started: int = restored.mission._stage_started_ms
	var capture: Dictionary = capture_adapter.capture(restored,retained_identity)
	var fresh_after: int = Time.get_ticks_msec()
	if not check("fresh full Core capture at real restored HELD",capture.get("ok",false) and capture.get("identity") == retained_identity,capture): return null
	if not _write_new_json(output.path_join("restored_world.json"),capture.record): return null
	var times := {"prepare_before":prepare_before,"prepare_after":prepare_after,"mount_before":mount_before,"mount_after":mount_after,"mounted_input_stamps":mounted_input_stamps,"activation_physics":activation_physics,"held_physics":held_physics,"fresh_before":fresh_before,"fresh_after":fresh_after,"fresh_process":fresh_process,"fresh_stage_started":fresh_stage_started}
	if not _compare_complete_world(slot.document.world,capture.record,times): return null
	if not _audit_bindings(restored): return null
	observations.append({"restored":_retreat_state(restored),"clock_audit":times})
	return restored

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
	var local_script: Script = Lifecycle
	var expected_life: RefCounted = local_script.new(packet.binding.token, SLOT_ROOT, packet.context, trusted, campaign.cloud_owner)
	if not check("actual local receipt fixed script/token/slot scope", b._continue_receipt.get_script() == local_script and b._continue_receipt.token == packet.binding.token and b._continue_receipt.directory == expected_life.directory): return false
	if not check("installed campaign lifecycle complete context identity owner exact", b._continue_receipt.matches_scope(packet.context,trusted,campaign.cloud_owner)): return false
	var binding: Dictionary = b._continue_receipt.binding()
	if not check("actual durable local lifecycle binding exact", binding.ok and binding.binding == packet.binding): return false
	var steam: Node = get_node("/root/SteamService")
	if not check("Steam-disabled Session active lease/context installed", steam._active_run == 0 and steam._context == packet.context): return false
	var adapter: RefCounted = Core.new(trusted, runtime, {}, null, Profiles.DAMING_CONTEXT)
	var actual_root: Dictionary = adapter._visuals(b)._read_node(b)
	adapter.dispose()
	if not check("complete saved Visual root_node installed exactly at HELD", actual_root == root_node.value): return false
	return _write_new_json(output.path_join("session_packet_install_audit.json"), {"packet_generation": packet.generation, "options": actual_options, "session_settings": actual_settings, "profile_flags": actual_flags, "context": b._official_context, "resume_paused": b._save_barrier._was_paused, "binding": binding.binding, "steam_run_id": b._steam_run_id, "steam_active_run": steam._active_run, "steam_context": steam._context, "root_node": packet.root_node, "actual_root_node": Codec.new().encode(actual_root).value})

func _compare_complete_world(original: Dictionary, fresh: Dictionary, times: Dictionary) -> bool:
	var required: Array = ["schema", "profile", "content_version", "engine_sha256", "sections"]
	if not check("complete whole-world envelope and field set exact", original.size() == required.size() and original.has_all(required) and _same_keys(original, fresh)): return false
	var old_envelope: Dictionary = original.duplicate(true)
	var new_envelope: Dictionary = fresh.duplicate(true)
	old_envelope.erase("sections")
	new_envelope.erase("sections")
	if not check("whole-world schema/profile/context/content/engine envelope exact", _exact(old_envelope, new_envelope)): return false
	if not check("complete exact section keyset retained", _same_keys(original.sections, fresh.sections) and original.sections.size() == Core.CAMPAIGN_SECTIONS.size() and original.sections.has_all(Core.CAMPAIGN_SECTIONS)): return false
	for section: String in ["mission", "root"]:
		var old_wrapper: Dictionary = original.sections[section].duplicate(true)
		var new_wrapper: Dictionary = fresh.sections[section].duplicate(true)
		if not check("complete " + section + " wrapper field set exact", old_wrapper.has("payload") and new_wrapper.has("payload") and _same_keys(old_wrapper, new_wrapper)): return false
		old_wrapper.erase("payload")
		new_wrapper.erase("payload")
		if not check("every non-payload " + section + " wrapper field exact", _exact(old_wrapper, new_wrapper)): return false
	var old_mission_decode: Dictionary = Codec.new().decode(original.sections.mission.payload)
	var new_mission_decode: Dictionary = Codec.new().decode(fresh.sections.mission.payload)
	if not check("full Mission payload explicitly decoded", old_mission_decode.ok and new_mission_decode.ok): return false
	var old_mission: Dictionary = old_mission_decode.value
	var new_mission: Dictionary = new_mission_decode.value
	var saved_age: int = int(old_mission.values.stage_age_ms)
	var fresh_age: int = int(new_mission.values.stage_age_ms)
	var mission_clock_ok: bool = saved_age == int(admitted.mission.values.stage_age_ms) and times.fresh_stage_started >= times.prepare_before - saved_age and times.fresh_stage_started <= times.prepare_after - saved_age and fresh_age >= times.fresh_before - times.fresh_stage_started and fresh_age <= times.fresh_after - times.fresh_stage_started
	if not check("Mission complete wall age rebased within real prepare/capture intervals", mission_clock_ok): return false
	old_mission.values.erase("stage_age_ms")
	new_mission.values.erase("stage_age_ms")
	var differs: Array = []
	for section: String in original.sections:
		if section == "root": continue
		var equal: bool = _exact(old_mission, new_mission) if section == "mission" else _exact(original.sections[section], fresh.sections[section])
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
	if not check("all Root non-clock values/references/grids/economy exact", _exact(old_root, new_root)): return false
	return _write_new_json(output.path_join("full_world_comparison.json"), {"compared": original.sections.keys(), "differing": differs, "mission_clock_qualified": mission_clock_ok, "root_clock_qualified": clock_ok, "all_root_nonclock_exact": _exact(old_root, new_root), "timing": times})

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

