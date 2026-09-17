extends SceneTree
## Standalone isolated QA. Default: synthetic facade only. Native: mock ABI only.
const Observer = preload("res://scripts/steam_stats_observer.gd")
const OBSERVER := "76561198000000001"
const TARGET := "76561198000000002"
const FIRST := "f123456789abcdef"
var checks: Array[Dictionary] = []

class LegacyNative extends RefCounted:
	var calls := 0
	func query(_command: String) -> String:
		calls += 1
		return '{"ok":true,"owner":"76561198000000001"}'

class FakeNative extends RefCounted:
	var calls: Array[String] = []
	var ready := false
	var handle := "f123456789abcdef"
	var observer := "76561198000000001"
	var target := "76561198000000002"
	var getter_index := 0
	var fail_at := -1
	var corrupt_field := ""
	var corrupt_when := "any"
	var corrupt_value: Variant = null
	var stat_value: Variant = 0
	var achievement_value: Variant = false
	var native_error := ""
	var malformed := ""
	var second := false
	func envelope() -> Dictionary:
		return {"ok": true, "protocol": 1, "app": 5088120, "observer": observer, "target": target, "source": "independent_requested_user_cache"}
	func observer_query(command: String) -> Variant:
		calls.append(command)
		if malformed == "type": return 12
		if malformed == "json": return "not json"
		if malformed == "ok": return '{"ok":1}'
		if not native_error.is_empty(): return JSON.stringify({"ok": false, "code": native_error})
		var row := envelope()
		if command == "request":
			if second: handle = "f123456789abcdf0"
			second = true
			row.handle = handle
			row.timeout_ms = 30000
		elif command.begins_with("poll "):
			row.handle = handle
			row.pending = not ready
		elif command.begins_with("stat ") or command.begins_with("achievement "):
			getter_index += 1
			if getter_index == fail_at: return '{"ok":false,"code":"GETTER_FAILED"}'
			row.handle = handle
			row.value = stat_value if command.begins_with("stat ") else achievement_value
		var corrupt_this := corrupt_when == "any" or (corrupt_when == "poll" and command.begins_with("poll ")) or (corrupt_when == "getter" and (command.begins_with("stat ") or command.begins_with("achievement ")))
		if not corrupt_field.is_empty() and corrupt_this: row[corrupt_field] = corrupt_value
		return JSON.stringify(row)

func check(label: String, passed: bool) -> void:
	checks.append({"label": label, "passed": passed})

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("LSH_OBSERVER_NATIVE") == "1":
		run_native()
	else:
		run_facade()
	finish()

func attached(fake: FakeNative) -> Observer:
	var observer := Observer.new()
	check("attach separate synthetic observer and target", observer.attach(OBSERVER, TARGET, fake).ok)
	return observer

func started(fake: FakeNative) -> Observer:
	var observer: Observer = attached(fake)
	check("synthetic request accepted", observer.request().ok)
	fake.ready = true
	return observer

func run_facade() -> void:
	var legacy := LegacyNative.new()
	var unsupported := Observer.new()
	check("old native object returns explicit unsupported", unsupported.attach(OBSERVER, TARGET, legacy).code == "OBSERVER_UNSUPPORTED")
	check("old query never called as cache fallback", legacy.calls == 0)
	var invalid := Observer.new()
	var unused := FakeNative.new()
	check("self observation rejected", invalid.attach(OBSERVER, OBSERVER, unused).code == "TARGET_IS_OBSERVER")
	for value in ["", "0", "076561198000000002", "18446744073709551616", "76561198000000002 extra"]:
		check("bad target syntax rejected: " + value, invalid.attach(OBSERVER, value, unused).code == "BAD_IDENTITIES")
	check("invalid attachment never calls native", unused.calls.is_empty())
	for malformed in ["type", "json", "ok"]:
		var fake := FakeNative.new()
		fake.malformed = malformed
		var reader := Observer.new()
		check("malformed native attach is rejected: " + malformed, reader.attach(OBSERVER, TARGET, fake).code == "BAD_NATIVE_RESPONSE")
	var fake := FakeNative.new()
	var reader: Observer = attached(fake)
	var requested: Dictionary = reader.request()
	check("exact unsigned handle preserved", requested.ok and requested.handle == FIRST)
	check("only one read outstanding", reader.request().code == "READ_BUSY")
	var call_count := fake.calls.size()
	check("wrong handle cannot poll native", reader.poll("f123456789abcdee").code == "UNKNOWN_HANDLE" and fake.calls.size() == call_count)
	var pending: Dictionary = reader.poll(FIRST)
	check("pending exposes no snapshot", pending.ok and pending.pending and not pending.has("stats"))
	fake.ready = true
	var snapshot: Dictionary = reader.poll(FIRST)
	check("complete four stats and thirty achievements", snapshot.ok and snapshot.stats.size() == 4 and snapshot.unlocked.size() == 30)
	check("valid zero and false preserved", snapshot.ok and snapshot.stats.TOTAL_KILLS == 0 and not snapshot.unlocked.ACH_WINS_10)
	check("snapshot separates both accounts", snapshot.ok and snapshot.observer == OBSERVER and snapshot.target == TARGET and not snapshot.has("owner"))
	check("snapshot explicitly cannot confirm writes", snapshot.ok and snapshot.write_confirmation == false and snapshot.source == "independent_requested_user_cache")
	check("duplicate completion rejected", reader.poll(FIRST).code == "UNKNOWN_HANDLE")
	var second: Dictionary = reader.request()
	check("same instance supports next exact handle", second.ok and second.handle == "f123456789abcdf0")
	check("late previous handle cannot complete next read", reader.poll(FIRST).code == "UNKNOWN_HANDLE")
	check("next read completes", reader.poll(second.handle).ok)
	var only_target_reads := true
	for command in fake.calls:
		only_target_reads = only_target_reads and not command.begins_with("current_") and not command.begins_with("user_") and not "store" in command.to_lower()
	check("facade never asks for current-user cache or writes", only_target_reads)
	for field in ["observer", "target", "app", "protocol", "source", "handle"]:
		var altered := FakeNative.new()
		var reading: Observer = started(altered)
		altered.corrupt_field = field
		altered.corrupt_when = "poll"
		altered.corrupt_value = 999 if field in ["app", "protocol"] else "wrong"
		check("mixed completed envelope rejected: " + field, reading.poll(FIRST).code == "BAD_NATIVE_RESPONSE")
	for field in ["observer", "target", "app", "protocol", "source", "handle"]:
		var altered := FakeNative.new()
		var reading: Observer = started(altered)
		altered.corrupt_field = field
		altered.corrupt_when = "getter"
		altered.corrupt_value = 999 if field in ["app", "protocol"] else "wrong"
		check("mixed getter envelope rejects entire snapshot: " + field, reading.poll(FIRST).code == "MIXED_SNAPSHOT")
	for failure_index in [1, 4, 5, 34]:
		var failed := FakeNative.new()
		var reading: Observer = started(failed)
		failed.fail_at = failure_index
		var result: Dictionary = reading.poll(FIRST)
		check("getter failure rejects whole snapshot: %d" % failure_index, result.code == "GETTER_FAILED" and not result.has("stats"))
		check("failed snapshot facade cannot be reused", reading.request().code == "OBSERVER_CLOSED")
	for bad_value in [-1, 2147483648, 1.5, true, "0"]:
		var failed := FakeNative.new()
		var reading: Observer = started(failed)
		failed.stat_value = bad_value
		check("invalid stat type/range rejected: " + str(bad_value), reading.poll(FIRST).code == "BAD_STAT")
	var maximum := FakeNative.new()
	var maximum_reader: Observer = started(maximum)
	maximum.stat_value = 2147483647
	maximum.achievement_value = true
	var maximum_snapshot: Dictionary = maximum_reader.poll(FIRST)
	check("int32 max and achieved true preserved", maximum_snapshot.ok and maximum_snapshot.stats.TOTAL_KILLS == 2147483647 and maximum_snapshot.unlocked.ACH_WINS_10)
	var bad_achievement := FakeNative.new()
	var achievement_reader: Observer = started(bad_achievement)
	bad_achievement.achievement_value = 0
	check("numeric false not accepted as achievement boolean", achievement_reader.poll(FIRST).code == "BAD_ACHIEVEMENT")
	for failure in ["READ_TIMEOUT", "OBSERVER_CHANGED", "RESULT_IDENTITY_MISMATCH", "READ_RESULT_FAILED", "RESULT_UNAVAILABLE"]:
		var failed := FakeNative.new()
		var reading: Observer = started(failed)
		failed.native_error = failure
		check("native failure is preserved: " + failure, reading.poll(FIRST).code == failure)
		failed.native_error = ""
		check("late success cannot resurrect failed facade", reading.poll(FIRST).code == "OBSERVER_CLOSED")

func run_native() -> void:
	# Only the isolated builder should select this mode, with the synthetic ABI.
	check("native observer class registered", ClassDB.class_exists("SteamStatsObserver"))
	if not ClassDB.class_exists("SteamStatsObserver"): return
	var reader := Observer.new()
	if OS.get_environment("LSH_READER_ABSENT") == "1":
		check("absent Steam fails without initialization", reader.attach(OBSERVER, TARGET).code == "STEAM_NOT_INITIALIZED")
		return
	if OS.get_environment("LSH_MOCK_TARGET_OFFSET") != "1":
		check("native QA requires independent-target mock fixture", false)
		return
	check("compiled class binds independent target", reader.attach(OBSERVER, TARGET).ok)
	var started: Dictionary = reader.request()
	check("native exact read handle", started.ok and started.handle == FIRST)
	if not started.ok: return
	var pending: Dictionary = reader.poll(started.handle)
	check("native read pending before callback", pending.ok and pending.get("pending") == true)
	if not pending.ok: return
	OS.set_environment("LSH_MOCK_DONE", "1")
	var snapshot: Dictionary = reader.poll(started.handle)
	check("compiled independent target ABI result accepted", snapshot.ok and snapshot.observer == OBSERVER and snapshot.target == TARGET)
	check("compiled target getters complete", snapshot.ok and snapshot.stats.size() == 4 and snapshot.unlocked.size() == 30)
	check("compiled snapshot cannot confirm writes", snapshot.ok and not snapshot.write_confirmation)
	check("native duplicate rejected", reader.poll(started.handle).code == "UNKNOWN_HANDLE")
	var second: Dictionary = reader.request()
	check("native second request accepted", second.ok)
	if not second.ok: return
	check("native old callback cannot finish next request", reader.poll(started.handle).code == "UNKNOWN_HANDLE")
	check("native second read completes", reader.poll(second.handle).ok)
	var third: Dictionary = reader.request()
	check("native third request accepted", third.ok)
	if not third.ok: return
	OS.set_environment("LSH_MOCK_RESULT_OWNER_OFFSET", "-1")
	check("native callback for observer rejected instead of target", reader.poll(third.handle).code == "RESULT_IDENTITY_MISMATCH")
	OS.set_environment("LSH_MOCK_RESULT_OWNER_OFFSET", "0")
	check("native late correction cannot resurrect closed facade", reader.poll(third.handle).code == "OBSERVER_CLOSED")

func finish() -> void:
	var passed := true
	for row in checks: passed = passed and row.passed
	var report := {"passed": passed, "checks": checks, "live_steam_tested": false, "write_confirmation_tested": false, "native_mode": OS.get_environment("LSH_OBSERVER_NATIVE") == "1"}
	var file := FileAccess.open("res://observer_report.json", FileAccess.WRITE)
	if file == null:
		push_error("Cannot write observer QA report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("STEAM_OBSERVER_QA ", JSON.stringify(report))
	quit(0 if passed else 1)
