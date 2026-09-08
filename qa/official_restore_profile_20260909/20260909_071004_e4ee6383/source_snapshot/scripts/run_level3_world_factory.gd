extends RefCounted
## Pure Level/runtime components for the installed official chapter; no deployment.
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Zhu := preload("res://scripts/levels/level3_zhujiazhuang_rts.gd")
const LevelState := preload("res://scripts/run_campaign_level_state.gd")
const DefinitionSource := preload("res://scripts/defs.gd")
const VisualRules := preload("res://scripts/ability_visuals.gd")
const Environment := preload("res://scripts/campaign_environment.gd")

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "complete_world": false}

static func _context(identity: Dictionary) -> Dictionary:
	var selected: Dictionary = Profiles.select_context(Profiles.ZHU_CONTEXT, identity)
	if not selected.ok: return selected
	if not Environment.enabled("level3"): return _bad("LEVEL3_CAMPAIGN_ENVIRONMENT_REQUIRED")
	return selected

static func prepare_runtime(identity: Dictionary) -> Dictionary:
	var selected: Dictionary = _context(identity)
	if not selected.ok: return selected
	var audit: Dictionary = LevelState.new().audit_declarations("level3")
	if not audit.ok: return audit
	# Exact normal-launch content order. Only private dictionaries are written.
	# Level3.apply_overrides does not inspect its instance state or call gameplay.
	var level: Variant = Zhu.new()
	var defs: Dictionary = DefinitionSource.UNITS.duplicate(true)
	var abilities: Dictionary = DefinitionSource.ABILITIES.duplicate(true)
	DefinitionSource.apply_content_pack(defs, abilities)
	level.apply_overrides(defs, abilities)
	VisualRules.apply(defs, abilities)
	return {"ok": true, "runtime": {"defs": defs, "abilities": abilities,
		"items": DefinitionSource.ITEMS.duplicate(true)},
		"environment_buildings": Environment.buildings("level3").duplicate(true),
		"profile": selected, "complete_world": false,
		"global_art_changed": false, "deploy_or_start_called": false}

static func restore_level(record: Variant, identity: Dictionary, id_to_unit: Dictionary,
		next_entity_id: int, mission_token: String) -> Dictionary:
	var selected: Dictionary = _context(identity)
	if not selected.ok: return selected
	# Level3 has zero external/UI declarations. Its eight named Unit references
	# and seven Unit arrays use the already-created, gated shared registry.
	# LevelState.restore checks exact installed script/declarations/record/refs,
	# creates Zhu.new(), and assigns audited fields. No callbacks are replayed.
	var restored: Dictionary = LevelState.new().restore(record, "level3",
		identity.content_version, id_to_unit, next_entity_id, {}, mission_token)
	if not restored.ok: return restored
	if restored.level.get_script() != Zhu: return _bad("LEVEL3_FACTORY_IDENTITY")
	return {"ok": true, "level": restored.level, "profile": selected,
		"complete_world": false, "deploy_or_start_called": false,
		"next_owner_steps": ["battle.configure_restored_gameplay_rng",
			"prepare_hud_shell_and_fx_partition", "presentation_prepare_including_mission",
			"cross_component_validation", "paused_layout", "final_clock_arm"]}
