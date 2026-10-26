extends RefCounted
## Strict read-only historical v2 data. No creation, migration or reward grant.
const Intent := preload("res://scripts/run_campaign_progress_intent.gd")
const Profiles := Intent.Profiles
const SCHEMA := "local_continue_lifecycle_v1"
const INTENT_SCHEMA := "campaign_progress_intent_v1"
const CAMPAIGN_SCHEMA := "local_campaign_continue_lifecycle_v2"
const FIELDS := ["schema", "token", "context", "profile_id", "owner", "content_version", "engine_sha256", "victory", "result"]
const DOCUMENT_FIELDS := ["schema", "generation", "token", "context", "scope", "state", "victory", "progress_state", "intent", "progress_receipt"]
const ACK_FIELDS := ["schema", "code", "persisted", "suppressed", "file_sha256"]

const RESULT_FIELDS := ["core_cleared", "story_complete", "story_done", "story_total", "done_ids", "contract_version"]
const HISTORICAL := {
	"campaign_level1_v1":{"level":"level1","version":2,"ids":["merchant_cover","wine_scheme","no_bloodshed","all_safe"]},
	"campaign_level1_v2":{"level":"level1","version":3,"ids":["merchant_cover","wine_scheme","no_bloodshed","all_safe"]},
	"campaign_level2_v1":{"level":"level2","version":2,"ids":["li_kui_first","free_both","bailong_meeting","named_survive"]},
	"campaign_level3_v1":{"level":"level3","version":2,"ids":["zhu_capture","zhu_inside","zhu_seven"]},
	"campaign_level4_v1":{"level":"level4","version":2,"ids":["lhm_training","lhm_hooks","lhm_han","lhm_hu"]},
	"campaign_level5_v1":{"level":"level5","version":3,"ids":["gao_lure","gao_fire","gao_land","gao_capture"]},
	"campaign_level6_v1":{"level":"level6","version":2,"ids":["hidden_intercept","spare_escorts","care_and_escort"]},
	"campaign_level7_v1":{"level":"level7","version":2,"ids":["three_bowls","drunken_provocation","signature_fists","spare_and_restore"]},
	"campaign_level8_v1":{"level":"level8","version":2,"ids":["daming_infiltration","daming_signal","daming_response"]},
}

static func integer(value: Variant, low: int, high: int) -> bool:
	return Intent.integer(value,low,high)

static func normalize_context(value: Variant) -> Dictionary:
	if not fields(value,["mode","level_id","waves"]) or value.mode != "campaign" \
		or typeof(value.level_id) != TYPE_STRING or not integer(value.waves,0,0): return bad("LEGACY_CAMPAIGN_CONTEXT")
	var profile_id := "campaign_" + value.level_id + "_v1"
	if not HISTORICAL.has(profile_id): return bad("LEGACY_CAMPAIGN_CONTEXT")
	return {"ok":true,"context":{"mode":"campaign","level_id":value.level_id,"waves":0},"profile_id":profile_id}

static func bad(code: String) -> Dictionary:
	return Intent.bad(code)
static func fields(value: Variant, names: Array) -> bool:
	return Intent.fields(value,names)
static func hex(value: Variant, count: int) -> bool:
	return Intent.hex(value,count)
static func valid_owner(value: Variant) -> bool:
	return Intent.valid_owner(value)
static func validate_result(value: Variant, context: Dictionary, victory: bool, profile_id: String) -> Dictionary:
	if not fields(value, RESULT_FIELDS): return bad("CAMPAIGN_INTENT_RESULT_FIELDS")
	if typeof(value.core_cleared) != TYPE_BOOL or typeof(value.story_complete) != TYPE_BOOL: return bad("CAMPAIGN_INTENT_RESULT_TYPES")
	if not HISTORICAL.has(profile_id): return bad("CAMPAIGN_INTENT_CONTRACT_REQUIRED")
	var contract: Dictionary = HISTORICAL[profile_id]
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

static func validate_intent(value: Variant, expected_token: String, expected: Dictionary) -> Dictionary:
	if not fields(value, FIELDS): return bad("CAMPAIGN_INTENT_FIELDS")
	if typeof(value.schema) != TYPE_STRING or value.schema != INTENT_SCHEMA or not hex(value.token, 32) or value.token != expected_token:
		return bad("CAMPAIGN_INTENT_IDENTITY")
	var normalized: Dictionary = normalize_context(value.context)
	if not normalized.ok or normalized.context != expected.context: return bad("CAMPAIGN_INTENT_CONTEXT")
	if typeof(value.profile_id) != TYPE_STRING or not HISTORICAL.has(value.profile_id) \
		or HISTORICAL[value.profile_id].level != value.context.level_id: return bad("CAMPAIGN_INTENT_PROFILE")
	if not valid_owner(value.owner) or value.owner != expected.scope.owner \
		or typeof(value.content_version) != TYPE_STRING or value.content_version != expected.scope.content_version \
		or not hex(value.engine_sha256, 64) or value.engine_sha256 != expected.scope.engine_sha256:
		return bad("CAMPAIGN_INTENT_SCOPE_CHANGED")
	if typeof(value.victory) != TYPE_BOOL: return bad("CAMPAIGN_INTENT_VICTORY_TYPE")
	var result: Dictionary = validate_result(value.result, expected.context, value.victory, value.profile_id)
	if not result.ok: return result
	return {"ok":true, "intent":{"schema":INTENT_SCHEMA, "token":expected_token, "context":normalized.context,
		"profile_id":value.profile_id, "owner":value.owner, "content_version":value.content_version,
		"engine_sha256":value.engine_sha256, "victory":value.victory, "result":result.result}}

static func validate_document_data(value: Variant, expected_token: String, expected: Dictionary) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY and value.get("schema") == SCHEMA:
		return Intent.bad("LEGACY_CAMPAIGN_CONTEXT_UNBOUND")
	if not Intent.fields(value, DOCUMENT_FIELDS): return Intent.bad("LOCAL_CAMPAIGN_FIELDS")
	if typeof(value.schema) != TYPE_STRING or value.schema != CAMPAIGN_SCHEMA or not Intent.hex(value.token, 32) or value.token != expected_token:
		return Intent.bad("LOCAL_CAMPAIGN_IDENTITY")
	var context: Dictionary = normalize_context(value.context)
	if not context.ok or context.context != expected.context: return Intent.bad("LOCAL_CAMPAIGN_CONTEXT")
	if not Intent.fields(value.scope, ["owner", "content_version", "engine_sha256"]): return Intent.bad("LOCAL_CAMPAIGN_SCOPE_FIELDS")
	for key in value.scope:
		if typeof(value.scope[key]) != TYPE_STRING or value.scope[key] != expected.scope[key]: return Intent.bad("LOCAL_CAMPAIGN_SCOPE_CHANGED")
	if typeof(value.state) != TYPE_STRING or typeof(value.progress_state) != TYPE_STRING \
		or typeof(value.victory) != TYPE_BOOL or not Intent.integer(value.generation, 1, 3): return Intent.bad("LOCAL_CAMPAIGN_TYPES")
	var generation := int(value.generation)
	if generation == 1:
		if value.state != "active" or value.progress_state != "none" or value.victory \
			or typeof(value.intent) != TYPE_DICTIONARY or not value.intent.is_empty() \
			or typeof(value.progress_receipt) != TYPE_DICTIONARY or not value.progress_receipt.is_empty(): return Intent.bad("LOCAL_CAMPAIGN_TRANSITION")
	else:
		if value.state != "terminal" or value.progress_state != ("pending" if generation == 2 else "applied"):
			return Intent.bad("LOCAL_CAMPAIGN_TRANSITION")
		var frozen: Dictionary = validate_intent(value.intent, expected_token, expected)
		if not frozen.ok or frozen.intent.victory != value.victory: return Intent.bad("LOCAL_CAMPAIGN_INTENT_CHANGED")
		if generation == 2:
			if typeof(value.progress_receipt) != TYPE_DICTIONARY or not value.progress_receipt.is_empty(): return Intent.bad("LOCAL_CAMPAIGN_EARLY_ACK")
		else:
			var ack: Dictionary = _validate_ack(value.progress_receipt, value.victory)
			if not ack.ok: return ack
	var out: Dictionary = value.duplicate(true)
	out.generation = generation
	out.context = context.context
	if generation > 1: out.intent = validate_intent(value.intent, expected_token, expected).intent
	return {"ok":true, "document":out, "revision":generation}

static func _validate_ack(value: Variant, victory: bool) -> Dictionary:
	if not Intent.fields(value, ACK_FIELDS) or typeof(value.schema) != TYPE_STRING \
		or value.schema != "campaign_progress_ack_v1" or typeof(value.code) != TYPE_STRING \
		or typeof(value.persisted) != TYPE_BOOL or typeof(value.suppressed) != TYPE_BOOL or typeof(value.file_sha256) != TYPE_STRING:
		return Intent.bad("LOCAL_CAMPAIGN_ACK_FIELDS")
	if value.suppressed: return Intent.bad("LOCAL_CAMPAIGN_QA_IS_NOT_DURABLE")
	if victory:
		if value.code != "CAMPAIGN_CFG_READBACK_VERIFIED" or not value.persisted or not Intent.hex(value.file_sha256, 64):
			return Intent.bad("LOCAL_CAMPAIGN_CFG_NOT_VERIFIED")
	elif value.code != "CAMPAIGN_PROGRESS_NOT_REQUIRED" or value.persisted or not value.file_sha256.is_empty():
		return Intent.bad("LOCAL_CAMPAIGN_LOSS_ACK")
	return {"ok":true, "ack":value.duplicate()}
