extends SceneTree
## Narrow HUD adapter regression: real Battle/HUD/hero death and real UI gating.
## Only the HELD capture boundary is supplied; no full save/continue claim.
var checks: Array = []
var failures: Array = []
var samples: Array = []
var completed := false

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"label": label, "passed": ok})
	print("[hud-snapshot] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func _private_ok() -> bool:
	var expected := OS.get_environment("LSH_RTS_QA_PROJECT").simplify_path().trim_suffix("/")
	var profile := OS.get_environment("LSH_RTS_QA_PROFILE").simplify_path().trim_suffix("/")
	return not expected.is_empty() and not profile.is_empty() \
		and ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/") == expected \
		and OS.get_user_data_dir().simplify_path().trim_suffix("/") == profile \
		and bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)) \
		and String(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("LSH-") \
		and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA") == "1"

func _make_battle():
	var campaign = root.get_node("Campaign")
	for key in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "ai_friendly", "scale_on"]:
		campaign.set(key, false)
	campaign.skirmish_ai = true
	campaign.ai_difficulty = "normal"
	campaign.victory_mode = "conquest"
	root.get_node("Settings").auto_micro_level = 0
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	if not b.has_method("gameplay_rng_fault"):
		check(false, "real Battle script attaches")
		return null
	b.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	b.phase = b.Phase.FIGHT
	b.hud._intro_root.hide()
	b.hud.hide_deploy()
	b.level.on_start(b)
	check(b.units.size() > 10 and b.gameplay_rng_fault().is_empty(), "nonempty real battle and HUD start without RNG fault")
	return b

func _validation_cases(adapter, raw: Dictionary, known: Dictionary, definitions: Dictionary) -> void:
	check(adapter.validate(raw, known).ok, "captured fight_hud_v2 passes production validation")
	var legacy := raw.duplicate(true)
	legacy.schema = "fight_hud_v1"
	legacy.erase("hero_roster")
	legacy.erase("compact_stats")
	check(adapter.validate(legacy, known).ok, "legacy fight_hud_v1 remains accepted without new fields")
	var bad := raw.duplicate(true)
	bad.hero_roster.append(raw.hero_roster[0])
	check(not adapter.validate(bad, known).ok, "duplicate roster key is rejected")
	for illegal in ["", 7, null, "x".repeat(129), "../bad", "bad key", "bad\nkey"]:
		bad = raw.duplicate(true)
		bad.hero_roster = [illegal]
		check(not adapter.validate(bad, known).ok, "illegal roster key rejected: " + str(illegal).replace("\n", "\\n"))
	bad = raw.duplicate(true)
	bad.compact_stats = 1
	check(not adapter.validate(bad, known).ok, "compact_stats requires a boolean")
	bad = raw.duplicate(true)
	bad.hero_roster = "lin_chong"
	check(not adapter.validate(bad, known).ok, "hero_roster requires an array")
	bad = raw.duplicate(true)
	bad.unexpected = true
	check(not adapter.validate(bad, known).ok, "unknown record field is rejected")
	bad = raw.duplicate(true)
	bad.schema = "fight_hud_v999"
	check(not adapter.validate(bad, known).ok, "unknown schema version is rejected")
	bad = raw.duplicate(true)
	bad.erase("compact_stats")
	check(not adapter.validate(bad, known).ok, "v2 cannot silently omit compact_stats")
	bad = raw.duplicate(true)
	bad.schema = "fight_hud_v1"
	check(not adapter.validate(bad, known).ok, "v1 with unversioned v2 fields is rejected")
	bad = raw.duplicate(true)
	bad.hero_clocks.append({"id": "missing-live-id", "clock": 0.0})
	check(not adapter.validate(bad, known).ok, "unknown living hero clock reference is rejected")
	bad = raw.duplicate(true)
	bad.hero_clocks.append(bad.hero_clocks[0].duplicate(true))
	check(not adapter.validate(bad, known).ok, "duplicate living hero clock reference is rejected")
	bad = raw.duplicate(true)
	bad.selected.append({"kind": "unit", "id": "missing-selected-id"})
	check(not adapter.validate(bad, known).ok, "unknown selection reference is rejected")
	bad = raw.duplicate(true)
	bad.hero_roster.resize(4097)
	check(not adapter.validate(bad, known).ok, "oversized roster is rejected")
	for unknown in ["qa_unknown_hero", "liang_dao"]:
		bad = raw.duplicate(true)
		bad.hero_roster.append(unknown)
		check(not adapter.validate(bad, known, definitions).ok, "definition-aware validation rejects missing/nonhero key: " + unknown)
	var extended := definitions.duplicate(true)
	extended["qa-content-hero"] = {"hero": true}
	bad = raw.duplicate(true)
	bad.hero_roster.append("qa-content-hero")
	check(adapter.validate(bad, known, extended).ok, "valid dynamic content-pack hero key remains supported")
	completed = true

func _capture_cases(b) -> void:
	var adapter = load("res://scripts/run_hud_state.gd").new()
	var codec = load("res://scripts/run_state_value_codec.gd").new()
	var cell = b.map.nearest_open(b.level.HALL + Vector2i(8, 8))
	var dead = b.spawn_at("hua_rong", 0, cell)
	var alive = b.spawn_at("lin_chong", 0, cell + Vector2i(2, 0))
	var order: Array = b._hero_roster_keys.duplicate()
	dead.take_damage(dead.max_hp * 100.0, null, false, true)
	b._set_selection([alive])
	b.hud._combat_stats_toggle.button_pressed = true
	b.hud._refresh_hero_bar()
	await process_frame # Flush replaced chips, while the combat world stays disabled.
	var dead_chips := 0
	var live_chips := 0
	for chip in b.hud._hero_bar.get_children():
		if is_instance_valid(chip.hero): live_chips += 1
		elif chip.roster_key == dead.key: dead_chips += 1
	check(dead_chips == 1 and live_chips > 0 and Array(b._hero_roster_keys) == order,
		"real lethal damage leaves one dead chip and stable living/dead roster order")
	var objects := {}
	var known := {}
	for u in b.units:
		var id := "unit-%d" % u.entity_id
		objects[u] = id
		known[id] = true
	check(not adapter.capture(b, objects).ok, "HUD adapter rejects capture outside a HELD boundary")
	# Bounded fixture: reuse the real barrier's pointer cleanup and recursive UI
	# gating, but supply HELD directly. No clock/whole-world save is certified.
	var gate = b._save_barrier
	gate._close_input()
	gate.state = gate.State.HELD
	var captured: Dictionary = adapter.capture(b, objects)
	check(captured.ok, "real live/dead HUD captures successfully behind the UI gate")
	if not captured.ok:
		samples.append({"capture_error": captured, "scope": "adapter boundary only"})
		gate._restore_input()
		gate.state = gate.State.IDLE
		return
	var decoded: Dictionary = codec.decode(captured.value)
	check(decoded.ok, "production value codec decodes the captured HUD")
	var raw: Dictionary = decoded.value
	check(raw.schema == "fight_hud_v2" and raw.hero_roster == order and raw.compact_stats,
		"v2 capture preserves exact roster order and enabled compact statistics")
	check(raw.hero_clocks.size() == live_chips and raw.hero_clocks.size() < b.hud._hero_bar.get_child_count(),
		"dead HeroChip contributes no living entity clock reference")
	check(raw.hero_clocks.any(func(row): return row.id == objects[alive]), "living hero still retains a captured clock")
	_validation_cases(adapter, raw, known, b._defs)
	var missing_live := objects.duplicate()
	missing_live.erase(alive)
	check(not adapter.capture(b, missing_live).ok, "living chip still requires a registered live entity")
	for chip in b.hud._hero_bar.get_children():
		if chip.roster_key != dead.key: continue
		chip.roster_key = "qa_unknown_dead_chip"
		check(not adapter.capture(b, objects).ok, "unregistered dead chip cannot bypass the capture registry")
		chip.roster_key = dead.key
	for invalid_key in ["qa_unknown_hero", "liang_dao", "../bad"]:
		b._hero_roster_keys.append(invalid_key)
		check(not adapter.capture(b, objects).ok, "capture rejects unknown/nonhero/illegal roster key: " + invalid_key)
		b._hero_roster_keys.assign(order)
	b.hud._compact_combat_stats = false
	var disabled: Dictionary = adapter.capture(b, objects)
	check(disabled.ok and not codec.decode(disabled.value).value.compact_stats, "disabled compact statistics are captured too")
	samples.append({"schema": raw.schema, "hero_roster": raw.hero_roster, "live_clocks": raw.hero_clocks.size(),
		"dead_chips": dead_chips, "compact_stats": raw.compact_stats})
	gate._restore_input()
	gate.state = gate.State.IDLE

func _run() -> void:
	if not _private_ok():
		push_error("PRIVATE_RTS_HUD_SNAPSHOT_QA_REQUIRED")
		quit(2)
		return
	AudioServer.set_bus_mute(0, true)
	var b = await _make_battle()
	if b == null: quit(3); return
	await _capture_cases(b)
	check(completed and checks.size() >= 25 and samples.size() == 1, "capture and mutation suites completed with nonempty evidence")
	current_scene = null
	b.queue_free()
	await process_frame
	await process_frame
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "samples": samples,
		"profile": OS.get_user_data_dir(), "full_save_continue": false,
		"scope": "Real Battle/HUD death and capture, production validation/codec; HELD boundary supplied without whole-world save or restore"}
	var out := OS.get_environment("LSH_RTS_QA_OUT")
	if not out.is_empty():
		var file := FileAccess.open(out.path_join("hud-snapshot-result.json"), FileAccess.WRITE)
		if file == null: check(false, "write HUD snapshot report")
		else: file.store_string(JSON.stringify(report, "\t"))
	print("[hud-snapshot-result] " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
