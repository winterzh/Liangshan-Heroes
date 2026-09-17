extends RefCounted
## Pure receipt transaction model. No disk, SDK or Battle calls.
## The host must atomically persist/read back a prepared record before commit(),
## then use publish_targets(). capture() is persistence/debug data, never an SDK queue.
## Owner and context originate from live SDK identity and the trusted launch policy,
## never from a battle slot. The separate latest receipt must not roll back with a slot.
## One serialized host writer owns preparation/persistence/commit and SDK read epochs.
## Result 8: invalidate -> persist/commit -> authoritative read -> correct -> persist/commit.
## A crash after receiving 8 but before persisting invalidation is a HOST-UNSOLVED
## boundary. This pure model cannot make a callback and disk write atomic.
const Catalog = preload("res://scripts/steam_achievement_catalog.gd")
const AchievementState = preload("res://scripts/steam_achievement_state.gd")
const VERSION := 2
const LIMIT := 2147483647
const MAX_RUNS := 10000
const ROOT_FIELDS := ["version", "owner", "generation", "requires_correction", "stats", "unlocked", "runs"]
const RUN_FIELDS := ["context", "credited_kills", "terminal", "victory"]
const CONTEXT_FIELDS := ["mode", "level_id", "waves"]
var _record: Dictionary = {}
var _pending: Dictionary = {}
var _pending_sha := ""
var _correction_notice := false

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func _keys(value: Variant, names: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != names.size(): return false
	for name in names:
		if not value.has(name): return false
	return true

func _number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT: return value >= 0 and value <= LIMIT
	return typeof(value) == TYPE_FLOAT and is_finite(value) and value >= 0.0 and value <= float(LIMIT) and value == floor(value)

func _owner(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() < 1 or value.length() > 20 or value.begins_with("0"): return false
	for c in value.to_utf8_buffer():
		if c < 48 or c > 57: return false
	return value.length() < 20 or value <= "18446744073709551615"

func _token(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 32: return false
	for c in value.to_utf8_buffer():
		if not (c >= 48 and c <= 57) and not (c >= 97 and c <= 102): return false
	return true

func _context(value: Variant) -> bool:
	if not _keys(value, CONTEXT_FIELDS): return false
	if typeof(value.mode) != TYPE_STRING or typeof(value.level_id) != TYPE_STRING or not _number(value.waves): return false
	match value.mode:
		"campaign": return value.level_id in ["level1", "level2", "level3", "level4", "level5", "level6", "level7", "level8"] and int(value.waves) == 0
		"defense": return value.level_id == "" and int(value.waves) in [20, 30, 60]
		"ai": return value.level_id == "" and int(value.waves) == 0
	return false

func _unlocked(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY: return false
	var ids := {}
	for entry in Catalog.entries(): ids[entry.id] = true
	if value.size() != ids.size(): return false
	for id in value:
		if not ids.has(id) or typeof(value[id]) != TYPE_BOOL: return false
	return true

func _stats(value: Variant) -> bool:
	if not _keys(value, Array(Catalog.STATS)): return false
	for name in Catalog.STATS:
		if not _number(value[name]): return false
	return true

func _validate(value: Variant, owner: String) -> Dictionary:
	if not _keys(value, ROOT_FIELDS): return _bad("RECORD_FIELDS")
	if not _number(value.version) or int(value.version) != VERSION: return _bad("RECORD_VERSION")
	if not _owner(owner) or typeof(value.owner) != TYPE_STRING or value.owner != owner: return _bad("OWNER")
	if not _number(value.generation): return _bad("GENERATION")
	if typeof(value.requires_correction) != TYPE_BOOL: return _bad("CORRECTION_FLAG")
	if not _stats(value.stats) or not _unlocked(value.unlocked): return _bad("TARGETS")
	if typeof(value.runs) != TYPE_DICTIONARY or value.runs.size() > MAX_RUNS: return _bad("RUNS")
	var normalized: Dictionary = value.duplicate(true)
	normalized.version = VERSION
	normalized.generation = int(value.generation)
	for name in Catalog.STATS: normalized.stats[name] = int(value.stats[name])
	for token in value.runs:
		var row: Variant = value.runs[token]
		if not _token(token) or not _keys(row, RUN_FIELDS): return _bad("RUN_FIELDS")
		if not _context(row.context) or not _number(row.credited_kills): return _bad("RUN_CONTEXT")
		if typeof(row.terminal) != TYPE_BOOL or typeof(row.victory) != TYPE_BOOL or (row.victory and not row.terminal): return _bad("RUN_TERMINAL")
		if value.requires_correction and not row.terminal: return _bad("CORRECTION_ACTIVE_RUN")
		normalized.runs[token].context.waves = int(row.context.waves)
		normalized.runs[token].credited_kills = int(row.credited_kills)
	return {"ok": true, "code": "OK", "value": normalized}

func create(owner: String, observed_stats: Dictionary, observed_unlocked: Dictionary) -> Dictionary:
	if not _record.is_empty(): return _bad("ALREADY_OPEN")
	var seed := {"version": VERSION, "owner": owner, "generation": 0, "requires_correction": false, "stats": observed_stats, "unlocked": observed_unlocked, "runs": {}}
	return open_record(seed, owner)

func open_record(value: Variant, owner: String) -> Dictionary:
	if not _record.is_empty(): return _bad("ALREADY_OPEN")
	var checked := _validate(value, owner)
	if not checked.ok: return checked
	_record = checked.value
	_correction_notice = _record.requires_correction
	return {"ok": true, "code": "OK"}

func capture() -> Dictionary:
	return _record.duplicate(true)

func publish_targets(owner: String) -> Dictionary:
	if _record.is_empty() or owner != _record.owner: return _bad("OWNER")
	if _correction_notice or _record.requires_correction: return _bad("SERVER_CORRECTION_REQUIRED")
	if not _pending.is_empty(): return _bad("PERSISTENCE_PENDING")
	return {"ok": true, "code": "OK", "owner": _record.owner, "generation": _record.generation,
		"stats": _record.stats.duplicate(true), "unlocked": _record.unlocked.duplicate(true)}

func _propose(next: Dictionary) -> Dictionary:
	if int(_record.generation) == LIMIT: return _bad("GENERATION_EXHAUSTED")
	next.generation = int(_record.generation) + 1
	_pending = next.duplicate(true)
	_pending_sha = JSON.stringify(_pending).sha256_text()
	return {"ok": true, "code": "PREPARED", "changed": true, "record": _pending.duplicate(true), "sha256": _pending_sha}

func commit(persisted: Variant, digest: String) -> Dictionary:
	if _pending.is_empty() or digest != _pending_sha: return _bad("NO_MATCHING_PREPARATION")
	var checked := _validate(persisted, String(_record.owner))
	if not checked.ok: return checked
	if JSON.stringify(checked.value).sha256_text() != _pending_sha: return _bad("PREPARATION_CHANGED")
	_record = checked.value
	_correction_notice = _record.requires_correction
	_pending.clear()
	_pending_sha = ""
	return {"ok": true, "code": "COMMITTED"}

func abandon() -> void:
	_pending.clear()
	_pending_sha = ""

func _check_run(token: Variant, trusted_context: Dictionary) -> Dictionary:
	if _record.is_empty(): return _bad("NOT_OPEN")
	if _correction_notice or _record.requires_correction: return _bad("SERVER_CORRECTION_REQUIRED")
	if not _token(token) or not _record.runs.has(token): return _bad("UNKNOWN_RUN")
	if not _context(trusted_context): return _bad("UNTRUSTED_MODE")
	var normalized := trusted_context.duplicate(true)
	normalized.waves = int(normalized.waves)
	if normalized != _record.runs[token].context: return _bad("CONTEXT_MISMATCH")
	return {"ok": true, "code": "OK"}

func can_resume(token: Variant, owner: String, trusted_context: Dictionary) -> Dictionary:
	if _record.is_empty() or owner != _record.owner: return _bad("OWNER")
	var checked := _check_run(token, trusted_context)
	if not checked.ok: return checked
	if _record.runs[token].terminal: return _bad("RUN_TERMINAL")
	return {"ok": true, "code": "OK", "credited_kills": _record.runs[token].credited_kills}

func prepare_begin(token: Variant, trusted_context: Dictionary) -> Dictionary:
	abandon()
	if _record.is_empty(): return _bad("NOT_OPEN")
	if _correction_notice or _record.requires_correction: return _bad("SERVER_CORRECTION_REQUIRED")
	if not _token(token): return _bad("TOKEN")
	if _record.runs.has(token): return _bad("RUN_EXISTS")
	if _record.runs.size() == MAX_RUNS: return _bad("RUN_LIMIT")
	if not _context(trusted_context): return _bad("UNTRUSTED_MODE")
	var next := capture()
	var context := trusted_context.duplicate(true)
	context.waves = int(context.waves)
	next.runs[token] = {"context": context, "credited_kills": 0, "terminal": false, "victory": false}
	return _propose(next)

func _evaluate(next: Dictionary) -> void:
	var evaluator := AchievementState.new()
	evaluator.seed(next.stats, next.unlocked)
	evaluator.evaluate()
	next.stats = evaluator.stats.duplicate(true)
	next.unlocked = evaluator.unlocked.duplicate(true)

func prepare_progress(token: Variant, trusted_context: Dictionary, total_valid_kills: Variant) -> Dictionary:
	abandon()
	var checked := _check_run(token, trusted_context)
	if not checked.ok: return checked
	if not _number(total_valid_kills): return _bad("KILLS")
	if _record.runs[token].terminal: return _bad("RUN_TERMINAL")
	var previous: int = _record.runs[token].credited_kills
	if int(total_valid_kills) <= previous: return {"ok": true, "code": "ALREADY_CREDITED", "changed": false}
	var next := capture()
	next.runs[token].credited_kills = int(total_valid_kills)
	next.stats.TOTAL_KILLS = mini(LIMIT, int(next.stats.TOTAL_KILLS) + int(total_valid_kills) - previous)
	_evaluate(next)
	return _propose(next)

func prepare_settle(token: Variant, trusted_context: Dictionary, victory: bool, result: Dictionary) -> Dictionary:
	abandon()
	var checked := _check_run(token, trusted_context)
	if not checked.ok: return checked
	if _record.runs[token].terminal: return {"ok": true, "code": "ALREADY_TERMINAL", "changed": false}
	if victory and trusted_context.mode == "campaign":
		for name in ["story_total", "story_done"]:
			if not _number(result.get(name, 0)): return _bad("STORY_RESULT")
		if typeof(result.get("story_complete", false)) != TYPE_BOOL or int(result.get("story_done", 0)) > int(result.get("story_total", 0)): return _bad("STORY_RESULT")
	var next := capture()
	next.runs[token].terminal = true
	next.runs[token].victory = victory
	var evaluator := AchievementState.new()
	evaluator.seed(next.stats, next.unlocked)
	evaluator.settle(1, trusted_context, victory, result)
	next.stats = evaluator.stats.duplicate(true)
	next.unlocked = evaluator.unlocked.duplicate(true)
	return _propose(next)

func prepare_remote_floor(owner: String, observed_stats: Dictionary, observed_unlocked: Dictionary, read_generation: Variant) -> Dictionary:
	## Normal initial read only. A persisted correction barrier explicitly rejects it.
	## Capture generation BEFORE starting the SDK read; stale callbacks cannot merge.
	if _record.is_empty() or owner != _record.owner: return _bad("OWNER")
	if _correction_notice or _record.requires_correction: return _bad("SERVER_CORRECTION_REQUIRED")
	if not _number(read_generation) or int(read_generation) != _record.generation: return _bad("STALE_REMOTE_READ")
	if not _stats(observed_stats) or not _unlocked(observed_unlocked): return _bad("TARGETS")
	abandon()
	var next := capture()
	for name in Catalog.STATS: next.stats[name] = maxi(int(next.stats[name]), int(observed_stats[name]))
	for id in next.unlocked: next.unlocked[id] = next.unlocked[id] or observed_unlocked[id]
	_evaluate(next)
	if next == _record: return {"ok": true, "code": "ALREADY_RECONCILED", "changed": false}
	return _propose(next)

func prepare_server_invalidation(owner: String) -> Dictionary:
	## The host first correlates result 8 to its own in-flight StoreStats request.
	if _record.is_empty() or owner != _record.owner: return _bad("OWNER")
	abandon()
	_correction_notice = true # Stops publication immediately, including failed persistence.
	if _record.requires_correction:
		return {"ok": true, "code": "ALREADY_INVALIDATED", "changed": false}
	var next := capture()
	next.requires_correction = true
	for token in next.runs: next.runs[token].terminal = true
	return _propose(next)

func prepare_server_correction(owner: String, observed_stats: Dictionary, observed_unlocked: Dictionary, read_generation: Variant) -> Dictionary:
	if _record.is_empty() or owner != _record.owner: return _bad("OWNER")
	# A normal fresh read cannot erase a pending absolute target. Require the durable
	# result-8 marker first, and retain every old token as a terminal tombstone.
	if not _record.requires_correction: return _bad("DURABLE_INVALIDATION_REQUIRED")
	if not _number(read_generation) or int(read_generation) != _record.generation: return _bad("STALE_REMOTE_READ")
	if not _stats(observed_stats) or not _unlocked(observed_unlocked): return _bad("TARGETS")
	abandon()
	var next := capture()
	next.requires_correction = false
	for name in Catalog.STATS: next.stats[name] = int(observed_stats[name])
	next.unlocked = observed_unlocked.duplicate(true)
	# Do not max-merge or evaluate old rejected achievements over authoritative data.
	return _propose(next)
