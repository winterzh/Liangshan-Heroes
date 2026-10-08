extends RefCounted
## Fixed data-only campaign outcome. Recovery never creates a Battle or Mission.
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const MissionScript := preload("res://scripts/campaign_mission.gd")
const Policy := preload("res://scripts/steam_run_policy.gd")
const SCHEMA := "campaign_progress_intent_v1"
const FIELDS := ["schema", "token", "context", "profile_id", "owner", "content_version", "engine_sha256", "victory", "result"]
const RESULT_FIELDS := ["core_cleared", "story_complete", "story_done", "story_total", "done_ids", "contract_version"]
const CONTRACTS := {
	"level1":{"version":2, "ids":["merchant_cover", "wine_scheme", "no_bloodshed", "all_safe"]},
	"level2":{"version":2, "ids":["li_kui_first", "free_both", "bailong_meeting", "named_survive"]},
	"level3":{"version":2, "ids":["zhu_capture", "zhu_inside", "zhu_seven"]},
	"level4":{"version":2, "ids":["lhm_training", "lhm_hooks", "lhm_han", "lhm_hu"]},
	"level5":{"version":3, "ids":["gao_lure", "gao_fire", "gao_land", "gao_capture"]},
	"level6":{"version":2, "ids":["hidden_intercept", "spare_escorts", "care_and_escort"]},
	"level7":{"version":2, "ids":["three_bowls", "drunken_provocation", "signature_fists", "spare_and_restore"]},
	"level8":{"version":2, "ids":["daming_infiltration", "daming_signal", "daming_response"]},
}

static func bad(code: String) -> Dictionary:
	return {"ok":false, "code":code}

static func fields(value: Variant, names: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != names.size(): return false
	for key in value:
		if typeof(key) != TYPE_STRING or key not in names: return false
	return value.has_all(names)

static func hex(value: Variant, count: int) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != count: return false
	for byte in value.to_utf8_buffer():
		if not (byte >= 48 and byte <= 57) and not (byte >= 97 and byte <= 102): return false
	return true

static func integer(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) \
		and float(value) == floor(float(value)) and value >= low and value <= high

static func valid_owner(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING: return false
	if value.is_empty(): return true
	# Preserve the existing SteamCloud owner domain; empty is an offline profile.
	return value.length() <= 20 and value.is_valid_int() and not value.begins_with("+") \
		and not value.begins_with("-") and value.to_int() > 0

static func scope(context: Variant, identity: Variant, owner: Variant) -> Dictionary:
	if typeof(identity) != TYPE_DICTIONARY or not valid_owner(owner): return bad("CAMPAIGN_SCOPE_TYPES")
	var chosen: Dictionary = Profiles.select_context(context, identity)
	if not chosen.ok: return chosen
	if not Profiles.is_official_campaign_profile(chosen.profile_id): return bad("CAMPAIGN_SCOPE_REQUIRED")
	return {"ok":true, "context":chosen.context, "profile_id":chosen.profile_id,
		"scope":{"owner":owner, "content_version":chosen.content_version, "engine_sha256":chosen.engine_sha256}}

static func validate_result(value: Variant, context: Dictionary, victory: bool) -> Dictionary:
	if not fields(value, RESULT_FIELDS): return bad("CAMPAIGN_INTENT_RESULT_FIELDS")
	if typeof(value.core_cleared) != TYPE_BOOL or typeof(value.story_complete) != TYPE_BOOL: return bad("CAMPAIGN_INTENT_RESULT_TYPES")
	if not CONTRACTS.has(context.level_id): return bad("CAMPAIGN_INTENT_CONTRACT_REQUIRED")
	var contract: Dictionary = CONTRACTS[context.level_id]
	if not integer(value.story_total, contract.ids.size(), contract.ids.size()) \
		or not integer(value.story_done, 0, contract.ids.size()) \
		or not integer(value.contract_version, contract.version, contract.version): return bad("CAMPAIGN_INTENT_CONTRACT_MISMATCH")
	if typeof(value.done_ids) != TYPE_ARRAY or value.done_ids.get_typed_builtin() not in [TYPE_NIL, TYPE_STRING] \
		or value.done_ids.get_typed_script() != null or value.done_ids.size() != int(value.story_done): return bad("CAMPAIGN_INTENT_IDS")
	var ids: Array = []
	for item in value.done_ids:
		if typeof(item) != TYPE_STRING or item not in contract.ids or ids.has(item): return bad("CAMPAIGN_INTENT_IDS")
		ids.append(item)
	if value.core_cleared != victory or value.story_complete != (victory and int(value.story_done) == int(value.story_total)):
		return bad("CAMPAIGN_INTENT_OUTCOME_MISMATCH")
	return {"ok":true, "result":{"core_cleared":victory, "story_complete":value.story_complete,
		"story_done":int(value.story_done), "story_total":int(value.story_total), "done_ids":ids,
		"contract_version":int(value.contract_version)}}

static func validate(value: Variant, expected_token: String, expected: Dictionary) -> Dictionary:
	if not fields(value, FIELDS): return bad("CAMPAIGN_INTENT_FIELDS")
	if typeof(value.schema) != TYPE_STRING or value.schema != SCHEMA or not hex(value.token, 32) or value.token != expected_token:
		return bad("CAMPAIGN_INTENT_IDENTITY")
	var normalized: Dictionary = Profiles.normalize_context(value.context)
	if not normalized.ok or normalized.context != expected.context: return bad("CAMPAIGN_INTENT_CONTEXT")
	if typeof(value.profile_id) != TYPE_STRING or value.profile_id != expected.profile_id \
		or not Profiles._installed(value.profile_id): return bad("CAMPAIGN_INTENT_PROFILE")
	if not valid_owner(value.owner) or value.owner != expected.scope.owner \
		or typeof(value.content_version) != TYPE_STRING or value.content_version != expected.scope.content_version \
		or not hex(value.engine_sha256, 64) or value.engine_sha256 != expected.scope.engine_sha256:
		return bad("CAMPAIGN_INTENT_SCOPE_CHANGED")
	if typeof(value.victory) != TYPE_BOOL: return bad("CAMPAIGN_INTENT_VICTORY_TYPE")
	var result: Dictionary = validate_result(value.result, expected.context, value.victory)
	if not result.ok: return result
	return {"ok":true, "intent":{"schema":SCHEMA, "token":expected_token, "context":normalized.context,
		"profile_id":expected.profile_id, "owner":value.owner, "content_version":value.content_version,
		"engine_sha256":value.engine_sha256, "victory":value.victory, "result":result.result}}

static func capture(battle: Variant, run_token: Variant, victory: Variant, identity: Variant) -> Dictionary:
	if typeof(victory) != TYPE_BOOL or not hex(run_token, 32) or typeof(battle) != TYPE_OBJECT \
		or not is_instance_valid(battle) or not battle is Node:
		return bad("CAMPAIGN_INTENT_SOURCE_REQUIRED")
	# A fixed cache lookup avoids preload cycles with Battle/ContinueFlow. Never
	# accept a path from the result or journal and never instantiate this script.
	var actual_script: Resource = ResourceLoader.load("res://scripts/battle.gd", "Script", ResourceLoader.CACHE_MODE_REUSE)
	var tree: MainLoop = Engine.get_main_loop()
	if not tree is SceneTree or (tree as SceneTree).current_scene != battle or battle.get_script() != actual_script or battle.phase != 3:
		return bad("CAMPAIGN_INTENT_TERMINAL_BATTLE_REQUIRED")
	var campaign = (tree as SceneTree).root.get_node_or_null("Campaign")
	var chosen: Dictionary = scope(battle._official_context, identity, campaign.cloud_owner if campaign != null else null)
	if not chosen.ok: return chosen
	var selected: Dictionary = Profiles.capture_selection(campaign, battle.level, identity)
	if not selected.ok or selected.context != chosen.context or Policy.classify(campaign, battle.level) != chosen.context:
		return bad("CAMPAIGN_INTENT_ACTUAL_CONTEXT_CHANGED")
	var mission = battle.mission
	if not is_instance_valid(mission) or mission.get_script() != MissionScript or mission.battle != battle:
		return bad("CAMPAIGN_INTENT_ACTUAL_MISSION_REQUIRED")
	var frozen: Dictionary = mission.result_snapshot(victory)
	if not mission._result_frozen or mission._result_cache != frozen: return bad("CAMPAIGN_INTENT_FROZEN_SOURCE_REQUIRED")
	var projection: Dictionary = {}
	for key in RESULT_FIELDS:
		if not frozen.has(key): return bad("CAMPAIGN_INTENT_FROZEN_RESULT_REQUIRED")
		projection[key] = frozen[key]
	var intent := {"schema":SCHEMA, "token":run_token, "context":chosen.context,
		"profile_id":chosen.profile_id, "owner":chosen.scope.owner, "content_version":chosen.scope.content_version,
		"engine_sha256":chosen.scope.engine_sha256, "victory":victory, "result":projection}
	return validate(intent, run_token, chosen)

static func cfg_dominates(cfg: ConfigFile, intent: Dictionary) -> bool:
	# A later better single run may dominate this non-additive intent. This never
	# unions IDs or requires an unrelated later preference file to keep an old SHA.
	if not intent.victory: return true
	for key in ["schema", "owner", "unlocked", "records"]:
		if not cfg.has_section_key("progress", key): return false
	var owner: Variant = cfg.get_value("progress", "owner", null)
	if not integer(cfg.get_value("progress", "schema", null), 2, 2) or typeof(owner) != TYPE_STRING or owner != intent.owner:
		return false
	var required_unlock := 1
	for index in range(Profiles.CampaignScript.LEVELS.size()):
		if Profiles.CampaignScript.LEVELS[index].id == intent.context.level_id: required_unlock = index + 2
	if not integer(cfg.get_value("progress", "unlocked", null), required_unlock, 9): return false
	var records: Variant = cfg.get_value("progress", "records", null)
	if typeof(records) != TYPE_DICTIONARY or not records.has(intent.context.level_id): return false
	var record: Variant = records[intent.context.level_id]
	if typeof(record) != TYPE_DICTIONARY or typeof(record.get("cleared")) != TYPE_BOOL or not record.cleared \
		or typeof(record.get("story_complete")) != TYPE_BOOL: return false
	if intent.result.story_complete and not record.story_complete: return false
	if not integer(record.get("best_done"), 0, 100000) or record.best_done < intent.result.story_done \
		or not integer(record.get("story_total"), int(record.best_done), 100000) \
		or not integer(record.get("contract_version"), int(intent.result.contract_version), 100000): return false
	var ids: Variant = record.get("best_goal_ids")
	if typeof(ids) != TYPE_ARRAY or ids.size() != int(record.best_done): return false
	var seen: Dictionary = {}
	for item in ids:
		if typeof(item) != TYPE_STRING or item not in CONTRACTS[intent.context.level_id].ids or seen.has(item): return false
		seen[item] = true
	return true
