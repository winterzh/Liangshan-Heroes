extends "res://tools/campaign_original19_first_repeat_v1.gd"
## Actual R12 cloud write failure, retained proposal and real retry UI boundary.
## No native execution admission. SDK-disabled owner is synthetic local input.
## Authorized account retry and successful restart remain separate requirements.
const FAILURE_CASE := "legacy_real_cloud_apply_failure_boundary"
const LOCAL_OWNER := "1"
const BLOCKER := "user://campaign_cfg_candidates/v1"
const BLOCKER_PARENT := "user://campaign_cfg_candidates"
const Values := preload("res://scripts/run_campaign_cfg_values.gd")
var failure_evidence: Dictionary = {}

func _campaign_memory(campaign: Node) -> Dictionary:
	return {"records":campaign.records.duplicate(true),"unlocked":campaign.unlocked,"owner":campaign.cloud_owner}

func _cloud_flags(cloud: Node) -> Dictionary:
	return {"dirty":cloud.dirty,"pending_upload":cloud._pending_upload,"revision":cloud._revision}

func _cfg_digest() -> String:
	return FileAccess.get_sha256("user://campaign.cfg") if FileAccess.file_exists("user://campaign.cfg") else ""

func _fresh() -> void:
	if not check(mode == "first" and OS.get_environment("CAMPAIGN_CALLBACK_CASE") == FAILURE_CASE,"only actual cloud failure boundary mode"): return
	var campaign: Node = root.get_node("Campaign")
	var cloud: Node = root.get_node("SteamCloud")
	var steam: Node = root.get_node("SteamService")
	var flow: Node = root.get_node("ContinueFlow")
	if not check(not steam.available and not cloud.cloud_ready and cloud._owner.is_empty(),"SDK disabled and original cloud unattached"): return
	if not check(campaign.records.is_empty() and campaign.unlocked == 1 and campaign.cloud_owner.is_empty()
		and not campaign.persistence_busy() and not cloud.shared_profile_pending(),"ordinary fresh profile has no pending campaign writer"): return
	var memory: Dictionary = _campaign_memory(campaign)
	var flags: Dictionary = _cloud_flags(cloud)
	var cfg_sha: String = _cfg_digest()
	var campaign_id: int = campaign.get_instance_id()
	var cloud_id: int = cloud.get_instance_id()
	if not check(not FileAccess.file_exists(BLOCKER) and not DirAccess.dir_exists_absolute(BLOCKER),"private stage obstruction path is initially absent"): return
	if not check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BLOCKER_PARENT)) == OK,"own private obstruction parent created"): return
	var file: FileAccess = FileAccess.open(BLOCKER,FileAccess.WRITE)
	if not check(file != null,"own real stage-parent file obstruction opened"): return
	file.store_string("CLOUD_FAILURE_PRIVATE_FIXTURE " + nonce + "\n")
	file.flush()
	file.close()
	var blocker_sha: String = FileAccess.get_sha256(BLOCKER)
	if not check(not blocker_sha.is_empty() and FileAccess.file_exists(BLOCKER) and not DirAccess.dir_exists_absolute(BLOCKER),"closed original obstruction is a regular file"): return
	# Same explicitly local account seam used by the reviewed cloud success probe.
	# Do not attach Steam, overwrite Campaign memory or change _applying manually.
	cloud._owner = LOCAL_OWNER
	var payload: Dictionary = cloud._build_payload(LOCAL_OWNER)
	payload.campaign = {"schema":2,"unlocked":2,"records":{}}
	if not check(cloud._validate_payload(payload,LOCAL_OWNER),"actual payload validator accepts bounded local input"): return
	var applied: bool = cloud._apply_profile(payload)
	if not check(not applied,"actual production cloud apply returns false on real storage obstruction"): return
	var writer: RefCounted = campaign.get("_cfg_writer")
	if not check(writer != null and writer.busy() and campaign.cloud_configuration_pending(),"same actual Campaign CFG writer remains pending"): return
	var proposal: ConfigFile = writer.get("_frozen_cfg")
	if not check(proposal != null,"real failed writer retains frozen ConfigFile proposal"): return
	var writer_id: int = writer.get_instance_id()
	var proposal_id: int = proposal.get_instance_id()
	var scope: Dictionary = campaign.get("_cfg_writer_scope").duplicate(true)
	var active: Dictionary = writer.get("_active").duplicate(true)
	var pending: Dictionary = writer.get("_pending_record").duplicate(true)
	var proposal_values: Dictionary = Values.semantics(proposal)
	if not check(scope.get("operation") == "cloud" and scope.get("target_owner") == LOCAL_OWNER
		and active.get("stage") == "staging" and proposal_values.get("ok",false),"actual frozen cloud scope and staging proposal retained"): return
	if not check(campaign.get("_cfg_writer_error").get("code") == "CFG_STAGE_PARENT","real parent-path failure code retained"): return
	if not check(_campaign_memory(campaign) == memory and _cfg_digest() == cfg_sha,"failed staged cloud write preserves original Campaign memory and CFG bytes"): return
	if not check(_cloud_flags(cloud) == flags and not cloud._applying and cloud.shared_profile_pending(),"failed production apply keeps original cloud flags and shared pending profile"): return
	if not check(flow.phase == flow.Phase.ERROR and flow.last_result.get("config_pending",false)
		and flow.last_result.get("code") == "CFG_STAGE_PARENT" and paused,"actual configuration ERROR pauses with original failure"): return
	if not check(is_instance_valid(flow._overlay) and flow._overlay.visible,"actual configuration failure overlay retained"): return
	var retry: Button = flow._overlay.find_child("RetryCampaignConfig",true,false) as Button
	if not check(retry != null and retry.text == "重试保存设置" and not retry.disabled and retry.is_visible_in_tree()
		and retry.is_connected("pressed",Callable(flow,"retry_config")),"actual visible retry control is connected to production retry_config"): return
	if not check(FileAccess.get_sha256(BLOCKER) == blocker_sha,"original obstruction bytes unchanged before own repair"): return
	if not check(DirAccess.remove_absolute(ProjectSettings.globalize_path(BLOCKER)) == OK,"only this probe's closed obstruction file is removed"): return
	if not check(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(BLOCKER)) == OK,"real stage parent repaired to an empty directory"): return
	if not check(campaign.get("_cfg_writer") == writer and writer.get("_frozen_cfg") == proposal
		and writer.get("_active") == active and writer.get("_pending_record") == pending
		and Values.semantics(proposal) == proposal_values and _campaign_memory(campaign) == memory and _cfg_digest() == cfg_sha,
		"filesystem repair does not replace pending writer proposal or publish progress"): return
	# A repaired disk does not grant account authority. Exercise the real UI path;
	# do not invoke writer.retry_write directly or fabricate Steam availability.
	retry.pressed.emit()
	var started: int = Time.get_ticks_msec()
	while flow.last_result.get("code") != "CLOUD_RETRY_SCOPE_CHANGED" and Time.get_ticks_msec()-started < 5000:
		await process_frame
	if not check(flow.last_result.get("code") == "CLOUD_RETRY_SCOPE_CHANGED" and flow.phase == flow.Phase.ERROR
		and flow.last_result.get("config_pending",false) and paused,"actual UI retry refuses synthetic owner without real account authority"): return
	if not check(campaign.get("_cfg_writer") == writer and writer.get_instance_id() == writer_id
		and writer.get("_frozen_cfg") == proposal and proposal.get_instance_id() == proposal_id
		and writer.get("_active") == active and writer.get("_pending_record") == pending
		and campaign.get("_cfg_writer_scope") == scope and Values.semantics(proposal) == proposal_values,
		"unauthorized retry retains exact same writer scope and frozen proposal"): return
	if not check(_campaign_memory(campaign) == memory and _cfg_digest() == cfg_sha and _cloud_flags(cloud) == flags
		and not steam.available and not cloud.cloud_ready and not cloud._applying and cloud.shared_profile_pending(),
		"refused retry changes no progress CFG memory cloud flags or SDK state"): return
	for frame in range(180): await process_frame
	if not check(campaign.get_instance_id() == campaign_id and cloud.get_instance_id() == cloud_id
		and campaign.get("_cfg_writer") == writer and writer.busy() and writer.get("_frozen_cfg") == proposal
		and _campaign_memory(campaign) == memory and _cfg_digest() == cfg_sha and _cloud_flags(cloud) == flags,
		"ordinary post-refusal frames preserve same original objects and pending data"): return
	failure_evidence = {"campaign_id":campaign_id,"cloud_id":cloud_id,"writer_id":writer_id,"proposal_id":proposal_id,
		"original_memory":memory,"original_cloud":flags,"original_cfg_sha256":cfg_sha,"blocker_sha256":blocker_sha,
		"apply_returned":applied,"writer_error":"CFG_STAGE_PARENT","retry_error":flow.last_result.duplicate(true),
		"writer_scope":scope,"writer_active":active,"writer_pending_record":pending,"proposal_semantics":proposal_values,
		"final_memory":_campaign_memory(campaign),"final_cloud":_cloud_flags(cloud),"final_cfg_sha256":_cfg_digest(),
		"same_pending_writer_retained":true,"real_fault_repaired":true,"successful_authorized_retry":false}

func _finish() -> void:
	check(mode == "first","failure boundary cannot substitute authorized account retry or restart")
	var passed: bool = failures.is_empty()
	var report: Dictionary = {"schema":"campaign_original19_cloud_write_failure_probe_v1","passed":passed,
		"checks":checks,"failures":failures,"observations":observations,"pid":OS.get_process_id(),"nonce":nonce,
		"mode":mode,"case":FAILURE_CASE,"identity":identity.duplicate(true),"user_directory":OS.get_user_data_dir(),
		"time_scale":Engine.time_scale,"physics_ticks":Engine.physics_ticks_per_second,"failure_evidence":failure_evidence,
		"scope":"SDK-disabled real storage failure and refused-account retry boundary only",
		"successful_authorized_same_writer_retry_required":true,"successful_authorized_same_writer_retry_qualified":false,
		"restart_qualified":false,"Steam_account_qualified":false,"upload_qualified":false,"SDK_reward_once_qualified":false,
		"original19_faults_qualified":false,"pending_failure_UI_qualified":false,"overall_goal_qualified":false}
	if not _write("report.json",report): quit(2);return
	print("CLOUD_REAL_WRITE_FAILURE_BOUNDARY_COMPLETE ",OS.get_process_id()," ",nonce," ",checks.size()," ",passed)
	quit(0 if passed else 1)
