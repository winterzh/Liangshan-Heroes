extends SceneTree
const Receipt = preload("res://steam_run_receipt.gd")
const Catalog = preload("res://scripts/steam_achievement_catalog.gd")
const OWNER := "76561198000000001"
const TOKEN := "0123456789abcdef0123456789abcdef"
const TOKEN2 := "abcdef0123456789abcdef0123456789"
const DEFENSE := {"mode": "defense", "level_id": "", "waves": 30}
var checks: Array = []

func check(name: String, passed: bool) -> void:
	checks.append({"name": name, "passed": passed})

func empty_stats() -> Dictionary:
	return {"TOTAL_KILLS": 0, "TOTAL_WINS": 0, "DEFENSE_WINS": 0, "AI_WINS": 0}

func empty_unlocks() -> Dictionary:
	var result := {}
	for entry in Catalog.entries(): result[entry.id] = false
	return result

func apply(model: RefCounted, prepared: Dictionary) -> bool:
	if not prepared.get("ok", false) or not prepared.get("changed", false): return false
	# A real JSON roundtrip is part of the caller's persistence boundary.
	var roundtrip: Variant = JSON.parse_string(JSON.stringify(prepared.record))
	return model.commit(roundtrip, prepared.sha256).get("ok", false)

func _init() -> void:
	var expected := OS.get_environment("STEAM_RECEIPT_EXPECTED_USER_DIR").replace("\\", "/").trim_suffix("/")
	check("actual private model user directory", not expected.is_empty() and OS.get_user_data_dir().replace("\\", "/").trim_suffix("/") == expected)
	var model := Receipt.new()
	check("create account", model.create(OWNER, empty_stats(), empty_unlocks()).ok)
	var initial: Dictionary = model.capture()
	var begin: Dictionary = model.prepare_begin(TOKEN, DEFENSE)
	check("begin prepared without changing committed receipt", begin.ok and model.capture() == initial)
	check("unpersisted begin cannot publish", model.publish_targets(OWNER).code == "PERSISTENCE_PENDING")
	check("begin JSON commit", apply(model, begin))
	check("committed absolute targets publish for current owner", model.publish_targets(OWNER).ok)
	check("another account cannot publish", not model.publish_targets("76561198000000002").ok)
	check("same token is not a new run", not model.prepare_begin(TOKEN, DEFENSE).ok)
	check("known run can resume", model.can_resume(TOKEN, OWNER, DEFENSE).ok)
	check("unknown run cannot resume", not model.can_resume(TOKEN2, OWNER, DEFENSE).ok)
	check("different account cannot resume", not model.can_resume(TOKEN, "76561198000000002", DEFENSE).ok)
	check("custom context cannot regain qualification", not model.can_resume(TOKEN, OWNER, {"mode":"custom", "level_id":"", "waves":0}).ok)
	check("another eligible context cannot reuse this token", not model.can_resume(TOKEN, OWNER, {"mode":"defense", "level_id":"", "waves":60}).ok)
	var twenty: Dictionary = model.prepare_progress(TOKEN, DEFENSE, 20)
	check("progress not published before commit", model.capture().stats.TOTAL_KILLS == 0)
	check("unpersisted progress blocks SDK targets", not model.publish_targets(OWNER).ok)
	check("20 kills committed", apply(model, twenty) and model.capture().stats.TOTAL_KILLS == 20)
	var persisted: Variant = JSON.parse_string(JSON.stringify(model.capture()))
	var restarted := Receipt.new()
	check("record opens after JSON restart", restarted.open_record(persisted, OWNER).ok)
	check("old 10-kill snapshot does not recredit", restarted.prepare_progress(TOKEN, DEFENSE, 10).code == "ALREADY_CREDITED")
	check("replay to 20 does not recredit", restarted.prepare_progress(TOKEN, DEFENSE, 20).code == "ALREADY_CREDITED")
	check("21st kill adds one", apply(restarted, restarted.prepare_progress(TOKEN, DEFENSE, 21)) and restarted.capture().stats.TOTAL_KILLS == 21)
	var next: Dictionary = restarted.prepare_progress(TOKEN, DEFENSE, 22)
	var tampered: Dictionary = next.record.duplicate(true)
	tampered.stats.TOTAL_KILLS += 5
	check("tampered preparation rejected", not restarted.commit(tampered, next.sha256).ok)
	check("failed commit leaves count unchanged", restarted.capture().stats.TOTAL_KILLS == 21)
	check("original preparation can retry", apply(restarted, next))
	var stale: Dictionary = restarted.prepare_progress(TOKEN, DEFENSE, 23)
	var fresh: Dictionary = restarted.prepare_progress(TOKEN, DEFENSE, 24)
	check("stale preparation cannot replace newer one", not restarted.commit(stale.record, stale.sha256).ok)
	check("newer preparation survives", apply(restarted, fresh) and restarted.capture().stats.TOTAL_KILLS == 24)
	var before_win: Dictionary = restarted.capture()
	check("win committed", apply(restarted, restarted.prepare_settle(TOKEN, DEFENSE, true, {})))
	check("win stats counted once", restarted.capture().stats.TOTAL_WINS == 1 and restarted.capture().stats.DEFENSE_WINS == 1)
	check("defense achievement unlocked", restarted.capture().unlocked.ACH_DEFENSE_30)
	var won_restart := Receipt.new()
	check("terminal receipt survives restart", won_restart.open_record(JSON.parse_string(JSON.stringify(restarted.capture())), OWNER).ok)
	check("terminal run cannot regain eligibility", not won_restart.can_resume(TOKEN, OWNER, DEFENSE).ok)
	check("old pre-win battle result does not recredit", won_restart.prepare_settle(TOKEN, DEFENSE, true, {}).code == "ALREADY_TERMINAL")
	check("terminal kills rejected", not won_restart.prepare_progress(TOKEN, DEFENSE, 25).ok)
	check("new token is a separate run", apply(won_restart, won_restart.prepare_begin(TOKEN2, DEFENSE)))
	check("second run 1 kill adds one", apply(won_restart, won_restart.prepare_progress(TOKEN2, DEFENSE, 1)) and won_restart.capture().stats.TOTAL_KILLS == 25)
	check("loss marks terminal", apply(won_restart, won_restart.prepare_settle(TOKEN2, DEFENSE, false, {})))
	check("loss does not add wins", won_restart.capture().stats.TOTAL_WINS == 1)
	check("loss replay cannot become victory", won_restart.prepare_settle(TOKEN2, DEFENSE, true, {}).code == "ALREADY_TERMINAL" and won_restart.capture().stats.TOTAL_WINS == 1)
	var reject_cases := [
		{"name":"negative kills", "value":-1}, {"name":"fractional kills", "value":0.5},
		{"name":"string kills", "value":"1"}, {"name":"boolean kills", "value":true},
		{"name":"NaN kills", "value":NAN}, {"name":"infinite kills", "value":INF},
		{"name":"overflow kills", "value":2147483648}]
	var valid := Receipt.new()
	check("active test record restored", valid.open_record(before_win, OWNER).ok)
	for item in reject_cases:
		check(item.name, not valid.prepare_progress(TOKEN, DEFENSE, item.value).ok)
	check("invalid input leaves record unchanged", valid.capture() == before_win)
	var wrong_owner := Receipt.new()
	check("record owner mismatch rejected", not wrong_owner.open_record(before_win, "76561198000000002").ok and wrong_owner.capture().is_empty())
	var bad_record := before_win.duplicate(true)
	bad_record.runs[TOKEN].context.waves = 31
	check("unsupported record context rejected", not Receipt.new().open_record(bad_record, OWNER).ok)
	bad_record = before_win.duplicate(true)
	bad_record.runs[TOKEN].credited_kills = -1
	check("negative record highwater rejected", not Receipt.new().open_record(bad_record, OWNER).ok)
	bad_record = before_win.duplicate(true)
	bad_record.runs[TOKEN].victory = true
	check("nonterminal victory rejected", not Receipt.new().open_record(bad_record, OWNER).ok)
	bad_record = before_win.duplicate(true)
	bad_record.unlocked["INVENTED_ACHIEVEMENT"] = true
	check("unknown achievement rejected", not Receipt.new().open_record(bad_record, OWNER).ok)
	for field in ["version", "generation"]:
		bad_record = before_win.duplicate(true)
		bad_record[field] = 1.5
		check("fractional record " + field, not Receipt.new().open_record(bad_record, OWNER).ok)
	bad_record = before_win.duplicate(true)
	bad_record.requires_correction = 1
	check("numeric correction boolean rejected", not Receipt.new().open_record(bad_record, OWNER).ok)
	check("owner above uint64 rejected", not Receipt.new().create("18446744073709551616", empty_stats(), empty_unlocks()).ok)
	check("uint64 owner retained as exact string", Receipt.new().create("18446744073709551615", empty_stats(), empty_unlocks()).ok)
	var remote := empty_stats()
	remote.TOTAL_KILLS = 100
	check("higher server floor merges once", apply(valid, valid.prepare_remote_floor(OWNER, remote, empty_unlocks(), valid.capture().generation)) and valid.capture().stats.TOTAL_KILLS == 100)
	check("same server floor does not add again", not valid.prepare_remote_floor(OWNER, remote, empty_unlocks(), valid.capture().generation).changed)
	check("lower server read does not erase pending absolute target", not valid.prepare_remote_floor(OWNER, empty_stats(), empty_unlocks(), valid.capture().generation).changed)
	check("highwater survives server floor merge", apply(valid, valid.prepare_progress(TOKEN, DEFENSE, 25)) and valid.capture().stats.TOTAL_KILLS == 101)
	var saturation := Receipt.new()
	var capped := empty_stats()
	capped.TOTAL_KILLS = 2147483646
	check("saturation account created", saturation.create(OWNER, capped, empty_unlocks()).ok)
	check("saturation run created", apply(saturation, saturation.prepare_begin(TOKEN, DEFENSE)))
	check("stat saturates without losing per-run highwater", apply(saturation, saturation.prepare_progress(TOKEN, DEFENSE, 10)) and saturation.capture().stats.TOTAL_KILLS == 2147483647 and saturation.capture().runs[TOKEN].credited_kills == 10)
	var exhausted := before_win.duplicate(true)
	exhausted.generation = 2147483647
	var full_generation := Receipt.new()
	check("maximum generation can open", full_generation.open_record(exhausted, OWNER).ok)
	check("maximum generation does not overflow", full_generation.prepare_progress(TOKEN, DEFENSE, 25).code == "GENERATION_EXHAUSTED" and full_generation.capture() == exhausted)
	var full_runs := before_win.duplicate(true)
	full_runs.runs.clear()
	for i in range(Receipt.MAX_RUNS): full_runs.runs[str(i).pad_zeros(32)] = before_win.runs[TOKEN].duplicate(true)
	var limit_model := Receipt.new()
	check("run tombstone capacity opens", limit_model.open_record(full_runs, OWNER).ok)
	check("run limit cannot evict old tombstones", limit_model.prepare_begin(TOKEN, DEFENSE).code == "RUN_LIMIT" and limit_model.capture().runs.size() == Receipt.MAX_RUNS)
	full_runs.runs[TOKEN] = before_win.runs[TOKEN].duplicate(true)
	check("over-capacity record rejected", not Receipt.new().open_record(full_runs, OWNER).ok)
	var correction := Receipt.new()
	check("correction fixture restored", correction.open_record(before_win, OWNER).ok)
	var rejected_floor := empty_stats()
	rejected_floor.TOTAL_KILLS = 10000
	check("correction fixture has prior earned targets", apply(correction, correction.prepare_remote_floor(OWNER, rejected_floor, empty_unlocks(), correction.capture().generation)) and correction.capture().unlocked.values().has(true))
	var rejected_work: Dictionary = correction.prepare_progress(TOKEN, DEFENSE, 10000)
	var old_read_generation: int = correction.capture().generation
	check("correction requires persisted invalidation", correction.prepare_server_correction(OWNER, empty_stats(), empty_unlocks(), correction.capture().generation).code == "DURABLE_INVALIDATION_REQUIRED")
	var invalidation: Dictionary = correction.prepare_server_invalidation(OWNER)
	check("result 8 immediately blocks publication", invalidation.ok and correction.publish_targets(OWNER).code == "SERVER_CORRECTION_REQUIRED")
	check("old pending target cannot commit after result 8", not correction.commit(rejected_work.record, rejected_work.sha256).ok)
	check("invalidation persisted separately", apply(correction, invalidation))
	var blocked := Receipt.new()
	check("correction barrier survives JSON restart", blocked.open_record(JSON.parse_string(JSON.stringify(correction.capture())), OWNER).ok and not blocked.publish_targets(OWNER).ok)
	check("normal max merge cannot bypass correction", blocked.prepare_remote_floor(OWNER, remote, empty_unlocks(), blocked.capture().generation).code == "SERVER_CORRECTION_REQUIRED")
	check("old active slot loses qualification on invalidation", not blocked.can_resume(TOKEN, OWNER, DEFENSE).ok)
	check("new runs wait for authoritative correction", not blocked.prepare_begin(TOKEN2, DEFENSE).ok)
	var authoritative := empty_stats()
	authoritative.TOTAL_KILLS = 5
	check("pre-invalidation read cannot serve as authority", blocked.prepare_server_correction(OWNER, authoritative, empty_unlocks(), old_read_generation).code == "STALE_REMOTE_READ")
	var corrected: Dictionary = blocked.prepare_server_correction(OWNER, authoritative, empty_unlocks(), blocked.capture().generation)
	check("authority correction cannot publish before persistence", corrected.ok and not blocked.publish_targets(OWNER).ok)
	check("authority correction commits exact lower targets", apply(blocked, corrected) and blocked.publish_targets(OWNER).stats == authoritative and blocked.publish_targets(OWNER).unlocked == empty_unlocks())
	check("late old read cannot resurrect rejected floor", blocked.prepare_remote_floor(OWNER, rejected_floor, empty_unlocks(), old_read_generation).code == "STALE_REMOTE_READ" and blocked.publish_targets(OWNER).stats == authoritative)
	check("retained tombstone rejects old token begin", blocked.prepare_begin(TOKEN, DEFENSE).code == "RUN_EXISTS")
	check("corrected old slot cannot regain qualification", not blocked.can_resume(TOKEN, OWNER, DEFENSE).ok and not blocked.prepare_progress(TOKEN, DEFENSE, 10001).ok)
	check("corrected terminal retry does not resurrect wins", blocked.prepare_settle(TOKEN, DEFENSE, true, {}).code == "ALREADY_TERMINAL" and blocked.capture().stats.TOTAL_WINS == 0)
	check("fresh run allowed after durable correction", apply(blocked, blocked.prepare_begin(TOKEN2, DEFENSE)))
	check("fresh kill adds only one to corrected floor", apply(blocked, blocked.prepare_progress(TOKEN2, DEFENSE, 1)) and blocked.publish_targets(OWNER).stats.TOTAL_KILLS == 6)
	var invalid_max := full_generation.prepare_server_invalidation(OWNER)
	check("failed invalidation persistence keeps in-process publish blocked", invalid_max.code == "GENERATION_EXHAUSTED" and not full_generation.publish_targets(OWNER).ok)
	var failure_count := 0
	for row in checks:
		if not row.passed: failure_count += 1
	var report := {"scope":"pure_receipt_model_json_contract", "pid":OS.get_process_id(), "user_data_dir":OS.get_user_data_dir(), "checks":checks, "failed":failure_count, "passed":failure_count == 0, "production_steam_or_disk_integration":false,
		"unsolved_host_boundary":"result 8 callback received but invalidation not yet durably persisted; capture is not a publication API"}
	var output := OS.get_environment("STEAM_RECEIPT_TEST_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			print("RECEIPT_REPORT_WRITE_FAILED")
			quit(2)
			return
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("RECEIPT_CHECKS=%d FAILED=%d" % [checks.size(), failure_count])
	quit(0 if failure_count == 0 else 1)
