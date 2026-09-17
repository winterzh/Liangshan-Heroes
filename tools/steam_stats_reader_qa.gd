extends SceneTree
const Reader = preload("res://scripts/steam_stats_reader.gd")
var checks := []
const OWNER := "76561198000000001"
func check(label: String, passed: bool) -> void:
	checks.append({"label": label, "passed": passed})
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	check("native class registered", ClassDB.class_exists("SteamStatsReader"))
	if not ClassDB.class_exists("SteamStatsReader"):
		finish(); return
	var reader := Reader.new()
	if OS.get_environment("LSH_READER_ABSENT") == "1":
		check("absent Steam fails without initialization", reader.attach(OWNER).code == "STEAM_NOT_INITIALIZED")
		finish(); return
	check("attach real compiled bridge to synthetic ABI", reader.attach(OWNER).ok)
	var snapshot := reader.current_snapshot()
	check("all four current stats read", snapshot.ok and snapshot.stats.size() == 4 and snapshot.stats.TOTAL_KILLS == 0)
	check("all achievements read including false", snapshot.ok and snapshot.unlocked.size() == 30 and not snapshot.unlocked.ACH_WINS_10)
	check("cache is explicitly not a request receipt", snapshot.source == "current_cache" and snapshot.handle.is_empty())
	OS.set_environment("LSH_MOCK_GET_FAIL", "1")
	check("failure not converted into zero", reader.current_snapshot().code == "GETTER_FAILED")
	OS.set_environment("LSH_MOCK_GET_FAIL", "0")
	OS.set_environment("LSH_MOCK_VALUE", "-1")
	check("negative counter fails whole snapshot", reader.current_snapshot().code == "BAD_STAT")
	OS.set_environment("LSH_MOCK_VALUE", "2147483647")
	check("int32 max preserved", reader.current_snapshot().stats.TOTAL_KILLS == 2147483647)
	var started := reader.request()
	check("uint64 handle kept as exact hex string", started.ok and started.handle == "f123456789abcdef")
	check("second request rejected while pending", reader.request().code == "READ_BUSY")
	check("wrong handle cannot consume result", reader.poll("f123456789abcdee").code == "UNKNOWN_HANDLE")
	check("pending returns no snapshot", reader.poll(started.handle).pending)
	OS.set_environment("LSH_MOCK_DONE", "1")
	var received := reader.poll(started.handle)
	check("correct ABI call result size and callback ID", received.ok)
	check("all user getters preserve handle owner and source", received.ok and received.handle == started.handle and received.owner == OWNER and received.source == "requested_user_cache")
	check("complete requested snapshot", received.ok and received.stats.size() == 4 and received.unlocked.size() == 30)
	check("duplicate result cannot be consumed", reader.poll(started.handle).code == "UNKNOWN_HANDLE")
	var second := reader.request()
	check("continuous reads in same process", second.ok and second.handle == "f123456789abcdf0")
	check("old call cannot finish new request", reader.poll(started.handle).code == "UNKNOWN_HANDLE")
	check("second read completes", reader.poll(second.handle).ok)
	var third := reader.request()
	OS.set_environment("LSH_MOCK_RESULT", "8")
	check("result 8 returns no trusted snapshot", reader.poll(third.handle).code == "READ_RESULT_FAILED")
	OS.set_environment("LSH_MOCK_RESULT", "1")
	var fourth := reader.request()
	OS.set_environment("LSH_MOCK_GET_FAIL", "1")
	check("completed request with bad getter rejects whole snapshot", reader.poll(fourth.handle).code == "GETTER_FAILED")
	OS.set_environment("LSH_MOCK_GET_FAIL", "0")
	OS.set_environment("LSH_MOCK_OWNER_OFFSET", "1")
	check("account switch closes native reader", reader.current_snapshot().code == "ACCOUNT_CHANGED")
	OS.set_environment("LSH_MOCK_OWNER_OFFSET", "0")
	check("switch back does not resurrect old reader", reader.current_snapshot().code == "READER_CLOSED")
	finish()
func finish() -> void:
	var passed := true
	for row in checks: passed = passed and row.passed
	var report := {"passed": passed, "checks": checks}
	var file := FileAccess.open("res://report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ")); file.close()
	print("STEAM_READER_QA ", JSON.stringify(report))
	quit(0 if passed else 1)
