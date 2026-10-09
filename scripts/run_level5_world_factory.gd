extends RefCounted
## Pure Level/runtime components for the installed official chapter; no deployment.
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Gao := preload("res://scripts/levels/level5_gao_rts.gd")
const LevelState := preload("res://scripts/run_campaign_level_state.gd")
const DefinitionSource := preload("res://scripts/defs.gd")
const VisualRules := preload("res://scripts/ability_visuals.gd")
const CampaignEnvironment := preload("res://scripts/campaign_environment.gd")

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "complete_world": false}

static func _context(identity: Dictionary) -> Dictionary:
	var selected: Dictionary = Profiles.select_context(Profiles.GAO_CONTEXT, identity)
	if not selected.ok: return selected
	# Gao uses the native Liangshan environment; CampaignEnvironment excludes level5.
	# Its normal-launch scoped environment_buildings remains empty.
	return selected

static func prepare_runtime(identity: Dictionary) -> Dictionary:
	var selected: Dictionary = _context(identity)
	if not selected.ok: return selected
	var audit: Dictionary = LevelState.new().audit_declarations("level5")
	if not audit.ok: return audit
	# Exact normal-launch content order. Only private dictionaries are written.
	# Level5.apply_overrides does not inspect its instance state or call gameplay.
	var level: Variant = Gao.new()
	var defs: Dictionary = DefinitionSource.UNITS.duplicate(true)
	var abilities: Dictionary = DefinitionSource.ABILITIES.duplicate(true)
	DefinitionSource.apply_content_pack(defs, abilities)
	level.apply_overrides(defs, abilities)
	VisualRules.apply(defs, abilities)
	return {"ok": true, "runtime": {"defs": defs, "abilities": abilities,
		"items": DefinitionSource.ITEMS.duplicate(true)},
		"environment_buildings": CampaignEnvironment.buildings("level5").duplicate(true),
		"profile": selected, "complete_world": false,
		"global_art_changed": false, "deploy_or_start_called": false}

static func restore_level(record: Variant, identity: Dictionary, id_to_unit: Dictionary,
		next_entity_id: int, mission_token: String, token_to_external: Dictionary = {}) -> Dictionary:
	var selected: Dictionary = _context(identity)
	if not selected.ok: return selected
	# The Mission-owned gao_end button must already be recreated and gated.
	# Unit and external nodes are supplied by the validated private world owner.
	# LevelState.restore checks exact installed script/declarations/record/refs,
	# creates Gao.new(), and assigns audited fields. No callbacks are replayed.
	var restored: Dictionary = LevelState.new().restore(record, "level5",
		identity.content_version, id_to_unit, next_entity_id, token_to_external, mission_token)
	if not restored.ok: return restored
	if restored.level.get_script() != Gao: return _bad("LEVEL5_FACTORY_IDENTITY")
	return {"ok": true, "level": restored.level, "profile": selected,
		"complete_world": false, "deploy_or_start_called": false,
		"next_owner_steps": ["battle.configure_restored_gameplay_rng",
			"prepare_hud_shell_and_fx_partition", "presentation_prepare_including_mission",
			"cross_component_validation", "paused_layout", "final_clock_arm"]}
