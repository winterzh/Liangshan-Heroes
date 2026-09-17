extends RefCounted
## Installed Jiangzhou definitions and inert level only; never deploys or starts.
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Jiang := preload("res://scripts/levels/level2_jiangzhou_rts.gd")
const LevelState := preload("res://scripts/run_campaign_level_state.gd")
const DefinitionSource := preload("res://scripts/defs.gd")
const VisualRules := preload("res://scripts/ability_visuals.gd")
const CampaignEnvironment := preload("res://scripts/campaign_environment.gd")

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "complete_world": false}

static func _context(identity: Dictionary) -> Dictionary:
	var selected: Dictionary = Profiles.select_context(Profiles.JIANG_CONTEXT, identity)
	if not selected.ok: return selected
	if not CampaignEnvironment.enabled("level2"): return _bad("LEVEL2_CAMPAIGN_ENVIRONMENT_REQUIRED")
	return selected

static func prepare_runtime(identity: Dictionary) -> Dictionary:
	var selected: Dictionary = _context(identity)
	if not selected.ok: return selected
	var audit: Dictionary = LevelState.new().audit_declarations("level2")
	if not audit.ok: return audit
	var level: Variant = Jiang.new()
	var defs: Dictionary = DefinitionSource.UNITS.duplicate(true)
	var abilities: Dictionary = DefinitionSource.ABILITIES.duplicate(true)
	DefinitionSource.apply_content_pack(defs, abilities)
	level.apply_overrides(defs, abilities)
	VisualRules.apply(defs, abilities)
	return {"ok": true, "runtime": {"defs": defs, "abilities": abilities,
		"items": DefinitionSource.ITEMS.duplicate(true)},
		"environment_buildings": CampaignEnvironment.buildings("level2").duplicate(true),
		"profile": selected, "complete_world": false,
		"global_art_changed": false, "deploy_or_start_called": false}

static func restore_level(record: Variant, identity: Dictionary, id_to_unit: Dictionary,
		next_entity_id: int, mission_token: String, token_to_external: Dictionary = {}) -> Dictionary:
	var selected: Dictionary = _context(identity)
	if not selected.ok: return selected
	var restored: Dictionary = LevelState.new().restore(record, "level2",
		identity.content_version, id_to_unit, next_entity_id, token_to_external, mission_token)
	if not restored.ok: return restored
	if restored.level.get_script() != Jiang: return _bad("LEVEL2_FACTORY_IDENTITY")
	return {"ok": true, "level": restored.level, "profile": selected,
		"complete_world": false, "deploy_or_start_called": false}
