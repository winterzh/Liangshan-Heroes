extends RefCounted
## Pure same-run projection. No filesystem, callback, Battle or reward operation.
const Intent := preload("res://scripts/run_campaign_progress_intent.gd")

static func _empty() -> Dictionary:
	return {"cleared":false, "story_complete":false, "best_done":0, "story_total":0,
		"best_goal_ids":[], "contract_version":1}

static func _prior_record(raw: Variant, level_id: String) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY: return Intent.bad("CAMPAIGN_PRIOR_RECORD_TYPE")
	var record: Dictionary = _empty()
	for key in ["cleared", "story_complete"]:
		if raw.has(key):
			if typeof(raw[key]) != TYPE_BOOL: return Intent.bad("CAMPAIGN_PRIOR_RECORD_TYPES")
			record[key] = raw[key]
	for key in ["best_done", "story_total", "contract_version"]:
		if raw.has(key):
			if not Intent.integer(raw[key], 0 if key != "contract_version" else 1, 100000):
				return Intent.bad("CAMPAIGN_PRIOR_RECORD_TYPES")
			record[key] = int(raw[key])
	if not raw.has("story_total") and raw.has("best_total"):
		if not Intent.integer(raw.best_total, 0, 100000): return Intent.bad("CAMPAIGN_PRIOR_RECORD_TYPES")
		record.story_total = int(raw.best_total)
	if record.story_total < record.best_done: return Intent.bad("CAMPAIGN_PRIOR_RECORD_COUNTS")
	var ids: Variant = raw.get("best_goal_ids", [])
	if typeof(ids) not in [TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY]: return Intent.bad("CAMPAIGN_PRIOR_RECORD_IDS")
	var seen: Dictionary = {}
	for item in ids:
		if typeof(item) != TYPE_STRING or item not in Intent.CONTRACTS[level_id].ids or seen.has(item):
			return Intent.bad("CAMPAIGN_PRIOR_RECORD_IDS")
		seen[item] = true
		record.best_goal_ids.append(item)
	if record.best_goal_ids.size() != record.best_done: return Intent.bad("CAMPAIGN_PRIOR_RECORD_COUNTS")
	if record.story_complete and (not record.cleared or record.story_total == 0 or record.best_done != record.story_total):
		return Intent.bad("CAMPAIGN_PRIOR_RECORD_OUTCOME")
	return {"ok":true, "record":record}

static func project(raw_intent: Variant, expected_token: String, expected: Dictionary, cfg: ConfigFile) -> Dictionary:
	if not Intent.fields(expected, ["ok", "context", "profile_id", "scope"]) \
		or typeof(expected.ok) != TYPE_BOOL or not expected.ok or typeof(expected.context) != TYPE_DICTIONARY \
		or typeof(expected.profile_id) != TYPE_STRING \
		or not Intent.fields(expected.scope, ["owner", "content_version", "engine_sha256"]):
		return Intent.bad("CAMPAIGN_PROJECTION_TRUSTED_SCOPE_REQUIRED")
	for key in expected.scope:
		if typeof(expected.scope[key]) != TYPE_STRING: return Intent.bad("CAMPAIGN_PROJECTION_SCOPE_TYPES")
	var normalized: Dictionary = Intent.Profiles.normalize_context(expected.context)
	if not normalized.ok or normalized.context != expected.context or normalized.profile_id != expected.profile_id \
		or not Intent.valid_owner(expected.scope.owner) or expected.scope.content_version.is_empty() \
		or expected.scope.content_version.length() > 256 or not Intent.hex(expected.scope.engine_sha256, 64) or cfg == null:
		return Intent.bad("CAMPAIGN_PROJECTION_TRUSTED_SCOPE_REQUIRED")
	var checked: Dictionary = Intent.validate(raw_intent, expected_token, expected)
	if not checked.ok: return checked
	var intent: Dictionary = checked.intent
	if not intent.victory: return {"ok":true, "progress_required":false, "new_story_seal":false}
	var owner: Variant = cfg.get_value("progress", "owner", "")
	var unlocked: Variant = cfg.get_value("progress", "unlocked", 1)
	var records: Variant = cfg.get_value("progress", "records", {})
	if typeof(owner) != TYPE_STRING or owner != intent.owner: return Intent.bad("CAMPAIGN_PROJECTION_OWNER_CHANGED")
	if not Intent.integer(unlocked, 1, 9) or typeof(records) != TYPE_DICTIONARY:
		return Intent.bad("CAMPAIGN_PROJECTION_PRIOR_TYPES")
	var previous: Dictionary = _prior_record(records.get(intent.context.level_id, {}), intent.context.level_id)
	if not previous.ok: return previous
	var old: Dictionary = previous.record
	var record: Dictionary = records.get(intent.context.level_id, {}).duplicate(true)
	# Retain future data keys inside the affected record as well as other records.
	record.merge(old, true)
	var result: Dictionary = intent.result
	record.cleared = true
	record.story_complete = old.story_complete or result.story_complete
	record.contract_version = maxi(int(old.contract_version), int(result.contract_version))
	# Original best-single-run rule: never union IDs from different victories.
	if result.story_done > old.best_done or (old.story_total == 0 and result.story_total > 0) \
		or (result.story_complete and not old.story_complete):
		record.best_done = result.story_done
		record.story_total = result.story_total
		record.best_goal_ids = result.done_ids.duplicate()
	var candidate_records: Dictionary = records.duplicate(true)
	candidate_records[intent.context.level_id] = record
	var required_unlock := 1
	for index in range(Intent.Profiles.CampaignScript.LEVELS.size()):
		if Intent.Profiles.CampaignScript.LEVELS[index].id == intent.context.level_id: required_unlock = index + 2
	var candidate_unlock: int = maxi(int(unlocked), required_unlock)
	# Only these progress keys change. Existing prefs/unknown sections/keys and
	# unrelated raw records remain in the original owned, independently loaded CFG.
	cfg.set_value("progress", "schema", 2)
	cfg.set_value("progress", "owner", intent.owner)
	cfg.set_value("progress", "unlocked", candidate_unlock)
	cfg.set_value("progress", "records", candidate_records)
	return {"ok":true, "progress_required":true, "new_story_seal":result.story_complete and not old.story_complete,
		"records":candidate_records, "unlocked":candidate_unlock, "record":record,
		"frozen_intent_sha256":JSON.stringify(intent).sha256_text()}
