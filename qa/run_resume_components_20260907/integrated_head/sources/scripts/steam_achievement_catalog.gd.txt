class_name SteamAchievementCatalog
extends RefCounted
## The only source of truth for game UI and the Steamworks setup export.

const APP_ID := 5088120
const STATS := ["TOTAL_WINS", "TOTAL_KILLS", "DEFENSE_WINS", "AI_WINS"]
const TITLES := ["智取生辰纲", "江州劫法场", "三打祝家庄", "大破连环马", "三败高太尉", "大闹野猪林", "醉打蒋门神", "智取大名府"]
const ENGLISH := ["The Birthday Tribute", "Rescue at Jiangzhou", "Zhu Family Manor", "The Linked Cavalry", "Defeat Gao Qiu", "Wild Boar Forest", "Defeat Jiang the Door God", "Capture Daming"]

static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(8):
		out.append(_entry("ACH_CLEAR_LEVEL_%d" % (i + 1), TITLES[i], "通关「%s」。" % TITLES[i], ENGLISH[i], "Complete %s." % ENGLISH[i]))
		out.append(_entry("ACH_STORY_LEVEL_%d" % (i + 1), "演义印 · " + TITLES[i], "在同一局中完成「%s」全部原著目标并获胜。" % TITLES[i], "Story Seal: " + ENGLISH[i], "Win %s with every story objective completed in the same run." % ENGLISH[i]))
	out.append(_entry("ACH_ALL_CLEAR", "八幕功成", "通关全部八幕官方战役。", "Eight Chapters Complete", "Complete all eight official campaign chapters."))
	out.append(_entry("ACH_ALL_STORY", "忠义全书", "集齐八幕原著印记。", "The Complete Chronicle", "Earn all eight story seals."))
	for n in [30, 60]:
		out.append(_entry("ACH_DEFENSE_%d" % n, "固守梁山 · %d波" % n, "完成官方据守 %d 波固定档位。" % n, "Hold Liangshan: %d Waves" % n, "Win the official fixed %d-wave defense preset." % n))
	for row in [["TOTAL_WINS", "WINS", [10, 50, 100], "百战建功", "官方对局累计胜利", "Victories", "Win official matches"], ["TOTAL_KILLS", "KILLS", [1000, 10000, 100000], "替天行道", "官方玩法累计歼敌", "Enemies Defeated", "Defeat enemies in official modes"], ["DEFENSE_WINS", "DEFENSE_WINS", [10, 50], "水泊坚壁", "官方固定据守累计胜利", "Defense Victories", "Win official fixed defense matches"], ["AI_WINS", "AI_WINS", [1, 10], "运筹帷幄", "官方 AI 对战累计胜利", "AI Victories", "Win official AI matches"]]:
		for n in row[2]:
			var e := _entry("ACH_%s_%d" % [row[1], n], "%s · %d" % [row[3], n], "%s %d。" % [row[4], n], "%s: %d" % [row[5], n], "%s: %d." % [row[6], n])
			e.stat = row[0]
			e.target = n
			out.append(e)
	return out

static func _entry(id: String, title: String, description: String, en: String, en_description: String) -> Dictionary:
	return {"id":id, "title":title, "description":description, "title_en":en, "description_en":en_description, "stat":"", "target":1, "icon":"res://assets/ui/achievements/%s.png" % id.to_lower(), "locked_icon":"res://assets/ui/achievements/%s_locked.png" % id.to_lower()}

static func aggregate_ids(unlocked: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for kind in ["CLEAR", "STORY"]:
		var complete := true
		for i in range(1, 9):
			complete = complete and bool(unlocked.get("ACH_%s_LEVEL_%d" % [kind, i], false))
		if complete:
			result.append("ACH_ALL_" + kind)
	return result

static func verified_legacy_ids(raw: Variant, contracts: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if not raw is Dictionary:
		return result
	for level_id in contracts:
		var record: Variant = raw.get(level_id)
		var contract: Dictionary = contracts[level_id]
		if not record is Dictionary or record.get("cleared") != true or record.get("story_complete") != true:
			continue
		if record.get("contract_version") != contract.version or record.get("story_total") != contract.ids.size() or record.get("best_done") != contract.ids.size():
			continue
		var ids: Variant = record.get("best_goal_ids")
		if not ids is Array or ids.size() != contract.ids.size() or ids.is_empty():
			continue
		var unique := {}
		for id in ids:
			if id is String and id in contract.ids:
				unique[id] = true
		if unique.size() == contract.ids.size():
			result.append("ACH_STORY_LEVEL_%s" % String(level_id).trim_prefix("level"))
			result.append("ACH_CLEAR_LEVEL_%s" % String(level_id).trim_prefix("level"))
	return result
