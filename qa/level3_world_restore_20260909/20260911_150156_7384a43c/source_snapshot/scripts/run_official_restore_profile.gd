extends RefCounted
## Fixed installed adapters only. Selection does not activate a world.
## The host supplies the installed identity; a slot supplies only scalar context.
const CampaignScript := preload("res://scripts/campaign.gd")
const Policy := preload("res://scripts/steam_run_policy.gd")
const Classic := preload("res://scripts/levels/skirmish.gd")
const Zhu := preload("res://scripts/levels/level3_zhujiazhuang_rts.gd")
const Huang := preload("res://scripts/levels/level1_huangnigang_short.gd")
const SCHEMA := "official_restore_profile_v1"
const CLASSIC_ID := "classic_30_v1"
const ZHU_ID := "campaign_level3_v1"
const HG_ID := "campaign_level1_v1"
const CLASSIC_CONTEXT := {"mode": "defense", "level_id": "", "waves": 30}
const ZHU_CONTEXT := {"mode": "campaign", "level_id": "level3", "waves": 0}
const HG_CONTEXT := {"mode": "campaign", "level_id": "level1", "waves": 0}
const CLASSIC_FLAGS := {"skirmish": true, "skirmish_ai": false, "arena": false,
	"custom_defense": false, "scenario": false, "defense_waves": 30, "defense_random": false}
const ZHU_FLAGS := {"current": 2, "skirmish": false, "skirmish_ai": false,
	"arena": false, "custom_defense": false, "scenario": false}
const HG_FLAGS := {"current": 0, "skirmish": false, "skirmish_ai": false,
	"arena": false, "custom_defense": false, "scenario": false}

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "complete_world": false, "player_entry_enabled": false}

static func _sha(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 64: return false
	for character: String in value:
		if not (character >= "0" and character <= "9") and not (character >= "a" and character <= "f"): return false
	return true

static func trusted_identity(identity: Dictionary) -> bool:
	# These values must originate in RunContentIdentity, never decoded slot data.
	return typeof(identity.get("ok")) == TYPE_BOOL and identity.ok \
		and typeof(identity.get("save_eligible")) == TYPE_BOOL and identity.save_eligible \
		and typeof(identity.get("content_version")) == TYPE_STRING \
		and not identity.content_version.is_empty() and identity.content_version.length() <= 256 \
		and _sha(identity.get("engine_binary_sha256"))

static func normalize_context(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or value.size() != 3 or not value.has_all(["mode", "level_id", "waves"]): return _bad("OFFICIAL_CONTEXT_FIELDS")
	if typeof(value.mode) != TYPE_STRING or typeof(value.level_id) != TYPE_STRING or typeof(value.waves) not in [TYPE_INT, TYPE_FLOAT]: return _bad("OFFICIAL_CONTEXT_TYPES")
	if value.mode == "defense" and value.level_id == "" and value.waves == 30:
		return {"ok": true, "context": CLASSIC_CONTEXT.duplicate(), "profile_id": CLASSIC_ID}
	if value.mode == "campaign" and value.level_id == "level3" and value.waves == 0:
		return {"ok": true, "context": ZHU_CONTEXT.duplicate(), "profile_id": ZHU_ID}
	if value.mode == "campaign" and value.level_id == "level1" and value.waves == 0:
		return {"ok": true, "context": HG_CONTEXT.duplicate(), "profile_id": HG_ID}
	return _bad("OFFICIAL_CONTEXT_NOT_SUPPORTED")

static func _installed(profile_id: String) -> bool:
	match profile_id:
		CLASSIC_ID:
			return CampaignScript.SKIRMISH_SCRIPT == Classic.resource_path
		ZHU_ID:
			return CampaignScript.LEVELS.size() > 2 \
				and CampaignScript.LEVELS[2].id == "level3" \
				and CampaignScript.LEVELS[2].script == Zhu.resource_path
		HG_ID:
			return CampaignScript.LEVELS.size() > 0 \
				and CampaignScript.LEVELS[0].id == "level1" \
				and CampaignScript.LEVELS[0].script == Huang.resource_path
	return false

static func select_context(context: Variant, identity: Dictionary) -> Dictionary:
	if not trusted_identity(identity): return _bad("INSTALLED_IDENTITY_REQUIRED")
	var normalized: Dictionary = normalize_context(context)
	if not normalized.ok: return normalized
	if not _installed(normalized.profile_id): return _bad("INSTALLED_OFFICIAL_CATALOG_MISMATCH")
	return {"ok": true, "schema": SCHEMA, "profile_id": normalized.profile_id,
		"context": normalized.context, "content_version": identity.content_version,
		"engine_sha256": identity.engine_binary_sha256,
		"complete_world": false, "player_entry_enabled": false,
		"scope": "selection_only_no_world_or_steam_authorization"}

static func select_saved(context: Variant, content_version: Variant,
		engine_sha256: Variant, identity: Dictionary) -> Dictionary:
	if not trusted_identity(identity): return _bad("INSTALLED_IDENTITY_REQUIRED")
	if typeof(content_version) != TYPE_STRING or content_version != identity.content_version \
		or typeof(engine_sha256) != TYPE_STRING or engine_sha256 != identity.engine_binary_sha256:
		return _bad("INSTALLED_CONTENT_IDENTITY_MISMATCH")
	return select_context(context, identity)

static func capture_selection(campaign: Node, level: RefCounted, identity: Dictionary) -> Dictionary:
	if not is_instance_valid(campaign) or campaign.get_script() != CampaignScript or not is_instance_valid(level): return _bad("OFFICIAL_SOURCE_REQUIRED")
	if level.get_script() not in [Classic, Zhu, Huang]: return _bad("OFFICIAL_SCRIPT_IDENTITY")
	var selected: Dictionary = select_context(Policy.classify(campaign, level), identity)
	if not selected.ok: return selected
	var expected: Script = level_script(selected.profile_id)
	if expected == null or level.get_script() != expected: return _bad("OFFICIAL_SCRIPT_IDENTITY")
	return selected

static func install_flags(profile_id: String) -> Dictionary:
	# Internal return value, never read from a file or applied by this selector.
	# Session must snapshot/revalidate/rollback every returned Campaign field.
	match profile_id:
		CLASSIC_ID: return {"ok": true, "flags": CLASSIC_FLAGS.duplicate()}
		ZHU_ID: return {"ok": true, "flags": ZHU_FLAGS.duplicate()}
		HG_ID: return {"ok": true, "flags": HG_FLAGS.duplicate()}
	return _bad("OFFICIAL_PROFILE_UNKNOWN")

static func level_script(profile_id: String) -> Script:
	# Call only with a profile selected above; no ResourceLoader/load/fallback.
	match profile_id:
		CLASSIC_ID: return Classic
		ZHU_ID: return Zhu
		HG_ID: return Huang
	return null

static func is_official_campaign_profile(profile_id: String) -> bool:
	return profile_id == ZHU_ID or profile_id == HG_ID

static func is_official_campaign_context(context: Variant) -> bool:
	var norm := normalize_context(context)
	return norm.ok and is_official_campaign_profile(norm.profile_id)
