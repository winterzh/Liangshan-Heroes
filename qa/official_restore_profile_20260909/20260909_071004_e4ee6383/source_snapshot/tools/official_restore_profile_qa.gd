extends Node
## Isolated selector/runtime/Level components. No full world, gameplay or Steam claim.
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Factory := preload("res://scripts/run_level3_world_factory.gd")
const LevelState := preload("res://scripts/run_campaign_level_state.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const CampaignSource := preload("res://scripts/campaign.gd")
const Classic := preload("res://scripts/levels/skirmish.gd")
const Zhu := preload("res://scripts/levels/level3_zhujiazhuang_rts.gd")
const U := preload("res://scripts/unit.gd")
const DefinitionSource := preload("res://scripts/defs.gd")
const TOKEN := "official-profile-fixture:mission:1"
const UNIT_KEYS := ["hall", "song_jiang", "zhu_gate", "zhu_gate", "hall", "barracks", "hu_sanniang", "sun_li",
	"shi_qian", "shi_xiu", "qin_ming", "yang_lin", "huang_xin", "wang_ying", "deng_fei",
	"lou_luo", "lou_luo", "lou_luo", "gold_mine", "tree", "zhu_keke"]
const BOOL_FIELDS := ["expansion_secured", "supply_cut", "inside_open", "prisoners_freed", "manor_fallen", "sent_sun", "main_breached"]
const UNIT_FIELDS := ["hall", "song", "gate", "side_gate", "enemy_base", "outpost", "hu", "sun"]
var checks: Array = []
var owned: Array[Node] = []
var identity: Dictionary
var phase: String
var fixture_info: Dictionary = {}

func _ready() -> void:
	var profile := OS.get_environment("LSH_OFFICIAL_PROFILE_ROOT").replace("\\", "/").simplify_path()
	var safe := profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		var actual := OS.get_environment(key).replace("\\", "/").simplify_path()
		safe = safe and actual.to_lower() == (profile + "/" + key.to_lower()).to_lower()
	var user_path := OS.get_user_data_dir().replace("\\", "/").simplify_path()
	safe = safe and user_path.to_lower().begins_with((profile + "/appdata/").to_lower())
	if not safe or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("CAMPAIGN_QA") != "1":
		print("OFFICIAL_RESTORE_PROFILE_QA PRIVATE_PROFILE_REQUIRED")
		get_tree().quit(2)
		return
	phase = OS.get_environment("LSH_OFFICIAL_PROFILE_PHASE")
	identity = {"ok": true, "save_eligible": true, "content_version": "official_profile_component_fixture:v1",
		"engine_binary_sha256": OS.get_environment("LSH_OFFICIAL_ENGINE_SHA256")}
	call_deferred("run")

func check(label: String, passed: bool) -> void:
	checks.append({"label": label, "passed": passed})
	if not passed: print("QA_FAIL ", label)

func reject(label: String, result: Dictionary) -> void:
	check(label, result.get("ok") == false and not result.get("code", "").is_empty())

func _global_state() -> Dictionary:
	var flags: Dictionary = {}
	for key: String in ["current", "skirmish", "skirmish_ai", "arena", "custom_defense", "scenario", "defense_waves", "defense_random"]:
		flags[key] = Campaign.get(key)
	return {"defs": DefinitionSource.UNITS.duplicate(true), "abilities": DefinitionSource.ABILITIES.duplicate(true),
		"items": DefinitionSource.ITEMS.duplicate(true), "art_buildings": Art.environment_buildings.duplicate(true),
		"art_aliases": Art._runtime_alias.duplicate(true), "campaign": flags}

func run() -> void:
	var before := _global_state()
	check("private profile validated before fixture allocation", owned.is_empty())
	check("runner engine identity supplied", Profiles.trusted_identity(identity))
	if phase == "profile_runtime":
		_test_profiles()
		_test_runtime()
		_write_fixtures()
	elif phase == "level_restore":
		_test_restore()
	else:
		check("known QA phase", false)
	check("Defs Art Campaign globals unchanged", before == _global_state())
	for node: Node in owned:
		if is_instance_valid(node): node.free()
	owned.clear()
	var passed := not checks.is_empty()
	for row: Dictionary in checks: passed = passed and row.passed
	var report := {"schema": "official_restore_profile_qa_v1", "phase": phase, "passed": passed,
		"component_only": true, "full_world": false, "normal_gameplay": false, "real_steam": false,
		"fixture": fixture_info, "checks": checks, "pid": OS.get_process_id()}
	var file := FileAccess.open(OS.get_environment("LSH_OFFICIAL_PROFILE_REPORT"), FileAccess.WRITE)
	if file == null:
		print("OFFICIAL_RESTORE_PROFILE_QA REPORT_WRITE_FAILED")
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(report, "  ")); file.close()
	print("OFFICIAL_RESTORE_PROFILE_QA phase=", phase, " checks=", checks.size(), " passed=", passed)
	get_tree().quit(0 if passed else 1)

func _test_profiles() -> void:
	var context_index := 0
	for context: Dictionary in [{"mode": "defense", "level_id": "", "waves": 30}, {"mode": "defense", "level_id": "", "waves": 30.0},
		{"mode": "campaign", "level_id": "level3", "waves": 0}, {"mode": "campaign", "level_id": "level3", "waves": 0.0}]:
		var selected := Profiles.select_context(context, identity)
		var label := str(context_index) + " " + str(context)
		context_index += 1
		check("accepted official context " + label, selected.ok)
		if selected.ok:
			check("selection remains component only " + label, selected.complete_world == false and selected.player_entry_enabled == false)
			check("normalized waves integer " + label, typeof(selected.context.waves) == TYPE_INT)
			check("saved installed identity accepted " + label, Profiles.select_saved(context, identity.content_version, identity.engine_binary_sha256, identity).ok)
			selected.context.mode = "mutated"
			check("returned context isolated " + label, Profiles.select_context(context, identity).context.mode == context.mode)
	var invalid: Array = [null, [], "level3", {}, {"mode": "campaign", "level_id": "level3"},
		{"mode": "campaign", "level_id": "level3", "waves": 0, "extra": true},
		{"mode": 2, "level_id": "level3", "waves": 0}, {"mode": "campaign", "level_id": 3, "waves": 0}]
	for waves: Variant in [true, "0", null, 0.5, -1, 1, NAN, INF, -INF]:
		invalid.append({"mode": "campaign", "level_id": "level3", "waves": waves})
	for context: Dictionary in [{"mode": "campaign", "level_id": "level1", "waves": 0}, {"mode": "campaign", "level_id": "level3", "waves": 30},
		{"mode": "defense", "level_id": "level3", "waves": 30}, {"mode": "defense", "level_id": "", "waves": 20},
		{"mode": "defense", "level_id": "", "waves": 60}, {"mode": "custom", "level_id": "level3", "waves": 0}]: invalid.append(context)
	for i in range(invalid.size()): reject("unknown context rejected " + str(i), Profiles.select_context(invalid[i], identity))
	for pair: Array in [["ok", false], ["ok", 1], ["ok", "true"], ["save_eligible", false], ["save_eligible", 1], ["save_eligible", "true"], ["content_version", ""], ["content_version", 7],
		["content_version", "x".repeat(257)], ["engine_binary_sha256", "f".repeat(63)], ["engine_binary_sha256", "G".repeat(64)], ["engine_binary_sha256", 7]]:
		var bad := identity.duplicate(); bad[pair[0]] = pair[1]
		reject("untrusted identity " + str(pair), Profiles.select_context({"mode": "campaign", "level_id": "level3", "waves": 0}, bad))
		reject("runtime rejects identity " + str(pair), Factory.prepare_runtime(bad))
	for pair: Array in [["different", identity.engine_binary_sha256], [identity.content_version, "0".repeat(64)], [4, identity.engine_binary_sha256], [identity.content_version, 4]]:
		reject("saved identity mismatch " + str(pair), Profiles.select_saved(Profiles.ZHU_CONTEXT, pair[0], pair[1], identity))
	check("installed catalog classic script", Profiles.level_script("classic_30_v1") == Classic and CampaignSource.SKIRMISH_SCRIPT == Classic.resource_path)
	check("installed catalog Level3 script", Profiles.level_script("campaign_level3_v1") == Zhu and CampaignSource.LEVELS[2].script == Zhu.resource_path)
	check("unknown profile no script", Profiles.level_script("other") == null)
	reject("unknown profile no flags", Profiles.install_flags("other"))
	var zflags := Profiles.install_flags("campaign_level3_v1")
	check("Level3 exact install flags", zflags.ok and zflags.flags == {"current": 2, "skirmish": false, "skirmish_ai": false, "arena": false, "custom_defense": false, "scenario": false})
	var cflags := Profiles.install_flags("classic_30_v1")
	check("classic exact install flags", cflags.ok and cflags.flags == {"skirmish": true, "skirmish_ai": false, "arena": false, "custom_defense": false, "scenario": false, "defense_waves": 30, "defense_random": false})
	zflags.flags.current = 7; cflags.flags.defense_waves = 60
	check("flags returned without shared aliases", Profiles.install_flags("campaign_level3_v1").flags.current == 2 and Profiles.install_flags("classic_30_v1").flags.defense_waves == 30)
	var campaign := CampaignSource.new(); owned.append(campaign)
	var zhu := Zhu.new(); var classic := Classic.new()
	for key: String in Profiles.install_flags("campaign_level3_v1").flags: campaign.set(key, Profiles.install_flags("campaign_level3_v1").flags[key])
	check("actual Campaign and Level3 capture", Profiles.capture_selection(campaign, zhu, identity).ok)
	reject("actual Campaign wrong classic script", Profiles.capture_selection(campaign, classic, identity))
	campaign.current = 0
	reject("actual Campaign wrong chapter index", Profiles.capture_selection(campaign, zhu, identity))
	campaign.current = 2
	for key: String in ["scenario", "arena", "custom_defense", "skirmish_ai", "skirmish"]:
		campaign.set(key, true); reject("actual Campaign disallowed flag " + key, Profiles.capture_selection(campaign, zhu, identity)); campaign.set(key, false)
	for key: String in Profiles.install_flags("classic_30_v1").flags: campaign.set(key, Profiles.install_flags("classic_30_v1").flags[key])
	check("actual Campaign and classic capture", Profiles.capture_selection(campaign, classic, identity).ok)
	campaign.defense_random = true
	reject("random defense capture rejected", Profiles.capture_selection(campaign, classic, identity))
	var plain := Node.new(); owned.append(plain)
	reject("unscripted Campaign rejected", Profiles.capture_selection(plain, zhu, identity))
	reject("unscripted Level rejected before Policy", Profiles.capture_selection(campaign, RefCounted.new(), identity))

func _test_runtime() -> void:
	var a := Factory.prepare_runtime(identity)
	var b := Factory.prepare_runtime(identity)
	check("runtime factory succeeds twice", a.ok and b.ok)
	if not a.ok or not b.ok: return
	check("runtime explicitly not world or deployment", a.complete_world == false and a.deploy_or_start_called == false and a.global_art_changed == false)
	check("hall production chapter restriction", a.runtime.defs.hall.produces == ["lou_luo", "song_jiang", "lin_chong", "hua_rong"])
	for key: String in ["shi_qian", "shi_xiu", "qin_ming", "yang_lin", "huang_xin", "wang_ying", "deng_fei"]:
		check("captive unavailable for training " + key, a.runtime.defs[key].hero_trainable == false and a.runtime.defs[key].pop == 0)
	for pair: Array in [["zhu_keke", "liang_dao"], ["zhu_gong", "liang_gong"], ["zhu_qi", "liang_ma"]]:
		for field: String in ["cost_gold", "cost_wood", "pop"]: check("chapter troop cost " + pair[0] + " " + field, a.runtime.defs[pair[0]][field] == a.runtime.defs[pair[1]][field])
	check("environment gate mapping", a.environment_buildings == {"zhu_gate": "zhu_gate"})
	check("runtime contains installed ability visuals and item catalog", a.runtime.abilities.has("song_rally") and a.runtime.items == DefinitionSource.ITEMS)
	a.runtime.defs.hall.produces.append("pollution")
	a.runtime.abilities.song_rally["qa_pollution"] = true
	a.runtime.items["qa_pollution"] = {"nested": true}
	a.environment_buildings.zhu_gate = "pollution"
	check("runtime nested dictionaries independent", not b.runtime.defs.hall.produces.has("pollution") and not b.runtime.abilities.song_rally.has("qa_pollution") and not b.runtime.items.has("qa_pollution") and b.environment_buildings.zhu_gate == "zhu_gate")
	var c := Factory.prepare_runtime(identity)
	check("subsequent runtime uncontaminated", c.ok and c.runtime == b.runtime and c.environment_buildings == b.environment_buildings)

func _registry() -> Dictionary:
	var ids: Dictionary = {}
	for index in range(UNIT_KEYS.size()):
		var unit := U.new(); unit.entity_id = index + 1; unit.key = UNIT_KEYS[index]
		unit.process_mode = Node.PROCESS_MODE_DISABLED; unit.set_block_signals(true)
		owned.append(unit); ids[str(index + 1)] = unit
	return ids

func _level_fixture(ids: Dictionary, stage: String, serial: int) -> Variant:
	var level := Zhu.new()
	for i in range(UNIT_FIELDS.size()): level.set(UNIT_FIELDS[i], ids[str(i + 1)])
	for i in range(7): level.prisoners.append(ids[str(i + 9)])
	level.workers.assign([ids["16"], null, ids["17"]]); level.enemy_workers.assign([ids["18"]])
	level.enemy_nodes.assign([ids["19"], ids["20"]]); level.reserve.assign([ids["1"], ids["9"]])
	level.trained.assign([ids["21"], ids["1"]]); level.resource_guards.assign([ids["6"], ids["7"]])
	level.elapsed = 137.25 + serial; level.train_clock = 21.5; level.raid_clock = 72.75; level.strategic_clock = 0.125
	level.ai_trained = serial + 2; level.ai_spent_gold = 17; level.ai_spent_wood = 9; level.raids_sent = serial + 1
	level.stage = stage
	for i in range(BOOL_FIELDS.size()): level.set(BOOL_FIELDS[i], (i + serial) % 2 == 0)
	return level

func _write_fixtures() -> void:
	var ids := _registry(); var state := LevelState.new(); var records: Array = []
	check("actual Level3 has 31 audited fields", state.audit_declarations("level3").ok and state._names("level3").size() == 31)
	for i in range(3):
		var level: Variant = _level_fixture(ids, ["scout", "contest", "siege"][i], i)
		var captured := state.capture(level, "level3", identity.content_version, ids, 22, {}, {"mission_token": TOKEN, "deferred_drained": true})
		check("actual LevelState source capture " + level.stage, captured.ok)
		if captured.ok: records.append(captured.record)
	var file := FileAccess.open(OS.get_environment("LSH_OFFICIAL_PROFILE_FIXTURE"), FileAccess.WRITE)
	check("fixture output opened", file != null)
	if file != null:
		file.store_string(JSON.stringify({"schema": "official_profile_level_fixture_v1", "producer_pid": OS.get_process_id(), "records": records, "unit_keys": UNIT_KEYS,
			"mission_token": TOKEN, "next_entity_id": 22, "content_version": identity.content_version, "engine_sha256": identity.engine_binary_sha256}, "  ")); file.close()
	fixture_info = {"records": records.size(), "unit_count": ids.size(), "fields_per_level": 31, "stages": ["scout", "contest", "siege"], "producer_pid": OS.get_process_id(), "sha256": FileAccess.get_sha256(OS.get_environment("LSH_OFFICIAL_PROFILE_FIXTURE"))}

func _mutate(record: Dictionary, section: String, field: String, value: Variant) -> Dictionary:
	var result := record.duplicate(true); var codec := Codec.new()
	var decoded: Dictionary = codec.decode(result.payload).value
	decoded[section][field] = value
	result.payload = codec.encode(decoded).value
	return result

func _test_restore() -> void:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("LSH_OFFICIAL_PROFILE_FIXTURE")))
	check("fresh process reads producer fixture", value is Dictionary and value.get("schema") == "official_profile_level_fixture_v1")
	if not value is Dictionary or value.get("schema") != "official_profile_level_fixture_v1": return
	check("fixture identity and registry shape", value.content_version == identity.content_version and value.engine_sha256 == identity.engine_binary_sha256 and value.unit_keys == UNIT_KEYS and value.records.size() == 3)
	check("fixture producer is a different native process", value.get("producer_pid", 0) > 0 and int(value.producer_pid) != OS.get_process_id())
	var ids := _registry(); var state := LevelState.new()
	fixture_info = {"records": value.records.size(), "unit_count": ids.size(), "fields_per_level": 31, "producer_pid": value.producer_pid, "sha256": FileAccess.get_sha256(OS.get_environment("LSH_OFFICIAL_PROFILE_FIXTURE"))}
	for i in range(value.records.size()):
		var record: Dictionary = value.records[i]
		var expected: Variant = _level_fixture(ids, ["scout", "contest", "siege"][i], i)
		var restored := Factory.restore_level(record, identity, ids, 22, TOKEN)
		check("factory restores stage " + expected.stage, restored.ok)
		if not restored.ok: continue
		check("restored actual private Level3 " + expected.stage, restored.level != expected and restored.level.get_script() == Zhu and restored.complete_world == false and restored.deploy_or_start_called == false)
		for field: String in state._names("level3"): check("restored field " + expected.stage + " " + field, restored.level.get(field) == expected.get(field))
		var again := state.capture(restored.level, "level3", identity.content_version, ids, 22, {}, {"mission_token": TOKEN, "deferred_drained": true})
		check("recaptured exact record " + expected.stage, again.ok and again.record == record)
		check("new registry aliases preserved " + expected.stage, restored.level.hall == ids["1"] and restored.level.trained[1] == ids["1"] and restored.level.prisoners[0] == ids["9"] and restored.level.prisoners[6] == ids["15"])
		var variants: Array = []
		for pair: Array in [["schema", "wrong"], ["level_id", "level2"], ["content_version", "wrong"], ["mission_token", "other"]]:
			var bad := record.duplicate(true); bad[pair[0]] = pair[1]; variants.append(bad)
		for field: String in ["schema", "level_id", "content_version", "mission_token"]:
			for invalid_identity: Variant in [1, [], {}, true, null]:
				var bad := record.duplicate(true)
				bad[field] = invalid_identity
				reject("level identity type rejected " + expected.stage + " " + field + " " + type_string(typeof(invalid_identity)), Factory.restore_level(bad, identity, ids, 22, TOKEN))
		variants.append(_mutate(record, "values", "stage", "other"))
		variants.append(_mutate(record, "values", "elapsed", "1.2"))
		variants.append(_mutate(record, "values", "unknown", 1))
		variants.append(_mutate(record, "references", "prisoners", []))
		variants.append(_mutate(record, "references", "hall", "999"))
		for n in range(variants.size()): reject("bad level record " + expected.stage + " " + str(n), Factory.restore_level(variants[n], identity, ids, 22, TOKEN))
		reject("wrong mission token " + expected.stage, Factory.restore_level(record, identity, ids, 22, "other"))
		reject("allocator bounds " + expected.stage, Factory.restore_level(record, identity, ids, 21, TOKEN))
		var missing := ids.duplicate(); missing.erase("15")
		reject("missing new referenced Unit " + expected.stage, Factory.restore_level(record, identity, missing, 22, TOKEN))
		ids["1"].process_mode = Node.PROCESS_MODE_INHERIT
		reject("ungated Unit rejected " + expected.stage, Factory.restore_level(record, identity, ids, 22, TOKEN))
		ids["1"].process_mode = Node.PROCESS_MODE_DISABLED; ids["1"].set_block_signals(false)
		reject("unblocked Unit rejected " + expected.stage, Factory.restore_level(record, identity, ids, 22, TOKEN))
		ids["1"].set_block_signals(true)
		var bad_identity := identity.duplicate(); bad_identity.save_eligible = false
		reject("restore identity required " + expected.stage, Factory.restore_level(record, bad_identity, ids, 22, TOKEN))
		check("failure leaves valid restore available " + expected.stage, Factory.restore_level(record, identity, ids, 22, TOKEN).ok)
	check("shared Unit registry remains detached and gated", ids.values().all(func(u): return u.get_parent() == null and u.process_mode == Node.PROCESS_MODE_DISABLED and u.is_blocking_signals() and u.battle == null and u.map == null))
