extends SceneTree
## Authorized read-only live probe. Does not load SteamService or a battle.
const Reader = preload("res://scripts/steam_stats_reader.gd")
var api: Object
var report := {"complete": false, "write_calls": 0, "reads": [], "write_acknowledgement_proven": false}
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if not Engine.has_singleton("Steam"):
		finish("STEAM_EXTENSION_MISSING"); return
	api = Engine.get_singleton("Steam")
	var initialized: Dictionary = api.call("steamInitEx", 5088120, false)
	if int(initialized.get("status", -1)) != 0:
		finish("STEAM_INIT_FAILED"); return
	if int(api.call("getAppID")) != 5088120:
		finish("APP_MISMATCH"); return
	var reader := Reader.new()
	var owner := str(api.call("getSteamID"))
	var attached: Dictionary = reader.attach(owner)
	if not attached.ok:
		finish(String(attached.code)); return
	var initial := reader.current_snapshot()
	report.current_read_ok = initial.ok
	if not initial.ok:
		finish(String(initial.code)); return
	var last := initial
	for iteration in range(2):
		var start := reader.request()
		if not start.ok:
			finish(String(start.code)); return
		var began := Time.get_ticks_msec()
		var received := {}
		while Time.get_ticks_msec() - began < 30000:
			api.call("run_callbacks")
			received = reader.poll(start.handle)
			if not received.ok or not received.get("pending", false): break
			await create_timer(0.1).timeout
		if not received.ok:
			finish(String(received.get("code", "READ_FAILED"))); return
		if received.get("pending", false):
			finish("READ_TIMEOUT"); return
		report.reads.append({"iteration": iteration + 1, "elapsed_ms": Time.get_ticks_msec() - began,
			"stats_count": received.stats.size(), "achievements_count": received.unlocked.size(),
			"same_owner": received.owner == owner, "same_as_previous": received.stats == last.stats and received.unlocked == last.unlocked,
			"source": received.source, "full_handle": start.handle.length() == 16})
		last = received
		await create_timer(1.0).timeout
	report.complete = true
	finish("READ_ONLY_PASS")
func finish(code: String) -> void:
	report.code = code
	# No Steam IDs, raw counters, achievements or handles enter the public report.
	var file := FileAccess.open("res://read_report.json", FileAccess.WRITE)
	if file == null:
		if api != null: api.call("steamShutdown")
		printerr("STEAM_LIVE_READ REPORT_WRITE_FAILED")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  ")); file.close()
	if api != null: api.call("steamShutdown")
	print("STEAM_LIVE_READ ", JSON.stringify(report))
	quit(0 if report.complete else 1)
