extends RefCounted
## Retained terminal -> CFG -> acknowledgement transaction. Recovery never settles.
const Intent := preload("res://scripts/run_campaign_progress_intent.gd")
const Lifecycle := preload("res://scripts/run_campaign_local_lifecycle.gd")
const Projection := preload("res://scripts/run_campaign_progress_projection.gd")
const ConfigTransaction := preload("res://scripts/run_campaign_cfg_transaction.gd")
const Gate := preload("res://scripts/run_campaign_progress_gate.gd")
const SLOT_ROOT := "user://continue/v1"
var _campaign: Node
var _identity: Dictionary = {}
var _issue := ""
var _stage := "new"
var _battle: WeakRef
var _life: RefCounted
var _intent: Dictionary = {}
var _expected: Dictionary = {}
var _gate_scope: Dictionary = {}
var _cfg: RefCounted
var _ack: Dictionary = {}
var _live := false
var _presentation_consumed := false
var _story_decided := false
var _new_story_seal := false
var _preparation_refusal: Dictionary = {}

func _init(campaign: Node, identity: Dictionary) -> void:
	var tree: MainLoop = Engine.get_main_loop()
	if not tree is SceneTree or campaign != (tree as SceneTree).root.get_node_or_null("Campaign") \
		or campaign == null or campaign.get_script() != Intent.Profiles.CampaignScript \
		or not Intent.Profiles.trusted_identity(identity):
		_issue = "CAMPAIGN_COORDINATOR_ACTUAL_SOURCE_REQUIRED"
		return
	_campaign = campaign
	_identity = identity.duplicate(true)
	_cfg = ConfigTransaction.new()

func _bad(code: String) -> Dictionary:
	return {"ok":false, "code":code, "campaign_progress_pending":not _intent.is_empty(),
		"local_terminal_committed":_stage in ["progress", "ack", "done"],
		"campaign_progress_committed":_stage == "done"}

func _scope_ok() -> bool:
	return _issue.is_empty() and is_instance_valid(_campaign) \
		and _campaign.get_script() == Intent.Profiles.CampaignScript \
		and _campaign.cloud_owner == _intent.get("owner") \
		and _life != null and _life.get_script() == Lifecycle \
		and _life.matches_scope(_intent.context, _identity, _campaign.cloud_owner)

func _install_intent(value: Dictionary) -> Dictionary:
	_expected = Intent.scope(value.get("context"), _identity, _campaign.cloud_owner)
	if not _expected.ok: return _expected
	var checked: Dictionary = Intent.validate(value, String(value.get("token", "")), _expected)
	if not checked.ok: return checked
	_intent = checked.intent.duplicate(true)
	_gate_scope = {"token":_intent.token, "intent_sha256":JSON.stringify(_intent).sha256_text(),
		"owner":_intent.owner, "content_version":_intent.content_version, "engine_sha256":_intent.engine_sha256}
	return {"ok":true}

func begin_live(battle: Node, victory: bool) -> Dictionary:
	if not _issue.is_empty(): return _bad(_issue)
	if _stage != "new" or Engine.is_in_physics_frame(): return _bad("CAMPAIGN_COORDINATOR_BEGIN_CONTEXT")
	var tree: MainLoop = Engine.get_main_loop()
	var actual_script: Resource = ResourceLoader.load("res://scripts/battle.gd", "Script", ResourceLoader.CACHE_MODE_REUSE)
	if not is_instance_valid(battle) or not tree is SceneTree \
		or (tree as SceneTree).current_scene != battle or battle.get_script() != actual_script:
		return _bad("CAMPAIGN_COORDINATOR_ACTUAL_BATTLE_REQUIRED")
	var run_token: String = Crypto.new().generate_random_bytes(16).hex_encode()
	if battle._continue_receipt != null:
		if battle._continue_receipt.get_script() != Lifecycle: return _bad("LOCAL_CAMPAIGN_LIFECYCLE_REQUIRED")
		run_token = battle._continue_receipt.token
	var captured: Dictionary = Intent.capture(battle, run_token, victory, _identity)
	if not captured.ok: return captured
	var installed: Dictionary = _install_intent(captured.intent)
	if not installed.ok: return installed
	_life = battle._continue_receipt if battle._continue_receipt != null else Lifecycle.new(run_token, SLOT_ROOT,
		_intent.context, _identity, _campaign.cloud_owner)
	if not _scope_ok(): return _bad("LOCAL_CAMPAIGN_SCOPE_CHANGED")
	var entered: Dictionary = Gate.enter(self, _gate_scope)
	if not entered.ok: return entered
	_live = true
	_battle = weakref(battle)
	battle._continue_receipt = _life
	_stage = "terminal"
	return retry()

func begin_recovery(lifecycle: RefCounted) -> Dictionary:
	if not _issue.is_empty(): return _bad(_issue)
	if _stage != "new" or lifecycle == null or lifecycle.get_script() != Lifecycle \
		or Engine.is_in_physics_frame(): return _bad("CAMPAIGN_COORDINATOR_RECOVERY_CONTEXT")
	var plan: Dictionary = lifecycle.prepare_progress_recovery()
	if not plan.ok: return plan
	if plan.already_applied:
		_stage = "done"
		return {"ok":true, "already_applied":true, "settlement_authorized":false}
	_life = lifecycle
	var installed: Dictionary = _install_intent(plan.intent)
	if not installed.ok: return installed
	if not _scope_ok(): return _bad("LOCAL_CAMPAIGN_SCOPE_CHANGED")
	var entered: Dictionary = Gate.enter(self, _gate_scope, true)
	if not entered.ok: return entered
	_stage = "progress"
	return retry()

func _live_source_ok() -> bool:
	if not _live: return true
	if _battle == null or not is_instance_valid(_battle.get_ref()): return false
	var source: Node = _battle.get_ref()
	var frozen: Dictionary = Intent.capture(source, _intent.token, _intent.victory, _identity)
	if not frozen.ok: return false
	return source._continue_receipt == _life and frozen.intent == _intent

func _cfg_request() -> Dictionary:
	return {"operation":"progress", "run_token":_intent.token, "intent_sha256":_gate_scope.intent_sha256,
		"target_owner":_intent.owner, "content_version":_intent.content_version, "engine_sha256":_intent.engine_sha256}

func _drive_cfg() -> Dictionary:
	if not _intent.victory:
		return {"ok":true, "code":"CAMPAIGN_PROGRESS_NOT_REQUIRED", "persisted":false, "suppressed":false, "file_sha256":""}
	if not _preparation_refusal.is_empty():
		var released: Dictionary = _cfg.abort_unprepared()
		if not released.ok: return released
		_preparation_refusal.clear()
	var status: Dictionary = _cfg.pending_status()
	if not status.ok: return status
	if _cfg.busy(): return _cfg.retry_write()
	if status.get("pending", false):
		var request: Dictionary = _cfg_request()
		for key in request:
			if status.document[key] != request[key]: return _bad("CAMPAIGN_CFG_OTHER_TRANSACTION_PENDING")
		var recovered: Dictionary = _cfg.recover_pending(_identity, _intent.owner,
			{"run_token":_intent.token, "intent_sha256":_gate_scope.intent_sha256})
		if not recovered.ok: return recovered
		if recovered.get("persisted", false): return recovered
	var begun: Dictionary = _cfg.begin_write(_cfg_request())
	if not begun.ok: return begun
	var projected: Dictionary = Projection.project(_intent, _intent.token, _expected, begun.cfg)
	if not projected.ok:
		_preparation_refusal = projected.duplicate(true)
		var released: Dictionary = _cfg.abort_unprepared()
		if not released.ok:
			return {"ok":false, "code":released.code, "original_error":projected.code, "owned_pending":true}
		_preparation_refusal.clear()
		return projected
	if not _story_decided:
		_new_story_seal = _live and projected.new_story_seal
		_story_decided = true
	return _cfg.commit_prepared(begun.cfg)

func retry() -> Dictionary:
	if not _issue.is_empty(): return _bad(_issue)
	if Engine.is_in_physics_frame(): return _bad("CAMPAIGN_COORDINATOR_PHYSICS_WRITE")
	if _stage == "done": return {"ok":true, "already_applied":true, "settlement_authorized":_live}
	if _stage == "new" or not _scope_ok() or not _live_source_ok() or not Gate.allows(self, _gate_scope):
		return _bad("CAMPAIGN_COORDINATOR_SCOPE_CHANGED")
	if _stage == "terminal":
		var ended: Dictionary = _life.terminal_with_intent(_intent.victory, _intent)
		if not ended.ok: return ended
		_stage = "progress"
	if _stage == "progress":
		var saved: Dictionary = _drive_cfg()
		if not saved.ok: return saved
		if saved.get("suppressed", false): return _bad("CAMPAIGN_QA_IS_NOT_DURABLE")
		if _intent.victory and not saved.get("persisted", false): return _bad("CAMPAIGN_CFG_NOT_DURABLE")
		_ack = {"schema":"campaign_progress_ack_v1", "code":saved.code, "persisted":saved.persisted,
			"suppressed":false, "file_sha256":saved.file_sha256}
		_stage = "ack"
	if _stage == "ack":
		var acknowledged: Dictionary = _life.ack_progress(_ack)
		if not acknowledged.ok: return acknowledged
		if _live and not acknowledged.settlement_authorized: return _bad("CAMPAIGN_SETTLEMENT_CAPABILITY_REQUIRED")
		# No on_level_won replay, factory, Mission callback or metrics on recovery.
		_campaign._load()
		if _campaign.cloud_owner != _intent.owner: return _bad("CAMPAIGN_OWNER_CHANGED_AFTER_ACK")
		var released: Dictionary = Gate.leave(self, _gate_scope)
		if not released.ok: return released
		_stage = "done"
	return {"ok":true, "local_terminal_committed":true, "campaign_progress_committed":true,
		"settlement_authorized":_live, "progress_recovery_only":not _live}

func consume_live_completion(battle: Node) -> Dictionary:
	if _stage != "done" or not _live or _presentation_consumed or _battle == null \
		or _battle.get_ref() != battle or not _live_source_ok(): return _bad("CAMPAIGN_COMPLETION_NOT_AUTHORIZED")
	_presentation_consumed = true
	var result: Dictionary = _intent.result.duplicate(true)
	result.new_story_seal = _new_story_seal
	return {"ok":true, "result":result, "local_terminal_committed":true,
		"campaign_progress_committed":true, "settlement_authorized":true}

func startup_complete() -> Dictionary:
	if not _issue.is_empty() or _stage not in ["new", "done"]: return _bad("CAMPAIGN_STARTUP_PENDING")
	return Gate.startup_complete(self)
