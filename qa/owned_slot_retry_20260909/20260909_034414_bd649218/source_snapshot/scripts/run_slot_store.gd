extends "res://scripts/run_snapshot_store.gd"
## One local continue slot. Scope key 1 is a slot number, never a Steam account.
const LocalRun = preload("res://scripts/steam_local_run_session.gd")
const Codec = preload("res://scripts/run_state_value_codec.gd")
const Core = preload("res://scripts/run_battle_world_core.gd")
const SCHEMA := "classic_continue_slot_v1"
const CONTEXT := {"mode": "defense", "level_id": "", "waves": 30}
const KEYS := ["schema", "generation", "context", "binding", "resume_paused", "options", "root_node", "world"]
const OPTIONS := ["defense_hero_cap", "ai_friendly", "scale_on", "enemy_mult", "hero_mult", "hero_mult_touched"]

var _pending_write: Dictionary = {}

func _init(root_path := "user://continue/v1") -> void:
	super("1", root_path)

func _magic() -> String:
	return "LH_CLASSIC_CONTINUE_SLOT"

func _byte_limit() -> int:
	return 67108864

func _validate_document(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or value.size() != KEYS.size() or not value.has_all(KEYS): return bad("SLOT_FIELDS")
	if value.schema != SCHEMA: return bad("SLOT_SCHEMA")
	if typeof(value.generation) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value.generation)) or value.generation < 1 or value.generation > 2147483647 or float(value.generation) != floor(float(value.generation)): return bad("SLOT_GENERATION")
	if typeof(value.context) != TYPE_DICTIONARY or value.context.size() != 3 or not value.context.has_all(["mode", "level_id", "waves"]): return bad("SLOT_CONTEXT")
	if value.context.mode != "defense" or value.context.level_id != "" or typeof(value.context.waves) not in [TYPE_INT, TYPE_FLOAT] or value.context.waves != 30: return bad("SLOT_CONTEXT")
	var binding: Dictionary = {}
	if typeof(value.binding) == TYPE_DICTIONARY and value.binding == {"kind": "uncredited"}: binding = value.binding.duplicate()
	else:
		var checked_binding: Dictionary = LocalRun.validate_binding(value.binding)
		if not checked_binding.ok: return checked_binding
		binding = checked_binding.binding
	if typeof(value.resume_paused) != TYPE_BOOL: return bad("SLOT_PAUSE")
	var options: Dictionary = Codec.new().decode(value.options)
	if not options.ok or typeof(options.value) != TYPE_DICTIONARY or options.value.size() != OPTIONS.size() or not options.value.has_all(OPTIONS): return bad("SLOT_OPTIONS")
	var opts: Dictionary = options.value
	if typeof(opts.defense_hero_cap) != TYPE_INT or opts.defense_hero_cap != 4: return bad("CLASSIC_HERO_CAP")
	for key in ["ai_friendly", "scale_on", "hero_mult_touched"]:
		if typeof(opts[key]) != TYPE_BOOL: return bad("SLOT_OPTION_TYPE")
	for key in ["enemy_mult", "hero_mult"]:
		if typeof(opts[key]) != TYPE_FLOAT or not is_finite(opts[key]) or opts[key] < 1.0 or opts[key] > (5.0 if key == "enemy_mult" else 3.0): return bad("SLOT_OPTION_RANGE")
	var node: Dictionary = Codec.new().decode(value.root_node)
	if not node.ok: return node
	var visual := Core.Visual.new(Codec, Core.B, Core.U)
	var checked: Dictionary = visual._check_node(node.value)
	if not checked.ok: return checked
	if node.value.activation.mode != Node.PROCESS_MODE_INHERIT or not node.value.activation.physics or node.value.activation.signals_blocked: return bad("SLOT_ROOT_ACTIVATION")
	if typeof(value.world) != TYPE_DICTIONARY or value.world.size() != 4 or not value.world.has_all(["schema", "content_version", "engine_sha256", "sections"]): return bad("SLOT_WORLD_FIELDS")
	if value.world.schema != Core.SCHEMA or typeof(value.world.content_version) != TYPE_STRING or value.world.content_version.is_empty() or typeof(value.world.engine_sha256) != TYPE_STRING or value.world.engine_sha256.length() != 64: return bad("SLOT_WORLD_IDENTITY")
	if typeof(value.world.sections) != TYPE_DICTIONARY or value.world.sections.size() != Core.SECTIONS.size() or not value.world.sections.has_all(Core.SECTIONS): return bad("SLOT_WORLD_SECTIONS")
	var normalized: Dictionary = value.duplicate(true)
	normalized.generation = int(value.generation)
	normalized.context = CONTEXT.duplicate()
	normalized.binding = binding
	return {"ok": true, "document": normalized, "revision": normalized.generation}

func read_slot(recover_dead_writer := false) -> Dictionary:
	if directory.is_empty(): return bad("USER_PATH")
	if not DirAccess.dir_exists_absolute(directory): return bad("NO_SLOT")
	var head := open_head()
	if not head.ok and head.code == "RECOVERY_REQUIRED" and recover_dead_writer:
		var plan := inspect_recovery()
		if not plan.ok: return plan
		head = recover(plan)
	if not head.ok: return head
	if head.revision == 0: return bad("NO_SLOT")
	return head

func inspect_slot() -> Dictionary:
	var head := read_slot(true)
	if not head.ok:
		if head.code == "NO_SLOT": return {"ok": true, "exists": false, "revision": 0, "file_sha256": ZERO}
		return head
	return {"ok": true, "exists": true, "revision": head.revision, "file_sha256": head.file_sha256}

func check_expected(expected: Dictionary) -> Dictionary:
	if expected.size() != 2 or not expected.has_all(["revision", "file_sha256"]) or typeof(expected.revision) != TYPE_INT or expected.revision < 0 or expected.revision > 2147483647 or typeof(expected.file_sha256) != TYPE_STRING or expected.file_sha256.length() != 64 or not expected.file_sha256.is_valid_hex_number(): return bad("SLOT_EXPECTATION")
	var observed := inspect_slot()
	if not observed.ok: return observed
	if observed.revision != expected.revision or observed.file_sha256 != expected.file_sha256: return bad("SLOT_CHANGED")
	return {"ok": true}

func write_slot(packet: Dictionary, expected: Dictionary = {}) -> Dictionary:
	if has_pending_write(): return _pending_failure(bad("SLOT_WRITE_PENDING"))
	if not expected.is_empty():
		var matching := check_expected(expected)
		if not matching.ok: return matching
	var ready := initialize_directory()
	if not ready.ok: return ready
	var head := read_slot(true)
	if not head.ok:
		if head.code != "NO_SLOT": return head
		head = open_head()
	if not head.ok: return head
	if not expected.is_empty() and (head.revision != expected.revision or head.file_sha256 != expected.file_sha256): return bad("SLOT_CHANGED")
	var next := packet.duplicate(true)
	next.generation = int(head.revision) + 1
	var prepared := _validate_document(next)
	if not prepared.ok: return prepared
	var document: Dictionary = prepared.document
	_pending_write = {"revision": int(head.revision), "file_sha256": head.file_sha256, "proposal": {"record": document.duplicate(true), "sha256": JSON.stringify(document).sha256_text()}}
	var locked := acquire()
	if not locked.ok:
		if _lock_created or _locked: return _pending_failure(locked)
		_pending_write.clear()
		return locked
	if locked.revision != head.revision or locked.file_sha256 != head.file_sha256:
		var unlocked := release()
		if not unlocked.ok: return _pending_failure(unlocked)
		_pending_write.clear()
		return bad("SLOT_CHANGED")
	var committed := commit_locked(head.revision, head.file_sha256, {"record": document, "sha256": JSON.stringify(document).sha256_text()})
	if not committed.ok: return _pending_failure(committed)
	var released := release()
	if not released.ok: return _pending_failure(released)
	_pending_write.clear()
	return {"ok": true, "generation": committed.revision, "file_sha256": committed.file_sha256, "record": committed.document}

func has_pending_write() -> bool:
	return not _pending_write.is_empty()

func pending_write_status() -> Dictionary:
	if not has_pending_write(): return {"ok": false, "code": "NO_PENDING_SLOT_WRITE", "pending_save": false, "retryable": false, "unsafe": false, "restart_required": false}
	var inspected := inspect_owned_commit(_pending_write.revision, _pending_write.file_sha256, _pending_write.proposal)
	var status := {"ok": inspected.ok, "pending_save": true, "retryable": inspected.get("retryable", false), "unsafe": inspected.get("unsafe", true), "restart_required": inspected.get("restart_required", true)}
	if inspected.ok: status["action"] = inspected.action
	else: status["code"] = inspected.code
	return status

func _pending_failure(reason: Dictionary) -> Dictionary:
	var result := reason.duplicate(true)
	var status := pending_write_status()
	result["ok"] = false
	for key in ["pending_save", "retryable", "unsafe", "restart_required"]: result[key] = status[key]
	if not status.ok: result["recovery_code"] = status.code
	return result

func retry_pending_write() -> Dictionary:
	if not has_pending_write(): return pending_write_status()
	var committed := retry_owned_commit(_pending_write.revision, _pending_write.file_sha256, _pending_write.proposal)
	if not committed.ok: return _pending_failure(committed)
	_pending_write.clear()
	return {"ok": true, "generation": committed.revision, "file_sha256": committed.file_sha256, "record": committed.document, "owned_retry": true}
