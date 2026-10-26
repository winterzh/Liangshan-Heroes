extends RefCounted
## Pure-model tests only. No filesystem, SDK, Battle, timer, or engine launch.
## Load from an approved frozen project's external bootstrap, then call run_all().
const Receipt := preload("res://scripts/steam_run_receipt.gd")
const Catalog := preload("res://scripts/steam_achievement_catalog.gd")
const Legacy := preload("res://scripts/run_campaign_legacy_data.gd")
const OWNER := "76561198000000001"
const TOKEN := "11111111111111111111111111111111"
const CONTEXT := {"mode":"campaign", "level_id":"level4", "waves":0}
var checks: Array = []

func expect(ok: bool, label: String) -> bool:
	checks.append({"label":label, "passed":ok})
	return ok

func targets() -> Dictionary:
	var stats := {}; var unlocked := {}
	for name in Catalog.STATS: stats[name] = 0
	for row in Catalog.entries(): unlocked[row.id] = false
	return {"stats":stats, "unlocked":unlocked}

func fresh() -> RefCounted:
	var model := Receipt.new()
	var blank := targets()
	expect(model.create(OWNER, blank.stats, blank.unlocked).ok, "create version3 model")
	return model

func apply(model: RefCounted, proposal: Dictionary, label: String) -> bool:
	if not expect(proposal.ok, label + " prepare"): return false
	if not proposal.get("changed", false): return true
	return expect(model.commit(proposal.record, proposal.sha256).ok, label + " model commit")

func descriptor(model: RefCounted, victory := true, final_kills := 8) -> Dictionary:
	var row: Dictionary = model.capture()
	return {"schema":"campaign_steam_handoff_v1", "owner":OWNER, "token":TOKEN,
		"context":CONTEXT.duplicate(), "intent_sha256":"a".repeat(64), "correction_epoch":row.correction_epoch,
		"basis_generation":row.generation, "basis_sha256":"b".repeat(64),
		"basis_credited_kills":row.runs[TOKEN].credited_kills, "final_credited_kills":final_kills,
		"victory":victory, "result":{"core_cleared":victory, "story_complete":victory,
			"story_done":4 if victory else 0, "story_total":4,
			"done_ids":["lhm_training", "lhm_hooks", "lhm_han", "lhm_hu"] if victory else [], "contract_version":2}}

func legacy_fixture(profile_id: String, contract_version: int, generation := 3) -> Dictionary:
	var context := {"mode":"campaign", "level_id":"level1", "waves":0}
	var scope := {"owner":OWNER, "content_version":"historical-model-fixture", "engine_sha256":"d".repeat(64)}
	var intent := {"schema":"campaign_progress_intent_v1", "token":TOKEN, "context":context.duplicate(),
		"profile_id":profile_id, "owner":OWNER, "content_version":scope.content_version,
		"engine_sha256":scope.engine_sha256, "victory":true,
		"result":{"core_cleared":true, "story_complete":false, "story_done":1, "story_total":4,
			"done_ids":["merchant_cover"], "contract_version":contract_version}}
	var ack := {"schema":"campaign_progress_ack_v1", "code":"CAMPAIGN_CFG_READBACK_VERIFIED",
		"persisted":true, "suppressed":false, "file_sha256":"e".repeat(64)}
	return {"expected":{"context":context.duplicate(), "scope":scope.duplicate()},
		"document":{"schema":"local_campaign_continue_lifecycle_v2", "generation":generation,
			"token":TOKEN, "context":context, "scope":scope, "state":"terminal", "victory":true,
			"progress_state":"applied" if generation == 3 else "pending", "intent":intent,
			"progress_receipt":ack if generation == 3 else {}}}

func legacy_read_checks() -> void:
	for pair in [["campaign_level1_v1",2], ["campaign_level1_v2",3]]:
		var fixture := legacy_fixture(pair[0], pair[1])
		var original: Dictionary = fixture.document.duplicate(true)
		var read: Dictionary = Legacy.validate_document_data(fixture.document, TOKEN, fixture.expected)
		var label := String(pair[0]) + "/contract" + str(pair[1])
		if expect(read.ok, label + " historical applied gen3 reads"):
			expect(read.document == original and fixture.document == original, label + " preserves historical model without migration")
			expect(read.document.intent.profile_id == pair[0] and not read.document.intent.has("credit")
				and not read.document.progress_receipt.has("steam_handoff"), label + " never fabricates credit or handoff")
		var pending := legacy_fixture(pair[0], pair[1], 2)
		var pending_read: Dictionary = Legacy.validate_document_data(pending.document, TOKEN, pending.expected)
		expect(pending_read.ok and pending_read.document == pending.document, label + " gen2 is readable data only")
		# StartupScan's independent branch must reject this readable gen2 as
		# LEGACY_CAMPAIGN_HANDOFF_UNBOUND; this pure model does not run filesystem scan.
		var crossed: Dictionary = fixture.document.duplicate(true)
		crossed.intent.result.contract_version = 3 if pair[1] == 2 else 2
		expect(not Legacy.validate_document_data(crossed, TOKEN, fixture.expected).ok, label + " rejects crossed profile/contract")
		for field_scope in ["document", "context", "intent", "result"]:
			var extra: Dictionary = fixture.document.duplicate(true)
			match field_scope:
				"document": extra["extra"] = true
				"context": extra.context["extra"] = true
				"intent": extra.intent["credit"] = {"kind":"uncredited"}
				"result": extra.intent.result["extra"] = true
			expect(not Legacy.validate_document_data(extra, TOKEN, fixture.expected).ok, label + " rejects extra " + field_scope + " field")

func run_all() -> Dictionary:
	checks.clear()
	legacy_read_checks()
	var model := fresh()
	apply(model, model.prepare_begin(TOKEN, CONTEXT), "begin ordinary run")
	apply(model, model.prepare_progress(TOKEN, CONTEXT, 5), "five real-model eligible kills")
	var handoff := descriptor(model)
	var before: Dictionary = model.capture()
	var prepared: Dictionary = model.prepare_campaign_handoff(handoff)
	expect(model.capture() == before, "prepare has no committed mutation")
	apply(model, prepared, "one campaign handoff")
	var after: Dictionary = model.capture()
	expect(after.generation == before.generation + 1, "kills and outcome share one proposal generation")
	expect(after.stats.TOTAL_KILLS == 8 and after.stats.TOTAL_WINS == 1, "only final three kill delta and one win")
	expect(after.unlocked.ACH_CLEAR_LEVEL_4 and after.unlocked.ACH_STORY_LEVEL_4, "clear and story flags present")
	expect(after.runs[TOKEN].terminal_reason == "settled", "explicit normal terminal source")
	var repeated: Dictionary = model.prepare_campaign_handoff(handoff)
	expect(repeated.ok and not repeated.changed and model.capture() == after, "identical handoff is exact no-op")
	expect(model.campaign_handoff_proof(handoff).ok, "precise model proof present")
	var changed: Dictionary = handoff.duplicate(true)
	changed.intent_sha256 = "c".repeat(64)
	expect(not model.prepare_campaign_handoff(changed).ok and model.capture() == after, "other intent cannot use terminal shortcut")
	changed = handoff.duplicate(true); changed.final_credited_kills += 1
	expect(not model.prepare_campaign_handoff(changed).ok, "changed final highwater refused")
	changed = handoff.duplicate(true); changed["extra"] = false
	expect(not model.normalize_campaign_handoff(changed).ok, "unknown descriptor field refused")
	changed = handoff.duplicate(true); changed.basis_sha256 = "B".repeat(64)
	expect(not model.normalize_campaign_handoff(changed).ok, "uppercase digest outside canonical descriptor domain")
	changed = handoff.duplicate(true); changed.result.done_ids[1] = changed.result.done_ids[0]
	expect(not model.normalize_campaign_handoff(changed).ok, "duplicate result ID refused")
	changed = handoff.duplicate(true); changed.result.story_done = 3.5
	expect(not model.normalize_campaign_handoff(changed).ok, "fractional result counter refused")
	var loss := fresh()
	apply(loss, loss.prepare_begin(TOKEN, CONTEXT), "begin loss run")
	var lost := descriptor(loss, false, 4)
	apply(loss, loss.prepare_campaign_handoff(lost), "losing handoff")
	expect(loss.capture().stats.TOTAL_KILLS == 4 and loss.capture().stats.TOTAL_WINS == 0, "loss records final kills without win")
	expect(not loss.capture().unlocked.ACH_CLEAR_LEVEL_4 and loss.campaign_handoff_proof(lost).ok, "loss has proof without clear award")
	var legacy: Dictionary = after.duplicate(true)
	legacy.version = 2; legacy.erase("correction_epoch")
	for token in legacy.runs:
		legacy.runs[token].erase("terminal_reason"); legacy.runs[token].erase("settlement")
	var reader := Receipt.new()
	expect(reader.open_record(legacy, OWNER).ok and reader.capture() == legacy, "v2 read remains byte-model schema2")
	expect(reader.prepare_progress(TOKEN, CONTEXT, 99).get("code") == "RECEIPT_UPGRADE_REQUIRED", "v2 events require explicit upgrade")
	apply(reader, reader.prepare_upgrade(), "explicit legacy upgrade")
	var upgraded: Dictionary = reader.capture()
	expect(upgraded.version == 3 and upgraded.generation == legacy.generation + 1, "upgrade adds exactly one generation")
	expect(upgraded.stats == legacy.stats and upgraded.unlocked == legacy.unlocked, "upgrade preserves aggregate targets")
	expect(upgraded.runs[TOKEN].terminal_reason == "legacy_unknown" and upgraded.runs[TOKEN].settlement.is_empty(), "ambiguous v2 terminal never guessed settled")
	expect(not reader.campaign_handoff_proof(handoff).ok, "legacy terminal is not handoff proof")
	var no_upgrade: Dictionary = reader.prepare_upgrade()
	expect(no_upgrade.ok and not no_upgrade.changed and reader.capture() == upgraded, "repeated upgrade no-op")
	apply(model, model.prepare_server_invalidation(OWNER), "authoritative invalidation")
	var invalid: Dictionary = model.capture()
	expect(invalid.correction_epoch == 1 and invalid.runs[TOKEN].terminal_reason == "invalidated", "correction increments epoch and keeps explicit tombstone")
	expect(not model.campaign_handoff_proof(handoff).ok, "pending correction blocks prior proof")
	var same_notice: Dictionary = model.prepare_server_invalidation(OWNER)
	expect(same_notice.ok and not same_notice.changed and model.capture().correction_epoch == 1, "same pending correction does not increment epoch twice")
	var blank := targets()
	apply(model, model.prepare_server_correction(OWNER, blank.stats, blank.unlocked, invalid.generation), "authoritative correction")
	expect(model.capture().correction_epoch == 1 and model.capture().stats.TOTAL_WINS == 0, "correction preserves epoch and authoritative lowered target")
	expect(not model.prepare_campaign_handoff(handoff).ok, "old epoch cannot resurrect reward")
	changed = handoff.duplicate(true); changed.correction_epoch = 1
	expect(not model.prepare_campaign_handoff(changed).ok, "matching epoch still cannot resurrect invalidated token")
	var invalid_record: Dictionary = model.capture()
	invalid_record.runs[TOKEN].terminal_reason = "settled"
	expect(not Receipt.new().open_record(invalid_record, OWNER).ok, "tampered tombstone cannot become matching settled receipt")
	var classic := fresh()
	var defense := {"mode":"defense", "level_id":"", "waves":30}
	apply(classic, classic.prepare_begin(TOKEN, defense), "classic begin")
	apply(classic, classic.prepare_progress(TOKEN, defense, 2), "classic progress")
	apply(classic, classic.prepare_settle(TOKEN, defense, true, {}), "classic settlement")
	var classic_after: Dictionary = classic.capture()
	expect(classic_after.stats.TOTAL_WINS == 1 and classic_after.stats.DEFENSE_WINS == 1, "classic counters preserved")
	expect(classic.prepare_settle(TOKEN, defense, true, {}).ok and classic.capture() == classic_after, "classic duplicate behavior preserved")
	expect(Receipt.new().open_record(classic_after, OWNER).ok, "v3 ordinary terminal validates")
	var passed := true
	for row in checks: passed = passed and row.passed
	return {"schema":"campaign_handoff_model_tests_v1", "passed":passed, "checks":checks,
		"pure_model_only":true, "filesystem_or_sdk_exercised":false, "native_runtime_qualified":false}
