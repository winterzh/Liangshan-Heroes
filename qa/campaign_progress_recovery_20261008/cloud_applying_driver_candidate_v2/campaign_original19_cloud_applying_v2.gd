extends "res://tools/campaign_original19_first_repeat_v1.gd"
## Real production _apply_profile -> CFG writer -> mark_dirty callback.
## Numeric owner is synthetic local input only, with SDK disabled throughout.
## No fake Cloud/Campaign node, direct memory seed or manual _applying toggle.
const CALLBACK_CASE := "cloud_applying_callback_no_upload_claim"
const FIXTURE_OWNER := "1"
var callback_observer
var cloud_evidence: Dictionary = {}

func _fresh() -> void:
	if not check(mode=="first" and OS.get_environment("CAMPAIGN_CALLBACK_CASE")==CALLBACK_CASE,"single real cloud applying mode"): return
	var campaign: Node=root.get_node("Campaign")
	var cloud: Node=root.get_node("SteamCloud")
	var steam: Node=root.get_node("SteamService")
	if not check(not steam.available and not cloud.cloud_ready and cloud._owner.is_empty(),"SDK disabled and unattached production cloud"): return
	if not check(campaign.records.is_empty() and campaign.unlocked==1 and campaign.cloud_owner.is_empty() and not campaign.persistence_busy() and not cloud.shared_profile_pending(),"fresh ordinary campaign with no pending writer or shared profile"): return
	var campaign_id: int=campaign.get_instance_id()
	var cloud_id: int=cloud.get_instance_id()
	var original_memory: Dictionary={"records":campaign.records.duplicate(true),"unlocked":campaign.unlocked,"owner":campaign.cloud_owner}
	var original_cloud: Dictionary={"dirty":cloud.dirty,"pending_upload":cloud._pending_upload,"revision":cloud._revision}
	var original_cfg: String=FileAccess.get_sha256("user://campaign.cfg") if FileAccess.file_exists("user://campaign.cfg") else ""
	# Explicit internal account seam input. This does not attach or enable Steam,
	# set campaign owner/memory, change applying, or fabricate an uploaded result.
	cloud._owner=FIXTURE_OWNER
	var payload: Dictionary=cloud._build_payload(FIXTURE_OWNER)
	payload.campaign={"schema":2,"unlocked":2,"records":{}}
	if not check(cloud._validate_payload(payload,FIXTURE_OWNER),"real validator accepts bounded synthetic local cloud input"): return
	var Observer: Script=load("res://tools/campaign_cloud_callback_observer_v2.gd")
	if not check(Observer!=null,"actual read-only cloud callback observer loaded"): return
	callback_observer=Observer.new()
	var profile: String=OS.get_environment("CAMPAIGN_TERMINAL_PROFILE")
	if not check(callback_observer.install(self,nonce,CALLBACK_CASE,profile,identity),"read-only observer on original production cloud and campaign"): return
	if not check(_write("callback_driver_ready.json",{"schema":"campaign_callback_driver_ready_v1","pid":OS.get_process_id(),"nonce":nonce,"case":CALLBACK_CASE,"identity":identity.duplicate(true),"user_directory":OS.get_user_data_dir()}),"closed original cloud callback driver ready"): return
	if not check(_write("cloud_apply_ready.json",{"schema":"campaign_cloud_apply_ready_v1","pid":OS.get_process_id(),"nonce":nonce,"case":CALLBACK_CASE,"identity":identity.duplicate(true),"user_directory":OS.get_user_data_dir(),"campaign_id":campaign_id,"cloud_id":cloud_id,"original_memory":original_memory,"original_cloud":original_cloud,"original_cfg_sha256":original_cfg,"payload":payload.duplicate(true),"synthetic_local_owner":true,"SDK_disabled":true,"Steam_account_qualified":false,"upload_qualified":false}),"closed original payload and baseline before real cloud apply"): return
	# Host must retain breakpoint-send and arm-send/ack on the same transport.
	# An actual engine-dispatched arm message releases this bounded wait.
	var arm_deadline: int=Time.get_ticks_msec()+30000
	while not callback_observer.arm_received and Time.get_ticks_msec()<arm_deadline:
		await process_frame
	if not check(callback_observer.arm_received and callback_observer.last_sequence==0,"actual engine dispatcher received host arm before cloud apply"): return
	if not check(campaign.get_instance_id()==campaign_id and cloud.get_instance_id()==cloud_id and campaign.records==original_memory.records and campaign.unlocked==original_memory.unlocked and campaign.cloud_owner==original_memory.owner and not campaign.persistence_busy() and not cloud.shared_profile_pending(),"production memory and writer unchanged while waiting for host arm"): return
	if not check(cloud.dirty==original_cloud.dirty and cloud._pending_upload==original_cloud.pending_upload and cloud._revision==original_cloud.revision,"original cloud upload state unchanged while waiting for arm"): return
	# This invokes real _applying=true and the actual normal CFG transaction.
	# The host must stop at the independently bound production callback stack,
	# request exactly one read-only snapshot, preserve raw packets and resume.
	var applied: bool=cloud._apply_profile(payload.duplicate(true))
	if not check(applied,"actual production cloud profile applies through CFG writer"): return
	check(campaign.get_instance_id()==campaign_id and cloud.get_instance_id()==cloud_id,"same real production object instances after cloud apply")
	check(campaign.unlocked==2 and campaign.records.is_empty() and campaign.cloud_owner==FIXTURE_OWNER,"new campaign memory published by production writer complete")
	var cfg: ConfigFile=ConfigFile.new()
	check(cfg.load("user://campaign.cfg")==OK,"fresh independent load of actual cloud CFG")
	check(cfg.get_value("progress","schema",null)==2 and cfg.get_value("progress","unlocked",null)==2 and cfg.get_value("progress","records",null)=={} and cfg.get_value("progress","owner",null)==FIXTURE_OWNER,"actual public CFG matches cloud input")
	check(not campaign.persistence_busy() and not cloud.shared_profile_pending() and not cloud._applying,"actual writer and shared apply close normally")
	check(cloud.dirty==original_cloud.dirty and cloud._pending_upload==original_cloud.pending_upload and cloud._revision==original_cloud.revision,"applying callback creates no new dirty pending upload or revision")
	check(not steam.available and not cloud.cloud_ready,"no Steam attachment or SDK upload claim")
	cloud_evidence={"campaign_id":campaign_id,"cloud_id":cloud_id,"original_memory":original_memory,"original_cloud":original_cloud,"original_cfg_sha256":original_cfg,"payload":payload.duplicate(true),"applied":applied,"cfg_sha256":FileAccess.get_sha256("user://campaign.cfg"),"final_memory":{"records":campaign.records.duplicate(true),"unlocked":campaign.unlocked,"owner":campaign.cloud_owner},"final_cloud":{"dirty":cloud.dirty,"pending_upload":cloud._pending_upload,"revision":cloud._revision,"applying":cloud._applying,"shared_profile_pending":cloud.shared_profile_pending()},"synthetic_local_owner":true,"SDK_disabled":true}

func _write(name: String,value: Dictionary) -> bool:
	if name not in ["callback_driver_ready.json","cloud_apply_ready.json","report.json"]: return false
	var path: String=output.path_join(name)
	var pending: String=path+".native-"+nonce
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path) or FileAccess.file_exists(pending) or DirAccess.dir_exists_absolute(pending): return false
	var file: FileAccess=FileAccess.open(pending,FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify(value,"\t")+"\n");file.flush();file.close()
	print("CAMPAIGN_FILE19_EXPORT ",OS.get_process_id()," ",nonce," ",name," ",FileAccess.get_sha256(pending))
	return true

func _finish() -> void:
	check(mode=="first","cloud callback cannot substitute ordinary restart")
	check(callback_observer!=null and callback_observer.last_sequence==1,"exactly one actual callback snapshot received")
	if callback_observer!=null: callback_observer.close()
	var passed: bool=failures.is_empty()
	var report: Dictionary={"schema":"campaign_original19_cloud_applying_probe_v2","passed":passed,"checks":checks,"failures":failures,"observations":observations,"pid":OS.get_process_id(),"nonce":nonce,"mode":mode,"identity":identity.duplicate(true),"user_directory":OS.get_user_data_dir(),"time_scale":Engine.time_scale,"physics_ticks":Engine.physics_ticks_per_second,"case":CALLBACK_CASE,"observer_sequence":callback_observer.last_sequence if callback_observer!=null else 0,"cloud_evidence":cloud_evidence,"arm_ack":callback_observer.arm_ack.duplicate(true) if callback_observer!=null else {},"scope":"actual normal production cloud apply with synthetic local SDK-disabled owner; host must bind actual stack, raw packet custody, CFG journals and same-profile restart","actual_callback_qualified":false,"Steam_account_qualified":false,"upload_qualified":false,"SDK_reward_once_qualified":false,"original19_faults_qualified":false,"overall_goal_qualified":false}
	_write("report.json",report)
	print("NATURAL_CLOUD_APPLY_COMPLETE ",OS.get_process_id()," ",nonce," ",CALLBACK_CASE," ",checks.size()," ",passed)
	quit(0 if passed else 1)
