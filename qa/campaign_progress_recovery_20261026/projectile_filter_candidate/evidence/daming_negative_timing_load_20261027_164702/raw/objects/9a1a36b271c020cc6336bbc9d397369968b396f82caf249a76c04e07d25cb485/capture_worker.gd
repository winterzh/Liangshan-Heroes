extends "capture_base.gd"
## One of the original 24 live object capture negatives per fresh GL process/profile.
## New raw closed-A admission only; never CPU/DTO substitution for Core.capture.
const LIVE_CAST_FIELDS := ["_walk_casts", "_pending_casts", "_channels", "_pending_item_casts", "_walk_item_casts"]
const CAPTURE_CASES := {
	"safe_queue_nonempty": "LEVEL8_SAFE_RETREAT_QUEUE",
	"safe_stop__chase_intent": "LEVEL8_SAFE_RETREAT_STOP_ANCHOR",
	"safe_stop__group_cap": "LEVEL8_SAFE_RETREAT_STOP_ANCHOR",
	"safe_stop__has_home": "LEVEL8_SAFE_RETREAT_STOP_ANCHOR",
	"safe_stop__home": "LEVEL8_SAFE_RETREAT_STOP_ANCHOR",
	"safe_stop__hua_lock_shots": "LEVEL8_SAFE_RETREAT_STOP_ANCHOR",
	"other_hp_zero": "LEVEL8_LIFETIME", "other_dying_true": "LEVEL8_LIFETIME",
	"other_role_null": "LEVEL8_SAFE_REQUIRED_ACTOR_MISSING",
	"other_alive_missing_active": "LEVEL8_ACTIVE_MEMBERSHIP",
	"other_outcome_captured": "LEVEL8_UNSUPPORTED_STORY_OUTCOME",
	"root_safe_selection": "LEVEL8_SAFE_SELECTED_ROOT",
	"root_safe__ability_caster": "LEVEL8_SAFE_ARMED_CASTER",
	"root_safe__item_caster": "LEVEL8_SAFE_ARMED_CASTER",
	"safe_event_missing": "LEVEL8_SAFE_EVENT_OUTCOME_PAIR",
	"other_safe_event_without_retreat": "LEVEL8_SAFE_EVENT_OUTCOME_PAIR",
	"safe_actor_outcome_empty": "LEVEL8_SAFE_EVENT_OUTCOME_PAIR",
	"freed_event_missing": "LEVEL8_SAFE_RESCUE_EVENT_PAIR",
	"rescue_done_false": "LEVEL8_SAFE_RESCUE_EVENT_PAIR",
	"safe_caster__walk_casts": "LEVEL8_SAFE_CAST_INTENT",
	"safe_caster__pending_casts": "LEVEL8_SAFE_CAST_INTENT",
	"safe_caster__channels": "LEVEL8_SAFE_CAST_INTENT",
	"safe_caster__pending_item_casts": "LEVEL8_SAFE_CAST_INTENT",
	"safe_caster__walk_item_casts": "LEVEL8_SAFE_CAST_INTENT"
}
const IDENTITY_FIELDS := ["_entities", "_known_ids", "_object_ids", "_retired_ids", "_retired_sources", "_decoded_ids", "_decoded_sources", "_issued_id_tokens", "_issued_source_tokens", "_next_id_token", "_next_source_token", "_tombstones", "_expired", "_released"]
var capture_case := ""
var mutation: Dictionary = {}
var live_row: Dictionary = {}
var row_completed := false
var actual_negative_capture_called := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func run() -> void:
	support = Support.new()
	admitted = await support.begin(self,"capture")
	if admitted.is_empty(): finish(); return
	profile = OS.get_environment("DN_PROFILE").replace("\\","/").simplify_path().trim_suffix("/")
	output = OS.get_environment("DN_EVIDENCE").replace("\\","/").simplify_path().trim_suffix("/")
	nonce = OS.get_environment("DN_PROCESS_NONCE")
	capture_case = OS.get_environment("DN_CASE")
	first_role = admitted.first_role
	trusted = support.trusted
	runtime = support.runtime
	_load_fixed_scripts()
	if not check("one original capture case and actual GL display",CAPTURE_CASES.has(capture_case) and DisplayServer.get_name() != "headless"): finish(); return
	var catalog: Script = load(OS.get_environment("DN_WORKERS").path_join("case_catalog.gd"))
	if not check("all 24 original expected capture codes preserved",catalog != null and _exact(CAPTURE_CASES,catalog.CAPTURE_CASES)): finish(); return
	if not check("exclusive evidence directory supplied by validated support",output == OS.get_environment("DN_OUTPUT").replace("\\","/").simplify_path().trim_suffix("/").path_join("evidence") and DirAccess.dir_exists_absolute(output) and support.reader.scan(output).files.is_empty() and support.reader.scan(output).directories.is_empty()): finish(); return
	capture_packet = admitted.packet.duplicate(true)
	capture_adapter = Core.new(trusted,runtime,{},null,Profiles.DAMING_CONTEXT)
	if not check("actual installed safe-pair method exists",capture_adapter.has_method("_validate_daming_safe_pair")): finish(); return
	battle = await _restore()
	if not is_instance_valid(battle): finish(); return
	if not _exercise(): finish(); return
	if not _profile_check(): finish(); return
	row_completed = true
	finish()

func _node_ids(node: Node) -> Array:
	var result: Array = [str(node.get_instance_id())]
	for child: Node in node.get_children(true): result.append_array(_node_ids(child))
	return result

func _identity_snapshot() -> Dictionary:
	var result := {}
	for name: String in IDENTITY_FIELDS: result[name] = _clone(retained_identity.get(name))
	return result

func _live_cast_entry(safe: Node, field: String) -> Dictionary:
	# These are native Object references and native Vector2 values, never saved DTO tags.
	# No command, allocator, cooldown, Unit setter or gameplay consumer is called.
	var serial: int = safe._order_serial if field in ["_walk_casts", "_walk_item_casts"] else safe._cast_serial
	if field != "_channels" and not check("actual original cast/order serial acceptable", serial >= (-1 if field in ["_walk_casts", "_walk_item_casts"] else 0)): return {}
	var uid := 0
	if field in ["_pending_item_casts", "_walk_item_casts"]:
		# Battle's allocator issues monotonically from 1 and never reuses a UID.
		# Original ItemFlow explicitly accepts a consumed/transferred retired alias.
		# Use an already-issued alias below the actual unchanged counter, never allocate.
		if not check("actual issued item alias exists without changing allocator", typeof(battle.get("next_item_uid")) == TYPE_INT and battle.next_item_uid > 1 and battle.next_item_uid <= Core.ItemCasts.MAX_UID): return {}
		uid = battle.next_item_uid - 1
	match field:
		"_walk_casts": return {"c": safe, "slot": 0, "tgt": null, "point": safe.position, "serial": serial, "t": 0.4, "age": 0.0}
		"_pending_casts": return {"caster": safe, "slot": 0, "lp": safe.position, "tgt": null, "serial": serial}
		"_channels": return {"caster": safe, "center": safe.position, "eff": {"kind": "channel", "dur": 3.0, "tick": 0.5}, "sc": 1.0, "rank": 1, "r": 110.0, "tick": 0.5, "tick_t": 0.0, "ad": {}}
		"_pending_item_casts": return {"caster": safe, "slot": 0, "uid": uid, "point": safe.position, "target": null, "serial": serial}
		"_walk_item_casts": return {"c": safe, "uid": uid, "tgt": null, "point": safe.position, "serial": serial, "t": 0.4, "age": 0.0}
	return {}

func _capture_cast_component(field: String) -> Dictionary:
	var ids := {}
	for unit: Node in battle.units_root.get_children(true): ids[unit] = str(unit.entity_id)
	var module: RefCounted = Core.ItemCasts.new(Codec, B, Core.U) if field in ["_pending_item_casts", "_walk_item_casts"] else Core.Casts.new(Codec, B, Core.U)
	return module.capture(battle, trusted.content_version, ids)

func _capture_guard_layer(refusal: Dictionary) -> String:
	if refusal.get("code") == "LEVEL8_SAFE_CAST_INTENT": return "level8_safe_pair"
	if typeof(refusal.get("section")) == TYPE_STRING: return "Core.capture section " + refusal.section
	return "Core.capture earlier validator or unknown layer"

func _make_mutation() -> Dictionary:
	var safe: Node = battle.level.get(first_role)
	var other: Node = battle.level.get("shi" if first_role == "lu" else "lu")
	if not check("real single-safe actors and events before negative", is_instance_valid(safe) and is_instance_valid(other) and safe.get_script() == Core.U and other.get_script() == Core.U and safe != other and safe.story_outcome == "retreated" and other.story_outcome == "" and safe.hp > 0.0 and other.hp > 0.0 and not other._dying and battle.units.has(safe) and battle.units.has(other) and safe.get_parent() == battle.units_root and other.get_parent() == battle.units_root and battle.mission.has_event("daming_" + first_role + "_safe") and not battle.mission.has_event("daming_" + ("shi" if first_role == "lu" else "lu") + "_safe")): return {}
	var target: Object = safe
	var field := ""
	var temporary: Variant = null
	if capture_case.begins_with("safe_caster_"):
		target = battle; field = capture_case.trim_prefix("safe_caster_")
		if not check("one actual existing cast array", field in LIVE_CAST_FIELDS and typeof(battle.get(field)) == TYPE_ARRAY): return {}
		var entry: Dictionary = _live_cast_entry(safe, field)
		if entry.is_empty(): return {}
		temporary = _clone(battle.get(field)); temporary.append(entry)
	elif capture_case == "safe_queue_nonempty": field = "_queue"; temporary = [{"kind": "move", "pos": safe.position, "group_cap": 0.0}]
	elif capture_case.begins_with("safe_stop_"):
		field = capture_case.trim_prefix("safe_stop_")
		match field:
			"_chase_intent", "_hua_lock_shots": temporary = 1
			"_group_cap": temporary = 1.0
			"_has_home": temporary = false
			"_home": temporary = safe.position + Vector2(1.0, 0.0)
	elif capture_case == "other_hp_zero": target = other; field = "hp"; temporary = 0.0
	elif capture_case == "other_dying_true": target = other; field = "_dying"; temporary = true
	elif capture_case == "other_role_null": target = battle.level; field = "shi" if first_role == "lu" else "lu"
	elif capture_case == "other_alive_missing_active": target = battle; field = "units"; temporary = battle.units.duplicate(); temporary.erase(other)
	elif capture_case == "other_outcome_captured": target = other; field = "story_outcome"; temporary = "captured"
	elif capture_case == "root_safe_selection": target = battle; field = "selection"; temporary = battle.selection.duplicate(); temporary.append(safe)
	elif capture_case.begins_with("root_safe_"): target = battle; field = capture_case.trim_prefix("root_safe_"); temporary = safe
	elif capture_case == "safe_actor_outcome_empty": field = "story_outcome"; temporary = ""
	elif capture_case in ["safe_event_missing", "other_safe_event_without_retreat", "freed_event_missing"]:
		target = battle.mission; field = "events"; temporary = battle.mission.events.duplicate(true)
		if capture_case == "safe_event_missing": temporary.erase("daming_" + first_role + "_safe")
		elif capture_case == "freed_event_missing": temporary.erase("daming_prisoners_freed")
		else: temporary["daming_" + ("shi" if first_role == "lu" else "lu") + "_safe"] = true
	elif capture_case == "rescue_done_false":
		target = battle.mission; field = "actions"; temporary = battle.mission.actions.duplicate(true)
		if not check("actual rescue action exists and completed", temporary.has("daming_rescue") and temporary.daming_rescue.done): return {}
		temporary.daming_rescue.done = false
	if not check("one exact actual object property selected", not field.is_empty() and is_instance_valid(target) and not _exact(target.get(field), temporary)): return {}
	return {"target": target, "field": field, "original": target.get(field), "original_snapshot": _clone(target.get(field)), "temporary": temporary, "object_id": str(target.get_instance_id())}

func _compare_held(before: Dictionary, after: Dictionary, bounds: Dictionary) -> bool:
	var left: Dictionary = before.duplicate(true)
	var right: Dictionary = after.duplicate(true)
	if not check("post-restore complete envelope and section keysets exact", _same_keys(left, right) and _exact(left.profile, right.profile) and _same_keys(left.sections, right.sections) and left.sections.size() == Core.CAMPAIGN_SECTIONS.size() and left.sections.has_all(Core.CAMPAIGN_SECTIONS)): return false
	for name: String in ["root", "mission"]:
		var opened_before: Dictionary = Codec.new().decode(left.sections[name].payload)
		var opened_after: Dictionary = Codec.new().decode(right.sections[name].payload)
		if not check("complete comparison payload decode " + name, opened_before.get("ok", false) and opened_after.get("ok", false)): return false
		var a: Dictionary = opened_before.value
		var b: Dictionary = opened_after.value
		if name == "mission":
			if not check("only actual wall age advance inside real capture bounds", battle.mission._stage_started_ms == bounds.stage_started and a.values.stage_age_ms >= bounds.before_min - bounds.stage_started and a.values.stage_age_ms <= bounds.before_max - bounds.stage_started and b.values.stage_age_ms >= bounds.after_min - bounds.stage_started and b.values.stage_age_ms <= bounds.after_max - bounds.stage_started): return false
			b.values.stage_age_ms = a.values.stage_age_ms
		else:
			if not check("HELD root physics/process/logical/cache clocks exact", _exact(a.simulation, b.simulation) and _exact(a.clock_values, b.clock_values) and a.clocks.physics == b.clocks.physics and a.clocks.process == b.clocks.process and a.clocks.process == bounds.process and a.clocks.msec >= bounds.before_min and a.clocks.msec <= bounds.before_max and b.clocks.msec >= bounds.after_min and b.clocks.msec <= bounds.after_max): return false
			b.clocks.msec = a.clocks.msec
		if not check("all decoded fields exact after only audited wall time leaf " + name, _exact(a, b)): return false
		# Retain entire wrappers. Only payload values whose one wall leaf was
		# independently bounded above can now compare using the original codec.
		right.sections[name].payload = left.sections[name].payload.duplicate(true)
	return check("every full world field/type/IEEE restored exactly", _exact(left, right))

func _exercise() -> bool:
	var before_min := Time.get_ticks_msec()
	var baseline: Dictionary = capture_adapter.capture(battle, retained_identity)
	var before_max := Time.get_ticks_msec()
	if not check("before-mutation actual whole source capture", baseline.get("ok", false) and baseline.get("identity") == retained_identity, baseline): return false
	if not _write_new_json(output.path_join("before_world.json"), baseline.record): return false
	var nodes_before := _node_ids(battle)
	var identity_before := _identity_snapshot()
	var canvas_before := get_tree().root.canvas_transform
	var physics_before := Engine.get_physics_frames()
	var process_before := Engine.get_process_frames()
	var next_tick: int = battle._run_clock._next_tick
	var stage_started: int = battle.mission._stage_started_ms
	mutation = _make_mutation()
	if mutation.is_empty(): return false
	var target: Object = mutation.target
	target.set(mutation.field, mutation.temporary)
	var applied := _exact(target.get(mutation.field), mutation.temporary)
	var cast_case: bool = capture_case.begins_with("safe_caster_")
	var cast_component: Dictionary = _capture_cast_component(mutation.field) if cast_case else {}
	actual_negative_capture_called = true
	var refusal: Dictionary = capture_adapter.capture(battle, retained_identity)
	var temporary_unchanged := _exact(target.get(mutation.field), mutation.temporary)
	# Synchronous single-field undo: no await, signal, tick, protection or broad reset.
	target.set(mutation.field, mutation.original)
	var restored_typed := _exact(target.get(mutation.field), mutation.original_snapshot) and _exact(mutation.original, mutation.original_snapshot)
	var after_min := Time.get_ticks_msec()
	var restored: Dictionary = capture_adapter.capture(battle, retained_identity)
	var after_max := Time.get_ticks_msec()
	var exact_code: bool = refusal.get("ok") == false and refusal.get("code") == CAPTURE_CASES[capture_case]
	if cast_case: exact_code = exact_code and cast_component.get("ok", false) and refusal.get("section") == mutation.field
	var identity_ok: bool = is_instance_valid(retained_identity) and _exact(identity_before, _identity_snapshot()) and restored.get("identity") == retained_identity
	var held_ok: bool = get_tree().paused and battle._save_barrier.state == battle._save_barrier.State.HELD and battle._save_barrier.health().ok and battle._run_clock._next_tick == next_tick and Engine.get_physics_frames() == physics_before and Engine.get_process_frames() == process_before and get_tree().current_scene == battle and _exact(canvas_before, get_tree().root.canvas_transform) and _exact(nodes_before, _node_ids(battle))
	live_row = {"case": capture_case, "first_role": first_role, "expected_code": CAPTURE_CASES[capture_case], "actual_code": refusal.get("code", ""), "actual_Core_capture_called": actual_negative_capture_called, "DTO_substitution": false, "single_live_field_applied": applied, "temporary_field_unchanged_by_capture": temporary_unchanged, "original_field_type_ieee_restored": restored_typed, "retained_identity_same_live_unchanged": identity_ok, "source_held_no_ticks_no_nodes_added": held_ok, "original_target_object_id": mutation.object_id, "field": mutation.field, "original_typed_view": _live_view(mutation.original_snapshot), "temporary_typed_view": _live_view(mutation.temporary), "refusal_summary": _brief(refusal), "passed": false}
	live_row["cast_component_capture_called"] = cast_case
	live_row["cast_component_capture_accepted"] = cast_component.get("ok", false) if cast_case else false
	live_row["cast_component_actual_code"] = cast_component.get("code", "") if cast_case else "not_run_original_19_case"
	live_row["expected_guard_layer"] = "level8_safe_pair" if cast_case else "original_fixed_capture_guard"
	live_row["actual_guard_layer"] = _capture_guard_layer(refusal)
	live_row["actual_section"] = refusal.get("section", "")
	live_row["actual_field"] = refusal.get("field", "")
	live_row["expected_pair_array"] = mutation.field if cast_case else ""
	live_row["actual_pair_array"] = refusal.get("section", "") if refusal.get("code") == "LEVEL8_SAFE_CAST_INTENT" else ""
	live_row["direct_safe_cast_pair_coverage"] = cast_case and exact_code
	if cast_case:
		live_row["actual_caster_object_id"] = str(battle.level.get(first_role).get_instance_id())
		live_row["actual_item_counter_unchanged"] = battle.next_item_uid
		if not _write_new_json(output.path_join("cast_component_capture.json"), cast_component): return false
	if not check("actual live capture exact controlled refusal", applied and temporary_unchanged and exact_code, refusal): return false
	if not check("original typed property and caller-owned identity restored", restored_typed and identity_ok): return false
	if not check("source remains exact HELD with no ticks/nodes/scene change", held_ok): return false
	if not check("after-undo complete actual capture succeeds", restored.get("ok", false), restored): return false
	if not _write_new_json(output.path_join("after_world.json"), restored.record): return false
	if not _compare_held(baseline.record, restored.record, {"before_min": before_min, "before_max": before_max, "after_min": after_min, "after_max": after_max, "stage_started": stage_started, "process": process_before}): return false
	if not _verify_packet_install(battle, capture_packet) or not _audit_bindings(battle): return false
	live_row.passed = true
	return _write_new_json(output.path_join("live_mutation_audit.json"), live_row)

func finish() -> void:
	if finished: return
	finished = true
	if not mutation.is_empty() and is_instance_valid(mutation.get("target")):
		mutation.target.set(mutation.field,mutation.original)
	var owned: bool = is_instance_valid(owned_installed_battle)
	# Evidence is complete before cleanup. No extra capture or gameplay tick is
	# introduced between applying the live field and synchronous exact undo.
	if owned:
		var world_ref: WeakRef = weakref(owned_installed_battle)
		owned_installed_battle.queue_free()
		await get_tree().process_frame
		check("owned installed Battle freed exactly once",world_ref.get_ref() == null)
	owned_installed_battle = null
	battle = null
	if retained_identity != null: retained_identity.dispose(); retained_identity = null
	if capture_adapter != null: capture_adapter.dispose(); capture_adapter = null
	if restore_session != null:
		var disposed: Dictionary = restore_session.dispose()
		check("restore Session has no pending write on cleanup",disposed.get("ok",false),disposed)
		restore_session = null
	if is_instance_valid(owned_menu):
		owned_menu.queue_free()
		await get_tree().process_frame
	owned_menu = null
	if not admitted.is_empty(): _profile_check()
	var passed: bool = row_completed and live_row.get("passed",false) and not checks.is_empty() and checks.all(func(row): return row.passed)
	var payload := {"family":"capture","case":capture_case,"row_completed":row_completed,
		"checks":checks,"observations":observations,"evidence":evidence,
		"executed_live_row":live_row,"actual_Core_capture_called":actual_negative_capture_called,
		"actual_live_object_capture":actual_negative_capture_called,"actual_session_install":owned,
		"implemented_cases":CAPTURE_CASES.keys(),"planned_cases":24,"planned_roles":["lu","shi"],
		"live_cast_cases_implemented":5,"source_row_isolation":"one case per fresh independent GL process/profile; original raw A installed by Session",
		"base_harness_sha256":FileAccess.get_sha256(OS.get_environment("DN_WORKERS").path_join("capture_base.gd")),
		"harness_sha256":FileAccess.get_sha256(get_script().resource_path),
		"disk_slot_writes":0,"gameplay_ticks_injected":0,"grid_clears":0,"runtime_patches":0,
		"whole_live_capture_matrix_qualified":false,"native_log_zero_ERROR_verified":false,
		"source_flow_chain_passed":false,"full_61_qualified":false,"original_19_faults_qualified":false,
		"native_sdk_qualified":false,"native_release_tested":false,"public_continue_qualified":false,
		"human_acceptance":false,"published":false}
	if support == null: get_tree().quit(2); return
	support.finish(payload,passed)
