extends RefCounted
## Real Receipt reducer only: no Ledger, Store, filesystem, SDK or Battle.
const Receipt := preload("res://scripts/steam_run_receipt.gd")
const Catalog := preload("res://scripts/steam_achievement_catalog.gd")
const OWNER := "76561198000000001"
var checks: Array = []
var observations: Dictionary = {}

static func run_case() -> Dictionary:
	return new().run()

func check(value: bool, label: String) -> bool:
	checks.append({"label":label, "passed":value})
	return value

func targets() -> Dictionary:
	var stats := {}; var unlocked := {}
	for name in Catalog.STATS: stats[name] = 0
	for row in Catalog.entries(): unlocked[row.id] = false
	stats.TOTAL_WINS = 10
	return {"stats":stats, "unlocked":unlocked}

func commit(model: RefCounted, proposal: Dictionary, label: String) -> bool:
	observations[label + "_proposal"] = proposal.duplicate(true)
	if not check(proposal.get("ok",false), label + " prepare"): return false
	if proposal.get("changed",false):
		if not check(model.commit(proposal.record, proposal.sha256).get("ok",false), label + " model commit"): return false
	observations[label + "_after"] = model.capture()
	return true

func run() -> Dictionary:
	var authoritative := targets()
	var old := targets()
	old.unlocked.ACH_WINS_10 = true
	var model := Receipt.new()
	check(model.create(OWNER,old.stats,old.unlocked).get("ok",false), "create existing ten-win model")
	observations["before_invalidation"] = model.capture()
	commit(model, model.prepare_server_invalidation(OWNER), "invalidate")
	var invalid: Dictionary = model.capture()
	commit(model, model.prepare_server_correction(OWNER,authoritative.stats,authoritative.unlocked,invalid.generation), "correct")
	var corrected: Dictionary = model.capture()
	check(corrected.correction_epoch == 1 and not corrected.requires_correction and corrected.stats.TOTAL_WINS == 10 \
		and not corrected.unlocked.ACH_WINS_10, "authority revokes achievement while retaining ten wins")
	# These are the same reducer calls used immediately after Service adoption
	# correction, then again by complete_campaign_startup. No invented reducer.
	commit(model, model.prepare_remote_floor(OWNER,authoritative.stats,authoritative.unlocked,corrected.generation), "adoption_merge")
	var after_adoption: Dictionary = model.capture()
	commit(model, model.prepare_remote_floor(OWNER,authoritative.stats,authoritative.unlocked,after_adoption.generation), "completion_merge")
	var after_completion: Dictionary = model.capture()
	var reopened := Receipt.new()
	check(reopened.open_record(after_completion, OWNER).get("ok",false), "reopen actual strict v3 model data")
	commit(reopened, reopened.prepare_remote_floor(OWNER,authoritative.stats,authoritative.unlocked,after_completion.generation), "restart_merge")
	var after_restart: Dictionary = reopened.capture()
	# Preserve the pre-correction behavior as a positive compatibility control.
	var ordinary := Receipt.new()
	check(ordinary.create(OWNER,authoritative.stats,authoritative.unlocked).get("ok",false), "create ordinary epoch-zero model")
	commit(ordinary, ordinary.prepare_remote_floor(OWNER,authoritative.stats,authoritative.unlocked,0), "ordinary_merge")
	var epoch_zero_ok: bool = ordinary.capture().unlocked.ACH_WINS_10 and ordinary.capture().correction_epoch == 0
	check(epoch_zero_ok, "epoch-zero remote floor still derives ordinary milestone")
	var setup_ok: bool = checks.all(func(row): return row.passed)
	var bug: bool = setup_ok and not corrected.unlocked.ACH_WINS_10 and after_adoption.unlocked.ACH_WINS_10
	var fixed: bool = setup_ok and not after_adoption.unlocked.ACH_WINS_10 and not after_completion.unlocked.ACH_WINS_10 \
		and not after_restart.unlocked.ACH_WINS_10 and after_restart.stats == authoritative.stats \
		and after_restart.unlocked == authoritative.unlocked and after_restart.correction_epoch == 1
	return {"setup_ok":setup_ok, "bug_reproduced":bug, "fixed_behavior_ok":fixed, "checks":checks,
		"observations":observations, "real_receipt_reducer":true, "synthetic_ledger":false,
		"filesystem_exercised":false, "sdk_exercised":false, "service_executed":false,
		"scenario":"authoritative false at TOTAL_WINS=10, followed by adoption/completion/restart remote floor"}
