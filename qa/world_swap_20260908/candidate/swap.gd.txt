extends RefCounted
## Synchronous same-process world replacement. Persistent Steam/slot loading is separate.
## Snapshot and active Steam lease come from the actual HELD source, never a caller save.
const Core := preload("res://scripts/run_battle_world_core.gd")
const B := preload("res://scripts/battle.gd")
const Policy := preload("res://scripts/steam_run_policy.gd")
var _core: Variant
var _source: Variant
var _record: Dictionary = {}
var _root_node: Dictionary = {}
var _lease: Dictionary = {}
var _phase := "new"
var _resume_paused := true

func _init(trusted: Dictionary, runtime: Dictionary) -> void:
	_core = Core.new(trusted, runtime)

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "cross_process": false}

func _source_check(source: Variant) -> Dictionary:
	if not is_instance_valid(source) or source.get_script() != B or not source.is_inside_tree() or source.is_queued_for_deletion(): return _bad("LIVE_SOURCE_REQUIRED")
	var tree: SceneTree = source.get_tree()
	if not tree.paused or Engine.is_in_physics_frame() or tree.current_scene != source or source.get_parent() != tree.root: return _bad("CURRENT_PAUSED_SOURCE_REQUIRED")
	if source._save_barrier == null or source._save_barrier.state != source._save_barrier.State.HELD: return _bad("HELD_SOURCE_REQUIRED")
	var checked: Dictionary = source._save_barrier.health()
	if not checked.ok: return checked
	var context: Dictionary = Policy.classify(tree.root.get_node("Campaign"), source.level)
	if context != source._official_context or context != {"mode": "defense", "level_id": "", "waves": 30}: return _bad("CURRENT_CLASSIC_CONTEXT_REQUIRED")
	var steam: Variant = tree.root.get_node("SteamService")
	if steam.get_script() != preload("res://scripts/steam_service.gd") or steam._active_run != source._steam_run_id or steam._context != context: return _bad("CURRENT_STEAM_LEASE_REQUIRED")
	if source._steam_run_id != 0 and (not steam.ensure_account() or not steam.stats_ready or steam.state.settled.has(source._steam_run_id)): return _bad("ACTIVE_UNSETTLED_STEAM_LEASE_REQUIRED")
	return {"ok": true, "context": context, "lease": {"account": steam.account, "run": source._steam_run_id, "counter": steam._run_counter}}

func prepare(source: Variant, retained_identity: Variant = null) -> Dictionary:
	if _phase != "new": return _bad("SWAP_ALREADY_USED")
	var checked: Dictionary = _source_check(source)
	if not checked.ok: return checked
	_source = source; _lease = checked.lease
	_root_node = _core._visuals(source)._read_node(source)
	if _root_node.activation.mode != Node.PROCESS_MODE_INHERIT or not _root_node.activation.physics or _root_node.activation.signals_blocked: return _bad("SOURCE_ROOT_MODE_UNSUPPORTED")
	_resume_paused = source._save_barrier._was_paused
	var captured: Dictionary = _core.capture(source, retained_identity)
	if not captured.ok: return captured
	_record = JSON.parse_string(JSON.stringify(captured.record))
	if retained_identity == null: captured.identity.dispose()
	checked = _core.prepare(_record)
	if not checked.ok: _phase = "failed"; return checked
	_phase = "prepared"
	return {"ok": true, "battle": _core._battle, "source_retained": true, "cross_process": false}

func _rollback(result: Dictionary) -> Dictionary:
	_core.dispose(); _phase = "failed"
	if is_instance_valid(_source) and _source.is_inside_tree():
		_source.get_tree().current_scene = _source
		_source.camera.make_current(); _source.camera.force_update_scroll()
	return {"ok": false, "code": result.get("code", "SWAP_FAILED"), "source_retained": is_instance_valid(_source), "cross_process": false}

func commit() -> Dictionary:
	if _phase != "prepared": return _bad("SWAP_NOT_PREPARED")
	var checked: Dictionary = _source_check(_source)
	if not checked.ok: return _rollback(checked)
	if checked.lease != _lease: return _rollback(_bad("STEAM_LEASE_CHANGED"))
	var tree: SceneTree = _source.get_tree()
	checked = _core.mount_disabled(tree.root)
	if not checked.ok: return _rollback(checked)
	var destination: Variant = _core._battle
	destination._official_context = _source._official_context.duplicate(true)
	destination._steam_run_id = _lease.run
	checked = _core.activate_components(_root_node)
	if not checked.ok: return _rollback(checked)
	checked = _core.handoff_world()
	if not checked.ok: return _rollback(checked)
	# No asynchronous boundary exists between consumer activation and ownership transfer.
	tree.current_scene = destination
	_source.free(); _source = null
	if not _root_node.name.is_empty(): destination.name = _root_node.name
	destination._install_target_cursor()
	_phase = "committed"
	tree.paused = _resume_paused
	return {"ok": true, "battle": destination, "identity": checked.identity, "paused": tree.paused, "source_freed": true, "same_steam_run": true, "cross_process": false}

func dispose() -> void:
	if _phase != "committed": _core.dispose()
	_record.clear(); _source = null
