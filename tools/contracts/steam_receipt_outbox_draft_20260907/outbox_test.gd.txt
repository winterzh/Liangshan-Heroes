extends SceneTree
const Receipt = preload("res://steam_run_receipt.gd")
const Outbox = preload("res://steam_receipt_outbox.gd")
const Catalog = preload("res://scripts/steam_achievement_catalog.gd")
const OWNER := "76561198000000001"
const RUN := "0123456789abcdef0123456789abcdef"
const SEND := "abcdef0123456789abcdef0123456789"
const READ := "11111111111111111111111111111111"
const READ2 := "22222222222222222222222222222222"
const DEFENSE := {"mode": "defense", "level_id": "", "waves": 30}
var checks: Array = []

func check(label: String, passed: bool) -> void:
	checks.append({"name": label, "passed": passed})

func stats(kills := 0) -> Dictionary:
	return {"TOTAL_KILLS": kills, "TOTAL_WINS": 0, "DEFENSE_WINS": 0, "AI_WINS": 0}

func unlocks() -> Dictionary:
	var value := {}
	for entry in Catalog.entries(): value[entry.id] = false
	return value

func applied(model: RefCounted, proposal: Dictionary) -> bool:
	if not proposal.get("ok", false) or not proposal.get("changed", false): return false
	return model.commit(JSON.parse_string(JSON.stringify(proposal.document)), proposal.sha256).ok

func fresh() -> RefCounted:
	var model := Outbox.new(Receipt)
	check("create commits exact JSON", applied(model, model.prepare_create(OWNER, stats(), unlocks())))
	check("begin commits exact JSON", applied(model, model.prepare_run_event("prepare_begin", [RUN, DEFENSE])))
	check("progress commits exact JSON", applied(model, model.prepare_run_event("prepare_progress", [RUN, DEFENSE, 20])))
	return model

func _init() -> void:
	var expected := OS.get_environment("STEAM_RECEIPT_EXPECTED_USER_DIR").replace("\\", "/").trim_suffix("/")
	check("actual private outbox user directory", not expected.is_empty() and OS.get_user_data_dir().replace("\\", "/").trim_suffix("/") == expected)
	var model := fresh()
	var before: Dictionary = model.capture()
	var dispatch: Dictionary = model.prepare_dispatch(SEND)
	check("outbox preparation leaves durable state unchanged", dispatch.ok and model.capture() == before)
	check("SDK targets blocked before outbox commit", not model.take_sdk_targets(OWNER, SEND).ok)
	var tampered: Dictionary = dispatch.document.duplicate(true)
	tampered.outbound.stats.TOTAL_KILLS = 99
	check("wrong closed readback rejected", not model.commit(tampered, dispatch.sha256).ok)
	check("wrong digest rejected", not model.commit(dispatch.document, "bad").ok)
	check("uncertainty JSON committed", applied(model, dispatch))
	var uncertain: Dictionary = model.capture()
	check("other account cannot take SDK targets", not model.take_sdk_targets("76561198000000002", SEND).ok)
	check("unissued callback rejected", not model.prepare_stored(OWNER, SEND, 1).ok)
	var sdk: Dictionary = model.take_sdk_targets(OWNER, SEND)
	check("first target is exact persisted batch", sdk.ok and sdk.targets.stats.TOTAL_KILLS == 20)
	check("targets issued once only", not model.take_sdk_targets(OWNER, SEND).ok)
	check("timeout never opens a second batch", model.prepare_stored(OWNER, SEND, 2).code == "OUTBOUND_UNRESOLVED" and model.prepare_dispatch(READ).code == "OUTBOUND_UNRESOLVED")
	check("new progress can persist during unresolved send", applied(model, model.prepare_run_event("prepare_progress", [RUN, DEFENSE, 21])))
	check("sent batch remains 20 latest receipt is 21", model.capture().outbound.stats.TOTAL_KILLS == 20 and model.capture().receipt.stats.TOTAL_KILLS == 21)
	check("wrong callback token rejected", not model.prepare_stored(OWNER, READ, 1).ok)
	check("success only prepares acknowledgement", model.prepare_stored(OWNER, SEND, 1).ok and model.capture().outbound.state == "uncertain")
	model.abandon()
	check("ack can be retried after persistence failure", applied(model, model.prepare_stored(OWNER, SEND, 1)))
	check("ack retains newer progress", model.capture().outbound.state == "none" and model.capture().receipt.stats.TOTAL_KILLS == 21)
	check("late old callback rejected", not model.prepare_stored(OWNER, SEND, 8).ok)
	check("next batch carries current target", applied(model, model.prepare_dispatch(READ)) and model.take_sdk_targets(OWNER, READ).targets.stats.TOTAL_KILLS == 21)
	var reopened := Outbox.new(Receipt)
	check("uncertain restart opens with explicit recovery", reopened.open_document(JSON.parse_string(JSON.stringify(uncertain)), OWNER).code == "RECOVERY_REQUIRED")
	check("restart cannot replay targets or continue old statistics", not reopened.take_sdk_targets(OWNER, SEND).ok and not reopened.prepare_dispatch(READ).ok and not reopened.prepare_run_event("prepare_progress", [RUN, DEFENSE, 21]).ok)
	check("read blocked before durable invalidation", not reopened.begin_authoritative_read(OWNER, READ).ok)
	var invalidation: Dictionary = reopened.prepare_recovery_invalidation(OWNER)
	check("invalidation preparation keeps uncertainty durable", invalidation.ok and reopened.capture().outbound.state == "uncertain")
	check("invalidation commits and retains closed run tombstone", applied(reopened, invalidation) and reopened.capture().receipt.runs[RUN].terminal and reopened.capture().receipt.requires_correction and reopened.capture().outbound.state == "none")
	check("correction without correlated new read rejected", not reopened.prepare_authoritative_correction(OWNER, READ, stats(7), unlocks()).ok)
	check("authoritative read epoch starts after invalidation", reopened.begin_authoritative_read(OWNER, READ).ok)
	check("second concurrent read rejected", not reopened.begin_authoritative_read(OWNER, SEND).ok)
	check("wrong read cancellation rejected", not reopened.cancel_authoritative_read(OWNER, SEND).ok)
	check("timed out read can cancel without clearing correction", reopened.cancel_authoritative_read(OWNER, READ).ok and reopened.capture().receipt.requires_correction)
	check("cancelled old callback is stale", not reopened.prepare_authoritative_correction(OWNER, READ, stats(99), unlocks()).ok)
	check("cancelled token cannot alias late callback", not reopened.begin_authoritative_read(OWNER, READ).ok)
	check("new read retries after timeout", reopened.begin_authoritative_read(OWNER, READ2).ok)
	check("different callback epoch rejected", not reopened.prepare_authoritative_correction(OWNER, SEND, stats(7), unlocks()).ok)
	var correction: Dictionary = reopened.prepare_authoritative_correction(OWNER, READ2, stats(7), unlocks())
	check("correction not visible before disk commit", correction.ok and reopened.capture().receipt.stats.TOTAL_KILLS == 20)
	check("exact lower correction commits", applied(reopened, correction) and reopened.capture().receipt.stats.TOTAL_KILLS == 7)
	check("old highwater retained and old run cannot replay", reopened.capture().receipt.runs[RUN].credited_kills == 20 and not reopened.prepare_run_event("prepare_progress", [RUN, DEFENSE, 21]).ok)
	check("old read cannot overwrite corrected state", not reopened.prepare_authoritative_correction(OWNER, READ, stats(100), unlocks()).ok)
	check("new run starts after correction", applied(reopened, reopened.prepare_run_event("prepare_begin", [SEND, DEFENSE])))
	check("new valid kill adds to corrected target", applied(reopened, reopened.prepare_run_event("prepare_progress", [SEND, DEFENSE, 1])) and reopened.capture().receipt.stats.TOTAL_KILLS == 8)
	var interrupted := fresh()
	check("second race dispatch committed", applied(interrupted, interrupted.prepare_dispatch(SEND)) and interrupted.take_sdk_targets(OWNER, SEND).ok)
	var ack: Dictionary = interrupted.prepare_stored(OWNER, SEND, 1)
	check("result8 immediately blocks while ack persistence pending", interrupted.prepare_stored(OWNER, SEND, 8).code == "PERSISTENCE_PENDING")
	# Intentional reentrancy violation in memory only. A disk host MUST serialize
	# callback dispatch with the entire non-yielding prepare/write/readback/commit.
	check("in-memory reentrant acknowledgement rejected", interrupted.commit(ack.document, ack.sha256).code == "INVALIDATION_SUPERSEDED_PREPARATION")
	interrupted.abandon()
	check("abandon does not clear live invalidation", not interrupted.take_sdk_targets(OWNER, SEND).ok and not interrupted.prepare_run_event("prepare_progress", [RUN, DEFENSE, 22]).ok)
	check("result8 invalidation retry persists", applied(interrupted, interrupted.prepare_recovery_invalidation(OWNER)))
	var clean := fresh()
	for args in [[RUN, 1], [RUN, DEFENSE, true, "bad"]]:
		check("bad typed host arguments rejected", not clean.prepare_run_event("prepare_begin" if args.size() == 2 else "prepare_settle", args).ok)
	check("arbitrary receipt methods are inaccessible", not clean.prepare_run_event("prepare_server_correction", []).ok)
	check("same app unowned result8 still invalidates", applied(clean, clean.prepare_external_invalidation(OWNER)) and clean.capture().receipt.requires_correction and clean.capture().receipt.runs[RUN].terminal)
	for key in ["owner", "revision", "outbound", "receipt"]:
		var bad: Dictionary = before.duplicate(true)
		bad.erase(key)
		check("missing document field rejected " + key, not Outbox.new(Receipt).open_document(bad, OWNER).ok)
	check("other owner cannot open receipt", not Outbox.new(Receipt).open_document(before, "76561198000000002").ok)
	var failed := 0
	for row in checks:
		if not row.passed: failed += 1
	var report := {"passed": failed == 0, "failed": failed, "checks": checks, "pid": OS.get_process_id(), "user_data_dir": OS.get_user_data_dir(), "phase": "outbox", "disk_adapter_tested": false, "sdk_tested": false}
	var output := OS.get_environment("STEAM_RECEIPT_TEST_OUTPUT")
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null: quit(1); return
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print("[steam receipt outbox QA] ", JSON.stringify(report))
	quit(0 if failed == 0 else 1)
