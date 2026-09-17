extends RefCounted
## Test-only adapter. No network, credentials, or Steam API calls.
signal user_stats_stored(game_id: int, result: int)
signal item_created(result: int, file_id: int, accept_tos: bool)
signal item_updated(result: int, accept_tos: bool, file_id: int)
signal item_installed(app_id: int, file_id: int)
signal item_downloaded(result: int, file_id: int, app_id: int)
var owner := 111
var stats := {"TOTAL_KILLS":0, "TOTAL_WINS":0, "DEFENSE_WINS":0, "AI_WINS":0}
var achievements := {}
var store_ok := true
var read_ok := true
var stat_writes := 0
var achievement_writes := 0
var stores := 0
var creates := 0
var submits := 0
var subscribed := []
var folder := ""
var flags := 5
var pages := []

func getSteamID() -> int: return owner
func run_callbacks() -> void: pass
func steamShutdown() -> void: pass
func getAchievement(id: String) -> Dictionary: return {"ret":true, "achieved":achievements.get(id, false)}
func getStatInt(id: String) -> int: return int(stats.get(id, 0))
func current_snapshot() -> Dictionary:
	if not read_ok: return {"ok": false, "code": "GETTER_FAILED"}
	var unlocked := {}
	for entry in SteamAchievementCatalog.entries(): unlocked[entry.id] = bool(achievements.get(entry.id, false))
	return {"ok": true, "owner": str(owner), "source": "current_cache", "stats": stats.duplicate(), "unlocked": unlocked}
func setStatInt(id: String, value: int) -> bool:
	stat_writes += 1
	if not stats.has(id): return false
	stats[id] = value
	return true
func setAchievement(id: String) -> bool:
	achievement_writes += 1
	achievements[id] = true
	return true
func storeStats() -> bool:
	stores += 1
	return store_ok
func getSubscribedItems() -> Array: return subscribed
func getItemState(_id: int) -> int: return flags
func getItemInstallInfo(_id: int) -> Dictionary: return {"ret":true,"folder":folder}
func downloadItem(_id: int, _priority: bool) -> bool: return true
func unsubscribeItem(id: int) -> void: subscribed.erase(id)
func createItem(_app: int, _kind: int) -> void: creates += 1
func startItemUpdate(_app: int, _id: int) -> int: return 42
func setItemTitle(_handle: int, _title: String) -> bool: return true
func setItemDescription(_handle: int, _text: String) -> bool: return true
func setItemVisibility(_handle: int, _visibility: int) -> bool: return true
func setItemContent(_handle: int, value: String) -> bool:
	folder = value
	return true
func setItemPreview(_handle: int, _path: String) -> bool: return true
func setItemTags(_handle: int, _tags: PackedStringArray) -> bool: return true
func submitItemUpdate(_handle: int, _notes: String) -> void: submits += 1
func getItemUpdateProgress(_handle: int) -> Dictionary: return {"status":3,"processed":1,"total":2}
func isOverlayEnabled() -> bool: return true
func activateGameOverlayToWebPage(url: String) -> void: pages.append(url)
