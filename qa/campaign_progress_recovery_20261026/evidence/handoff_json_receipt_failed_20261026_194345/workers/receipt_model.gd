extends RefCounted
## Pure-model tests only. No filesystem, SDK, Battle, timer, or engine launch.
## Load from an approved frozen project's external bootstrap, then call run_all().
const Receipt := preload("res://scripts/steam_run_receipt.gd")
const Catalog := preload("res://scripts/steam_achievement_catalog.gd")
const Legacy := preload("res://scripts/run_campaign_legacy_data.gd")
const CampaignIntent := preload("res://scripts/run_campaign_progress_intent.gd")
const CampaignLifecycle := preload("res://scripts/run_campaign_local_lifecycle.gd")
const OWNER := "76561198000000001"
const TOKEN := "11111111111111111111111111111111"
const CONTEXT := {"mode":"campaign", "level_id":"level4", "waves":0}
var checks: Array = []
var lifecycle_json_evidence: Array = []
var receipt_json_evidence: Dictionary = {}

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

func lifecycle_json_roundtrip_checks() -> void:
	# These dictionaries are synthetic model inputs, including all owner/token,
	# receipt hashes, epoch and claimed credit. No actual save or SDK is opened.
	for kind in ["uncredited", "steam"]:
		var scope := {"owner":OWNER, "content_version":"synthetic-lifecycle-json-roundtrip", "engine_sha256":"d".repeat(64)}
		var expected := {"ok":true, "context":CONTEXT.duplicate(), "profile_id":"campaign_level4_v1", "scope":scope.duplicate()}
		var credit: Dictionary = {"kind":"uncredited"}
		if kind == "steam":
			credit = {"kind":"steam", "binding":{"kind":"steam", "owner":OWNER, "token":TOKEN,
				"credited_kills":8, "generation":7, "receipt_sha256":"b".repeat(64)}, "correction_epoch":2}
		var input_intent := {"schema":"campaign_progress_intent_v2", "token":TOKEN, "context":CONTEXT.duplicate(),
			"profile_id":"campaign_level4_v1", "owner":OWNER, "content_version":scope.content_version,
			"engine_sha256":scope.engine_sha256, "victory":true, "credit":credit,
			"result":{"core_cleared":true, "story_complete":false, "story_done":1, "story_total":4,
				"done_ids":["lhm_training"], "contract_version":2}}
		var checked_intent: Dictionary = CampaignIntent.validate(input_intent, TOKEN, expected)
		var label: String = "synthetic " + kind + " lifecycle gen3 JSON"
		if not expect(checked_intent.ok, label + " strict Intent v2 fixture validates"): continue
		var intent: Dictionary = checked_intent.intent
		var proof: Dictionary = CampaignIntent.uncredited_proof(intent)
		if kind == "steam":
			var handoff: Dictionary = CampaignIntent.handoff_descriptor(intent)
			proof = {"schema":"campaign_steam_handoff_proof_v1", "owner":OWNER, "token":TOKEN,
				"context":CONTEXT.duplicate(), "intent_sha256":JSON.stringify(intent).sha256_text(),
				"descriptor_sha256":JSON.stringify(handoff).sha256_text(), "correction_epoch":2,
				"ledger_document_generation":8, "ledger_file_sha256":"c".repeat(64)}
		expect(CampaignIntent.validate_handoff_proof(proof, intent).ok, label + " synthetic proof has valid strict data shape")
		var document := {"schema":"local_campaign_continue_lifecycle_v3", "generation":3, "token":TOKEN,
			"context":CONTEXT.duplicate(), "scope":scope, "state":"terminal", "victory":true,
			"progress_state":"applied", "intent":intent,
			"progress_receipt":{"schema":"campaign_progress_ack_v2", "code":"CAMPAIGN_CFG_READBACK_VERIFIED",
				"persisted":true, "suppressed":false, "file_sha256":"e".repeat(64), "steam_handoff":proof}}
		var direct: Dictionary = CampaignLifecycle.validate_document_data(document, TOKEN, expected)
		expect(direct.ok, label + " strict v3 document validates before serialization")
		for mutation in ["context_extra", "context_level", "context_fractional_waves", "intent_digest"]:
			var invalid: Dictionary = document.duplicate(true)
			var invalid_proof: Dictionary = invalid.progress_receipt.steam_handoff
			match mutation:
				"context_extra": invalid_proof.context["extra"] = true
				"context_level": invalid_proof.context.level_id = "level3"
				"context_fractional_waves": invalid_proof.context.waves = 0.5
				"intent_digest": invalid_proof.intent_sha256 = "f".repeat(64)
			expect(not CampaignLifecycle.validate_document_data(invalid, TOKEN, expected).ok,
				label + " rejects proof " + String(mutation))
		if kind == "steam":
			var fractional_epoch: Dictionary = document.duplicate(true)
			fractional_epoch.progress_receipt.steam_handoff.correction_epoch = 2.5
			expect(not CampaignLifecycle.validate_document_data(fractional_epoch, TOKEN, expected).ok,
				label + " rejects fractional proof epoch")
		var raw := JSON.stringify(document)
		var parser := JSON.new()
		if not expect(parser.parse(raw) == OK, label + " canonical string parses"): continue
		var decoded: Dictionary = parser.data
		var read: Dictionary = CampaignLifecycle.validate_document_data(decoded, TOKEN, expected)
		expect(read.ok, label + " parsed document validates: " + String(read.get("code", "OK")))
		var encoded := JSON.stringify(read.document) if read.ok else ""
		expect(read.ok and encoded == raw, label + " stringify parse validate stringify preserves exact original bytes")
		var normalized_intent: Dictionary = CampaignIntent.validate(decoded.intent, TOKEN, expected)
		var normalized_ack: Dictionary = {}
		if normalized_intent.ok:
			normalized_ack = CampaignLifecycle._validate_ack(decoded.progress_receipt, normalized_intent.intent)
		lifecycle_json_evidence.append({"kind":kind, "synthetic_model_only":true, "real_save_or_sdk_qualified":false,
			"before_json":raw, "before_sha256":raw.sha256_text(), "after_json":encoded,
			"validator":read, "raw_intent_sha256":JSON.stringify(decoded.intent).sha256_text(),
			"normalized_intent_sha256":JSON.stringify(normalized_intent.get("intent",{})).sha256_text(),
			"stored_proof_intent_sha256":decoded.progress_receipt.steam_handoff.intent_sha256,
			"parsed_context_waves_type":typeof(decoded.context.waves),
			"parsed_proof_context_waves_type":typeof(decoded.progress_receipt.steam_handoff.context.waves),
			"parsed_credit_epoch_type":typeof(decoded.intent.credit.get("correction_epoch")),
			"parsed_proof_epoch_type":typeof(decoded.progress_receipt.steam_handoff.get("correction_epoch")),
			"parsed_proof_generation_type":typeof(decoded.progress_receipt.steam_handoff.get("ledger_document_generation")),
			"normalized_ack_diagnostic":normalized_ack})

func run_all() -> Dictionary:
	checks.clear()
	lifecycle_json_evidence.clear()
	receipt_json_evidence.clear()
	legacy_read_checks()
	lifecycle_json_roundtrip_checks()
	var model := fresh()
	apply(model, model.prepare_begin(TOKEN, CONTEXT), "begin ordinary run")
	apply(model, model.prepare_progress(TOKEN, CONTEXT, 5), "five real-model eligible kills")
	var handoff := descriptor(model)
	var before: Dictionary = model.capture()
	var prepared: Dictionary = model.prepare_campaign_handoff(handoff)
	expect(model.capture() == before, "prepare has no committed mutation")
	apply(model, prepared, "one campaign handoff")
	var after: Dictionary = model.capture()
	# Same bytes the native Store writes and reads. These are still synthetic
	# model documents; no receipt file, real account or SDK is being qualified.
	var receipt_raw := JSON.stringify(after)
	var receipt_decoded: Variant = JSON.parse_string(receipt_raw)
	var receipt_reader := Receipt.new()
	var receipt_opened: Dictionary = receipt_reader.open_record(receipt_decoded, OWNER)
	expect(receipt_opened.ok, "synthetic handoff receipt JSON read validates: " + String(receipt_opened.get("code", "OK")))
	var receipt_reencoded := JSON.stringify(receipt_reader.capture()) if receipt_opened.ok else ""
	expect(receipt_opened.ok and receipt_reencoded == receipt_raw, "synthetic handoff receipt JSON roundtrip preserves exact canonical bytes")
	var wrong_handoff: Dictionary = handoff.duplicate(true); wrong_handoff.intent_sha256 = "f".repeat(64)
	expect(receipt_opened.ok and receipt_reader.campaign_handoff_proof(handoff).ok \
		and not receipt_reader.campaign_handoff_proof(wrong_handoff).ok, "JSON-read receipt proves exact handoff and rejects wrong intent digest")
	receipt_json_evidence = {"synthetic_model_only":true, "real_save_or_sdk_qualified":false,
		"before_json":receipt_raw, "before_sha256":receipt_raw.sha256_text(), "after_json":receipt_reencoded,
		"open_result":receipt_opened, "parsed_run_context_waves_type":typeof(receipt_decoded.runs[TOKEN].context.waves),
		"parsed_handoff_context_waves_type":typeof(receipt_decoded.runs[TOKEN].settlement.handoff.context.waves)}
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
		"pure_model_only":true, "filesystem_or_sdk_exercised":false, "native_runtime_qualified":false,
		"lifecycle_json_roundtrips":lifecycle_json_evidence, "receipt_json_roundtrip":receipt_json_evidence}
