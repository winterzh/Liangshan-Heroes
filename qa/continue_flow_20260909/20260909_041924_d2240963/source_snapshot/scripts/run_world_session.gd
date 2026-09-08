extends RefCounted
## Internal save/install transaction for official classic worlds and durable local runs.
## Trusted identity/runtime are provided by the current installation, never the slot.
## SDK dispatch and normal player entry remain separate integration gates.
const Core = preload("res://scripts/run_battle_world_core.gd")
const Store = preload("res://scripts/run_slot_store.gd")
const Codec = preload("res://scripts/run_state_value_codec.gd")
const SteamScript = preload("res://scripts/steam_service.gd")
const MenuScript = preload("res://scripts/menu.gd")
const CampaignScript = preload("res://scripts/campaign.gd")
const LocalLifecycle = preload("res://scripts/run_local_lifecycle.gd")
const FLAGS := {"skirmish": true, "skirmish_ai": false, "arena": false, "custom_defense": false, "scenario": false, "defense_waves": 30, "defense_random": false}
var _core: RefCounted
var _store: RefCounted
var _trusted: Dictionary
var _packet: Dictionary = {}
var _old_scene: Node
var _steam_lease: Dictionary = {}
var _campaign_before: Dictionary = {}
var _campaign_applied := false
var _canvas_before := Transform2D.IDENTITY
var _slot_sha := ""
var _phase := "new"
var _save_source: WeakRef
var _save_lease: Dictionary = {}
var _save_clock: Dictionary = {}
var _slot_root := ""
var _local_receipt: RefCounted

func _init(trusted: Dictionary, runtime: Dictionary, slot_root := "user://continue/v1") -> void:
	_trusted = trusted.duplicate(true)
	_core = Core.new(trusted, runtime)
	_store = Store.new(slot_root)
	_slot_root = slot_root

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

func _campaign() -> Node:
	return _tree().root.get_node("Campaign")

func _steam() -> Node:
	return _tree().root.get_node("SteamService")

func _lease() -> Dictionary:
	var steam := _steam()
	if steam.get_script() != SteamScript or (steam._active_run != 0 and steam._local_runs == null): return _bad("PERSISTENT_STEAM_BINDING_REQUIRED")
	return {"ok": true, "active": steam._active_run, "counter": steam._run_counter, "account": steam.account, "available": steam.available, "ready": steam.stats_ready, "context": steam._context.duplicate(true), "local": steam._local_runs, "token": "" if steam._local_runs == null else steam._local_runs._token}

func save_held(source: Variant, retained_identity: Variant = null, expected_slot: Dictionary = {}) -> Dictionary:
	if _phase != "new": return _bad("SESSION_ALREADY_USED")
	if not expected_slot.is_empty():
		var matching: Dictionary = _store.check_expected(expected_slot)
		if not matching.ok: return matching
	if not is_instance_valid(source) or source.get_script() != Core.B or source != _tree().current_scene or source.get_parent() != _tree().root: return _bad("CURRENT_BATTLE_REQUIRED")
	if not _tree().paused or Engine.is_in_physics_frame(): return _bad("PAUSED_SAVE_REQUIRED")
	if _campaign().get_script() != CampaignScript or SteamRunPolicy.classify(_campaign(), source.level) != Store.CONTEXT or source._official_context != Store.CONTEXT: return _bad("CLASSIC_CONTEXT_REQUIRED")
	var lease := _lease()
	if not lease.ok or source._steam_run_id != lease.active or lease.context != Store.CONTEXT: return _bad("PERSISTENT_STEAM_BINDING_REQUIRED")
	var captured: Dictionary = _core.capture(source, retained_identity)
	if not captured.ok: return captured
	var options := {}
	for name in Store.OPTIONS: options[name] = _campaign().get(name)
	var encoded_options: Dictionary = Codec.new().encode(options)
	var root_node: Dictionary = Codec.new().encode(_core._visuals(source)._read_node(source))
	if retained_identity == null: captured.identity.dispose()
	if not encoded_options.ok: return encoded_options
	if not root_node.ok: return root_node
	var binding := {}
	if source._steam_run_id != 0:
		var bound: Dictionary = _steam()._persistent_binding(source._steam_run_id, Store.CONTEXT, source._steam_valid_kills)
		if not bound.ok: return bound
		binding = bound.binding
	else:
		if source._continue_receipt == null:
			source._continue_receipt = LocalLifecycle.new(Crypto.new().generate_random_bytes(16).hex_encode(), _slot_root)
		if source._continue_receipt.get_script() != LocalLifecycle: return _bad("LOCAL_LIFECYCLE_SCRIPT")
		var bound: Dictionary = source._continue_receipt.binding()
		if not bound.ok: return bound
		binding = bound.binding
	var packet := {"schema": Store.SCHEMA, "generation": 0, "context": Store.CONTEXT.duplicate(), "binding": binding, "resume_paused": source._save_barrier._was_paused, "options": encoded_options.value, "root_node": root_node.value, "world": captured.record}
	var clock: Dictionary = source._run_clock.capture()
	if not clock.ok: return clock
	var written: Dictionary = _store.write_slot(packet, expected_slot)
	if not written.ok:
		if written.get("pending_save", false):
			_phase = "save_pending"
			_save_source = weakref(source)
			_save_lease = lease.duplicate(true)
			_save_clock = clock.record.duplicate(true)
		return written
	_phase = "saved"
	return {"ok": true, "generation": written.generation, "file_sha256": written.file_sha256, "source_retained": true, "source_held": source._save_barrier.health().ok}

func has_pending_save() -> bool:
	return _phase == "save_pending" and _store.has_pending_write()

func pending_save_status() -> Dictionary:
	return _store.pending_write_status()

func _pending_save_refused(code: String) -> Dictionary:
	return {"ok": false, "code": code, "pending_save": has_pending_save(), "retryable": false, "unsafe": true, "restart_required": true}

func retry_pending_save(source: Variant) -> Dictionary:
	# Keep this Session and the original Battle HELD after a pending write. A
	# later running battle must never quit based on an older frozen proposal.
	if not has_pending_save(): return _bad("NO_PENDING_SAVE")
	if not is_instance_valid(source) or _save_source == null or _save_source.get_ref() != source or source.get_script() != Core.B or source != _tree().current_scene or source.get_parent() != _tree().root: return _pending_save_refused("PENDING_SAVE_SOURCE_CHANGED")
	if not _tree().paused or Engine.is_in_physics_frame() or source._save_barrier == null or source._save_barrier.state != source._save_barrier.State.HELD: return _pending_save_refused("PENDING_SAVE_HOLD_LOST")
	var held: Dictionary = source._save_barrier.health()
	if not held.ok: return _pending_save_refused(held.code)
	var clock: Dictionary = source._run_clock.capture()
	if not clock.ok or clock.record != _save_clock: return _pending_save_refused("PENDING_SAVE_CLOCK_CHANGED")
	if _lease() != _save_lease: return _pending_save_refused("PENDING_SAVE_STEAM_CHANGED")
	var written: Dictionary = _store.retry_pending_write()
	if not written.ok: return written
	_phase = "saved"
	_save_source = null; _save_lease.clear(); _save_clock.clear()
	return {"ok": true, "generation": written.generation, "file_sha256": written.file_sha256, "source_retained": true, "source_held": true, "owned_retry": true}

func prepare_restore(menu: Node) -> Dictionary:
	if _phase != "new": return _bad("SESSION_ALREADY_USED")
	if not is_instance_valid(menu) or menu.get_script() != MenuScript or not menu.is_inside_tree() or menu != _tree().current_scene or menu.get_parent() != _tree().root or menu.is_queued_for_deletion(): return _bad("CURRENT_MENU_REQUIRED")
	if not _tree().paused or Engine.is_in_physics_frame(): return _bad("PAUSED_RESTORE_REQUIRED")
	var lease := _lease()
	if not lease.ok: return lease
	if lease.active != 0: return _bad("ACTIVE_STEAM_RUN")
	if _campaign().get_script() != CampaignScript: return _bad("CAMPAIGN_REQUIRED")
	var read: Dictionary = _store.read_slot(true)
	if not read.ok: return read
	_packet = read.document; _slot_sha = read.file_sha256
	if _packet.binding.kind == "uncredited":
		_local_receipt = LocalLifecycle.new(_packet.binding.token, _slot_root)
		var local_plan: Dictionary = _local_receipt.prepare_resume(_packet.binding)
		if not local_plan.ok: return local_plan
	var prepared: Dictionary = _core.prepare(_packet.world)
	if not prepared.ok: return prepared
	if _packet.binding.kind == "steam":
		var binding_plan: Dictionary = _steam()._prepare_persistent_resume(_packet.binding, Store.CONTEXT, _core._battle._steam_valid_kills)
		if not binding_plan.ok: _core.dispose(); return binding_plan
	_old_scene = menu; _steam_lease = lease
	_canvas_before = _tree().root.canvas_transform
	for name in FLAGS: _campaign_before[name] = _campaign().get(name)
	for name in Store.OPTIONS: _campaign_before[name] = _campaign().get(name)
	_phase = "prepared"
	return {"ok": true, "generation": _packet.generation, "menu_retained": true, "battle": _core._battle}

func _rollback(reason: Dictionary) -> Dictionary:
	_core.dispose(); _phase = "failed"
	if _campaign_applied:
		for name in _campaign_before: _campaign().set(name, _campaign_before[name])
		_tree().root.canvas_transform = _canvas_before
		_campaign_applied = false
	return {"ok": false, "code": reason.get("code", "RESTORE_FAILED"), "menu_retained": is_instance_valid(_old_scene)}

func commit_restore() -> Dictionary:
	if _phase != "prepared": return _bad("RESTORE_NOT_PREPARED")
	if not _tree().paused or Engine.is_in_physics_frame() or not is_instance_valid(_old_scene) or _tree().current_scene != _old_scene or _old_scene.get_parent() != _tree().root or _old_scene.is_queued_for_deletion(): return _rollback(_bad("MENU_CHANGED"))
	if _lease() != _steam_lease: return _rollback(_bad("STEAM_LEASE_CHANGED"))
	for name in _campaign_before:
		if _campaign().get(name) != _campaign_before[name]: return _rollback(_bad("CAMPAIGN_CHANGED"))
	var latest: Dictionary = _store.read_slot()
	if not latest.ok or latest.file_sha256 != _slot_sha or latest.document != _packet: return _rollback(_bad("SLOT_CHANGED"))
	if _local_receipt != null:
		var local_plan: Dictionary = _local_receipt.prepare_resume(_packet.binding)
		if not local_plan.ok: return _rollback(local_plan)
	var options: Dictionary = Codec.new().decode(_packet.options)
	var node: Dictionary = Codec.new().decode(_packet.root_node)
	if not options.ok or not node.ok: return _rollback(_bad("PACKET_CHANGED"))
	for name in FLAGS: _campaign().set(name, FLAGS[name])
	for name in Store.OPTIONS: _campaign().set(name, options.value[name])
	_campaign_applied = true
	var mounted: Dictionary = _core.mount_disabled(_tree().root)
	if not mounted.ok: return _rollback(mounted)
	var battle: Node = _core._battle
	battle._official_context = Store.CONTEXT.duplicate(); battle._steam_run_id = 0
	battle._continue_receipt = _local_receipt
	var activated: Dictionary = _core.activate_components(node.value)
	if not activated.ok: return _rollback(activated)
	var binding_plan := {}
	if _packet.binding.kind == "steam":
		binding_plan = _steam()._prepare_persistent_resume(_packet.binding, Store.CONTEXT, battle._steam_valid_kills)
		if not binding_plan.ok: return _rollback(binding_plan)
	var owned: Dictionary = _core.handoff_world()
	if not owned.ok: return _rollback(owned)
	if not binding_plan.is_empty():
		_steam()._install_persistent_resume(binding_plan)
		battle._steam_run_id = binding_plan.handle
	_steam()._context = Store.CONTEXT.duplicate()
	_tree().current_scene = battle
	_old_scene.free(); _old_scene = null
	if not node.value.name.is_empty(): battle.name = node.value.name
	battle._install_target_cursor()
	Engine.time_scale = _tree().root.get_node("Settings").game_speed
	_phase = "installed"
	_tree().paused = _packet.resume_paused
	return {"ok": true, "battle": battle, "identity": owned.identity, "generation": _packet.generation, "steam_credit": not binding_plan.is_empty(), "steam_published": false, "paused": _tree().paused}

func dispose() -> Dictionary:
	# The caller must retain this object when this refusal is returned. Dropping
	# the final reference would discard the only live token for this write.
	if has_pending_save(): return _pending_save_refused("PENDING_SAVE_RETAIN_SESSION")
	if _phase != "installed": _core.dispose()
	_old_scene = null; _packet.clear()
	return {"ok": true}
