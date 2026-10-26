extends RefCounted
## Real LocalRunSession + real Receipt reducer, with an explicitly synthetic,
## memory-only Ledger seam. No disk, native SDK, Battle or ordinary play is tested.
## Load in the frozen candidate project; res:// resolves its unchanged scripts.
const LocalSession := preload("res://scripts/steam_local_run_session.gd")
const Catalog := preload("res://scripts/steam_achievement_catalog.gd")
const OWNER := "76561198000000001"
const CONTEXT := {"mode":"defense", "level_id":"", "waves":30}
const TOKEN_A := "00000000000000000000000000000001"
const TOKEN_B := "00000000000000000000000000000002"
var checks: Array = []
var observations: Dictionary = {}

class FakeLedger extends RefCounted:
	const Model := preload("res://scripts/steam_run_receipt.gd")
	var model: RefCounted = Model.new()
	var created: Dictionary = {}
	var pending: Dictionary = {}
	var history: Array = []
	var failures: Array = ["progress:10"]
	var retry_failures := 0
	var next_token := 1

	func _init(owner: String, targets: Dictionary) -> void:
		created = model.create(owner, targets.stats, targets.unlocked)

	func pending_status() -> Dictionary:
		return {"ok":true, "pending":not pending.is_empty(),
			"kind":"other" if not pending.is_empty() else "", "unsafe":false}

	func _failure() -> Dictionary:
		return {"ok":false, "code":"WRITE_OPEN", "retryable":true,
			"pending_save":true, "pending_kind":"other", "synthetic_in_memory_failure":true}

	func _start(kind: String, scope: Dictionary, proposal: Dictionary, fields: Dictionary = {}) -> Dictionary:
		history.append({"event":"prepare", "kind":kind, "scope":scope.duplicate(true),
			"proposal":proposal.duplicate(true), "model_before_commit":model.capture()})
		if not proposal.get("ok", false): return proposal
		if not proposal.get("changed", false): return proposal
		pending = {"kind":kind, "scope":scope.duplicate(true),
			"proposal":proposal.duplicate(true), "success_fields":fields.duplicate(true)}
		var failure_key: String = kind + (":" + str(scope.kills) if kind == "progress" else "")
		if failures.has(failure_key):
			failures.erase(failure_key)
			history.append({"event":"synthetic_failure_before_commit", "pending":pending.duplicate(true)})
			return _failure()
		return _finish_pending()

	func _finish_pending() -> Dictionary:
		if pending.is_empty(): return {"ok":false, "code":"NO_PENDING_WRITE"}
		var committed: Dictionary = model.commit(pending.proposal.record, pending.proposal.sha256)
		if not committed.get("ok", false): return committed
		var result := {"ok":true, "code":"COMMITTED", "changed":true,
			"generation":model.capture().generation}
		result.merge(pending.success_fields)
		history.append({"event":"commit", "pending":pending.duplicate(true), "model_after":model.capture()})
		pending.clear()
		return result

	func retry_pending() -> Dictionary:
		history.append({"event":"retry", "pending":pending.duplicate(true), "model_before":model.capture()})
		if pending.is_empty(): return {"ok":false, "code":"NO_PENDING_WRITE"}
		if retry_failures > 0:
			retry_failures -= 1
			history.append({"event":"synthetic_retry_failure", "pending":pending.duplicate(true)})
			return _failure()
		return _finish_pending()

	func begin_run(context: Dictionary) -> Dictionary:
		if not pending.is_empty(): return {"ok":false, "code":"NOT_READY"}
		var token: String = "%032x" % next_token
		next_token += 1
		return _start("begin", {"context":context.duplicate(true)}, model.prepare_begin(token, context), {"token":token})

	func progress(token: String, context: Dictionary, kills: Variant) -> Dictionary:
		if not pending.is_empty(): return {"ok":false, "code":"NOT_READY"}
		return _start("progress", {"token":token, "context":context.duplicate(true), "kills":kills},
			model.prepare_progress(token, context, kills))

	func settle(token: String, context: Dictionary, victory: bool, result: Dictionary) -> Dictionary:
		if not pending.is_empty(): return {"ok":false, "code":"NOT_READY"}
		return _start("settle", {"token":token, "context":context.duplicate(true),
			"victory":victory, "result":result.duplicate(true)}, model.prepare_settle(token, context, victory, result))

	func capture() -> Dictionary:
		if not pending.is_empty(): return {"ok":false, "code":"NOT_READY"}
		var record: Dictionary = model.capture()
		return {"ok":true, "record":record, "file_sha256":JSON.stringify(record).sha256_text(),
			"hash_is_synthetic_model_json_not_file":true}

	func can_resume(token: String, owner: String, context: Dictionary) -> Dictionary:
		if not pending.is_empty(): return {"ok":false, "code":"NOT_READY"}
		return model.can_resume(token, owner, context)

static func run_case() -> Dictionary:
	return new().run()

func check(value: bool, label: String, kind := "setup") -> bool:
	checks.append({"label":label, "passed":value, "kind":kind})
	return value

func targets() -> Dictionary:
	var stats := {}; var unlocked := {}
	for name in Catalog.STATS: stats[name] = 0
	for row in Catalog.entries(): unlocked[row.id] = false
	return {"stats":stats, "unlocked":unlocked}

func snapshot(env: Dictionary, step: String, result: Dictionary = {}) -> Dictionary:
	var session: RefCounted = env.session
	var ledger: FakeLedger = env.ledger
	var row := {"step":step, "result":result.duplicate(true),
		"session":{"token":session._token, "context":session._context.duplicate(true),
			"pending_kills":session._pending_kills, "terminal":session._terminal.duplicate(true),
			"last_terminal":session._last_terminal.duplicate(true), "settled":session._settled,
			"dirty":session._dirty, "has_pending":session.has_pending(),
			"operation":session._operation.duplicate(true), "checkpoint":session._checkpoint.duplicate(true)},
		"model":ledger.model.capture(), "model_pending":ledger.model._pending.duplicate(true),
		"model_pending_sha256":ledger.model._pending_sha,
		"ledger_pending":ledger.pending.duplicate(true), "remaining_faults":ledger.failures.duplicate(),
		"retry_faults":ledger.retry_failures, "history":ledger.history.duplicate(true)}
	observations[env.name].append(row)
	return row

func prepare_case(name: String) -> Dictionary:
	observations[name] = []
	var ledger := FakeLedger.new(OWNER, targets())
	var session: RefCounted = LocalSession.new()
	# Deliberate test seam: production Session methods are unchanged. The fake
	# models only Ledger's retained proposal/commit contract, never native I/O.
	session._ledger = ledger
	session._owner = OWNER
	var env := {"name":name, "ledger":ledger, "session":session, "setup_ok":true}
	check(ledger.created.get("ok", false), name + " real Receipt blank model")
	var begun: Dictionary = session.begin(CONTEXT)
	snapshot(env, "begin_A", begun)
	env.setup_ok = check(begun.get("ok", false) and begun.get("token", "") == TOKEN_A, name + " begin A") and env.setup_ok
	var observed: Dictionary = session.observe(10)
	snapshot(env, "observe_10", observed)
	env.setup_ok = check(observed.get("ok", false), name + " observe ten") and env.setup_ok
	var failed: Dictionary = session.checkpoint()
	var retained: Dictionary = snapshot(env, "checkpoint_10_transient_failure", failed)
	var frozen_ok: bool = not failed.get("ok", true) and failed.get("code") == "WRITE_OPEN" \
		and not ledger.pending.is_empty() and ledger.pending.kind == "progress" \
		and ledger.pending.scope.kills == 10 and ledger.pending.proposal.record.runs[TOKEN_A].credited_kills == 10 \
		and retained.model.runs[TOKEN_A].credited_kills == 0 and session._checkpoint.kills == 10
	env.setup_ok = check(frozen_ok, name + " original progress ten exact proposal retained before commit") and env.setup_ok
	observed = session.observe(11)
	snapshot(env, "observe_11_while_10_retained", observed)
	env.setup_ok = check(observed.get("ok", false), name + " newer eleven observed") and env.setup_ok
	var terminal: Dictionary = session.queue_terminal(true, {})
	snapshot(env, "queue_victory_while_10_retained", terminal)
	env.setup_ok = check(terminal.get("ok", false) and session._pending_kills == 11 \
		and session._terminal == {"victory":true, "result":{}} and session._checkpoint.terminal.is_empty(),
		name + " current tail differs from frozen older checkpoint") and env.setup_ok
	return env

func a_complete(env: Dictionary) -> bool:
	var ledger: FakeLedger = env.ledger
	var record: Dictionary = ledger.model.capture()
	var row: Dictionary = record.runs.get(TOKEN_A, {})
	return row.get("credited_kills", -1) == 11 and row.get("terminal", false) and row.get("victory", false) \
		and record.stats.TOTAL_KILLS == 11 and record.stats.TOTAL_WINS == 1 and record.stats.DEFENSE_WINS == 1

func a_retained(env: Dictionary) -> bool:
	var session: RefCounted = env.session
	return session._token == TOKEN_A and session._pending_kills == 11 \
		and session._terminal == {"victory":true, "result":{}} and session.has_pending() and not session._settled

func no_b(env: Dictionary) -> bool:
	var ledger: FakeLedger = env.ledger
	return not ledger.model.capture().runs.has(TOKEN_B)

func drained(env: Dictionary) -> bool:
	var session: RefCounted = env.session
	var ledger: FakeLedger = env.ledger
	return not session.has_pending() and session._operation.is_empty() and session._checkpoint.is_empty() \
		and session._terminal.is_empty() and ledger.pending.is_empty()

func checkpoint_case() -> Dictionary:
	var env := prepare_case("checkpoint_current_tail")
	var session: RefCounted = env.session
	var first: Dictionary = session.checkpoint()
	snapshot(env, "one_checkpoint_after_tail_arrived", first)
	var fully_committed: bool = a_complete(env) and drained(env)
	var safely_refused: bool = not first.get("ok", true) and a_retained(env) and no_b(env)
	var first_safe: bool = (first.get("ok", false) and fully_committed) or safely_refused
	check(first_safe, env.name + " success means current tail committed, or explicit failure preserves tail", "contract")
	var false_success: bool = first.get("ok", false) and not fully_committed
	var recover: Dictionary = session.checkpoint()
	snapshot(env, "explicit_followup_checkpoint", recover)
	var recovered: bool = recover.get("ok", false) and a_complete(env) and drained(env) and no_b(env)
	check(recovered, env.name + " retained tail completes on explicit retry without new run", "contract")
	return {"setup_ok":env.setup_ok, "bug_reproduced":env.setup_ok and false_success,
		"fixed_behavior_ok":env.setup_ok and first_safe and recovered,
		"first_call_false_success":false_success, "tail_recovered_on_followup":recovered}

func begin_case() -> Dictionary:
	var env := prepare_case("begin_preserves_previous_tail")
	var session: RefCounted = env.session
	var first: Dictionary = session.begin(CONTEXT)
	snapshot(env, "begin_B_with_A_retained", first)
	var accepted: bool = first.get("ok", false)
	var accepted_safe: bool = accepted and first.get("token", "") == TOKEN_B and a_complete(env) and drained(env)
	var refused_safe: bool = not accepted and a_retained(env) and no_b(env)
	var first_safe: bool = accepted_safe or refused_safe
	check(first_safe, env.name + " B either starts after A commit or is refused without clearing A", "contract")
	var lost_tail: bool = accepted and not a_complete(env) and not a_retained(env)
	var eventual_start_ok: bool = accepted_safe
	if not accepted:
		var recover: Dictionary = session.checkpoint()
		snapshot(env, "explicit_checkpoint_after_B_refusal", recover)
		var recovered: bool = recover.get("ok", false) and a_complete(env) and drained(env)
		var second: Dictionary = session.begin(CONTEXT)
		snapshot(env, "begin_B_after_explicit_checkpoint", second)
		eventual_start_ok = recovered and second.get("ok", false) and second.get("token", "") == TOKEN_B and a_complete(env) and drained(env)
	check(eventual_start_ok, env.name + " B can start after durable A, including explicit recovery after refusal", "contract")
	return {"setup_ok":env.setup_ok, "bug_reproduced":env.setup_ok and lost_tail,
		"fixed_behavior_ok":env.setup_ok and first_safe and eventual_start_ok,
		"new_token_lost_A_tail":lost_tail, "eventual_B_started_safely":eventual_start_ok}

func second_failure_case() -> Dictionary:
	var env := prepare_case("second_batch_failure_exact_retry")
	var session: RefCounted = env.session
	var ledger: FakeLedger = env.ledger
	# A second, independent transient failure occurs after old progress ten has
	# completed and the current batch reaches its terminal proposal (one win).
	ledger.failures.append("settle")
	var first: Dictionary = session.checkpoint()
	snapshot(env, "drain_old_and_current_batch_with_settle_failure", first)
	var first_safe: bool = not first.get("ok", true) and a_retained(env) and no_b(env)
	check(first_safe, env.name + " second batch fault cannot return successful checkpoint", "contract")
	var false_success: bool = first.get("ok", false) and not a_complete(env)
	var reached_during_first: bool = not ledger.pending.is_empty() and ledger.pending.kind == "settle"
	if not reached_during_first:
		# Diagnostic continuation of the old baseline; it does not excuse the
		# preceding false success. It also supports an explicit retry-required API.
		var followup: Dictionary = session.checkpoint()
		snapshot(env, "explicit_followup_reaches_second_batch", followup)
	var has_settle: bool = not ledger.pending.is_empty() and ledger.pending.kind == "settle"
	var current: Dictionary = ledger.model.capture()
	var setup_second: bool = has_settle and current.runs[TOKEN_A].credited_kills == 11 \
		and not current.runs[TOKEN_A].terminal and current.stats.TOTAL_WINS == 0 \
		and ledger.pending.proposal.record.runs[TOKEN_A].terminal \
		and ledger.pending.proposal.record.stats.TOTAL_WINS == 1
	check(setup_second, env.name + " real terminal proposal contains exactly one not-yet-committed win")
	var exact: Dictionary = ledger.pending.duplicate(true)
	var model_pending: Dictionary = ledger.model._pending.duplicate(true)
	var model_sha: String = ledger.model._pending_sha
	var checkpoint_before: Dictionary = session._checkpoint.duplicate(true)
	var operation_before: Dictionary = session._operation.duplicate(true)
	ledger.retry_failures = 1
	var retry_failed: Dictionary = session.checkpoint()
	snapshot(env, "same_terminal_proposal_retry_fails_again", retry_failed)
	var retained_exact: bool = not retry_failed.get("ok", true) and ledger.pending == exact \
		and ledger.model._pending == model_pending and ledger.model._pending_sha == model_sha \
		and ledger.model.capture() == current and session._checkpoint == checkpoint_before \
		and session._operation == operation_before and a_retained(env) and no_b(env)
	check(retained_exact, env.name + " retry failure retains exact proposal, model basis and Session request", "contract")
	var retry: Dictionary = session.checkpoint()
	snapshot(env, "retry_exact_terminal_proposal_success", retry)
	var once: bool = retry.get("ok", false) and a_complete(env) and drained(env) and no_b(env)
	check(once, env.name + " successful retry commits eleven kills and exactly one defense win", "contract")
	var after: Dictionary = ledger.model.capture()
	var duplicate: Dictionary = session.queue_terminal(true, {})
	snapshot(env, "repeat_identical_terminal", duplicate)
	var repeat_checkpoint: Dictionary = session.checkpoint()
	snapshot(env, "checkpoint_after_already_committed_terminal", repeat_checkpoint)
	var idempotent: bool = duplicate.get("ok", false) and not duplicate.get("changed", true) \
		and repeat_checkpoint.get("ok", false) and ledger.model.capture() == after and drained(env)
	check(idempotent, env.name + " repeated terminal/checkpoint changes neither counters nor generation", "contract")
	var setup_ok: bool = env.setup_ok and setup_second
	return {"setup_ok":setup_ok, "bug_reproduced":setup_ok and false_success,
		"fixed_behavior_ok":setup_ok and first_safe and retained_exact and once and idempotent,
		"second_fault_reached_during_first_call":reached_during_first,
		"first_call_false_success":false_success, "exact_proposal_retained":retained_exact,
		"one_win_after_retry":once, "duplicate_is_exact_noop":idempotent}

func run() -> Dictionary:
	var case_results := {"checkpoint":checkpoint_case(), "begin":begin_case(), "second_failure":second_failure_case()}
	var setup_ok := true
	var bugs := true
	var fixed := true
	for name in case_results:
		var row: Dictionary = case_results[name]
		setup_ok = setup_ok and row.setup_ok
		bugs = bugs and row.bug_reproduced
		fixed = fixed and row.fixed_behavior_ok
	for row in checks:
		if row.kind == "setup": setup_ok = setup_ok and row.passed
	return {"schema":"local_session_retained_tail_synthetic_cases_v1", "setup_ok":setup_ok,
		"bug_reproduced":setup_ok and bugs, "fixed_behavior_ok":setup_ok and fixed,
		"case_results":case_results, "checks":checks, "observations":observations,
		"real_local_run_session":true, "real_receipt_reducer":true, "synthetic_ledger":true,
		"filesystem_exercised":false, "sdk_exercised":false, "service_executed":false,
		"native_runtime_qualified":false, "human_acceptance":false,
		"scope":"three independent in-memory sessions; retained progress ten, newer eleven plus victory; checkpoint/begin/second-batch retry"}
