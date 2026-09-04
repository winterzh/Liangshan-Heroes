extends SceneTree
## Read-only headless inventory/contract for the default Liangshan defense roster.
##
## The roster is derived from the production 30-wave table, the production
## catapult rule and the units exposed by the default economy producers.  Art
## gaps are reported as coverage, while broken runtime routing and legacy
## action precedence are contract failures.

const CA := preload("res://scripts/campaign_art.gd")
const REPORT_DIR := "res://qa/skirmish_direction4_20260904"
const REPORT_PATH := REPORT_DIR + "/report.json"
const ANIM_DIR := "res://assets/anim"
const FULL_DIRECTION_STATES := ["idle", "walk", "attack", "hurt", "down"]
const LEGACY_PRECEDENCE_STATES := ["walk", "attack", "hurt", "down", "death"]

var checks: Array = []
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, details: Variant = null) -> void:
	checks.append({"name":name, "passed":passed, "details":details})
	print("[skirmish-direction4] ", "PASS " if passed else "FAIL ", name,
		"" if details == null else " :: " + JSON.stringify(details))
	if not passed:
		failures.append(name)


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path)


func _frame_source(frame: Variant) -> String:
	if frame is AtlasTexture and frame.atlas != null:
		return frame.atlas.resource_path
	return frame.resource_path if frame != null else ""


func _percent(part: int, whole: int) -> float:
	return snappedf(100.0 * float(part) / float(whole), 0.001) if whole > 0 else 0.0


func _add_role(roles: Dictionary, key: String, role: String) -> void:
	var current: Array = roles.get(key, [])
	if role not in current:
		current.append(role)
	roles[key] = current


func _add_producer(producers: Dictionary, unit_key: String, producer_key: String) -> void:
	var current: Array = producers.get(unit_key, [])
	if producer_key not in current:
		current.append(producer_key)
	producers[unit_key] = current


func _derive_enemy_roster(skirmish_script: GDScript) -> Dictionary:
	var weights: Dictionary = {}
	var wave_appearances: Dictionary = {}
	var waves: Array = skirmish_script.WAVES
	for wave_index in range(waves.size()):
		var wave: Dictionary = waves[wave_index]
		for raw_group in wave.get("groups", []):
			var group: Array = raw_group
			var key := String(group[0])
			var count := int(group[1])
			weights[key] = int(weights.get(key, 0)) + count
			wave_appearances[key] = int(wave_appearances.get(key, 0)) + 1

	# Do not duplicate the implementation formula here: use the production
	# level method for every default wave so a future rule change is reflected.
	var level = skirmish_script.new()
	var cata_total := 0
	var cata_waves := 0
	for wave_index in range(waves.size()):
		var count := int(level._cata_for(wave_index))
		if count > 0:
			cata_total += count
			cata_waves += 1
	level = null
	if cata_total > 0:
		weights["siege_cata"] = int(weights.get("siege_cata", 0)) + cata_total
		wave_appearances["siege_cata"] = int(wave_appearances.get("siege_cata", 0)) + cata_waves
	return {
		"weights":weights,
		"wave_appearances":wave_appearances,
		"wave_count":waves.size(),
		"catapult_instances":cata_total,
		"catapult_waves":cata_waves,
	}


func _derive_default_trainable_roster(definitions: Dictionary) -> Dictionary:
	var producers: Dictionary = {}
	var producer_keys: Array[String] = []
	var keys: Array = definitions.keys()
	keys.sort()
	for raw_producer_key in keys:
		var producer_key := String(raw_producer_key)
		var definition: Dictionary = definitions[producer_key]
		# The deployed main base plus player-buildable production buildings are
		# the default defense economy.  Scenario-only buildings are excluded.
		var available_by_default := bool(definition.get("is_main_base", false)) \
			or bool(definition.get("buildable", false))
		if not available_by_default or not definition.has("produces"):
			continue
		producer_keys.append(producer_key)
		for raw_unit_key in definition.get("produces", []):
			_add_producer(producers, String(raw_unit_key), producer_key)
	producer_keys.sort()
	for raw_key in producers.keys():
		var unit_key := String(raw_key)
		var sources: Array = producers[unit_key]
		sources.sort()
		producers[unit_key] = sources
	return {"producers":producers, "producer_keys":producer_keys}


func _state_audit(art: Node, key: String, state: String) -> Dictionary:
	var physical_directions: Array[String] = []
	var resource_directions: Array[String] = []
	var runtime_exact_directions: Array[String] = []
	var selected_sources: Dictionary = {}
	var directional_flags: Dictionary = {}
	var sha256: Dictionary = {}
	var routing_mismatches: Array = []
	var import_mismatches: Array = []
	for raw_direction in CA.DIRECTIONS:
		var direction := String(raw_direction)
		var expected := ANIM_DIR.path_join("%s_%s_%s.png" % [key, state, direction])
		var physical_exists := FileAccess.file_exists(expected)
		var resource_exists := ResourceLoader.exists(expected)
		if physical_exists:
			physical_directions.append(direction)
			sha256[direction] = FileAccess.get_sha256(expected)
		if resource_exists:
			resource_directions.append(direction)
		if physical_exists != resource_exists:
			import_mismatches.append({
				"state":state,
				"direction":direction,
				"path":expected,
				"physical_exists":physical_exists,
				"resource_exists":resource_exists,
			})
		var frames: Array = art.unit_anim_frames(key, state, direction, "")
		var selected := _frame_source(frames[0]) if not frames.is_empty() else ""
		var directional: bool = bool(art.unit_anim_uses_directional_source(key, state, direction, ""))
		selected_sources[direction] = selected
		directional_flags[direction] = directional
		if resource_exists and selected == expected and directional:
			runtime_exact_directions.append(direction)
		elif resource_exists:
			routing_mismatches.append({
				"state":state,
				"direction":direction,
				"expected":expected,
				"selected":selected,
				"directional":directional,
			})
	var exact_four_direction := runtime_exact_directions.size() == CA.DIRECTIONS.size()
	return {
		"physical_directions":physical_directions,
		"resource_directions":resource_directions,
		"runtime_exact_directions":runtime_exact_directions,
		"missing_runtime_exact_directions":CA.DIRECTIONS.filter(
			func(direction): return String(direction) not in runtime_exact_directions),
		"selected_sources":selected_sources,
		"runtime_directional_flags":directional_flags,
		"sha256":sha256,
		"exact_four_direction":exact_four_direction,
		"routing_mismatches":routing_mismatches,
		"import_mismatches":import_mismatches,
	}


func _legacy_precedence_audit(art: Node, key: String) -> Dictionary:
	var cases: Array = []
	var idle_override_risks: Array = []
	var other_mismatches: Array = []
	for raw_state in LEGACY_PRECEDENCE_STATES:
		var state := String(raw_state)
		var legacy_path := ANIM_DIR.path_join("%s_%s.png" % [key, state])
		if not ResourceLoader.exists(legacy_path):
			continue
		for raw_direction in CA.DIRECTIONS:
			var direction := String(raw_direction)
			var exact_path := ANIM_DIR.path_join("%s_%s_%s.png" % [key, state, direction])
			# Exact directional actions correctly take priority over legacy actions;
			# this contract concerns the fallback case only.
			if ResourceLoader.exists(exact_path):
				continue
			var frames: Array = art.unit_anim_frames(key, state, direction, "")
			var selected := _frame_source(frames[0]) if not frames.is_empty() else ""
			var directional: bool = bool(art.unit_anim_uses_directional_source(key, state, direction, ""))
			var idle_path := ANIM_DIR.path_join("%s_idle_%s.png" % [key, direction])
			var preserved: bool = selected == legacy_path and not directional
			var record := {
				"state":state,
				"direction":direction,
				"legacy_path":legacy_path,
				"selected":selected,
				"runtime_directional":directional,
				"preserved":preserved,
			}
			cases.append(record)
			if not preserved:
				if ResourceLoader.exists(idle_path) and selected == idle_path:
					idle_override_risks.append(record)
				else:
					other_mismatches.append(record)
	return {
		"cases":cases,
		"idle_override_risks":idle_override_risks,
		"other_mismatches":other_mismatches,
	}


func _audit_unit(art: Node, key: String, definition: Dictionary, roles: Array,
		enemy_weight: int, wave_appearances: int, producers: Array) -> Dictionary:
	var states: Dictionary = {}
	var routing_mismatches: Array = []
	var import_mismatches: Array = []
	var missing_full_states: Array[String] = []
	for raw_state in FULL_DIRECTION_STATES:
		var state := String(raw_state)
		var state_result := _state_audit(art, key, state)
		states[state] = state_result
		routing_mismatches.append_array(state_result["routing_mismatches"])
		import_mismatches.append_array(state_result["import_mismatches"])
		if not bool(state_result["exact_four_direction"]):
			missing_full_states.append(state)
	var legacy := _legacy_precedence_audit(art, key)
	return {
		"key":key,
		"display_name":String(definition.get("name", key)),
		"roles":roles,
		"enemy_instance_weight":enemy_weight,
		"enemy_wave_appearances":wave_appearances,
		"producer_keys":producers,
		"idle_four_direction":bool(states["idle"]["exact_four_direction"]),
		"full_action_four_direction":missing_full_states.is_empty(),
		"missing_full_direction_states":missing_full_states,
		"states":states,
		"legacy_precedence_case_count":legacy["cases"].size(),
		"legacy_action_idle_override_risks":legacy["idle_override_risks"],
		"legacy_action_other_mismatches":legacy["other_mismatches"],
		"routing_mismatches":routing_mismatches,
		"import_mismatches":import_mismatches,
	}


func _sort_frequency_desc(a: Dictionary, b: Dictionary) -> bool:
	var aw := int(a.get("enemy_instance_weight", 0))
	var bw := int(b.get("enemy_instance_weight", 0))
	if aw == bw:
		return String(a.get("key", "")) < String(b.get("key", ""))
	return aw > bw


func _stop_test_audio() -> void:
	for autoload_name in ["Sfx", "Music"]:
		var audio_root := root.get_node_or_null(autoload_name)
		if audio_root == null:
			continue
		audio_root.set("enabled", false)
		for child in audio_root.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream = null


func _write_report(report: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(_absolute(REPORT_DIR))
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output == null:
		return false
	output.store_string(JSON.stringify(report, "  ") + "\n")
	output.close()
	return true


func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	_stop_test_audio()
	var skirmish_script = load("res://scripts/levels/skirmish.gd")
	var definitions_script = load("res://scripts/defs.gd")
	var scripts_ok: bool = skirmish_script != null and definitions_script != null \
		and skirmish_script.can_instantiate() and definitions_script.can_instantiate()
	_check("production skirmish and definitions scripts instantiate", scripts_ok)
	if not scripts_ok:
		var failed_report := {
			"passed":false,
			"automation":true,
			"human_playtest":false,
			"failures":failures,
			"checks":checks,
		}
		_write_report(failed_report)
		quit(1)
		return

	var definitions: Dictionary = definitions_script.UNITS
	var enemy := _derive_enemy_roster(skirmish_script)
	var trainable := _derive_default_trainable_roster(definitions)
	var enemy_weights: Dictionary = enemy["weights"]
	var appearances: Dictionary = enemy["wave_appearances"]
	var trainable_producers: Dictionary = trainable["producers"]
	var roles: Dictionary = {}
	for raw_key in enemy_weights.keys():
		_add_role(roles, String(raw_key), "enemy_default_30_wave")
	for raw_key in trainable_producers.keys():
		_add_role(roles, String(raw_key), "player_default_trainable")
	var roster_keys: Array = roles.keys()
	roster_keys.sort()
	var undefined_keys: Array[String] = []
	for raw_key in roster_keys:
		if not definitions.has(String(raw_key)):
			undefined_keys.append(String(raw_key))
	_check("derived roster is non-empty", not roster_keys.is_empty(), {
		"unique":roster_keys.size(), "enemy_unique":enemy_weights.size(),
		"trainable_unique":trainable_producers.size(),
	})
	_check("all derived roster keys exist in production definitions", undefined_keys.is_empty(), undefined_keys)
	_check("production wave table and catapult rule are represented",
		int(enemy["wave_count"]) == skirmish_script.WAVES.size() \
			and int(enemy["catapult_instances"]) > 0,
		{"waves":enemy["wave_count"], "catapult_instances":enemy["catapult_instances"]})

	var art := root.get_node("Art")
	var rows: Array = []
	var all_routing_mismatches: Array = []
	var all_import_mismatches: Array = []
	var all_idle_override_risks: Array = []
	var all_legacy_other_mismatches: Array = []
	var legacy_case_count := 0
	for raw_key in roster_keys:
		var key := String(raw_key)
		if not definitions.has(key):
			continue
		var row := _audit_unit(art, key, definitions[key], roles.get(key, []),
			int(enemy_weights.get(key, 0)), int(appearances.get(key, 0)),
			trainable_producers.get(key, []))
		rows.append(row)
		for mismatch in row["routing_mismatches"]:
			var tagged: Dictionary = mismatch.duplicate(true)
			tagged["key"] = key
			all_routing_mismatches.append(tagged)
		for mismatch in row["import_mismatches"]:
			var tagged: Dictionary = mismatch.duplicate(true)
			tagged["key"] = key
			all_import_mismatches.append(tagged)
		legacy_case_count += int(row["legacy_precedence_case_count"])
		for risk in row["legacy_action_idle_override_risks"]:
			var tagged: Dictionary = risk.duplicate(true)
			tagged["key"] = key
			all_idle_override_risks.append(tagged)
		for mismatch in row["legacy_action_other_mismatches"]:
			var tagged: Dictionary = mismatch.duplicate(true)
			tagged["key"] = key
			all_legacy_other_mismatches.append(tagged)

	_check("physical directional files are importable", all_import_mismatches.is_empty(), all_import_mismatches)
	_check("exact directional files route to their exact runtime source", all_routing_mismatches.is_empty(), all_routing_mismatches)
	_check("legacy actions are never incorrectly covered by directional idle",
		all_idle_override_risks.is_empty(), all_idle_override_risks)
	_check("legacy action fallback has no other routing mismatch",
		all_legacy_other_mismatches.is_empty(), all_legacy_other_mismatches)

	var enemy_unique := enemy_weights.size()
	var enemy_instances := 0
	for weight in enemy_weights.values():
		enemy_instances += int(weight)
	var enemy_idle_unique := 0
	var enemy_idle_instances := 0
	var enemy_full_unique := 0
	var enemy_full_instances := 0
	var trainable_idle_unique := 0
	var trainable_full_unique := 0
	var roster_idle_unique := 0
	var roster_full_unique := 0
	var high_frequency_idle_gaps: Array = []
	var high_frequency_full_action_gaps: Array = []
	for row in rows:
		var key := String(row["key"])
		var idle_ok := bool(row["idle_four_direction"])
		var full_ok := bool(row["full_action_four_direction"])
		if idle_ok:
			roster_idle_unique += 1
		if full_ok:
			roster_full_unique += 1
		if enemy_weights.has(key):
			var weight := int(enemy_weights[key])
			if idle_ok:
				enemy_idle_unique += 1
				enemy_idle_instances += weight
			else:
				high_frequency_idle_gaps.append({
					"key":key,
					"display_name":row["display_name"],
					"enemy_instance_weight":weight,
					"wave_appearances":row["enemy_wave_appearances"],
					"missing_idle_directions":row["states"]["idle"]["missing_runtime_exact_directions"],
				})
			if full_ok:
				enemy_full_unique += 1
				enemy_full_instances += weight
			else:
				high_frequency_full_action_gaps.append({
					"key":key,
					"display_name":row["display_name"],
					"enemy_instance_weight":weight,
					"wave_appearances":row["enemy_wave_appearances"],
					"missing_states":row["missing_full_direction_states"],
				})
		if trainable_producers.has(key):
			if idle_ok:
				trainable_idle_unique += 1
			if full_ok:
				trainable_full_unique += 1
	high_frequency_idle_gaps.sort_custom(_sort_frequency_desc)
	high_frequency_full_action_gaps.sort_custom(_sort_frequency_desc)

	var report := {
		"schema":"skirmish_direction4_contract_v1",
		"generated_at":Time.get_datetime_string_from_system(false, true),
		"passed":failures.is_empty(),
		"automation":true,
		"human_playtest":false,
		"evidence_class":"headless_contract_and_inventory",
		"scope":"Default 30-wave defense roster, production catapult rule and default economy trainables. No visual, gameplay-feel, performance or human-playtest claim.",
		"coverage_semantics":{
			"idle_four_direction":"All se/sw/ne/nw idle resources exist and Art selects each exact directional path at runtime.",
			"full_action_four_direction":"All se/sw/ne/nw resources are selected exactly for idle, walk, attack, hurt and down.",
			"passed":"Contract integrity and fallback ordering only; missing art is reported by coverage gates and does not masquerade as a runtime test failure.",
		},
		"source_derivation":{
			"waves":"res://scripts/levels/skirmish.gd::WAVES",
			"catapult_rule":"res://scripts/levels/skirmish.gd::_cata_for",
			"trainables":"res://scripts/defs.gd producers where is_main_base or buildable",
			"producer_keys":trainable["producer_keys"],
			"source_sha256":{
				"skirmish.gd":FileAccess.get_sha256("res://scripts/levels/skirmish.gd"),
				"defs.gd":FileAccess.get_sha256("res://scripts/defs.gd"),
				"art_db.gd":FileAccess.get_sha256("res://scripts/art_db.gd"),
			},
		},
		"summary":{
			"default_wave_count":enemy["wave_count"],
			"catapult_instances":enemy["catapult_instances"],
			"enemy_unique":enemy_unique,
			"enemy_instances":enemy_instances,
			"enemy_idle_four_direction_unique":enemy_idle_unique,
			"enemy_idle_four_direction_unique_percent":_percent(enemy_idle_unique, enemy_unique),
			"enemy_idle_four_direction_weighted_instances":enemy_idle_instances,
			"enemy_idle_four_direction_weighted_percent":_percent(enemy_idle_instances, enemy_instances),
			"enemy_full_action_four_direction_unique":enemy_full_unique,
			"enemy_full_action_four_direction_weighted_instances":enemy_full_instances,
			"default_trainable_unique":trainable_producers.size(),
			"default_trainable_idle_four_direction_unique":trainable_idle_unique,
			"default_trainable_idle_four_direction_percent":_percent(trainable_idle_unique, trainable_producers.size()),
			"default_trainable_full_action_four_direction_unique":trainable_full_unique,
			"combined_roster_unique":rows.size(),
			"combined_roster_idle_four_direction_unique":roster_idle_unique,
			"combined_roster_full_action_four_direction_unique":roster_full_unique,
			"legacy_precedence_cases":legacy_case_count,
			"legacy_action_idle_override_risk_count":all_idle_override_risks.size(),
			"legacy_action_other_mismatch_count":all_legacy_other_mismatches.size(),
		},
		"coverage_gates":{
			"enemy_idle_complete":enemy_idle_unique == enemy_unique,
			"enemy_full_action_complete":enemy_full_unique == enemy_unique,
			"default_trainable_idle_complete":trainable_idle_unique == trainable_producers.size(),
			"default_trainable_full_action_complete":trainable_full_unique == trainable_producers.size(),
			"legacy_precedence_safe":all_idle_override_risks.is_empty() and all_legacy_other_mismatches.is_empty(),
		},
		"high_frequency_idle_gaps":high_frequency_idle_gaps,
		"high_frequency_full_action_gaps":high_frequency_full_action_gaps,
		"legacy_action_idle_override_risks":all_idle_override_risks,
		"legacy_action_other_mismatches":all_legacy_other_mismatches,
		"routing_mismatches":all_routing_mismatches,
		"import_mismatches":all_import_mismatches,
		"units":rows,
		"checks":checks,
		"failures":failures,
		"production_scripts_modified_by_test":false,
	}
	var wrote := _write_report(report)
	print("[skirmish-direction4-result] ", JSON.stringify({
		"passed":report["passed"],
		"report":REPORT_PATH,
		"report_written":wrote,
		"summary":report["summary"],
		"coverage_gates":report["coverage_gates"],
	}))
	_stop_test_audio()
	for frame in range(3):
		await process_frame
	quit(0 if wrote and failures.is_empty() else 1)
