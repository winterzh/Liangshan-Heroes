extends SceneTree
const Receipt = preload("res://steam_run_receipt.gd")
const Catalog = preload("res://scripts/steam_achievement_catalog.gd")
const OWNER := "76561198000000001"
const TOKEN := "0123456789abcdef0123456789abcdef"
const TOKEN2 := "abcdef0123456789abcdef0123456789"
const CONTEXT := {"mode": "defense", "level_id": "", "waves": 30}
const FIXTURE := "user://receipt-fixture.json"
var checks: Array = []

func check(label: String, passed: bool) -> void:
	checks.append({"name": label, "passed": passed})

func write_fixture(record: Dictionary) -> bool:
	var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(record))
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK

func read_fixture() -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))

func empty_unlocks() -> Dictionary:
	var value := {}
	for entry in Catalog.entries(): value[entry.id] = false
	return value

func persist(model: RefCounted, prepared: Dictionary) -> bool:
	if not prepared.get("ok", false) or not prepared.get("changed", false): return false
	if not write_fixture(prepared.record): return false
	return model.commit(read_fixture(), prepared.sha256).get("ok", false)

func _init() -> void:
	var phase := OS.get_environment("STEAM_RECEIPT_PHASE")
	var expected := OS.get_environment("STEAM_RECEIPT_EXPECTED_USER_DIR").replace("\\", "/").trim_suffix("/")
	var actual := OS.get_user_data_dir().replace("\\", "/").trim_suffix("/")
	check("actual private user directory", not expected.is_empty() and actual == expected)
	if actual != expected:
		finish(phase)
		return
	var model := Receipt.new()
	if phase == "create":
		check("fixture absent at first process", not FileAccess.file_exists(FIXTURE))
		var unlocked := {}
		for entry in Catalog.entries(): unlocked[entry.id] = false
		check("create", model.create(OWNER, {"TOTAL_KILLS":0,"TOTAL_WINS":0,"DEFENSE_WINS":0,"AI_WINS":0}, unlocked).ok)
		check("persist begin", persist(model, model.prepare_begin(TOKEN, CONTEXT)))
		check("persist 20 kills", persist(model, model.prepare_progress(TOKEN, CONTEXT, 20)))
	else:
		check("open prior process receipt", model.open_record(read_fixture(), OWNER).ok)
		if model.capture().is_empty():
			finish(phase)
			return
		match phase:
			"resume":
				check("prior process count", model.capture().stats.TOTAL_KILLS == 20)
				check("old save 10 adds nothing", model.prepare_progress(TOKEN, CONTEXT, 10).code == "ALREADY_CREDITED")
				check("replay 20 adds nothing", model.prepare_progress(TOKEN, CONTEXT, 20).code == "ALREADY_CREDITED")
				check("21st kill adds one", persist(model, model.prepare_progress(TOKEN, CONTEXT, 21)) and model.capture().stats.TOTAL_KILLS == 21)
			"intent_only":
				var before: Dictionary = model.capture()
				var proposed: Dictionary = model.prepare_settle(TOKEN, CONTEXT, true, {})
				check("win intent persisted", proposed.ok and write_fixture(proposed.record))
				check("process exits before model commit and SDK call", model.capture() == before and before.stats.TOTAL_WINS == 0)
			"recover":
				var committed_before: Dictionary = model.capture()
				var fixture_bytes_before := FileAccess.get_file_as_bytes(FIXTURE)
				check("persisted intent becomes absolute target", model.capture().stats.TOTAL_WINS == 1 and model.capture().stats.DEFENSE_WINS == 1)
				check("retry same terminal result is no-op", model.prepare_settle(TOKEN, CONTEXT, true, {}).code == "ALREADY_TERMINAL")
				check("restored pre-win slot cannot regain qualification", not model.can_resume(TOKEN, OWNER, CONTEXT).ok)
				check("kills unchanged after terminal recovery", model.capture().stats.TOTAL_KILLS == 21)
				check("terminal achievement retained", model.capture().unlocked.ACH_DEFENSE_30)
				check("receipt unchanged by no-op retry", model.capture() == committed_before and FileAccess.get_file_as_bytes(FIXTURE) == fixture_bytes_before)
				check("durable terminal target is publishable", model.publish_targets(OWNER).ok)
			"invalidate_only":
				check("second live token persisted", persist(model, model.prepare_begin(TOKEN2, CONTEXT)))
				check("second token seven kills persisted", persist(model, model.prepare_progress(TOKEN2, CONTEXT, 7)))
				var invalidation: Dictionary = model.prepare_server_invalidation(OWNER)
				check("result 8 blocks SDK target before write", not model.publish_targets(OWNER).ok)
				check("invalidation intent persisted before process exit", invalidation.ok and write_fixture(invalidation.record))
				check("graceful exit before invalidation model commit", not model.capture().requires_correction and not model.publish_targets(OWNER).ok)
			"correct":
				check("durable invalidation blocks restarted publisher", model.capture().requires_correction and not model.publish_targets(OWNER).ok)
				check("old pending max cannot revive after restart", not model.prepare_remote_floor(OWNER, {"TOTAL_KILLS":1000,"TOTAL_WINS":100,"DEFENSE_WINS":100,"AI_WINS":0}, empty_unlocks(), model.capture().generation).ok)
				check("old active slot has no qualification", not model.can_resume(TOKEN2, OWNER, CONTEXT).ok)
				var corrected := {"TOTAL_KILLS":2,"TOTAL_WINS":0,"DEFENSE_WINS":0,"AI_WINS":0}
				check("authority correction persists exact lower target", persist(model, model.prepare_server_correction(OWNER, corrected, empty_unlocks(), model.capture().generation)))
				check("lower correction published after commit", model.publish_targets(OWNER).stats == corrected and model.publish_targets(OWNER).unlocked == empty_unlocks())
			"recover_correction":
				check("authority floor survives next process", model.publish_targets(OWNER).ok and model.publish_targets(OWNER).stats.TOTAL_KILLS == 2 and model.publish_targets(OWNER).stats.TOTAL_WINS == 0)
				check("rejected old victory is not resurrected", model.prepare_settle(TOKEN, CONTEXT, true, {}).code == "ALREADY_TERMINAL" and model.capture().stats.TOTAL_WINS == 0)
				check("rejected old progress is not resurrected", not model.prepare_progress(TOKEN2, CONTEXT, 8).ok and model.capture().stats.TOTAL_KILLS == 2)
				check("all old tokens remain non-resumable", not model.can_resume(TOKEN, OWNER, CONTEXT).ok and not model.can_resume(TOKEN2, OWNER, CONTEXT).ok)
				check("both tombstones retained", model.capture().runs.size() == 2)
			_:
				check("known phase", false)
	finish(phase)

func finish(phase: String) -> void:
	var failures := 0
	for row in checks:
		if not row.passed: failures += 1
	var report := {"scope":"pure_receipt_fixture_cross_process", "phase":phase, "pid":OS.get_process_id(), "user_data_dir":OS.get_user_data_dir(), "checks":checks, "failed":failures, "passed":failures == 0, "production_disk_transaction_or_sdk":false, "interruption":"graceful exit after intent write; no power-loss simulation", "unsolved_host_boundary":"result 8 before invalidation persistence; receipt rollback with a battle slot; no atomic disk adapter here"}
	var file := FileAccess.open(OS.get_environment("STEAM_RECEIPT_TEST_OUTPUT"), FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("RECEIPT_PROCESS_%s_CHECKS=%d_FAILED=%d" % [phase, checks.size(), failures])
	quit(0 if failures == 0 else 1)
