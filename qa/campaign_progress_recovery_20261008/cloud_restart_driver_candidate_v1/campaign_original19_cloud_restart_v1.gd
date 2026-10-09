extends "res://tools/campaign_original19_first_repeat_v1.gd"
## Ordinary new process reads the same completed local cloud profile.
## No account attachment, cloud apply, memory seed or lifecycle fabrication.
const CALLBACK_CASE := "cloud_applying_callback_no_upload_claim"
const CfgValues := preload("res://scripts/run_campaign_cfg_values.gd")
var restart_evidence: Dictionary = {}

func _restart() -> void:
	if not check(mode=="restart_first" and OS.get_environment("CAMPAIGN_CALLBACK_CASE")==CALLBACK_CASE,"ordinary cloud restart mode and case"): return
	var path: String=OS.get_environment("CAMPAIGN_CLOUD_PRIOR_REPORT_FILE")
	var digest: String=OS.get_environment("CAMPAIGN_CLOUD_PRIOR_REPORT_SHA256")
	if not check(path.is_absolute_path() and Intent.hex(digest,64) and FileAccess.file_exists(path),"immutable actual preceding cloud report path and SHA"): return
	var raw: PackedByteArray=FileAccess.get_file_as_bytes(path)
	var text: String=raw.get_string_from_utf8()
	if not check(not raw.is_empty() and raw.size()<=2097152 and text.to_utf8_buffer()==raw and text.sha256_text()==digest and FileAccess.get_sha256(path)==digest,"original cloud report exact bounded UTF8 bytes"): return
	var prior: Variant=JSON.parse_string(text)
	if not check(prior is Dictionary and prior.get("schema")=="campaign_original19_cloud_applying_probe_v3" and prior.get("passed")==true and prior.get("failures")==[] and prior.get("case")==CALLBACK_CASE and prior.get("mode")=="first","preceding original successful cloud report"): return
	if not check(prior.get("identity")==identity and prior.get("user_directory")==OS.get_user_data_dir() and prior.get("pid")!=OS.get_process_id() and Intent.hex(prior.get("nonce",""),32) and prior.nonce!=nonce,"same full installed identity and raw user text in a distinct process"): return
	var evidence: Variant=prior.get("cloud_evidence")
	var semantic: Variant=prior.get("cfg_semantics")
	if not check(evidence is Dictionary and semantic is Dictionary and evidence.get("applied")==true and evidence.get("synthetic_local_owner")==true and evidence.get("SDK_disabled")==true and evidence.get("final_memory")=={"records":{},"unlocked":2,"owner":"1"} and Intent.hex(evidence.get("cfg_sha256",""),64),"original local cloud result and exact final CFG hash"): return
	if not check(semantic.get("final_sections_json") is String and semantic.get("final_semantics_sha256") is String and semantic.final_sections_json.sha256_text()==semantic.final_semantics_sha256,"original whole native typed CFG projection hash"): return
	var expected: Variant=JSON.parse_string(semantic.final_sections_json)
	if not check(expected is Dictionary,"original whole native projection readable"): return
	var campaign: Node=root.get_node("Campaign")
	var cloud: Node=root.get_node("SteamCloud")
	var steam: Node=root.get_node("SteamService")
	var flow: Node=root.get_node("ContinueFlow")
	if not check(campaign.records.is_empty() and campaign.unlocked==2 and campaign.cloud_owner=="1" and not campaign.has_story_seal("level1"),"ordinary startup loads exact local cloud progress without a story seal"): return
	if not check(not campaign.persistence_busy() and not cloud.shared_profile_pending() and not cloud._applying,"ordinary startup has no pending writer or shared cloud apply"): return
	if not check(not steam.available and steam._active_run==0 and not cloud.cloud_ready and cloud._owner.is_empty(),"ordinary SDK disabled startup has no attached account or active run"): return
	if not check(flow.last_result=={"ok":true,"startup_checked":true,"progress_recovered":0,"settlement_authorized":false} and flow._campaign_completion.is_empty() and current_scene.scene_file_path=="res://scenes/menu.tscn","ordinary startup neither recovers a terminal nor creates Battle presentation"): return
	var cfg: ConfigFile=ConfigFile.new()
	if not check(FileAccess.get_sha256("user://campaign.cfg")==evidence.cfg_sha256 and cfg.load("user://campaign.cfg")==OK,"ordinary restart fresh load keeps original final public CFG bytes"): return
	var projected: Dictionary=CfgValues.semantics(cfg)
	if not check(projected.get("ok",false) and projected.sections==expected,"whole restart typed CFG projection matches original including unknown keys"): return
	var journals: Dictionary=_cloud_journal_files()
	if not check(journals.size()==2 and journals.values().all(func(value):return Intent.hex(value,64)),"ordinary restart retains exactly two nonempty CFG journal originals"): return
	if not check(_empty_cloud_stage() and _no_terminal_files(),"ordinary restart has empty candidate stage and no terminal lifecycle files"): return
	var campaign_id: int=campaign.get_instance_id()
	var cloud_id: int=cloud.get_instance_id()
	var original_cloud: Dictionary={"dirty":cloud.dirty,"pending_upload":cloud._pending_upload,"revision":cloud._revision}
	for frame in range(180): await process_frame
	while Engine.is_in_physics_frame(): await process_frame
	check(campaign.get_instance_id()==campaign_id and cloud.get_instance_id()==cloud_id and campaign.records.is_empty() and campaign.unlocked==2 and campaign.cloud_owner=="1","same loaded production objects retain progress across ordinary frames")
	check(FileAccess.get_sha256("user://campaign.cfg")==evidence.cfg_sha256 and _cloud_journal_files()==journals and _empty_cloud_stage() and _no_terminal_files(),"ordinary restart frames do not replay CFG or create terminal records")
	check(flow.phase==flow.Phase.IDLE and flow.last_result=={"ok":true,"startup_checked":true,"progress_recovered":0,"settlement_authorized":false} and flow._campaign_completion.is_empty() and Gate.background_allowed(),"ordinary restart remains idle with settlement denied and gate open")
	check(not campaign.persistence_busy() and not cloud.shared_profile_pending() and not cloud._applying and cloud.dirty==original_cloud.dirty and cloud._pending_upload==original_cloud.pending_upload and cloud._revision==original_cloud.revision and not steam.available and steam._active_run==0 and not cloud.cloud_ready and cloud._owner.is_empty(),"ordinary frames create no cloud pending upload revision or SDK run")
	check(FileAccess.get_sha256(path)==digest,"original preceding cloud report unchanged after ordinary frames")
	restart_evidence={"prior_report_sha256":digest,"prior_pid":prior.pid,"prior_nonce":prior.nonce,"cfg_sha256":evidence.cfg_sha256,"journal_files":journals,"sections_json":JSON.stringify(projected.sections),"startup_result":flow.last_result.duplicate(true),"final_memory":{"records":campaign.records.duplicate(true),"unlocked":campaign.unlocked,"owner":campaign.cloud_owner},"cloud_state":original_cloud,"campaign_id":campaign_id,"cloud_id":cloud_id}

func _cloud_journal_files() -> Dictionary:
	var directory: String="user://campaign_cfg_transactions/v1/5088120/1"
	var files: Dictionary={}
	if not DirAccess.dir_exists_absolute(directory): return files
	for name in DirAccess.get_files_at(directory):
		files[name]=FileAccess.get_sha256(directory.path_join(name))
	for name in DirAccess.get_directories_at(directory): files[name+"/"]=""
	return files

func _empty_cloud_stage() -> bool:
	var directory: String="user://campaign_cfg_candidates/v1"
	return DirAccess.dir_exists_absolute(directory) and DirAccess.get_files_at(directory).is_empty() and DirAccess.get_directories_at(directory).is_empty()

func _no_terminal_files() -> bool:
	var directory: String="user://continue/v1/local_runs"
	return not DirAccess.dir_exists_absolute(directory) or (DirAccess.get_files_at(directory).is_empty() and DirAccess.get_directories_at(directory).is_empty())

func _write(name: String,value: Dictionary) -> bool:
	if name!="report.json": return false
	var path: String=output.path_join(name)
	var pending: String=path+".native-"+nonce
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path) or FileAccess.file_exists(pending) or DirAccess.dir_exists_absolute(pending): return false
	var file: FileAccess=FileAccess.open(pending,FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify(value,"\t")+"\n");file.flush();file.close()
	print("CAMPAIGN_FILE19_EXPORT ",OS.get_process_id()," ",nonce," ",name," ",FileAccess.get_sha256(pending))
	return true

func _finish() -> void:
	var passed: bool=failures.is_empty() and not restart_evidence.is_empty()
	var report: Dictionary={"schema":"campaign_original19_cloud_restart_probe_v1","passed":passed,"checks":checks,"failures":failures,"observations":observations,"pid":OS.get_process_id(),"nonce":nonce,"mode":mode,"identity":identity.duplicate(true),"user_directory":OS.get_user_data_dir(),"time_scale":Engine.time_scale,"physics_ticks":Engine.physics_ticks_per_second,"case":CALLBACK_CASE,"restart_evidence":restart_evidence,"ordinary_restart_qualified":false,"Steam_account_qualified":false,"upload_qualified":false,"SDK_reward_once_qualified":false,"original19_faults_qualified":false,"overall_goal_qualified":false}
	if not _write("report.json",report): quit(2);return
	print("NATURAL_CLOUD_RESTART_COMPLETE ",OS.get_process_id()," ",nonce," ",CALLBACK_CASE," ",checks.size()," ",passed)
	quit(0 if passed else 1)
