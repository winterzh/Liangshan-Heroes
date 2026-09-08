class_name SteamRunPolicy
extends RefCounted
## Trust launch flags AND the exact production script, never a content-supplied id.

static func classify(campaign: Node, level: RefCounted) -> Dictionary:
	var out := {"mode":"custom", "level_id":"", "waves":0}
	if level == null or campaign.scenario or campaign.custom_defense or campaign.arena:
		return out
	var path: String = level.get_script().resource_path
	if campaign.skirmish_ai and path == campaign.SKIRMISH_AI_SCRIPT:
		out.mode = "ai"
	elif campaign.skirmish and not campaign.skirmish_ai and path == campaign.SKIRMISH_SCRIPT:
		if not campaign.defense_random and campaign.defense_waves in [20, 30, 60]:
			out.mode = "defense"
			out.waves = campaign.defense_waves
	elif not campaign.skirmish and not campaign.skirmish_ai and campaign.current >= 0 and campaign.current < campaign.LEVELS.size():
		var expected: Dictionary = campaign.LEVELS[campaign.current]
		if path == expected.script and level.id() == expected.id:
			out.mode = "campaign"
			out.level_id = expected.id
	return out

static func test_environment() -> bool:
	if OS.has_feature("editor") or DisplayServer.get_name() == "headless":
		return true
	for key in ["LEVEL", "SCENARIO", "CUSTOM_DEFENSE", "STEAM_DISABLED", "SKIRMISH", "SKIRMISH_AI", "ARENA", "AUTO_MICRO", "AUTOMICRO", "NEWHERO", "SMOKE_TEST", "CAMPAIGN_QA", "ABILITY_VIS_AUDIT"]:
		if not OS.get_environment(key).is_empty():
			return true
	if "--script" in OS.get_cmdline_args() or "-s" in OS.get_cmdline_args():
		return true
	return false
