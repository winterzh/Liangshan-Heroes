class_name SteamAchievementState
extends RefCounted
## Pure state reducer. Backend acknowledgements and persistence live in SteamService.

var stats: Dictionary = {}
var unlocked: Dictionary = {}
var settled: Dictionary = {}

func seed(initial_stats: Dictionary, initial_unlocked: Dictionary) -> void:
	stats = initial_stats.duplicate(true)
	unlocked = initial_unlocked.duplicate(true)
	settled.clear()

func add_kill() -> void:
	stats.TOTAL_KILLS = mini(2147483647, int(stats.get("TOTAL_KILLS", 0)) + 1)
	evaluate()

func settle(run_id: int, context: Dictionary, victory: bool, result: Dictionary) -> bool:
	if settled.has(run_id) or context.get("mode", "custom") == "custom":
		return false
	settled[run_id] = true
	if not victory:
		return true
	stats.TOTAL_WINS = mini(2147483647, int(stats.get("TOTAL_WINS", 0)) + 1)
	match context.mode:
		"campaign":
			var index := String(context.level_id).trim_prefix("level")
			unlocked["ACH_CLEAR_LEVEL_" + index] = true
			if bool(result.get("story_complete", false)) and int(result.get("story_total", 0)) > 0 and int(result.get("story_done", 0)) == int(result.get("story_total", 0)):
				unlocked["ACH_STORY_LEVEL_" + index] = true
		"defense":
			stats.DEFENSE_WINS = mini(2147483647, int(stats.get("DEFENSE_WINS", 0)) + 1)
			if int(context.waves) in [30, 60]:
				unlocked["ACH_DEFENSE_%d" % int(context.waves)] = true
		"ai":
			stats.AI_WINS = mini(2147483647, int(stats.get("AI_WINS", 0)) + 1)
	evaluate()
	return true

func evaluate() -> void:
	for e in SteamAchievementCatalog.entries():
		if e.stat != "" and int(stats.get(e.stat, 0)) >= int(e.target):
			unlocked[e.id] = true
	for id in SteamAchievementCatalog.aggregate_ids(unlocked):
		unlocked[id] = true
