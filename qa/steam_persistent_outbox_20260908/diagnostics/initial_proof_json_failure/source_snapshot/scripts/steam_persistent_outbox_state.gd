extends RefCounted
## Full persistent intent validator. Receipt high-water/tombstones stay in the
## separate ledger; an intent keeps their exact generation and canonical digest.
const Receipt = preload("res://scripts/steam_run_receipt.gd")
const Catalog = preload("res://scripts/steam_achievement_catalog.gd")
const VERSION := 1
const LIMIT := 2147483647
const MAX_INTENTS := 512
const FIELDS := ["version", "owner", "revision", "correction_required", "intents"]
const INTENT_FIELDS := ["id", "generation", "receipt_sha256", "ledger_sha256", "targets_sha256", "stats", "unlocked", "state", "confirmation_sha256"]

static func bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

static func keys(value: Variant, fields: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != fields.size(): return false
	for key in value:
		if typeof(key) != TYPE_STRING or key not in fields: return false
	return true

static func number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT: return value >= 0 and value <= LIMIT
	return typeof(value) == TYPE_FLOAT and is_finite(value) and value >= 0.0 and value <= LIMIT and value == floor(value)

static func hex(value: Variant, count: int) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != count: return false
	for character in value:
		if character not in "0123456789abcdef": return false
	return true

static func checked_targets(stats: Variant, unlocked: Variant) -> Dictionary:
	if not keys(stats, Array(Catalog.STATS)): return bad("STATS_FIELDS")
	var normalized := {}
	for name in Catalog.STATS:
		if not number(stats[name]): return bad("STAT_VALUE")
		normalized[name] = int(stats[name])
	if typeof(unlocked) != TYPE_DICTIONARY or unlocked.size() != Catalog.entries().size(): return bad("UNLOCKS_FIELDS")
	for entry in Catalog.entries():
		if not unlocked.has(entry.id) or typeof(unlocked[entry.id]) != TYPE_BOOL: return bad("UNLOCK_VALUE")
	for key in unlocked:
		if typeof(key) != TYPE_STRING: return bad("UNLOCK_KEY")
	return {"ok": true, "stats": normalized, "unlocked": unlocked.duplicate(true)}

static func target_digest(stats: Dictionary, unlocked: Dictionary) -> String:
	return JSON.stringify({"stats": stats, "unlocked": unlocked}).sha256_text()

static func validate(value: Variant, account: String) -> Dictionary:
	if not keys(value, FIELDS): return bad("OUTBOX_FIELDS")
	if not Receipt.new()._owner(account) or typeof(value.owner) != TYPE_STRING or value.owner != account: return bad("OWNER")
	if not number(value.version) or int(value.version) != VERSION: return bad("VERSION")
	if not number(value.revision) or int(value.revision) < 1: return bad("REVISION")
	if typeof(value.correction_required) != TYPE_BOOL or typeof(value.intents) != TYPE_ARRAY or value.intents.size() > MAX_INTENTS: return bad("OUTBOX_SHAPE")
	var normalized: Dictionary = value.duplicate(true)
	normalized.version = VERSION
	normalized.revision = int(value.revision)
	var ids := {}
	var generation := -1
	var uncertain := 0
	for index in range(value.intents.size()):
		var row: Variant = value.intents[index]
		if not keys(row, INTENT_FIELDS): return bad("INTENT_FIELDS")
		if not hex(row.id, 32) or ids.has(row.id): return bad("INTENT_ID")
		if not number(row.generation) or int(row.generation) <= generation: return bad("INTENT_GENERATION")
		for field in ["receipt_sha256", "ledger_sha256", "targets_sha256"]:
			if not hex(row[field], 64): return bad("INTENT_DIGEST")
		if typeof(row.state) != TYPE_STRING or row.state not in ["queued", "uncertain", "confirmed"]: return bad("INTENT_STATE")
		if row.state == "confirmed":
			if not hex(row.confirmation_sha256, 64): return bad("CONFIRMATION_DIGEST")
		elif typeof(row.confirmation_sha256) != TYPE_STRING or not row.confirmation_sha256.is_empty(): return bad("UNCONFIRMED_PROOF")
		var targets := checked_targets(row.stats, row.unlocked)
		if not targets.ok: return targets
		if target_digest(targets.stats, targets.unlocked) != row.targets_sha256: return bad("TARGET_DIGEST")
		if row.state == "uncertain": uncertain += 1
		if uncertain > 1: return bad("MULTIPLE_UNCERTAIN")
		ids[row.id] = true
		generation = int(row.generation)
		normalized.intents[index].generation = generation
		normalized.intents[index].stats = targets.stats
	return {"ok": true, "document": normalized, "revision": normalized.revision}
