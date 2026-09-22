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
var rich_presence := {}
var cloud_files := {}
var file_write_ok := true
var file_read_ok := true
var cloud_enabled_account := true
var cloud_enabled_app := true
var file_writes := 0
var file_reads := 0
var file_size_reads := 0
var file_exists_reads := 0
var cloud_account_checks := 0
var cloud_app_checks := 0
var read_sizes: Array[int] = []
var file_read_ret_override := -1
var short_read_by := 0
var rich_presence_writes := 0
var rich_presence_clears := 0
var presence_writes := 0
var presence_clears := 0
var presence_write_ok := true
var presence_fail_key := ""
func setRichPresence(key: String, value: String) -> bool:
	rich_presence_writes += 1
	presence_writes += 1
	if not presence_write_ok or key == presence_fail_key: return false
	rich_presence[key] = value
	return true
func clearRichPresence() -> void:
	rich_presence_clears += 1
	presence_clears += 1
	rich_presence.clear()
func isCloudEnabledForAccount() -> bool:
	cloud_account_checks += 1
	return cloud_enabled_account
func isCloudEnabledForApp() -> bool:
	cloud_app_checks += 1
	return cloud_enabled_app
func fileExists(name: String) -> bool:
	file_exists_reads += 1
	return cloud_files.has(name)
func getFileSize(name: String) -> int:
	file_size_reads += 1
	return cloud_files[name].size() if cloud_files.has(name) else 0
func fileWrite(name: String, data: PackedByteArray) -> bool:
	file_writes += 1
	if not file_write_ok: return false
	cloud_files[name] = data.duplicate()
	return true
func fileRead(name: String, size: int) -> Dictionary:
	# GodotSteam 4.22.1: caller supplies the requested byte count; ret is the
	# number of bytes read and buf is PackedByteArray, not bool/content.
	file_reads += 1
	read_sizes.append(size)
	var result := PackedByteArray()
	result.resize(maxi(0, size))
	if not file_read_ok or not cloud_files.has(name):
		return {"ret": 0, "buf": result}
	var bytes: PackedByteArray = cloud_files[name]
	var returned := maxi(0, mini(size, bytes.size()) - short_read_by)
	for index in range(returned): result[index] = bytes[index]
	return {"ret": file_read_ret_override if file_read_ret_override >= 0 else returned, "buf": result}
func fileDelete(name: String) -> bool:
	cloud_files.erase(name)
	return true
func filePersisted(name: String) -> bool:
	return cloud_files.has(name)
func getQuota() -> Dictionary:
	return {"ret": true, "total": 104857600, "available": 104857600}
